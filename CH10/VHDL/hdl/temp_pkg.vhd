-- temp_pkg.vhd
-- ------------------------------------
-- Package for the CH10 i2c_temp project
-- ------------------------------------
-- Author : Frank Bruno, Guy Eschemann
--
-- NOTE: This package is provided to satisfy the CH10 i2c_temp dependency.
--       The original SystemVerilog imports temp_pkg::* purely for the
--       bin_to_bcd() helper (double-dabble binary-to-BCD conversion).  The CH10
--       source tree does not contain a temp_pkg, so this VHDL package supplies:
--         * type array_t     - packed array of BCD nibbles (matches the
--                              counting_buttons_pkg/seven_segment convention)
--         * function bin_to_bcd - modelled on CH08 calculator_pkg's double-dabble
--
--       The element subtype is left UNCONSTRAINED (std_logic_vector, not
--       std_logic_vector(3 downto 0)) so that the "array_t(NUM_SEGMENTS-1
--       downto 0)(3 downto 0)" element-constrained notation used by
--       seven_segment and throughout i2c_temp remains legal.

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package temp_pkg is

  -- Packed array of std_logic_vector; element width is supplied at the point of
  -- use, e.g. array_t(NUM_SEGMENTS-1 downto 0)(3 downto 0).
  type array_t is array (natural range <>) of std_logic_vector;

  -- Number of BCD digits produced by bin_to_bcd (matches CH08 calculator_pkg).
  constant NUM_SEGMENTS : integer := 8;

  -- Binary to BCD (double-dabble).  Accepts an unconstrained std_logic_vector so
  -- the same function serves the 9-bit integer part and the 16-bit fraction
  -- table lookups.  Returns NUM_SEGMENTS BCD digits (low digits carry the
  -- result; callers slice as needed).
  function bin_to_bcd(bin_in : std_logic_vector) return array_t;

end package temp_pkg;

package body temp_pkg is

  function bin_to_bcd(bin_in : std_logic_vector) return array_t is
    constant LEN     : integer := bin_in'length;
    variable v       : std_logic_vector(LEN - 1 downto 0) := bin_in;
    variable shifted : std_logic_vector(NUM_SEGMENTS * 4 - 1 downto 0);
    variable digit   : unsigned(3 downto 0);
    variable bin2bcd : array_t(NUM_SEGMENTS - 1 downto 0)(3 downto 0);
  begin
    shifted := (others => '0');
    -- Process input MSB-first.  Before each shift, add 3 to any BCD column
    -- whose value is 5 or greater (the "dabble" step).
    for i in LEN - 1 downto 0 loop
      for j in 0 to NUM_SEGMENTS - 1 loop
        digit := unsigned(shifted(j * 4 + 3 downto j * 4));
        if digit > 4 then
          shifted(j * 4 + 3 downto j * 4) := std_logic_vector(digit + 3);
        end if;
      end loop;
      shifted := shifted(NUM_SEGMENTS * 4 - 2 downto 0) & v(i);
    end loop;
    for i in 0 to NUM_SEGMENTS - 1 loop
      bin2bcd(i) := shifted(4 * i + 3 downto 4 * i);
    end loop;
    return bin2bcd;
  end function bin_to_bcd;

end package body temp_pkg;
