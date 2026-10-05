#!/usr/bin/env bash
set -euo pipefail

ISO="${1:?Usage: build_phase6b_backend.sh ISO_PATH OUTPUT_DIR}"
OUT="${2:?Usage: build_phase6b_backend.sh ISO_PATH OUTPUT_DIR}"
EXPECTED_ISO_SHA256="6a95de52ce839d44e3fde80a61aa554b381913f99aa5d75f199c9ed44444600c"

[[ -f "$ISO" ]] || { echo "ISO not found: $ISO" >&2; exit 2; }
actual_iso_sha256="$(sha256sum "$ISO" | cut -d' ' -f1)"
if [[ "${ATLASOS_G4_CANDIDATE:-0}" != 1 ]]; then
  [[ "$actual_iso_sha256" == "$EXPECTED_ISO_SHA256" ]] || {
    echo "Unexpected pinned AtlasOS 0.6.2 ISO SHA-256: $actual_iso_sha256" >&2
    exit 3
  }
else
  live_listing="$(xorriso -indev "$ISO" -ls /casper 2>&1)" || {
    echo "Candidate is not a readable AtlasOS Live ISO." >&2
    exit 3
  }
  for required in vmlinuz initrd.img filesystem.squashfs; do
    grep -q "${required}" <<<"$live_listing" || {
      echo "Candidate is missing /casper/${required}." >&2
      exit 3
    }
  done
fi

mkdir -p "$OUT"
for item in AtlasGrubProduction.efi AtlasGrubLiveBackend.efi grub-live-autoboot.cfg; do
  [[ ! -e "$OUT/$item" ]] || { echo "Refusing to overwrite: $OUT/$item" >&2; exit 4; }
done

work="$(mktemp -d "${TMPDIR:-/tmp}/atlas-phase6b.XXXXXXXX")"
trap 'rm -rf -- "$work"' EXIT
xorriso -osirrox on -indev "$ISO" \
  -extract /EFI/BOOT/BOOTX64.EFI "$work/AtlasGrubProduction.efi" \
  -extract /boot/grub/efi.img "$work/efi.img" \
  -extract /SHA256SUMS "$work/ISO-SHA256SUMS"
mcopy -i "$work/efi.img" ::/EFI/BOOT/BOOTX64.EFI "$work/AtlasGrubProduction-efifat.efi"
cmp "$work/AtlasGrubProduction.efi" "$work/AtlasGrubProduction-efifat.efi"
cp "$work/AtlasGrubProduction.efi" "$OUT/AtlasGrubProduction.efi"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cp "$PROJECT_ROOT/iso/grub-live-autoboot.cfg" "$OUT/grub-live-autoboot.cfg"

grub-mkstandalone \
  --format=x86_64-efi \
  --directory=/usr/lib/grub/x86_64-efi \
  --install-modules='normal part_gpt part_msdos fat iso9660 search search_fs_file linux' \
  --locales='' --fonts='' --themes='' \
  --output="$OUT/AtlasGrubLiveBackend.efi" \
  "boot/grub/grub.cfg=$OUT/grub-live-autoboot.cfg"
grub-file --is-x86_64-efi "$OUT/AtlasGrubLiveBackend.efi"

cp "$work/ISO-SHA256SUMS" "$OUT/ISO-SHA256SUMS"
(
  cd "$OUT"
  sha256sum AtlasGrubProduction.efi AtlasGrubLiveBackend.efi \
    grub-live-autoboot.cfg ISO-SHA256SUMS > SHA256SUMS.txt
)
printf 'input_iso_sha256=%s\n' "$actual_iso_sha256"
stat -c 'size=%s path=%n' "$OUT/AtlasGrubProduction.efi" "$OUT/AtlasGrubLiveBackend.efi"
cat "$OUT/SHA256SUMS.txt"
