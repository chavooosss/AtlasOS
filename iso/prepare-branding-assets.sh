#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UI_BRANDING="${PROJECT_ROOT}/config/includes.chroot/usr/local/share/atlasos/ui/branding"
ATLAS_BRANDING="${PROJECT_ROOT}/config/includes.chroot/usr/share/atlasos/branding"
PLYMOUTH_THEME="${PROJECT_ROOT}/config/includes.chroot/usr/share/plymouth/themes/atlasos"

# These checked-in files are the canonical build inputs. Do not regenerate
# them from ignored local JPGs: doing so makes clean clones non-reproducible
# and can overwrite a developer's locally customized branding.
required_assets=(
  "${UI_BRANDING}/atlas-primary.png"
  "${UI_BRANDING}/atlas-symbol.png"
  "${UI_BRANDING}/atlas-dashboard-footer.png"
  "${UI_BRANDING}/atlas-dashboard-landscape.png"
  "${UI_BRANDING}/atlas-dashboard-motto.png"
  "${ATLAS_BRANDING}/atlas-primary.svg"
  "${ATLAS_BRANDING}/atlas-symbol.svg"
  "${ATLAS_BRANDING}/atlas-symbol.png"
  "${ATLAS_BRANDING}/atlas-mono.svg"
  "${ATLAS_BRANDING}/atlas-boot.svg"
  "${ATLAS_BRANDING}/atlas-boot-bios.svg"
  "${PLYMOUTH_THEME}/atlas-logo.png"
  "${PLYMOUTH_THEME}/atlas-plymouth.svg"
  "${PLYMOUTH_THEME}/atlas-sweep-"*.png
  "${PLYMOUTH_THEME}/atlas-usb-message.png"
  "${PLYMOUTH_THEME}/atlas-usb-message.svg"
  "${PLYMOUTH_THEME}/atlasos.plymouth"
  "${PLYMOUTH_THEME}/atlasos.script"
)

is_git_checkout=0
if command -v git >/dev/null 2>&1 && git -C "${PROJECT_ROOT}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  is_git_checkout=1
fi

missing=()
untracked=()
for asset in "${required_assets[@]}"; do
  if [[ ! -s "${asset}" ]]; then
    missing+=("${asset#"${PROJECT_ROOT}"/}")
    continue
  fi

  if (( is_git_checkout )); then
    relative="${asset#"${PROJECT_ROOT}"/}"
    if ! git -C "${PROJECT_ROOT}" ls-files --error-unmatch -- "${relative}" >/dev/null 2>&1; then
      untracked+=("${relative}")
    fi
  fi
done

if (( ${#missing[@]} )); then
  echo 'Required tracked AtlasOS branding files are missing or empty:' >&2
  printf '  %s\n' "${missing[@]}" >&2
  exit 1
fi
if (( ${#untracked[@]} )); then
  echo 'Required AtlasOS branding files must be tracked by Git:' >&2
  printf '  %s\n' "${untracked[@]}" >&2
  exit 1
fi

printf 'Validated and reused %d AtlasOS branding files; no local JPG inputs required.\n' "${#required_assets[@]}"
