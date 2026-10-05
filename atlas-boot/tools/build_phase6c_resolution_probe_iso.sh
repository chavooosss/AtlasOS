#!/usr/bin/env bash
set -euo pipefail
if [[ $# -ne 4 ]]; then
  echo 'Usage: build_phase6c_resolution_probe_iso.sh SOURCE_ISO FRONTEND_EFI BACKEND_EFI OUTPUT_ISO' >&2
  exit 2
fi
ISO="$1"
FRONTEND="$2"
BACKEND="$3"
OUTPUT="$4"
EXPECTED_ISO=6a95de52ce839d44e3fde80a61aa554b381913f99aa5d75f199c9ed44444600c
EXPECTED_BACKEND=b4e833c68a116d38abce823f7e923dd8a2ef7b8692e4d09f16c5841c3cb8932b
frontend_hash="$(sha256sum "$FRONTEND" | cut -d' ' -f1)"
case "$frontend_hash" in
  0fa0c68946ba318016d4bbfd41289d5edbf18fb7987f9cd5a3a4f2e8b78a7377) variant=1368x768 ;;
  208aa9a60e27a80c60cc6be45b8c29ecb05fa84b00e3559b42c890509fb2711c) variant=1280x720 ;;
  *) echo "Frontend is not a frozen Phase 6B resolution variant: $frontend_hash" >&2; exit 3 ;;
esac
[[ "$(sha256sum "$ISO" | cut -d' ' -f1)" == "$EXPECTED_ISO" ]] || { echo 'Source ISO hash mismatch.' >&2; exit 4; }
[[ "$(sha256sum "$BACKEND" | cut -d' ' -f1)" == "$EXPECTED_BACKEND" ]] || { echo 'Backend hash mismatch.' >&2; exit 5; }
[[ ! -e "$OUTPUT" ]] || { echo "Refusing to overwrite probe ISO: $OUTPUT" >&2; exit 6; }
OUTDIR="$(dirname "$OUTPUT")"
mkdir -p "$OUTDIR"
WORK="$(mktemp -d "$OUTDIR/.resolution-probe.XXXXXXXX")"
trap 'rm -rf -- "$WORK"' EXIT
xorriso -indev "$ISO" -osirrox on -extract /boot/grub/efi.img "$WORK/efi.img" -end >/dev/null
chmod u+rw "$WORK/efi.img"
mcopy -o -i "$WORK/efi.img" "$FRONTEND" ::/EFI/BOOT/BOOTX64.EFI
mcopy -o -i "$WORK/efi.img" "$BACKEND" ::/EFI/BOOT/ATLASGRUB.EFI
xorriso -indev "$ISO" -outdev "$OUTPUT" -boot_image any replay \
  -map "$FRONTEND" /EFI/BOOT/BOOTX64.EFI \
  -map "$BACKEND" /EFI/BOOT/ATLASGRUB.EFI \
  -map "$WORK/efi.img" /boot/grub/efi.img \
  -append_partition 2 0xef "$WORK/efi.img" -commit >"$OUTDIR/xorriso-$variant.log" 2>&1
EXPECTED_SIZE_FRONTEND=5121536
[[ "$(stat -c %s "$FRONTEND")" == "$EXPECTED_SIZE_FRONTEND" ]] || { echo 'Unexpected frozen frontend size.' >&2; exit 7; }
xorriso -indev "$OUTPUT" -osirrox on -extract /boot/grub/efi.img "$WORK/check-efi.img" -end >/dev/null
mcopy -i "$WORK/check-efi.img" ::/EFI/BOOT/BOOTX64.EFI "$WORK/check-frontend.efi"
mcopy -i "$WORK/check-efi.img" ::/EFI/BOOT/ATLASGRUB.EFI "$WORK/check-backend.efi"
cmp "$FRONTEND" "$WORK/check-frontend.efi"
cmp "$BACKEND" "$WORK/check-backend.efi"
xorriso -indev "$OUTPUT" -report_el_torito plain -report_system_area plain -end >"$OUTDIR/ISO-metadata-$variant.txt" 2>&1
printf 'variant=%s\nfrontend_sha256=%s\nbackend_sha256=%s\niso_size=%s\n' \
  "$variant" "$frontend_hash" "$EXPECTED_BACKEND" "$(stat -c %s "$OUTPUT")"
sha256sum "$OUTPUT"
