import importlib.machinery
import importlib.util
import io
import json
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import wave


ROOT = Path(__file__).resolve().parents[1]
UI = ROOT / "config/includes.chroot/usr/local/bin/atlasos-ui"
COMPONENTS = ROOT / "config/includes.chroot/usr/local/share/atlasos/ui/components"
NETWORK_RULE = ROOT / "config/includes.chroot/etc/polkit-1/rules.d/50-atlasos-live-network.rules"
NETWORKMANAGER_ETHERNET_POLICY = ROOT / "config/includes.chroot/etc/NetworkManager/conf.d/20-atlasos-managed-ethernet.conf"
NETWORKMANAGER_VENDOR_POLICY_OVERRIDE = ROOT / "config/includes.chroot/etc/NetworkManager/conf.d/10-globally-managed-devices.conf"


class SmartboardDemoTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.ui = None

    def load_ui(self):
        if self.ui is None:
            loader = importlib.machinery.SourceFileLoader("atlasos_ui_demo_test", str(UI))
            spec = importlib.util.spec_from_loader(loader.name, loader)
            self.__class__.ui = importlib.util.module_from_spec(spec)
            try:
                loader.exec_module(self.__class__.ui)
            except ModuleNotFoundError as error:
                if error.name == "PySide6" or (error.name and error.name.startswith("PySide6.")):
                    self.skipTest("PySide6 is required for the AtlasAudio runtime test")
                raise
        return self.ui

    def test_board_density_uses_real_viewport_and_material_cards_wrap(self):
        main = (COMPONENTS.parent / "Main.qml").read_text(encoding="utf-8")
        material = (COMPONENTS / "AtlasLessonDashboard.qml").read_text(encoding="utf-8")
        self.assertIn("Math.min(2.0,", main)
        self.assertIn("Math.min(root.width / 1920, root.height / 1080) * 1.32", main)
        self.assertNotIn("Math.min(2.64", main)
        self.assertIn("Flow {", material)
        self.assertIn("Controls.ScrollBar.vertical", material)

    def test_scaled_button_text_is_bounded_by_available_content_width(self):
        button = (COMPONENTS / "AtlasButton.qml").read_text(encoding="utf-8")
        self.assertIn("control.availableWidth", button)
        self.assertIn("TextMetrics", button)
        self.assertIn("buttonLabelMetrics.advanceWidth", button)
        self.assertIn("buttonIcon.width + buttonContent.spacing", button)
        self.assertIn("wrapMode: Text.NoWrap", button)
        self.assertIn("elide: Text.ElideRight", button)

    def test_settings_cards_and_navigation_scale_as_one_density(self):
        settings = (COMPONENTS / "AtlasSettings.qml").read_text(encoding="utf-8")
        navigation = (COMPONENTS / "AtlasSettingsNav.qml").read_text(encoding="utf-8")
        self.assertIn("height: 112 * panel.density", settings)
        self.assertIn("width: 205 * panel.density", settings)
        self.assertIn("Math.min(parent.width * 0.30", settings)
        self.assertIn("anchors.margins: 10 * navigation.density", navigation)
        self.assertIn("spacing: 5 * navigation.density", navigation)

    def test_network_and_files_controls_follow_smartboard_density(self):
        network = (COMPONENTS / "AtlasNetwork.qml").read_text(encoding="utf-8")
        files = (COMPONENTS / "AtlasFiles.qml").read_text(encoding="utf-8")
        self.assertIn("height: 58 * panel.density", network)
        self.assertIn("height: 24 * panel.density", network)
        self.assertIn("height: 60 * panel.density", network)
        self.assertIn("width: 30 * panel.density; height: 30 * panel.density", network)
        self.assertIn("controlScale: panel.density", network)
        self.assertIn("height: 56 * files.uiScale", files)
        self.assertIn("font.pixelSize: 16 * files.uiScale", files)
        self.assertIn("font.pixelSize: 13 * files.uiScale", files)
        self.assertIn("height: parent.height - (files.width < 1450 ? 86 : 98) * files.uiScale", files)

    def test_developer_and_quick_settings_follow_board_density(self):
        header = (COMPONENTS / "AtlasHeader.qml").read_text(encoding="utf-8")
        quick = (COMPONENTS / "AtlasQuickSettings.qml").read_text(encoding="utf-8")
        developer = (COMPONENTS / "AtlasDeveloper.qml").read_text(encoding="utf-8")
        settings = (COMPONENTS / "AtlasSettings.qml").read_text(encoding="utf-8")
        self.assertIn("quickSettingsDensity", header)
        self.assertIn("density: header.quickSettingsDensity", header)
        self.assertIn("scale: quick.density", quick)
        self.assertIn("property real density: 1.0", developer)
        self.assertIn("implicitHeight: content.implicitHeight * page.density", developer)
        self.assertIn("item.density = panel.density", settings)

    def test_sound_settings_offer_non_privileged_output_test(self):
        settings = (COMPONENTS / "AtlasSettings.qml").read_text(encoding="utf-8")
        self.assertIn('text: "Kısa test sesi çal"', settings)
        self.assertIn("panel.audioController.testOutput()", settings)

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

        with patch.object(self.load_ui().subprocess, "run", side_effect=command) as run:
            audio = self.ui.AtlasAudio()
            self.assertEqual(audio.outputs[0]["name"], "HDMI Board")
            self.assertTrue(audio.outputs[0]["selected"])
            self.assertTrue(audio.outputs[1]["virtual"])
            audio.selectOutput(46)
            self.assertFalse(any(call.args[0][:2] == ["wpctl", "set-default"] for call in run.call_args_list))
            audio.selectOutput(45)
            self.assertTrue(any(call.args[0] == ["wpctl", "set-default", "45"] for call in run.call_args_list))

    def test_audio_lists_available_output_profiles_and_changes_only_on_explicit_selection(self):
        ui = self.load_ui()
        sink_output = """Sink #45
        State: SUSPENDED
        Name: alsa_output.test.hdmi
        Description: HDMI Audio Output
        Ports:
                hdmi-output-0: HDMI / DisplayPort (type: HDMI, priority: 5900, available: yes)
                hdmi-output-1: HDMI 2 (type: HDMI, priority: 5800, available: no)
        Active Port: hdmi-output-0
"""
        card_output = """Card #0
        Name: alsa_card.pci-test
        Profiles:
                off: Off (sinks: 0, sources: 0, priority: 0, available: yes)
                output:analog-stereo: Analog Stereo Output (sinks: 1, sources: 0, priority: 6500, available: yes)
                output:hdmi-stereo: Digital Stereo (HDMI) Output (sinks: 1, sources: 0, priority: 5900, available: yes)
                output:hdmi-stereo-extra1: HDMI 2 Output (sinks: 1, sources: 0, priority: 5800, available: no)
                input:analog-stereo: Analog Stereo Input (sinks: 0, sources: 1, priority: 60, available: yes)
        Active Profile: output:analog-stereo
        Ports:
                analog-output-speaker: Speakers (type: Speaker, priority: 10000, availability group: Legacy 1, available: yes)
"""
        nodes = [{"id": 45, "info": {"props": {"media.class": "Audio/Sink", "node.description": "HDMI Board"}}}]
        calls = []

        def command(args, **_kwargs):
            calls.append(args)
            if args == ["pw-dump"]:
                return SimpleNamespace(returncode=0, stdout=json.dumps(nodes))
            if args[:2] == ["wpctl", "inspect"]:
                return SimpleNamespace(returncode=0, stdout="id 45, type PipeWire:Interface:Node")
            if args == ["pactl", "list", "cards"]:
                return SimpleNamespace(returncode=0, stdout=card_output)
            if args == ["pactl", "list", "sinks"]:
                return SimpleNamespace(returncode=0, stdout=sink_output)
            if args[:2] == ["wpctl", "get-volume"]:
                return SimpleNamespace(returncode=0, stdout="Volume: 0.40")
            return SimpleNamespace(returncode=0, stdout="")

        with patch.object(ui.subprocess, "run", side_effect=command):
            audio = ui.AtlasAudio()
            profiles = audio.profiles
            self.assertEqual(len(profiles), 2)
            self.assertEqual(profiles[0]["profile"], "output:analog-stereo")
            self.assertTrue(profiles[0]["selected"])
            self.assertEqual(profiles[1]["profile"], "output:hdmi-stereo")
            self.assertFalse(profiles[1]["selected"])
            self.assertEqual(len(audio.ports), 1)
            self.assertEqual(audio.ports[0]["port"], "hdmi-output-0")
            self.assertTrue(audio.ports[0]["selected"])
            self.assertFalse(any(call[:2] == ["pactl", "set-card-profile"] for call in calls))
            self.assertFalse(any(call[:2] == ["pactl", "set-sink-port"] for call in calls))
            audio.selectOutputPort("alsa_output.test.hdmi", "hdmi-output-0")
            self.assertIn(["pactl", "set-sink-port", "alsa_output.test.hdmi", "hdmi-output-0"], calls)
            before = len(calls)
            audio.selectOutputPort("alsa_output.test.hdmi", "hdmi-output-1")
            self.assertEqual(len(calls), before)
            audio.selectCardProfile("0", "output:hdmi-stereo")
            self.assertIn(["pactl", "set-card-profile", "0", "output:hdmi-stereo"], calls)
            self.assertFalse(any(call[:2] == ["wpctl", "set-default"] for call in calls))
            before = len(calls)
            audio.selectCardProfile("0", "input:analog-stereo")
            self.assertEqual(len(calls), before)

    def test_sound_settings_exposes_explicit_card_profile_selection(self):
        settings = (COMPONENTS / "AtlasSettings.qml").read_text(encoding="utf-8")
        self.assertIn("Ses kartı çıkış profili (yalnızca seçtiğinizde değişir)", settings)
        self.assertIn("selectCardProfile(modelData.cardId, modelData.profile)", settings)
        self.assertIn("selectOutputPort(modelData.sink, modelData.port)", settings)

    def test_audio_self_test_generates_short_tone_and_requires_real_output(self):
        ui = self.load_ui()
        with wave.open(io.BytesIO(ui.AtlasAudio._test_tone_wav()), "rb") as tone:
            self.assertEqual(tone.getframerate(), 48000)
            self.assertEqual(tone.getnchannels(), 1)
            self.assertEqual(tone.getsampwidth(), 2)
            self.assertEqual(tone.getnframes(), 36000)

        with patch.object(ui, "QProcess") as process_factory:
            audio = ui.AtlasAudio()
            audio._available = False
            audio._selected_output = -1
            audio.testOutput()
            process_factory.assert_not_called()
            self.assertIn("ses çıkışı seçin", audio.outputStatus)

    def test_audio_self_test_rejects_virtual_muted_and_zero_volume_outputs(self):
        ui = self.load_ui()
        with patch.object(ui, "QProcess") as process_factory:
            audio = ui.AtlasAudio()
            audio._outputs = [{"id": 12, "selected": True, "virtual": True}]
            audio._selected_output = 12
            audio._available = True
            audio._volume = 40
            audio.testOutput()
            self.assertIn("ses çıkışı seçin", audio.outputStatus)

            audio._outputs = [{"id": 12, "selected": True, "virtual": False}]
            audio._muted = True
            audio.testOutput()
            self.assertIn("sesi açın", audio.outputStatus)

            audio._muted = False
            audio._volume = 0
            audio.testOutput()
            self.assertIn("ses düzeyini yükseltin", audio.outputStatus)
            process_factory.assert_not_called()

    def test_audio_self_test_uses_pipewire_default_and_has_timeout(self):
        ui = self.load_ui()

        class Signal:
            def connect(self, callback):
                self.callback = callback

        class Process:
            def __init__(self):
                self.started = Signal()
                self.finished = Signal()
                self.errorOccurred = Signal()
                self.written = None
                self.deleted = False
                self.killed = False

            def state(self):
                return ui.QProcess.ProcessState.NotRunning

            def start(self, program, arguments):
                self.program, self.arguments = program, arguments

            def write(self, value):
                self.written = value

            def closeWriteChannel(self):
                self.closed = True

            def deleteLater(self):
                self.deleted = True

            def kill(self):
                self.killed = True

        class Timer:
            def __init__(self, _parent):
                self.timeout = Signal()

            def setSingleShot(self, value):
                self.single_shot = value

            def start(self, milliseconds):
                self.milliseconds = milliseconds

            def stop(self):
                self.stopped = True

            def deleteLater(self):
                self.deleted = True

        process = Process()
        timer = Timer(None)
        audio = ui.AtlasAudio()
        audio._outputs = [{"id": 12, "selected": True, "virtual": False}]
        audio._selected_output = 12
        audio._available = True
        audio._volume = 40
        with patch.object(ui, "QProcess") as process_factory, patch.object(ui, "QTimer", return_value=timer):
            process_factory.return_value = process
            audio.testOutput()
            self.assertEqual((process.program, process.arguments), ("pw-play", ["-"]))
            self.assertEqual(timer.milliseconds, 5000)
            process.started.callback()
            self.assertTrue(process.written.startswith(b"RIFF"))
            self.assertTrue(process.closed)
            process.finished.callback(0, None)
            self.assertIn("hoparlörden duyulup duyulmadığını", audio.outputStatus)
            self.assertTrue(timer.stopped)

            audio.testOutput()
            timer.timeout.callback()
            self.assertTrue(process.killed)
            self.assertIn("zaman aşımına uğradı", audio.outputStatus)

    def test_chrome_scale_is_connected_to_atlas_density_without_laptop_enlargement(self):
        main = (COMPONENTS.parent / "Main.qml").read_text(encoding="utf-8")
        ui = UI.read_text(encoding="utf-8")
        launcher = (ROOT / "config/includes.chroot/usr/local/bin/atlasos-browser").read_text(encoding="utf-8")
        self.assertIn("setBrowserScaleFactor(boardMode ? interfaceScale : 1.0)", main)
        self.assertIn("ATLASOS_CHROME_SCALE_FACTOR", ui)
        self.assertIn("--force-device-scale-factor=", launcher)
        self.assertIn("ATLASOS_CHROME_SCALE_FACTOR:-1.0", launcher)
        self.assertIn("close all browser windows to apply", launcher)

    def test_browser_scale_factor_is_clamped_and_exported_for_child_launcher(self):
        ui = self.load_ui()
        old = ui.os.environ.get("ATLASOS_CHROME_SCALE_FACTOR")
        try:
            preferences = ui.AtlasPreferences()
            preferences.setBrowserScaleFactor(1.42)
            self.assertEqual(ui.os.environ.get("ATLASOS_CHROME_SCALE_FACTOR"), "1.42")
            preferences.setBrowserScaleFactor(float("inf"))
            self.assertEqual(ui.os.environ.get("ATLASOS_CHROME_SCALE_FACTOR"), "1.00")
            preferences.setBrowserScaleFactor(9.0)
            self.assertEqual(ui.os.environ.get("ATLASOS_CHROME_SCALE_FACTOR"), "2.00")
        finally:
            if old is None:
                ui.os.environ.pop("ATLASOS_CHROME_SCALE_FACTOR", None)
            else:
                ui.os.environ["ATLASOS_CHROME_SCALE_FACTOR"] = old

    def test_audio_services_missing_does_not_crash_or_report_success(self):
        ui = self.load_ui()
        with patch.object(ui.subprocess, "run", side_effect=FileNotFoundError("pw-dump unavailable")):
            audio = ui.AtlasAudio()
            self.assertEqual(audio.outputs, [])
            self.assertFalse(audio.available)
            self.assertIn("okunamadı", audio.outputStatus)
            with patch.object(ui, "QProcess") as process_factory:
                audio.testOutput()
                process_factory.assert_not_called()
                self.assertNotIn("gönderildi", audio.outputStatus)

    def test_live_image_includes_audio_route_diagnostic_tools(self):
        packages = (ROOT / "config/package-lists/atlasos-live.list.chroot").read_text(encoding="utf-8").splitlines()
        self.assertIn("alsa-utils", packages)
        self.assertIn("pulseaudio-utils", packages)


    def test_display_settings_explain_chrome_scale_restart_requirement(self):
        settings = (COMPONENTS / "AtlasSettings.qml").read_text(encoding="utf-8")
        self.assertIn("Ölçek değişince Chrome pencerelerini kapatıp yeniden açın.", settings)

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
