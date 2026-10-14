import importlib.machinery
import importlib.util
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
UI = ROOT / "config/includes.chroot/usr/local/bin/atlasos-ui"
COMPONENTS = ROOT / "config/includes.chroot/usr/local/share/atlasos/ui/components"
NETWORK_RULE = ROOT / "config/includes.chroot/etc/polkit-1/rules.d/50-atlasos-live-network.rules"
NETWORKMANAGER_ETHERNET_POLICY = ROOT / "config/includes.chroot/etc/NetworkManager/conf.d/20-atlasos-managed-ethernet.conf"
NETWORKMANAGER_VENDOR_POLICY_OVERRIDE = ROOT / "config/includes.chroot/etc/NetworkManager/conf.d/10-globally-managed-devices.conf"


class SmartboardDemoTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        loader = importlib.machinery.SourceFileLoader("atlasos_ui_demo_test", str(UI))
        spec = importlib.util.spec_from_loader(loader.name, loader)
        cls.ui = importlib.util.module_from_spec(spec)
        loader.exec_module(cls.ui)

    def test_board_density_uses_real_viewport_and_material_cards_wrap(self):
        main = (COMPONENTS.parent / "Main.qml").read_text(encoding="utf-8")
        material = (COMPONENTS / "AtlasLessonDashboard.qml").read_text(encoding="utf-8")
        self.assertIn("Math.min(root.width / 1920, root.height / 1080) * 1.32", main)
        self.assertIn("Math.min(2.64", main)
        self.assertIn("Flow {", material)
        self.assertIn("Controls.ScrollBar.vertical", material)

    def test_live_network_authorization_is_limited_to_active_atlas_session(self):
        rule = NETWORK_RULE.read_text(encoding="utf-8")
        for required in ('subject.user !== "atlas"', "subject.active !== true", "subject.local !== true",
                         "boot=casper", '"squashfs"', '"ro"', "polkit.Result.NOT_HANDLED"):
            self.assertIn(required, rule)
        self.assertIn("org.freedesktop.NetworkManager.network-control", rule)
        self.assertIn("org.freedesktop.NetworkManager.wifi.scan", rule)
        self.assertNotIn("settings.modify.system", rule)

    def test_live_ethernet_is_explicitly_managed_by_networkmanager(self):
        policy = NETWORKMANAGER_ETHERNET_POLICY.read_text(encoding="utf-8")
        hook = (ROOT / "config/hooks/normal/010-atlasos-branding.hook.chroot").read_text(encoding="utf-8")
        self.assertIn("match-device=type:ethernet", policy)
        self.assertIn("managed=1", policy)
        self.assertIn("systemctl enable NetworkManager.service", hook)
        self.assertNotIn("match-device=*", policy)

    def test_live_ethernet_masks_vendor_unmanaged_default(self):
        self.assertTrue(NETWORKMANAGER_VENDOR_POLICY_OVERRIDE.is_file())
        self.assertEqual(NETWORKMANAGER_VENDOR_POLICY_OVERRIDE.stat().st_size, 0)

    def test_audio_exposes_real_sinks_and_never_selects_dummy(self):
        nodes = [
            {"id": 45, "info": {"props": {"media.class": "Audio/Sink", "node.description": "HDMI Board"}}},
            {"id": 46, "info": {"props": {"media.class": "Audio/Sink", "node.name": "auto_null"}}},
        ]

        def command(args, **_kwargs):
            if args[0] == "pw-dump":
                return SimpleNamespace(returncode=0, stdout=json.dumps(nodes))
            if args[:2] == ["wpctl", "inspect"]:
                return SimpleNamespace(returncode=0, stdout="id 45, type PipeWire:Interface:Node")
            return SimpleNamespace(returncode=0, stdout="Volume: 0.40")

        with patch.object(self.ui.subprocess, "run", side_effect=command) as run:
            audio = self.ui.AtlasAudio()
            self.assertEqual(audio.outputs[0]["name"], "HDMI Board")
            self.assertTrue(audio.outputs[0]["selected"])
            self.assertTrue(audio.outputs[1]["virtual"])
            audio.selectOutput(46)
            self.assertFalse(any(call.args[0][:2] == ["wpctl", "set-default"] for call in run.call_args_list))
            audio.selectOutput(45)
            self.assertTrue(any(call.args[0] == ["wpctl", "set-default", "45"] for call in run.call_args_list))

    def test_chrome_progress_is_stage_based_and_backend_stays_fixed(self):
        launcher = (ROOT / "config/includes.chroot/usr/local/bin/atlasos-browser").read_text(encoding="utf-8")
        helper = (ROOT / "config/includes.chroot/usr/local/libexec/atlasos-install-google-chrome").read_text(encoding="utf-8")
        self.assertIn("--pulsate --no-cancel", launcher)
        self.assertIn("pkexec /usr/local/libexec/atlasos-install-google-chrome", launcher)
        self.assertIn("ATLASOS_STAGE:download", helper)
        self.assertIn("ATLASOS_STAGE:verify", helper)
        self.assertIn("ATLASOS_STAGE:install", helper)
        self.assertNotIn("--percentage", launcher)


if __name__ == "__main__":
    unittest.main()
