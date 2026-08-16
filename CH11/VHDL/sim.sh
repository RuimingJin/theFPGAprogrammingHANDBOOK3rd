#!/usr/bin/env bash
# Simulate the VHDL image filter with Vivado xsim.
#
# Mixed-language: the DUT is VHDL, the testbench is the same SystemVerilog one
# used for the SystemVerilog implementation. Reusing it verbatim is the point --
# identical stimulus and identical golden model, so a pass here means the two
# implementations agree with the HLS C simulation and with each other.
#
#   source /opt/Xilinx/2025.2/Vivado/settings64.sh
#   ./sim.sh
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
mkdir -p build && cd build

xvhdl -nolog \
    ../hdl/sync_fifo.vhd \
    ../hdl/image_filter_ctrl.vhd \
    ../hdl/image_filter_rd.vhd \
    ../hdl/image_filter_wr.vhd \
    ../hdl/image_filter_core.vhd \
    ../hdl/image_filter.vhd

xvlog -sv -nolog ../tb/tb_image_filter.sv

xelab -nolog -debug typical tb_image_filter -s tb_sim
xsim tb_sim -nolog -runall
