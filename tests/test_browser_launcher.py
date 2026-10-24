import os
import pathlib
import shutil
import subprocess
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
LAUNCHER = ROOT / "config/includes.chroot/usr/local/bin/atlasos-browser"


def fake_curl(fake_bin, body=None):
    executable = fake_bin / "curl"
    executable.write_text("#!/bin/bash\n" + (body or "printf '200'\nexit 0\n"), encoding="utf-8")
    executable.chmod(0o755)
    return executable


def fake_browser(fake_bin, body="exit 0\n"):
    executable = fake_bin / "google-chrome-stable"
    executable.write_text("#!/bin/sh\n" + body, encoding="utf-8")
    executable.chmod(0o755)
    return executable


@unittest.skipUnless(os.name == "posix" and shutil.which("bash") and shutil.which("flock"), "requires bash and flock")
class BrowserLauncherTests(unittest.TestCase):
    def environment(self, root, fake_bin, **extra):
        env = os.environ.copy()
        env.update({
            "PATH": str(fake_bin) + os.pathsep + env.get("PATH", ""),
            "HOME": str(root / "home"),
            "XDG_CACHE_HOME": str(root / "cache"),
        })
        env.update(extra)
        return env

    def run_launcher(self, root, env, url="https://example.com"):
        return subprocess.run(["bash", str(LAUNCHER), url], env=env, text=True,
                              capture_output=True, timeout=10, check=False)

    def test_retries_one_transient_137_without_showing_error(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            fake_bin = root / "bin"
            fake_bin.mkdir()
            counter = root / "launch-count"
            browser = fake_bin / "google-chrome-stable"
            browser.write_text(
                "#!/bin/sh\n"
                f"count=0; test ! -f '{counter}' || read count < '{counter}'\n"
                f"count=$((count + 1)); printf '%s\n' \"$count\" > '{counter}'\n"
                "if test \"$count\" -eq 1; then exit 137; fi\n"
                "exit 0\n", encoding="utf-8")
            browser.chmod(0o755)
            fake_curl(fake_bin)
            result = self.run_launcher(root, self.environment(root, fake_bin), "https://example.com")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(counter.read_text().strip(), "2")
            self.assertEqual(result.stderr, "")

    def test_about_blank_uses_atlas_homepage(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            fake_bin = root / "bin"
            fake_bin.mkdir()
            received = root / "arguments"
            fake_browser(fake_bin, "printf '%s\n' \"$@\" > '" + str(received) + "'\n")
            fake_curl(fake_bin)
            result = self.run_launcher(root, self.environment(root, fake_bin), "about:blank")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(received.read_text().splitlines(),
                             ["--new-window", "https://chavooosss.github.io/AtlasOS/"])

    def test_https_probe_classifies_failures_without_logging_secrets_or_url(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            fake_bin = root / "bin"
            fake_bin.mkdir()
            fake_browser(fake_bin)
            fake_curl(fake_bin, "case \"$*\" in *example.com*) printf '200'; exit 0 ;; *) exit 6 ;; esac\n")
            env = self.environment(root, fake_bin, https_proxy="http://student:private-value@proxy.school.invalid:8080")
            target = "https://atlas.invalid/?token=do-not-log"
            result = self.run_launcher(root, env, target)
            self.assertEqual(result.returncode, 0, result.stderr)
            log = (root / "cache/atlasos/browser.log").read_text()
            self.assertIn("Proxy configuration: env=https_proxy", log)
            self.assertIn("atlas=failed category=dns curl_exit=6", log)
            self.assertIn("example=ok http=200", log)
            self.assertNotIn("private-value", log)
            self.assertNotIn("do-not-log", log)
            self.assertIn("Genel HTTPS erişimi var", result.stderr)

    def test_https_probe_reports_interrupted_response_separately_from_tls(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            fake_bin = root / "bin"
            fake_bin.mkdir()
            fake_browser(fake_bin)
            fake_curl(fake_bin, "exit 56\n")
            result = self.run_launcher(root, self.environment(root, fake_bin))
            log = (root / "cache/atlasos/browser.log").read_text()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("atlas=failed category=interrupted curl_exit=56", log)
            self.assertIn("example=failed category=interrupted curl_exit=56", log)
            self.assertIn("yanıt alınırken kesildi", result.stderr)
            self.assertNotIn("TLS/sertifika", result.stderr)

    def test_https_probe_explains_untrusted_certificate_without_disabling_validation(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            fake_bin = root / "bin"
            fake_bin.mkdir()
            fake_browser(fake_bin)
            fake_curl(fake_bin, "exit 60\n")
            result = self.run_launcher(root, self.environment(root, fake_bin))
            log = (root / "cache/atlasos/browser.log").read_text()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("category=certificate curl_exit=60", log)
            self.assertIn("sertifikası AtlasOS tarafından güvenilir bulunmadı", result.stderr)
            self.assertIn("sertifika kontrolü kapatılmadı", result.stderr)

    def test_https_probe_maps_tls_certificate_and_ca_store_codes(self):
        expected = {35: "tls", 51: "certificate", 58: "tls", 60: "certificate", 77: "ca_store"}
        for curl_exit, category in expected.items():
            with self.subTest(curl_exit=curl_exit), tempfile.TemporaryDirectory() as temporary:
                root = pathlib.Path(temporary)
                fake_bin = root / "bin"
                fake_bin.mkdir()
                fake_browser(fake_bin)
                fake_curl(fake_bin, f"exit {curl_exit}\n")
                result = self.run_launcher(root, self.environment(root, fake_bin))
                log = (root / "cache/atlasos/browser.log").read_text()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(f"curl_exit={curl_exit}", log)
                self.assertIn(f"category={category}", log)

    def test_browser_and_https_diagnostics_keep_certificate_verification_enabled(self):
        launcher = LAUNCHER.read_text()
        for unsafe_option in ("--ignore-certificate-errors", "--allow-insecure-localhost", "--insecure"):
            self.assertNotIn(unsafe_option, launcher)
        self.assertNotIn("curl -k", launcher)
        self.assertNotIn("curl --insecure", launcher)
        self.assertIn("browser_args=(--new-window)", launcher)

    def test_browser_diagnostics_do_not_copy_browser_output_into_log(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            fake_bin = root / "bin"
            fake_bin.mkdir()
            fake_browser(fake_bin, "printf 'private-browser-output\n' >&2\nexit 9\n")
            fake_curl(fake_bin)
            result = self.run_launcher(root, self.environment(root, fake_bin),
                                       "https://example.com/?secret=query")
            self.assertEqual(result.returncode, 9)
            log = (root / "cache/atlasos/browser.log").read_text()
            self.assertIn("Browser launch attempt 1 exited with status 9", log)
            self.assertNotIn("private-browser-output", log)
            self.assertNotIn("secret=query", log)

    def test_missing_browser_cancel_does_not_request_privileged_install(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            fake_bin = root / "bin"
            fake_bin.mkdir()
            for name in ("mkdir", "date", "flock"):
                (fake_bin / name).symlink_to(shutil.which(name))
            marker = root / "pkexec-called"
            (fake_bin / "zenity").write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
            (fake_bin / "zenity").chmod(0o755)
            (fake_bin / "pkexec").write_text("#!/bin/sh\nprintf called > '" + str(marker) + "'\nexit 0\n", encoding="utf-8")
            (fake_bin / "pkexec").chmod(0o755)
            env = self.environment(root, fake_bin)
            result = subprocess.run(["/bin/bash", str(LAUNCHER)], env=env, text=True,
                                    capture_output=True, timeout=10, check=False)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(marker.exists())

    def test_chromium_scale_tracks_board_and_laptop_modes(self):
        for scale, expected in (("1.32", "--force-device-scale-factor=1.32"), ("1.0", None)):
            with self.subTest(scale=scale), tempfile.TemporaryDirectory() as temporary:
                root = pathlib.Path(temporary)
                fake_bin = root / "bin"
                fake_bin.mkdir()
                received = root / "arguments"
                fake_browser(fake_bin, "printf '%s\n' \"$@\" > '" + str(received) + "'\n")
                fake_curl(fake_bin)
                result = self.run_launcher(root, self.environment(root, fake_bin, ATLASOS_CHROME_SCALE_FACTOR=scale))
                self.assertEqual(result.returncode, 0, result.stderr)
                args = received.read_text().splitlines()
                if expected:
                    self.assertIn(expected, args)
                else:
                    self.assertFalse(any(arg.startswith("--force-device-scale-factor=") for arg in args))

    def test_invalid_chromium_scale_fails_back_to_unscaled(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = pathlib.Path(temporary)
            fake_bin = root / "bin"
            fake_bin.mkdir()
            received = root / "arguments"
            fake_browser(fake_bin, "printf '%s\n' \"$@\" > '" + str(received) + "'\n")
            fake_curl(fake_bin)
            result = self.run_launcher(root, self.environment(root, fake_bin,
                                                              ATLASOS_CHROME_SCALE_FACTOR="3.5"))
            self.assertEqual(result.returncode, 0, result.stderr)
            args = received.read_text().splitlines()
            self.assertFalse(any(arg.startswith("--force-device-scale-factor=") for arg in args))
            log = (root / "cache/atlasos/browser.log").read_text()
            self.assertIn("Chromium UI scale for next launch: 1.0", log)


if __name__ == "__main__":
    unittest.main()
