#!/usr/bin/env python3
"""Show the CH11 image_filter output on the PS DisplayPort.

The Mali GPU is NOT involved. The ZynqMP DisplayPort controller (DPDMA + DP
subsystem) is a hardened block that scans out from DDR on its own; the Mali is
a renderer that would only ever be one possible producer of those pixels. Here
the producer is the PL accelerator, so the path is:

    JPEG -> A53 decode -> DDR -> [PL: gray/sobel/invert] -> DDR -> DPDMA -> DP

Works with any of the three CH11 implementations -- HLS, SystemVerilog or VHDL
-- because they share a register map. Pick one with --bitstream.

Run it directly:
    sudo env XILINX_XRT=/usr /usr/local/share/pynq-venv/bin/python3 \
        dp_display.py --hold

or install it as a service so it survives logout and reboot; see
CH11/deploy/README.md.

Root is required (programming the PL and opening the DRM device), and
XILINX_XRT must be set -- /etc/profile.d/xrt_setup.sh does not run for
non-interactive shells or for systemd units.
"""
import argparse
import os
import signal
import sys
import time

import numpy as np
from PIL import Image, ImageDraw
from pynq import Overlay, allocate
from pynq.lib.video import DisplayPort, PIXEL_RGB

MODES = [(0, "GRAYSCALE"), (1, "SOBEL EDGES"), (2, "INVERTED")]
DP_STATUS = "/sys/class/drm/card0-DP-1/status"


def parse_args():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("duration", nargs="?", type=float, default=30.0,
                   help="seconds to run (ignored with --hold; default 30)")
    p.add_argument("--hold", action="store_true",
                   help="run until stopped instead of for a fixed duration")
    p.add_argument("--bitstream", default="image_filter.bit",
                   help="overlay to load (default: image_filter.bit)")
    p.add_argument("--image", default="test.jpg",
                   help="source JPEG (default: test.jpg)")
    p.add_argument("--interval", type=float, default=3.0,
                   help="seconds to dwell on each mode (default 3)")
    p.add_argument("--width", type=int, default=1920)
    p.add_argument("--height", type=int, default=1080)
    return p.parse_args()


# --------------------------------------------------------------------------
# Clean shutdown. systemd stops a unit with SIGTERM, whose default disposition
# kills the interpreter outright -- no finally block, no dp.close(), so the
# DisplayPort is never released and the contiguous buffers are never freed.
# Turning the signal into an exception lets the normal cleanup path run.
# --------------------------------------------------------------------------
class Stop(Exception):
    pass


def _on_signal(signum, frame):
    raise Stop(signal.Signals(signum).name)


def main():
    args = parse_args()

    if os.geteuid() != 0:
        sys.exit("must run as root (needs the PL and /dev/dri) -- use sudo")

    # Fail early and clearly rather than deep inside pynq if nothing is plugged in.
    try:
        with open(DP_STATUS) as fh:
            status = fh.read().strip()
        if status != "connected":
            sys.exit(f"no monitor: {DP_STATUS} reads '{status}'")
    except FileNotFoundError:
        sys.exit(f"no DisplayPort connector found at {DP_STATUS}")

    for path in (args.bitstream, args.image):
        if not os.path.exists(path):
            sys.exit(f"missing file: {path}")

    signal.signal(signal.SIGTERM, _on_signal)
    signal.signal(signal.SIGINT, _on_signal)

    print(f"1. Overlay: {args.bitstream}")
    ol = Overlay(args.bitstream)
    filt = ol.image_filter_0

    dp = DisplayPort()
    wanted = [m for m in dp.modes
              if m.width == args.width and m.height == args.height]
    if not wanted:
        dp.close()
        sys.exit(f"monitor does not offer {args.width}x{args.height}; "
                 f"it offers: {sorted({(m.width, m.height) for m in dp.modes})}")
    mode = max(wanted, key=lambda m: m.fps)
    dp.configure(mode, PIXEL_RGB)
    W, H = mode.width, mode.height
    print(f"   DisplayPort {W}x{H} @ {mode.fps} Hz, RGB24")

    print(f"2. Canvas from {args.image}")
    img = Image.open(args.image).convert("RGBA")
    img.thumbnail((W, H), Image.LANCZOS)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    canvas.paste(img, ((W - img.width) // 2, (H - img.height) // 2))
    print(f"   {img.size} letterboxed into {W}x{H}")

    src_buf = allocate(shape=(H, W, 4), dtype=np.uint8)
    dst_buf = allocate(shape=(H, W, 4), dtype=np.uint8)
    src_buf[:] = np.array(canvas)
    src_buf.flush()

    def run(mode_id):
        rm = filt.register_map
        sp, dp_addr = src_buf.physical_address, dst_buf.physical_address
        rm.src_1 = sp & 0xFFFFFFFF
        rm.src_2 = (sp >> 32) & 0xFFFFFFFF
        rm.dst_1 = dp_addr & 0xFFFFFFFF
        rm.dst_2 = (dp_addr >> 32) & 0xFFFFFFFF
        rm.img_width = W
        rm.img_height = H
        rm.mode = mode_id
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
        d.text((16, 16), f"PL accelerator: {text}", fill=(0, 255, 128))
        return np.asarray(im)

    how_long = "until stopped" if args.hold else f"for {args.duration:.0f}s"
    print(f"3. Cycling modes {how_long}")

    frame = dp.newframe()
    t_end = time.time() + args.duration
    i = 0
    rc = 0
    try:
        while args.hold or time.time() < t_end:
            mid, name = MODES[i % len(MODES)]
            t_pl = run(mid)
            rgb = label(np.array(dst_buf)[:, :, :3], name)
            t0 = time.perf_counter()
            frame[:] = rgb
            dp.writeframe(frame)
            t_wr = time.perf_counter() - t0
            frame = dp.newframe()
            print(f"   {name:<12} PL {t_pl*1e3:6.2f} ms   "
                  f"copy+flip {t_wr*1e3:6.2f} ms   "
                  f"({1.0/(t_pl+t_wr):.1f} fps end-to-end)")
            i += 1
            time.sleep(args.interval)
    except Stop as why:
        print(f"\n   stopping on {why}")
    except KeyboardInterrupt:
        print("\n   interrupted")
    except Exception as exc:                       # noqa: BLE001
        print(f"\n   error: {exc}")
        rc = 1
    finally:
        src_buf.freebuffer()
        dst_buf.freebuffer()
        dp.close()
        print("4. DisplayPort released")
    return rc


if __name__ == "__main__":
    sys.exit(main())
