import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from tools.ci.check_repo import check_file_policy


class RepositoryPolicyTests(unittest.TestCase):
    def test_generated_and_release_artifact_paths_are_rejected(self):
        errors = []
        check_file_policy(["dist/candidate.iso", "atlas-boot/target/release/App.efi"], errors)
        self.assertTrue(any("generated root" in item for item in errors))
        self.assertTrue(any("generated/release artifact" in item for item in errors))
        self.assertTrue(any("generated/raw-data directory" in item for item in errors))

    def test_hard_file_size_threshold_is_50_mib(self):
        errors = []
        with patch.object(Path, "is_file", return_value=True), patch.object(
            Path, "stat", return_value=SimpleNamespace(st_size=50 * 1024 * 1024 + 1)
        ):
            check_file_policy(["source/oversized.dat"], errors)
        self.assertEqual(len(errors), 1)
        self.assertIn("50 MiB", errors[0])


if __name__ == "__main__":
    unittest.main()
