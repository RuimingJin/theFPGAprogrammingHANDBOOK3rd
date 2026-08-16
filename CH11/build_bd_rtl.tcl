# Vivado block design for the RTL image filter (SystemVerilog or VHDL).
#
#   vivado -mode batch -source build_bd_rtl.tcl -tclargs sv
#   vivado -mode batch -source build_bd_rtl.tcl -tclargs vhdl
#
# Same block design as HLS/build_bd.tcl -- PS, two SmartConnects, the filter on
# HP0/HP1 and HPM0_LPD -- but the accelerator is added as a module reference
# rather than a packaged IP, so no IP-XACT packaging step is needed. Vivado
# infers the AXI interfaces from the port names.
#
# Produces  ./out_<lang>/image_filter.bit  and  .hwh

set lang "sv"
if {[llength $argv] > 0} { set lang [lindex $argv 0] }

set script_dir [file dirname [file normalize [info script]]]
set part_name  {xczu3eg-sfvc784-2-e}
set board_part {realdigital.org:aup-zu3-8gb:part0:1.0}
set board_repo [file normalize [file join $script_dir .. .. aup-zu3-board-files]]

set proj_name  image_filter_$lang
set bd_name    design_1
set out_dir    $script_dir/out_$lang
set ip_repo    $script_dir/ip_repo_$lang

file mkdir $out_dir

