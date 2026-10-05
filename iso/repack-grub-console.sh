#!/usr/bin/env bash
set -euo pipefail

# Repackage the physically booted 0.6.2 diagnostics image with the console-only
# Atlas menu. The root filesystem, kernel, initramfs, Plymouth and BIOS menu are
# taken from the input ISO without rebuilding the live system.
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INPUT_ISO="${1:?Pass the verified source ISO path}"
OUTPUT_ISO="${2:?Pass a new output ISO path}"
EXPECTED_SHA256="${3:?Pass the source ISO SHA-256}"
[[ "${EXPECTED_SHA256}" =~ ^[a-fA-F0-9]{64}$ ]] || { echo "Invalid source hash" >&2; exit 1; }
[[ -f "${INPUT_ISO}" ]] || { echo "Source ISO missing" >&2; exit 1; }
[[ ! -e "${OUTPUT_ISO}" && ! -e "${OUTPUT_ISO}.sha256" ]] || { echo "Output exists" >&2; exit 1; }
[[ "$(sha256sum "${INPUT_ISO}" | cut -d' ' -f1)" == "${EXPECTED_SHA256,,}" ]] || { echo "Source ISO hash mismatch" >&2; exit 1; }

STAGE_ROOT="$(mktemp -d "${HOME}/.cache/atlasos/grub-console.XXXXXXXX")"
trap 'chmod -R u+rwX -- "${STAGE_ROOT}" 2>/dev/null || true; rm -rf -- "${STAGE_ROOT}"' EXIT
STAGE="${STAGE_ROOT}/binary"
mkdir -p "${STAGE}/boot/grub" "${STAGE_ROOT}/efi" "$(dirname "${OUTPUT_ISO}")"
xorriso -osirrox on -indev "${INPUT_ISO}" -extract / "${STAGE}" >/dev/null 2>"${STAGE_ROOT}/extract.log"
chmod -R u+rwX -- "${STAGE}"

cp "${PROJECT_ROOT}/iso/grub-console.cfg" "${STAGE_ROOT}/efi/grub.cfg"
grub-mkstandalone -O x86_64-efi \
  -o "${STAGE_ROOT}/efi/BOOTX64.EFI" \
  "boot/grub/grub.cfg=${STAGE_ROOT}/efi/grub.cfg"
truncate -s 10M "${STAGE}/boot/grub/efi.img"
mformat -i "${STAGE}/boot/grub/efi.img" -c 1 ::
mmd -i "${STAGE}/boot/grub/efi.img" ::/EFI ::/EFI/BOOT
mcopy -i "${STAGE}/boot/grub/efi.img" "${STAGE_ROOT}/efi/BOOTX64.EFI" ::/EFI/BOOT/BOOTX64.EFI
cp "${STAGE_ROOT}/efi/BOOTX64.EFI" "${STAGE}/EFI/BOOT/BOOTX64.EFI"

(
  cd "${STAGE}"
  find . -type f ! -name SHA256SUMS ! -path ./isolinux/isolinux.bin -print0 \
    | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS
)

TEMP_ISO="${STAGE_ROOT}/AtlasOS-0.6.2-live-amd64.iso"
xorriso -as mkisofs \
  -r -J -joliet-long -l -V "ATLASOS_062" \
  -A "AtlasOS Live Demo" -publisher "AtlasOS Project" -p "AtlasOS Project" \
  -o "${TEMP_ISO}" \
  -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin -partition_offset 16 \
  -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot \
  -boot-load-size 4 -boot-info-table \
  -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
  -append_partition 2 0xef "${STAGE}/boot/grub/efi.img" \
  "${STAGE}" >"${STAGE_ROOT}/xorriso.log" 2>&1

cp "${TEMP_ISO}" "${OUTPUT_ISO}.part"
mv "${OUTPUT_ISO}.part" "${OUTPUT_ISO}"
(
  cd "$(dirname "${OUTPUT_ISO}")"
  sha256sum "$(basename "${OUTPUT_ISO}")" > "$(basename "${OUTPUT_ISO}").sha256"
)
echo "Created ${OUTPUT_ISO}"
