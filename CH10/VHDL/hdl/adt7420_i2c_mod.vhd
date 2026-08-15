-- adt7420_i2c_mod.vhd
-- ----------------------------------------------------------------------------
--  ADT7420 I2C temperature-sensor reader with AXI-Lite register interface,
--  boxcar smoothing (via xpm_fifo_sync) and a bit-banged open-drain I2C master.
--
--  VHDL port of adt7420_i2c_mod.sv (see that file for the full commentary).
--
--  Notes on this port:
--    * DEVICE_ID is the ASCII string "TEMP" in the source; here it is carried
--      as the 32-bit value x"54454D50" ('T','E','M','P') so it can be returned
--      directly on the AXI read data bus.
--    * The I2C / smoothing logic is reset-less in the source (SV `initial`
--      blocks + un-reset `always`); the corresponding signals are given VHDL
--      declaration-time initial values and their process has no reset branch.
--    * Only the AXI read/write channels have a (synchronous, active-low) reset.
--    * TMP_INT and TMP_CT are unused inout pins; they are driven to 'Z'.
--    * xpm_fifo_sync generics not set here take the Xilinx IP defaults; only
--      FIFO_WRITE_DEPTH, WRITE_DATA_WIDTH and READ_MODE are overridden, exactly
--      as in the SystemVerilog source.
-- ----------------------------------------------------------------------------
-- Author : Frank Bruno

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library xpm;
use xpm.vcomponents.all;

