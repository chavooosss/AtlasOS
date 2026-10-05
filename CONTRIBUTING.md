# Contributing to AtlasOS

AtlasOS is a pre-publication development project. The repository is not yet public and external contributions are not currently open. This document records the lightweight expectations to use when contribution access is enabled.

## Before a large change

For substantial architecture or product changes, open an issue or discussion first once a public project channel exists. Explain the user problem, proposed scope, affected components, and how the result can be validated. Small fixes may be submitted with a concise description and evidence.

## Source layout

- Atlas desktop and runtime integration: **config/**.
- UEFI Atlas Boot Manager: **atlas-boot/**.
- ISO build and integration tools: **iso/**.
- Tests and validation helpers: **tests/**.
- Curated engineering documentation: **docs/**.

Generated ISO files, EFI binaries, VM images, test captures, extracted filesystems, logs, and diagnostics bundles should not be committed.

## Change expectations

- Keep claims aligned with the current implementation and evidence. Distinguish source inspection, virtual tests, and physical results.
- For Python or shell changes, run the relevant focused unit or syntax checks where available.
- For Rust boot-manager changes, include relevant formatting/build/test evidence and identify the firmware mode used.
- UI changes should include a current screenshot or render comparison when it can be captured without personal information.
- Boot, kernel, initramfs, GRUB, Plymouth, or firmware-path changes need explicit boot validation. QEMU evidence must be labeled virtual; physical claims require recorded hardware results.
- Preserve storage-safety and privacy boundaries in diagnostics and removable-media code.
- Review third-party licensing and asset provenance before adding redistributed material.

The project-wide license is not yet selected. Do not assume that the Rust package license applies to the entire tree.