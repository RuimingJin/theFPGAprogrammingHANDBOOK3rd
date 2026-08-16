#!/usr/bin/env bash
# Simulate the SystemVerilog image filter with Vivado xsim.
#
#   source /opt/Xilinx/2025.2/Vivado/settings64.sh
#   ./sim.sh
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
mkdir -p build && cd build

xvlog -sv -nolog \
    ../hdl/sync_fifo.sv \
    ../hdl/image_filter_ctrl.sv \
    ../hdl/image_filter_rd.sv \
    ../hdl/image_filter_wr.sv \
    ../hdl/image_filter_core.sv \
    ../hdl/image_filter.sv \
    ../tb/tb_image_filter.sv

# -debug typical keeps internal signals visible; the testbench reaches into the
# DUT for its completion wait and its state dump, and an optimised-away signal
# takes the xsim kernel down rather than erroring cleanly.
xelab -nolog -debug typical tb_image_filter -s tb_sim
xsim tb_sim -nolog -runall
