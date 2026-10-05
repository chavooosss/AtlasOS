import importlib.util
import io
import json
import pathlib
import runpy
import tempfile
import unittest
import zipfile
from types import SimpleNamespace
from unittest.mock import patch


ROOT = pathlib.Path(__file__).resolve().parents[1]
MODULE = ROOT / "config/includes.chroot/usr/local/bin/atlasos_diagnostics.py"
PRIVILEGED_HELPER = ROOT / "config/includes.chroot/usr/local/libexec/atlasos-privileged-diagnostics"
spec = importlib.util.spec_from_file_location("atlasos_diagnostics", MODULE)
diag = importlib.util.module_from_spec(spec)
spec.loader.exec_module(diag)


class StorageFixtures:
    def __init__(self, root):
        self.root = pathlib.Path(root)
        self.sys = self.root / "sys"
        self.devices = self.sys / "devices"
        self.class_block = self.sys / "class/block"
        self.class_block.mkdir(parents=True)
        self.mountinfo = self.root / "mountinfo"
        self.cmdline = self.root / "cmdline"
        self.cmdline.write_text("quiet splash\n")
        self._mounts = []

    def device(self, name, number, *, usb=False, partition=False, parent=None):
        base = self.devices
        if usb:
            base = base / "pci0000:00" / "usb1" / "1-1" / "1-1:1.0" / "host7" / "target7:0:0" / "block"
        if partition:
            diskname = name.rstrip("0123456789")
            parentpath = self.devices / "internal" / "block" / diskname
            if usb:
                parentpath = self.devices / "pci0000:00" / "usb1" / "1-1" / "1-1:1.0" / "host7" / "target7:0:0" / "block" / diskname
            parentpath.mkdir(parents=True, exist_ok=True)
            (parentpath / "dev").write_text(parent or "8:0")
            (parentpath / "size").write_text("100000")
            path = parentpath / name
            path.mkdir(exist_ok=True)
            (path / "partition").write_text("1")
            (path / "dev").write_text(number)
            (path / "size").write_text("99000")
        else:
            path = base / name
            path.mkdir(parents=True, exist_ok=True)
            (path / "dev").write_text(number)
            (path / "size").write_text("100000")
        (path / "removable").write_text("0")
        alias = self.class_block / name
        if alias.exists() or alias.is_symlink():
            alias.unlink()
        alias.symlink_to(path, target_is_directory=True)
        return path

    def mount(self, number, point, *, mount_id="40", root="/", options="rw,relatime", source="/dev/sdb1"):
        # This fixture models mountinfo only; never create real system mountpoints.
        self._mounts.append(f"{mount_id} 1 {number} {root} {point} {options} - ext4 {source} rw")
        self.mountinfo.write_text("\n".join(self._mounts) + "\n")

    def boot_mount(self, number="8:0", source="/dev/sda"):
        self._mounts.append(f"10 1 {number} / /run/live/medium ro,relatime - iso9660 {source} ro")
        self.mountinfo.write_text("\n".join(self._mounts) + "\n")

    def policy(self):
        return diag.StorageSafetyPolicy(self.sys, self.mountinfo, self.cmdline)


class StorageSafetyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.fixtures = StorageFixtures(self.temp.name)

    def test_internal_sata_nvme_emmc_and_unknown_are_protected(self):
        for name, number in (("sda", "8:0"), ("nvme0n1", "259:0"), ("mmcblk0", "179:0")):
            self.fixtures.device(name, number)
        policy = self.fixtures.policy()
        for number in ("8:0", "259:0", "179:0"):
            self.assertEqual(policy.classify(number), policy.INTERNAL_PROTECTED)
        self.assertEqual(policy.classify("253:9"), policy.UNKNOWN_PROTECTED)

    def test_internal_efi_ntfs_and_recovery_partitions_remain_protected(self):
        self.fixtures.device("sda", "8:0")
        for name, number in (("sda1", "8:1"), ("sda2", "8:2"), ("sda3", "8:3")):
            self.fixtures.device(name, number, partition=True, parent="8:0")
        policy = self.fixtures.policy()
        for number in ("8:0", "8:1", "8:2", "8:3"):
            self.assertEqual(policy.classify(number), policy.INTERNAL_PROTECTED)

    def test_live_usb_is_not_export_target_but_second_usb_is(self):
        with tempfile.TemporaryDirectory() as live, tempfile.TemporaryDirectory() as export:
            self.fixtures.device("sda", "8:0", usb=True)
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.device("sda1", "8:1", usb=True, partition=True, parent="8:0")
            self.fixtures.device("sdb1", "8:17", usb=True, partition=True, parent="8:16")
            self.fixtures.mount("8:1", "/run/live/medium", mount_id="10", source="/dev/sda1", options="ro,relatime")
            self.fixtures.mount("8:17", export, mount_id="20", source="/dev/sdb1")
            policy = self.fixtures.policy()
            self.assertEqual(policy.classify("8:1"), policy.LIVE_BOOT_MEDIA)
            self.assertEqual([item["id"] for item in policy.export_targets()], ["20"])
            self.assertEqual(policy.authorize_destination(export, "20")["major_minor"], "8:17")

    def test_internal_mount_and_fake_media_path_are_rejected(self):
        with tempfile.TemporaryDirectory() as target:
            self.fixtures.device("nvme0n1", "259:0")
            self.fixtures.mount("259:0", target, mount_id="31", source="/dev/nvme0n1")
            with self.assertRaises(PermissionError):
                self.fixtures.policy().authorize_destination(target)

    def test_symlink_escape_and_path_traversal_are_rejected(self):
        with tempfile.TemporaryDirectory() as usb, tempfile.TemporaryDirectory() as internal:
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.mount("8:16", usb, mount_id="44", source="/dev/sdb")
            escape = pathlib.Path(usb) / "escape"
            escape.symlink_to(internal, target_is_directory=True)
            policy = self.fixtures.policy()
            with self.assertRaises(PermissionError):
                policy.authorize_destination(str(escape))
            with self.assertRaises(PermissionError):
                policy.authorize_destination(str(pathlib.Path(usb) / ".." / pathlib.Path(internal).name))

    def test_bind_mount_root_and_unknown_device_are_rejected(self):
        with tempfile.TemporaryDirectory() as target:
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.mount("8:16", target, mount_id="45", root="/nested", source="/dev/sdb")
            with self.assertRaises(PermissionError):
                self.fixtures.policy().authorize_destination(target)
        self.assertEqual(self.fixtures.policy().classify("0:88"), "UNKNOWN_PROTECTED")

    def test_valid_usb_export_copies_only_regular_bundle_file(self):
        with tempfile.TemporaryDirectory() as usb, tempfile.TemporaryDirectory() as volatile:
            self.fixtures.device("sda", "8:0", usb=True)
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.boot_mount()
            self.fixtures.mount("8:16", usb, mount_id="46", source="/dev/sdb")
            archive = pathlib.Path(volatile) / "AtlasOS-Diagnostics-0.6.2-20261003T100000Z.zip"
            archive.write_bytes(b"generated diagnostic archive")
            result = self.fixtures.policy().export(archive, usb, "46")
            self.assertEqual(pathlib.Path(result).read_bytes(), archive.read_bytes())
            with self.assertRaises(PermissionError):
                self.fixtures.policy().authorize_destination("/dev/sdb")

    def test_live_usb_unknown_and_unmounted_internal_are_never_exportable(self):
        with tempfile.TemporaryDirectory() as target:
            self.fixtures.device("sda", "8:0", usb=True)
            self.fixtures.mount("8:0", target, mount_id="47", source="/dev/sda", options="ro")
            self.fixtures.cmdline.write_text("boot=live live-media=/dev/sda\n")
            policy = self.fixtures.policy()
            self.assertEqual(policy.classify("8:0"), policy.LIVE_BOOT_MEDIA)
            self.assertEqual(policy.export_targets(), [])
            with self.assertRaises(PermissionError):
                policy.authorize_destination(target)
        self.assertEqual(self.fixtures.policy().classify("99:99"), "UNKNOWN_PROTECTED")

    def test_usb_removed_during_export_fails_without_fallback(self):
        with tempfile.TemporaryDirectory() as usb, tempfile.TemporaryDirectory() as volatile:
            self.fixtures.device("sda", "8:0", usb=True)
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.boot_mount()
            self.fixtures.mount("8:16", usb, mount_id="48", source="/dev/sdb")
            archive = pathlib.Path(volatile) / "AtlasOS-Diagnostics-0.6.2-20261003T100000Z.zip"
            archive.write_bytes(b"x" * 1024 * 1024)
            policy = self.fixtures.policy()
            original = policy.authorize_destination
            calls = 0
            def remove_after_initial_validation(destination, expected_mount_id=None):
                nonlocal calls
                calls += 1
                if calls == 3:
                    self.fixtures.mountinfo.write_text("")
                return original(destination, expected_mount_id)
            with patch.object(policy, "authorize_destination", side_effect=remove_after_initial_validation):
                with self.assertRaises(PermissionError):
                    policy.export(archive, usb, "48")
            self.assertFalse((pathlib.Path(usb) / archive.name).exists())

    def test_insufficient_space_stops_before_copy(self):
        with tempfile.TemporaryDirectory() as usb, tempfile.TemporaryDirectory() as volatile:
            self.fixtures.device("sda", "8:0", usb=True)
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.boot_mount()
            self.fixtures.mount("8:16", usb, mount_id="49", source="/dev/sdb")
            archive = pathlib.Path(volatile) / "AtlasOS-Diagnostics-0.6.2-20261003T100000Z.zip"
            archive.write_bytes(b"bundle")
            with patch.object(diag.shutil, "disk_usage", return_value=SimpleNamespace(free=1)):
                with self.assertRaises(OSError):
                    self.fixtures.policy().export(archive, usb, "49")
            self.assertFalse((pathlib.Path(usb) / archive.name).exists())

    def test_export_is_denied_when_live_boot_device_is_unknown(self):
        with tempfile.TemporaryDirectory() as usb:
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.mount("8:16", usb, mount_id="50", source="/dev/sdb")
            policy = self.fixtures.policy()
            self.assertEqual(policy.export_targets(), [])
            with self.assertRaises(PermissionError):
                policy.authorize_destination(usb)


