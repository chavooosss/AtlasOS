# Changelog

## [0.6.3] - 2026-10-05

### Added
- Clean release-candidate build identity for the material package and asset cleanup after the historical 0.6.2 image.

### Changed
- Release build excludes the unresolved optional startup WAV from the staged Live image; source asset remains preserved and outside the proposed publication candidate.
- Fresh RC integrates newly built Atlas Boot Manager and invisible GRUB backend into a distinct validation ISO.

### Validation
- Fresh build integrity and embedded-manifest checks passed; OVMF/QEMU reached the Live desktop.
- One physical UEFI Live test on a Casper Excalibur G870 was reported by the project owner; this does not establish broad hardware compatibility.

This is a selected milestone summary based on retained project records. It is not a complete release history, and it does not reconstruct a missing Git history.

## [Unreleased]

### Added

- Release engineering policies and release-candidate metadata are being prepared before publication.
- Tiered CI and repository quality checks are documented in [CI policy](docs/development/ci.md).

## [0.6.2] — Development Preview / Physical Validation Build

- Integrates the Rust UEFI Atlas Boot Manager with the Live ISO boot path.
- Uses GRUB as a backend during the documented successful normal UEFI path.
- The physical validation record reports boot through Casper Live and Plymouth to the Atlas desktop on one device; this result is user-reported.
- Adds or refines Atlas desktop, dock/window tracking, display presentation modes, and Developer Center diagnostics as documented in current component status.
- Secure Boot, physical Legacy BIOS, broad hardware compatibility, and all boot-backend failure paths remain unvalidated.

See [physical validation](docs/validation/physical-0.6.2.md), [component status](docs/project/status.md), and [release integrity](docs/validation/release-integrity.md) for scope and caveats. This is a selected milestone summary, not a reconstructed complete history; the project did not have Git history for these earlier changes.
