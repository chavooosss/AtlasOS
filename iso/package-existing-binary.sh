#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${ATLASOS_BUILD_DIR:-${HOME}/.cache/atlasos/live-build}"
BINARY_DIR="${BUILD_DIR}/binary"
OUTPUT="${PROJECT_ROOT}/dist/AtlasOS-0.2.1-r3-live-amd64.iso"
EFI_WORK="${BUILD_DIR}/efi-final"

if [[ ! -d "${BINARY_DIR}" ]]; then
  echo "No live-build binary directory found: ${BINARY_DIR}" >&2
  exit 1
fi

rm -rf "${EFI_WORK}"
mkdir -p "${EFI_WORK}" "${BINARY_DIR}/boot/grub" "${BINARY_DIR}/EFI/BOOT" "${PROJECT_ROOT}/dist"

cat > "${EFI_WORK}/grub.cfg" <<'GRUB'
insmod part_gpt
insmod part_msdos
insmod fat
insmod iso9660
insmod search_fs_file

search --no-floppy --file --set=root /casper/vmlinuz
set default=0
set timeout=5

menuentry "AtlasOS 0.2.1 Live" {
    linux /casper/vmlinuz boot=live config boot=casper username=atlas hostname=atlasos locales=tr_TR.UTF-8 keyboard-layouts=tr keyboard-configuration/layoutcode=tr console-setup/layoutcode=tr timezone=Europe/Istanbul quiet splash
    initrd /casper/initrd.img
}

menuentry "AtlasOS 0.2.1 Live (guvenli grafik)" {
    linux /casper/vmlinuz boot=live config boot=casper username=atlas hostname=atlasos locales=tr_TR.UTF-8 keyboard-layouts=tr keyboard-configuration/layoutcode=tr console-setup/layoutcode=tr timezone=Europe/Istanbul quiet splash nomodeset
    initrd /casper/initrd.img
}
GRUB

grub-mkstandalone \
  -O x86_64-efi \
  -o "${EFI_WORK}/BOOTX64.EFI" \
  "boot/grub/grub.cfg=${EFI_WORK}/grub.cfg"

rm -f "${BINARY_DIR}/boot/grub/efi.img"
truncate -s 10M "${BINARY_DIR}/boot/grub/efi.img"
mformat -i "${BINARY_DIR}/boot/grub/efi.img" -c 1 ::
mmd -i "${BINARY_DIR}/boot/grub/efi.img" ::/EFI ::/EFI/BOOT
mcopy -i "${BINARY_DIR}/boot/grub/efi.img" "${EFI_WORK}/BOOTX64.EFI" ::/EFI/BOOT/BOOTX64.EFI
cp "${EFI_WORK}/BOOTX64.EFI" "${BINARY_DIR}/EFI/BOOT/BOOTX64.EFI"

xorriso -as mkisofs \
  -r -J -joliet-long -l \
  -V "AtlasOS 0.2.1 Live" \
  -A "AtlasOS Live Demo" \
  -publisher "AtlasOS Project" \
  -p "AtlasOS Project" \
  -o "${OUTPUT}" \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
  -partition_offset 16 \
  -b isolinux/isolinux.bin \
  -c isolinux/boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-alt-boot \
  -e boot/grub/efi.img \
  -no-emul-boot \
  -append_partition 2 0xef "${BINARY_DIR}/boot/grub/efi.img" \
  "${BINARY_DIR}"

echo "AtlasOS ISO created: ${OUTPUT}"
