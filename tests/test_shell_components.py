import importlib.machinery
import importlib.util
import base64
import os
import pathlib
import tempfile
import unittest
from unittest.mock import patch


UI_PATH = pathlib.Path(__file__).resolve().parents[1] / "config/includes.chroot/usr/local/bin/atlasos-ui"


class ShellComponentsTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        try:
            loader = importlib.machinery.SourceFileLoader("atlasos_ui_test", str(UI_PATH))
            spec = importlib.util.spec_from_loader(loader.name, loader)
            cls.ui = importlib.util.module_from_spec(spec)
            loader.exec_module(cls.ui)
        except ImportError as exc:
            raise unittest.SkipTest(str(exc)) from exc

    def test_11b_weekly_schedule_has_eight_periods_and_school_day_times(self):
        data_path = UI_PATH.parents[1] / "share/atlasos/ui/data/lessons.json"
        data = __import__("json").loads(data_path.read_text(encoding="utf-8"))
        self.assertEqual(data["version"], 2)
        self.assertFalse(data["demo"])
        self.assertEqual(data["profile"]["classLabel"], "11/B")
        self.assertEqual(set(data["days"]), {"1", "2", "3", "4", "5"})
        self.assertTrue(all(len(periods) == 8 for periods in data["days"].values()))
        start = 8 * 60
        cursor = start
        lesson_times = []
        for period in range(8):
            lesson_times.append((cursor, cursor + 40))
            cursor += 40
            if period < 7:
                cursor += 45 if period == 4 else 10
        self.assertEqual(lesson_times[0], (480, 520))
        self.assertEqual(lesson_times[4], (680, 720))
        self.assertEqual(lesson_times[5], (765, 805))
        self.assertEqual(lesson_times[-1], (865, 905))
        self.assertEqual(cursor, 905)

    def test_ui_launcher_shebang_uses_unix_line_endings(self):
        launcher = UI_PATH.read_bytes()
        self.assertTrue(launcher.startswith(b"#!/usr/bin/env python3\n"))
        self.assertNotIn(b"\r", launcher)

    def test_secure_wifi_secret_is_sent_over_stdin_not_arguments(self):
        class FakeProcess:
            NotRunning = None
            def __init__(self):
                self.started = None
                self.writes = []
            def state(self):
                return self.NotRunning
            def start(self, command, args):
                self.started = (command, args)
            def write(self, data):
                self.writes.append(data)

        FakeProcess.NotRunning = self.ui.QProcess.NotRunning
        network = self.ui.AtlasNetwork()
        fake = FakeProcess()
        network._process = fake
        network.connectSecure("Test SSID", "test-secret")
        command, arguments = fake.started
        self.assertEqual(command, "nmcli")
        self.assertIn("--ask", arguments)
        self.assertIn("Test SSID", arguments)
        self.assertNotIn("test-secret", arguments)
        network._send_wifi_secret()
        self.assertEqual(fake.writes, [("test-secret" + chr(10)).encode()])
        self.assertEqual(network._pending_wifi_secret, "")

    def test_audio_volume_reads_applies_and_mutes_system_sink(self):
        class Result:
            returncode = 0
            stdout = "Volume: 0.70 [MUTED]"
            stderr = ""
        with patch.object(self.ui.subprocess, "run", return_value=Result()) as run:
            audio = self.ui.AtlasAudio()
            self.assertTrue(audio.available)
            self.assertEqual(audio.volume, 70)
            self.assertTrue(audio.muted)
            audio.setVolume(84)
            self.assertTrue(any("0.84" in call.args[0] for call in run.call_args_list))
            audio.toggleMute()
            self.assertTrue(any(call.args[0][-1] == "toggle" for call in run.call_args_list))

    def test_audio_without_a_sink_disables_controls_without_crashing(self):
        with patch.object(self.ui.subprocess, "run", side_effect=FileNotFoundError):
            audio = self.ui.AtlasAudio()
            self.assertFalse(audio.available)
            self.assertEqual(audio.volume, 0)
            audio.setVolume(50)
            audio.toggleMute()

    def test_material_favorites_and_recent_items_persist(self):
        settings_type = self.ui.QSettings
        with tempfile.TemporaryDirectory() as directory:
            settings_file = pathlib.Path(directory) / "atlasos.ini"
            apps = self.ui.AtlasApps()
            apps._settings = settings_type(str(settings_file), settings_type.IniFormat)
            apps._favorites = apps._read_keys("favoriteMaterials")
            apps._recent = apps._read_keys("recentMaterials")
            apps._settings.clear()
            apps.setFavorite("kig", True)
            apps.track("geogebra")
            apps.track("ogm")
            self.assertEqual(apps.favoriteKeys, ["kig"])
            self.assertEqual(apps.recentKeys[:2], ["ogm", "geogebra"])
            restored = self.ui.AtlasApps()
            restored._settings = settings_type(str(settings_file), settings_type.IniFormat)
            restored._favorites = restored._read_keys("favoriteMaterials")
            restored._recent = restored._read_keys("recentMaterials")
            self.assertEqual(restored.favoriteKeys, ["kig"])
            self.assertEqual(restored.recentKeys[:2], ["ogm", "geogebra"])
            apps.setFavorite("unknown", True)
            self.assertEqual(apps.favoriteKeys, ["kig"])

    def test_resources_reader_reports_proc_memory(self):
        resources = self.ui.AtlasResources()
        resources.refresh()
        self.assertGreater(resources.memoryTotalMb, 0)
        self.assertGreaterEqual(resources.memoryUsedMb, 0)
        self.assertGreaterEqual(resources.memoryPercent, 0)
        self.assertLessEqual(resources.memoryPercent, 100)

    def test_normal_shell_starts_atlas_dock_and_keeps_app_launch_route(self):
        main_qml = UI_PATH.parents[1] / "share/atlasos/ui/Main.qml"
        launcher_qml = main_qml.parent / "components/AtlasLauncher.qml"
        main_source = main_qml.read_text(encoding="utf-8")
        launcher_source = launcher_qml.read_text(encoding="utf-8")
        ui_source = UI_PATH.read_text(encoding="utf-8")
        dock_source = (main_qml.parent / "components/AtlasDock.qml").read_text(encoding="utf-8")
        self.assertIn("AtlasDock.qml", ui_source)
        self.assertIn("WindowStaysOnTopHint", dock_source)
        self.assertIn('color: "#f5f9fe"', dock_source)
        self.assertIn("atlasWindows.activate", dock_source)
        self.assertIn('modelData.icon || "applications"', dock_source)
        self.assertIn('modelData.minimized', dock_source)
        self.assertIn("visible: taskCount > 0", dock_source)
        self.assertNotIn("launcherRequested", dock_source)
        self.assertIn("taskCount * iconSlot", dock_source)
        self.assertIn("(Screen.width - width) / 2", dock_source)
        self.assertIn('source: modelData.iconData || ""', dock_source)
        self.assertIn('text: "Uygulamaya Geç"', dock_source)
        self.assertIn('text: "Kapat"', dock_source)
        self.assertNotIn("dockShadow", dock_source)
        self.assertIn("dockGroups", (UI_PATH.read_text(encoding="utf-8")))
        monitor = (UI_PATH.parent / "atlasos-window-monitor").read_text(encoding="utf-8")
        self.assertIn("_NET_WM_ICON", monitor)
        self.assertIn("_NET_CLOSE_WINDOW", monitor)
        self.assertIn("selected(key)", launcher_source)

    def test_dock_groups_windows_by_wm_class_and_keeps_classless_windows_separate(self):
        backend = self.ui.AtlasWindows()
        backend._windows = [
            {"id": "10", "title": "Browser one", "class": "chromium", "icon": "browser", "active": False, "minimized": True},
            {"id": "11", "title": "Browser two", "class": "chromium", "icon": "browser", "active": True, "minimized": False},
            {"id": "12", "title": "Mystery", "class": "", "icon": "applications", "active": False, "minimized": False},
        ]
        groups = backend.dockGroups
        self.assertEqual(len(groups), 2)
        browser = next(group for group in groups if group["class"] == "chromium")
        self.assertEqual(browser["count"], 2)
        self.assertEqual(browser["windowId"], "11")
        self.assertTrue(browser["active"])
        self.assertEqual(browser["title"], "Web Tarayıcısı")

    def test_dock_backend_sends_close_using_existing_window_monitor(self):
        class FakeProcess:
            def state(self):
                return self.ui_state
            def write(self, data):
                self.writes.append(data)

        backend = self.ui.AtlasWindows()
        fake = FakeProcess()
        fake.ui_state = self.ui.QProcess.Running
        fake.writes = []
        backend._monitor = fake
        backend.closeWindow("42")
        self.assertEqual(fake.writes, [b'{"action": "close", "id": "42"}\n'])

    def test_display_mode_is_qml_only_and_does_not_change_session_dpi(self):
        previous_mode = os.environ.get("ATLASOS_VALIDATE_DISPLAY_MODE")
        previous_environment_mode = os.environ.get("ATLASOS_DISPLAY_MODE")
        os.environ.pop("ATLASOS_VALIDATE_DISPLAY_MODE", None)
        try:
            with tempfile.TemporaryDirectory() as directory:
                settings_type = self.ui.QSettings
                settings_type.setDefaultFormat(settings_type.IniFormat)
                settings_type.setPath(settings_type.IniFormat, settings_type.UserScope, directory)
                preferences = self.ui.AtlasPreferences()
                with patch.object(self.ui.subprocess, "run") as run:
                    for mode, expected in (("board", "board"), ("laptop", "laptop"), ("auto", "board" if preferences.touchscreenDetected else "laptop")):
                        preferences.setDisplayMode(mode)
                        self.assertEqual(os.environ["ATLASOS_DISPLAY_MODE"], expected)
                    run.assert_not_called()
        finally:
            if previous_mode is not None:
                os.environ["ATLASOS_VALIDATE_DISPLAY_MODE"] = previous_mode
            if previous_environment_mode is None:
                os.environ.pop("ATLASOS_DISPLAY_MODE", None)
            else:
                os.environ["ATLASOS_DISPLAY_MODE"] = previous_environment_mode

    def test_home_dashboard_uses_reference_art_and_responsive_teacher_layout(self):
        ui_dir = UI_PATH.parents[1] / "share/atlasos/ui"
        dashboard = (ui_dir / "components/AtlasHomeDashboard.qml").read_text(encoding="utf-8")
        main_source = (ui_dir / "Main.qml").read_text(encoding="utf-8")
        header_source = (ui_dir / "components/AtlasHeader.qml").read_text(encoding="utf-8")
        self.assertIn("atlas-dashboard-footer.png", dashboard)
        self.assertTrue((ui_dir / "branding/atlas-dashboard-footer.png").is_file())
        self.assertIn("anchors.leftMargin: 0", dashboard)
        self.assertIn("anchors.rightMargin: 0", dashboard)
        self.assertIn("MEB Kaynakları", dashboard)
        self.assertIn("Ekrana Çiz", dashboard)
        self.assertIn("width >= 850", dashboard)
        self.assertIn("AtlasHomeDashboard {", main_source)
        self.assertNotIn("QT_SCALE_FACTOR=1.25", (UI_PATH.parents[1] / "bin/atlasos-session").read_text(encoding="utf-8"))
        self.assertIn('atlasPreferences.displayMode === "board"', main_source)
        self.assertIn("root.width < 1440 ? 1.0 : 1.08", main_source)
        self.assertIn("anchors.bottom: footer.top", (UI_PATH.parents[1] / "share/atlasos/ui/components/AtlasSidebar.qml").read_text(encoding="utf-8"))
        self.assertIn("touchscreenDetected", main_source)
        self.assertIn('Qt.locale("tr_TR")', header_source)
        self.assertNotIn('text: "İnternet Bağlı"', header_source)

    def test_062_iso_uses_canonical_version_console_backend_and_checksum_order(self):
        build = pathlib.Path(__file__).resolve().parents[1] / "iso/build-atlasos.sh"
        source = build.resolve().read_text(encoding="utf-8")
        self.assertIn('ISO_NAME="${ATLASOS_ISO_NAME:-AtlasOS-${ATLAS_VERSION}-live-amd64.iso}"', source)
        self.assertIn('DEFAULT_VERSION="$(tr -d \'[:space:]\' < "${PROJECT_ROOT}/VERSION")"', source)
        self.assertIn(r'^[0-9]+\.[0-9]+\.[0-9]+([.-][A-Za-z0-9.-]+)?$', source)
        self.assertIn('LATEST_DIR="${ATLASOS_OUTPUT_DIR:-${DIST_DIR}/AtlasOS-${ATLAS_VERSION}}"', source)
        self.assertIn('iso_hash="$(sha256sum "${LATEST_ISO}" | awk \'{print $1}\')"', source)
        self.assertIn('printf \'%s  %s\\n\' "${iso_hash}" "${ISO_NAME}" > "${LATEST_ISO}.sha256"', source)
        self.assertIn('> "${LATEST_DIR}/SHA256SUMS.txt"', source)
        self.assertIn('--iso-volume "ATLASOS_${ATLAS_VERSION//./}"', source)
        self.assertIn('cp "${PROJECT_ROOT}/iso/grub-console.cfg" "${grub_cfg}"', source)
        grub = (build.parent / "grub-console.cfg").read_text(encoding="utf-8")
        self.assertIn("terminal_input console", grub)
        self.assertIn("terminal_output console", grub)
        self.assertIn("set gfxpayload=keep", grub)
        self.assertNotIn("loadfont", grub)
        self.assertNotIn("gfxterm", grub)
        self.assertNotIn("background_image", grub)
        self.assertNotIn("set theme=", grub)
        self.assertIn("vt.handoff=7", source)
        self.assertNotIn("0.6.0", source)
        checksum_refresh = source.index("find . -type f ! -name SHA256SUMS ! -path ./isolinux/isolinux.bin")
        uefi_assets = source.index('create_uefi_boot_image "${binary_dir}"')
        iso_write = source.index("xorriso -as mkisofs", uefi_assets)
        self.assertLess(uefi_assets, checksum_refresh)
        self.assertLess(checksum_refresh, iso_write)

    def test_062_early_i915_experiment_resolves_modules_and_limits_firmware(self):
        root = pathlib.Path(__file__).resolve().parents[1]
        hook = (root / "config/hooks/normal/020-atlasos-early-i915.hook.chroot").read_text(encoding="utf-8")
        build = (root / "iso/build-atlasos.sh").read_text(encoding="utf-8")
        self.assertIn('ISO_NAME="${ATLASOS_ISO_NAME:-AtlasOS-${ATLAS_VERSION}-live-amd64.iso}"', build)
        self.assertIn('modprobe --set-version "$version" --ignore-install --show-depends i915', hook)
        self.assertIn('copy_once module "$module_path"', hook)
        self.assertIn('copy_once firmware "$firmware"', hook)
        self.assertIn("icl_dmc_ver1_09.bin.zst", hook)
        self.assertIn("kbl_dmc_ver1_04.bin.zst", hook)
        self.assertNotIn("_guc_", hook.lower())
        self.assertNotIn("_huc_", hook.lower())
        self.assertIn('PREREQ="udev"', hook)
        self.assertIn("modprobe i915", hook)
        self.assertIn("ATLASOS_OUTPUT_DIR", build)

    def test_privileged_boot_diagnostics_replaces_caspers_unrestricted_sudo(self):
        root = pathlib.Path(__file__).resolve().parents[1]
        hook = (root / "config/hooks/normal/010-atlasos-branding.hook.chroot").read_text(encoding="utf-8")
        helper = root / "config/includes.chroot/usr/local/libexec/atlasos-privileged-diagnostics"
        packages = (root / "config/package-lists/atlasos-live.list.chroot").read_text(encoding="utf-8")
        self.assertIn('old = \'echo "${USERNAME}  ALL=(ALL) NOPASSWD: ALL" > /root/etc/sudoers.d/casper\'', hook)
        self.assertIn("gpasswd -d \"$USERNAME\" sudo", hook)
        self.assertIn("gpasswd -d \"$USERNAME\" admin", hook)
        self.assertIn('NOPASSWD: /usr/local/libexec/atlasos-privileged-diagnostics ""', hook)
        self.assertIn("chmod 0440 /root/etc/sudoers.d/casper", hook)
        self.assertGreater(hook.index("update-initramfs -u -k all"), hook.index("Unexpected Casper sudoers implementation"))
        self.assertTrue(helper.is_file())
        self.assertIn("sudo", packages.splitlines())

    def test_062_developer_center_is_in_settings_and_uses_explicit_safe_actions(self):
        ui_dir = UI_PATH.parents[1] / "share/atlasos/ui"
        settings = (ui_dir / "components/AtlasSettings.qml").read_text(encoding="utf-8")
        developer_path = ui_dir / "components/AtlasDeveloper.qml"
        developer = developer_path.read_text(encoding="utf-8")
        bridge = UI_PATH.read_text(encoding="utf-8")
        diagnostics_path = UI_PATH.with_name("atlasos_diagnostics.py")
        diagnostics = diagnostics_path.read_text(encoding="utf-8")
        self.assertTrue(developer_path.is_file())
        self.assertTrue(diagnostics_path.is_file())
        self.assertIn('{ key: "developer", label: "Geliştirici" }', settings)
        self.assertIn('source: "AtlasDeveloper.qml"', settings)
        self.assertIn('active: panel.selectedSection === "developer"', settings)
        self.assertIn('"Boot Tanılama · Atlas Servisleri · Günlükler"', developer)
        self.assertIn('"Tüm Tanılamaları Çalıştır"', developer)
        self.assertIn('"Tanılama Paketini Dışa Aktar"', developer)
        self.assertIn("refreshExportTargets", developer)
        self.assertIn("progressChanged", bridge)
        self.assertIn("threading.Thread", bridge)
        self.assertIn('tempfile.mkdtemp(prefix="atlasos-diagnostics-", dir=runtime_dir)', diagnostics)
        self.assertIn('XDG_RUNTIME_DIR', diagnostics)
        self.assertIn('_validate_runtime_directory', diagnostics)
        self.assertIn("UNKNOWN_PROTECTED", diagnostics)
        self.assertIn('"internal_storage_policy": "READ_ONLY_PROTECTED"', diagnostics)
        self.assertIn("shell=False", diagnostics)
        self.assertNotIn("disk benchmark", developer.lower())
        self.assertNotIn("setInterval", developer)

    def test_062_diagnostic_policy_tests_cover_internal_and_usb_export_edges(self):
        test = (UI_PATH.parents[5] / "tests/test_diagnostics.py").read_text(encoding="utf-8")
        for phrase in ("nvme0n1", "mmcblk0", "LIVE_BOOT_MEDIA", "USB removed", "path traversal",
                       "symlink_escape", "bind_mount", "insufficient_space", "internal_mount"):
            self.assertIn(phrase.lower().replace(" ", "_"), test.lower().replace(" ", "_"))

    def test_lesson_session_and_categorized_resources_are_integrated(self):
        root = pathlib.Path(__file__).resolve().parents[1]
        main = (root / "config/includes.chroot/usr/local/share/atlasos/ui/Main.qml").read_text(encoding="utf-8")
        panel = (root / "config/includes.chroot/usr/local/share/atlasos/ui/components/LessonPanel.qml").read_text(encoding="utf-8")
        dashboard = (root / "config/includes.chroot/usr/local/share/atlasos/ui/components/AtlasLessonDashboard.qml").read_text(encoding="utf-8")
        files = (root / "config/includes.chroot/usr/local/share/atlasos/ui/components/AtlasFiles.qml").read_text(encoding="utf-8")
        self.assertIn('signal startRequested(string title, string start, string end)', panel)
        self.assertIn('text: "Derse Başla  →"', panel)
        self.assertIn("activeLessonElapsedSeconds++", main)
        self.assertIn('root.activeLessonTitle = ""', main)
        self.assertIn('key:"library"', dashboard)
        self.assertIn('target:"library"', dashboard)
        self.assertIn('title:"OGM Materyal"', dashboard)
        self.assertIn('title:"MEBİ"', dashboard)
        self.assertIn('property string category: ["favorites", "recent", "local", "web"].indexOf(atlasValidateMaterialFilter) >= 0 ? atlasValidateMaterialFilter : "all"', dashboard)
        self.assertIn('placeholderText: "Ders, konu veya araç ara"', dashboard)
        self.assertIn('page.category === "favorites"', dashboard)
        self.assertIn('page.category === "recent"', dashboard)
        for key in ("kig", "kalzium", "step"):
            self.assertIn('"' + key + '"', dashboard)
        self.assertIn('"atlasos-app-launcher"', (root / "config/includes.chroot/usr/local/bin/atlasos-ui").read_text(encoding="utf-8"))
        self.assertIn('atlasApps.setFavorite(modelData.key, enabled)', dashboard)
        self.assertIn('workspaceTitle = "Kaynak Rafı"', main)
        self.assertIn('placeholderText: "Bu klasörde kaynak ara"', files)
        self.assertIn("fileName.toLocaleLowerCase().indexOf(files.searchText)", files)

    def test_network_notifications_are_suppressed_before_nm_applet_starts(self):
        root = pathlib.Path(__file__).resolve().parents[1]
        session = (root / "config/includes.chroot/usr/local/bin/atlasos-session").read_text(encoding="utf-8")
        applet_start = session.index("nm-applet >/dev/null")
        self.assertLess(session.index("suppress-wireless-networks-available true"), applet_start)
        self.assertIn("suppress-wireless-networks-available true", session)

    def test_browser_launcher_serializes_and_retries_transient_137(self):
        launcher = (pathlib.Path(__file__).resolve().parents[1] / "config/includes.chroot/usr/local/bin/atlasos-browser").read_text(encoding="utf-8")
        self.assertIn("flock -w 20", launcher)
        self.assertIn('[[ "${status}" == "137" && "${attempt}" == "1" ]]', launcher)
        self.assertIn("for attempt in 1 2", launcher)

    def test_startup_sound_preference_persists_and_sound_is_packaged_explicitly(self):
        ui_dir = pathlib.Path(__file__).resolve().parents[1] / "config/includes.chroot/usr/local/share/atlasos/ui"
        previous_ui_path = os.environ.get("ATLASOS_UI_PATH")
        os.environ["ATLASOS_UI_PATH"] = str(ui_dir / "Main.qml")
        with tempfile.TemporaryDirectory() as directory:
            settings_type = self.ui.QSettings
            settings_type.setDefaultFormat(settings_type.IniFormat)
            settings_type.setPath(settings_type.IniFormat, settings_type.UserScope, directory)
            preferences = self.ui.AtlasPreferences()
            preferences._settings.clear()
            preferences._settings.sync()
            self.assertTrue(preferences.startupSoundEnabled)
            expected_sound = (pathlib.Path(__file__).resolve().parents[1] / "config/includes.chroot/usr/local/share/atlasos/ui/sounds/atlasos-startup.wav").is_file()
            self.assertEqual(preferences.startupSoundAvailable, expected_sound)
            preferences.setStartupSoundEnabled(False)
            self.assertFalse(self.ui.AtlasPreferences().startupSoundEnabled)
        if previous_ui_path is None:
            os.environ.pop("ATLASOS_UI_PATH", None)
        else:
            os.environ["ATLASOS_UI_PATH"] = previous_ui_path

        main_source = (ui_dir / "Main.qml").read_text(encoding="utf-8")
        settings_source = (ui_dir / "components/AtlasSettings.qml").read_text(encoding="utf-8")
        self.assertIn('Qt.resolvedUrl("sounds/atlasos-startup.wav")', main_source)
        self.assertIn('root.showToast("Ders tamamlandı", doneMessage)', main_source)
        self.assertIn('"Erişilebilirlik"', settings_source)
        self.assertIn('"Veli Ercan"', settings_source)
        self.assertIn("startupSoundChanged(bool enabled)", settings_source)

    def test_new_user_logos_drive_interface_and_boot_themes(self):
        root = pathlib.Path(__file__).resolve().parents[1]
        prepare = (root / "iso/prepare-branding-assets.sh").read_text(encoding="utf-8")
        header = (root / "config/includes.chroot/usr/local/share/atlasos/ui/components/AtlasHeader.qml").read_text(encoding="utf-8")
        about = (root / "config/includes.chroot/usr/local/share/atlasos/ui/components/AtlasSettings.qml").read_text(encoding="utf-8")
        plymouth = (root / "config/includes.chroot/usr/share/plymouth/themes/atlasos/atlasos.script").read_text(encoding="utf-8")
        for filename in (
            "atlas-os sistem içi logo.jpg",
            "atlas-os açılış animasyonu ve diğer açılışla akalı yerlerde kullanılıcak görsel.jpg",
        ):
            self.assertTrue((root / "docs/assets" / filename).is_file())
        self.assertIn("atlas-os sistem içi logo.jpg", prepare)
        self.assertIn("atlas-os açılış animasyonu", prepare)
        self.assertIn('source: "../branding/atlas-primary.png"', header)
        self.assertIn('source: "../branding/atlas-symbol.png"', about)
        self.assertIn("Window.SetBackgroundTopColor (0.96, 0.98, 0.99)", plymouth)

    def test_about_page_credits_veli_ercan_and_applications_remain_available(self):
        ui_dir = UI_PATH.parents[1] / "share/atlasos/ui"
        sidebar = (ui_dir / "components/AtlasSidebar.qml").read_text(encoding="utf-8")
        dashboard = (ui_dir / "components/AtlasHomeDashboard.qml").read_text(encoding="utf-8")
        self.assertIn('{ label: "Uygulamalar", icon: "applications", page: "tools", active: true }', sidebar)
        self.assertIn('{ label: "Hakkında", icon: "help", page: "about", active: true }', sidebar)
        self.assertIn('text: "Veli Ercan"', dashboard)

    def test_live_demo_logs_into_atlas_session_without_password_prompt(self):
        hook = UI_PATH.parents[5] / "config/hooks/normal/010-atlasos-branding.hook.chroot"
        source = hook.read_text(encoding="utf-8")
        self.assertIn("autologin-user=atlas", source)
        self.assertIn("user-session=atlasos", source)

    def test_text_editing_stays_inside_atlas_workspace(self):
        main_qml = UI_PATH.parents[1] / "share/atlasos/ui/Main.qml"
        text_qml = main_qml.parent / "components/AtlasText.qml"
        main_source = main_qml.read_text(encoding="utf-8")
        text_source = text_qml.read_text(encoding="utf-8")
        self.assertNotIn("mousepad", main_source.lower() + text_source.lower())
        self.assertIn("atlasFs.writeText(fileUrl, editDraft)", text_source)

    def test_plymouth_theme_displays_usb_removal_prompt_above_splash(self):
        theme = UI_PATH.parents[3] / "usr/share/plymouth/themes/atlasos/atlasos.script"
        message_svg = theme.parent / "atlas-usb-message.svg"
        source = theme.read_text(encoding="utf-8")
        prompt = message_svg.read_text(encoding="utf-8")
        self.assertIn("Plymouth.SetMessageFunction (atlas_message_callback)", source)
        self.assertIn("usb_message_sprite.SetZ (10001)", source)
        self.assertIn("Window.GetHeight () * 0.90", source)
        self.assertIn("USB belleğini çıkarın", prompt)

    def test_plymouth_logo_is_animated_without_distorting_the_emblem(self):
        theme = UI_PATH.parents[3] / "usr/share/plymouth/themes/atlasos"
        source = (theme / "atlasos.script").read_text(encoding="utf-8")
        self.assertIn("Plymouth.SetRefreshFunction (atlas_refresh_callback)", source)
        self.assertIn('Image ("atlas-sweep-23.png")', source)
        self.assertIn("logo_sprite.SetOpacity (logo_opacity)", source)
        self.assertTrue(all((theme / f"atlas-sweep-{index:02d}.png").is_file() for index in range(24)))
    def test_nmcli_escaped_fields(self):
        self.assertEqual(self.ui.split_nmcli_row(r"enp1s0:ethernet:connected:Okul\: Kablo"),
                         ["enp1s0", "ethernet", "connected", "Okul: Kablo"])

    def test_wired_diagnostics_separate_link_address_gateway_and_dns(self):
        class OutputProcess:
            def __init__(self):
                self.output = b"wlan0:wifi:connected:Home\nenp1s0:ethernet:disconnected:--\n"
                self.started = None

            def readAllStandardOutput(self):
                return self.output

            def start(self, command, args):
                self.started = (command, args)

        network = self.ui.AtlasNetwork()
        fake = OutputProcess()
        network._wired_process = fake
        network._wired_stage = "devices"
        network._wired_finished(0, None)
        self.assertEqual(network.wired["device"], "enp1s0")
        self.assertEqual(fake.started[0], "nmcli")
        fake.output = b"WIRED-PROPERTIES.CARRIER:on\nIP4.ADDRESS[1]:10.2.3.4/24\nIP4.GATEWAY:10.2.3.1\nIP4.DNS[1]:10.2.3.53\n"
        network._wired_finished(0, None)
        self.assertEqual(network.wired["carrier"], "on")
        self.assertEqual(network.wired["address"], "10.2.3.4/24")
        self.assertEqual(network.wired["gateway"], "10.2.3.1")
        self.assertEqual(network.wired["dns"], "10.2.3.53")
        self.assertEqual(fake.started, ("nmcli", ["networking", "connectivity", "check"]))
        fake.output = b"full\n"
        network._wired_finished(0, None)
        self.assertEqual(network.wired["connectivity"], "full")

    def test_network_panel_labels_system_connectivity_separately_from_ethernet(self):
        ui_dir = UI_PATH.parents[1] / "share/atlasos/ui"
        network = (ui_dir / "components/AtlasNetwork.qml").read_text(encoding="utf-8")
        self.assertIn('function connectivityLabel(value)', network)
        self.assertIn('value === "portal"', network)
        self.assertIn("Ethernet'e özel değildir", network)

    def test_header_network_status_distinguishes_link_from_internet(self):
        ui_dir = UI_PATH.parents[1] / "share/atlasos/ui"
        header = (ui_dir / "components/AtlasHeader.qml").read_text(encoding="utf-8")
        status = (UI_PATH.parents[1] / "bin/atlasos-ui-status").read_text(encoding="utf-8")
        self.assertIn("nmcli networking connectivity check", status)
        self.assertIn("none)", status)
        self.assertIn("limited)", status)
        self.assertIn("portal)", status)
        self.assertIn('"İnternet yok"', header)

    def test_atlas_alerts_are_bounded_and_can_be_read(self):
        alerts = self.ui.AtlasAlerts()
        for index in range(25):
            alerts.add("Olay", str(index))
        self.assertEqual(len(alerts.items), 20)
        self.assertEqual(alerts.unread, 20)
        alerts.markRead()
        self.assertEqual(alerts.unread, 0)
        self.assertEqual(alerts.items[0]["message"], "24")
        alerts.clear()
        self.assertEqual(alerts.items, [])

    def test_whiteboard_png_is_saved_under_documents(self):
        png = base64.b64decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADUlEQVR4nGP4z8AAAAMBAQDJ/pLvAAAAAElFTkSuQmCC"
        )
        data_url = "data:image/png;base64," + base64.b64encode(png).decode("ascii")
        with tempfile.TemporaryDirectory() as temporary:
            with patch.object(self.ui.Path, "home", return_value=pathlib.Path(temporary)):
                saved = pathlib.Path(self.ui.AtlasFs().saveWhiteboard(data_url))
            self.assertEqual(saved.parent, pathlib.Path(temporary) / "Documents/AtlasOS/Ders")
            self.assertEqual(saved.read_bytes(), png)

    def test_whiteboard_rejects_invalid_png_data(self):
        fs = self.ui.AtlasFs()
        self.assertEqual(fs.saveWhiteboard("data:image/jpeg;base64,AAAA"), "")
        self.assertEqual(fs.saveWhiteboard("data:image/png;base64,not-base64!"), "")

    def test_internal_pdf_accepts_only_local_pdf_in_allowed_roots(self):
        filesystem = self.ui.AtlasFs()
        with tempfile.TemporaryDirectory(dir=pathlib.Path.home()) as folder:
            pdf = pathlib.Path(folder) / "lesson.pdf"
            pdf.write_bytes(b"%PDF-1.4\n")
            self.assertTrue(filesystem.canOpen("pdf", pdf.as_uri()))
            self.assertFalse(filesystem.canOpen("video", pdf.as_uri()))
            video = pathlib.Path(folder) / "lesson.mp4"
            video.write_bytes(b"placeholder")
            self.assertTrue(filesystem.canOpen("video", video.as_uri()))
            self.assertFalse(filesystem.canOpen("pdf", "https://example.com/lesson.pdf"))
            self.assertFalse(filesystem.canOpen("pdf", pathlib.Path(folder, "missing.pdf").as_uri()))

    def test_txt_reader_preserves_turkish_utf8_and_blank_files(self):
        filesystem = self.ui.AtlasFs()
        with tempfile.TemporaryDirectory(dir=pathlib.Path.home()) as folder:
            text_file = pathlib.Path(folder) / "Türkçe.txt"
            text_file.write_text("İçerik: ğüşiöç\n", encoding="utf-8")
            result = filesystem.readText(text_file.as_uri())
            self.assertTrue(result["ok"])
            self.assertEqual(result["text"], "İçerik: ğüşiöç\n")
            blank_file = pathlib.Path(folder) / "bos.txt"
            blank_file.write_text("", encoding="utf-8")
            blank_result = filesystem.readText(blank_file.as_uri())
            self.assertTrue(blank_result["ok"])
            self.assertEqual(blank_result["text"], "")

    def test_txt_reader_refuses_unapproved_paths_and_large_files(self):
        filesystem = self.ui.AtlasFs()
        with tempfile.TemporaryDirectory() as folder:
            external = pathlib.Path(folder) / "external.txt"
            external.write_text("Gizli", encoding="utf-8")
            self.assertFalse(filesystem.readText(external.as_uri())["ok"])
        with tempfile.TemporaryDirectory(dir=pathlib.Path.home()) as folder:
            large = pathlib.Path(folder) / "large.txt"
            large.write_text("x" * (2 * 1024 * 1024 + 1), encoding="utf-8")
            result = filesystem.readText(large.as_uri())
            self.assertFalse(result["ok"])
            self.assertIn("2 MB", result["error"])

    def test_text_editor_saves_utf8_content_in_place(self):
        filesystem = self.ui.AtlasFs()
        with tempfile.TemporaryDirectory(dir=pathlib.Path.home()) as folder:
            text_file = pathlib.Path(folder) / "edit.txt"
            text_file.write_text("edit", encoding="utf-8")
            result = filesystem.writeText(text_file.as_uri(), "Düzenlendi: ğüşiöç\n")
            self.assertTrue(result["ok"], result["error"])
            self.assertEqual(text_file.read_text(encoding="utf-8"), "Düzenlendi: ğüşiöç\n")
            self.assertEqual(list(pathlib.Path(folder).glob(".atlasos-save-*")), [])

    def test_text_reader_supports_common_text_formats(self):
        filesystem = self.ui.AtlasFs()
        with tempfile.TemporaryDirectory(dir=pathlib.Path.home()) as folder:
            for suffix in ("md", "csv", "json", "log"):
                text_file = pathlib.Path(folder) / f"lesson.{suffix}"
                text_file.write_text("AtlasOS içerik\n", encoding="utf-8")
                with self.subTest(suffix=suffix):
                    self.assertTrue(filesystem.canOpen("text", text_file.as_uri()))
                    self.assertEqual(filesystem.readText(text_file.as_uri())["text"], "AtlasOS içerik\n")

    def test_text_editor_refuses_symlinks_binary_and_oversized_content(self):
        filesystem = self.ui.AtlasFs()
        with tempfile.TemporaryDirectory() as outside:
            external = pathlib.Path(outside) / "external.txt"
            external.write_text("external", encoding="utf-8")
            with tempfile.TemporaryDirectory(dir=pathlib.Path.home()) as folder:
                link = pathlib.Path(folder) / "link.txt"
                link.symlink_to(external)
                self.assertFalse(filesystem.canOpen("text", link.as_uri()))
                binary = pathlib.Path(folder) / "binary.txt"
                binary.write_bytes(b"a\0b")
                self.assertFalse(filesystem.readText(binary.as_uri())["ok"])
                target = pathlib.Path(folder) / "large.txt"
                target.write_text("small", encoding="utf-8")
                result = filesystem.writeText(target.as_uri(), "x" * (filesystem.MAX_TEXT_BYTES + 1))
                self.assertFalse(result["ok"])
                self.assertEqual(target.read_text(encoding="utf-8"), "small")

    def test_finish_demo_only_removes_named_temp_dirs_and_preserves_documents(self):
        filesystem = self.ui.AtlasFs()
        with tempfile.TemporaryDirectory(dir=pathlib.Path.home()) as folder:
            home = pathlib.Path(folder)
            cache_demo = home / ".cache" / "atlasos-session"
            download_demo = home / "Downloads" / "atlasos-temp"
            personal = home / "Documents" / "keep.txt"
            cache_demo.mkdir(parents=True)
            download_demo.mkdir(parents=True)
            personal.parent.mkdir()
            (cache_demo / "demo.txt").write_text("demo", encoding="utf-8")
            (download_demo / "demo.txt").write_text("demo", encoding="utf-8")
            personal.write_text("keep", encoding="utf-8")
            with patch.object(self.ui.Path, "home", return_value=home):
                result = filesystem.finishDemoLesson()
            self.assertTrue(result["ok"])
            self.assertCountEqual(result["removed"], ["atlasos-session", "atlasos-temp"])
            self.assertFalse(cache_demo.exists())
            self.assertFalse(download_demo.exists())
            self.assertEqual(personal.read_text(encoding="utf-8"), "keep")


if __name__ == "__main__":
    unittest.main()
