// ============================================================================
//  test_bench.cpp
//
//  Self-checking C test bench for the HLS flt_temp core.  Streams a sample
//  sequence through the DUT one sample per call (matching the free-running,
//  ap_ctrl_none IP) and compares each (degC, degF) pair against an independent
//  software reference of the same cumulative-then-sliding moving average.
//
//  Returns 0 on success (Vitis HLS treats a non-zero return as a csim failure).
// ============================================================================
#include "flt_temp.h"
#include <cstdio>
#include <cmath>

static const float TOL = 1e-2f;   // degC/degF tolerance (recip-multiply vs divide)

int main() {
    hls::stream<data_t> in("in"), oc("degC"), of("degF");

    // Stimulus: a warm-up plateau, a step, then a second plateau -- exercises
    // the cumulative phase, the window-full transition and the slide.
    const int NS = 48;
    float samples[NS];
    for (int i = 0; i < NS; i++)
        samples[i] = (i < 24) ? 25.0f : 30.0f;

    // Software reference (plain divide) of the identical algorithm.
    float win[SMOOTHING] = {0};
    int   widx = 0, count = 0;
    float sum = 0.0f;

    int errors = 0;
    for (int i = 0; i < NS; i++) {
        in.write(samples[i]);
        flt_temp(in, oc, of);
        float dc = oc.read();
        float df = of.read();

        float oldest = win[widx];
        if (count == SMOOTHING) sum -= oldest;
        sum += samples[i];
        win[widx] = samples[i];
        widx = (widx + 1) % SMOOTHING;
        if (count < SMOOTHING) count++;
        float ravg = sum / (float)count;
        float rf   = ravg * (9.0f / 5.0f) + 32.0f;

        if (std::fabs(dc - ravg) > TOL || std::fabs(df - rf) > TOL) {
            printf("  [%2d] in=%.2f  DUT(%.4f C, %.4f F)  REF(%.4f C, %.4f F)  MISMATCH\n",
                   i, samples[i], dc, df, ravg, rf);
            errors++;
        } else if (i < 3 || i == SMOOTHING || i == 24) {
            printf("  [%2d] in=%.2f  degC=%.4f  degF=%.4f  ok\n", i, samples[i], dc, df);
        }
    }

    if (errors == 0) {
        printf("TB_FLT_TEMP: PASS (%d samples)\n", NS);
        return 0;
    }
    printf("TB_FLT_TEMP: FAIL (%d mismatches)\n", errors);
    return 1;
}
