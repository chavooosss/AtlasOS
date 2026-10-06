# AtlasOS published source scope

This record describes the current public source repository and its curated source boundary. The first public source baseline was published on 2026-10-05; see the [publication record](publication-record.md). AtlasOS development predates Git, so the first commit is a selected baseline rather than reconstructed history.

## Included source and documentation

The public repository contains Atlas desktop/runtime integration, the Rust UEFI Boot Manager, build and integration scripts, selected tests, and curated engineering, product, validation, and legal documentation. Atlas-specific assets are included only where the asset inventory records an appropriate source or project-distribution basis. The initial baseline scope remains documented in the [historical first-commit manifest](first-commit-manifest.json).

The product screenshot set under `docs/media/` was added as curated documentation after the initial source baseline. Its capture method and exclusions are described in [the media record](../media/README.md).

## Excluded from normal Git history

Generated outputs such as ISO files, EFI binaries, VM images, extracted filesystems, build trees, logs, local review captures, and raw diagnostics. Local assistant state, credentials, private environment files, personal/device photos, and raw prompt/conversation exports are also excluded.

## Binary release boundary

The public source repository does not publish an ISO. AtlasOS 0.6.3 RC remains on hold until exact-image package copyright/notice metadata, archive component attribution, and applicable corresponding-source obligations have been reviewed. The preserved physical 0.6.2 ISO is historical validation evidence only; it contains Chrome and rights-uncleared media, and its embedded checksum list has three known stale rows and boot-critical coverage gaps. See the [0.6.2 release matrix](../release/release-readiness-matrix.md).

The G4.1 image is an engineering candidate, not a public binary. Source availability and binary redistribution are evaluated separately.

## Third-party and generated assets

Ubuntu/Debian packages, Rust dependencies, fonts, icons, and other upstream components retain their own terms. The owner has recorded project-distribution permission for reviewed Atlas-specific AI-generated visual assets; provider/model terms remain unknown and the project makes no exclusive-copyright claim. The startup WAV, branded design-reference screenshots, and personal/device photos are excluded. See [license scope](../legal/project-license-scope.md), [asset inventory](../legal/asset-inventory.json), and [third-party inventory](../legal/third-party-inventory.md).
