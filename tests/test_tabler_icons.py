import re
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UI = ROOT / "config/includes.chroot/usr/local/share/atlasos/ui"
ICON_COMPONENT = UI / "components/AtlasIcon.qml"
ICON_ASSETS = UI / "icons/tabler"

REQUIRED_NAMES = {
    "home", "lessons", "files", "applications", "settings", "about", "help", "power",
    "wifi", "network", "ethernet", "airplane", "airplane-mode", "logout", "restart", "notifications", "volume", "volume-low", "volume-muted", "pen", "bell",
    "display", "accessibility", "developer", "bluetooth", "night-light", "cast", "search",
    "arrow-left", "arrow-right", "arrow-up", "arrow-down", "close", "refresh", "folder",
    "document", "pdf", "video", "presentation", "whiteboard", "calendar", "clock", "bulb",
    "check", "warning", "error", "info", "download", "upload", "trash", "menu", "list",
    "grid", "fullscreen", "minimize", "external-link", "lock", "unlock", "usb", "book", "school",
    "books", "eba", "ogm", "mebi", "screen-draw", "browser", "chemistry", "physics", "office",
    "terminal", "file", "star",
}


class TablerIconTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.qml = ICON_COMPONENT.read_text(encoding="utf-8")
        cls.mapping = dict(re.findall(r'"([^"\n]+)"\s*:\s*"([^"\n]+)"', cls.qml))

    def test_all_system_and_legacy_names_resolve_to_local_tabler_svg(self):
        self.assertTrue(REQUIRED_NAMES.issubset(self.mapping.keys()))
        for tabler_name in self.mapping.values():
            path = ICON_ASSETS / f"{tabler_name}.svg"
            self.assertTrue(path.is_file(), f"missing SVG for {tabler_name}")

    def test_assets_are_monochrome_outline_tabler_svg(self):
        svg_files = sorted(ICON_ASSETS.glob("*.svg"))
        self.assertGreater(len(svg_files), 0)
        self.assertEqual({p.stem for p in svg_files}, set(self.mapping.values()))
        for path in svg_files:
            root = ET.parse(path).getroot()
            self.assertEqual(root.tag.rsplit("}", 1)[-1], "svg", path.name)
            self.assertEqual(root.get("viewBox"), "0 0 24 24", path.name)
            self.assertEqual(root.get("fill"), "none", path.name)
            self.assertEqual(root.get("stroke"), "#ffffff", path.name)
            self.assertEqual(root.get("stroke-linecap"), "round", path.name)
            self.assertEqual(root.get("stroke-linejoin"), "round", path.name)

    def test_semantic_aliases_remain_distinct(self):
        distinct_pairs = (
            ("bluetooth", "wifi"),
            ("airplane", "wifi"),
            ("ethernet", "wifi"),
            ("ethernet", "network"),
            ("files", "lessons"),
            ("developer", "settings"),
            ("browser", "applications"),
            ("logout", "arrow-right"),
            ("network", "wifi"),
            ("display", "screen-draw"),
            ("cast", "display"),
            ("power", "restart"),
        )
        for left, right in distinct_pairs:
            with self.subTest(left=left, right=right):
                self.assertNotEqual(self.mapping[left], self.mapping[right])

    def test_ui_uses_semantic_icons_for_confirmed_concepts(self):
        components = UI / "components"
        quick = (components / "AtlasQuickSettings.qml").read_text(encoding="utf-8")
        sidebar = (components / "AtlasSidebar.qml").read_text(encoding="utf-8")
        settings_nav = (components / "AtlasSettingsNav.qml").read_text(encoding="utf-8")
        home = (components / "AtlasHomeDashboard.qml").read_text(encoding="utf-8")
        power = (components / "AtlasPowerMenu.qml").read_text(encoding="utf-8")
        self.assertIn('{label: "Bluetooth", icon: "bluetooth"}', quick)
        self.assertIn('{label: "Uçak Modu", icon: "airplane"}', quick)
        self.assertIn('name: "wifi"', quick)
        self.assertIn('name: "ethernet"', quick)
        self.assertIn('{ label: "Dersler", icon: "books"', sidebar)
        self.assertIn('{ label: "Dosyalar", icon: "files"', sidebar)
        self.assertIn('label: "Geliştirici", hint: "Güvenli tanılama", icon: "developer"', settings_nav)
        self.assertIn('{key: "display", label: "Görünüm", hint: "Ekran ve boyut", icon: "display"}', settings_nav)
        self.assertIn('title: "Web Tarayıcısı"; detail: "Web sayfalarını aç"; iconName: "browser"', home)
        self.assertIn('label: "Oturumu Kapat"', power)
        self.assertIn('icon: "logout"', power)

    def test_qml_uses_local_svg_with_runtime_theme_tint(self):
        self.assertIn("../icons/tabler/", self.qml)
        self.assertIn("colorizationColor: icon.strokeColor", self.qml)
        self.assertIn("colorization: 1.0", self.qml)
        self.assertNotIn("Canvas {", self.qml)
        package_list = (ROOT / "config/package-lists/atlasos-live.list.chroot").read_text(encoding="utf-8")
        self.assertIn("qml6-module-qtquick-effects", package_list)
        self.assertIn("qt6-svg-plugins", package_list)

    def test_upstream_license_notice_and_attribution_are_present(self):
        license_text = (ICON_ASSETS / "LICENSE.txt").read_text(encoding="utf-8")
        self.assertIn("MIT License", license_text)
        self.assertIn("Paweł Kuna", license_text)
        inventory = (ROOT / "docs/legal/third-party-inventory.md").read_text(encoding="utf-8")
        self.assertIn("Tabler Icons v3.49.0", inventory)
        self.assertIn("tabler.io/license", inventory)


if __name__ == "__main__":
    unittest.main()
