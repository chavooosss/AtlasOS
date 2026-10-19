# AtlasOS project status

## Current source line: 0.6.4

The root `VERSION` file is `0.6.4`. This is a Development Preview source candidate carrying forward the 0.6.3 UI/boot work and adding the user-triggered official external-browser installation path. The project owner selected the pre-existing `AtlasOS-0.6.4-Smartboard-Demo-amd64.iso` as the current local USB-test reference (3,273,457,664 bytes; SHA-256 `491c2a931a3f8ecfe75f0bd25bf6d1c10fac7670b978b491310ed90b1d677587`). Its embedded build identity is 20261014-22:26, and its source commit is not recorded; it is not evidence that the current `main` source was built or validated. Exact-image physical validation is pending. There is no public 0.6.4 binary download, tag, or GitHub Release. See the [selected image record](../validation/selected-0.6.4-smartboard-demo.md).

The project owner reports one successful UEFI Live USB test on a Casper Excalibur G870 for the exact 0.6.3 RC1 image. That physical result and the prior 0.6.3 OVMF/QEMU boot are historical evidence for 0.6.3 only; they do not validate a 0.6.4 build. See the [0.6.3 artifact-bound record](../validation/physical-0.6.3-rc1.md).

## Public project status

The AtlasOS source repository and product website are public. The repository is a curated source baseline; its initial commit does not reconstruct pre-Git development history. No ISO download is published. The historical 0.6.3 binary remains on its recorded package notice, archive component, and source-obligation review hold. The new 0.6.4 candidate requires its own clean build and validation. See the [publication record](publication-record.md) and [release status](../release/README.md).
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

AtlasOS-owned source is covered by root MIT within the documented scope; `atlas-boot` retains its separate `MIT OR Apache-2.0` declaration. Upstream packages, fonts, and icons keep their own terms. The project owner has recorded permission for reviewed Atlas-specific AI-generated logo, UI, boot, and Plymouth artwork; provider/model terms remain unknown and no exclusive-copyright claim is made. The UI concept and branded reference screenshots, startup WAV, and personal/device photos remain excluded. The 0.6.3 RC binary remains historically held pending exact-image package notices, archive component attribution, and applicable source-obligation review; this does not approve or publish a 0.6.4 binary. The historical 0.6.2 ISO is not a public binary candidate. See [AI asset policy](../legal/ai-generated-assets.md), [asset provenance record](../legal/asset-provenance-attestation.md), [asset inventory](../legal/asset-inventory.json), [package policy](../legal/package-distribution-policy.md), the [historical 0.6.2 matrix](../release/release-readiness-matrix.md), and the [G7 decision record](../release/decisions/0004-g7-publication-review.md).
