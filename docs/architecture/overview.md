# AtlasOS architecture (0.6.2)

This overview describes the current source and the bounded 0.6.2 validation record. **Implemented** means present in source/configuration. **Validated** applies only to the named evidence and does not imply general hardware compatibility. **Partial** identifies a feature with known scope limits. **Planned** is not implemented.

## Product layers

\`\`\`mermaid
flowchart TD
    SOURCE[Atlas source and package configuration] --> BUILD[live-build and ISO tooling]
    BUILD --> LIVE[Ubuntu-based Casper Live image]
    LIVE --> LOGIN[LightDM]
    LOGIN --> DESKTOP[XFCE session and window manager]
    DESKTOP --> ATLAS[Atlas Qt 6 / PySide6 QML shell]
    ATLAS --> SERVICES[NetworkManager, PipeWire/WirePlumber, udisks]
    ATLAS --> DIAG[Atlas diagnostics helpers]
\`\`\`

The desktop uses established Linux services for device and session functions. Atlas provides the teacher-facing shell, selected workflows, integration helpers, and diagnostics experience.

## Boot and Live path

The successful physical path recorded for 0.6.2 is **user-reported**:

UEFI firmware → Rust Atlas Boot Manager → invisible GRUB backend → Linux kernel/initramfs → Casper Live → Plymouth → LightDM → XFCE session with Atlas UI.

Atlas Boot Manager is a UEFI application. It renders through the firmware Graphics Output Protocol, accepts keyboard navigation, uses a countdown, and loads/starts the backend EFI image from the same boot device. GRUB remains the boot backend; its interface was not seen on the recorded successful path. Some backend failure paths can show GRUB diagnostics or a command line.

UEFI is AtlasOS's primary supported boot path. Legacy BIOS is best-effort, currently unsupported and unvalidated for new builds, and is not release-gating. The legacy path remains in source; G5 does not diagnose or change it. Secure Boot is not validated. The 0.6.2 physical result applies only to the reported test device and setup.

## Session and UI

The packaged Live environment uses LightDM and an XFCE/XFWM4 session with the Atlas interface launched as a Qt 6 / PySide6 QML application. Canonical UI components, launchers, and services live under the current configuration tree and are copied into the Live filesystem by the build process.

The shell surfaces lesson tools, educational-resource shortcuts, system status, settings, and the Developer Center. The Material Center is a local catalog/shortcut interface; no official education-service backend or online content delivery is established.

## System integration

- **Audio:** PipeWire/WirePlumber, including wpctl-based level/mute controls.
- **Network:** NetworkManager state queried through nmcli; status display does not guarantee a working connection.
- **Window and dock behavior:** XFWM4/X11 window observation and Atlas dock/taskbar UI.
- **Removable media:** lsblk/udisks tooling and diagnostics storage-safety policy.
- **Power:** Live-session power actions through system facilities.
- **Display:** Atlas presentation modes affect interface behavior; they do not prove hardware resolution or DPI control.

## Diagnostics

The Developer Center combines bounded system and boot information with packaged helpers. Diagnostic export is subject to explicit removable-target selection and storage-safety checks. The collectors are not a comprehensive hardware repair or security-audit system. Review diagnostic archives before sharing because system information and logs may contain identifying details.

## Build and generated outputs

The source-build entry point is **iso/build-atlasos.sh**. Package lists, hooks, GRUB configuration, and files staged into the Live filesystem are under **config/** and **iso/**. The Rust UEFI application is under **atlas-boot/** and is integrated into an existing ISO by separate Phase 6 tooling; that integration/repack flow is distinct from a clean source build.

Generated ISO files, EFI binaries, extracted filesystems, test captures, and logs are outputs, not canonical source. A clean end-to-end reproducible build is not yet claimed. The build guide records dependencies and the opt-in host patch limitation.

See the [source map](source-map.md), [build guide](../build/README.md), [test layers](../testing/README.md), and [component status](../project/status.md).
