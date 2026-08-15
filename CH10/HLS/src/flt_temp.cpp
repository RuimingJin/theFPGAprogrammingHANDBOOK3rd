// ============================================================================
//  flt_temp.cpp
//
//  HLS floating-point temperature filter -- the internal-FP-units equivalent of
//  flt_temp.sv.  See flt_temp.h for the full RTL-to-HLS mapping.
//
//  Compare with the RTL: flt_temp.sv had to marshal every operand out to an
//  external fp_addsub / fp_mult / fp_fused_mult_add core and step the
//  convert_pipe state machine to collect the results.  The three statements
//  below (subtract-oldest, add-new, multiply-by-1/n, and the multiply-add for
//  Fahrenheit) are all Vitis HLS needs; it builds the floating-point adder,
//  multiplier and FMA internally.
// ============================================================================
#include "flt_temp.h"

void flt_temp(hls::stream<data_t> &fix_temp,
              hls::stream<data_t> &fp_temp,
              hls::stream<data_t> &fh_temp) {
    // Free-running streaming IP: no ap_ctrl handshake, one sample per call.
    // (The RTL was likewise self-clocked off tvalid, with no start/done.)
#pragma HLS INTERFACE axis port=fix_temp
#pragma HLS INTERFACE axis port=fp_temp
#pragma HLS INTERFACE axis port=fh_temp
#pragma HLS INTERFACE ap_ctrl_none port=return
    // No PIPELINE pragma on purpose.  Temperature samples arrive at only a few
    // Hz (SAMPLE_HZ), so throughput is irrelevant; what matters is closing
    // timing.  Left un-pipelined, HLS schedules the dependent floating-point
    // chain (subtract -> add -> multiply -> FMA, plus the `sum` recurrence)
    // across several clock cycles with registers between the FP units -- the
    // same thing the RTL did by spreading the ops over its convert_pipe stages.
    // Forcing II=1 instead would chain all of them combinationally (~66 ns) and
    // drop Fmax to ~15 MHz.

    // --- persistent window state (replaces the RTL's XPM sample FIFO) --------
    static data_t window[SMOOTHING];        // the last SMOOTHING samples
    static ap_uint<16> widx  = 0;           // circular write index
    static ap_uint<16> count = 0;           // fill level, saturates at SMOOTHING
    static data_t      sum   = 0.0f;        // running window sum (the accumulator)

    // Reciprocal LUT: recip[n] = 1/n, clamped at 1/SMOOTHING.  Multiplying by
    // this (rather than dividing) is exactly what the RTL's divide[] table did,
    // so HLS builds a multiplier, not an FP divider.  recip[0] is unused.
    static const data_t recip[SMOOTHING + 1] = {
        0.0f,
        1.0f / 1.0f,  1.0f / 2.0f,  1.0f / 3.0f,  1.0f / 4.0f,
        1.0f / 5.0f,  1.0f / 6.0f,  1.0f / 7.0f,  1.0f / 8.0f,
        1.0f / 9.0f,  1.0f / 10.0f, 1.0f / 11.0f, 1.0f / 12.0f,
        1.0f / 13.0f, 1.0f / 14.0f, 1.0f / 15.0f, 1.0f / 16.0f
    };

    // --- one sample --------------------------------------------------------
    data_t s      = fix_temp.read();
    data_t oldest = window[widx];

    // Once the window is full, drop the sample leaving the window (FP subtract),
    // giving a true sliding sum; during warm-up we only accumulate.
    if (count == SMOOTHING)
        sum = sum - oldest;
    sum = sum + s;                          // FP add (accumulate)

    window[widx] = s;
    widx = (widx == SMOOTHING - 1) ? ap_uint<16>(0) : ap_uint<16>(widx + 1);
    if (count < SMOOTHING)
        count = count + 1;

    // Divide-by-count as a multiply by 1/count (cumulative avg during warm-up,
    // /SMOOTHING once full), then Fahrenheit as a fused multiply-add.
    data_t avg  = sum * recip[count];       // FP multiply
    data_t degF = avg * NINE_FIFTHS + THIRTY_TWO;  // FP fused-multiply-add

    fp_temp.write(avg);
    fh_temp.write(degF);
}
