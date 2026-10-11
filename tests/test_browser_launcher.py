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
            fake_browser = fake_bin / "google-chrome-stable"
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

    def test_about_blank_uses_atlas_homepage(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            fake_bin = root / "bin"
            fake_bin.mkdir()
            received = root / "arguments"
            fake_browser = fake_bin / "google-chrome-stable"
            fake_browser.write_text(
                "#!/bin/sh\nprintf '%s\\n' \"$@\" > '" + str(received) + "'\nexit 0\n",
                encoding="utf-8",
            )
            fake_browser.chmod(0o755)
            environment = os.environ.copy()
            environment.update({"PATH": str(fake_bin) + os.pathsep + environment.get("PATH", ""), "HOME": str(root / "home"), "XDG_CACHE_HOME": str(root / "cache")})
            result = subprocess.run(["bash", str(LAUNCHER), "about:blank"], env=environment, text=True, capture_output=True, timeout=10, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(received.read_text(encoding="utf-8").splitlines(), ["--new-window", "https://chavooosss.github.io/AtlasOS/"])

    def test_missing_browser_cancel_does_not_request_privileged_install(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            fake_bin = root / "bin"
            fake_bin.mkdir()
            for name in ("mkdir", "date", "flock"):
                (fake_bin / name).symlink_to(shutil.which(name))
            marker = root / "pkexec-called"
            zenity = fake_bin / "zenity"
            zenity.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
            zenity.chmod(0o755)
            pkexec = fake_bin / "pkexec"
            pkexec.write_text("#!/bin/sh\nprintf called > '" + str(marker) + "'\nexit 0\n", encoding="utf-8")
            pkexec.chmod(0o755)
            environment = os.environ.copy()
            environment.update({"PATH": str(fake_bin), "HOME": str(root / "home"), "XDG_CACHE_HOME": str(root / "cache")})
            result = subprocess.run(["/bin/bash", str(LAUNCHER)], env=environment, text=True, capture_output=True, timeout=10, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(marker.exists(), "declining the dialog must not run the privileged installer")


if __name__ == "__main__":
    unittest.main()
