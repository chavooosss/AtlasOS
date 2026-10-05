# AtlasOS build guide

## Supported environment

Use x86_64 Ubuntu 26.04 (Resolute), preferably a dedicated WSL2 distro or disposable Ubuntu VM. The build needs root privileges for live-build mount/chroot operations and downloads Ubuntu archive packages. It is not a fully offline build and no immutable package snapshot is configured. Google Chrome repository/key setup has been removed from future build configuration. Do not use the Windows PowerShell wrapper's desktop archival/copy mode as a release workflow; the canonical entry point is `bash iso/build-atlasos.sh` from this source tree.

`iso/setup-build-env.sh` installs the listed Ubuntu packages after an explicit `sudo` prompt. It does not install Rust or alter host binaries. Install Rust with rustup using a reviewed stable toolchain, add `x86_64-unknown-uefi`, then install Pillow for the selected Python. `iso/check-build-env.sh` checks tools, project-local helper dispatch, target, Python/Pillow, and available disk before a build. Approximately 3 GiB free is a minimum preflight warning threshold; the complete build needs substantially more room for package caches, chroot, squashfs, and ISO staging. CI runs only the isolated dispatcher regression and source checks; it does not run live-build or make an ISO.

The installed tool versions are recorded in [toolchain.env](toolchain.env). This file records the inspected host; it is not a lockfile. Rust/Cargo are installed with the official rustup mechanism, the UEFI target is added through rustup, and Pillow comes from Ubuntu's `python3-pil` package.

## Build stages and commands

```bash
bash iso/check-build-env.sh
bash iso/build-atlasos.sh --dry-run
bash iso/build-atlasos.sh
```

The base build stages are preflight, path validation, generated branding, live-build configuration, bootstrap, chroot, binary tree, UEFI boot image, embedded payload checksum generation, hybrid ISO packaging, and external checksums/build report. Live-build invokes `sudo` for its isolated workspace/chroot operations. The output contract reads the project-root `VERSION` (currently `0.6.3`) and defaults to `dist/AtlasOS-<version>/AtlasOS-<version>-live-amd64.iso`; set `ATLASOS_VERSION`, `ATLASOS_OUTPUT_DIR`, `ATLASOS_ISO_NAME`, or `ATLASOS_BUILD_DIR` to override it. Outputs must remain below `dist/`; build work must remain below project `build/` or the user's Linux cache workspace. In WSL, keep live-build work on a Linux ext4 filesystem; Windows-mounted filesystems cannot represent distinct case-sensitive archive names such as `pam.7.gz` and `PAM.7.gz`.

**Important:** this entry point creates the base Live ISO. It does not, by itself, produce the integrated Atlas Boot Manager release. The validated 0.6.2 Phase 6C integration still consumes separately built frontend/backend EFI artifacts and is retained as an integration step in `atlas-boot/tools/build_phase6c_iso.sh`. That script emits a new candidate and refuses overwrite. Use a new output directory/name; never target the historical physical ISO.

`--clean` removes generated children only in the already canonicalized and allowlisted build workspace, retaining its `cache` child. It never cleans source or `dist/`. `--dry-run` prints selected version, paths and legacy patch state without creating files or running a build. Existing ISO/checksum/report paths cause a refusal rather than overwrite.

## Host and build isolation safety

The standard build does not write `/usr/lib/live/build/lb_binary_syslinux` or `/usr/bin/rsvg`. It copies the live-build syslinux helper into the build workspace and applies Ubuntu/Casper/rsvg compatibility substitutions to that copy. `ATLASOS_ENABLE_LEGACY_HOST_PATCH=1` is rejected as unsupported. `iso/live-build-dispatch.sh` prepends a project-local `lb` shim that intercepts only `binary_syslinux`; every other live-build command is delegated to `/usr/bin/lb` with `LIVE_BUILD` unset. The copied syslinux helper sources `/usr/lib/live/build.sh` in its own shell so `Echo` and other live-build functions are defined. The original failure came from live-build's attempted project-local initialization being sourced in a subshell with errors suppressed, followed by a fallback that did not run; the helper body then reached `DESCRIPTION="$(Echo ...)"` with no `Echo` function. The isolated test now verifies helper selection, `Echo`, argument/exit behavior, and stable system-file hashes before build workspace cleanup.

Use a dedicated WSL2 distro or disposable VM because `live-build` still needs privileged mount/chroot operations and package downloads. Docker is not currently recommended: no container recipe or tested privileged mount configuration exists. Isolation is workspace/process-level, not a hermetic environment.

## Atlas Boot Manager and assets

Build the UEFI frontend from `atlas-boot/` with Cargo.lock and a Rust toolchain plus target `x86_64-unknown-uefi`. The source entrypoint is `src/bin/uefi_main.rs`; `build.rs` embeds files under `assets/generated/` and `src/glyph_metrics.rs`. These generated RGBA/alpha files are required compile inputs. `tools/build_assets.py` regenerates them from checked-in source artwork/font and requires Pillow 12.x, but generated bytes are not claimed bit-for-bit deterministic across Pillow/FreeType versions. Do not run asset regeneration as part of an ordinary build unless using the recorded toolchain and checking the resulting diff.

