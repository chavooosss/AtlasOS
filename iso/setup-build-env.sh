#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]] || ! grep -qiE 'ubuntu|microsoft' /etc/os-release; then
  echo 'Use x86_64 Ubuntu 26.04 in WSL2 (or a disposable Ubuntu 26.04 VM).' >&2
  exit 64
fi
if [[ "${EUID}" -eq 0 ]]; then
  echo 'Run this as a normal user; sudo will be used only for apt package installation.' >&2
  exit 64
fi
sudo -v
sudo apt-get update
sudo apt-get install -y \
  live-build debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin \
  mtools isolinux syslinux-common syslinux-utils imagemagick librsvg2-bin \
  python3 python3-pil curl gnupg cpio tar xz-utils dosfstools e2fsprogs \
  qemu-system-x86 ovmf
cat <<'EOF'
System packages installed. Install Rust through the official rustup procedure,
then select the project's documented stable toolchain and run:
  rustup target add x86_64-unknown-uefi
No AtlasOS source, /usr build helper, or host executable was patched.
EOF
