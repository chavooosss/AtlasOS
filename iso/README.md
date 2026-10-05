# ISO build tooling

The documented entry point and supported environment are in [`docs/build/README.md`](../docs/build/README.md). Run `bash iso/check-build-env.sh` before a full frontend/release build, or `bash iso/check-build-env.sh --base` for the base Live ISO stage. `iso/build-atlasos.sh` builds only the base Live ISO; Boot Manager integration is a separate, explicit candidate step.

The helper `iso/grub-live-autoboot.cfg` is the source for the invisible GRUB backend configuration. The older `atlas-boot/tools/build_phase6b_backend.sh` and `build_phase6c_iso.sh` remain hash-pinned 0.6.2 engineering tools. Phase 6C now refreshes embedded EFI payload checksums and writes an external ISO checksum for its new candidate. Do not use these scripts to overwrite historical releases.

The normal build does not patch `/usr`. Legacy host patch opt-in is rejected; compatibility adjustments are made in a build-workspace helper copy. `--dry-run` resolves and prints paths without creating files. `--clean` only removes generated children under a canonicalized allowlisted build workspace. No Git or GitHub operation is part of the build workflow.
