#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSETS_DIR="${PROJECT_ROOT}/docs/assets"
UI_BRANDING="${PROJECT_ROOT}/config/includes.chroot/usr/local/share/atlasos/ui/branding"
ATLAS_BRANDING="${PROJECT_ROOT}/config/includes.chroot/usr/share/atlasos/branding"
PLYMOUTH_THEME="${PROJECT_ROOT}/config/includes.chroot/usr/share/plymouth/themes/atlasos"

SYSTEM_LOGO="${ASSETS_DIR}/atlas-os sistem içi logo.jpg"
BOOT_MARK="${ASSETS_DIR}/atlas-os açılış animasyonu ve diğer açılışla akalı yerlerde kullanılıcak görsel.jpg"

for asset in "${SYSTEM_LOGO}" "${BOOT_MARK}"; do
  if [[ ! -s "${asset}" ]]; then
    echo "Required AtlasOS branding asset is missing: ${asset}" >&2
    exit 1
  fi
done

mkdir -p "${UI_BRANDING}" "${ATLAS_BRANDING}" "${PLYMOUTH_THEME}"

# The delivered JPGs have a flat white background. Derive transparent PNGs
# while retaining the artwork's proportions and keeping the source files intact.
magick "${SYSTEM_LOGO}" \
  -fuzz 5% -transparent '#fdfdfd' -trim +repage \
  "${UI_BRANDING}/atlas-primary.png"

magick "${BOOT_MARK}" \
  -fuzz 8% -transparent '#f9faf4' -trim +repage \
  "${ATLAS_BRANDING}/atlas-symbol.png"

magick "${ATLAS_BRANDING}/atlas-symbol.png" \
  -resize 512x512 -gravity center -background none -extent 512x512 \
  "${UI_BRANDING}/atlas-symbol.png"

magick "${ATLAS_BRANDING}/atlas-symbol.png" \
  -resize 560x560 -gravity center -background none -extent 660x740 \
  "${PLYMOUTH_THEME}/atlas-logo.png"

echo "AtlasOS branding assets prepared from docs/assets."
