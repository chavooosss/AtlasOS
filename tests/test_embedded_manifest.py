import hashlib
import pathlib
import subprocess
import sys
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
UPDATER = ROOT / "iso/update-embedded-manifest.py"


class EmbeddedManifestTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.temp.name)
        self.source = self.root / "SHA256SUMS"
        self.frontend = self.root / "frontend.efi"
        self.backend = self.root / "backend.efi"
        self.efi_image = self.root / "efi.img"
        self.output = self.root / "out/SHA256SUMS"
        self.frontend.write_bytes(b"frontend-new")
        self.backend.write_bytes(b"backend-new")
        self.efi_image.write_bytes(b"efi-image-new")

    def tearDown(self):
        self.temp.cleanup()

    @staticmethod
    def row(data: bytes, name: str) -> str:
        return f"{hashlib.sha256(data).hexdigest()}  {name}\n"

    def run_updater(self):
        return subprocess.run(
            [sys.executable, str(UPDATER), str(self.source), str(self.frontend), str(self.backend), str(self.efi_image), str(self.output)],
            text=True,
            capture_output=True,
            check=False,
        )

    def test_replaces_three_payload_rows_and_preserves_unrelated_rows(self):
        unrelated = self.row(b"keep-me", "./casper/vmlinuz")
        self.source.write_text(
            self.row(b"old-front", "./EFI/BOOT/BOOTX64.EFI")
            + self.row(b"old-back", "./EFI/BOOT/ATLASGRUB.EFI")
            + self.row(b"old-img", "./boot/grub/efi.img")
            + unrelated,
            encoding="ascii",
        )
        result = self.run_updater()
        self.assertEqual(result.returncode, 0, result.stderr)
        entries = {line[66:]: line[:64] for line in self.output.read_text(encoding="ascii").splitlines()}
        self.assertEqual(entries["./EFI/BOOT/BOOTX64.EFI"], hashlib.sha256(b"frontend-new").hexdigest())
        self.assertEqual(entries["./EFI/BOOT/ATLASGRUB.EFI"], hashlib.sha256(b"backend-new").hexdigest())
        self.assertEqual(entries["./boot/grub/efi.img"], hashlib.sha256(b"efi-image-new").hexdigest())
        self.assertEqual(entries["./casper/vmlinuz"], hashlib.sha256(b"keep-me").hexdigest())

    def test_rejects_malformed_input(self):
        self.source.write_text("not a checksum row\n", encoding="ascii")
        result = self.run_updater()
        self.assertEqual(result.returncode, 3)
        self.assertFalse(self.output.exists())

    def test_rejects_missing_required_base_entry(self):
        self.source.write_text(self.row(b"old", "./casper/vmlinuz"), encoding="ascii")
        result = self.run_updater()
        self.assertEqual(result.returncode, 4)
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
