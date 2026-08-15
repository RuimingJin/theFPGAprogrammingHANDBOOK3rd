-- flt_temp_wrapper.vhd
-- ----------------------------------------------------------------------------
--  Thin structural wrapper around flt_temp.
--
--  VHDL port of flt_temp_wrapper.v (see that file for the full commentary).
-- ----------------------------------------------------------------------------
-- Author : Frank Bruno

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity flt_temp_wrapper is
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
end entity flt_temp_wrapper;

architecture rtl of flt_temp_wrapper is
begin

  flt_temp : entity work.flt_temp
    generic map (
      SMOOTHING    => 16,
      NUM_SEGMENTS => 8
    )
    port map (
      clk              => clk,
      rst_n            => rst_n,

      -- data from fix to float
      fix_temp_tvalid  => fix_temp_tvalid,
      fix_temp_tdata   => fix_temp_tdata,

      -- Addsub interface
      addsub_a_tvalid  => addsub_a_tvalid,
      addsub_a_tdata   => addsub_a_tdata,
      addsub_b_tvalid  => addsub_b_tvalid,
      addsub_b_tdata   => addsub_b_tdata,
      addsub_op_tvalid => addsub_op_tvalid,
      addsub_op_tdata  => addsub_op_tdata,
      addsub_tvalid    => addsub_tvalid,
      addsub_tdata     => addsub_tdata,

      -- Multiplier interface
      mult_a_tvalid    => mult_a_tvalid,
      mult_a_tdata     => mult_a_tdata,
      mult_b_tvalid    => mult_b_tvalid,
      mult_b_tdata     => mult_b_tdata,
      mult_tvalid      => mult_tvalid,
      mult_tdata       => mult_tdata,

      -- Fused Multiplier-Add interface
      fused_a_tvalid   => fused_a_tvalid,
      fused_a_tdata    => fused_a_tdata,
      fused_b_tvalid   => fused_b_tvalid,
      fused_b_tdata    => fused_b_tdata,
      fused_c_tvalid   => fused_c_tvalid,
      fused_c_tdata    => fused_c_tdata,
      fused_tvalid     => fused_tvalid,
      fused_tdata      => fused_tdata,

      -- Float to fixed
      fp_temp_tvalid   => fp_temp_tvalid,
      fp_temp_tdata    => fp_temp_tdata,
      fh_temp_tvalid   => fh_temp_tvalid,
      fh_temp_tdata    => fh_temp_tdata
    );

end architecture rtl;
