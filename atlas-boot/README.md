# Atlas Boot Manager

Atlas Boot Manager is a Rust UEFI application that provides a graphical Atlas interface before the Live operating system starts.

## Current role

The application uses UEFI Graphics Output Protocol (GOP) to render the menu with Atlas artwork and embedded bitmap glyph assets. It handles keyboard navigation and a timed countdown, then loads and starts the backend EFI application from the same boot device. In the integrated 0.6.2 successful normal UEFI path, the backend is GRUB and its menu is not displayed.

This behavior is not guaranteed for every error path: the frontend reports backend errors and firmware/backend diagnostics may become visible. Secure Boot and physical Legacy BIOS are not validated.

## Validation boundary

QEMU/OVMF evidence and a user-reported physical UEFI run are recorded for the integrated Live image. Physical results were not independently reproduced as part of the documentation work. QEMU/SeaBIOS validates a virtual Legacy BIOS path only. See the [physical validation record](../docs/validation/physical-0.6.2.md) and [current architecture](../docs/architecture/overview.md).

## Source and local checks

- Rust source and shared renderer: **src/**, **build.rs**, **Cargo.toml**, **Cargo.lock**.
- Asset generation: **tools/** and source/generated artwork under **assets/**.
- Local test tooling: project **tests/** and generated **dist/validation/** outputs.

The package declares an MIT OR Apache-2.0 license expression for the Atlas Boot Manager package metadata only. This does not choose a license for the entire AtlasOS repository or distribution; see the [third-party inventory](../docs/legal/third-party-inventory.md).