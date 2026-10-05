import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class ReleaseMetadataTests(unittest.TestCase):
    def test_historical_release_manifest_keeps_its_original_identity(self):
        manifest = json.loads((ROOT / "docs/release/release-manifest-0.6.2.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["version"], "0.6.2")
        self.assertEqual(manifest["maturity"], "Development Preview")
        self.assertEqual(manifest["artifact"]["filename"], "AtlasOS-0.6.2-live-amd64.iso")
        self.assertEqual(manifest["artifact"]["size_bytes"], 3_471_966_208)
        self.assertRegex(manifest["artifact"]["sha256"], re.compile(r"^[0-9a-f]{64}$"))

    def test_current_rc_manifest_matches_canonical_version_and_identity(self):
        manifest = json.loads((ROOT / "docs/release/release-manifest-0.6.3-rc1.json").read_text(encoding="utf-8"))
        version = (ROOT / "VERSION").read_text(encoding="ascii").strip()
        self.assertEqual(manifest["version"], version)
        self.assertEqual(manifest["maturity"], "Development Preview / Release Candidate")
        self.assertEqual(manifest["artifact"]["filename"], f"AtlasOS-{version}-rc1-live-amd64.iso")
        self.assertEqual(manifest["artifact"]["size_bytes"], 3_273_064_448)
        self.assertRegex(manifest["artifact"]["sha256"], re.compile(r"^[0-9a-f]{64}$"))
        self.assertEqual(manifest["artifact"]["publication_status"], "not published")
        self.assertIn("pending", manifest["distribution_review"]["package_inventory"]["package_level_notices_and_corresponding_source_review"])

    def test_manifest_keeps_validation_and_provenance_boundaries_explicit(self):
        manifest = json.loads((ROOT / "docs/release/release-manifest-0.6.2.json").read_text(encoding="utf-8"))
        self.assertIn("user-reported", manifest["validation"]["physical"])
        self.assertIn("not proven", manifest["source_binary_relationship"])
        self.assertEqual(manifest["boot_policy"]["primary"], "UEFI")
        self.assertIn("not validated", manifest["boot_policy"]["secure_boot"])
        self.assertIn("not published", manifest["publication"])

    def test_release_readiness_does_not_hide_license_or_embedded_manifest_blockers(self):
        manifest = json.loads((ROOT / "docs/release/release-manifest-0.6.2.json").read_text(encoding="utf-8"))
        self.assertIn("MIT for AtlasOS-owned source", manifest["rights"]["project_license"])
        self.assertIn("not public", manifest["rights"]["binary_publication"])
        embedded = manifest["embedded_checksum_manifest"]
        self.assertEqual((embedded["rows_total"], embedded["rows_pass"], embedded["rows_fail"]), (25, 22, 3))
        self.assertIn("not passing", embedded["status"])


if __name__ == "__main__":
    unittest.main()
