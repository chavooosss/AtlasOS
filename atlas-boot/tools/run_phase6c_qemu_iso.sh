#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 6 ]]; then
  echo "Usage: run_phase6c_qemu_iso.sh ISO OUTPUT_DIR [WIDTHxHEIGHT] [live|timeout] [VGA_MEMORY_MB] [EDID on|off]" >&2
  exit 2
fi
ISO="$1"
OUT="$2"
RESOLUTION="${3:-1920x1080}"
MODE="${4:-live}"
VGA_MEMORY_MB="${5:-64}"
EDID="${6:-on}"
[[ -s "$ISO" ]] || { echo "Missing test ISO: $ISO" >&2; exit 3; }
[[ "$RESOLUTION" =~ ^(1920x1080|1368x768|1280x720)$ ]] || { echo "Unsupported QEMU resolution: $RESOLUTION" >&2; exit 4; }
[[ "$MODE" == live || "$MODE" == timeout || "$MODE" == navigation ]] || { echo "Unsupported mode: $MODE" >&2; exit 5; }
[[ "$VGA_MEMORY_MB" =~ ^([4-9]|[1-5][0-9]|6[0-4])$ ]] || { echo "Invalid VGA memory amount: $VGA_MEMORY_MB" >&2; exit 8; }
[[ "$EDID" == on || "$EDID" == off ]] || { echo 'EDID must be on or off.' >&2; exit 9; }
[[ ! -e "$OUT" ]] || { echo "Refusing to overwrite QEMU output: $OUT" >&2; exit 6; }

CODE=/usr/share/OVMF/OVMF_CODE_4M.fd
VARS_TEMPLATE=/usr/share/OVMF/OVMF_VARS_4M.fd
[[ -s "$CODE" && -s "$VARS_TEMPLATE" ]] || { echo 'OVMF firmware files are missing.' >&2; exit 7; }
command -v qemu-system-x86_64 >/dev/null
command -v python3 >/dev/null

mkdir -p "$OUT"
WIDTH="${RESOLUTION%x*}"
HEIGHT="${RESOLUTION#*x}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/atlas-phase6c-ovmf.XXXXXXXX")"
QMP="$WORK/qmp.sock"
VARS="$WORK/OVMF_VARS.fd"
cp "$VARS_TEMPLATE" "$VARS"
SERIAL="$OUT/ovmf-serial.txt"
qemu-system-x86_64 \
  -machine q35,accel=tcg -m 4096 -smp 2 -nodefaults \
  -device VGA,xres="$WIDTH",yres="$HEIGHT",vgamem_mb="$VGA_MEMORY_MB",edid="$EDID" \
  -display none -monitor none -serial "file:$SERIAL" \
  -qmp "unix:$QMP,server=on,wait=off" \
  -drive "if=pflash,format=raw,unit=0,readonly=on,file=$CODE" \
  -drive "if=pflash,format=raw,unit=1,file=$VARS" \
  -drive "if=none,id=atlas_iso,media=cdrom,readonly=on,file=$ISO" \
  -device ich9-ahci,id=sata \
  -device ide-cd,drive=atlas_iso,bus=sata.0,bootindex=0 \
  -boot order=d,menu=off \
  -net none -no-reboot -no-shutdown \
  >"$OUT/qemu.stdout.txt" 2>&1 &
QEMU_PID=$!
cleanup() {
  kill "$QEMU_PID" 2>/dev/null || true
  wait "$QEMU_PID" 2>/dev/null || true
  rm -rf -- "$WORK"
}
trap cleanup EXIT

python3 "$(dirname "$0")/qemu_phase6b.py" "$QMP" "$OUT" "$MODE" 300 "$RESOLUTION"
