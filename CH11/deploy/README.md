# Deploying CH11 to the board

Copies a built accelerator to an AUP-ZU3 running PYNQ and installs the
DisplayPort demo as a systemd service, so it survives logout and (optionally)
reboot.

```
deploy/
├── deploy.sh          run this from the host
├── ch11-dp.service    systemd unit, installed to /etc/systemd/system/
└── README.md
```

## Prerequisites

- SSH key auth to the board: `ssh-copy-id xilinx@192.168.3.1`
- The bitstream built for whichever implementation you want:

  | `--impl` | built by | lands in |
  |---|---|---|
  | `hls` | `HLS/build_hls.sh` then `HLS/build_bd.tcl` | `HLS/out/` |
  | `sv` | `build_bd_rtl.tcl -tclargs sv` | `out_sv/` |
  | `vhdl` | `build_bd_rtl.tcl -tclargs vhdl` | `out_vhdl/` |

## Use

```bash
cd CH11/deploy
./deploy.sh --impl hls --start            # copy, install, run now
./deploy.sh --impl sv  --start --enable   # ...and start at every boot
./deploy.sh --impl vhdl                   # copy + install, don't start
./deploy.sh --board 192.168.3.1 --user xilinx --interval 5
```

You are prompted once for the board's sudo password (PYNQ's default is
`xilinx`). Nothing stores it — not this repo, not the board.

Each implementation is copied to its own subdirectory, so all three can sit on
the board at once:

```
/home/xilinx/ch11_hil/
├── hls/  sv/  vhdl/        image_filter.bit + .hwh
├── dp_display.py
├── hil_test.py
└── test.jpg
```

## Running it

```bash
sudo systemctl start   ch11-dp     # run
sudo systemctl stop    ch11-dp     # stop, release the monitor
sudo systemctl enable  ch11-dp     # start at boot
journalctl -u ch11-dp -f           # watch the frame log
```

### Switching implementations without redeploying

The unit reads its configuration from `/etc/default/ch11-dp`, so pointing it at
a different build is an edit and a restart:

```bash
sudo sed -i 's|^CH11_BITSTREAM=.*|CH11_BITSTREAM=/home/xilinx/ch11_hil/sv/image_filter.bit|' \
    /etc/default/ch11-dp
sudo systemctl restart ch11-dp
```

You can see which one is loaded in the frame log: HLS runs the PL stage in
~11.24 ms, the RTL versions in ~11.37 ms.

## Things this gets right, and why they matter

Each of these cost real debugging time; they are the reason this is a script
rather than a paragraph of instructions.

**`Environment=XILINX_XRT=/usr`.** `/etc/profile.d/xrt_setup.sh` sets this, and
systemd does not source profile scripts — neither does a non-interactive
`ssh host cmd`. Without it PYNQ raises `RuntimeError: No Devices Found` and the
unit dies at startup, which looks exactly like a broken overlay.

**Root.** Programming the PL and opening `/dev/dri` both need it. As the
`xilinx` user you get the same `No Devices Found`. Jupyter hides this because it
already runs as root.

**SIGTERM is handled.** `systemctl stop` sends SIGTERM, whose default
disposition kills the interpreter outright — no cleanup, so the DisplayPort is
never released and the CMA buffers leak. `dp_display.py` turns it into an
exception so the normal shutdown path runs; you should see `stopping on SIGTERM`
then `DisplayPort released` in the journal, and the stop should take about a
second rather than hitting `TimeoutStopSec`.

**A start-limit, not an infinite restart loop.** `Restart=on-failure` with
`StartLimitBurst=3` means a board that boots with no monitor attached gives up
instead of respawning forever. `dp_display.py` also checks
`/sys/class/drm/card0-DP-1/status` up front and exits with a clear message.

**Checksums, not timestamps.** `deploy.sh` verifies the copied bitstream by
md5. The board has no RTC — its clock is not even monotonic across reboots, and
has been observed reading year 2105 — so file mtimes are worthless for telling
versions apart. For the same reason, read the journal with
`journalctl _PID=$(systemctl show -p MainPID --value ch11-dp)`: filtering by
unit can surface a *previous* boot's lines as the newest, because they sort
later by timestamp.

**Systemd, not `nohup`.** Backgrounding with `nohup` or `setsid` under `sudo`
does not survive the SSH session closing here — the process stays in the
session's tree and dies with the pty. A unit is spawned by PID 1 and has no such
ancestry.
