#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 4 || $# -gt 7 ]]; then
  echo "Usage: run_phase6b_qemu.sh ISO FRONTEND_EFI BACKEND_EFI OUTPUT_DIR [live|missing|invalid] [TIMEOUT_SECONDS] [WIDTHxHEIGHT]" >&2
  exit 2
fi
ISO="$1"
FRONTEND="$2"
BACKEND="$3"
OUT="$4"
MODE="${5:-live}"
TIMEOUT="${6:-300}"
RESOLUTION="${7:-1920x1080}"
[[ "$RESOLUTION" =~ ^(1920x1080|1368x768|1280x720)$ ]] || { echo "Unsupported test resolution: $RESOLUTION" >&2; exit 8; }
WIDTH="${RESOLUTION%x*}"
HEIGHT="${RESOLUTION#*x}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODE=/usr/share/OVMF/OVMF_CODE_4M.fd
VARS_TEMPLATE=/usr/share/OVMF/OVMF_VARS_4M.fd

[[ -s "$ISO" && -s "$FRONTEND" ]] || { echo 'Missing ISO or frontend EFI.' >&2; exit 3; }
[[ "$MODE" == live || "$MODE" == missing || "$MODE" == invalid ]] || { echo "Invalid mode: $MODE" >&2; exit 4; }
[[ "$MODE" != live || -s "$BACKEND" ]] || { echo 'Missing GRUB backend EFI.' >&2; exit 5; }
command -v qemu-system-x86_64 >/dev/null
command -v mformat >/dev/null
command -v mcopy >/dev/null
mkdir -p "$OUT"

case "$MODE" in
  live) ESP="$OUT/esp-live.img"; QMP_OUT="$OUT/live" ;;
  missing) ESP="$OUT/esp-missing-backend.img"; QMP_OUT="$OUT/missing-backend" ;;
  invalid) ESP="$OUT/esp-invalid-backend.img"; QMP_OUT="$OUT/invalid-backend" ;;
esac
[[ ! -e "$ESP" ]] || { echo "Refusing to overwrite test media: $ESP" >&2; exit 6; }
[[ ! -e "$QMP_OUT" ]] || { echo "Refusing to overwrite captures: $QMP_OUT" >&2; exit 7; }

truncate -s 96M "$ESP"
mformat -i "$ESP" -F ::
mmd -i "$ESP" ::/EFI ::/EFI/BOOT
mcopy -i "$ESP" "$FRONTEND" ::/EFI/BOOT/BOOTX64.EFI
if [[ "$MODE" == live ]]; then
  mcopy -i "$ESP" "$BACKEND" ::/EFI/BOOT/ATLASGRUB.EFI
elif [[ "$MODE" == invalid ]]; then
  printf 'This is deliberately not a PE/COFF EFI image.\n' > "$OUT/invalid-backend.txt"
  mcopy -i "$ESP" "$OUT/invalid-backend.txt" ::/EFI/BOOT/ATLASGRUB.EFI
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/atlas-phase6b-qemu.XXXXXXXX")"
QMP="$WORK/qmp.sock"
VARS="$WORK/OVMF_VARS.fd"
SERIAL="$QMP_OUT-serial.txt"
mkdir -p "$QMP_OUT"
cp "$VARS_TEMPLATE" "$VARS"
VGA="-device VGA,xres=$WIDTH,yres=$HEIGHT,vgamem_mb=64,edid=on"

qemu-system-x86_64 \
  -machine q35,accel=tcg -m 4096 -smp 2 -nodefaults \
  $VGA -display none -monitor none -serial "file:$SERIAL" \
  -qmp "unix:$QMP,server=on,wait=off" \
  -drive "if=pflash,format=raw,unit=0,readonly=on,file=$CODE" \
  -drive "if=pflash,format=raw,unit=1,file=$VARS" \
  -drive "if=none,id=abm_esp,format=raw,file=$ESP" \
  -device virtio-blk-pci,drive=abm_esp,bootindex=0 \
  -drive "if=none,id=atlas_iso,media=cdrom,readonly=on,file=$ISO" \
  -device ich9-ahci,id=sata \
  -device ide-cd,drive=atlas_iso,bus=sata.0,bootindex=1 \
  -net none -no-reboot -no-shutdown \
  >"$QMP_OUT/qemu.stdout.txt" 2>&1 &
QEMU_PID=$!
cleanup() {
  kill "$QEMU_PID" 2>/dev/null || true
  wait "$QEMU_PID" 2>/dev/null || true
  rm -rf -- "$WORK"
}
trap cleanup EXIT

python3 "$ROOT/tools/qemu_phase6b.py" "$QMP" "$QMP_OUT" \
  "$([[ "$MODE" == live ]] && echo live || echo failure)" "$TIMEOUT" "$RESOLUTION"
echo "QEMU Phase 6B run artifacts: $QMP_OUT"
