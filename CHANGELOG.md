# Changelog

This is a selected milestone summary, not a complete reconstruction of AtlasOS development. The project predates its public Git baseline; earlier changes are represented by dated artifacts and validation records, not backfilled commits.

## [Unreleased]

### Added

- Public product website and a curated product gallery rendered from the AtlasOS implementation.
- Public repository guidance for contributors and a clearer product-first documentation entry point.

### Changed

- Atlas system interfaces were refreshed with a consistent Atlas visual language, improved touch targets, responsive Quick Settings behavior, and custom Atlas controls.
- Release and validation documentation now distinguishes the public source repository from the unpublished ISO candidate.

## [0.6.3] - 2026-10-05 — Development Preview / Release Candidate

### Added

- Clean release-candidate build identity following the material package and asset cleanup from the historical 0.6.2 image.

### Changed

- Excluded the unresolved optional startup WAV from the staged Live image; the source asset remains preserved outside the proposed publication candidate.
- Integrated fresh Atlas Boot Manager and invisible GRUB backend builds into a distinct validation ISO.

### Validation

- Fresh build integrity and embedded-manifest checks passed; OVMF/QEMU reached the Live desktop.
- The project owner reported one physical UEFI Live test on a Casper Excalibur G870. This does not establish broad hardware compatibility.

## [0.6.2] — Development Preview / Physical Validation Build

- Integrated the Rust UEFI Atlas Boot Manager with the Live ISO boot path.
- Used GRUB as a backend during the documented successful normal UEFI path.
- The physical validation record reports boot through Casper Live and Plymouth to the Atlas desktop on one device; this result is user-reported.
- Added or refined Atlas desktop, dock/window tracking, display presentation modes, and Developer Center diagnostics as documented in current component status.
- Secure Boot, physical Legacy BIOS, broad hardware compatibility, and all boot-backend failure paths remain unvalidated.

See [validation records](docs/testing/README.md), [component status](docs/project/status.md), and [release status](docs/release/README.md) for scope and caveats. The 0.6.2 section is retained as historical evidence and is not a claim that the old binary is a current public release.
