# Contributing to AtlasOS

AtlasOS is a public development-preview project. Contributions are welcome through public GitHub issues and pull requests; changes are reviewed before merge. For a substantial product or architecture proposal, open an issue first to agree on the problem and scope.

## Where to start

- Desktop and packaged runtime integration: `config/`
- UEFI Atlas Boot Manager: `atlas-boot/`
- ISO build and integration tools: `iso/`
- Tests and validation helpers: `tests/`
- Curated engineering and product documentation: `docs/`

Check [project status](docs/project/status.md), [architecture](docs/architecture/overview.md), and the [roadmap](ROADMAP.md) before taking on a larger change.

## Pull requests

Keep each PR focused. Explain the user problem, affected components, and how you checked the change. Match claims to evidence: distinguish source inspection, virtual checks, and owner-reported physical tests.

- Python and shell changes: run the relevant focused tests or syntax checks.
- Rust boot changes: include formatting, test/build evidence, and the firmware mode used.
- UI changes: include a current screenshot or render comparison when practical; remove personal and device-identifying information.
- Boot, kernel, initramfs, GRUB, Plymouth, or firmware changes: describe the boot path tested. Label QEMU evidence as virtual; physical claims need an artifact- and device-specific record.
- Diagnostics and removable-media changes: preserve storage-safety and privacy boundaries.
- Generated ISO files, EFI binaries, VM disks, extracted filesystems, build outputs, raw logs, and diagnostics bundles do not belong in Git history.

## Licensing and assets

The root [MIT license](LICENSE) covers AtlasOS-owned code within the scope described in [project license scope](docs/legal/project-license-scope.md). `atlas-boot` retains its own `MIT OR Apache-2.0` crate declaration. Third-party packages, fonts, icons, marks, and other assets keep their original terms. Include provenance and redistribution information for new assets; do not assume that a file’s presence means it is cleared for distribution.

## Validation boundary

The required CI checks cover source and policy checks, not a complete OS build or hardware matrix. Full ISO builds and physical validation remain separate release activities. See [CI and quality gates](docs/development/ci.md) and the [testing guide](docs/testing/README.md).
