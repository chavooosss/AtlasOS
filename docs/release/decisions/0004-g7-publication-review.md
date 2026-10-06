# Decision 0004: G7 source and binary publication readiness

**Recorded:** 2026-10-05

**Historical outcome:** The public source repository was subsequently published on 2026-10-05; see [publication record](../../project/publication-record.md). The source-publication step is complete. The 0.6.3 binary hold remains current.

## Decision

- **Source repository:** GO for the G8 source-publication step, subject to the project owner's final authorization to create and publish the repository.
- **AtlasOS 0.6.3 binary:** HOLD. Do not include the RC ISO in the initial publication until exact-image package copyright/notice metadata, archive component attribution, and applicable corresponding-source obligations have been reviewed and documented.
- **Overall G8 source publication:** GO. Source publication is independent of the binary hold.

## Evidence and scope

The proposed first-commit manifest resolves to 244 source/documentation candidates totaling approximately 13,875,389 bytes after the G7 records were added. The manifest excludes generated build outputs, ISO files, QEMU captures, startup audio, personal/device photographs, and branded reference screenshots. The root MIT license is scoped to AtlasOS-owned source; `atlas-boot` retains `MIT OR Apache-2.0`; Ubuntu Sans and upstream packages retain their own notices. Owner-recorded project distribution permission exists for the included, reviewed AI-generated Atlas visuals; provider/model terms remain unknown and no exclusive copyright is claimed.

The clean 0.6.3 RC is 3,273,064,448 bytes with SHA-256 `0a044347d556493ea62e3767f22e4cba796962988b9be9a4ee156ad7c96b4233`. Its 23 embedded manifest rows passed, package manifest inventory contains 1,692 entries, and one QEMU/OVMF smoke test reached the Live desktop. The project owner separately reports a successful UEFI USB Live boot to desktop on a Casper Excalibur G870. Physical evidence is limited to that one device and is user-reported.

The package inventory was generated from `filesystem.manifest`; it does not map exact installed copyright files, archive components, or source-package obligations. That is the remaining binary release work. The historical 0.6.2 ISO remains unpublished and unchanged.

## Publication identity

- Repository: `AtlasOS`
- Suggested description: “Education-focused Ubuntu-based Live Linux distribution for classroom interactive boards, with a Qt/QML desktop and custom UEFI boot frontend.”
- Default branch: `main`
- Visibility: public, when the owner authorizes G8
- First commit subject: `chore: establish AtlasOS source baseline`
- First commit body: `Introduce the curated source tree and publication-ready documentation as the first version-controlled baseline. AtlasOS development predates Git history; earlier work is not represented as reconstructed or backdated commits.`
- Binary tag plan, when separately approved: `v0.6.3`; release name: `AtlasOS 0.6.3 — Development Preview`
- Badge plan: add the CI badge after repository creation; add the MIT license badge when the public README location is final; add a release badge only after a release exists. Do not add a coverage badge without coverage measurement.

No Git repository, commit, tag, remote, GitHub repository, release, or upload was created by this decision.