entity adt7420_i2c_mod is
  generic (
    -- ASCII "TEMP" carried as a 32-bit read value ('T','E','M','P')
    DEVICE_ID : std_logic_vector(31 downto 0) := x"54454D50";
    SMOOTHING : integer := 16;
    INTERVAL  : integer := 1000000000;
    CLK_PER   : integer := 10
  );
  port (
    -- AXI lite interface for register access
    s_axi_aclk    : in  std_logic;
    s_axi_aresetn : in  std_logic;
    s_axi_awaddr  : in  std_logic_vector(21 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    s_axi_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;
    s_axi_araddr  : in  std_logic_vector(21 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    s_axi_rdata   : out std_logic_vector(31 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic;

    -- Temperature Sensor Interface
    TMP_SCL_i : in    std_logic;
    TMP_SCL_o : out   std_logic;
    TMP_SCL_t : out   std_logic;
    TMP_SDA_i : in    std_logic;
    TMP_SDA_o : out   std_logic;
    TMP_SDA_t : out   std_logic;
    TMP_INT   : inout std_logic;
    TMP_CT    : inout std_logic;

    fix_temp_tvalid : out std_logic;
    fix_temp_tdata  : out std_logic_vector(15 downto 0);

    flt_temp_tvalid : in  std_logic;
    flt_temp_tdata  : in  std_logic_vector(15 downto 0)
  );
end entity adt7420_i2c_mod;

architecture rtl of adt7420_i2c_mod is

  -- Clock ticks per interval / I2C timing (integer division, as in the source)
  constant TIME_1SEC   : integer := INTERVAL/CLK_PER; -- Clock ticks in 1 sec
  constant TIME_THDSTA : integer := 600/CLK_PER;
  constant TIME_TSUSTA : integer := 600/CLK_PER;
  constant TIME_THIGH  : integer := 600/CLK_PER;
  constant TIME_TLOW   : integer := 1300/CLK_PER;
  constant TIME_TSUDAT : integer := 20/CLK_PER;
  constant TIME_TSUSTO : integer := 600/CLK_PER;
  constant TIME_THDDAT : integer := 30/CLK_PER;

  constant I2C_ADDR : std_logic_vector(6 downto 0) := "1001011"; -- 0x4B

  constant I2CBITS : integer :=
    1 +      -- start
    7 +      -- 7 bits for address
    1 +      -- 1 bit for read
    1 +      -- 1 bit for ack back
    8 +      -- 8 bits upper data
    1 +      -- 1 bit for ack
    8 +      -- 8 bits lower data
    1 +      -- 1 bit for ack
    1 + 1;   -- 1 bit for stop

  -- ADT7420 register pointer for the temperature MSB register.
  constant PTR_TEMP : std_logic_vector(7 downto 0) := x"00";
  -- Terminal bit_count for each phase.
  constant WR_LAST : integer := 18;
  constant RD_LAST : integer := I2CBITS;

  -- Register address map (used as literal case choices below)
  constant ADDR_DEVICE_ID    : std_logic_vector(7 downto 0) := x"00";
  constant ADDR_VERSION      : std_logic_vector(7 downto 0) := x"04";
  constant ADDR_STATUS       : std_logic_vector(7 downto 0) := x"10";
  constant ADDR_TEMP         : std_logic_vector(7 downto 0) := x"14";
  constant ADDR_TEMP_SMOOTH  : std_logic_vector(7 downto 0) := x"18";
  constant ADDR_TEMP_FLOAT   : std_logic_vector(7 downto 0) := x"1C";

  constant CLOG2_TIME_1SEC : integer := integer(ceil(log2(real(TIME_1SEC))));
  constant CLOG2_I2CBITS   : integer := integer(ceil(log2(real(I2CBITS))));
  constant SMOOTHING_SHIFT : integer := integer(ceil(log2(real(SMOOTHING))));

  type axil_rd_cs_t is (RD_IDLE, RD_WAIT, RD_W4RREADY);
  type axil_cs_t    is (WR_IDLE, WR_W4ADDR, WR_W4DATA, WR_BRESP);
  signal axil_rd_cs : axil_rd_cs_t;
  signal axil_cs    : axil_cs_t;

  signal rd_addr    : std_logic_vector(7 downto 0);
  signal read_data  : std_logic_vector(31 downto 0);
  signal axil_din   : std_logic_vector(31 downto 0);
  signal axil_be    : std_logic_vector(3 downto 0);
  signal axil_we    : std_logic;
  signal axil_addr  : std_logic_vector(7 downto 0);

  signal sda_en     : std_logic := '0';
  signal scl_en     : std_logic := '0';
  signal i2c_data   : std_logic_vector(I2CBITS-1 downto 0);
  signal i2c_en     : std_logic_vector(I2CBITS-1 downto 0);
  signal i2c_capt   : std_logic_vector(I2CBITS-1 downto 0);
  signal counter    : unsigned(CLOG2_TIME_1SEC-1 downto 0) := (others => '0');
  signal counter_reset : std_logic := '0';
  signal bit_count  : unsigned(CLOG2_I2CBITS-1 downto 0) := (others => '0');
  signal temp_data  : std_logic_vector(15 downto 0);
  signal capture_en : std_logic;
  signal convert    : std_logic;
  signal temp_count : unsigned(31 downto 0) := (others => '0');
  signal wr_phase   : std_logic := '0'; -- 1 = writing pointer, 0 = reading temperature

  type spi_t is (IDLE, START, TLOW, TSU, THIGH, THD,
                 PSTO,   -- stop setup: pull SDA low while SCL is low
                 TSTO,
                 TBUF);  -- bus-free time between pointer-write and read
  signal spi_state : spi_t;

  -- Smoothing / accumulator
  signal smooth_data    : signed(15 downto 0);
  signal smooth_convert : std_logic;
  signal smooth_capt    : signed(15 downto 0);
  signal smooth_count   : unsigned(SMOOTHING_SHIFT downto 0) := (others => '0');
  signal dout           : signed(15 downto 0);
  signal dout_slv       : std_logic_vector(15 downto 0);
  signal rden, rden_del : std_logic := '0';
  signal accumulator    : signed(31 downto 0) := (others => '0');
  signal temperature    : signed(15 downto 0);
  signal fp_temp        : signed(15 downto 0);

  -- helper: index into the I2C bit vectors from the current bit_count
  function cur_idx(bc : unsigned) return integer is
  begin
    return I2CBITS - to_integer(bc) - 1;
  end function;

begin

  -- Open-drain temperature-sensor pins
  TMP_SCL_o <= '0';
  TMP_SCL_t <= scl_en;
  TMP_SDA_o <= '0';
  TMP_SDA_t <= sda_en;

  -- Unused inout pins
  TMP_INT <= 'Z';
  TMP_CT  <= 'Z';

  capture_en <= i2c_capt(cur_idx(bit_count));

  -- I2C bit-banged master + interval counter (reset-less)
  process (s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      scl_en <= '1';
      sda_en <= (not i2c_en(cur_idx(bit_count))) or i2c_data(cur_idx(bit_count));
      if counter_reset = '1' then
        counter <= (others => '0');
      else
        counter <= counter + 1;
      end if;
      counter_reset <= '0';
      convert       <= '0';

      case spi_state is
        when IDLE =>
          -- Every cycle runs two transactions: a pointer write then a read.
          wr_phase  <= '1';
          i2c_data  <= "0" & I2C_ADDR & "0" & "1" & PTR_TEMP & "1" & "00000000000";
          i2c_en    <= "1" & "1111111" & "1" & "0" & x"FF" & "0" & "00000000000";
          i2c_capt  <= (others => '0'); -- nothing captured while writing pointer
          bit_count <= (others => '0');
          sda_en    <= '1'; -- Force to 1 in the beginning.

          if counter = TIME_1SEC then
            temp_data     <= (others => '0');
            spi_state     <= START;
            counter_reset <= '1';
            sda_en        <= '0'; -- Drop the data
          end if;

        when START =>
          sda_en <= '0'; -- Drop the data
          if counter = TIME_THDSTA then
            counter_reset <= '1';
            scl_en        <= '0'; -- Drop the clock
            spi_state     <= TLOW;
          end if;

        when TLOW =>
          scl_en <= '0'; -- Drop the clock
          if counter = TIME_TLOW then
            bit_count     <= bit_count + 1;
            counter_reset <= '1';
            spi_state     <= TSU;
          end if;

        when TSU =>
          scl_en <= '0'; -- Drop the clock
          if counter = TIME_TSUSTA then
            counter_reset <= '1';
            spi_state     <= THIGH;
          end if;

        when THIGH =>
          scl_en <= '1'; -- Raise the clock
          if counter = TIME_THIGH then
            if capture_en = '1' then
              temp_data <= temp_data(14 downto 0) & TMP_SDA_i;
            end if;
            counter_reset <= '1';
            spi_state     <= THD;
          end if;

        when THD =>
          scl_en <= '0'; -- Drop the clock
          if counter = TIME_THDDAT then
            counter_reset <= '1';
            -- Each phase stops after its own last bit; PSTO/TSTO form the STOP.
            if (wr_phase = '1' and bit_count = WR_LAST) or
               (wr_phase = '0' and bit_count = RD_LAST) then
              spi_state <= PSTO;
            else
              spi_state <= TLOW;
            end if;
          end if;

        when PSTO =>
          -- Stop setup: with SCL low, pull SDA low.
          scl_en <= '0'; -- keep SCL low
          sda_en <= '0'; -- drive SDA low
          if counter = TIME_TSUSTA then
            counter_reset <= '1';
            spi_state     <= TSTO;
          end if;

        when TSTO =>
          -- Raise SCL with SDA held low, then release SDA high => STOP.
          scl_en <= '1'; -- SCL high
          sda_en <= '0'; -- SDA low, ready to rise
          if counter = TIME_TSUSTO then
            counter_reset <= '1';
            sda_en        <= '1'; -- release SDA high => STOP
            if wr_phase = '1' then
              -- Pointer write finished. Load the read frame.
              wr_phase  <= '0';
              i2c_data  <= "0" & I2C_ADDR & "1" & "0" & x"00" & "0" & x"00" & "1" & "0" & "1";
              i2c_en    <= "1" & "1111111" & "1" & "0" & x"00" & "1" & x"00" & "1" & "1" & "1";
              i2c_capt  <= "0" & "0000000" & "0" & "0" & x"FF" & "0" & x"FF" & "0" & "0" & "0";
              bit_count <= (others => '0');
              spi_state <= TBUF;
            else
              -- Read finished; publish the sample.
              convert    <= '1';
              temp_count <= temp_count + 1;
              spi_state  <= IDLE;
            end if;
          end if;

        when TBUF =>
          -- Bus-free time between the two transactions, then a fresh START.
          scl_en <= '1'; -- SCL idle high
          sda_en <= '1'; -- SDA idle high
          if counter = TIME_TLOW then
            counter_reset <= '1';
            sda_en        <= '0'; -- drop SDA while SCL high => (re)START
            spi_state     <= START;
          end if;

      end case;
    end if;
  end process;

  fix_temp_tvalid <= convert;
  fix_temp_tdata  <= std_logic_vector(shift_right(unsigned(temp_data), 3));

  dout <= signed(dout_slv);

  -- Boxcar smoothing accumulator (reset-less)
  process (s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      rden           <= '0';
      rden_del       <= rden;
      smooth_convert <= '0';
      if convert = '1' then
        smooth_count <= smooth_count + 1;
        accumulator  <= accumulator + signed(temp_data(15 downto 3) & "000");
      elsif smooth_count = SMOOTHING+1 then
        rden         <= '1';
        smooth_count <= smooth_count - 1;
        accumulator  <= accumulator - dout;
      elsif rden = '1' then
        smooth_data    <= resize(shift_right(accumulator, SMOOTHING_SHIFT), 16);
        smooth_convert <= '1';
      end if;
    end if;
  end process;

  u_xpm_fifo_sync : xpm_fifo_sync
    generic map (
      FIFO_WRITE_DEPTH => SMOOTHING,
      WRITE_DATA_WIDTH => 16,
      READ_DATA_WIDTH  => 16,   -- symmetric FIFO. The SV omitted this, leaving the
                                -- XPM default of 32 (an asymmetric 16-write/32-read
                                -- FIFO) and relying on Verilog silently truncating
                                -- the 16-bit dout net; VHDL requires the exact width.
      READ_MODE        => "FWFT"
    )
    port map (
      sleep         => '0',
      rst           => '0',

      wr_clk        => s_axi_aclk,
      wr_en         => convert,
      din           => temp_data(15 downto 3) & "000",
      full          => open,
      prog_full     => open,
      wr_data_count => open,
      overflow      => open,
      wr_rst_busy   => open,
      almost_full   => open,
      wr_ack        => open,

      rd_en         => rden,
      dout          => dout_slv,
      empty         => open,
      prog_empty    => open,
      rd_data_count => open,
      underflow     => open,
      rd_rst_busy   => open,
      almost_empty  => open,
      data_valid    => open,

      injectsbiterr => '0',
      injectdbiterr => '0',
      sbiterr       => open,
      dbiterr       => open
    );

  -- AXI Read Channel
  process (s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      s_axi_arready <= '1';
      s_axi_rvalid  <= '0';
      s_axi_rresp   <= "00";

      case axil_rd_cs is
        when RD_IDLE =>
          if s_axi_arvalid = '1' then
            s_axi_arready <= '0';
            rd_addr       <= s_axi_araddr(7 downto 0);
            axil_rd_cs    <= RD_WAIT;
          end if;
        when RD_WAIT =>
          s_axi_arready <= '0';
          axil_rd_cs    <= RD_W4RREADY;
        when RD_W4RREADY =>
          s_axi_arready <= '0';
          s_axi_rdata   <= read_data;
          s_axi_rvalid  <= '1';
          if s_axi_rready = '1' and s_axi_rvalid = '1' then
            s_axi_arready <= '1';
            s_axi_rvalid  <= '0';
            axil_rd_cs    <= RD_IDLE;
          end if;
      end case;

      if s_axi_aresetn = '0' then
        axil_rd_cs <= RD_IDLE;
      end if;
    end if;
  end process;

  -- AXI Write Channel
  process (s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      axil_we      <= '0';
      s_axi_bvalid <= '0';
      s_axi_bresp  <= "00"; -- OKAY

      case axil_cs is
        when WR_IDLE =>
          s_axi_awready <= '1';
          s_axi_wready  <= '1';
          case std_logic_vector'(s_axi_awvalid & s_axi_wvalid) is
            when "11" =>
              s_axi_awready <= '0';
              s_axi_wready  <= '0';
              axil_addr     <= s_axi_awaddr(7 downto 0);
              axil_we       <= '1';
              s_axi_bvalid  <= '1';
              axil_cs       <= WR_BRESP;
              axil_din      <= s_axi_wdata;
              axil_be       <= s_axi_wstrb;
            when "10" =>
              -- Address only
              s_axi_awready <= '0';
              axil_addr     <= s_axi_awaddr(7 downto 0);
              axil_cs       <= WR_W4DATA;
            when "01" =>
              s_axi_wready <= '0';
              axil_we      <= '1';
              axil_din     <= s_axi_wdata;
              axil_be      <= s_axi_wstrb;
              axil_cs      <= WR_W4ADDR;
            when others =>
              null;
          end case;

        when WR_W4DATA =>
          if s_axi_wvalid = '1' then
            s_axi_wready <= '0';
            axil_we      <= '1';
            s_axi_bvalid <= '1';
            axil_din     <= s_axi_wdata;
            axil_be      <= s_axi_wstrb;
            axil_cs      <= WR_BRESP;
          end if;

        when WR_W4ADDR =>
          if s_axi_awvalid = '1' then
            s_axi_awready <= '0';
            s_axi_bvalid  <= '1';
            axil_addr     <= s_axi_awaddr(7 downto 0);
            axil_cs       <= WR_BRESP;
          end if;

        when WR_BRESP =>
          s_axi_awready <= '0';
          s_axi_wready  <= '0';
          s_axi_bvalid  <= '1';
          if s_axi_bready = '1' then
            s_axi_awready <= '1';
            s_axi_wready  <= '1';
            s_axi_bvalid  <= '0';
            axil_cs       <= WR_IDLE;
          end if;
      end case;

      if s_axi_aresetn = '0' then
        axil_cs <= WR_IDLE;
      end if;
    end if;
  end process;

  -- Register read-data mux
  process (s_axi_aclk)
  begin
    if rising_edge(s_axi_aclk) then
      if smooth_convert = '1' then smooth_capt <= smooth_data; end if;
      if convert = '1' then temperature <= signed(temp_data); end if;
      if flt_temp_tvalid = '1' then fp_temp <= signed(flt_temp_tdata); end if;
      read_data <= (others => '0');
      case rd_addr is
        when x"00" => read_data <= DEVICE_ID;                                  -- ADDR_DEVICE_ID
        when x"04" => read_data <= x"00000000";                               -- ADDR_VERSION
        when x"10" => read_data <= std_logic_vector(temp_count);              -- ADDR_STATUS
        when x"14" => read_data <= x"0000" & std_logic_vector(temperature);   -- ADDR_TEMP
        when x"18" => read_data <= x"0000" & std_logic_vector(smooth_capt);   -- ADDR_TEMP_SMOOTH
        when x"1C" => read_data <= x"0000" & std_logic_vector(fp_temp);       -- ADDR_TEMP_FLOAT
        when others => read_data <= x"00000000";
      end case;
    end if;
  end process;

end architecture rtl;
