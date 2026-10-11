# AtlasOS release status

AtlasOS 0.6.4 is the current **Development Preview source candidate**. The source repository is public; no 0.6.4 ISO download, version tag, or GitHub Release has been published. The clean 0.6.3 RC reached the Live desktop in one OVMF/QEMU run, and the project owner reports one physical UEFI Live test on a Casper Excalibur G870. These are historical 0.6.3 results and do not validate 0.6.4.

## Binary distribution status

The next 0.6.4 ISO is a validation candidate only. It is not approved or published as a public binary. The preserved physical 0.6.2 ISO and the 0.6.3 RC remain historical artifacts. The G4.1 ISO is an internal engineering candidate.

Google Chrome is not bundled in the 0.6.4 ISO. The external-browser launcher may offer the user a deliberate download and installation from Google's official Linux source after displaying links to applicable terms and requesting administrator authorization. See the [Chrome integration policy](../legal/google-chrome-integration.md). This avoids assuming that a free download grants third-party ISO redistribution rights.

The 0.6.3 RC's package notice, archive-component attribution, and corresponding-source review remain recorded against that historical artifact; they are not erased or retroactively treated as a 0.6.4 review. The startup WAV, branded design-reference screenshots, and personal/device photos remain excluded.

## Documents

- [Release checklist](checklist.md)
- [Release process](process.md)
- [Versioning and maturity](versioning.md)
- [Artifact, checksum, and signing policy](artifact-policy.md)
- [Validation and support policy](validation-policy.md)
- [Third-party notice strategy](third-party-notices.md)
- [0.6.4 candidate release notes](release-notes-0.6.4.md)
- [0.6.3 RC historical machine-readable manifest](release-manifest-0.6.3-rc1.json)
- [Historical 0.6.2 rights and artifact matrix](release-readiness-matrix.md)
- [License readiness decision](decisions/0002-license-readiness.md)
- [Physical ISO embedded-manifest decision](decisions/0003-physical-iso-manifest.md)
- [Public source and binary decision](decisions/0004-g7-publication-review.md)

The `dist/release-staging/` directory contains historical release metadata only. ISO files and generated release outputs stay outside Git history.