import json
import fnmatch
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

    def test_chrome_and_google_repository_absent_from_active_build_inputs(self):
        active = [
            "config/package-lists/atlasos-live.list.chroot",
            "iso/build-atlasos.sh",
            "config/hooks/normal/010-atlasos-branding.hook.chroot",
            "config/includes.chroot/usr/local/bin/atlasos-browser",
            "config/includes.chroot/usr/local/bin/atlasos-open-request",
            "config/includes.chroot/usr/local/share/atlasos/ui/Main.qml",
        ]
        for relative in active:
            content = (ROOT / relative).read_text(encoding="utf-8", errors="replace").lower()
            self.assertNotIn("google-chrome", content, relative)
            self.assertNotIn("dl.google.com", content, relative)

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
