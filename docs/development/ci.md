# CI and quality gates

AtlasOS 0.6.2 is a Development Preview / Physical Validation Build. CI checks source quality and repository hygiene; it does not certify hardware compatibility or produce release images.

## Tiers

| Tier | Trigger | Scope |
|---|---|---|
| A — required PR checks | Push and pull request | Python compile/unit checks, Rust formatting/tests, shell syntax and dispatcher regression, PowerShell parser, public-doc/link/version/manifest policy, artifact guard, and secret scan. |
| B — optional UEFI check | Manual `workflow_dispatch` | Compile the Rust UEFI application and validate its PE/COFF EFI image. No ISO integration or upload. |
| C — release validation | Manual, release-oriented process (not implemented as a workflow) | Fresh build, integrated candidate, checksum and embedded-manifest validation, OVMF/QEMU boot, then physical validation. |

Workflows use read-only repository permissions and do not need repository secrets. Pull request workflows do not receive write tokens or publish artifacts. The full ISO build is deliberately excluded from push/PR CI.

## Local required checks

From the project root:

```bash
python3 -m compileall -q config/includes.chroot/usr/local tests tools/ci
python3 -m unittest discover -s tests -p 'test_*.py' -v
python3 tools/ci/check_repo.py --source-tree  # pre-Git local mode
cargo fmt --manifest-path atlas-boot/Cargo.toml --check
cargo test --manifest-path atlas-boot/Cargo.toml --locked
bash iso/check-build-env.sh --dispatch-only
```

The workflow additionally runs Bash syntax checks, ShellCheck on the core build/dispatcher shell scripts, and a parser-only PowerShell check for `iso/build-atlasos.ps1`. ShellCheck suppresses SC2094 only because the build script intentionally writes a newly generated checksum list while its `find` input explicitly excludes that list; lower-severity informational notices about sourcing the standard `/etc/os-release` file do not fail the check. The dispatcher smoke test uses a temporary directory and compares system live-build file hashes; it does not run `live-build` to generate an ISO. Build safety tests use isolated `--dry-run` invocations.

## Required, advisory, and manual evidence

- **Required:** source policy, secret scan, Python unit/compile checks, Rust format/tests, shell syntax, PowerShell parse, docs and manifest validation, large/generated-file policy, path safety and dispatcher regression.
- **Advisory/deferred:** QML lint/format. The current local environment does not provide a stable, project-pinned QML static-check toolchain; graphical desktop testing is not a reliable hosted PR gate.
- **Manual:** optional UEFI compile workflow; QEMU/OVMF and integrated ISO validation; physical Live USB validation. SeaBIOS/Legacy BIOS is not a release gate.

## Build and release limits

The project-local build preflight is a source-level environment check, not a hosted-runner compatibility claim. An end-to-end ISO build needs several gigabytes of workspace and package/cache storage, network package sources, and privileged live-build mount/chroot operations in a Linux filesystem. GitHub-hosted runner suitability has not been demonstrated. Keep Tier C manual until a capacity-controlled self-hosted runner or a sufficiently provisioned isolated build host is measured and reviewed. A future release workflow should be manual/tag-triggered, use a case-sensitive ext4 workspace, build the frontend/backend/base ISO/integrated candidate, verify both manifest and external checksums, run OVMF validation, and upload only reviewed release outputs.

## Boot policy

UEFI is the primary supported AtlasOS boot path. Legacy BIOS is best-effort, currently unsupported/unvalidated for new builds, and **not release-gating**. The legacy path remains in source; CI does not run SeaBIOS.

## Repository and security decisions

The source policy follows `.gitignore` and `docs/project/first-commit-manifest.json`: ISO, disk, EFI, squashfs, VM, diagnostic archive, build, and `dist/` outputs are prohibited from ordinary Git. Gitleaks scans Git history with redaction enabled. Dependabot is configured for weekly GitHub Actions updates and monthly Cargo updates with low open-PR limits. No CODEOWNERS file is justified for this small project.

After creating the GitHub repository, enable private vulnerability reporting if GitHub makes it available. No email address is asserted. Do not publish CI, license, release, or coverage badges until their repository/license/release/coverage targets actually exist.
