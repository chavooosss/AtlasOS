# Decision 0001: first public release candidate

**Status:** recommended, not approved for publication  
**Date:** 2026-10-05

## Decision

Recommend `AtlasOS-0.6.2-live-amd64.iso` from the protected physical-validation artifact as the first public 0.6.2 asset, only after legal/privacy/artifact review. Do not silently substitute the G4.1 engineering candidate.

## Evidence and rationale

The physical artifact is 3,471,966,208 bytes with SHA-256 `670031830f191edaaeaa6cca32233bf56f416bc666cb2af69a0ce296caa1b5d8`. The retained physical validation record reports that exact ISO reaching the Live desktop via UEFI on one laptop. The evidence is user-reported, not independently reproduced, and does not establish general hardware support. Read-only inspection found 22 of 25 embedded checksum rows pass; the three stale rows match known Phase 6C EFI replacements and regenerated El Torito metadata. The list omits boot-critical files, so external whole-ISO SHA-256 is the artifact identity but does not make the embedded list pass. See [decision 0003](0003-physical-iso-manifest.md).

The G4.1 candidate is 3,475,963,904 bytes with SHA-256 `89523905f3e04814db2b6d0c34d141a45af8f0b50cef2dfc9dda72a5ffc1a492`. It is a fresh build with 23/23 embedded manifest rows and structural UEFI checks passing; QEMU/OVMF reached the Live desktop. It has not been physically validated. Component hashes varied between two frontend builds, repository/package inputs were not fully pinned, and the ISO was built once, so bit-for-bit reproducibility levels 2/3 are not claimed. The G4.1 candidate has not received the rights review needed for public binary distribution either.

The original base ISO remains a protected historical input, not a recommended public release. Neither it nor the physical artifact should be overwritten. The physical artifact predates some later build/integrity source work and is not proven to represent the exact current source baseline. The G4.1 candidate is closer to the cleaned build pipeline and has stronger recorded embedded-manifest validation, but is not automatically the public artifact because its evidence is virtual only and its provenance is not bit-reproducible.

## Maturity and support

0.6.2 is **Development Preview / Physical Validation Build**, not Stable. UEFI is the primary supported boot path. Legacy BIOS is best-effort and not release-gating; new-build Legacy BIOS and Secure Boot are not validated. No broad device matrix, installer, or upgrade mechanism is established.

## Release blockers

Superseded by G6.2: the project owner selected MIT for AtlasOS-owned source. The physical ISO includes Google Chrome 154.0.8037.97-1 and rights-uncleared artwork/audio, so it is historical evidence and not a public binary candidate. Chrome has been removed from future package configuration; remaining asset clearance/replacement and exact package notice/source obligations must be completed for a new candidate. The embedded manifest caveat is separately documented. No Git tag or GitHub release is created by this decision.

### G6.2.1 asset provenance update — 2026-10-05

The owner attests that reviewed Atlas-specific logo, boot, UI, and Plymouth artwork was AI-generated for AtlasOS and authorizes its distribution as part of this project. The source proposal includes these assets with `AI-GENERATED-CLEARED`; this records project permission, not exclusive copyright. The generation provider/model and terms are not recorded for the visual assets. The UI concept/reference screenshots remain excluded where third-party service names appear. The optional startup WAV remains excluded: UI text indicates ElevenLabs, whose current terms tie commercial rights to plan and impose attribution for free-plan sharing, but the WAV's plan/model/inputs/attribution are unknown. The visual source inputs are now present for a clean build; public source and binary readiness remain conditional on rights/package review. The historical 0.6.2 ISO remains unchanged and unsuitable for public distribution.
