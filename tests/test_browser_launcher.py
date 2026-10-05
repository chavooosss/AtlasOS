import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
LAUNCHER = ROOT / "config/includes.chroot/usr/local/bin/atlasos-browser"


@unittest.skipUnless(os.name == "posix" and shutil.which("bash") and shutil.which("flock"), "requires bash and flock")
class BrowserLauncherTests(unittest.TestCase):
    def test_retries_one_transient_137_without_showing_error(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            fake_bin = root / "bin"
            fake_bin.mkdir()
            counter = root / "launch-count"
            fake_browser = fake_bin / "chromium"
            fake_browser.write_text(
                "#!/bin/sh\n"
                f"count=0; test ! -f '{counter}' || read count < '{counter}'\n"
                f"count=$((count + 1)); printf '%s\\n' \"$count\" > '{counter}'\n"
                "if test \"$count\" -eq 1; then exit 137; fi\n"
                "exit 0\n",
                encoding="utf-8",
            )
            fake_browser.chmod(0o755)
            environment = os.environ.copy()
            environment.update(
                {
                    "PATH": str(fake_bin) + os.pathsep + environment.get("PATH", ""),
                    "HOME": str(root / "home"),
                    "XDG_CACHE_HOME": str(root / "cache"),
                    "DISPLAY": ":1",
                }
            )
            result = subprocess.run(
                ["bash", str(LAUNCHER), "https://example.com"],
                env=environment,
                text=True,
                capture_output=True,
                timeout=10,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(counter.read_text(encoding="utf-8").strip(), "2")
            self.assertEqual(result.stderr, "")


if __name__ == "__main__":
    unittest.main()
