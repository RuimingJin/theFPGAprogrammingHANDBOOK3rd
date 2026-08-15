#!/usr/bin/env python3
"""Hardware-in-the-loop test for the CH11 image_filter accelerator.

Runs on the AUP-ZU3 under PYNQ. Uses a synthetic image identical to the C
testbench pattern so the hardware result can be checked against the same
golden model csim used -- no external JPEG required.
"""
import time, sys
import numpy as np
from pynq import Overlay, allocate

W, H = 640, 480
MODE_GRAY, MODE_SOBEL, MODE_INVERT = 0, 1, 2

print("=" * 60)
print("1. Loading overlay")
ol = Overlay("image_filter.bit")
filt = ol.image_filter_0

print("\n2. register_map  <-- this is what raised RecursionError before")
print(filt.register_map)

print("\n3. Building synthetic test image (%dx%d)" % (W, H))
r = (np.arange(W) * 255 // (W - 1)).astype(np.uint8)[None, :].repeat(H, 0)
g = (np.arange(H) * 255 // (H - 1)).astype(np.uint8)[:, None].repeat(W, 1)
b = ((np.arange(H)[:, None] + np.arange(W)[None, :]) * 255 // (W + H - 2)).astype(np.uint8)
img = np.dstack([r, g, b, np.full((H, W), 255, np.uint8)])
img[H//4+1:3*H//4, W//4+1:3*W//4, :3] = 240          # hard-edged bright square

src_buf = allocate(shape=(H, W, 4), dtype=np.uint8)
dst_buf = allocate(shape=(H, W, 4), dtype=np.uint8)
src_buf[:] = img
src_buf.flush()
print("   src phys 0x%012X   dst phys 0x%012X"
      % (src_buf.physical_address, dst_buf.physical_address))

def run(mode):
    rm = filt.register_map
    sp, dp = src_buf.physical_address, dst_buf.physical_address
    rm.src_1 = sp & 0xFFFFFFFF; rm.src_2 = (sp >> 32) & 0xFFFFFFFF
    rm.dst_1 = dp & 0xFFFFFFFF; rm.dst_2 = (dp >> 32) & 0xFFFFFFFF
    rm.img_width = W; rm.img_height = H; rm.mode = mode
    t0 = time.perf_counter()
    rm.CTRL.AP_START = 1
    n = 0
    while rm.CTRL.AP_DONE == 0:
        n += 1
        if n > 200_000_000:
            raise RuntimeError("AP_DONE never asserted (mode=%d)" % mode)
    t = time.perf_counter() - t0
    dst_buf.invalidate()
    return np.array(dst_buf), t

# golden model -- same arithmetic as tb_image_filter.cpp
def golden(rgba, mode):
    R = rgba[:, :, 0].astype(np.int32); G = rgba[:, :, 1].astype(np.int32)
    B = rgba[:, :, 2].astype(np.int32)
    gray = ((77 * R + 150 * G + 29 * B) >> 8).astype(np.int32)
    if mode == MODE_GRAY:
        o = gray
    elif mode == MODE_INVERT:
        o = 255 - gray
    else:
        o = np.zeros_like(gray); p = gray
        gx = (p[:-2, 2:] + 2*p[1:-1, 2:] + p[2:, 2:]) - (p[:-2, :-2] + 2*p[1:-1, :-2] + p[2:, :-2])
        gy = (p[2:, :-2] + 2*p[2:, 1:-1] + p[2:, 2:]) - (p[:-2, :-2] + 2*p[:-2, 1:-1] + p[:-2, 2:])
        o[1:-1, 1:-1] = np.clip(np.abs(gx) + np.abs(gy), 0, 255)
    o = o.astype(np.uint8)
    return np.dstack([o, o, o, np.full(o.shape, 255, np.uint8)])

print("\n4. Running all three modes against the golden model")
fail = 0
for mode, name in ((MODE_GRAY, "GRAY"), (MODE_SOBEL, "SOBEL"), (MODE_INVERT, "INVERT")):
    hw, t = run(mode)
    ref = golden(img, mode)
    diff = (hw != ref)
    nwrong = int(diff.any(axis=2).sum())
    ok = "PASS" if nwrong == 0 else "FAIL"
    if nwrong: fail += 1
    print("   [%-6s] %s  %6.2f ms  %6.1f Mpixel/s  wrong=%d/%d"
          % (name, ok, t*1e3, W*H/t/1e6, nwrong, W*H))

print("\n5. Re-running SOBEL 10x for a stable timing figure")
ts = [run(MODE_SOBEL)[1] for _ in range(10)]
print("   best %.2f ms  median %.2f ms  -> %.1f Mpixel/s (best)"
      % (min(ts)*1e3, sorted(ts)[5]*1e3, W*H/min(ts)/1e6))

t0 = time.perf_counter(); golden(img, MODE_SOBEL); t_sw = time.perf_counter() - t0
print("   NumPy Sobel on A53: %.2f ms  ->  PL is %.2fx faster" % (t_sw*1e3, t_sw/min(ts)))

src_buf.freebuffer(); dst_buf.freebuffer()
print("\n" + "=" * 60)
print("HIL RESULT:", "ALL MODES PASS" if fail == 0 else "%d MODE(S) FAILED" % fail)
sys.exit(1 if fail else 0)
