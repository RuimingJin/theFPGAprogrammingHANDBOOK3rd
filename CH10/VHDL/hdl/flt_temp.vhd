-- flt_temp.vhd
-- ----------------------------------------------------------------------------
--  Fixed-to-float temperature smoothing / Celsius-Fahrenheit conversion engine.
--
--  VHDL port of flt_temp.sv (see that file for the full commentary).
--
--  Note on the struct/union:
--    The SystemVerilog source declares a packed struct float_t and a packed
--    union float_u (fp : float_t / raw : logic[31:0]).  In this design every
--    float_u object is only ever read or written as the whole 32 bits (via
--    ".raw" or a whole ".fp" assignment), so the union collapses to a plain
--    std_logic_vector(31 downto 0) here -- no record type is required.  The
--    single commented-out ".exponent" line stays commented.
-- ----------------------------------------------------------------------------
-- Author : Frank Bruno

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library xpm;
use xpm.vcomponents.all;

entity flt_temp is
  generic (
    SMOOTHING    : integer := 16;
    NUM_SEGMENTS : integer := 8
  );
  port (
    clk   : in  std_logic;                       -- 100Mhz clock
    rst_n : in  std_logic;                       -- Reset - active Low

    -- data from fix to float
    fix_temp_tvalid : in  std_logic;
    fix_temp_tdata  : in  std_logic_vector(31 downto 0);

    -- Addsub interface
    addsub_a_tvalid  : out std_logic;
    addsub_a_tdata   : out std_logic_vector(31 downto 0);
    addsub_b_tvalid  : out std_logic;
    addsub_b_tdata   : out std_logic_vector(31 downto 0);
    addsub_op_tvalid : out std_logic;
    addsub_op_tdata  : out std_logic_vector(7 downto 0);
    addsub_tvalid    : in  std_logic;
    addsub_tdata     : in  std_logic_vector(31 downto 0);

    -- Multiplier interface
    mult_a_tvalid : out std_logic;
    mult_a_tdata  : out std_logic_vector(31 downto 0);
    mult_b_tvalid : out std_logic;
    mult_b_tdata  : out std_logic_vector(31 downto 0);
    mult_tvalid   : in  std_logic;
    mult_tdata    : in  std_logic_vector(31 downto 0);

    -- Fused Multiplier-Add interface
    fused_a_tvalid : out std_logic;
    fused_a_tdata  : out std_logic_vector(31 downto 0);
    fused_b_tvalid : out std_logic;
    fused_b_tdata  : out std_logic_vector(31 downto 0);
    fused_c_tvalid : out std_logic;
    fused_c_tdata  : out std_logic_vector(31 downto 0);
    fused_tvalid   : in  std_logic;
    fused_tdata    : in  std_logic_vector(31 downto 0);

    -- Float to fixed
    fp_temp_tvalid : out std_logic;
    fp_temp_tdata  : out std_logic_vector(31 downto 0);
    fh_temp_tvalid : out std_logic;
    fh_temp_tdata  : out std_logic_vector(31 downto 0)
  );
end entity flt_temp;

architecture rtl of flt_temp is

  -- Width of the smooth_count counter: [$clog2(SMOOTHING):0]
  constant SMOOTH_CW : integer := integer(ceil(log2(real(SMOOTHING))));

  -- Array of 32-bit floating point words (used for divide LUT, mult_in,
  -- addsub_in).  Represents the collapsed float_u as a plain 32-bit vector.
  type slv32_array is array (natural range <>) of std_logic_vector(31 downto 0);

  signal smooth_data    : std_logic_vector(15 downto 0);
  signal smooth_convert : std_logic;
  signal sample_count   : unsigned(4 downto 0) := (others => '0');

  -- Declared in the source but only nine_fifths/thirty_two below are used.
  -- (Renamed from NINE_FIFTHS: VHDL is case-insensitive so it would clash with
  --  the 32-bit nine_fifths constant below, which SystemVerilog kept distinct.)
  constant NINE_FIFTHS_17 : std_logic_vector(16 downto 0) := "11100110011001100";

  signal smooth_count : unsigned(SMOOTH_CW downto 0) := (others => '0');
  signal dout         : std_logic_vector(31 downto 0);
  signal rden         : std_logic := '0';
  signal accumulator  : std_logic_vector(31 downto 0) := (others => '0'); -- 0.0 FP
  signal result_data  : std_logic_vector(31 downto 0);
  signal result_valid : std_logic;
  signal temperature  : std_logic_vector(31 downto 0);
  signal temperature_valid : std_logic;
  signal f_valid      : std_logic;
  signal convert_pipe : std_logic_vector(2 downto 0);

  constant divide : slv32_array(0 to 16) := (
    x"3F800000", -- 1
    x"3F000000", -- 1/2
    x"3eaaaaab", -- 1/3
    x"3e800000", -- 1/4
    x"3e4ccccd", -- 1/5
    x"3e2aaaab", -- 1/6
    x"3e124924", -- 1/7
    x"3e000000", -- 1/8
    x"3de38e39", -- 1/9
    x"3dcccccd", -- 1/10
    x"3dba2e8c", -- 1/11
    x"3daaaaab", -- 1/12
    x"3d9d89d9", -- 1/13
    x"3d924925", -- 1/14
    x"3d888888", -- 1/15
    x"3d800000", -- 1/16
    x"3d800000"  -- 1/16
  );

  constant nine_fifths : std_logic_vector(31 downto 0) := x"3fe66666"; -- 9/5 in FP
  constant thirty_two  : std_logic_vector(31 downto 0) := x"42000000"; -- Floating point

  signal mult_in       : slv32_array(0 to 1);
  signal mult_in_valid : std_logic;

  signal s_axis_a_tready : std_logic;
  signal accum_valid     : std_logic;
  signal addsub_in       : slv32_array(0 to 1);