The invisible GRUB backend configuration is sourced from [`iso/grub-live-autoboot.cfg`](../../iso/grub-live-autoboot.cfg). `atlas-boot/tools/build_phase6b_backend.sh` is the historical, hash-pinned 0.6.2 backend builder; its fixed source ISO and expected artifact hashes make it a validation recipe, not a general version-agnostic release command.

## Validation and integrity

The embedded `SHA256SUMS` validates selected files stored inside the ISO. The external `SHA256SUMS.txt` validates the entire `.iso`; it is generated only after packaging. Integrated builds must update the embedded rows after all final EFI payloads are written. The Phase 6C step now updates entries for root `BOOTX64.EFI`, `ATLASGRUB.EFI`, and the EFI boot image, and verifies the manifest embedded in the candidate. See [integrity semantics](integrity.md).

For a candidate, inspect ISO9660, BIOS and UEFI El Torito entries, hybrid metadata, the EFI image and root EFI files, Casper kernel/initrd/squashfs, every embedded checksum, external ISO checksum, then boot OVMF/QEMU and SeaBIOS/QEMU. File presence is not proof of successful boot.

### G4.1 validation record (2026-10-05)

- Built a separate base ISO and integrated candidate at `dist/validation/g4.1/`; protected historical ISOs were not overwritten.
- The integrated candidate is `AtlasOS-0.6.2-g4.1-repro-test.iso` (3,475,963,904 bytes; SHA-256 `89523905f3e04814db2b6d0c34d141a45af8f0b50cef2dfc9dda72a5ffc1a492`). The external checksum is in `dist/validation/g4.1/integrated/SHA256SUMS.txt`.
- Its embedded manifest has 23 rows and all 23 validate against extracted ISO contents, including `BOOTX64.EFI`, `ATLASGRUB.EFI`, and `boot/grub/efi.img`. ISO inspection confirmed ISO9660, BIOS and UEFI El Torito entries, hybrid metadata, readable EFI image, and Casper kernel/initrd/squashfs.
- OVMF/QEMU reached the AtlasOS Live desktop in 180 seconds. The representative desktop capture is `dist/validation/g4.1/qemu-ovmf/live-180s.png`; the selection screen is `01-atlas-menu.png`. None of the sampled captures shows a GRUB menu, but these are snapshots and do not prove that no brief GRUB frame occurred between captures. Plymouth was not separately confirmed. QEMU serial output contains OVMF boot-manager disk-start messages only; it is not kernel logging.
- SeaBIOS reached the ISOLINUX screen, but the single 240-second run remained black after Enter and did not reach the Live desktop. See `dist/validation/g4.1/qemu-bios/`; Legacy BIOS is not validated.
- Repeated frontend builds were valid EFI files but had different SHA-256 values (`dd15e11a…` and `05c5af54…`), so component bit-for-bit repeatability was not observed. No second full ISO build was attempted.
- Dispatcher smoke test and full preflight passed. The build itself did not patch `/usr`; the required Pillow package was installed through Ubuntu apt. See the G4.1 result below for limitations.
- G4.1 was recorded as **PARTIAL** at that phase because the Legacy BIOS run did not reach the desktop. Current project policy sets UEFI as the primary supported path; Legacy BIOS is best-effort, unsupported/unvalidated for new builds, and not release-gating. The captured ISO9660/El Torito structure proves that the BIOS boot entry is present, not that the path completes successfully.

## Reproducibility level and limitations

**G4.1 achieved Level 1**: a fresh base build and separately integrated candidate were produced and the candidate passed structural/integrity checks and OVMF/QEMU desktop boot. **Level 2 is not achieved**: this host's versions are recorded, but package repositories and downloaded inputs are not pinned or snapshotted. **Level 3 is not achieved**: the repeated frontend EFI builds differed, and no full-ISO bit-for-bit comparison was performed. Network package contents, rustup stable selection and generated font rasterization can change build outputs. G4.1 evidence describes its historical configuration and does not prove the current rights-cleaned source builds identically.

## Clean environment test plan

1. Create a fresh disposable Ubuntu 26.04 WSL2 distro or VM.
2. Obtain the curated source tree and record a source archive hash/commit ID.
3. Run `iso/setup-build-env.sh`, install and record Rust/Pillow, and run `iso/check-build-env.sh`.
4. Run `bash iso/build-atlasos.sh --dry-run`, then build to a new candidate output.
5. Build Atlas Boot Manager and backend from documented source inputs; integrate into a separate candidate.
6. Verify embedded and external checksums plus ISO9660, BIOS/UEFI El Torito, hybrid and Casper contents.
7. Boot OVMF/QEMU through Atlas Boot Manager to the Live desktop. Legacy BIOS/SeaBIOS testing is optional historical/best-effort evidence and is not a release gate.
8. Save a sanitized build report, toolchain manifest and validation evidence alongside the candidate.

Generated ISOs, EFI binaries, extracted filesystems, logs and QEMU captures belong in ignored `build/` or `dist/validation/`, not in ordinary source history. Git and GitHub remain outside this phase.
