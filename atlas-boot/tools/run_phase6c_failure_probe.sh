#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 4 || $# -gt 5 ]]; then
  echo 'Usage: run_phase6c_failure_probe.sh ISO FRONTEND_EFI BACKEND_EFI OUTPUT_DIR [WIDTHxHEIGHT]' >&2
  exit 2
fi
ISO="$1"
FRONTEND="$2"
BACKEND="$3"
OUT="$4"
RESOLUTION="${5:-1920x1080}"
[[ -s "$ISO" && -s "$FRONTEND" && -s "$BACKEND" ]] || { echo 'Missing ISO/frontend/backend.' >&2; exit 3; }
[[ "$RESOLUTION" =~ ^(1920x1080|1368x768|1280x720)$ ]] || { echo 'Unsupported resolution.' >&2; exit 4; }
[[ ! -e "$OUT" ]] || { echo "Refusing to overwrite output: $OUT" >&2; exit 5; }
for tool in qemu-system-x86_64 mformat mcopy mmd python3; do command -v "$tool" >/dev/null; done
CODE=/usr/share/OVMF/OVMF_CODE_4M.fd
VARS_TEMPLATE=/usr/share/OVMF/OVMF_VARS_4M.fd
[[ -s "$CODE" && -s "$VARS_TEMPLATE" ]] || { echo 'OVMF firmware files are missing.' >&2; exit 6; }
mkdir -p "$OUT"
ESP="$OUT/esp-backend-failure.img"
truncate -s 96M "$ESP"
mformat -i "$ESP" -F ::
mmd -i "$ESP" ::/EFI ::/EFI/BOOT
mcopy -i "$ESP" "$FRONTEND" ::/EFI/BOOT/BOOTX64.EFI
mcopy -i "$ESP" "$BACKEND" ::/EFI/BOOT/ATLASGRUB.EFI
WORK="$(mktemp -d "${TMPDIR:-/tmp}/atlas-phase6c-failure.XXXXXXXX")"
QMP="$WORK/qmp.sock"
VARS="$WORK/OVMF_VARS.fd"
cp "$VARS_TEMPLATE" "$VARS"
WIDTH="${RESOLUTION%x*}"
HEIGHT="${RESOLUTION#*x}"
SERIAL="$OUT/ovmf-serial.txt"
qemu-system-x86_64 \
  -machine q35,accel=tcg -m 4096 -smp 2 -nodefaults \
  -device VGA,xres="$WIDTH",yres="$HEIGHT",vgamem_mb=64,edid=on \
  -display none -monitor none -serial "file:$SERIAL" \
  -qmp "unix:$QMP,server=on,wait=off" \
  -drive "if=pflash,format=raw,unit=0,readonly=on,file=$CODE" \
  -drive "if=pflash,format=raw,unit=1,file=$VARS" \
  -drive "if=none,id=atlas_test_esp,format=raw,file=$ESP" \
  -device virtio-blk-pci,drive=atlas_test_esp,bootindex=0 \
  -drive "if=none,id=atlas_iso,media=cdrom,readonly=on,file=$ISO" \
  -device ich9-ahci,id=sata \
  -device ide-cd,drive=atlas_iso,bus=sata.0,bootindex=1 \
  -net none -no-reboot -no-shutdown >"$OUT/qemu.stdout.txt" 2>&1 &
QEMU_PID=$!
cleanup() {
  kill "$QEMU_PID" 2>/dev/null || true
  wait "$QEMU_PID" 2>/dev/null || true
  rm -rf -- "$WORK"
}
trap cleanup EXIT
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$ROOT/tools/qemu_phase6c_failure.py" "$QMP" "$OUT"
