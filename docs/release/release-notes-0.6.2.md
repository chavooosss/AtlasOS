# AtlasOS 0.6.2 — Development Preview

**Release maturity:** Development Preview  
**Release description:** Physical Validation Build  
**Architecture:** x86_64  
**Historical artifact:** `AtlasOS-0.6.2-live-amd64.iso` (not offered for public download)

## Overview

AtlasOS is an Ubuntu-based Live Linux environment with an education-focused Atlas desktop and UEFI boot experience. Version 0.6.2 is a development preview. Physical boot evidence is user-reported for one laptop; this release is not a broad hardware qualification.

## Highlights

- Atlas desktop shell with classroom-oriented navigation, lesson tools, settings, and local resource shortcuts.
- Rust-based Atlas Boot Manager frontend for the UEFI path, with GRUB used as a backend in the documented successful normal boot path.
- Atlas session components for dock/window tracking, audio controls, presentation modes, and diagnostics; individual hardware behavior remains device-dependent.
- Build, integrity, and CI quality checks are documented for ongoing development.

## What is included

An x86_64 Ubuntu-based Live system. Resource entries are shortcuts/local catalog data; official MEB/EBA/OGM/MEBİ service integration is not established. No installer or first-boot provisioning is included.

## Validation

- **Physical:** one laptop UEFI Live boot to the Atlas desktop, user-reported for the exact historical physical-validation ISO.
- **Virtual:** a separate G4.1 fresh candidate reached the Live desktop in QEMU/OVMF; its evidence does not apply to this physical ISO.
- See `VALIDATION.md` for detailed scope and limitations.

## Supported boot path

UEFI is the primary supported path. Legacy BIOS is best-effort and currently unsupported/unvalidated for new-build release gating. Secure Boot is not validated.

## Known limitations

- No installer, provisioning flow, or established in-place upgrade path.
- No broad interactive-board or laptop compatibility matrix.
- Touch, stylus, display resolution, networking, audio, and peripherals require target-device validation.
- GRUB may be visible on backend failure paths.
- The selected physical ISO is a protected historical artifact and is not claimed to be a bit-for-bit build from the current source baseline.
- The physical ISO's embedded `SHA256SUMS` has 25 rows: 22 pass and 3 stale rows fail (`EFI/BOOT/BOOTX64.EFI`, `boot/grub/efi.img`, `isolinux/boot.cat`). The observed EFI payloads match retained Phase 6 artifacts, and the catalog was regenerated during ISO mastering. The embedded list also omits boot-critical files including `EFI/BOOT/ATLASGRUB.EFI`; it must not be described as passing. If ever published, disclose this and verify the whole ISO with its separate external SHA-256.
- The protected historical physical 0.6.2 ISO contains Google Chrome 154.0.8037.97-1 and rights-uncleared Atlas-specific artwork/audio. It is not a public download candidate and will not be uploaded as the first public ISO. Its recorded package contents and validation remain historical facts.
- Future public build configuration removes Chrome and Google's repository/key. A future clean candidate must use cleared or replacement branding/audio, include an exact package inventory and required notices/source references, and undergo its own physical validation. No Chromium package is selected yet; Ubuntu Resolute's `chromium-browser` package is a Snap transition and the current Live build has no verified Snap provisioning/offline behavior.
- Source code is licensed MIT only where AtlasOS owns the code. In the later publication candidate, the project owner has attested to AI generation and authorized project distribution of reviewed Atlas visual assets; provider terms remain unverified and the optional startup WAV plus branded UI reference screenshots remain excluded. See the [AI asset policy](../legal/ai-generated-assets.md), [provenance record](../legal/asset-provenance-attestation.md), [asset inventory](../legal/asset-inventory.json), and [license scope](../legal/project-license-scope.md). This later source review does not change the historical 0.6.2 ISO's rights status.

## Live usage note

This image is a Live system. No in-place upgrade is provided. Use only after verifying the downloaded ISO checksum and selecting the intended boot device.

## Integrity verification

Use `SHA256SUMS.txt` with `sha256sum -c SHA256SUMS.txt` on Linux. On PowerShell, compare `Get-FileHash .\AtlasOS-0.6.2-live-amd64.iso -Algorithm SHA256` against the published release manifest/checksum.

## Upgrade notes

There is no supported in-place upgrade workflow in 0.6.2. A future installer or provisioning process must define migration behavior.

## Upstream foundation

AtlasOS is built on Ubuntu and includes upstream Linux, GRUB, Casper, Plymouth, XFCE/XFWM4, Qt/PySide6, and other packages. AtlasOS does not claim ownership of upstream software or official MEB endorsement. See the repository's third-party inventory and notices before redistribution.

## Reporting issues

Report reproducible issues with AtlasOS version, device model, CPU/GPU, boot mode, display resolution, Live/installed state, and steps. Do not include serial numbers, MAC addresses, student data, or private identifiers.
