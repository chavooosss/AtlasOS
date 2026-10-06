# AtlasOS release status

AtlasOS 0.6.3 is the current **Development Preview / Release Candidate**. The source repository is public; no ISO download, version tag, or GitHub Release has been published. The clean RC reached the Live desktop in one OVMF/QEMU run. The project owner reports one physical UEFI Live test on a Casper Excalibur G870. This is limited evidence from one device.

## Binary distribution status

The 0.6.3 RC remains on hold pending exact-image package copyright/notice inventory, archive-component attribution, and review of applicable corresponding-source obligations. The preserved 0.6.2 physical ISO is historical validation evidence only and will not be offered as a public download. The G4.1 ISO is an internal engineering candidate.

The clean 0.6.3 RC excludes Google Chrome, the Google package repository, and the optional startup sound. Its reviewed Atlas-specific logo, boot, UI, and Plymouth artwork has separate owner-recorded permission for AtlasOS project distribution. Provider/model terms are not recorded and no exclusive copyright claim is made. The startup WAV, branded design-reference screenshots, and personal/device photos remain excluded.

The public source baseline and its scope are recorded in the [publication record](../project/publication-record.md) and [publication manifest](../project/publication-manifest.md). Source publication does not imply that the binary distribution gate has passed.

## Documents

- [Release checklist](checklist.md)
- [Release process](process.md)
- [Versioning and maturity](versioning.md)
- [Artifact, checksum, and signing policy](artifact-policy.md)
- [Validation and support policy](validation-policy.md)
- [Third-party notice strategy](third-party-notices.md)
- [0.6.3 RC machine-readable manifest](release-manifest-0.6.3-rc1.json)
- [Historical 0.6.2 rights and artifact matrix](release-readiness-matrix.md)
- [License readiness decision](decisions/0002-license-readiness.md)
- [Physical ISO embedded-manifest decision](decisions/0003-physical-iso-manifest.md)
- [Public source and binary decision](decisions/0004-g7-publication-review.md)

The `dist/release-staging/` directory contains historical release metadata only. ISO files and generated release outputs stay outside Git history.
