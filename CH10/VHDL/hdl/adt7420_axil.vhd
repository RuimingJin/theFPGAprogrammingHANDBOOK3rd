-- adt7420_axil.vhd
-- ----------------------------------------------------------------------------
--  AXI4-Lite wrapper around adt7420_temp_if.  Exposes the current
--  (instantaneous) and 16-sample-averaged ADT7420 temperatures, plus status,
--  as read registers.  The sensor logic runs on the AXI clock (single clock
--  domain, no CDC).
--
--  VHDL port of adt7420_axil.sv (see that file for the full commentary).
--
--  Register map (byte offsets, 32-bit registers, read-only):
--    0x00  TEMP_INST  signed 32-bit, sign-extended.  degC = value / 128.0
--    0x04  TEMP_AVG   signed 32-bit, sign-extended.  degC = value / 128.0
--    0x08  STATUS     [0]     busy   (transaction in progress)
--                     [1]     error  (last I2C transaction was NACKed)
--                     [31:16] sample counter (increments per new measurement)
--    0x0C  ID         0x00007420 (ADT7420 part number, for probing)
--
--  Writes are accepted and answered OKAY (there are no writable registers).
-- ----------------------------------------------------------------------------
-- Author : Frank Bruno

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity adt7420_axil is
  generic (
    CLK_FREQ_HZ        : integer := 100_000_000;          -- = AXI clock
    I2C_FREQ_HZ        : integer := 100_000;
    SAMPLE_HZ          : integer := 4;
    DEV_ADDR           : std_logic_vector(6 downto 0) := "1001011"; -- 7'h4B
    AVG_N              : integer := 16;
    C_S_AXI_ADDR_WIDTH : integer := 4
  );
  port (
    -- AXI4-Lite slave
    s_axi_aclk    : in  std_logic;
    s_axi_aresetn : in  std_logic;

    s_axi_awaddr  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    s_axi_awvalid : in  std_logic;
    s_axi_awready : out std_logic;
    s_axi_wdata   : in  std_logic_vector(31 downto 0);
    s_axi_wstrb   : in  std_logic_vector(3 downto 0);
    s_axi_wvalid  : in  std_logic;
    s_axi_wready  : out std_logic;
    s_axi_bresp   : out std_logic_vector(1 downto 0);
    s_axi_bvalid  : out std_logic;
    s_axi_bready  : in  std_logic;

    s_axi_araddr  : in  std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
    s_axi_arvalid : in  std_logic;
    s_axi_arready : out std_logic;
    s_axi_rdata   : out std_logic_vector(31 downto 0);
    s_axi_rresp   : out std_logic_vector(1 downto 0);
    s_axi_rvalid  : out std_logic;
    s_axi_rready  : in  std_logic;

    temp_inst_valid : out std_logic;
    temp_inst       : out signed(15 downto 0);
    fx_inst_valid   : in  std_logic;
    fx_inst         : in  signed(15 downto 0);
    fh_inst_valid   : in  std_logic;
    fh_inst         : in  signed(15 downto 0);

    -- I2C open-drain bus (to external IOBUFs)
    scl_i : in  std_logic;
    scl_o : out std_logic;
    scl_t : out std_logic;
    sda_i : in  std_logic;
    sda_o : out std_logic;
    sda_t : out std_logic
  );
end entity adt7420_axil;

architecture rtl of adt7420_axil is

  component adt7420_temp_if is
    generic (
      CLK_FREQ_HZ : integer := 100_000_000;
      I2C_FREQ_HZ : integer := 100_000;
      SAMPLE_HZ   : integer := 4;
      DEV_ADDR    : std_logic_vector(6 downto 0) := "1001011";
      AVG_N       : integer := 16
    );
    port (
      clk             : in  std_logic;
      rst_n           : in  std_logic;
      scl_i           : in  std_logic;
      scl_o           : out std_logic;
      scl_t           : out std_logic;
      sda_i           : in  std_logic;
      sda_o           : out std_logic;
      sda_t           : out std_logic;
      temp_inst       : out signed(15 downto 0);
      temp_inst_valid : out std_logic;
      temp_avg        : out signed(15 downto 0);
      temp_avg_valid  : out std_logic;
      busy            : out std_logic;
      error           : out std_logic
    );
  end component;

  -- Sensor interface signals (runs on the AXI clock / reset)
  signal temp_avg       : signed(15 downto 0);
  signal temp_avg_valid : std_logic;
  signal busy, error    : std_logic;

  -- Internal copy of temp_inst (output port cannot be read directly)
  signal temp_inst_i       : signed(15 downto 0);
  signal temp_inst_valid_i : std_logic;

  -- Captured measurements + sample counter
  signal inst_r, avg_r, fh_r, fx_r : signed(15 downto 0);
  signal sample_cnt                : unsigned(15 downto 0);

  -- Read-data mux and sign-extended register values
  signal inst_ext, avg_ext, fh_ext, fx_ext : std_logic_vector(31 downto 0);
  signal rd_mux                            : std_logic_vector(31 downto 0);

  -- Internal AXI handshake registers (outputs cannot be read back)
  signal arready_i : std_logic;
  signal rvalid_i  : std_logic;
  signal awready_i : std_logic;
  signal wready_i  : std_logic;
  signal bvalid_i  : std_logic;