class DiagnosticsCollectorTests(unittest.TestCase):
    def test_privileged_helper_rejects_arguments_and_non_root_invocation(self):
        helper = runpy.run_path(str(PRIVILEGED_HELPER), run_name="atlasos_privileged_diagnostics_test")
        self.assertEqual(helper["main"](["dmesg"]), 2)
        with patch.object(helper["os"], "geteuid", return_value=1000, create=True):
            self.assertEqual(helper["main"]([]), 2)

    def test_privileged_helper_runs_only_fixed_read_only_commands_without_shell(self):
        helper = runpy.run_path(str(PRIVILEGED_HELPER), run_name="atlasos_privileged_diagnostics_test")
        results = [SimpleNamespace(returncode=0, stdout="[ 1.0] kernel\n", stderr=""),
                   SimpleNamespace(returncode=0, stdout="[ 2.0] service\n", stderr="")]
        output = io.StringIO()
        with patch.object(helper["os"], "geteuid", return_value=0, create=True), \
             patch.object(helper["subprocess"], "run", side_effect=results) as run, \
             patch("sys.stdout", output):
            self.assertEqual(helper["main"]([]), 0)
        calls = run.call_args_list
        self.assertEqual([call.args[0] for call in calls], [helper["OPERATIONS"]["dmesg"], helper["OPERATIONS"]["journal_current"]])
        self.assertTrue(all(call.kwargs["shell"] is False for call in calls))
        self.assertTrue(all(call.kwargs["stdin"] is helper["subprocess"].DEVNULL for call in calls))
        self.assertFalse(any("mount" in arg for call in calls for arg in call.args[0]))
        payload = json.loads(output.getvalue())
        self.assertEqual(payload["operations"]["dmesg"]["stdout"], "[ 1.0] kernel\n")

    def test_collector_invokes_only_no_argument_privileged_diagnostics_helper(self):
        def runner(argv):
            self.assertEqual(argv, diag.DiagnosticsCollector.PRIVILEGED_BOOT_COMMAND)
            self.assertEqual(argv[1:], ("-n", "--", "/usr/local/libexec/atlasos-privileged-diagnostics"))
            return SimpleNamespace(returncode=0, stdout=json.dumps({
                "schema_version": 1,
                "operations": {
                    "dmesg": {"returncode": 0, "stdout": "[ 1.0] Linux version 6.12-test\n", "stderr": ""},
                    "journal_current": {"returncode": 0, "stdout": "[ 2.0] service\n", "stderr": ""},
                },
            }), stderr="")
        collector = diag.DiagnosticsCollector(command_runner=runner)
        self.assertEqual(collector._collect_privileged_boot(), {
            "dmesg": "[ 1.0] Linux version 6.12-test\n",
            "journal_current": "[ 2.0] service\n",
        })
        self.assertEqual(collector.errors, [])

    def test_timeline_parses_physical_monotonic_kernel_and_service_patterns(self):
        collector = diag.DiagnosticsCollector()
        timeline = collector._boot_timeline({
            "dmesg": "\n".join((
                "[    0.000000] Linux version 7.0.0-38-generic (buildd@lcy02-amd64-090) #38-Ubuntu SMP",
                "[   17.935374] simpledrm: Initialized simpledrm 1.0.0 for simple-framebuffer on minor 0",
                "[   20.179988] [drm] Initialized i915 1.6.0 for 0000:00:02.0 on minor 1",
                "[   20.189064] fbcon: i915drmfb (fb0) is primary device",
            )),
            "journal_current": "\n".join((
                "[   18.219727] atlas systemd[1]: Starting plymouth-start.service - Show Plymouth Boot Screen...",
                "[   32.769666] atlas systemd[1]: Starting lightdm.service - Light Display Manager...",
                "[   32.929117] atlas audit[800]: ANOM_ABEND auid=4294967295 uid=0 comm=\"Xorg.wrap\" exe=\"/usr/lib/xorg/Xorg.wrap\"",
                "[   36.404114] atlas lightdm[1200]: pam_unix(lightdm:session): session opened for user atlas(uid=1000)",
                "[   36.487335] atlas systemd-xdg-autostart-generator[1575]: /etc/xdg/autostart/atlasos-ui-status.desktop: not generating unit",
            )),
        })["events"]
        expected = {
            "kernel_start": 0.0,
            "framebuffer_or_simpledrm": 17.935374,
            "native_drm_init": 20.179988,
            "fbcon_takeover": 20.189064,
            "plymouth_start": 18.219727,
            "display_manager_start": 32.769666,
            "xorg_start": 32.929117,
            "atlas_session_start": 36.404114,
        }
        for event, timestamp in expected.items():
            self.assertEqual(timeline[event]["seconds_since_boot"], timestamp, event)
            self.assertIsNotNone(timeline[event]["event"], event)
        self.assertIsNone(timeline["atlas_ui_start"]["seconds_since_boot"])
        self.assertIsNone(timeline["atlas_ui_start"]["event"])

    def test_wall_clock_kernel_timestamp_is_never_invented_as_monotonic(self):
        collector = diag.DiagnosticsCollector()
        events = collector._boot_timeline({
            "dmesg": "[2026-10-03T15:44:31,000859+03:00] Linux version 7.0.0-38-generic",
            "journal_current": "",
        })["events"]
        self.assertIsNone(events["kernel_start"]["seconds_since_boot"])
        self.assertEqual(events["kernel_start"]["timestamp_kind"], "wall_clock")
        self.assertIn("2026-10-03T15:44:31", events["kernel_start"]["wall_clock_timestamp"])

    def test_bundle_storage_refuses_non_run_fallback_without_injected_test_root(self):
        with tempfile.TemporaryDirectory() as temp:
            collector = diag.DiagnosticsCollector(run_root=temp)
            with self.assertRaises(OSError):
                collector._bundle_root()

    def test_user_runtime_directory_must_be_owned_private_and_writable(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            uid = 1000
            runtime = root / str(uid)
            private_dir = SimpleNamespace(st_mode=diag.stat.S_IFDIR | 0o700, st_uid=uid)
            with patch.object(pathlib.Path, "lstat", return_value=private_dir):
                self.assertEqual(diag.DiagnosticsCollector._validate_runtime_directory(runtime, expected_uid=uid, user_root=root), runtime)
            with patch.object(pathlib.Path, "lstat", return_value=SimpleNamespace(st_mode=diag.stat.S_IFDIR | 0o777, st_uid=uid)):
                with self.assertRaises(OSError):
                    diag.DiagnosticsCollector._validate_runtime_directory(runtime, expected_uid=uid, user_root=root)
            with patch.object(pathlib.Path, "lstat", return_value=private_dir):
                with self.assertRaises(OSError):
                    diag.DiagnosticsCollector._validate_runtime_directory(runtime, expected_uid=uid + 1, user_root=root)

    def test_bundle_is_generated_in_injected_volatile_area_and_privacy_filtered(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            proc = root / "proc"
            sysroot = root / "sys"
            volatile = root / "run"
            for directory in (proc, sysroot / "class/block", sysroot / "class/drm", sysroot / "class/net", sysroot / "class/thermal", volatile):
                directory.mkdir(parents=True, exist_ok=True)
            (proc / "cpuinfo").write_text("processor\t: 0\nmodel name\t: Example CPU\n")
            (proc / "stat").write_text("cpu 100 0 20 500 0 0 0 0\n")
            (proc / "meminfo").write_text("MemTotal: 8192000 kB\nMemAvailable: 4096000 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB\n")
            (proc / "uptime").write_text("42.00 21.00\n")
            (proc / "loadavg").write_text("0.10 0.20 0.30 1/100 777\n")
            (proc / "cmdline").write_text("quiet splash root=UUID=12345678-abcd-1234-abcd-123456789abc\n")
            (proc / "sys/kernel").mkdir(parents=True)
            (proc / "sys/kernel/osrelease").write_text("6.12-test\n")
            mountinfo = root / "mountinfo"
            mountinfo.write_text("")
            def runner(argv):
                output = "" if argv[0] == "systemctl" else "/home/veli test aa:bb:cc:dd:ee:ff 192.168.1.20 password=hunter2 user=veli UID=1000\n"
                return SimpleNamespace(returncode=0, stdout=output, stderr="")
            collector = diag.DiagnosticsCollector(sysroot, proc, root, runner, mountinfo, volatile)
            progress = []
            result = collector.collect_all(lambda label, value: progress.append((label, value)))
            self.assertTrue(result["ok"])
            self.assertTrue(pathlib.Path(result["bundle"]).is_relative_to(volatile))
            self.assertEqual([value for _, value in progress], [10, 25, 40, 60, 78, 92])
            with zipfile.ZipFile(result["bundle"]) as bundle:
                names = set(bundle.namelist())
                self.assertIn("summary.json", names)
                self.assertIn("boot/physical-video-observations.json", names)
                self.assertIn("collection/manifest.json", names)
                log = bundle.read("graphics/lspci.txt").decode()
                self.assertNotIn("veli", log)
                self.assertNotIn("hunter2", log)
                self.assertNotIn("user=veli", log)
                self.assertNotIn("UID=1000", log)
                self.assertNotIn("192.168.1.20", log)
                summary = json.loads(bundle.read("summary.json"))
                self.assertEqual(summary["schema_version"], 1)
                self.assertEqual(summary["storage_safety_state"], "INTERNAL_READ_ONLY_UNKNOWN_PROTECTED")
                self.assertIn("atlas_ui", summary)
                self.assertNotIn("12345678-abcd-1234-abcd-123456789abc", bundle.read("summary.json").decode())
                observations = json.loads(bundle.read("boot/physical-video-observations.json"))
                self.assertTrue(all(value is None for value in observations.values()))

    def test_collector_uses_no_shell_and_forbidden_commands_are_not_invoked(self):
        source = MODULE.read_text(encoding="utf-8")
        self.assertIn("shell=False", source)
        self.assertIn("stdin=subprocess.DEVNULL", source)
        self.assertIn("FORBIDDEN_COMMANDS", source)
        for command in diag.FORBIDDEN_COMMANDS:
            self.assertNotIn(f'("{command}"', source)

    def test_missing_commands_are_partial_errors_not_fake_success(self):
        def missing(_argv):
            raise FileNotFoundError()
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            proc = root / "proc"
            proc.mkdir()
            collector = diag.DiagnosticsCollector(root / "sys", proc, root, missing)
            output = collector._collect_command("lspci")
            self.assertIn("Mevcut değil", output)
            self.assertEqual(collector.errors[0]["collector"], "lspci")

    def test_cancellation_removes_partial_bundle_from_volatile_area(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            proc = root / "proc"
            proc.mkdir()
            (proc / "cpuinfo").write_text("processor\t: 0\nmodel name\t: Example CPU\n")
            (proc / "stat").write_text("cpu 10 0 1 20 0 0 0 0\n")
            (proc / "meminfo").write_text("MemTotal: 1000 kB\nMemAvailable: 500 kB\n")
            (proc / "uptime").write_text("1.0 1.0\n")
            (proc / "cmdline").write_text("quiet\n")
            volatile = root / "run"
            volatile.mkdir()
            collector = diag.DiagnosticsCollector(root / "sys", proc, root, lambda _argv: SimpleNamespace(returncode=0, stdout="", stderr=""), root / "mountinfo", volatile)
            def cancel(_label, _value):
                raise InterruptedError("cancelled")
            with self.assertRaises(InterruptedError):
                collector.collect_all(progress=cancel)
            self.assertEqual(list(volatile.iterdir()), [])

    def test_storage_diagnostics_never_walk_filesystem_contents(self):
        source = MODULE.read_text(encoding="utf-8")
        self.assertNotIn("os.walk(", source)
        self.assertNotIn("rglob('*')", source)
        self.assertIn("filesystem_scanning\": False", source)


if __name__ == "__main__":
    unittest.main()
