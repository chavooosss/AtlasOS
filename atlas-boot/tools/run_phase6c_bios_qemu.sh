#!/usr/bin/env bash
set -euo pipefail
if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo 'Usage: run_phase6c_bios_qemu.sh ISO OUTPUT_DIR [TIMEOUT_SECONDS]' >&2
  exit 2
fi
ISO="$1"
OUT="$2"
TIMEOUT="${3:-300}"
[[ -s "$ISO" ]] || { echo "Missing candidate ISO: $ISO" >&2; exit 3; }
[[ ! -e "$OUT" ]] || { echo "Refusing to overwrite output: $OUT" >&2; exit 4; }
command -v qemu-system-x86_64 >/dev/null
command -v python3 >/dev/null
mkdir -p "$OUT"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/atlas-phase6c-bios.XXXXXXXX")"
QMP="$WORK/qmp.sock"
SERIAL="$OUT/seabios-serial.txt"
qemu-system-x86_64 \
  -machine pc,accel=tcg -m 4096 -smp 2 -nodefaults \
  -device VGA,xres=1368,yres=768,vgamem_mb=64,edid=on \
  -display none -monitor none -serial "file:$SERIAL" \
  -qmp "unix:$QMP,server=on,wait=off" \
  -drive "if=none,id=atlas_iso,media=cdrom,readonly=on,file=$ISO" \
  -device ide-cd,drive=atlas_iso,bus=ide.1,bootindex=0 \
  -boot order=d,menu=off -net none -no-reboot -no-shutdown \
  >"$OUT/qemu.stdout.txt" 2>&1 &
QEMU_PID=$!
cleanup() {
  kill "$QEMU_PID" 2>/dev/null || true
  wait "$QEMU_PID" 2>/dev/null || true
  rm -rf -- "$WORK"
}
trap cleanup EXIT
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 "$ROOT/tools/qemu_phase6c_bios.py" "$QMP" "$OUT" "$TIMEOUT"
