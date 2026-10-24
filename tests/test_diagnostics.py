import hashlib
import importlib.util
import io
import json
import os
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


def write_valid_bundle(path, extra_payload=b"generated diagnostic archive"):
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
        bundle.writestr("README.txt", "AtlasOS diagnostics test bundle\n")
        bundle.writestr("summary.json", '{"schema_version": 1}\n')
        bundle.writestr("collection/manifest.json", '{"files": []}\n')
        bundle.writestr("test/payload.bin", extra_payload)
    return pathlib.Path(path)


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
            archive = write_valid_bundle(pathlib.Path(volatile) / f"AtlasOS-Diagnostics-{diag.VERSION}-20261003T100000Z.zip")
            result = self.fixtures.policy().export(archive, usb, "46")
            self.assertEqual(pathlib.Path(result).read_bytes(), archive.read_bytes())
            self.assertEqual(
                hashlib.sha256(pathlib.Path(result).read_bytes()).digest(),
                hashlib.sha256(archive.read_bytes()).digest(),
            )
            self.assertTrue(zipfile.is_zipfile(result))
            self.assertFalse(any(path.name.endswith(".partial") for path in pathlib.Path(usb).iterdir()))
            with self.assertRaises(PermissionError):
                self.fixtures.policy().authorize_destination("/dev/sdb")

    def test_empty_or_invalid_bundle_is_rejected_before_usb_file_is_created(self):
        with tempfile.TemporaryDirectory() as usb, tempfile.TemporaryDirectory() as volatile:
            self.fixtures.device("sda", "8:0", usb=True)
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.boot_mount()
            self.fixtures.mount("8:16", usb, mount_id="47", source="/dev/sdb")
            for payload in (b"", b"not a zip archive"):
                archive = pathlib.Path(volatile) / f"AtlasOS-Diagnostics-{diag.VERSION}-20261003T100000Z.zip"
                archive.write_bytes(payload)
                with self.assertRaises(ValueError):
                    self.fixtures.policy().export(archive, usb, "47")
            self.assertEqual(list(pathlib.Path(usb).iterdir()), [])

    def test_incomplete_usb_copy_never_publishes_a_final_zip(self):
        with tempfile.TemporaryDirectory() as usb, tempfile.TemporaryDirectory() as volatile:
            self.fixtures.device("sda", "8:0", usb=True)
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.boot_mount()
            self.fixtures.mount("8:16", usb, mount_id="47", source="/dev/sdb")
            archive = write_valid_bundle(
                pathlib.Path(volatile) / f"AtlasOS-Diagnostics-{diag.VERSION}-20261003T100001Z.zip",
                b"x" * (2 * 1024 * 1024),
            )
            policy = self.fixtures.policy()
            original = policy.authorize_destination
            calls = 0

            def interrupt_copy(destination, expected_mount_id=None):
                nonlocal calls
                calls += 1
                if calls == 3:
                    raise PermissionError("simulated USB removal")
                return original(destination, expected_mount_id)

            with patch.object(policy, "authorize_destination", side_effect=interrupt_copy):
                with self.assertRaisesRegex(OSError, "simulated USB removal.*empty file"):
                    policy.export(archive, usb, "47")
            failed_output = pathlib.Path(usb) / archive.name
            self.assertTrue(failed_output.exists())
            self.assertEqual(failed_output.stat().st_size, 0, "Failed export must leave no corrupt bytes presented as a completed ZIP.")

    def test_live_usb_unknown_and_unmounted_internal_are_never_exportable(self):
        self.fixtures.device("sda", "8:0", usb=True)
        # Identify the live medium through the synthetic mount table rather
        # than resolving /dev/sda on the host running the test.
        self.fixtures.boot_mount("8:0", source="/dev/sda")
        policy = self.fixtures.policy()
        self.assertEqual(policy.classify("8:0"), policy.LIVE_BOOT_MEDIA)
        self.assertEqual(policy.export_targets(), [])
        self.assertEqual(self.fixtures.policy().classify("99:99"), "UNKNOWN_PROTECTED")

    def test_usb_removed_during_export_fails_without_fallback(self):
        with tempfile.TemporaryDirectory() as usb, tempfile.TemporaryDirectory() as volatile:
            self.fixtures.device("sda", "8:0", usb=True)
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.boot_mount()
            self.fixtures.mount("8:16", usb, mount_id="48", source="/dev/sdb")
            archive = write_valid_bundle(pathlib.Path(volatile) / f"AtlasOS-Diagnostics-{diag.VERSION}-20261003T100000Z.zip",
                                         b"x" * 1024 * 1024)
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
                with self.assertRaisesRegex(OSError, "block aygıtı doğrulanamadı.*empty file"):
                    policy.export(archive, usb, "48")
            failed_output = pathlib.Path(usb) / archive.name
            self.assertTrue(failed_output.exists())
            self.assertEqual(failed_output.stat().st_size, 0, "USB loss must not leave a corrupt archive presented as complete.")

    def test_insufficient_space_stops_before_copy(self):
        with tempfile.TemporaryDirectory() as usb, tempfile.TemporaryDirectory() as volatile:
            self.fixtures.device("sda", "8:0", usb=True)
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.boot_mount()
            self.fixtures.mount("8:16", usb, mount_id="49", source="/dev/sdb")
            archive = write_valid_bundle(pathlib.Path(volatile) / f"AtlasOS-Diagnostics-{diag.VERSION}-20261003T100000Z.zip")
            with patch.object(diag.shutil, "disk_usage", return_value=SimpleNamespace(free=1)):
                with self.assertRaises(OSError):
                    self.fixtures.policy().export(archive, usb, "49")
            self.assertFalse((pathlib.Path(usb) / archive.name).exists())
            self.assertEqual(list(pathlib.Path(usb).iterdir()), [], "Insufficient space must not leave a partial file.")

    def test_export_is_denied_when_live_boot_device_is_unknown(self):
        with tempfile.TemporaryDirectory() as usb:
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.mount("8:16", usb, mount_id="50", source="/dev/sdb")
            policy = self.fixtures.policy()
            self.assertEqual(policy.export_targets(), [])
            with self.assertRaises(PermissionError):
                policy.authorize_destination(usb)

    def test_current_version_bundle_name_is_accepted_for_export(self):
        with tempfile.TemporaryDirectory() as usb, tempfile.TemporaryDirectory() as volatile:
            self.fixtures.device("sda", "8:0", usb=True)
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.boot_mount()
            self.fixtures.mount("8:16", usb, mount_id="52", source="/dev/sdb")
            archive = write_valid_bundle(pathlib.Path(volatile) / f"AtlasOS-Diagnostics-{diag.VERSION}-20261016T120000Z.zip")
            result = self.fixtures.policy().export(archive, usb, "52")
            self.assertEqual(pathlib.Path(result).read_bytes(), archive.read_bytes())
            self.assertFalse(any(path.name.endswith(".partial") for path in pathlib.Path(usb).iterdir()))

    def test_export_rejects_archive_from_a_different_release_version(self):
        with tempfile.TemporaryDirectory() as usb, tempfile.TemporaryDirectory() as volatile:
            self.fixtures.device("sda", "8:0", usb=True)
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.boot_mount()
            self.fixtures.mount("8:16", usb, mount_id="54", source="/dev/sdb")
            archive = write_valid_bundle(pathlib.Path(volatile) / "AtlasOS-Diagnostics-0.6.2-20261016T120002Z.zip")
            with self.assertRaises(ValueError):
                self.fixtures.policy().export(archive, usb, "54")
            self.assertEqual(list(pathlib.Path(usb).iterdir()), [])

    def test_export_does_not_overwrite_an_existing_bundle(self):
        with tempfile.TemporaryDirectory() as usb, tempfile.TemporaryDirectory() as volatile:
            self.fixtures.device("sda", "8:0", usb=True)
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.boot_mount()
            self.fixtures.mount("8:16", usb, mount_id="53", source="/dev/sdb")
            archive = write_valid_bundle(pathlib.Path(volatile) / f"AtlasOS-Diagnostics-{diag.VERSION}-20261016T120001Z.zip")
            existing = pathlib.Path(usb) / archive.name
            old_bytes = b"existing user file must remain byte-for-byte unchanged"
            existing.write_bytes(old_bytes)
            with self.assertRaises(FileExistsError):
                self.fixtures.policy().export(archive, usb, "53")
            self.assertEqual(existing.read_bytes(), old_bytes)

    def test_target_created_immediately_before_exclusive_open_is_preserved(self):
        with tempfile.TemporaryDirectory() as usb, tempfile.TemporaryDirectory() as volatile:
            self.fixtures.device("sda", "8:0", usb=True)
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.boot_mount()
            self.fixtures.mount("8:16", usb, mount_id="54", source="/dev/sdb")
            archive = write_valid_bundle(pathlib.Path(volatile) / f"AtlasOS-Diagnostics-{diag.VERSION}-20261016T120003Z.zip")
            target = pathlib.Path(usb) / archive.name
            rival_bytes = b"rival file created at exclusive-open boundary"
            real_open = diag.os.open
            injected = False

            def create_rival_before_exclusive_open(path, flags, *args, **kwargs):
                nonlocal injected
                if path == archive.name and flags & diag.os.O_EXCL:
                    injected = True
                    target.write_bytes(rival_bytes)
                return real_open(path, flags, *args, **kwargs)

            with patch.object(diag.os, "open", side_effect=create_rival_before_exclusive_open):
                with self.assertRaises(FileExistsError):
                    self.fixtures.policy().export(archive, usb, "54")
            self.assertTrue(injected)
            self.assertEqual(target.read_bytes(), rival_bytes)

    def test_write_failure_is_not_reported_as_success_and_owned_file_is_zeroed(self):
        with tempfile.TemporaryDirectory() as usb, tempfile.TemporaryDirectory() as volatile:
            self.fixtures.device("sda", "8:0", usb=True)
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.boot_mount()
            self.fixtures.mount("8:16", usb, mount_id="55", source="/dev/sdb")
            archive = write_valid_bundle(pathlib.Path(volatile) / f"AtlasOS-Diagnostics-{diag.VERSION}-20261016T120004Z.zip")
            target = pathlib.Path(usb) / archive.name
            real_write = diag.os.write
            write_count = 0

            def fail_after_partial_write(fd, data):
                nonlocal write_count
                write_count += 1
                if write_count == 1:
                    return real_write(fd, data[:64])
                raise OSError(diag.errno.ENOSPC, "simulated USB full during write")

            with patch.object(diag.os, "write", side_effect=fail_after_partial_write):
                with self.assertRaisesRegex(OSError, "simulated USB full.*Export failed"):
                    self.fixtures.policy().export(archive, usb, "55")
            self.assertTrue(target.exists())
            self.assertEqual(target.stat().st_size, 0)
            self.assertFalse(zipfile.is_zipfile(target))

    def test_path_replacement_during_write_preserves_rival_and_never_reports_success(self):
        with tempfile.TemporaryDirectory() as usb, tempfile.TemporaryDirectory() as volatile:
            self.fixtures.device("sda", "8:0", usb=True)
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.boot_mount()
            self.fixtures.mount("8:16", usb, mount_id="56", source="/dev/sdb")
            archive = write_valid_bundle(pathlib.Path(volatile) / f"AtlasOS-Diagnostics-{diag.VERSION}-20261016T120005Z.zip")
            target = pathlib.Path(usb) / archive.name
            rival_bytes = b"replacement belongs to another process"
            policy = self.fixtures.policy()
            original_authorize = policy.authorize_destination
            calls = 0

            real_write = diag.os.write
            replaced = False

            def replace_owned_path_after_first_write(fd, data):
                nonlocal replaced
                written = real_write(fd, data)
                if not replaced and target.exists() and target.stat().st_size:
                    target.unlink()
                    target.write_bytes(rival_bytes)
                    replaced = True
                return written

            with patch.object(diag.os, "write", side_effect=replace_owned_path_after_first_write):
                with self.assertRaisesRegex(OSError, "girdisi aktarım sırasında değişti"):
                    policy.export(archive, usb, "56")
            self.assertEqual(target.read_bytes(), rival_bytes)

    def test_failed_cleanup_keeps_primary_error_and_never_unlinks_by_path(self):
        with tempfile.TemporaryDirectory() as usb, tempfile.TemporaryDirectory() as volatile:
            self.fixtures.device("sda", "8:0", usb=True)
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.boot_mount()
            self.fixtures.mount("8:16", usb, mount_id="57", source="/dev/sdb")
            archive = write_valid_bundle(pathlib.Path(volatile) / f"AtlasOS-Diagnostics-{diag.VERSION}-20261016T120006Z.zip")
            target = pathlib.Path(usb) / archive.name
            real_write = diag.os.write
            writes = 0

            def fail_write_after_first_chunk(fd, data):
                nonlocal writes
                writes += 1
                if writes == 1:
                    return real_write(fd, data[:64])
                raise OSError(diag.errno.EIO, "primary write failure")

            with (
                patch.object(diag.os, "write", side_effect=fail_write_after_first_chunk),
                patch.object(diag.os, "ftruncate", side_effect=OSError(diag.errno.EIO, "secondary truncate failure")),
                patch.object(diag.os, "unlink", side_effect=AssertionError("pathname deletion is forbidden")) as unlink,
            ):
                with self.assertRaisesRegex(OSError, "primary write failure.*cleanup failed") as raised:
                    self.fixtures.policy().export(archive, usb, "57")
            unlink.assert_not_called()
            self.assertIsInstance(raised.exception.__cause__, OSError)
            self.assertEqual(raised.exception.__cause__.errno, diag.errno.EIO)
            self.assertIn("secondary truncate failure", str(raised.exception))
            self.assertTrue(target.exists())

    def test_complete_archive_is_retained_if_post_write_mount_check_fails(self):
        with tempfile.TemporaryDirectory() as usb, tempfile.TemporaryDirectory() as volatile:
            self.fixtures.device("sda", "8:0", usb=True)
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.boot_mount()
            self.fixtures.mount("8:16", usb, mount_id="58", source="/dev/sdb")
            archive = write_valid_bundle(pathlib.Path(volatile) / f"AtlasOS-Diagnostics-{diag.VERSION}-20261016T120007Z.zip")
            target = pathlib.Path(usb) / archive.name
            policy = self.fixtures.policy()
            original_authorize = policy.authorize_destination
            calls = 0

            def fail_at_post_write_check(destination, expected_mount_id=None):
                nonlocal calls
                calls += 1
                if calls == 5:
                    raise PermissionError("simulated mount change after completed write")
                return original_authorize(destination, expected_mount_id)

            with patch.object(policy, "authorize_destination", side_effect=fail_at_post_write_check):
                with self.assertRaisesRegex(OSError, "doğrulandı.*final dosya silinmedi"):
                    policy.export(archive, usb, "58")
            self.assertEqual(target.read_bytes(), archive.read_bytes())
            self.assertTrue(zipfile.is_zipfile(target))

    def test_directory_entry_replacement_after_open_cannot_pass_identity_check(self):
        with tempfile.TemporaryDirectory() as usb, tempfile.TemporaryDirectory() as volatile:
            self.fixtures.device("sda", "8:0", usb=True)
            self.fixtures.device("sdb", "8:16", usb=True)
            self.fixtures.boot_mount()
            self.fixtures.mount("8:16", usb, mount_id="59", source="/dev/sdb")
            archive = write_valid_bundle(pathlib.Path(volatile) / f"AtlasOS-Diagnostics-{diag.VERSION}-20261016T120008Z.zip")
            target = pathlib.Path(usb) / archive.name
            rival_bytes = b"different file was installed at final path"
            policy = self.fixtures.policy()
            original_authorize = policy.authorize_destination
            calls = 0

            real_write = diag.os.write
            replaced = False

            def replace_after_first_write(fd, data):
                nonlocal replaced
                written = real_write(fd, data)
                if not replaced and target.exists() and target.stat().st_size:
                    target.unlink()
                    target.write_bytes(rival_bytes)
                    replaced = True
                return written

            with patch.object(diag.os, "write", side_effect=replace_after_first_write):
                with self.assertRaisesRegex(OSError, "girdisi aktarım sırasında değişti"):
                    policy.export(archive, usb, "59")
            self.assertEqual(target.read_bytes(), rival_bytes)

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
        self.assertEqual(diag.VERSION, "0.6.4")
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
            (proc / "asound").mkdir()
            (proc / "asound/cards").write_text(" 0 [PCH            ]: HDA-Intel - HDA Intel PCH\n")
            (proc / "sys/kernel").mkdir(parents=True)
            (proc / "sys/kernel/osrelease").write_text("6.12-test\n")
            mountinfo = root / "mountinfo"
            mountinfo.write_text("")
            def runner(argv):
                output = "" if argv[0] == "systemctl" else "/home/veli test aa:bb:cc:dd:ee:ff 192.168.1.20 password=hunter2 user=veli UID=1000\n"
                if argv[0] == "journalctl":
                    output += "\n".join((
                        "NetworkManager: Config: added 'ssid' value 'Fake Archive Network Name'",
                        "NetworkManager: device (wlan0): Activation: (wifi) access point 'Fake Archive AP' has security",
                        'NetworkManager: device (wlan0): Activation successful. Connected to wireless network "Fake Archive Connected"',
                        "NetworkManager: device (wlan0): state change: config -> activated",
                    )) + "\n"
                return SimpleNamespace(returncode=0, stdout=output, stderr="")
            collector = diag.DiagnosticsCollector(sysroot, proc, root, runner, mountinfo, volatile)
            progress = []
            result = collector.collect_all(lambda label, value: progress.append((label, value)))
            self.assertTrue(result["ok"])
            self.assertGreater(result["size_bytes"], 0)
            self.assertTrue(pathlib.Path(result["bundle"]).is_relative_to(volatile))
            self.assertEqual([value for _, value in progress], [10, 25, 40, 60, 78, 92, 93, 94, 95, 96, 97, 98, 99])
            with zipfile.ZipFile(result["bundle"]) as bundle:
                names = set(bundle.namelist())
                self.assertIn("summary.json", names)
                self.assertEqual(json.loads(bundle.read("atlas/version.json")), {"version": "0.6.4"})
                self.assertIn("boot/physical-video-observations.json", names)
                self.assertIn("collection/manifest.json", names)
                self.assertIn("audio/output-route.json", names)
                self.assertIn("system/time-sync.json", names)
                self.assertIn("network/https-connectivity.json", names)
                self.assertIn("browser/browser-and-ca-status.json", names)
                self.assertIn("field/physical-observations.json", names)
                self.assertIn("audio/recent-audio-service-log.txt", names)
                log = bundle.read("graphics/lspci.txt").decode()
                self.assertNotIn("veli", log)
                self.assertNotIn("hunter2", log)
                self.assertNotIn("user=veli", log)
                self.assertNotIn("UID=1000", log)
                self.assertNotIn("192.168.1.20", log)
                summary = json.loads(bundle.read("summary.json"))
                self.assertEqual(summary["schema_version"], 2)
                self.assertEqual(summary["storage_safety_state"], "INTERNAL_READ_ONLY_UNKNOWN_PROTECTED")
                self.assertIn("atlas_ui", summary)
                self.assertNotIn("12345678-abcd-1234-abcd-123456789abc", bundle.read("summary.json").decode())
                observations = json.loads(bundle.read("boot/physical-video-observations.json"))
                self.assertTrue(all(value is None for value in observations.values()))
                field = json.loads(bundle.read("field/physical-observations.json"))
                self.assertEqual(field["observations"]["speaker_test"]["value"], "not_tested")
                self.assertFalse(field["urls_or_page_contents_collected"])
                manifest = json.loads(bundle.read("collection/manifest.json"))
                self.assertEqual(manifest["schema_version"], 2)
                self.assertIn("SSIDs and Wi-Fi profile names in supported log formats", manifest["sanitization"])
                archive_payload = b"\n".join(bundle.read(name) for name in names)
                for fake_ssid in (b"Fake Archive Network Name", b"Fake Archive AP", b"Fake Archive Connected"):
                    self.assertNotIn(fake_ssid, archive_payload)
                network_log = bundle.read("network/recent-network-events.txt").decode()
                self.assertIn("state change: config -> activated", network_log)
                self.assertIn("Activation successful", network_log)
                self.assertTrue({
                    "audio/output-route.json", "system/time-sync.json", "network/https-connectivity.json",
                    "browser/browser-and-ca-status.json", "field/physical-observations.json",
                }.issubset(set(manifest["files"])))

    def test_https_probe_keeps_tls_verification_and_only_records_issuer(self):
        calls = []
        def runner(argv):
            calls.append(argv)
            return SimpleNamespace(returncode=60, stdout="000|60", stderr="*  issuer: O=School Network, CN=Inspection CA\nAuthorization: private-value")
        collector = diag.DiagnosticsCollector(command_runner=runner)
        result = collector._https_probe("affected_site", "chavooosss.github.io")
        self.assertEqual(result["category"], "certificate")
        self.assertEqual(result["tls_verify_result"], 60)
        self.assertEqual(result["presented_issuer"], "O=School Network, CN=Inspection CA")
        self.assertEqual(len(calls), 1)
        self.assertNotIn("--insecure", calls[0])
        self.assertIn("https://chavooosss.github.io/", calls[0])
        self.assertNotIn("Authorization", json.dumps(result))

    def test_network_diagnostics_probe_only_fixed_hosts_and_store_no_proxy_values(self):
        calls = []
        def runner(argv):
            calls.append(argv)
            if argv[0] == "curl":
                return SimpleNamespace(returncode=0, stdout="200|0", stderr="*  issuer: C=US, O=Public CA, CN=Example Issuer")
            return SimpleNamespace(returncode=0, stdout="", stderr="")
        collector = diag.DiagnosticsCollector(command_runner=runner)
        with patch.dict("os.environ", {"https_proxy": "http://user:password@proxy.internal:8080"}):
            result = collector._network_diagnostics()
        self.assertTrue(result["proxy_environment_configured"])
        self.assertEqual([item["host"] for item in result["probes"]],
                         ["chavooosss.github.io", "example.com", "www.eba.gov.tr",
                          "ogmmateryal.eba.gov.tr", "mebi.eba.gov.tr"])
        self.assertTrue(all(item["tls_verification"] == "enabled" for item in result["probes"]))
        self.assertNotIn("proxy.internal", json.dumps(result))
        self.assertNotIn("password", json.dumps(result))
        curl_calls = [call for call in calls if call[0] == "curl"]
        self.assertEqual(len(curl_calls), 5)
        self.assertTrue(all("--insecure" not in call for call in curl_calls))

    def test_field_observations_allow_only_non_sensitive_enumerated_values(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            proc = root / "proc"
            proc.mkdir()
            volatile = root / "volatile"
            mountinfo = root / "mountinfo"
            mountinfo.write_text("")
            collector = diag.DiagnosticsCollector(root / "sys", proc, root,
                lambda _argv: SimpleNamespace(returncode=0, stdout="", stderr=""),
                mountinfo_path=mountinfo, volatile_root=volatile)
            result = collector.collect_all(observations={
                "speaker_test": {"value": "silent", "recorded_at_utc": "2026-10-16T12:00:00+00:00"},
                "chrome_navigation": {"value": "certificate_authority_invalid", "recorded_at_utc": "2026-10-16T12:00:00+00:00"},
                "extra": {"value": "https://school.example/private?token=secret"},
            })
            with zipfile.ZipFile(result["bundle"]) as bundle:
                data = bundle.read("field/physical-observations.json").decode()
                self.assertIn("certificate_authority_invalid", data)
                self.assertIn("silent", data)
                self.assertNotIn("school.example", data)
                self.assertNotIn("token=secret", data)

    def test_audio_snapshot_is_read_only_and_has_output_route_evidence(self):
        def runner(argv):
            if argv[0] == "wpctl" and argv[1] == "get-volume":
                output = "Volume: 0.40 [MUTED]\n"
            elif argv[0] == "wpctl" and argv[1] == "inspect":
                output = "id 42, type PipeWire:Interface:Node\n\tmedia.class = \"Audio/Sink\"\n\tnode.name = \"alsa_output.pci-0000_00_1f.3.analog-stereo\"\n\tnode.state = \"suspended\"\n\tdevice.description = \"Built-in Audio\"\n"
            elif argv[:3] == ("pactl", "list", "cards"):
                output = "Card #2\n        Name: alsa_card.test\n        Profiles:\n                output:analog-stereo: Analog Stereo Output (sinks: 1, sources: 0, priority: 6500, available: yes)\n        Active Profile: output:analog-stereo\n        Ports:\n                analog-output-speaker: Speakers (type: Speaker, priority: 10000, available: yes)\n        Properties:\n                device.serial = \"PRIVATE-SERIAL-987\"\n"
            elif argv[:3] == ("pactl", "list", "sinks"):
                output = "Sink #42\n        Name: alsa_output.test.analog\n        Description: Analog Output\n        Ports:\n                analog-output-speaker: Speakers (type: Speaker, priority: 10000, available: yes)\n        Active Port: analog-output-speaker\n        Properties:\n                device.serial = \"PRIVATE-SERIAL-987\"\n"
            elif argv[0] == "timedatectl":
                output = "Timezone=Europe/Istanbul\nNTPSynchronized=no\nNTP=yes\nLocalRTC=no\nTimeUSec=2026-10-23T08:24:00Z\n"
            elif argv[0] == "chronyc":
                output = "Reference ID : 192.0.2.5\nLeap status : Not synchronised\n"
            else:
                output = "card 0: PCH [HDA Intel PCH], device 0: ALC Analog [ALC Analog]\n"
            return SimpleNamespace(returncode=0, stdout=output, stderr="")
        collector = diag.DiagnosticsCollector(command_runner=runner)
        result = collector._audio_diagnostics()
        self.assertIn("MUTED", result["default_sink_volume_and_mute"])
        self.assertIn("node.state", result["default_sink_properties"])
        self.assertIn("Audio/Sink", result["default_sink_properties"])
        self.assertIn("Built-in Audio", result["default_sink_properties"])
        self.assertIn("Card #2", result["audio_card_profiles_and_ports"])
        self.assertIn("output:analog-stereo", result["audio_card_profiles_and_ports"])
        self.assertIn("analog-output-speaker", result["audio_card_profiles_and_ports"])
        self.assertNotIn("PRIVATE-SERIAL-987", result["audio_card_profiles_and_ports"])
        self.assertNotIn("Properties:", result["audio_card_profiles_and_ports"])
        self.assertIn("Sink #42", result["sink_ports_and_active_port"])
        self.assertIn("Active Port: analog-output-speaker", result["sink_ports_and_active_port"])
        self.assertNotIn("PRIVATE-SERIAL-987", result["sink_ports_and_active_port"])
        self.assertFalse(result["test_tone_played"])
        self.assertFalse(result["microphone_recording_performed"])

    def test_browser_diagnostics_reports_ca_state_without_profile_data(self):
        collector = diag.DiagnosticsCollector(command_runner=lambda _argv:
            SimpleNamespace(returncode=0, stdout="Google Chrome 129.0\n", stderr=""))
        with patch.object(diag.shutil, "which", return_value="/usr/bin/google-chrome-stable"), \
             patch.object(diag.Path, "home", return_value=pathlib.Path("/tmp/diagnostic-test-home")), \
             patch("pathlib.Path.stat", side_effect=FileNotFoundError), \
             patch("pathlib.Path.is_file", return_value=False):
            result = collector._browser_diagnostics()
        self.assertTrue(result["browser"]["available"])
        self.assertEqual(result["browser"]["version"], "Google Chrome 129.0")
        self.assertFalse(result["system_ca_bundle"]["available"])
        self.assertFalse(result["browser_history_collected"])
        self.assertIsNone(result["atlasos_browser_launcher_log"])

    def test_sanitizer_redacts_url_queries_ssids_and_ipv6(self):
        text = diag.sanitize_text("url=https://example.com/path?token=abc#fragment ssid=SchoolNet gateway=fe80::1234")
        self.assertNotIn("token=abc", text)
        self.assertNotIn("SchoolNet", text)
        self.assertNotIn("fe80::1234", text)
        self.assertIn("[PATH/QUERY REDACTED]", text)

    def test_sanitizer_redacts_networkmanager_ssid_and_profile_log_formats(self):
        raw = "\n".join((
            "NetworkManager: Config: added 'ssid' value 'Fake Board Network Name'",
            "NetworkManager: device (wlan0): Activation: starting connection 'profile-id' (Fake Profile Name)",
            "NetworkManager: device (wlan0): Activation: (wifi) access point 'Fake Access Point' has security",
            'NetworkManager: device (wlan0): Activation successful. Connected to wireless network "Fake Connected Network"',
            'NetworkManager: audit: op="connection-add-activate" uuid=11111111-2222-3333-4444-555555555555 name="Fake Audit Profile"',
            'wpa_supplicant: wlan0: CTRL-EVENT-CONNECTED ssid="Fake WPA Network Name"',
            "wpa_supplicant: wlan0: SSID=Fake WPA Unquoted Network Name",
            "NetworkManager: device (wlan0): state change: config -> activated",
        ))
        sanitized = diag.sanitize_text(raw)
        for secret in (
            "Fake Board Network Name", "Fake Profile Name", "Fake Access Point",
            "Fake Connected Network", "Fake Audit Profile", "Fake WPA Network Name",
            "Fake WPA Unquoted Network Name",
        ):
            self.assertNotIn(secret, sanitized)
        self.assertIn("state change: config -> activated", sanitized)
        self.assertIn("Activation successful", sanitized)
        self.assertIn("ssid", sanitized)

    def test_sanitization_manifest_describes_ssid_and_profile_redaction(self):
        description = " ".join(diag.PRIVACY_RULES)
        self.assertIn("SSIDs and Wi-Fi profile names in supported log formats", description)

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
