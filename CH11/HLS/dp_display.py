#!/usr/bin/env python3
"""Show the CH11 image_filter output on the PS DisplayPort.

The Mali GPU is NOT involved. The ZynqMP DisplayPort controller (DPDMA + DP
subsystem) is a hardened block that scans out from DDR on its own; the Mali is
a renderer that would only ever be one possible producer of those pixels. Here
the producer is the PL accelerator, so the path is:

    JPEG -> A53 decode -> DDR -> [PL: gray/sobel/invert] -> DDR -> DPDMA -> DP

Usage:
    sudo env XILINX_XRT=/usr python3 dp_display.py [seconds] [--hold]
"""
import sys, time
import numpy as np
from PIL import Image, ImageDraw
from pynq import Overlay, allocate
from pynq.lib.video import DisplayPort, PIXEL_RGB

DURATION = 30.0
HOLD = "--hold" in sys.argv
for a in sys.argv[1:]:
    if not a.startswith("-"):
        DURATION = float(a)

MODES = [(0, "GRAYSCALE"), (1, "SOBEL EDGES"), (2, "INVERTED")]

print("1. Overlay + DisplayPort")
ol = Overlay("image_filter.bit")
filt = ol.image_filter_0
dp = DisplayPort()
hd = [m for m in dp.modes if m.width == 1920 and m.height == 1080]
if not hd:
    sys.exit("No 1920x1080 mode offered by the monitor: %s" % dp.modes)
mode = max(hd, key=lambda m: m.fps)
dp.configure(mode, PIXEL_RGB)
W, H = mode.width, mode.height
print("   %dx%d @ %d Hz, RGB24" % (W, H, mode.fps))

print("2. Building the 1920x1080 canvas from test.jpg")
img = Image.open("test.jpg").convert("RGBA")
img.thumbnail((W, H), Image.LANCZOS)                 # fit, preserve aspect
canvas = Image.new("RGBA", (W, H), (0, 0, 0, 255))
canvas.paste(img, ((W - img.width) // 2, (H - img.height) // 2))
print("   source %s letterboxed into %dx%d" % (img.size, W, H))

src_buf = allocate(shape=(H, W, 4), dtype=np.uint8)
dst_buf = allocate(shape=(H, W, 4), dtype=np.uint8)
src_buf[:] = np.array(canvas)
src_buf.flush()

def run(mode_id):
    rm = filt.register_map
    sp, dp_ = src_buf.physical_address, dst_buf.physical_address
    rm.src_1 = sp & 0xFFFFFFFF;  rm.src_2 = (sp >> 32) & 0xFFFFFFFF
    rm.dst_1 = dp_ & 0xFFFFFFFF; rm.dst_2 = (dp_ >> 32) & 0xFFFFFFFF
    rm.img_width = W; rm.img_height = H; rm.mode = mode_id
    t0 = time.perf_counter()
    rm.CTRL.AP_START = 1
    while rm.CTRL.AP_DONE == 0:
        pass
    t = time.perf_counter() - t0
    dst_buf.invalidate()
    return t

def label(rgb, text):
    im = Image.fromarray(rgb)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, 470, 54], fill=(0, 0, 0))
    d.text((16, 16), "PL accelerator: %s" % text, fill=(0, 255, 128))
    return np.asarray(im)

print("3. Cycling modes on the monitor for %.0fs%s" % (DURATION, " (--hold: until Ctrl-C)" if HOLD else ""))
frame = dp.newframe()
t_end = time.time() + DURATION
i = 0
try:
    while HOLD or time.time() < t_end:
        mid, name = MODES[i % len(MODES)]
        t_pl = run(mid)
        rgb = label(np.array(dst_buf)[:, :, :3], name)
        t0 = time.perf_counter()
        frame[:] = rgb
        dp.writeframe(frame)
        t_wr = time.perf_counter() - t0
        frame = dp.newframe()
        print("   %-12s PL %6.2f ms   copy+flip %6.2f ms   (%.1f fps end-to-end)"
              % (name, t_pl * 1e3, t_wr * 1e3, 1.0 / (t_pl + t_wr)))
        i += 1
        time.sleep(3.0)
except KeyboardInterrupt:
    print("\n   interrupted")

src_buf.freebuffer(); dst_buf.freebuffer()
dp.close()
print("4. DisplayPort released (console returns)")