begin

  --------------------------------------------------------------------
  -- Sensor interface (runs on the AXI clock / reset)
  --------------------------------------------------------------------
  u_sensor : adt7420_temp_if
    generic map (
      CLK_FREQ_HZ => CLK_FREQ_HZ,
      I2C_FREQ_HZ => I2C_FREQ_HZ,
      SAMPLE_HZ   => SAMPLE_HZ,
      DEV_ADDR    => DEV_ADDR,
      AVG_N       => AVG_N
    )
    port map (
      clk             => s_axi_aclk,
      rst_n           => s_axi_aresetn,
      scl_i           => scl_i,
      scl_o           => scl_o,
      scl_t           => scl_t,
      sda_i           => sda_i,
      sda_o           => sda_o,
      sda_t           => sda_t,
      temp_inst       => temp_inst_i,
      temp_inst_valid => temp_inst_valid_i,
      temp_avg        => temp_avg,
      temp_avg_valid  => temp_avg_valid,
      busy            => busy,
      error           => error
    );

  temp_inst       <= temp_inst_i;
  temp_inst_valid <= temp_inst_valid_i;

  --------------------------------------------------------------------
  -- Capture the latest measurements + a sample counter
  --------------------------------------------------------------------
  process (s_axi_aclk, s_axi_aresetn) begin
    if s_axi_aresetn = '0' then
      inst_r     <= (others => '0');
      avg_r      <= (others => '0');
      sample_cnt <= (others => '0');
    elsif rising_edge(s_axi_aclk) then
      if temp_inst_valid_i = '1' then
        inst_r     <= temp_inst_i;
        sample_cnt <= sample_cnt + 1;
      end if;
      if temp_avg_valid = '1' then avg_r <= temp_avg; end if;
      if fx_inst_valid  = '1' then fx_r  <= fx_inst;  end if;
      if fh_inst_valid  = '1' then fh_r  <= fh_inst;  end if;
    end if;
  end process;

  --------------------------------------------------------------------
  -- Read-data mux (registers are word-aligned; decode araddr[4:2])
  --------------------------------------------------------------------
  inst_ext <= std_logic_vector(resize(inst_r, 32));   -- sign-extend to 32 bits
  avg_ext  <= std_logic_vector(resize(avg_r,  32));
  fh_ext   <= std_logic_vector(resize(fh_r,   32));
  fx_ext   <= std_logic_vector(resize(fx_r,   32));

  process (all)
    variable sel : integer range 0 to 7;
  begin
    sel := to_integer(unsigned(s_axi_araddr(4 downto 2)));
    case sel is
      when 0      => rd_mux <= inst_ext;                                       -- TEMP_INST
      when 1      => rd_mux <= avg_ext;                                        -- TEMP_AVG
      when 2      => rd_mux <= std_logic_vector(sample_cnt) & "00000000000000" -- STATUS
                              & error & busy;
      when 3      => rd_mux <= x"0000_7420";                                   -- ID
      when 4      => rd_mux <= fx_ext;
      when 5      => rd_mux <= fh_ext;
      when others => rd_mux <= x"0000_0000";
    end case;
  end process;

  --------------------------------------------------------------------
  -- AXI4-Lite read channel
  --------------------------------------------------------------------
  process (s_axi_aclk, s_axi_aresetn) begin
    if s_axi_aresetn = '0' then
      arready_i   <= '0';
      rvalid_i    <= '0';
      s_axi_rresp <= "00";
      s_axi_rdata <= (others => '0');
    elsif rising_edge(s_axi_aclk) then
      arready_i <= '0';                                 -- default: 1-cycle accept
      if s_axi_arvalid = '1' and arready_i = '0' and rvalid_i = '0' then
        arready_i   <= '1';                             -- accept address
        s_axi_rdata <= rd_mux;                          -- latch data for this addr
        s_axi_rresp <= "00";                            -- OKAY
        rvalid_i    <= '1';
      elsif rvalid_i = '1' and s_axi_rready = '1' then
        rvalid_i    <= '0';                             -- read data accepted
      end if;
    end if;
  end process;

  s_axi_arready <= arready_i;
  s_axi_rvalid  <= rvalid_i;

  --------------------------------------------------------------------
  -- AXI4-Lite write channel (no writable registers; just answer OKAY)
  --------------------------------------------------------------------
  process (s_axi_aclk, s_axi_aresetn) begin
    if s_axi_aresetn = '0' then
      awready_i   <= '0';
      wready_i    <= '0';
      bvalid_i    <= '0';
      s_axi_bresp <= "00";
    elsif rising_edge(s_axi_aclk) then
      awready_i <= '0';
      wready_i  <= '0';
      if s_axi_awvalid = '1' and s_axi_wvalid = '1' and bvalid_i = '0' and
         awready_i = '0' and wready_i = '0' then
        awready_i   <= '1';                             -- accept address + data
        wready_i    <= '1';
        bvalid_i    <= '1';                             -- OKAY response
        s_axi_bresp <= "00";
      elsif bvalid_i = '1' and s_axi_bready = '1' then
        bvalid_i    <= '0';
      end if;
    end if;
  end process;

  s_axi_awready <= awready_i;
  s_axi_wready  <= wready_i;
  s_axi_bvalid  <= bvalid_i;

end architecture rtl;
