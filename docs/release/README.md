# AtlasOS release preparation

AtlasOS 0.6.3 is the current **Development Preview / Release Candidate**. Its clean ISO passed one OVMF/QEMU Live desktop smoke test and one owner-reported physical UEFI Live test on a Casper Excalibur G870. This is limited evidence from one physical device. This directory defines how a release is identified, validated, documented, and staged. It does not publish an artifact or create a Git tag.

## First public release candidate recommendation

The preserved 0.6.2 physical ISO is a historical validation artifact only and must not be offered publicly. The G4.1 ISO is an engineering candidate, not a public release. The owner has authorized project distribution of reviewed AI-generated Atlas logo, boot, UI, and Plymouth artwork; provider/model terms are not recorded and no exclusive copyright is claimed. The startup WAV and UI reference screenshots remain excluded. The clean 0.6.3 candidate excludes Chrome, the Google repository, and the optional sound. It passed OVMF/QEMU and one owner-reported physical UEFI Live test. Source publication is ready for G8 subject to final owner authorization. Binary distribution remains on hold pending exact-image package copyright/notice inventory, archive component attribution, and source-obligation review.

The exact 0.6.3 RC identity and both validation boundaries are recorded in the [RC manifest](release-manifest-0.6.3-rc1.json) and [physical test record](../validation/physical-0.6.3-rc1.md). The historical 0.6.2 and G4.1 artifacts are not selected as public binaries. See [artifact policy](artifact-policy.md) and [validation policy](validation-policy.md).

## Documents

- [Historical 0.6.2 rights and artifact matrix](release-readiness-matrix.md)
- [License readiness decision](decisions/0002-license-readiness.md)
- [Physical ISO embedded-manifest decision](decisions/0003-physical-iso-manifest.md)
- [Versioning and maturity](versioning.md)
- [Artifact, checksum, and signing policy](artifact-policy.md)
- [Validation and support policy](validation-policy.md)
- [Release checklist](checklist.md)
- [Release process](process.md)
- [0.6.2 release notes](release-notes-0.6.2.md)
- [0.6.2 machine-readable release manifest](release-manifest-0.6.2.json)
- [GitHub Release draft](github-release-0.6.2.md)
- [Third-party notice strategy](third-party-notices.md)
- [First public release decision](decisions/0001-first-public-release.md)
- [G7 source/binary publication decision](decisions/0004-g7-publication-review.md)

## Publication boundary

There is no public release or download URL. AtlasOS-owned source has a root MIT license; source publication is ready for G8 subject to the owner's final authorization. Visual build inputs have separate owner-recorded project-distribution permission; the startup WAV and branded reference images remain excluded. Binary distribution is on hold pending exact package notice/SBOM and corresponding-source review. Release staging under `dist/release-staging/0.6.2/` contains historical metadata only; it intentionally does not duplicate the multi-gigabyte ISO.

The repository publication manifest remains a proposal and Git remains uninitialized. ISO images and release staging are excluded from Git history.
