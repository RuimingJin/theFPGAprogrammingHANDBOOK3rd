-- adt7420_axil_wrapper.vhd
-- ----------------------------------------------------------------------------
--  Thin structural wrapper that instantiates adt7420_axil.
--
--  VHDL port of adt7420_axil_wrapper.v (see that file for the full commentary).
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

entity adt7420_axil_wrapper is
  generic (
    CLK_FREQ_HZ        : integer := 100_000_000;          -- = AXI clock
    I2C_FREQ_HZ        : integer := 100_000;
    SAMPLE_HZ          : integer := 4;
    DEV_ADDR           : std_logic_vector(6 downto 0) := "1001011"; -- 7'h4B
    AVG_N              : integer := 16;
    C_S_AXI_ADDR_WIDTH : integer := 16
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
    temp_inst       : out std_logic_vector(15 downto 0);
    fx_inst_valid   : in  std_logic;
    fx_inst         : in  std_logic_vector(15 downto 0);
    fh_inst_valid   : in  std_logic;
    fh_inst         : in  std_logic_vector(15 downto 0);

    -- I2C open-drain bus (to external IOBUFs)
    scl_i : in  std_logic;
    scl_o : out std_logic;
    scl_t : out std_logic;
    sda_i : in  std_logic;
    sda_o : out std_logic;
    sda_t : out std_logic
  );
end entity adt7420_axil_wrapper;

architecture rtl of adt7420_axil_wrapper is

  component adt7420_axil is
    generic (
      CLK_FREQ_HZ        : integer := 100_000_000;
      I2C_FREQ_HZ        : integer := 100_000;
      SAMPLE_HZ          : integer := 4;
      DEV_ADDR           : std_logic_vector(6 downto 0) := "1001011";
      AVG_N              : integer := 16;
      C_S_AXI_ADDR_WIDTH : integer := 4
    );
    port (
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

      scl_i : in  std_logic;
      scl_o : out std_logic;
      scl_t : out std_logic;
      sda_i : in  std_logic;
      sda_o : out std_logic;
      sda_t : out std_logic
    );
  end component;

  signal temp_inst_s : signed(15 downto 0);

begin

  adt7420_axil_inst : adt7420_axil
    generic map (
      CLK_FREQ_HZ        => CLK_FREQ_HZ,
      I2C_FREQ_HZ        => I2C_FREQ_HZ,
      SAMPLE_HZ          => SAMPLE_HZ,
      DEV_ADDR           => DEV_ADDR,
      AVG_N              => AVG_N,
      C_S_AXI_ADDR_WIDTH => C_S_AXI_ADDR_WIDTH
    )
    port map (
      -- AXI4-Lite slave
      s_axi_aclk    => s_axi_aclk,
      s_axi_aresetn => s_axi_aresetn,

      s_axi_awaddr  => s_axi_awaddr,
      s_axi_awvalid => s_axi_awvalid,
      s_axi_awready => s_axi_awready,
      s_axi_wdata   => s_axi_wdata,
      s_axi_wstrb   => s_axi_wstrb,
      s_axi_wvalid  => s_axi_wvalid,
      s_axi_wready  => s_axi_wready,
      s_axi_bresp   => s_axi_bresp,
      s_axi_bvalid  => s_axi_bvalid,
      s_axi_bready  => s_axi_bready,

      s_axi_araddr  => s_axi_araddr,
      s_axi_arvalid => s_axi_arvalid,
      s_axi_arready => s_axi_arready,
      s_axi_rdata   => s_axi_rdata,
      s_axi_rresp   => s_axi_rresp,
      s_axi_rvalid  => s_axi_rvalid,
      s_axi_rready  => s_axi_rready,

      temp_inst_valid => temp_inst_valid,
      temp_inst       => temp_inst_s,
      fx_inst_valid   => fx_inst_valid,
      fx_inst         => signed(fx_inst),
      fh_inst_valid   => fh_inst_valid,
      fh_inst         => signed(fh_inst),

      -- I2C open-drain bus (to external IOBUFs)
      scl_i => scl_i,
      scl_o => scl_o,
      scl_t => scl_t,
      sda_i => sda_i,
      sda_o => sda_o,
      sda_t => sda_t
    );

  temp_inst <= std_logic_vector(temp_inst_s);

end architecture rtl;
