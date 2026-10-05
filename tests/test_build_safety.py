import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest
import uuid


ROOT = pathlib.Path(__file__).resolve().parents[1]
BUILDER = ROOT / "iso/build-atlasos.sh"


@unittest.skipUnless(os.name == "posix" and shutil.which("bash") and shutil.which("realpath"), "requires Linux build shell")
class BuildSafetyTests(unittest.TestCase):
    def setUp(self):
        self.token = uuid.uuid4().hex
        self.build = ROOT / "build" / f"ci-safety-{self.token}"
        self.output = ROOT / "dist" / f"ci-safety-{self.token}"
        self.env = os.environ.copy()
        self.env.update({"ATLASOS_BUILD_DIR": str(self.build), "ATLASOS_OUTPUT_DIR": str(self.output)})

    def tearDown(self):
        self.assertFalse(self.build.exists(), "dry-run must not create the build workspace")
        self.assertFalse(self.output.exists(), "dry-run must not create the output directory")

    def run_dry_run(self, **updates):
        env = self.env | updates
        return subprocess.run(["bash", str(BUILDER), "--dry-run"], cwd=ROOT, env=env, text=True, capture_output=True, check=False)

    def test_safe_isolated_dry_run_does_not_create_outputs(self):
        result = self.run_dry_run()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("legacy_host_patch=disabled", result.stdout)

    def test_rejects_root_home_and_project_workspace_paths(self):
        for unsafe in ("/", str(pathlib.Path.home()), str(ROOT)):
            with self.subTest(workspace=unsafe):
                result = self.run_dry_run(ATLASOS_BUILD_DIR=unsafe)
                self.assertNotEqual(result.returncode, 0)

    def test_rejects_external_output_roots(self):
        for unsafe in (str(ROOT), "/tmp/atlasos-ci-outside", "../../outside"):
            with self.subTest(output=unsafe):
                result = self.run_dry_run(ATLASOS_OUTPUT_DIR=unsafe)
                self.assertNotEqual(result.returncode, 0)

    def test_rejects_traversal_filename_and_invalid_version(self):
        for updates in (
            {"ATLASOS_ISO_NAME": "../outside.iso"},
            {"ATLASOS_ISO_NAME": "nested/candidate.iso"},
            {"ATLASOS_ISO_NAME": "candidate.bin"},
            {"ATLASOS_VERSION": "0.6.2/invalid"},
        ):
            with self.subTest(updates=updates):
                result = self.run_dry_run(**updates)
                self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
