# Privacy and publication inventory

This records the privacy boundaries used for the public source baseline. It does not claim that excluded historical or binary material has received privacy clearance.

## Curated public documentation candidates

The public source baseline contains the project README, documentation index, roadmap/changelog/contribution/security guidance, architecture/build/testing records, project status and publication notes, third-party inventory, and curated validation records. The source candidate passed the repository's public-document path and link checks before publication.

## Review before publishing

- Photos and screenshots may reveal people, personal papers, school/device identifiers, local desktop details, or third-party marks. Do not publish a capture until it has been visually reviewed and approved.
- Branding, boot artwork, fonts, and audio need source/provenance and redistribution review.
- Third-party product/service names and marks do not establish affiliation, endorsement, or official integration.
- Diagnostic bundles and logs can contain system, hardware, boot, service, network, or filesystem information. Inspect each bundle before sharing.

## Keep internal or exclude from the initial public baseline

Raw project handoffs, prompts, memory/session exports, unreviewed field reports, private physical photos, raw diagnostic bundles, generated build/validation output, ISO variants, and assistant-local metadata remain outside the initial publication set. Historical documents may be curated into evidence-based summaries after paths and identifying details are removed.

## Review status

The G7/G8 source-candidate scan found no high-confidence secret patterns or workstation paths in public documents. Gitleaks was unavailable locally; the first GitHub Actions secret-scan result should be checked independently. Third-party package notices and source obligations remain a binary release gate.

See the [publication manifest](publication-manifest.md), [third-party inventory](../legal/third-party-inventory.md), and [first-commit manifest](first-commit-manifest.json).
