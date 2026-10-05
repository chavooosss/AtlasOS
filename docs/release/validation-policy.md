# Release validation and support policy

## 0.6.2 evidence summary

### Physical validation — user-reported

One laptop was reported to boot the protected 0.6.2 Live USB in UEFI mode through Atlas Boot Manager, the invisible GRUB backend, Linux kernel/initramfs, Casper Live, Plymouth, and the Atlas desktop. This is evidence for that device and successful path only, not an independently reproduced lab result or a model-family qualification.

### Virtual validation

The separate G4.1 fresh integrated candidate passed its recorded ISO structural checks, 23/23 embedded manifest entries, and QEMU/OVMF boot to the Live desktop. This is not physical evidence for that candidate and does not transfer to the physical-validation ISO. G4.1 frontend builds differed in hash; package/repository inputs were not fully pinned, the integrated ISO was built once, and bit-for-bit reproducibility levels 2/3 are not claimed.

### Not validated / not established

- Secure Boot.
- A broad hardware or interactive-board matrix.
- New Legacy BIOS builds; Legacy BIOS is best-effort/currently unsupported or unvalidated for release gating.
- Installer, first boot provisioning, or in-place upgrade.
- Resolution, touch/stylus, network, audio, and peripheral behavior across devices.
- Exact source-to-binary reproducibility for the recommended physical ISO.
- The physical ISO's embedded manifest is fully inspected: 25 rows total, 22 pass and 3 fail (`EFI/BOOT/BOOTX64.EFI`, `boot/grub/efi.img`, `isolinux/boot.cat`). The failed EFI payloads match retained Phase 6 artifacts; `boot.cat` was regenerated after the El Torito layout changed. The manifest also omits `EFI/BOOT/ATLASGRUB.EFI`, `isolinux/isolinux.bin`, and El Torito boot-image entries. See [manifest decision 0003](decisions/0003-physical-iso-manifest.md). The exact whole-ISO SHA-256 is verified separately.
- Public redistribution rights for the exact historical installed packages/assets have not been established; that image contains Google Chrome and uncleared Atlas art/audio and is not a public binary candidate. A future clean candidate needs its own package/asset review. This is a publication blocker, not a boot-validation result.
- All GRUB backend failure paths and uninterrupted absence of GRUB on every outcome.

See the [physical test record](../validation/physical-0.6.2.md), [build integrity record](../validation/release-integrity.md), and [project status](../project/status.md) for detailed boundaries.

## Hardware language

AtlasOS is designed primarily for x86_64 classroom interactive-board environments. Say that current validation is limited to the specific recorded evidence. Do not claim universal smart-board, laptop, or firmware support.

## Boot policy

UEFI is the primary supported boot path. Legacy BIOS is best-effort and does not gate release checks; it is not supported or validated for new-build release claims. Secure Boot is not validated.

## Upgrade policy

0.6.2 has no established installer or in-place operating-system upgrade mechanism. Describe usage as a fresh Live image workflow; do not imply that user data or settings migrate between images.
