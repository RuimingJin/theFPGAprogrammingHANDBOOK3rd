#!/usr/bin/env bash
#
# Deploy the CH11 image filter to an AUP-ZU3 running PYNQ and install the
# DisplayPort demo as a systemd service.
#
#   ./deploy.sh                          # HLS build, copy + install, do not start
#   ./deploy.sh --impl sv --start        # SystemVerilog build, start it now
#   ./deploy.sh --impl vhdl --start --enable   # ...and start at boot
#   ./deploy.sh --board 192.168.3.1 --user xilinx
#
# You will be prompted for the board's sudo password once (PYNQ's default is
# "xilinx"). No credentials are stored here or on the board.
#
# Prerequisites: SSH key auth to the board (ssh-copy-id), and the bitstream for
# the chosen implementation already built:
#   HLS  -> CH11/HLS/out/            (HLS/build_hls.sh then HLS/build_bd.tcl)
#   sv   -> CH11/out_sv/             (build_bd_rtl.tcl -tclargs sv)
#   vhdl -> CH11/out_vhdl/           (build_bd_rtl.tcl -tclargs vhdl)

set -euo pipefail

CH11="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"

BOARD=192.168.3.1
USER_NAME=xilinx
IMPL=hls
DEST=/home/xilinx/ch11_hil
INTERVAL=3
DO_START=0
DO_ENABLE=0

usage() { sed -n '2,20p' "$0"; exit "${1:-0}"; }

while [ $# -gt 0 ]; do
    case "$1" in
        --board)    BOARD=$2; shift 2 ;;
        --user)     USER_NAME=$2; shift 2 ;;
        --impl)     IMPL=$2; shift 2 ;;
        --dest)     DEST=$2; shift 2 ;;
        --interval) INTERVAL=$2; shift 2 ;;
        --start)    DO_START=1; shift ;;
        --enable)   DO_ENABLE=1; DO_START=1; shift ;;
        -h|--help)  usage 0 ;;
        *) echo "unknown option: $1" >&2; usage 1 ;;
    esac
done

case "$IMPL" in
    hls)  BITDIR="$CH11/HLS/out" ;;
    sv)   BITDIR="$CH11/out_sv" ;;
    vhdl) BITDIR="$CH11/out_vhdl" ;;
    *) echo "--impl must be hls, sv or vhdl (got '$IMPL')" >&2; exit 1 ;;
esac

BIT="$BITDIR/image_filter.bit"
HWH="$BITDIR/image_filter.hwh"
for f in "$BIT" "$HWH"; do
    [ -f "$f" ] || { echo "missing $f -- build the $IMPL bitstream first" >&2; exit 1; }
done

# PYNQ requires the .bit and .hwh to share a basename and directory; it parses
# the .hwh to discover the IP and its register map.
IMG="$CH11/HLS/test.jpg"
[ -f "$IMG" ] || { echo "missing $IMG (any JPEG will do)" >&2; exit 1; }

SSH_OPTS="-o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new"
TARGET="$USER_NAME@$BOARD"

echo "==> Checking $TARGET is reachable"
ssh $SSH_OPTS -o BatchMode=yes "$TARGET" true 2>/dev/null || {
    echo "cannot reach $TARGET with key auth." >&2
    echo "  is the board powered up?   ping $BOARD" >&2
    echo "  set up a key:              ssh-copy-id $TARGET" >&2
    exit 1
}

# Each implementation gets its own subdirectory so all three can live on the
# board at once. Switching between them is then just an edit to
# /etc/default/ch11-dp plus a restart -- no redeploy, no touching the unit file.
BOARD_BITDIR="$DEST/$IMPL"

echo "==> Copying the $IMPL build and scripts to $BOARD_BITDIR"
ssh $SSH_OPTS "$TARGET" "mkdir -p $BOARD_BITDIR"
# .bit and .hwh must share a basename and directory; PYNQ parses the .hwh to
# discover the IP and its register map.
scp -q $SSH_OPTS "$BIT" "$HWH" "$TARGET:$BOARD_BITDIR/"
scp -q $SSH_OPTS "$IMG" "$CH11/HLS/dp_display.py" "$CH11/HLS/hil_test.py" "$TARGET:$DEST/"

echo "==> Verifying the bitstream arrived intact"
local_md5=$(md5sum "$BIT" | awk '{print $1}')
board_md5=$(ssh $SSH_OPTS "$TARGET" "md5sum $BOARD_BITDIR/image_filter.bit" | awk '{print $1}')
if [ "$local_md5" != "$board_md5" ]; then
    echo "checksum mismatch: $local_md5 (host) vs $board_md5 (board)" >&2
    exit 1
fi
# The board has no RTC -- its clock is not even monotonic across reboots -- so
# file timestamps are meaningless here. Checksums are the only honest check.
echo "    md5 $local_md5 OK"

echo "==> Installing the service (sudo password required)"
ssh -t $SSH_OPTS "$TARGET" "
    set -e
    sudo tee /etc/default/ch11-dp >/dev/null <<CONF
# Written by CH11/deploy/deploy.sh. To switch implementations, point
# CH11_BITSTREAM at another subdirectory and restart:
#   $DEST/hls/image_filter.bit
#   $DEST/sv/image_filter.bit
#   $DEST/vhdl/image_filter.bit
# then: sudo systemctl restart ch11-dp
CH11_BITSTREAM=$BOARD_BITDIR/image_filter.bit
CH11_IMAGE=$DEST/test.jpg
CH11_INTERVAL=$INTERVAL
CONF
    sudo cp /dev/stdin /etc/systemd/system/ch11-dp.service <<'UNIT'
$(cat "$CH11/deploy/ch11-dp.service")
UNIT
    sudo chmod 0644 /etc/systemd/system/ch11-dp.service /etc/default/ch11-dp
    sudo systemctl daemon-reload
    sudo systemctl reset-failed ch11-dp 2>/dev/null || true
    $([ $DO_ENABLE = 1 ] && echo 'sudo systemctl enable ch11-dp' || echo 'true')
    $([ $DO_START  = 1 ] && echo 'sudo systemctl restart ch11-dp' || echo 'true')
"

echo
echo "=========================================="
echo " Deployed: $IMPL"
if [ $DO_START = 1 ]; then
    sleep 6
    ssh $SSH_OPTS -o BatchMode=yes "$TARGET" \
        'systemctl is-active ch11-dp >/dev/null \
            && echo " ch11-dp is active" \
            || { echo " ch11-dp FAILED to start:"; journalctl -u ch11-dp -n 15 --no-pager; }'
else
    echo " Not started. To run it:"
    echo "   ssh $TARGET sudo systemctl start ch11-dp"
fi
echo
echo " Watch frames:  ssh $TARGET journalctl -u ch11-dp -f"
echo " Stop:          ssh $TARGET sudo systemctl stop ch11-dp"
echo "=========================================="
