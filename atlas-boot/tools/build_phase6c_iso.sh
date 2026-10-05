#!/usr/bin/env bash
set -euo pipefail

ISO="${1:?Usage: build_phase6c_iso.sh SOURCE_ISO FRONTEND_EFI BACKEND_EFI OUTPUT_DIR}"
FRONTEND="${2:?Usage: build_phase6c_iso.sh SOURCE_ISO FRONTEND_EFI BACKEND_EFI OUTPUT_DIR}"
BACKEND="${3:?Usage: build_phase6c_iso.sh SOURCE_ISO FRONTEND_EFI BACKEND_EFI OUTPUT_DIR}"
OUT="${4:?Usage: build_phase6c_iso.sh SOURCE_ISO FRONTEND_EFI BACKEND_EFI OUTPUT_DIR}"

EXPECTED_ISO=6a95de52ce839d44e3fde80a61aa554b381913f99aa5d75f199c9ed44444600c
EXPECTED_FRONTEND=6aec59a922aba6d86de075f9042e892458964fdde920ad9498e5869aa55b46d9
EXPECTED_BACKEND=b4e833c68a116d38abce823f7e923dd8a2ef7b8692e4d09f16c5841c3cb8932b
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ATLAS_VERSION="${ATLASOS_VERSION:-$(tr -d '[:space:]' < "${PROJECT_ROOT}/VERSION")}"
OUTPUT_NAME="${ATLASOS_INTEGRATED_ISO_NAME:-AtlasOS-${ATLAS_VERSION}-bootmanager-test.iso}"
[[ "$OUTPUT_NAME" != */* && "$OUTPUT_NAME" == *.iso ]] || { echo 'Output name must be a plain .iso filename.' >&2; exit 2; }
OUTPUT="$OUT/$OUTPUT_NAME"

for file in "$ISO" "$FRONTEND" "$BACKEND"; do
  [[ -s "$file" ]] || { echo "Missing input: $file" >&2; exit 2; }
done
[[ ! -e "$OUTPUT" ]] || { echo "Refusing to overwrite candidate: $OUTPUT" >&2; exit 3; }

check_hash() {
  local path="$1" expected="$2" name="$3" actual
  actual="$(sha256sum "$path" | awk '{print $1}')"
  [[ "$actual" == "$expected" ]] || {
    echo "$name SHA-256 mismatch: $actual" >&2
    exit 4
  }
  printf '%s  %s\n' "$actual" "$name"
}

if [[ "${ATLASOS_G4_CANDIDATE:-0}" == 1 ]]; then
  EXPECTED_ISO="$(sha256sum "$ISO" | awk '{print $1}')"
  EXPECTED_FRONTEND="$(sha256sum "$FRONTEND" | awk '{print $1}')"
  EXPECTED_BACKEND="$(sha256sum "$BACKEND" | awk '{print $1}')"
  grub-file --is-x86_64-efi "$FRONTEND"
  grub-file --is-x86_64-efi "$BACKEND"
  live_listing="$(xorriso -indev "$ISO" -ls /casper 2>&1)" || { echo 'Source candidate ISO cannot be read.' >&2; exit 5; }
  for required in vmlinuz initrd.img filesystem.squashfs; do
    grep -q "${required}" <<<"$live_listing" || { echo "Source ISO is missing /casper/${required}." >&2; exit 5; }
  done
else
  check_hash "$ISO" "$EXPECTED_ISO" "source ISO"
  check_hash "$FRONTEND" "$EXPECTED_FRONTEND" "Phase 6B frontend"
  check_hash "$BACKEND" "$EXPECTED_BACKEND" "Phase 6B backend"
  [[ "$(stat -c %s "$FRONTEND")" == 5121536 ]] || { echo 'Unexpected frontend size.' >&2; exit 5; }
  [[ "$(stat -c %s "$BACKEND")" == 737280 ]] || { echo 'Unexpected backend size.' >&2; exit 6; }
fi

mkdir -p "$OUT/verification"
WORK="$(mktemp -d "$OUT/.phase6c-work.XXXXXXXX")"
trap 'rm -rf -- "$WORK"' EXIT
mkdir -p "$WORK/verification"

xorriso -indev "$ISO" -report_el_torito plain -report_system_area plain -end \
  > "$OUT/ISO-metadata-source.txt" 2>&1
xorriso -indev "$ISO" -osirrox on \
  -extract /boot/grub/efi.img "$WORK/efi.img" \
  -extract /EFI/BOOT/BOOTX64.EFI "$WORK/source-BOOTX64.EFI" \
  -extract /SHA256SUMS "$WORK/source-SHA256SUMS" \
  -end >/dev/null
chmod u+rw "$WORK/efi.img"

# Keep the production EFI as an output-side reference, but do not use it
# as the active UEFI frontend. Update the El Torito EFI filesystem itself.
mcopy -o -i "$WORK/efi.img" "$FRONTEND" ::/EFI/BOOT/BOOTX64.EFI
mcopy -o -i "$WORK/efi.img" "$BACKEND" ::/EFI/BOOT/ATLASGRUB.EFI
mcopy -i "$WORK/efi.img" ::/EFI/BOOT/BOOTX64.EFI "$WORK/verification/EFI-image-BOOTX64.EFI"
mcopy -i "$WORK/efi.img" ::/EFI/BOOT/ATLASGRUB.EFI "$WORK/verification/EFI-image-ATLASGRUB.EFI"
cmp "$FRONTEND" "$WORK/verification/EFI-image-BOOTX64.EFI"
cmp "$BACKEND" "$WORK/verification/EFI-image-ATLASGRUB.EFI"

# Regenerate the embedded payload manifest after all EFI changes. The historical
# source SHA256SUMS is retained as input, but its three boot payload entries are
# replaced with the exact final staged bytes before ISO remastering.
python3 "$(dirname "$0")/../../iso/update-embedded-manifest.py" \
  "$WORK/source-SHA256SUMS" "$FRONTEND" "$BACKEND" "$WORK/efi.img" \
  "$WORK/SHA256SUMS"

# xorriso replay preserves the original BIOS/UEFI El Torito and isohybrid
# recipe. Replace the imported appended ESP data with the updated EFI image
# so raw-ISO USB boot and El Torito CD boot see the same UEFI files.
xorriso -indev "$ISO" -outdev "$OUTPUT" \
  -boot_image any replay \
  -map "$FRONTEND" /EFI/BOOT/BOOTX64.EFI \
  -map "$BACKEND" /EFI/BOOT/ATLASGRUB.EFI \
  -map "$WORK/efi.img" /boot/grub/efi.img \
  -map "$WORK/SHA256SUMS" /SHA256SUMS \
  -append_partition 2 0xef "$WORK/efi.img" \
  -commit > "$OUT/xorriso-repack.log" 2>&1

xorriso -indev "$OUTPUT" -report_el_torito plain -report_system_area plain -end \
  > "$OUT/ISO-metadata-candidate.txt" 2>&1
xorriso -indev "$OUTPUT" -osirrox on \
  -extract /boot/grub/efi.img "$OUT/verification/EFI-boot-image.img" \
  -extract /EFI/BOOT/BOOTX64.EFI "$OUT/verification/ISO-root-BOOTX64.EFI" \
  -extract /EFI/BOOT/ATLASGRUB.EFI "$OUT/verification/ISO-root-ATLASGRUB.EFI" \
  -extract /SHA256SUMS "$OUT/verification/ISO-SHA256SUMS" \
  -end >/dev/null
mcopy -i "$OUT/verification/EFI-boot-image.img" \
  ::/EFI/BOOT/BOOTX64.EFI "$OUT/verification/EFI-image-BOOTX64.EFI"
mcopy -i "$OUT/verification/EFI-boot-image.img" \
  ::/EFI/BOOT/ATLASGRUB.EFI "$OUT/verification/EFI-image-ATLASGRUB.EFI"

for actual in \
  "$OUT/verification/ISO-root-BOOTX64.EFI" \
  "$OUT/verification/EFI-image-BOOTX64.EFI"; do
  cmp "$FRONTEND" "$actual"
done
for actual in \
  "$OUT/verification/ISO-root-ATLASGRUB.EFI" \
  "$OUT/verification/EFI-image-ATLASGRUB.EFI"; do
  cmp "$BACKEND" "$actual"
done
cmp "$WORK/SHA256SUMS" "$OUT/verification/ISO-SHA256SUMS"

check_hash "$ISO" "$EXPECTED_ISO" "source ISO after repack"
check_hash "$OUT/verification/ISO-root-BOOTX64.EFI" "$EXPECTED_FRONTEND" "extracted ISO-root frontend"
check_hash "$OUT/verification/EFI-image-BOOTX64.EFI" "$EXPECTED_FRONTEND" "extracted EFI-image frontend"
check_hash "$OUT/verification/ISO-root-ATLASGRUB.EFI" "$EXPECTED_BACKEND" "extracted ISO-root backend"
check_hash "$OUT/verification/EFI-image-ATLASGRUB.EFI" "$EXPECTED_BACKEND" "extracted EFI-image backend"
printf 'candidate_size=%s\n' "$(stat -c %s "$OUTPUT")"
sha256sum "$OUTPUT"
(cd "$OUT" && sha256sum "$(basename "$OUTPUT")" > SHA256SUMS.txt)
cat > "$OUT/BUILD-INFO.txt" <<EOF
AtlasOS version: ${ATLAS_VERSION}
Build profile: phase6c-bootmanager-integration-candidate
Source ISO SHA-256: $EXPECTED_ISO
Frontend SHA-256: $EXPECTED_FRONTEND
Backend SHA-256: $EXPECTED_BACKEND
Output: $(basename "$OUTPUT")
Output size bytes: $(stat -c %s "$OUTPUT")
Output SHA-256: $(sha256sum "$OUTPUT" | awk '{print $1}')
Embedded EFI payload rows: regenerated and candidate manifest compared
Validation: structural artifact checks only; boot success is not implied
EOF
printf 'external_checksum=%s\n' "$OUT/SHA256SUMS.txt"
