#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# run_xsim.sh - analyze, elaborate and simulate the CH10 VHDL with Vivado xsim.
#
#   1. analyze every hdl/ source (VHDL-2008) plus the sim stubs/testbenches
#   2. elaboration smoke-test of every synthesizable top (binds xpm + sub-cells)
#   3. run the two self-checking testbenches and report PASS/FAIL
#
# Usage:  ./run_xsim.sh            (expects Vivado 2025.2; override with VIVADO=)
# ----------------------------------------------------------------------------
set -e

VIVADO="${VIVADO:-/opt/Xilinx/2025.2/Vivado}"
# shellcheck disable=SC1091
source "$VIVADO/settings64.sh"

cd "$(dirname "$0")"
HDL=../hdl
WORK=xsim.dir
rm -rf "$WORK" *.jou *.log *.pb *.wdb xelab.* xvhdl.* 2>/dev/null || true

echo "== [1/3] analyze =="
xvhdl --2008 \
  "$HDL/temp_pkg.vhd" \
  "$HDL/adt7420_temp_if.vhd" \
  "$HDL/adt7420_axil.vhd" \
  "$HDL/adt7420_axil_wrapper.vhd" \
  "$HDL/flt_temp.vhd" \
  "$HDL/flt_temp_wrapper.vhd" \
  "$HDL/adt7420_i2c_mod.vhd" \
  "$HDL/adt7420_i2c_mod_wrapper.vhd" \
  "$HDL/dht11_axi_lite.vhd" \
  "$HDL/dht11_axi_lite_wrapper.vhd" \
  seven_segment_stub.vhd \
  "$HDL/i2c_temp.vhd" \
  tb_moving_avg.vhd \
  tb_adt7420_axil.vhd

echo "== [2/3] elaborate every top (smoke test) =="
for top in adt7420_axil_wrapper dht11_axi_lite_wrapper flt_temp_wrapper \
           adt7420_i2c_mod_wrapper i2c_temp; do
  printf '   %-26s ' "$top"
  if xelab -L xpm "work.$top" -s "elab_$top" >/dev/null 2>&1; then
    echo "elaborates OK"
  else
    echo "ELABORATION FAILED"; exit 1
  fi
done

echo "== [3/3] run self-checking testbenches =="
rc=0
for tb in tb_moving_avg tb_adt7420_axil; do
  xelab -L xpm "work.$tb" -s "sim_$tb" >/dev/null 2>&1
  out=$(xsim "sim_$tb" -R 2>&1)
  if echo "$out" | grep -q "$(echo "$tb" | tr a-z A-Z | sed 's/TB_/TB_/'): PASS"; then
    echo "   $tb : PASS"
  elif echo "$out" | grep -qi ": PASS"; then
    echo "   $tb : $(echo "$out" | grep -i ': PASS' | tail -1 | sed 's/^.*: //')"
  else
    echo "   $tb : FAIL"; echo "$out" | grep -iE "Error|Failure|expected" | head; rc=1
  fi
done

echo "----"
[ $rc -eq 0 ] && echo "ALL PASS" || { echo "FAILURES ABOVE"; exit 1; }
