import os
import pathlib
import shutil
import subprocess
import unittest
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
POLICY = ROOT / "config/includes.chroot/usr/share/polkit-1/actions/org.atlasos.install-google-chrome.policy"
RULE = ROOT / "config/includes.chroot/etc/polkit-1/rules.d/49-atlasos-live-chrome.rules"
HELPER = ROOT / "config/includes.chroot/usr/local/libexec/atlasos-install-google-chrome"
LAUNCHER = ROOT / "config/includes.chroot/usr/local/bin/atlasos-browser"
HOOK = ROOT / "config/hooks/normal/010-atlasos-branding.hook.chroot"


class ChromePrivilegePolicyTests(unittest.TestCase):
    def test_dedicated_action_is_bound_to_exact_helper_with_conservative_defaults(self):
        action = ET.parse(POLICY).getroot().find("./action[@id='org.atlasos.install-google-chrome']")
        self.assertIsNotNone(action)
        action_ids = {node.attrib.get("id") for node in ET.parse(POLICY).getroot().findall("action")}
        self.assertEqual(action_ids, {"org.atlasos.install-google-chrome"})
        annotations = {node.attrib["key"]: node.text for node in action.findall("annotate")}
        self.assertEqual(
            annotations.get("org.freedesktop.policykit.exec.path"),
            "/usr/local/libexec/atlasos-install-google-chrome",
        )
        defaults = action.find("defaults")
        self.assertEqual(defaults.findtext("allow_any"), "no")
        self.assertEqual(defaults.findtext("allow_inactive"), "auth_admin")
        self.assertEqual(defaults.findtext("allow_active"), "auth_admin")

    def test_rule_grants_only_live_atlas_active_local_session(self):
        rule = RULE.read_text(encoding="utf-8")
        for required in (
            'action.id !== "org.atlasos.install-google-chrome"',
            'subject.user !== "atlas"',
            "subject.active !== true",
            "subject.local !== true",
            "polkit.Result.YES",
            "polkit.Result.NOT_HANDLED",
            "boot=casper",
            '"/rofs"',
            '"squashfs"',
            '"ro"',
        ):
            self.assertIn(required, rule)
        self.assertNotIn("org.freedesktop.policykit.exec", rule)

    def test_helper_is_fixed_zero_argument_live_only_root_installer(self):
        helper = HELPER.read_text(encoding="utf-8")
        for required in (
            "if (( $# != 0 ))",
            "if (( EUID != 0 ))",
            "boot=casper",
            '"$FINDMNT" --noheadings --raw --mountpoint /rofs --output FSTYPE,OPTIONS',
            '[[ "$filesystem" == squashfs ]]',
            '[[ "$option" == ro ]]',
            "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb",
            "--field \"$package_file\" Package",
            "--field \"$package_file\" Architecture",
            "--field \"$package_file\" Version",
            "package_name\" != google-chrome-stable",
            "package_arch\" != amd64",
            "package_version\" =~ ^[0-9]",
            "package_version\" =~ ^[0-9]",
            "apt-get",
            "trap",
            "/usr/bin/",
        ):
            self.assertIn(required, helper)
        for forbidden in ("eval ", "sh -c", "bash -c", '"$@"', "NOPASSWD: ALL"):
            self.assertNotIn(forbidden, helper)

    def test_casper_hook_keeps_helper_and_policy_root_owned_and_diagnostics_sudo_scoped(self):
        hook = HOOK.read_text(encoding="utf-8")
        self.assertIn("chown root:root /usr/local/libexec/atlasos-install-google-chrome", hook)
        self.assertIn("chmod 0755 /usr/local/libexec/atlasos-install-google-chrome", hook)
        self.assertIn("org.atlasos.install-google-chrome.policy", hook)
        self.assertIn("49-atlasos-live-chrome.rules", hook)
        self.assertIn("atlasos-privileged-diagnostics", hook)
        self.assertNotIn("passwd root", hook)
        self.assertNotIn("chpasswd", HELPER.read_text(encoding="utf-8"))
        self.assertNotIn("chpasswd", HELPER.read_text(encoding="utf-8"))

    def test_pkexec_gets_no_user_supplied_arguments_and_browser_homepage_is_unchanged(self):
        launcher = LAUNCHER.read_text(encoding="utf-8")
        self.assertIn("pkexec /usr/local/libexec/atlasos-install-google-chrome", launcher)
        self.assertIn("https://chavooosss.github.io/AtlasOS/", launcher)
        self.assertIn("--text=", launcher)
        self.assertIn("https://policies.google.com/terms", launcher)
        self.assertIn("echo \"URL: [redacted]\"", launcher)
        self.assertNotIn('echo "URL: ${url}"', launcher)
        self.assertNotIn("pkexec /usr/local/libexec/atlasos-install-google-chrome \"$", launcher)

    def test_helper_rejects_arguments_before_privilege_checks(self):
        result = subprocess.run(["/bin/bash", str(HELPER), "unexpected"], text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 64, result.stderr)

    def test_helper_rejects_nonroot_caller(self):
        if os.geteuid() == 0:
            nobody = shutil.which("runuser")
            if not nobody:
                self.skipTest("runuser unavailable to test a non-root identity")
            command = [nobody, "-u", "nobody", "--", "/bin/bash", str(HELPER)]
        else:
            command = ["/bin/bash", str(HELPER)]
        result = subprocess.run(command, text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 77, result.stderr)

    def test_root_invocation_rejects_nonlive_system(self):
        if os.geteuid() == 0:
            command = ["/bin/bash", str(HELPER)]
        elif shutil.which("sudo") and subprocess.run(["sudo", "-n", "true"], text=True, capture_output=True, check=False).returncode == 0:
            command = ["sudo", "-n", "/bin/bash", str(HELPER)]
        else:
            self.skipTest("passwordless sudo is unavailable for the non-live root-gate check")
        result = subprocess.run(command, text=True, capture_output=True, check=False)
        self.assertEqual(result.returncode, 78, result.stderr)


if __name__ == "__main__":
    unittest.main()
