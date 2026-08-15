-- adt7420_i2c_mod_wrapper.vhd
-- ----------------------------------------------------------------------------
--  Thin structural wrapper around adt7420_i2c_mod.
--
--  VHDL port of adt7420_i2c_mod_wrapper.v (see that file for the full
--  commentary).
--
--  Note: DEVICE_ID is the ASCII "TEMP" carried as the 32-bit value
--  x"54454D50" ('T','E','M','P'), matching adt7420_i2c_mod.
-- ----------------------------------------------------------------------------
-- Author : Frank Bruno

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity adt7420_i2c_mod_wrapper is
  generic (
    DEVICE_ID : std_logic_vector(31 downto 0) := x"54454D50"; -- ASCII "TEMP"
    SMOOTHING : integer := 16;
    INTERVAL  : integer := 1000000000;
    CLK_PER   : integer := 10
  );
  port (
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
end entity adt7420_i2c_mod_wrapper;

architecture rtl of adt7420_i2c_mod_wrapper is
begin

  adt7420_i2c_mod_inst : entity work.adt7420_i2c_mod
    generic map (
      DEVICE_ID => DEVICE_ID,
      SMOOTHING => SMOOTHING,
      INTERVAL  => INTERVAL,
      CLK_PER   => CLK_PER
    )
    port map (
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
      TMP_SCL_i     => TMP_SCL_i,
      TMP_SCL_o     => TMP_SCL_o,
      TMP_SCL_t     => TMP_SCL_t,
      TMP_SDA_i     => TMP_SDA_i,
      TMP_SDA_o     => TMP_SDA_o,
      TMP_SDA_t     => TMP_SDA_t,
      TMP_INT       => TMP_INT,
      TMP_CT        => TMP_CT,

      fix_temp_tvalid => fix_temp_tvalid,
      fix_temp_tdata  => fix_temp_tdata,

      flt_temp_tvalid => flt_temp_tvalid,
      flt_temp_tdata  => flt_temp_tdata
    );

end architecture rtl;
