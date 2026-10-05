# AtlasOS source publication record

**Publication date:** 2026-10-05

## Repository

- Owner: `chavooosss` (project owner account)
- Repository: [AtlasOS](https://github.com/chavooosss/AtlasOS)
- Visibility: public
- Default branch: `main`
- Source version: 0.6.3 — Development Preview
- Initial curated source commit: `2e0c4ca19a721c684978eace58d72d77e8418074`
- Initial source baseline: 244 tracked files; approximately 13,875,389 bytes

AtlasOS development predates Git history. The initial commit is a curated source baseline, not reconstructed or backdated history. Two follow-up commits corrected CI portability and publication-document links.

## CI status

The first CI run on the initial commit failed on a Python-version-sensitive manifest glob, a storage-test fixture that depended on the host device table, and links to an excluded planning document. These publication/CI issues were corrected in follow-up commits. The subsequent `main` CI run passed all jobs, including the Gitleaks scan: [run 37351043266](https://github.com/chavooosss/AtlasOS/actions/runs/37351043266).

The manual UEFI compile workflow is published as `.github/workflows/uefi-check.yml` and was not triggered as part of publication.

## Binary status

The AtlasOS 0.6.3 RC remains **HOLD** for public distribution pending exact-image package copyright/notice inventory, archive component attribution, and review of applicable corresponding-source obligations. No ISO was uploaded; no version tag or GitHub Release was created.
