#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
PROFILE="${1:-release}"
missing=()
required=(lb debootstrap gpg mksquashfs xorriso grub-mkstandalone grub-file mformat mmd mcopy isohybrid magick rsvg-convert python3)
if [[ "${PROFILE}" == --dispatch-only ]]; then
  required=()
elif [[ "${PROFILE}" != --base ]]; then
  required+=(cargo rustc)
fi
printf 'AtlasOS build preflight\nroot=%s\n' "$ROOT"
if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  echo 'FAIL: supported build host is x86_64 Linux, preferably Ubuntu 26.04 in WSL2.' >&2
  exit 1
fi
if [[ -r /etc/os-release ]]; then . /etc/os-release; printf 'os=%s %s\n' "${ID:-unknown}" "${VERSION_ID:-unknown}"; fi
for tool in "${required[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf 'OK  %-18s %s\n' "$tool" "$(command -v "$tool")"
  else
    printf 'MISS %s\n' "$tool" >&2
    missing+=("$tool")
  fi
done
dispatch_test() {
  local dispatch_tmp before after fake_helper output
  dispatch_tmp="$(mktemp -d /tmp/atlasos-dispatch-smoke.XXXXXX)"
  case "${dispatch_tmp}" in /tmp/atlasos-dispatch-smoke.*) ;; *) echo 'Unsafe dispatcher temp path.' >&2; return 1 ;; esac
  trap 'case "${dispatch_tmp}" in /tmp/atlasos-dispatch-smoke.*) rm -rf -- "${dispatch_tmp}" ;; *) echo "Refusing unsafe cleanup: ${dispatch_tmp}" >&2 ;; esac' RETURN
  mkdir -p "${dispatch_tmp}/local/bin" "${dispatch_tmp}/local/live-build/functions"
  cp "${ROOT}/iso/live-build-dispatch.sh" "${dispatch_tmp}/local/bin/lb"
  chmod +x "${dispatch_tmp}/local/bin/lb"
  fake_helper="${dispatch_tmp}/local/helper"
  output="${dispatch_tmp}/output.txt"
  cat >"${fake_helper}" <<'HELPER'
#!/bin/sh
set -eu
unset LIVE_BUILD
. /usr/lib/live/build.sh
command -v Echo >/dev/null
Echo 'AtlasOS dispatcher smoke check' >/dev/null
printf 'ATLASOS_LOCAL_HELPER_SELECTED\n'
printf 'ARGS=%s\n' "$*"
HELPER
  chmod +x "${fake_helper}"
  before="$(sha256sum /usr/bin/lb /usr/lib/live/build.sh /usr/lib/live/build/lb_binary_syslinux)"
  if ! (cd "${dispatch_tmp}" && PATH="${dispatch_tmp}/local/bin:${PATH}" ATLASOS_LOCAL_LIVE_BUILD_HELPER="${fake_helper}" LIVE_BUILD=/deliberately/invalid lb binary_syslinux --probe) >"${output}" 2>&1; then
    cat "${output}" >&2
    echo 'FAIL project-local dispatcher did not complete.' >&2
    return 1
  fi
  grep -q '^ATLASOS_LOCAL_HELPER_SELECTED$' "${output}" || { cat "${output}" >&2; echo 'FAIL local helper was not selected.' >&2; return 1; }
  grep -q '^ARGS=--probe$' "${output}" || { cat "${output}" >&2; echo 'FAIL arguments were not preserved.' >&2; return 1; }
  if (cd "${dispatch_tmp}" && PATH="${dispatch_tmp}/local/bin:${PATH}" LIVE_BUILD=/deliberately/invalid lb --version) >/dev/null 2>&1; then
    :
  else
    echo 'FAIL standard live-build command did not delegate successfully.' >&2
    return 1
  fi
  if (cd "${dispatch_tmp}" && PATH="${dispatch_tmp}/local/bin:${PATH}" ATLASOS_LOCAL_LIVE_BUILD_HELPER="${dispatch_tmp}/missing" lb binary_syslinux --probe) >/dev/null 2>&1; then
    echo 'FAIL missing helper was incorrectly reported as success.' >&2
    return 1
  fi
  after="$(sha256sum /usr/bin/lb /usr/lib/live/build.sh /usr/lib/live/build/lb_binary_syslinux)"
  [[ "${before}" == "${after}" ]] || { echo 'FAIL system live-build files changed during smoke test.' >&2; return 1; }
  echo 'OK  project-local helper selected; Echo available; args and exit status preserved; /usr hashes unchanged'
}
if [[ "${PROFILE}" == --dispatch-only ]]; then
  dispatch_test && exit 0
  exit 1
fi
if command -v lb >/dev/null 2>&1 && [[ -f /usr/lib/live/build.sh ]]; then
  dispatch_test || { missing+=(live-build-local-dispatch); }
else
  echo 'MISS live-build dispatcher prerequisites' >&2
  missing+=(live-build-local-dispatch)
fi
if [[ "${PROFILE}" == --dispatch-only ]]; then
  :
elif [[ "${PROFILE}" == --base ]]; then
  echo 'INFO base profile: Rust/UEFI/asset-generator tools not required for this base-ISO stage.'
elif command -v rustup >/dev/null 2>&1; then
  rustup target list --installed | grep -qx x86_64-unknown-uefi || { echo 'MISS rust target x86_64-unknown-uefi' >&2; missing+=(x86_64-unknown-uefi); }
else
  echo 'MISS rustup (needed to inspect/install the UEFI target)' >&2
  missing+=(rustup)
fi
if [[ "${PROFILE}" != --base ]]; then
python3 -c 'import PIL; print("Pillow", PIL.__version__)' 2>/dev/null || { echo 'MISS Python Pillow' >&2; missing+=(Pillow); }
fi
if command -v qemu-system-x86_64 >/dev/null 2>&1; then echo "OK  qemu: $(qemu-system-x86_64 --version | head -1)"; else echo 'WARN QEMU unavailable; virtual boot validation cannot run.'; fi
free_kb="$(df -Pk "$ROOT" | awk 'NR==2 {print $4}')"
printf 'free_space_kib=%s (3,000,000 KiB / about 3 GiB minimum warning threshold)\n' "$free_kb"
if (( free_kb < 3000000 )); then echo 'WARN less than recommended 3 GiB free space.' >&2; fi
if (( ${#missing[@]} )); then
  printf 'PREFLIGHT FAIL: missing prerequisites: %s\n' "${missing[*]}" >&2
  exit 1
fi
echo 'PREFLIGHT PASS'
