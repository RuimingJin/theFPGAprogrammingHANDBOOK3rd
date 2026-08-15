# ============================================================================
#  run_hls.tcl  --  build the flt_temp HLS core (Vitis unified flow)
#
#  Run from THIS directory (src/), so the relative source paths resolve and the
#  generated component folder lands here, matching the book's other HLS chapters:
#
#     vitis-run --mode hls --tcl run_hls.tcl
#
#  Produces one IP-catalog package, flt_temp, that drops in for the RTL flt_temp
#  plus its external fp_addsub / fp_mult / fp_fused_mult_add cores: the floating-
#  point units are synthesized INSIDE this component.
#
#  Stage control via environment variables (all optional):
#     RUN_CSIM=0    skip C simulation       (default 1)
#     RUN_COSIM=1   also run C/RTL co-sim    (default 0)
#     RUN_EXPORT=0  skip IP export           (default 1)
# ============================================================================

set PART {xczu3eg-sfvc784-2-e}
set CLK  100MHz

proc opt {name default} {
    return [expr {[info exists ::env($name)] ? $::env($name) : $default}]
}
set do_csim   [opt RUN_CSIM   1]
set do_cosim  [opt RUN_COSIM  0]
set do_export [opt RUN_EXPORT 1]

open_component -reset flt_temp -flow_target vivado
add_files flt_temp.cpp
add_files -tb test_bench.cpp
set_top flt_temp
set_part $PART
create_clock -period $CLK

if {$do_csim}   { csim_design }
csynth_design
if {$do_cosim}  { cosim_design }
if {$do_export} { export_design -format ip_catalog }
