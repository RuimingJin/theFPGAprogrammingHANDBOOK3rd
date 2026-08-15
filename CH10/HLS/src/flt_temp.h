// ============================================================================
//  flt_temp.h
//
//  HLS implementation of the flt_temp floating-point temperature filter
//  (Chapter 10) -- the high-level-synthesis counterpart of flt_temp.sv.
//
//  The RTL flt_temp.sv computes a floating-point moving average and a Celsius->
//  Fahrenheit conversion, but it does NOT contain any arithmetic itself: every
//  add/subtract, multiply and fused-multiply-add is streamed out to a separate
//  Xilinx "floating_point" IP core (fp_addsub, fp_mult, fp_fused_mult_add) over
//  a fistful of AXI4-Stream ports, and the results are streamed back.  That is
//  why the RTL entity has ~30 addsub_*/mult_*/fused_* ports and a hand-built
//  little sequencer (convert_pipe) to shuttle operands through those cores.
//
//  Here the floating-point units are INTERNAL: the body just writes the math in
//  plain `float`, and Vitis HLS infers the adders, the multiplier and the FMA
//  (mapped onto DSP slices) inside this one component.  The external-IP ports
//  and the convert_pipe sequencer disappear entirely; what remains is one
//  streaming sample in, two streaming results out.
//
//  Ports (all bare AXI4-Stream, TDATA/TVALID/TREADY, 32-bit float):
//    fix_temp : temperature sample in  (degC as float; from the fixed_to_float IP)
//    fp_temp  : filtered temperature   (degC, the moving average)      -> float_to_fixed
//    fh_temp  : filtered temperature   (degF = avg*9/5 + 32)           -> float_to_fixed1
//
//  Filtering (identical to the RTL): a cumulative average over the first
//  SMOOTHING samples, then a true SMOOTHING-deep sliding window.  The divide by
//  the sample count is done as a multiply by a 1/n reciprocal (mirroring the
//  RTL's `divide[]` LUT), so no FP divider is instantiated.
// ============================================================================
#ifndef FLT_TEMP_H
#define FLT_TEMP_H

#include <hls_stream.h>
#include <ap_int.h>

// 32-bit IEEE-754 single precision, carried as the AXI4-Stream TDATA payload
// (same 32-bit float the RTL exchanged with the floating_point IP cores).
typedef float data_t;

// Moving-average depth (RTL parameter SMOOTHING).
#define SMOOTHING 16

// Fahrenheit conversion constants (RTL: nine_fifths = 0x3fe66666, thirty_two =
// 0x42000000, applied by the fused-multiply-add core).
const data_t NINE_FIFTHS = 9.0f / 5.0f;   // 1.8
const data_t THIRTY_TWO  = 32.0f;

void flt_temp(hls::stream<data_t> &fix_temp,   // sample in  (degC, float)
              hls::stream<data_t> &fp_temp,    // filtered   (degC, float)
              hls::stream<data_t> &fh_temp);   // filtered   (degF, float)

#endif // FLT_TEMP_H