# --- Phase 1: package the RTL as IP -----------------------------------------
# A module reference will not accept a SystemVerilog top file, so package the
# accelerator properly instead. ipx infers the AXI interfaces from the port
# names, which is why they follow the s_axi_*/m_axi_* convention.
file delete -force $ip_repo
file mkdir $ip_repo
create_project -in_memory -part $part_name pack_tmp
if {$lang eq "sv"} {
    add_files -norecurse [glob $script_dir/SystemVerilog/hdl/*.sv]
    set_property file_type SystemVerilog [get_files *.sv]
} else {
    add_files -norecurse [list \
        $script_dir/VHDL/hdl/sync_fifo.vhd \
        $script_dir/VHDL/hdl/image_filter_ctrl.vhd \
        $script_dir/VHDL/hdl/image_filter_rd.vhd \
        $script_dir/VHDL/hdl/image_filter_wr.vhd \
        $script_dir/VHDL/hdl/image_filter_core.vhd \
        $script_dir/VHDL/hdl/image_filter.vhd]
}
update_compile_order -fileset sources_1
set_property top image_filter [current_fileset]
ipx::package_project -root_dir $ip_repo -vendor aup -library rtl \
    -taxonomy /UserIP -import_files -force
set core [ipx::current_core]
set_property name image_filter $core
set_property version 1.0 $core
set_property display_name "RGBA Gray / Sobel Filter (RTL $lang)" $core
ipx::infer_bus_interfaces xilinx.com:interface:aximm_rtl:1.0 $core
ipx::associate_bus_interfaces -busif s_axi_control -clock ap_clk $core
ipx::associate_bus_interfaces -busif m_axi_gmem0   -clock ap_clk $core
ipx::associate_bus_interfaces -busif m_axi_gmem1   -clock ap_clk $core
# --- register map -----------------------------------------------------------
# ipx infers the AXI interfaces but NOT the register definitions, and without
# them PYNQ cannot build filt.register_map -- it raises "register_map only
# available if the .hwh is provided". Declare them explicitly so the offsets and
# names match the HLS build byte for byte.
set mm [ipx::get_memory_maps s_axi_control -of_objects $core]
if {$mm eq ""} {
    set mm [ipx::add_memory_map s_axi_control $core]
    set_property slave_memory_map_ref s_axi_control \
        [ipx::get_bus_interfaces s_axi_control -of_objects $core]
}
# Exactly ONE address block must remain. package_project auto-creates "reg0";
# leaving it alongside ours gives the interface two address blocks, which makes
# PYNQ key the IP as "image_filter_0/s_axi_control" instead of "image_filter_0"
# and ol.image_filter_0 then has no register map at all.
foreach ab [ipx::get_address_blocks -of_objects $mm] {
    ipx::remove_address_block [get_property name $ab] $mm
}
set blk [ipx::add_address_block Reg $mm]
set_property base_address  0            $blk
set_property range         65536        $blk
set_property width         32           $blk
set_property usage         register     $blk
set_property access        read-write   $blk

proc add_reg {blk name offset desc} {
    set r [ipx::add_register $name $blk]
    set_property address_offset $offset $r
    set_property size 32 $r
    set_property description $desc $r
    return $r
}
proc add_fld {reg name bitoff bitwidth desc} {
    set f [ipx::add_field $name $reg]
    set_property bit_offset $bitoff $f
    set_property bit_width $bitwidth $f
    set_property description $desc $f
    return $f
}

set ctrl [add_reg $blk CTRL 0x0 "Control signals"]
add_fld $ctrl AP_START     0 1 "ap_start"
add_fld $ctrl AP_DONE      1 1 "ap_done"
add_fld $ctrl AP_IDLE      2 1 "ap_idle"
add_fld $ctrl AP_READY     3 1 "ap_ready"
add_fld $ctrl AUTO_RESTART 7 1 "auto_restart"
add_fld $ctrl INTERRUPT    9 1 "interrupt"
add_reg $blk GIER       0x4  "Global Interrupt Enable Register"
add_reg $blk IP_IER     0x8  "IP Interrupt Enable Register"
add_reg $blk IP_ISR     0xC  "IP Interrupt Status Register"
add_reg $blk src_1      0x10 "src low"
add_reg $blk src_2      0x14 "src high"
add_reg $blk dst_1      0x1C "dst low"
add_reg $blk dst_2      0x20 "dst high"
add_reg $blk img_width  0x28 "image width in pixels"
add_reg $blk img_height 0x30 "image height in rows"
add_reg $blk mode       0x38 "0 gray, 1 sobel, 2 invert"

set_property core_revision 1 $core
ipx::create_xgui_files $core
ipx::update_checksums $core
ipx::save_core $core
close_project

# --- Phase 2: block design ---------------------------------------------------
create_project $proj_name $script_dir/vivado_$lang -part $part_name -force
set_property ip_repo_paths $ip_repo [current_project]
update_ip_catalog -rebuild

if {![file isdirectory $board_repo]} {
    error "Board files not found at $board_repo"
}
set_property board_part_repo_paths [list $board_repo] [current_project]
set_property board_part $board_part [current_project]

create_bd_design $bd_name

# --- Processing System -------------------------------------------------------
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e \
    -config {apply_board_preset "1"} [get_bd_cells zynq_ultra_ps_e_0]

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

# --- Accelerator -------------------------------------------------------------
create_bd_cell -type ip -vlnv aup:rtl:image_filter:1.0 image_filter_0

# --- Interconnect / reset ----------------------------------------------------
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
make_wrapper -files [get_files $script_dir/vivado_$lang/${proj_name}.srcs/sources_1/bd/${bd_name}/${bd_name}.bd] -top
add_files -norecurse $script_dir/vivado_$lang/${proj_name}.gen/sources_1/bd/${bd_name}/hdl/${bd_name}_wrapper.v
set_property top ${bd_name}_wrapper [current_fileset]
update_compile_order -fileset sources_1

launch_runs impl_1 -to_step write_bitstream -jobs 12
wait_on_run impl_1

set bit_src [glob -nocomplain $script_dir/vivado_$lang/${proj_name}.runs/impl_1/*_wrapper.bit]
set hwh_src $script_dir/vivado_$lang/${proj_name}.gen/sources_1/bd/${bd_name}/hw_handoff/${bd_name}.hwh

if {[llength $bit_src] == 0 || ![file exists $hwh_src]} {
    error "Build finished but artifacts are missing -- check impl_1"
}

file copy -force [lindex $bit_src 0] $out_dir/image_filter.bit
file copy -force $hwh_src            $out_dir/image_filter.hwh

puts "=========================================="
puts " RTL ($lang) artifacts:"
puts "   $out_dir/image_filter.bit"
puts "   $out_dir/image_filter.hwh"
puts "=========================================="
exit
