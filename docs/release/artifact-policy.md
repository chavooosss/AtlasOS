# Release artifact, integrity, and immutability policy

## Asset names and set

Use `AtlasOS-X.Y.Z-live-amd64.iso` for the ISO. A release should contain the ISO, `SHA256SUMS.txt`, `RELEASE_NOTES.md`, and `VALIDATION.md`. `BUILD_INFO.txt` and `release-manifest.json` are useful compact companions. Do not attach source build trees, extracted filesystems, VM captures, raw logs, diagnostics, or duplicate test ISOs. Source archives may be provided by the hosting platform; do not bundle an ad hoc source archive.

The preserved physical 0.6.2 ISO is 3,471,966,208 bytes, but it is a historical artifact and is not recommended or cleared for public upload. Check the host's current per-file and total release limits and transfer practicality for any future candidate; do not assume the multi-gigabyte upload will succeed. ISO files stay outside Git and should not use Git LFS.

## SHA-256

SHA-256 is the canonical checksum. `SHA256SUMS.txt` uses the standard `sha256sum` text format and names the expected release filename. On Linux:

```sh
sha256sum -c SHA256SUMS.txt
```

On PowerShell:

```powershell
$expected = '670031830f191edaaeaa6cca32233bf56f416bc666cb2af69a0ce296caa1b5d8'
$actual = (Get-FileHash .\AtlasOS-0.6.2-live-amd64.iso -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actual -ne $expected) { throw "SHA-256 mismatch: $actual" }
'SHA-256 verified'
```

The expected value must come from the reviewed release notes/manifest, not from a value calculated from an untrusted download alone. MD5 and SHA-1 are not release integrity algorithms.

The protected historical physical ISO's embedded manifest was read-only checked: 25 rows, 22 pass, 3 fail (`EFI/BOOT/BOOTX64.EFI`, `boot/grub/efi.img`, `isolinux/boot.cat`). All three are explained by the documented Phase 6C EFI replacement / El Torito remaster; the observed EFI hashes match retained Phase 6 outputs. The embedded list also omits boot-critical files, so it does not provide full payload coverage. Do not claim it passes. The decision is to keep this ISO as historical validation evidence, not to publish it; its external whole-ISO SHA-256 identifies the preserved bytes but does not repair or validate internal rows. See [decision 0003](decisions/0003-physical-iso-manifest.md).

## Signing

No maintained AtlasOS release-signing identity is established. The 0.6.2 proposal is checksum-only; no key is generated and no signature is claimed. Before signing future releases, select and document a durable key custody/rotation and recovery process. GPG signatures, signed Git tags, Sigstore/cosign, or hosting provenance can be evaluated then.

## Immutability and correction

After publication, a versioned binary is immutable. Never silently replace a file under the same version and filename. If an artifact is defective, mark the release withdrawn or broken, preserve its published hash and explanation, and publish a corrected artifact under a new version. Any byte change requires a new artifact identity and version.

## Staging and Git boundary

Stage release metadata separately from source. `dist/release-staging/` is generated/pre-publication material and is excluded from Git. Copy a selected ISO only when the upload is approved and needed; verify source and staged copy before publication. Never track release ISOs in normal Git history.
