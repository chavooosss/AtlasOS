import json
import tempfile
import unittest
from pathlib import Path

from tools.release.package_inventory import parse_dpkg_status, parse_manifest, write_notices


class PackageInventoryTests(unittest.TestCase):
    def test_manifest_rows_are_unknown_without_license_claims(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "filesystem.manifest"
            source.write_text("alpha 1.2-3 amd64\nbeta 4.5\n", encoding="utf-8")
            rows = parse_manifest(source)
        self.assertEqual(len(rows), 2)
        self.assertEqual(rows[0]["license"], "UNKNOWN")
        self.assertIsNone(rows[0]["source_package"])

    def test_dpkg_inventory_points_to_real_copyright_metadata(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "var/lib/dpkg").mkdir(parents=True)
            (root / "var/lib/dpkg/status").write_text(
                "Package: alpha\nStatus: install ok installed\nVersion: 1.2\nArchitecture: amd64\nSource: alpha-src (1.2)\nSection: utils\nHomepage: https://example.invalid\n\n",
                encoding="utf-8",
            )
            copyright = root / "usr/share/doc/alpha/copyright"
            copyright.parent.mkdir(parents=True)
            copyright.write_text("Upstream license metadata", encoding="utf-8")
            rows = parse_dpkg_status(root)
            notice = root / "notices.txt"
            write_notices(rows, notice)
            notice_text = notice.read_text(encoding="utf-8")
        self.assertEqual(rows[0]["source_package"], "alpha-src")
        self.assertEqual(rows[0]["license"], "REVIEW_REQUIRED")
        self.assertIn("usr/share/doc/alpha/copyright", notice_text)

    def test_malformed_manifest_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "manifest"
            source.write_text("not a package row with too many fields here\n", encoding="utf-8")
            with self.assertRaises(ValueError):
                parse_manifest(source)


if __name__ == "__main__":
    unittest.main()
