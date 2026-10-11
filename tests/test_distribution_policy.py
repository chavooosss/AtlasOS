import hashlib
import json
import fnmatch
import subprocess
import unittest

from tools.ci.check_repo import ROOT, manifest_source_files


class DistributionPolicyTests(unittest.TestCase):
    def test_project_license_is_scoped_and_atlas_boot_keeps_its_license(self):
        license_text = (ROOT / "LICENSE").read_text(encoding="utf-8")
        scope = (ROOT / "docs/legal/project-license-scope.md").read_text(encoding="utf-8")
        crate = (ROOT / "atlas-boot/Cargo.toml").read_text(encoding="utf-8")
        self.assertIn("MIT License", license_text)
        self.assertIn("third-party", scope.lower())
        self.assertIn('license = "MIT OR Apache-2.0"', crate)

    def test_chrome_is_optional_and_official_install_is_explicit(self):
        image_inputs = [
            "config/package-lists/atlasos-live.list.chroot",
            "iso/build-atlasos.sh",
            "config/hooks/normal/010-atlasos-branding.hook.chroot",
        ]
        for relative in image_inputs:
            content = (ROOT / relative).read_text(encoding="utf-8", errors="replace").lower()
            if relative == "config/hooks/normal/010-atlasos-branding.hook.chroot":
                content = content.replace("atlasos-install-google-chrome", "atlasos-install-browser-helper")
                content = content.replace("org.atlasos.install-google-chrome", "org.atlasos.install-browser-helper")
            self.assertNotIn("google-chrome", content, relative)
            self.assertNotIn("dl.google.com", content, relative)
        launcher = (ROOT / "config/includes.chroot/usr/local/bin/atlasos-browser").read_text(encoding="utf-8")
        installer = (ROOT / "config/includes.chroot/usr/local/libexec/atlasos-install-google-chrome").read_text(encoding="utf-8")
        self.assertIn("google-chrome-stable", launcher)
        self.assertIn("https://chavooosss.github.io/AtlasOS/", launcher)
        self.assertIn("Şartları inceledim · indir", launcher)
        self.assertIn("pkexec /usr/local/libexec/atlasos-install-google-chrome", launcher)
        self.assertIn("https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb", installer)
        self.assertIn('if [[ "$package_name" != google-chrome-stable', installer)
        self.assertIn('if [[ "$package_name" != google-chrome-stable || "$package_arch" != amd64', installer)

    def test_rights_uncertain_assets_are_not_public_source_candidates(self):
        manifest = json.loads((ROOT / "docs/project/first-commit-manifest.json").read_text(encoding="utf-8"))
        inventory = json.loads((ROOT / "docs/legal/asset-inventory.json").read_text(encoding="utf-8"))
        candidates = manifest_source_files(manifest)
        self.assertIn("LICENSE", candidates)
        self.assertIn("atlas-boot/fonts/source/UbuntuSans.ttf", candidates)
        self.assertIn("atlas-boot/fonts/source/LICENSE-Ubuntu.txt", candidates)
        for required_art in (
            "assets/branding/atlasos-logo-seedream-master.png",
            "assets/branding/atlasos-emblem-traced.svg",
            "atlas-boot/assets/source/atlas-boot-landscape.png",
            "atlas-boot/assets/generated/landscape.rgba",
            "config/includes.chroot/usr/share/plymouth/themes/atlasos/atlas-logo.png",
        ):
            self.assertIn(required_art, candidates)
        self.assertNotIn("atlas-boot/assets/source/phase5-reference.png", candidates)
        self.assertNotIn("config/includes.chroot/usr/local/share/atlasos/ui/sounds/atlasos-startup.wav", candidates)
        for asset in inventory["assets"]:
            if asset["redistribution_status"] == "EXCLUDE-FROM-PUBLICATION":
                path = asset["path"]
                if path.startswith("package:"):
                    continue
                self.assertFalse(any(fnmatch.fnmatchcase(candidate, path) for candidate in candidates), path)

    def test_branding_preparation_reuses_tracked_assets_without_mutating_them(self):
        script = ROOT / "iso/prepare-branding-assets.sh"
        source = script.read_text(encoding="utf-8")
        self.assertNotIn("docs/assets", source)

        tracked = subprocess.run(
            [
                "git",
                "ls-files",
                "--",
                "config/includes.chroot/usr/local/share/atlasos/ui/branding",
                "config/includes.chroot/usr/share/atlasos/branding",
                "config/includes.chroot/usr/share/plymouth/themes/atlasos",
            ],
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=True,
        )
        assets = [ROOT / path for path in tracked.stdout.splitlines() if path]
        self.assertTrue(assets, "expected tracked AtlasOS branding assets")
        before = {path: hashlib.sha256(path.read_bytes()).hexdigest() for path in assets}

        result = subprocess.run(
            ["bash", str(script)], cwd=ROOT, text=True, capture_output=True, check=False
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("reused", result.stdout)
        after = {path: hashlib.sha256(path.read_bytes()).hexdigest() for path in assets}
        self.assertEqual(before, after, "branding preparation must not rewrite tracked artwork")

    def test_ai_asset_clearance_records_provider_and_third_party_review(self):
        inventory = json.loads((ROOT / "docs/legal/asset-inventory.json").read_text(encoding="utf-8"))
        cleared = [a for a in inventory["assets"] if a["redistribution_status"] == "AI-GENERATED-CLEARED"]
        self.assertTrue(cleared)
        for asset in cleared:
            self.assertTrue(asset.get("provider"), asset["path"])
            self.assertTrue(asset.get("provider_terms_status"), asset["path"])
            self.assertTrue(asset.get("third_party_content_status"), asset["path"])
            self.assertIn("no exclusive copyright claim", asset["publication_status"].lower())
        policy = (ROOT / "docs/legal/ai-generated-assets.md").read_text(encoding="utf-8")
        self.assertIn("does **not** claim exclusive copyright", policy)

    def test_historical_binary_is_not_marked_ready(self):
        release = json.loads((ROOT / "docs/release/release-manifest-0.6.2.json").read_text(encoding="utf-8"))
        self.assertIn("not public", release["rights"]["binary_publication"].lower())
        self.assertIn("not a public", release["artifact"]["selection"].lower())


if __name__ == "__main__":
    unittest.main()
