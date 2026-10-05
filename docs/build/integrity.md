# ISO integrity metadata

AtlasOS uses two checksum layers with different purposes:

- **Embedded `SHA256SUMS`:** hashes selected files stored inside the ISO. The manifest does not hash itself. `isolinux/isolinux.bin` is excluded because ISO mastering writes its boot-info table into that file. Atlas Boot Manager integration regenerates rows for `EFI/BOOT/BOOTX64.EFI`, `EFI/BOOT/ATLASGRUB.EFI`, and `boot/grub/efi.img` after all final EFI payloads are written. `iso/update-embedded-manifest.py` updates these entries while retaining other base payload rows.
- **External `SHA256SUMS.txt`:** hashes the complete final `.iso`, generated only after the image is mastered. It detects any change to the whole artifact, including boot records and the embedded manifest.

The base builder creates an embedded file manifest after its EFI image is created and writes external ISO checksums after ISO mastering. Phase 6C integration regenerates the three changed EFI payload rows after updating the FAT EFI image, maps that manifest into the remastered candidate, compares the embedded copy byte-for-byte, and verifies extracted EFI payload hashes. This does not make old physical artifacts retroactively correct; those artifacts remain immutable evidence.

Future release tooling should parse each `SHA256SUMS` row, extract and hash each referenced file, treat the documented boot-info-table exclusion explicitly, and independently hash the complete ISO against its external checksum. Never report an embedded checksum as verification of the whole ISO.

## G4.1 candidate evidence (2026-10-05)

`dist/validation/g4.1/integrated/AtlasOS-0.6.2-g4.1-repro-test.iso` is the isolated 0.6.2 integration candidate. Its 3,475,963,904-byte whole-image SHA-256 is `89523905f3e04814db2b6d0c34d141a45af8f0b50cef2dfc9dda72a5ffc1a492`, recorded in the adjacent `SHA256SUMS.txt`. The ISO-contained manifest was extracted from the final ISO and checked: 23 rows, 23 `OK`, including both root EFI payloads and `boot/grub/efi.img`. The manifest output and summary are retained under `dist/validation/g4.1/integrated/verification/` and `embedded-manifest-check.txt`.

This verifies the candidate's recorded payload and whole-file hashes. It does not establish bit-for-bit reproducibility: two clean frontend component builds produced distinct PE files, and no second full ISO build was made.
