# Decision 0003: physical ISO embedded manifest

**Status:** read-only inspection completed  
**Date:** 2026-10-05

## Method

The protected physically validated ISO was opened read-only with 7-Zip. Only its root `SHA256SUMS` and individual manifest-listed payloads were streamed to a temporary verifier; no ISO payload was extracted into or written back to the project. SHA-256 was computed for every one of the 25 listed rows. The ISO's whole-file hash was independently checked against the protected historical value.

## Results

**25 manifest rows: 22 pass, 3 fail.**

| Manifest path | Embedded expected SHA-256 | Observed ISO payload SHA-256 | Identity comparison |
|---|---|---|---|
| `EFI/BOOT/BOOTX64.EFI` | `64284316a6105ccbb7d421fb6eb707cbe86eadfd43c0833d554fbfb5ca8bd06a` | `6aec59a922aba6d86de075f9042e892458964fdde920ad9498e5869aa55b46d9` | Observed hash matches retained Phase 6B frontend artifact (`AtlasBootManager-phase6b.efi`, 5,121,536 bytes). |
| `boot/grub/efi.img` | `d393cbd74832d5f39d9952578a4bdbd44b9493451739f6969739a4481eae93b6` | `f46ceb2a90f6db8f2856fefd2c8082a233b342e04fbfd4514a3ec1555bfdc44c` | Observed hash/10,485,760-byte size match retained Phase 6C `EFI-boot-image.img`; this is the regenerated EFI boot image. |
| `isolinux/boot.cat` | `a5c874200980bc55754e5ae730ea3f70e764366aeb2dd1b3d729c7cd39be1383` | `c3ec8fc8379193908aa8c22944bd3d24de103fdfc1213644eab1fcf12ccc77b1` | Original base ISO's catalog hashes to the embedded expected value. Phase 6C changed ISO mastering/layout and regenerated the El Torito catalog. |

The two EFI mismatches are intended payload replacements/repacks documented by Phase 6C, not unexplained byte damage. The boot catalog mismatch is consistent with the changed El Torito layout: retained Phase 6C metadata records the original and candidate catalog/boot-image LBAs, and the candidate's catalog was regenerated during mastering. All other 22 listed payloads validate, including kernel, initramfs, and `casper/filesystem.squashfs`.

## Coverage limitation

The embedded manifest is stale and incomplete, not merely a single old EFI hash. The ISO contains `EFI/BOOT/ATLASGRUB.EFI`, which has SHA-256 `b4e833c68a116d38abce823f7e923dd8a2ef7b8692e4d09f16c5841c3cb8932b`, matching the retained Phase 6B normal Live backend, but this file has no manifest row. `isolinux/isolinux.bin` and two El Torito boot-image entries likewise are outside the 25-row manifest. A manifest check therefore fails and does not inventory every boot-critical payload. The external whole-ISO hash remains the verifiable identity of this preserved artifact; it does not make the embedded manifest pass.

## Severity and release decision

**Severity: RELEASE-NOTE-WORTHY, not release-blocking by itself.** The whole ISO matches the recorded external SHA-256, only three of 25 listed rows fail, all three have a specific expected repack/regeneration explanation, all other listed system payloads pass, and the observed EFI files match retained intended Phase 6 artifacts. No unrelated listed payload mismatch was found.

Do not say the embedded manifest validates. If this historical artifact is ever published, disclose that its embedded `SHA256SUMS` is stale/incomplete and instruct users to verify the whole ISO using the separately published external `SHA256SUMS.txt`. The external value verifies exact artifact bytes; it is not a replacement for per-file inventory and does not cure the three failed rows. Do not repair or rebuild the protected ISO in place. A newly versioned candidate should regenerate a complete embedded manifest after all ISO mastering changes and be verified before any physical-validation/publication decision.

This finding clears the manifest mismatch as a standalone release blocker only. The ISO remains blocked for publication by the separate rights issues in [Decision 0002](0002-license-readiness.md).