begin

  addsub_a_tvalid  <= convert_pipe(0);
  addsub_a_tdata   <= addsub_in(0);
  addsub_b_tvalid  <= convert_pipe(0);
  addsub_b_tdata   <= addsub_in(1);
  addsub_op_tvalid <= convert_pipe(0);

  mult_a_tvalid <= mult_in_valid;
  mult_a_tdata  <= mult_in(0);
  mult_b_tvalid <= mult_in_valid;
  mult_b_tdata  <= mult_in(1);
  result_valid  <= mult_tvalid;
  result_data   <= mult_tdata;

  fp_temp_tvalid <= temperature_valid;
  fp_temp_tdata  <= temperature;
  fh_temp_tvalid <= fused_tvalid;
  fh_temp_tdata  <= fused_tdata;

  fused_a_tvalid <= temperature_valid; -- mult_tvalid; -- result_valid;
  fused_a_tdata  <= temperature;       -- mult_tdata; -- result_data;
  fused_b_tvalid <= temperature_valid; -- mult_tvalid; -- result_valid;
  fused_b_tdata  <= nine_fifths;
  fused_c_tvalid <= temperature_valid; -- mult_tvalid; -- result_valid;
  fused_c_tdata  <= thirty_two;

  process (clk) begin
    if rising_edge(clk) then
      rden              <= '0';
      convert_pipe      <= (others => '0');
      temperature_valid <= '0';
      f_valid           <= '0';
      mult_in_valid     <= '0';

      if fix_temp_tvalid = '1' then
        -- First stage, temperature data converted to float, add to accumulator
        addsub_op_tdata <= (others => '0'); -- add
        convert_pipe(0) <= '1';
        addsub_in(0)    <= accumulator;
        addsub_in(1)    <= fix_temp_tdata;
        -- Pop the oldest sample from the window, but only once the FIFO actually
        -- holds SMOOTHING entries.  For the first SMOOTHING samples we only write
        -- (the running sum is a cumulative average); from then on each new sample
        -- is paired with a read of the value SMOOTHING samples ago, giving a true
        -- moving average.  Issuing the read here (rather than after the add) also
        -- gives the registered FIFO dout time to settle before the subtract stage.
        if smooth_count = 16 then
          rden <= '1';
        else
          rden <= '0';
        end if;
      end if;

      if addsub_tvalid = '1' then
        accumulator <= addsub_tdata;
        if addsub_op_tdata = x"00" then
          convert_pipe(1) <= '1';
        else
          convert_pipe(2) <= '1';
        end if;
      end if;

      if convert_pipe(1) = '1' then
        -- We just performed an add, so now perform a subtract
        addsub_op_tdata <= x"01"; -- subtract
        convert_pipe(0) <= '1';
        addsub_in(0)    <= accumulator;
        if smooth_count = 16 then
          addsub_in(1) <= dout;
        else
          addsub_in(1) <= (others => '0');
        end if;
      end if;

      if convert_pipe(2) = '1' then
        -- Drive data into multiplier
        if sample_count(4) = '0' then
          sample_count <= sample_count + 1;
        end if;
        if smooth_count /= 16 then
          smooth_count <= smooth_count + 1;
        end if;
        mult_in(0)    <= accumulator;
        mult_in(1)    <= divide(to_integer(sample_count));
        mult_in_valid <= '1';
      end if;

      if result_valid = '1' then
        temperature <= result_data;
        -- temperature.fp.exponent <= result_data.fp.exponent - 4;
        temperature_valid <= '1';
      end if;

      -- Fahrenheit conversion
      if fused_tvalid = '1' then
        temperature <= fused_tdata;
        f_valid     <= '1';
      end if;

      if rst_n = '0' then
        rden         <= '0';
        smooth_count <= (others => '0');
        accumulator  <= (others => '0');
        sample_count <= (others => '0');
      end if;
    end if;
  end process;

  u_xpm_fifo_sync : xpm_fifo_sync
    generic map (
      FIFO_WRITE_DEPTH => SMOOTHING * 2,
      WRITE_DATA_WIDTH => 32              -- $bits(fix_temp_tdata)
    )
    port map (
      sleep         => '0',
      rst           => (not rst_n),       -- flush the window on reset (active-high
                                          -- rst; hold long enough for wr_rst_busy)

      wr_clk        => clk,
      wr_en         => fix_temp_tvalid,
      din           => fix_temp_tdata,
      full          => open,
      prog_full     => open,
      wr_data_count => open,
      overflow      => open,
      wr_rst_busy   => open,
      almost_full   => open,
      wr_ack        => open,

      rd_en         => rden,
      dout          => dout,
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

end architecture rtl;
