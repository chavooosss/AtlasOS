#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root/../dist/validation/atlas-boot/phase6/finalvisual/qemu"
mkdir -p "$out"
code=/usr/share/OVMF/OVMF_CODE_4M.fd
vars_template=/usr/share/OVMF/OVMF_VARS_4M.fd

targets=${1:-${ATLAS_BOOT_QEMU_TARGETS:-"1920x1080 1366x768 1280x720"}}
for target in $targets; do
  width=${target%x*}
  height=${target#*x}
  vga_width=$width
  # QEMU std VGA uses an 8-pixel aligned surface; 1366 is rounded down and
  # corrupts its monitor capture, so use the adjacent aligned mode for OVMF.
  if [[ "$target" == "1366x768" ]]; then vga_width=1368; fi
  efi="$out/AtlasBootManager-$target.efi"
  test -s "$efi" || { echo "Missing target EFI: $efi" >&2; exit 2; }
  work="$(mktemp -d "/tmp/atlas-boot-$target.XXXXXX")"
  esp="$work/abm-esp.img"
  vars="$work/OVMF_VARS.fd"
  qmp="$work/qmp.sock"
  serial="$out/qemu-$target-serial.txt"
  ppm="$out/qemu-$target"
  truncate -s 96M "$esp"
  mformat -i "$esp" -F ::
  mmd -i "$esp" ::/EFI ::/EFI/BOOT
  mcopy -i "$esp" "$efi" ::/EFI/BOOT/BOOTX64.EFI
  cp "$vars_template" "$vars"

  qemu-system-x86_64 \
    -machine q35,accel=tcg -m 512M -nodefaults \
    -device VGA,xres="$vga_width",yres="$height",vgamem_mb=64,edid=on \
    -display none -monitor none -serial "file:$serial" \
    -qmp "unix:$qmp,server=on,wait=off" \
    -drive "if=pflash,format=raw,unit=0,readonly=on,file=$code" \
    -drive "if=pflash,format=raw,unit=1,file=$vars" \
    -drive "if=none,id=abm_esp,format=raw,file=$esp" \
    -device virtio-blk-pci,drive=abm_esp,bootindex=0 \
    -net none -no-reboot -no-shutdown \
    >"$work/qemu.stdout" 2>&1 &
  qemu_pid=$!
  cleanup() {
    kill "$qemu_pid" 2>/dev/null || true
    wait "$qemu_pid" 2>/dev/null || true
    rm -rf "$work"
  }
  trap cleanup EXIT
  sleep 1
  if ! kill -0 "$qemu_pid" 2>/dev/null; then
    cat "$work/qemu.stdout" >&2
    exit 1
  fi
  python3 "$root/tools/qemu_capture.py" "$qmp" "$ppm" "$target"
  cleanup
  trap - EXIT
done
