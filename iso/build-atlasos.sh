#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${PROJECT_ROOT}/dist"
DEFAULT_VERSION="$(tr -d '[:space:]' < "${PROJECT_ROOT}/VERSION")"
ATLAS_VERSION="${ATLASOS_VERSION:-${DEFAULT_VERSION}}"
ISO_NAME="${ATLASOS_ISO_NAME:-AtlasOS-${ATLAS_VERSION}-live-amd64.iso}"
LATEST_DIR="${ATLASOS_OUTPUT_DIR:-${DIST_DIR}/AtlasOS-${ATLAS_VERSION}}"
DRY_RUN=0
CLEAN=0
RELEASE="resolute"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --clean) CLEAN=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: bash iso/build-atlasos.sh [--dry-run] [--clean]
Environment: ATLASOS_VERSION, ATLASOS_OUTPUT_DIR, ATLASOS_ISO_NAME, ATLASOS_BUILD_DIR.
This entry point builds the base Live ISO; Atlas Boot Manager integration is separate.
EOF
      exit 0
      ;;
    *) echo "Unknown argument: $arg" >&2; exit 64 ;;
  esac
done
if [[ ! "${ATLAS_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$ ]]; then
  echo "ATLASOS_VERSION must be a version such as 0.6.2: ${ATLAS_VERSION}" >&2
  exit 64
fi
if [[ "${ISO_NAME}" == */* || "${ISO_NAME}" != *.iso || "${ISO_NAME}" == ".iso" ]]; then
  echo "ATLASOS_ISO_NAME must be a plain .iso filename: ${ISO_NAME}" >&2
  exit 64
fi

if [[ "${PROJECT_ROOT}" == /mnt/* ]]; then
  BUILD_DIR="${ATLASOS_BUILD_DIR:-${HOME}/.cache/atlasos/live-build}"
else
  BUILD_DIR="${ATLASOS_BUILD_DIR:-${PROJECT_ROOT}/build/live-build}"
fi

# Canonicalize and constrain all writable paths before creating or deleting anything.
PROJECT_ROOT="$(realpath -e "${PROJECT_ROOT}")"
DIST_DIR="$(realpath -m "${PROJECT_ROOT}/dist")"
CACHE_ROOT="$(realpath -m "${HOME}/.cache/atlasos")"
[[ "${BUILD_DIR}" == /* ]] || { echo "ATLASOS_BUILD_DIR must be absolute: ${BUILD_DIR}" >&2; exit 64; }
BUILD_DIR="$(realpath -m "${BUILD_DIR}")"
[[ "${LATEST_DIR}" == /* ]] || LATEST_DIR="${PROJECT_ROOT}/${LATEST_DIR}"
LATEST_DIR="$(realpath -m "${LATEST_DIR}")"
case "${BUILD_DIR}/" in
  "${PROJECT_ROOT}/build/"*|"${CACHE_ROOT}/"*) ;;
  *) echo "Refusing unsafe ATLASOS_BUILD_DIR outside approved build roots: ${BUILD_DIR}" >&2; exit 64 ;;
esac
[[ "${BUILD_DIR}" != / && "${BUILD_DIR}" != "${HOME}" && "${BUILD_DIR}" != "${PROJECT_ROOT}" ]] || { echo "Refusing unsafe build path: ${BUILD_DIR}" >&2; exit 64; }
case "${LATEST_DIR}/" in
  "${DIST_DIR}/"*) ;;
  *) echo "Refusing ATLASOS_OUTPUT_DIR outside project dist/: ${LATEST_DIR}" >&2; exit 64 ;;
esac
[[ "${LATEST_DIR}" != "${DIST_DIR}" && "${LATEST_DIR}" != / ]] || { echo "Refusing unsafe output path: ${LATEST_DIR}" >&2; exit 64; }
LATEST_ISO="${LATEST_DIR}/${ISO_NAME}"
if [[ -e "${LATEST_ISO}" || -e "${LATEST_ISO}.sha256" || -e "${LATEST_DIR}/SHA256SUMS.txt" || -e "${LATEST_DIR}/BUILD-INFO.txt" ]]; then
  echo "Output already exists; choose a new ATLASOS_ISO_NAME or ATLASOS_OUTPUT_DIR: ${LATEST_ISO}" >&2
  exit 73
fi
if [[ "${ATLASOS_ENABLE_LEGACY_HOST_PATCH:-0}" == "1" ]]; then
  echo "Legacy host patch is unsupported and unsafe; the normal path uses a project-local helper." >&2
  exit 64
fi
if (( DRY_RUN )); then
  printf 'AtlasOS base ISO plan\nversion=%s\nrelease=%s\nenvironment=%s %s\nbuild_dir=%s\noutput=%s\nlegacy_host_patch=disabled\nclean=%s\nstages=preflight, workspace, branding, live-build config, bootstrap, chroot, binary, UEFI image, embedded SHA256SUMS, hybrid ISO, external checksum/report\n' \
    "${ATLAS_VERSION}" "${RELEASE}" "$(. /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-Linux}")" "$(uname -m)" "${BUILD_DIR}" "${LATEST_ISO}" "${CLEAN}"
  exit 0
fi

bash "${PROJECT_ROOT}/iso/check-build-env.sh" --base

REQUIRED_TOOLS=(
  lb
  curl
  debootstrap
  gpg
  mksquashfs
  xorriso
  grub-mkstandalone
  mformat
  mmd
  mcopy
  isohybrid
  magick
  rsvg-convert
)

missing=()
for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    missing+=("${tool}")
  fi
done

if (( ${#missing[@]} > 0 )); then
  cat >&2 <<'EOF'
AtlasOS build tools are missing.

Run this inside WSL Ubuntu 26.04:

  sudo apt update
  sudo apt install -y live-build debootstrap squashfs-tools xorriso \
    grub-pc-bin grub-efi-amd64-bin mtools isolinux syslinux-common \
    syslinux-utils imagemagick librsvg2-bin

Then run:

  bash iso/build-atlasos.sh
EOF
  printf 'Missing tools: %s\n' "${missing[*]}" >&2
  exit 1
fi


mkdir -p "${BUILD_DIR}/config" "${DIST_DIR}" "${LATEST_DIR}"

create_uefi_boot_image() {
  local binary_dir="$1"
  local efi_work="${BUILD_DIR}/efi"
  local grub_cfg="${efi_work}/grub.cfg"
  local bootx64="${efi_work}/BOOTX64.EFI"
  local efi_img="${binary_dir}/boot/grub/efi.img"

  rm -rf "${efi_work}"
  mkdir -p "${efi_work}" "${binary_dir}/boot/grub" "${binary_dir}/EFI/BOOT"
  cp "${PROJECT_ROOT}/iso/grub-console.cfg" "${grub_cfg}"

  grub-mkstandalone \
    -O x86_64-efi \
    -o "${bootx64}" \
    "boot/grub/grub.cfg=${grub_cfg}"

  rm -f "${efi_img}"
  truncate -s 10M "${efi_img}"
  mformat -i "${efi_img}" -c 1 ::
  mmd -i "${efi_img}" ::/EFI ::/EFI/BOOT
  mcopy -i "${efi_img}" "${bootx64}" ::/EFI/BOOT/BOOTX64.EFI
  cp "${bootx64}" "${binary_dir}/EFI/BOOT/BOOTX64.EFI"
}

create_hybrid_iso() {
  local binary_dir="$1"
  local output_iso="$2"

  create_uefi_boot_image "${binary_dir}"

  # Refresh checksums after the UEFI boot image is final.
  (
    cd "${binary_dir}"
    # xorriso patches isolinux.bin with an ISO-specific boot-info table.
    find . -type f ! -name SHA256SUMS ! -path ./isolinux/isolinux.bin -print0 \
      | LC_ALL=C sort -z \
      | xargs -0 sha256sum > SHA256SUMS
  )

  xorriso -as mkisofs \
    -r -J -joliet-long -l \
    -V "ATLASOS_${ATLAS_VERSION//./}" \
    -A "AtlasOS Live Demo" \
    -publisher "AtlasOS Project" \
    -p "AtlasOS Project" \
    -o "${output_iso}" \
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
    -append_partition 2 0xef "${binary_dir}/boot/grub/efi.img" \
    "${binary_dir}"
}

assert_output_available() {
  if [[ -e "${LATEST_ISO}" || -e "${LATEST_ISO}.sha256" || -e "${LATEST_DIR}/SHA256SUMS.txt" || -e "${LATEST_DIR}/BUILD-INFO.txt" ]]; then
    echo "Output already exists; choose a new ATLASOS_ISO_NAME or ATLASOS_OUTPUT_DIR: ${LATEST_ISO}" >&2
    return 1
  fi
}

write_build_metadata() {
  local iso_hash iso_size build_time
  iso_hash="$(sha256sum "${LATEST_ISO}" | awk '{print $1}')"
  iso_size="$(stat -c %s "${LATEST_ISO}")"
  build_time="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s  %s\n' "${iso_hash}" "${ISO_NAME}" > "${LATEST_ISO}.sha256"
  printf '%s  %s\n' "${iso_hash}" "${ISO_NAME}" > "${LATEST_DIR}/SHA256SUMS.txt"
  cat > "${LATEST_DIR}/BUILD-INFO.txt" <<EOF
AtlasOS version: ${ATLAS_VERSION}
Build profile: base-live-iso (not Atlas Boot Manager integrated)
Build time UTC: ${build_time}
Build environment: $(. /etc/os-release 2>/dev/null; printf '%s %s' "${PRETTY_NAME:-Linux}" "$(uname -m)")
Source identifier: unavailable (Git not initialized)
Build options: ATLASOS_PACKAGE_ONLY=${ATLASOS_PACKAGE_ONLY:-0}
live-build: $(lb --version 2>&1 | head -1)
xorriso: $(xorriso -version 2>&1 | head -1)
Legacy host patch: disabled
Output: ${ISO_NAME}
Output size bytes: ${iso_size}
Output SHA-256: ${iso_hash}
Validation: ISO mastered; structural and QEMU validation not implied
EOF
  printf 'Build report: %s\nISO size: %s bytes\nSHA-256: %s\n' "${LATEST_DIR}/BUILD-INFO.txt" "${iso_size}" "${iso_hash}"
}

assert_output_available

if [[ "${ATLASOS_PACKAGE_ONLY:-0}" == "1" ]]; then
  cd "${BUILD_DIR}"
  if [[ ! -d "${BUILD_DIR}/binary" ]]; then
    echo "No prepared binary directory was found in ${BUILD_DIR}" >&2
    exit 1
  fi
  sudo chown -R "$(id -u):$(id -g)" "${BUILD_DIR}/binary"
  create_hybrid_iso "${BUILD_DIR}/binary" "${LATEST_ISO}"
  write_build_metadata
  echo "AtlasOS ISO created: ${LATEST_ISO}"
  exit 0
fi

if (( CLEAN )) && [[ -d "${BUILD_DIR}" ]]; then
  case "${BUILD_DIR}/" in
    "${PROJECT_ROOT}/build/"*|"${CACHE_ROOT}/"*) ;;
    *) echo "Refusing cleanup outside approved build roots: ${BUILD_DIR}" >&2; exit 64 ;;
  esac
  [[ "${BUILD_DIR}" != / && "${BUILD_DIR}" != "${HOME}" && "${BUILD_DIR}" != "${PROJECT_ROOT}" ]] || { echo "Refusing unsafe cleanup target: ${BUILD_DIR}" >&2; exit 64; }
  find "${BUILD_DIR}" -mindepth 1 -maxdepth 1 ! -name cache -exec rm -rf -- {} +
fi
mkdir -p "${BUILD_DIR}/config" "${DIST_DIR}" "${LATEST_DIR}"

bash "${PROJECT_ROOT}/iso/prepare-branding-assets.sh"

cp -a "${PROJECT_ROOT}/config/package-lists" "${BUILD_DIR}/config/"
cp -a "${PROJECT_ROOT}/config/includes.chroot" "${BUILD_DIR}/config/"
# The startup WAV is excluded from the public candidate until its provider
# plan, attribution, and source/sample provenance are confirmed. Preserve the
# source-tree file; omit only the optional sound from this staged Live image.
rm -f "${BUILD_DIR}/config/includes.chroot/usr/local/share/atlasos/ui/sounds/atlasos-startup.wav"
PLYMOUTH_THEME_DIR="${BUILD_DIR}/config/includes.chroot/usr/share/plymouth/themes/atlasos"
mkdir -p "${PLYMOUTH_THEME_DIR}"
rsvg-convert -w 1200 -h 112 \
  "${PLYMOUTH_THEME_DIR}/atlas-usb-message.svg" \
  -o "${PLYMOUTH_THEME_DIR}/atlas-usb-message.png"
rm -f \
  "${BUILD_DIR}/config/includes.chroot/usr/share/atlasos/branding/atlas-primary.svg" \
  "${BUILD_DIR}/config/includes.chroot/usr/share/atlasos/branding/atlas-mono.svg" \
  "${BUILD_DIR}/config/includes.chroot/usr/share/atlasos/branding/atlas-boot.svg" \
  "${BUILD_DIR}/config/includes.chroot/usr/share/atlasos/branding/atlas-symbol.svg" \
  "${BUILD_DIR}/config/includes.chroot/usr/local/share/atlasos/ui/branding/atlas-symbol.svg" \
  "${PLYMOUTH_THEME_DIR}/atlas-plymouth.svg"
rm -rf "${BUILD_DIR}/config/hooks"
mkdir -p "${BUILD_DIR}/config/hooks"
while IFS= read -r hook; do
  cp "${hook}" "${BUILD_DIR}/config/hooks/"
done < <(find "${PROJECT_ROOT}/config/hooks" -type f -name '*.hook.chroot')
find "${BUILD_DIR}/config/hooks" -type f -name '*.hook.*' -exec chmod +x {} \;

# Ubuntu live-build compatibility edits stay in a project-local helper copy.
# The project-local PATH shim intercepts only binary_syslinux; all normal
# stages retain /usr/bin/lb's standard library initialization.
LOCAL_LIVE_BUILD="${BUILD_DIR}/local/live-build"
LOCAL_BIN="${BUILD_DIR}/local/bin"
LOCAL_HELPER="${LOCAL_LIVE_BUILD}/scripts/build/lb_binary_syslinux"
mkdir -p "${LOCAL_BIN}" "${LOCAL_LIVE_BUILD}/scripts/build"
cp "${PROJECT_ROOT}/iso/live-build-dispatch.sh" "${LOCAL_BIN}/lb"
chmod +x "${LOCAL_BIN}/lb"
cp /usr/lib/live/build/lb_binary_syslinux "${LOCAL_HELPER}"
python3 - "${LOCAL_HELPER}" <<'PY'
from pathlib import Path
import sys

helper = Path(sys.argv[1])
text = helper.read_text()
broken = '( . "${LIVE_BUILD}/scripts/build.sh" > /dev/null 2>&1 || true ) || . /usr/lib/live/build.sh'
fixed = 'unset LIVE_BUILD\n. /usr/lib/live/build.sh'
if text.count(broken) != 1:
    raise SystemExit('Expected exactly one live-build init block in copied lb_binary_syslinux')
helper.write_text(text.replace(broken, fixed, 1))
PY
sed -i \
  -e 's|binary/live/vmlinuz|binary/casper/vmlinuz|g' \
  -e 's|binary/live/initrd|binary/casper/initrd|g' \
  -e 's|/live/vmlinuz|/casper/vmlinuz|g' \
  -e 's|/live/initrd|/casper/initrd|g' \
  -e 's|${_SUFFIX}/live.cfg|${_TARGET}/live.cfg|g' \
  -e 's|chroot/usr/bin/rsvg librsvg2-bin|chroot/usr/bin/rsvg-convert librsvg2-bin|g' \
  -e 's|/usr/bin/rsvg - no such file|/usr/bin/rsvg-convert - no such file|g' \
  -e 's|! -e /usr/bin/rsvg|! -e /usr/bin/rsvg-convert|g' \
  -e 's|"rsvg --format png --height 480 --width 640 splash.svg splash.png"|"rsvg-convert -f png -h 480 -w 640 -o splash.png splash.svg"|g' \
  -e 's|rsvg --format png --height 480 --width 640 "${_TARGET}/splash.svg" "${_TARGET}/splash.png"|rsvg-convert -f png -h 480 -w 640 -o "${_TARGET}/splash.png" "${_TARGET}/splash.svg"|g' \
  "${LOCAL_LIVE_BUILD}/scripts/build/lb_binary_syslinux"
chmod +x "${LOCAL_LIVE_BUILD}/scripts/build/lb_binary_syslinux"

# Exercise the exact project-local dispatcher before any build cleanup or
# live-build stage. The fixture writes only under its temporary /tmp directory.
bash "${PROJECT_ROOT}/iso/check-build-env.sh" --dispatch-only
export ATLASOS_LOCAL_LIVE_BUILD_HELPER="${LOCAL_HELPER}"
export PATH="${LOCAL_BIN}:${PATH}"

# Ubuntu 26.04 ships syslinux files in newer locations than the live-build
# isolinux template expects. Generate a build-local template with regular files
# so live-build does not chase stale symlinks inside the chroot.
BOOTLOADER_DIR="${BUILD_DIR}/config/bootloaders/isolinux"
mkdir -p "${BOOTLOADER_DIR}"
cp -a /usr/share/live/build/bootloaders/isolinux/. "${BOOTLOADER_DIR}/"
rm -f "${BOOTLOADER_DIR}/isolinux.bin" "${BOOTLOADER_DIR}/vesamenu.c32" "${BOOTLOADER_DIR}/ldlinux.c32"
cp /usr/lib/ISOLINUX/isolinux.bin "${BOOTLOADER_DIR}/isolinux.bin"
cp /usr/lib/syslinux/modules/bios/vesamenu.c32 "${BOOTLOADER_DIR}/vesamenu.c32"
cp /usr/lib/syslinux/modules/bios/ldlinux.c32 "${BOOTLOADER_DIR}/ldlinux.c32"
cp /usr/lib/syslinux/modules/bios/libcom32.c32 "${BOOTLOADER_DIR}/libcom32.c32"
cp /usr/lib/syslinux/modules/bios/libutil.c32 "${BOOTLOADER_DIR}/libutil.c32"
cp /usr/lib/syslinux/modules/bios/menu.c32 "${BOOTLOADER_DIR}/menu.c32"
(
  tmp_bootlogo="$(mktemp -d)"
  trap 'rm -rf "${tmp_bootlogo}"' EXIT
  : | (cd "${tmp_bootlogo}" && cpio --quiet -o -H newc) > "${BOOTLOADER_DIR}/bootlogo"
)
mkdir -p "${BUILD_DIR}/config/includes.chroot/usr/share/gfxboot-theme-ubuntu"
tar -czf "${BUILD_DIR}/config/includes.chroot/usr/share/gfxboot-theme-ubuntu/bootlogo.tar.gz" -T /dev/null

cd "${BUILD_DIR}"

if [[ -d chroot ]]; then
  sudo rm -rf chroot/binary chroot/binary.hybrid.iso chroot/live-image-*.iso
fi

lb config \
  --mode ubuntu \
  --distribution "${RELEASE}" \
  --architectures amd64 \
  --archive-areas "main restricted universe multiverse" \
  --mirror-bootstrap "http://archive.ubuntu.com/ubuntu/" \
  --mirror-chroot "http://archive.ubuntu.com/ubuntu/" \
  --mirror-chroot-security "http://security.ubuntu.com/ubuntu/" \
  --mirror-binary "http://archive.ubuntu.com/ubuntu/" \
  --mirror-binary-security "http://security.ubuntu.com/ubuntu/" \
  --cache true \
  --cache-stages bootstrap \
  --source false \
  --binary-images iso-hybrid \
  --debian-installer false \
  --memtest none \
  --syslinux-theme live-build \
  --iso-application "AtlasOS Live Demo" \
  --iso-preparer "AtlasOS Project" \
  --iso-publisher "AtlasOS Project" \
  --iso-volume "ATLASOS_${ATLAS_VERSION//./}" \
  --bootappend-live "boot=casper username=atlas hostname=atlasos locales=tr_TR.UTF-8 keyboard-layouts=tr keyboard-configuration/layoutcode=tr console-setup/layoutcode=tr timezone=Europe/Istanbul quiet splash vt.handoff=7"

echo "[5/10] live-build bootstrap"
sudo env PATH="${PATH}" ATLASOS_LOCAL_LIVE_BUILD_HELPER="${LOCAL_HELPER}" lb bootstrap
echo "[6/10] live-build chroot"
sudo env PATH="${PATH}" ATLASOS_LOCAL_LIVE_BUILD_HELPER="${LOCAL_HELPER}" lb chroot
echo "[7/10] live-build binary"
sudo env PATH="${PATH}" ATLASOS_LOCAL_LIVE_BUILD_HELPER="${LOCAL_HELPER}" lb binary

if [[ ! -d "${BUILD_DIR}/binary" ]]; then
  echo "Build finished, but no binary directory was found in ${BUILD_DIR}" >&2
  exit 1
fi

sudo chown -R "$(id -u):$(id -g)" "${BUILD_DIR}/binary"
if [[ ! -f "${BUILD_DIR}/binary/isolinux/isolinux.cfg" ]]; then
  echo "BIOS boot menu was not generated." >&2
  exit 1
fi
rsvg-convert -w 640 -h 480 \
  "${BUILD_DIR}/config/includes.chroot/usr/share/atlasos/branding/atlas-boot-bios.svg" \
  -o "${BUILD_DIR}/binary/isolinux/splash.png"
magick "${BUILD_DIR}/binary/isolinux/splash.png" \
  \( "${BUILD_DIR}/config/includes.chroot/usr/share/atlasos/branding/atlas-symbol.png" -resize 156x156 \) \
  -geometry +438+68 -composite "${BUILD_DIR}/binary/isolinux/splash-with-mark.png"
mv "${BUILD_DIR}/binary/isolinux/splash-with-mark.png" "${BUILD_DIR}/binary/isolinux/splash.png"
cat >"${BUILD_DIR}/binary/isolinux/isolinux.cfg" <<'SYSLINUX'
UI vesamenu.c32
PROMPT 0
TIMEOUT 50
DEFAULT atlasos
ONTIMEOUT atlasos
MENU TITLE AtlasOS ${ATLAS_VERSION}
MENU RESOLUTION 640 480
MENU BACKGROUND splash.png
MENU WIDTH 64
MENU MARGIN 2
MENU ROWS 5
MENU TABMSG Tab ile secenekleri duzenleyebilirsiniz.
MENU AUTOBOOT AtlasOS # saniye icinde basliyor...
MENU COLOR screen 0 #ff17334d #00000000 none
MENU COLOR border 0 #00000000 #00000000 none
MENU COLOR title 0 #ff17334d #00000000 none
MENU COLOR sel 0 #ffffffff #ee087fa7 none
MENU COLOR unsel 0 #ff17334d #00000000 none
MENU COLOR timeout_msg 0 #ff42647c #00000000 none
MENU COLOR tabmsg 0 #ff42647c #00000000 none
MENU COLOR help 0 #ff42647c #00000000 none
LABEL atlasos
  MENU LABEL AtlasOS Live baslat
  MENU DEFAULT
  KERNEL /casper/vmlinuz
  APPEND initrd=/casper/initrd.img boot=live config boot=casper username=atlas hostname=atlasos locales=tr_TR.UTF-8 keyboard-layouts=tr keyboard-configuration/layoutcode=tr console-setup/layoutcode=tr timezone=Europe/Istanbul quiet splash vt.handoff=7
LABEL atlasos-safe
  MENU LABEL Guvenli grafik modunda baslat
  KERNEL /casper/vmlinuz
  APPEND initrd=/casper/initrd.img boot=live config boot=casper username=atlas hostname=atlasos locales=tr_TR.UTF-8 keyboard-layouts=tr keyboard-configuration/layoutcode=tr console-setup/layoutcode=tr timezone=Europe/Istanbul quiet splash vt.handoff=7 nomodeset
SYSLINUX
echo "[8/10] base ISO, embedded manifest, BIOS/UEFI mastering"
create_hybrid_iso "${BUILD_DIR}/binary" "${LATEST_ISO}"
echo "[9/10] external checksum and build metadata"
write_build_metadata
echo "[10/10] base ISO created: ${LATEST_ISO}"
