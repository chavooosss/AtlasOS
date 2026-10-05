# Proposed publication manifest

This records the approved publication scope and current public source repository. The first commit was created from the approved manifest; generated artifacts and review-excluded material remain outside Git history.

## Proposed public source and documentation

- **config/**, **atlas-boot/**, **iso/**, and selected **tests/** source, subject to the exclusions and rights review in the [first-commit manifest](first-commit-manifest.json).
- **assets/** and boot assets where the asset inventory records source ownership, upstream terms, or owner-authorized AtlasOS project distribution.
- Curated current docs under architecture, build, legal, project, testing, and validation.
- Root README, roadmap, selected changelog, contribution guidance, security guidance, and documentation index.
- No raw handoffs, private photos, diagnostic archives, local captures, or unreconciled historical notes.

## Excluded from normal Git history

Generated output such as ISO files, EFI binaries, VM images, extracted filesystems, build trees, logs, screenshots, test captures, and raw diagnostic bundles. Local assistant state, credentials, private environment files, and raw conversation/prompt exports also remain excluded.

## Release artifacts

A public source repository is ready for the G8 publication step, subject to final owner authorization. The 0.6.3 RC binary is on hold until its exact package copyright/notice inventory, archive component attribution, and applicable source obligations are reviewed. No public download is currently available. The preserved physical 0.6.2 ISO is **historical validation evidence only** and will not be published: it contains Chrome and art/audio not cleared for that image. Its embedded checksum list has three known stale rows and boot-critical coverage gaps; see the [historical 0.6.2 release matrix](../release/release-readiness-matrix.md).

## Internal or review-required material

The proposed first commit excludes internal handoffs, prompts, memory/session exports, raw field reports, original device photographs, diagnostic evidence, the startup WAV, and branded UI reference screenshots. Atlas logo, boot, UI, and Plymouth art are included where marked `AI-GENERATED-CLEARED` under the project-owner provenance record; this records project distribution permission but does not assert exclusive copyright or verified provider terms. The Boot Manager asset generator uses an isolated landscape crop with no visible vendor marks; its pixels were byte-compared to the existing generated payload. Package notices and source obligations are a binary release gate, not a source repository gate. See [license scope](../legal/project-license-scope.md), [AI asset policy](../legal/ai-generated-assets.md), [provenance attestation](../legal/asset-provenance-attestation.md), and [asset inventory](../legal/asset-inventory.json).

See [privacy inventory](privacy-inventory.md), [third-party inventory](../legal/third-party-inventory.md), [license decision](../release/decisions/0002-license-readiness.md), [manifest decision](../release/decisions/0003-physical-iso-manifest.md), and the [first-commit manifest](first-commit-manifest.json). This record describes the published source scope; it does not approve binary distribution.
