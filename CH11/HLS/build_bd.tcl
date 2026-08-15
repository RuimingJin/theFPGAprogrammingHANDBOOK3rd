# Vivado block design for the ZU3EG HLS image filter.
#   Run with:  vivado -mode batch -source build_bd.tcl
#
# Produces  ./out/image_filter.bit  and  ./out/image_filter.hwh
# which are the two files PYNQ needs (same basename, same directory).

# ---------------------------------------------------------------------------
# EDIT THESE FOR YOUR BOARD
# ---------------------------------------------------------------------------
set part_name  {xczu3eg-sfvc784-2-e}

# The board preset configures the PS DDR controller. Without it the PS is left
# at defaults, which will not match the board's memory -- the resulting image
# does not boot Linux reliably. The AUP-ZU3 comes in 4GB and 8GB variants with
# different DDR settings; pick the one matching your board.
#
#   realdigital.org:aup-zu3-8gb:part0:1.0
#   realdigital.org:aup-zu3-4gb:part0:1.0
set board_part {realdigital.org:aup-zu3-8gb:part0:1.0}

# Board files are not installed into Vivado, so point at the repo checkout.
# Adjust if yours lives elsewhere; `get_board_parts *zu3*` in the Vivado Tcl
# console confirms what is visible once this path is set.
set board_repo [file normalize [file join [file dirname [info script]] \
                    .. .. .. aup-zu3-board-files]]

# Where the unified Vitis flow drops the packaged IP. This is
# <work_dir>/hls/impl/ip -- the old vitis_hls path
# (image_filter_prj/sol1/impl/ip) no longer exists.
set hls_ip_repo [file normalize [file join [file dirname [info script]] \
                     image_filter hls impl ip]]
# ---------------------------------------------------------------------------

set proj_name  image_filter
set bd_name    design_1

file mkdir ./out
create_project $proj_name ./vivado_proj -part $part_name -force

# board_part_repo_paths has to be set before board_part, or the preset is not
# in the catalog yet when we ask for it.
if {$board_part ne ""} {
    if {![file isdirectory $board_repo]} {
        error "Board files not found at $board_repo -- clone the aup-zu3-board-files\
               repo there, or clear board_part to build without a preset."
    }
    set_property board_part_repo_paths [list $board_repo] [current_project]
    set_property board_part $board_part [current_project]
    puts "Using board preset: $board_part (from $board_repo)"
}

if {![file isdirectory $hls_ip_repo]} {
    error "HLS IP not found at $hls_ip_repo -- run './build_hls.sh' first."
}
set_property ip_repo_paths $hls_ip_repo [current_project]
update_ip_catalog -rebuild

create_bd_design $bd_name

# --- Processing System -------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps_e_0
if {$board_part ne ""} {
    apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
        -config {apply_board_preset "1"} [get_bd_cells zynq_ultra_ps_e_0]
}

# HPM0_LPD  -> 32-bit master, drives the HLS control (s_axilite) port
# S_AXI_HP0/HP1_FPD -> slaves for the two HLS m_axi bundles (gmem0/gmem1)
# PL0 clock at 200 MHz to match the 5 ns HLS target
set_property -dict [list \
    CONFIG.PSU__USE__M_AXI_GP0 {0} \
    CONFIG.PSU__USE__M_AXI_GP1 {0} \
    CONFIG.PSU__USE__M_AXI_GP2 {1} \
    CONFIG.PSU__MAXIGP2__DATA_WIDTH {32} \
    CONFIG.PSU__USE__S_AXI_GP2 {1} \
    CONFIG.PSU__SAXIGP2__DATA_WIDTH {128} \
    CONFIG.PSU__USE__S_AXI_GP3 {1} \
    CONFIG.PSU__SAXIGP3__DATA_WIDTH {128} \
    CONFIG.PSU__FPGA_PL0_ENABLE {1} \
    CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ {200} \
] [get_bd_cells zynq_ultra_ps_e_0]

# --- HLS accelerator ---------------------------------------------------------
set hls_ip [create_bd_cell -type ip -vlnv aup:hls:image_filter:1.0 image_filter_0]

# --- Interconnect / reset (let automation do the plumbing) -------------------
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { \
    Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
    Master {/zynq_ultra_ps_e_0/M_AXI_HPM0_LPD} Slave {/image_filter_0/s_axi_control} \
    intc_ip {New AXI SmartConnect} master_apm {0} } \
    [get_bd_intf_pins image_filter_0/s_axi_control]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { \
    Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
    Master {/image_filter_0/m_axi_gmem0} Slave {/zynq_ultra_ps_e_0/S_AXI_HP0_FPD} \
    intc_ip {New AXI SmartConnect} master_apm {0} } \
    [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]

apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { \
    Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} \
    Master {/image_filter_0/m_axi_gmem1} Slave {/zynq_ultra_ps_e_0/S_AXI_HP1_FPD} \
    intc_ip {New AXI SmartConnect} master_apm {0} } \
    [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP1_FPD]

assign_bd_address
validate_bd_design
save_bd_design

# --- Implementation ----------------------------------------------------------
make_wrapper -files [get_files ./vivado_proj/${proj_name}.srcs/sources_1/bd/${bd_name}/${bd_name}.bd] -top
add_files -norecurse ./vivado_proj/${proj_name}.gen/sources_1/bd/${bd_name}/hdl/${bd_name}_wrapper.v
set_property top ${bd_name}_wrapper [current_fileset]
update_compile_order -fileset sources_1

launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1

# --- Collect PYNQ artifacts --------------------------------------------------
set bit_src [glob -nocomplain ./vivado_proj/${proj_name}.runs/impl_1/*_wrapper.bit]
set hwh_src ./vivado_proj/${proj_name}.gen/sources_1/bd/${bd_name}/hw_handoff/${bd_name}.hwh

if {[llength $bit_src] == 0 || ![file exists $hwh_src]} {
    error "Build finished but artifacts are missing -- check impl_1 for errors."
}

file copy -force [lindex $bit_src 0] ./out/image_filter.bit
file copy -force $hwh_src            ./out/image_filter.hwh

puts "=========================================="
puts " Copy these to the board alongside the notebook:"
puts "   out/image_filter.bit"
puts "   out/image_filter.hwh"
puts "=========================================="
exit
