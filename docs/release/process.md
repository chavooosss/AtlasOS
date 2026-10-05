# Release process

1. Freeze the target version in `VERSION`; confirm the maturity label and scope.
2. Review the changelog, source changes, licensing/attribution status, and release limitations.
3. Select a candidate artifact. Record its origin and exact SHA-256; do not assume the newest ISO is the release candidate.
4. Run required CI and build checks, then validate that exact ISO structurally and on UEFI/OVMF. Record physical testing separately and only when performed.
5. Generate the checksum, build information, release manifest, release notes, and validation summary from the selected artifact facts.
6. Stage only the named release assets outside Git. Verify staged size/hash against the source artifact.
7. Perform final privacy, secret, legal, artifact-size, and source/binary correspondence review.
8. Obtain publication approval. Then create the version tag and a GitHub Release draft with the reviewed files.
9. Publish only after final human review; do not automate publication from PR CI.
10. Verify the published assets by downloading/checksumming them and record the release URL and final hashes.

This is the future workflow. G6 performs no Git initialization, tag creation, GitHub interaction, or publication.

## Failure handling

If a published release is found defective, retain its identity and hash, mark it withdrawn/broken with a clear explanation, and publish a corrected version. Never replace a release binary under the same version and hash identity.

## Automation boundary

CI may validate metadata, checksums, manifests, source hygiene, and build outputs. Physical hardware validation, hardware compatibility claims, legal review, release approval, and final publication remain human-reviewed steps.
