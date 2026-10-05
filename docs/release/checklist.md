# Release checklist

Complete and record each applicable item before publishing a release.

## Identity and scope

- [ ] `VERSION` is correct and matches release notes, manifest, and asset names.
- [ ] Maturity label and release title are factual; no Stable/production/certification claim is implied.
- [ ] `CHANGELOG.md` has a concise entry with user-visible changes and no reconstructed history.
- [ ] Release notes and validation summary are finalized and reviewed.

## Product and validation

- [ ] Required CI checks pass; advisory/manual checks are recorded separately.
- [ ] UEFI build and ISO validation evidence refers to the exact candidate hash.
- [ ] Physical validation is included only for the exact artifact and hardware actually tested.
- [ ] Legacy BIOS and Secure Boot status are stated accurately.
- [ ] Known limitations, installer status, and upgrade status are explicit.

## Rights, privacy, and security

- [ ] Project license decision and third-party package/asset notices are reviewed; no source or binary rights are inferred from a component license.
- [ ] Future package configuration contains no Google Chrome package/repository; historical 0.6.2 ISO is not selected as a public asset.
- [ ] Atlas-specific art/audio is rights-cleared or replaced; exact candidate package inventory and source/notices obligations are reviewed.
- [ ] Exact-image package SBOM/license/notice and corresponding-source obligations are satisfied.
- [ ] Atlas artwork/audio/photo/mark provenance and Canonical/EBA/MEB/OGM/MEBİ branding are reviewed.
- [ ] Third-party trademarks and logos do not imply endorsement or official integration.
- [ ] Privacy scan finds no local paths, usernames, identifiers, student data, or internal prompts.
- [ ] Secret scan and large-file/repository artifact checks pass.

## Artifact and publication

- [ ] Canonical ISO name and size are recorded; the release ISO is outside Git history.
- [ ] ISO SHA-256 is computed from the final candidate and verified after staging.
- [ ] External `SHA256SUMS.txt`, `VALIDATION.md`, `BUILD_INFO.txt`, and release manifest match the selected artifact.
- [ ] Embedded ISO manifest is verified after final mastering; all included boot-critical payloads are covered, or any known limitation is explicit and release approval records it.
- [ ] Protected historical artifacts are rechecked and unchanged.
- [ ] Release assets contain no debug dumps, duplicate ISOs, screenshots, or raw logs.
- [ ] Host upload limits and transfer practicality are checked.
- [ ] Git tag plan is reviewed; do not create tags until publication is explicitly authorized.
- [ ] GitHub Release draft is reviewed; no release is created until explicitly authorized.
- [ ] Physical test evidence is attached only when a build was actually physically tested.
