# Versioning and release maturity

## Version format

AtlasOS uses a SemVer-inspired `MAJOR.MINOR.PATCH` number from the root `VERSION` file. It is a product milestone label, not a promise of a stable public API.

- **MAJOR** changes mark a substantial architecture, platform, or compatibility break.
- **MINOR** marks a significant user-visible platform milestone.
- **PATCH** covers compatible fixes, polish, and validation changes.

The project may revise this policy before 1.0 if the product model requires it. Historical versions are not retroactively retagged.

## Maturity states

- **Development Snapshot:** internal or experimental work; behavior and artifacts may change without a release process.
- **Development Preview:** usable development build with a defined scope and documented validation, while material limitations remain. AtlasOS 0.6.2 uses this state.
- **Release Candidate:** feature-frozen candidate under final validation. It is not stable and may be withdrawn or superseded.
- **Stable:** reserved for a release that meets explicitly published reliability, compatibility, update, security, and support criteria. AtlasOS has not met or defined a sufficient broad qualification matrix for this claim.

## Tags and display names

Future release tags should use `vMAJOR.MINOR.PATCH`, for example `v0.7.0` or `v1.0.0`. A GitHub release title should be factual: `AtlasOS 0.6.2 — Development Preview`. Because a future rights-cleaned binary materially changes the 0.6.2 package/artifact identity, the current recommendation is to use `0.6.3` for that candidate rather than reusing `v0.6.2`; this does not change `VERSION` or create a tag. No historical tags are to be fabricated.

For now, the only maintained channel is **Development Preview**. Do not introduce Nightly, Alpha, Beta, or Canary channels without a maintained artifact and validation workflow for each.
