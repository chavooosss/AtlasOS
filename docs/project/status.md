# AtlasOS project status

## Current candidate: 0.6.3

The source version is `0.6.3`. A clean Release Candidate has passed one normal OVMF/QEMU boot to the Live desktop and one owner-reported physical UEFI Live test on a Casper Excalibur G870. The physical evidence is limited to one device and is not independently reproduced here. This candidate is distinct from the protected historical 0.6.2 artifacts below.

## Historical 0.6.2 status

AtlasOS 0.6.2 is a **Development Preview / Physical Validation Build**. The physical result in this document is user-reported; this documentation work did not independently reproduce it.

## 0.6.3 RC physical validation

The project owner reports that the exact 0.6.3 RC1 artifact reached the AtlasOS Live desktop on a Casper Excalibur G870 using UEFI, through Atlas Boot Manager and the Atlas boot backend. No blocking issue was reported during this smoke test. This is a single-device user report, not a compatibility guarantee. See the [artifact-bound record](../validation/physical-0.6.3-rc1.md).

## Status legend

- **IMPLEMENTED:** code or configuration exists in the current source tree.
- **PARTIAL:** a feature exists but has a documented capability or coverage limit.
- **VM VALIDATED:** evidence exists on a named virtual platform only.
- **PHYSICALLY VALIDATED — USER-REPORTED:** the user reported a result on the documented device; this is not a compatibility guarantee.
- **PLANNED:** not implemented as a current product capability.
- **NOT VALIDATED:** no supporting evidence is established.

## Boot and platform

| Area | Status | Scope |
|---|---|---|
| Rust UEFI Atlas Boot Manager | Implemented; VM validated; physical result user-reported | QEMU/OVMF evidence and one reported physical UEFI path |
| Normal UEFI Live boot | Physically validated — user-reported | Atlas Boot Manager → invisible GRUB backend → kernel/initramfs → Casper Live → Plymouth → Atlas desktop |
| GRUB visibility | Successful path only | Backend failures may expose GRUB diagnostics or a command line |
| Legacy BIOS | Best-effort / non-gating | Historical QEMU evidence does not establish current support; new builds are unsupported/unvalidated for release purposes |
| Secure Boot | Not validated | No support claim |
| Interactive-board compatibility | Not validated broadly | One reported device does not establish model-wide support |

The 0.6.2 record describes the earlier Event A observation and that artifact's result; it remains historical. The 0.6.3 RC owner report is separately scoped in [its physical test record](../validation/physical-0.6.3-rc1.md).

## Desktop and system integration

| Component | Status | Scope |
|---|---|---|
| Atlas home, navigation, settings, and lesson tools | Implemented | Qt 6 / PySide6 QML shell in the packaged Live session |
| Dock, taskbar, and window tracking | Implemented | Behavior and evidence are build/device-specific |
| Audio | Implemented | Uses existing PipeWire/WirePlumber interfaces including wpctl; hardware coverage is limited |
| Network status | Implemented | Reads NetworkManager state through nmcli; this is not a guarantee of network access on every device |
| Power controls | Implemented | Current Live-session actions |
| Display and scaling modes | Partial | Presentation and touch-target behavior do not establish hardware resolution/DPI control |
| Material Center / resource interface | Partial | Local catalog and shortcuts; no official service backend or online content delivery is established |
| Developer Center and diagnostics | Implemented / partial | Bounded information collection and storage-safety rules; not a comprehensive diagnostic suite |

## Planned, not current capabilities

- Installer and first-boot provisioning.
- Grade/class profiles and classroom setup workflows.
- Centralized school device administration.
- Offline educational content preparation.
- Official MEB, EBA, OGM, or MEBİ integration.
- Broad hardware qualification and a Secure Boot validation program.

For build, test, publication, and licensing boundaries, see the [documentation index](../README.md) and the linked records there.

## Release rights and ISO integrity gate

The project owner selected MIT for AtlasOS-owned source; the root license does not change third-party terms. The `atlas-boot` crate retains its separate `MIT OR Apache-2.0` declaration. The owner has attested that reviewed Atlas-specific logo, UI, boot, and Plymouth artwork was AI-generated for AtlasOS and authorized project distribution. Provider/model terms remain unknown for visual assets; this is not an exclusive-copyright claim. The first-commit candidate includes the reviewed runtime visual assets and generated Boot Manager inputs; the project owner has recorded permission for AtlasOS project distribution. The UI concept screenshot, the reference screenshot containing third-party service names, startup audio, and personal/device photos remain excluded. Source publication is ready for the G8 source-publication step subject to final owner authorization. The 0.6.3 binary remains on hold until package copyright/notice metadata, archive component attribution, and applicable source obligations are reviewed for the exact RC package set. The 0.6.2 physical ISO remains a protected historical artifact and is not a public binary candidate. See [AI asset policy](../legal/ai-generated-assets.md), [asset provenance record](../legal/asset-provenance-attestation.md), [asset inventory](../legal/asset-inventory.json), [package policy](../legal/package-distribution-policy.md), the [historical 0.6.2 matrix](../release/release-readiness-matrix.md), and the [current G7 decision](../release/decisions/0004-g7-publication-review.md).
