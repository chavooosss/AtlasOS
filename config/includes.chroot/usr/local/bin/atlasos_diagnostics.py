#!/usr/bin/env python3
"""Read-only AtlasOS diagnostics with fail-closed removable-media export.

The collector never mounts storage and never opens a block device for writing.
Its only persistent write API creates one generated archive on a filesystem
whose removable USB ancestry and mount source have been revalidated.
"""
from __future__ import annotations

import errno
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import tempfile
import time
import zipfile
from datetime import datetime, timezone
from pathlib import Path

VERSION = "0.6.4"
FORBIDDEN_COMMANDS = {
    "mkfs", "mkfs.ext4", "mkfs.vfat", "wipefs", "fdisk", "sfdisk",
    "parted", "dd", "fio", "fsck", "ntfsfix", "resize2fs", "blkdiscard",
    "badblocks", "sgdisk", "gdisk", "nvme", "hdparm",
}
PRIVACY_RULES = [
    "Browser histories, cookies, passwords, tokens, profiles and page contents are not collected.",
    "Wi-Fi credentials, SSH keys, clipboard, home documents and personal files are not collected.",
    "Storage inventory reads device metadata only; filesystems are never traversed or mounted.",
    "Logs are bounded and sanitized for home paths, account IDs, MAC/IP addresses, URL query strings, SSIDs and Wi-Fi profile names in supported log formats, and credential-like values.",
    "Audio diagnostics record device/route state only; no test tone or microphone capture is performed.",
    "Network diagnostics use fixed HTTPS probes and record outcome codes only; no page body, browsing history, proxy value or credentials are stored.",
]
MAX_LOG_BYTES = 2 * 1024 * 1024
MAX_BUNDLE_BYTES = 24 * 1024 * 1024


def _read(path: Path, default=""):
    try:
        return path.read_text(encoding="utf-8", errors="replace").strip()
    except OSError:
        return default


def _json_default(value):
    return str(value)


def _unescape_mount(value: str) -> str:
    return re.sub(r"\\([0-7]{3})", lambda m: chr(int(m.group(1), 8)), value)


def sanitize_text(text: str) -> str:
    """Remove common personal identifiers while preserving driver evidence."""
    text = text[:MAX_LOG_BYTES]
    text = re.sub(r"/home/[^/\s]+", "/home/[USER]", text)
    text = re.sub(r"/run/user/\d+", "/run/user/[UID]", text)
    text = re.sub(r"(?i)(https?://)[^/@\s]+:[^/@\s]+@", r"\1[REDACTED]@", text)
    text = re.sub(r"(?i)(https?://[^/\s?#]+)(?:/[^\s?#]*)?(?:\?[^\s#]*)?(?:#[^\s]*)?", r"\1/[PATH/QUERY REDACTED]", text)
    text = re.sub(r"(?i)(password|passwd|psk|token|cookie|secret|username|user|account|_uid|uid)(\s*[=:]\s*)\S+", r"\1\2[REDACTED]", text)
    # NetworkManager journal lines can carry the SSID as a quoted value after
    # the quoted key ("added 'ssid' value '...'"), not as ssid=... . Mask the
    # complete value, including spaces, before applying the general key form.
    text = re.sub(r"(?i)(\bssid\b['\"]?\s+value\s+)(['\"])(.*?)\2", r"\1\2[REDACTED]\2", text)
    # Unquoted key/value forms have no reliable delimiter for SSIDs containing
    # spaces; redact the rest of that log line rather than leak a suffix.
    text = re.sub(r"(?i)(\bssid\s*(?:[=:]\s*|\s+))(?:(['\"])(.*?)\2|[^\r\n]*)", r"\1[REDACTED]", text)
    # NM also logs the network/profile name outside an explicit SSID field.
    text = re.sub(r"(?i)(\baccess point\s+)(['\"])(.*?)\2", r"\1\2[REDACTED]\2", text)
    text = re.sub(r"(?i)(\bconnected to wireless network\s+)(['\"])(.*?)\2", r"\1\2[REDACTED]\2", text)
    text = re.sub(r"(?im)(^.*NetworkManager[^\r\n]*\bop=\"connection-[^\"]+\"[^\r\n]*\bname=)(['\"])(.*?)\2", r"\1\2[REDACTED]\2", text)
    text = re.sub(r"(?im)(^.*NetworkManager[^\r\n]*Activation:\s+starting connection\s+['\"][^'\"]+['\"]\s+\()([^)]*)(\))", r"\1[REDACTED]\3", text)
    text = re.sub(r"(?i)\b(connection|profile)\s+(['\"])[^'\"]+\2", r"\1 [REDACTED]", text)
    text = re.sub(r"\b(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}\b", "[MAC]", text)
    text = re.sub(r"\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b", "[IP]", text)
    text = re.sub(r"(?i)\b(?:[0-9a-f]{0,4}:){2,}[0-9a-f]{0,4}\b", "[IPV6]", text)
    text = re.sub(r"\b[0-9a-fA-F]{8}-[0-9a-fA-F-]{27,}\b", "[UUID]", text)
    return text


class StorageSafetyPolicy:
    """Classify block-backed mounts and authorize exports only to verified USB.

    `sys_root` and `mountinfo_path` are injectable for unit tests. Production
    callers use the real kernel sysfs and `/proc/self/mountinfo`.
    """
    LIVE_BOOT_MEDIA = "LIVE_BOOT_MEDIA"
    REMOVABLE_EXPORT_MEDIA = "REMOVABLE_EXPORT_MEDIA"
    INTERNAL_PROTECTED = "INTERNAL_PROTECTED"
    UNKNOWN_PROTECTED = "UNKNOWN_PROTECTED"

    def __init__(self, sys_root="/sys", mountinfo_path="/proc/self/mountinfo", cmdline_path="/proc/cmdline"):
        self.sys_root = Path(sys_root)
        self.mountinfo_path = Path(mountinfo_path)
        self.cmdline_path = Path(cmdline_path)

    def _block_entries(self):
        result = {}
        for item in (self.sys_root / "class/block").glob("*"):
            try:
                real = item.resolve(strict=True)
                dev = _read(item / "dev")
                if not dev:
                    continue
                size = int(_read(item / "size", "0")) * 512
                removable = _read(item / "removable") == "1"
                is_partition = (item / "partition").exists()
                usb_ancestor = bool(re.search(r"(?:^|/)usb\d+/\d+-[\d.]+(?:/|$)", str(real)))
                result[dev] = {
                    "name": item.name, "path": str(real), "bytes": size,
                    "removable": removable, "partition": is_partition,
                    "usb_ancestor": usb_ancestor,
                    "parent": self._parent_dev(real),
                }
            except (OSError, ValueError, RuntimeError):
                continue
        return result

    @staticmethod
    def _parent_dev(real: Path):
        if (real / "partition").exists():
            try:
                return (real.parent / "dev").read_text().strip()
            except OSError:
                pass
        for parent in real.parents:
            part = parent / "partition"
            dev = parent / "dev"
            if part.exists():
                try:
                    return dev.read_text().strip()
                except OSError:
                    pass
        return None

    def _mounts(self):
        mounts = []
        for line in _read(self.mountinfo_path).splitlines():
            fields = line.split()
            try:
                separator = fields.index("-")
                mounts.append({
                    "id": fields[0], "major_minor": fields[2],
                    "root": _unescape_mount(fields[3]), "mountpoint": _unescape_mount(fields[4]),
                    "options": fields[5].split(","), "fstype": fields[separator + 1],
                    "source": _unescape_mount(fields[separator + 2]),
                })
            except (ValueError, IndexError):
                continue
        return mounts

    def _resolve_device_number(self, source: str, entries):
        if source.startswith("/dev/"):
            try:
                resolved = Path(source).resolve(strict=True)
                dev_file = self.sys_root / "class/block" / resolved.name / "dev"
                value = dev_file.read_text().strip()
                if value in entries:
                    return value
            except OSError:
                pass
        return None

    def _live_dev_numbers(self, entries, mounts):
        found = set()
        for mount in mounts:
            if mount["mountpoint"] in {"/run/live/medium", "/lib/live/mount/medium", "/cdrom"}:
                if mount["major_minor"] in entries:
                    found.add(mount["major_minor"])
        cmdline = _read(self.cmdline_path)
        match = re.search(r"(?:^|\s)live-media=(/dev/\S+)", cmdline)
        if match:
            number = self._resolve_device_number(match.group(1), entries)
            if number:
                found.add(number)
        return found

    def _same_physical_device(self, dev_number, live_numbers, entries):
        current = dev_number
        seen = set()
        while current and current not in seen:
            if current in live_numbers:
                return True
            seen.add(current)
            entry = entries.get(current)
            current = entry.get("parent") if entry else None
        return False

    def classify(self, major_minor: str, entries=None, live_numbers=None):
        entries = entries if entries is not None else self._block_entries()
        mounts = self._mounts()
        live_numbers = live_numbers if live_numbers is not None else self._live_dev_numbers(entries, mounts)
        entry = entries.get(major_minor)
        if not entry:
            return self.UNKNOWN_PROTECTED
        if self._same_physical_device(major_minor, live_numbers, entries):
            return self.LIVE_BOOT_MEDIA
        # The removable bit alone can identify an internal card reader or optical
        # drive. Export authorization therefore requires a proven USB ancestry.
        if entry["usb_ancestor"]:
            return self.REMOVABLE_EXPORT_MEDIA
        return self.INTERNAL_PROTECTED

    def inventory(self):
        entries = self._block_entries()
        mounts = self._mounts()
        live_numbers = self._live_dev_numbers(entries, mounts)
        mounted_by_dev = {}
        for mount in mounts:
            mounted_by_dev.setdefault(mount["major_minor"], []).append(mount["mountpoint"])
        result = []
        for number, entry in sorted(entries.items(), key=lambda pair: pair[1]["name"]):
            classification = self.classify(number, entries, live_numbers)
            result.append({
                "device": entry["name"], "major_minor": number, "size_bytes": entry["bytes"],
                "partition": entry["partition"], "class": classification,
                "mountpoints": [sanitize_text(path) for path in mounted_by_dev.get(number, [])],
                "write_policy": "EXPORT_ONLY" if classification == self.REMOVABLE_EXPORT_MEDIA else "PROTECTED",
            })
        return {"devices": result, "live_source": sorted(live_numbers) or None,
                "internal_storage_policy": "READ_ONLY_PROTECTED", "unknown_policy": "PROTECTED"}

    def export_targets(self):
        entries = self._block_entries()
        mounts = self._mounts()
        live_numbers = self._live_dev_numbers(entries, mounts)
        # If the running boot medium cannot be identified, a candidate USB
        # cannot be proven to be a separate export drive. Fail closed.
        if not live_numbers:
            return []
        targets = []
        for mount in mounts:
            if mount["major_minor"] not in entries:
                continue
            if self.classify(mount["major_minor"], entries, live_numbers) != self.REMOVABLE_EXPORT_MEDIA:
                continue
            if mount["root"] != "/" or "rw" not in mount["options"]:
                continue
            point = Path(mount["mountpoint"])
            if not point.is_dir() or self._path_has_symlink(point):
                continue
            targets.append({"id": mount["id"], "mountpoint": str(point), "device": entries[mount["major_minor"]]["name"],
                            "size_bytes": entries[mount["major_minor"]]["bytes"], "class": self.REMOVABLE_EXPORT_MEDIA})
        return targets

    @staticmethod
    def _path_has_symlink(path: Path):
        current = Path(path.anchor)
        for part in path.parts[1:]:
            current = current / part
            try:
                if stat.S_ISLNK(current.lstat().st_mode):
                    return True
            except OSError:
                return True
        return False

    def authorize_destination(self, destination: str, expected_mount_id=None):
        raw = Path(destination)
        if not raw.is_absolute() or ".." in raw.parts or self._path_has_symlink(raw):
            raise PermissionError("Hedef yol doğrulanamadı; sembolik bağlantı ve yol geçişi reddedildi.")
        resolved = raw.resolve(strict=True)
        mounts = self._mounts()
        applicable = []
        for mount in mounts:
            try:
                point = Path(mount["mountpoint"])
                if resolved == point or point in resolved.parents:
                    applicable.append(mount)
            except (OSError, RuntimeError):
                continue
        if not applicable:
            raise PermissionError("Hedefin block aygıtı doğrulanamadı; dışa aktarma reddedildi.")
        mount = max(applicable, key=lambda item: len(Path(item["mountpoint"]).parts))
        if expected_mount_id is not None and mount["id"] != str(expected_mount_id):
            raise PermissionError("USB bağlantısı veya hedef mount değişti; dışa aktarma reddedildi.")
        if resolved != Path(mount["mountpoint"]):
            raise PermissionError("Dışa aktarma yalnızca doğrulanmış USB mount köküne yapılabilir.")
        if mount["root"] != "/":
            raise PermissionError("Bind mount veya alt dosya sistemi güvenli dışa aktarma hedefi değil.")
        entries = self._block_entries()
        live_numbers = self._live_dev_numbers(entries, mounts)
        if not live_numbers:
            raise PermissionError("Live boot kaynağı doğrulanamadı; hiçbir USB dışa aktarım hedefi olarak kullanılamaz.")
        classification = self.classify(mount["major_minor"], entries, live_numbers)
        if classification != self.REMOVABLE_EXPORT_MEDIA:
            if classification == self.INTERNAL_PROTECTED:
                raise PermissionError("Bu konum dahili depolama aygıtında. Güvenlik nedeniyle yazma reddedildi.")
            raise PermissionError("Hedef aygıtın çıkarılabilir USB olduğu doğrulanamadı; yazma reddedildi.")
        if "rw" not in mount["options"]:
            raise PermissionError("USB salt okunur bağlı; dışa aktarma reddedildi.")
        return mount

    def export(self, archive: Path, destination: str, expected_mount_id=None):
        # Pin and validate the source archive once; the bytes copied below come
        # from this same open regular-file descriptor.
        archive_flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
        archive_fd = os.open(archive, archive_flags)
        try:
            archive_stat = os.fstat(archive_fd)
            if not stat.S_ISREG(archive_stat.st_mode) or archive_stat.st_size <= 0 or archive_stat.st_size > MAX_BUNDLE_BYTES:
                raise ValueError("Tanılama paketi geçersiz veya boyut sınırını aşıyor.")
            try:
                with os.fdopen(os.dup(archive_fd), "rb", closefd=True) as source_validation:
                    self._validate_bundle_stream(source_validation)
            except (zipfile.BadZipFile, EOFError) as exc:
                raise ValueError("Tanılama paketi geçerli bir ZIP arşivi değil.") from exc
            os.lseek(archive_fd, 0, os.SEEK_SET)

            mount = self.authorize_destination(destination, expected_mount_id)
            target_dir = Path(destination)
            usage = shutil.disk_usage(target_dir)
            if usage.free < archive_stat.st_size + 1024 * 1024:
                raise OSError("USB bellekte tanılama paketi için yeterli boş alan yok.")
            name = Path(archive).name
            if not re.fullmatch(rf"AtlasOS-Diagnostics-{re.escape(VERSION)}-[0-9TZ-]+\.zip", name):
                raise ValueError("Yalnızca oluşturulmuş AtlasOS tanılama arşivleri dışa aktarılabilir.")

            dir_flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
            dir_fd = os.open(target_dir, dir_flags)
            file_fd = None
            created = False
            complete = False
            try:
                self.authorize_destination(destination, mount["id"])
                # O_EXCL atomically reserves the final name on ordinary Linux
                # filesystems including FAT/exFAT implementations that lack
                # O_TMPFILE or linkat(AT_EMPTY_PATH). No rename/replace fallback
                # is used. The file stays open by descriptor for all writes and
                # validation; only this owned inode is ever truncated on error.
                flags = os.O_RDWR | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
                file_fd = os.open(name, flags, 0o600, dir_fd=dir_fd)
                created = True

                source_digest = hashlib.sha256()
                copied = 0
                with os.fdopen(os.dup(archive_fd), "rb", closefd=True) as source:
                    while True:
                        self.authorize_destination(destination, mount["id"])
                        chunk = source.read(1024 * 1024)
                        if not chunk:
                            break
                        source_digest.update(chunk)
                        view = memoryview(chunk)
                        while view:
                            written = os.write(file_fd, view)
                            if written <= 0:
                                raise OSError("Tanılama paketi USB belleğe tam yazılamadı.")
                            copied += written
                            view = view[written:]
                if copied != archive_stat.st_size:
                    raise OSError("Tanılama paketi USB belleğe eksik aktarıldı.")
                os.fsync(file_fd)

                os.lseek(file_fd, 0, os.SEEK_SET)
                copied_digest = hashlib.sha256()
                with os.fdopen(os.dup(file_fd), "rb", closefd=True) as copied_file:
                    while True:
                        chunk = copied_file.read(1024 * 1024)
                        if not chunk:
                            break
                        copied_digest.update(chunk)
                    if copied_digest.digest() != source_digest.digest():
                        raise OSError("USB kopyası kaynak tanılama paketiyle eşleşmiyor.")
                    copied_file.seek(0)
                    try:
                        self._validate_bundle_stream(copied_file)
                    except (zipfile.BadZipFile, EOFError) as exc:
                        raise ValueError("USB kopyası geçerli bir ZIP arşivi değil.") from exc

                opened_stat = os.fstat(file_fd)
                named_stat = os.stat(name, dir_fd=dir_fd, follow_symlinks=False)
                if (not stat.S_ISREG(named_stat.st_mode) or opened_stat.st_nlink < 1
                        or (opened_stat.st_dev, opened_stat.st_ino) != (named_stat.st_dev, named_stat.st_ino)):
                    raise OSError("USB hedef girdisi aktarım sırasında değişti; dışa aktarma başarılı sayılmadı.")
                complete = True
                try:
                    self.authorize_destination(destination, mount["id"])
                except Exception as exc:
                    raise OSError("Tanılama paketi doğrulandı ve USB dosyasına yazıldı ancak son mount doğrulaması başarısız oldu; final dosya silinmedi. USB içeriğini kontrol edin.") from exc
                try:
                    os.fsync(dir_fd)
                except OSError as exc:
                    # Some removable filesystems reject directory fsync even
                    # after the file itself has been synced and validated.
                    if exc.errno not in (errno.EINVAL, errno.ENOTSUP, errno.EOPNOTSUPP):
                        raise
                return str(target_dir / name)
            except Exception as primary_error:
                cleanup_errors = []
                if created and file_fd is not None and not complete:
                    try:
                        os.ftruncate(file_fd, 0)
                    except OSError as exc:
                        cleanup_errors.append(f"truncate: {exc}")
                    try:
                        os.fsync(file_fd)
                    except OSError as exc:
                        cleanup_errors.append(f"flush: {exc}")
                    try:
                        os.close(file_fd)
                    except OSError as exc:
                        cleanup_errors.append(f"close: {exc}")
                    file_fd = None
                    if cleanup_errors:
                        detail = "; ".join(cleanup_errors)
                        raise OSError(
                            f"{primary_error} Export failed; an empty or incomplete file named {name} may remain on the USB because cleanup failed ({detail}). No pathname-based deletion was attempted."
                        ) from primary_error
                    raise OSError(
                        f"{primary_error} Export failed; an empty file named {name} remains on the USB. It was not reported as a successful archive and was not removed by pathname."
                    ) from primary_error
                raise
            finally:
                if file_fd is not None:
                    try:
                        os.close(file_fd)
                    except OSError as exc:
                        if complete:
                            raise OSError(
                                exc.errno, "Tanılama paketi doğrulandı ve yazıldı ancak dosya tanıtıcısı kapatılamadı; dosya silinmedi. USB içeriğini kontrol edin.", str(target_dir / name)
                            ) from exc
                try:
                    os.close(dir_fd)
                except OSError as exc:
                    if complete:
                        raise OSError(
                            exc.errno, "Tanılama paketi doğrulandı ve yazıldı ancak hedef dizin tanıtıcısı kapatılamadı; dosya silinmedi.", str(target_dir / name)
                        ) from exc
        finally:
            os.close(archive_fd)

    @staticmethod
    def _validate_bundle_stream(stream):
        stream.seek(0)
        with zipfile.ZipFile(stream, "r") as bundle:
            infos = bundle.infolist()
            names = {info.filename for info in infos}
            required = {"README.txt", "summary.json", "collection/manifest.json"}
            if not required.issubset(names) or sum(info.file_size for info in infos) > MAX_BUNDLE_BYTES:
                raise ValueError("Tanılama ZIP içeriği eksik veya boyut sınırını aşıyor.")
            bad_member = bundle.testzip()
            if bad_member is not None:
                raise ValueError("Tanılama ZIP içeriği bozuk.")
        stream.seek(0)

    @classmethod
    def _validate_bundle(cls, archive: Path):
        try:
            with archive.open("rb") as stream:
                cls._validate_bundle_stream(stream)
        except (OSError, zipfile.BadZipFile, EOFError) as exc:
            raise ValueError("Tanılama arşivi boş veya okunamıyor.") from exc


class DiagnosticsCollector:
    COMMANDS = {
        "dmesg": ("dmesg", "--time-format=iso"),
        "journal_current": ("journalctl", "--no-pager", "--output=short-monotonic", "--boot", "0"),
        "journal_previous": ("journalctl", "--no-pager", "--output=short-monotonic", "--boot", "-1"),
        "lspci": ("lspci", "-nnk"),
        "modules": ("lsmod",),
        "xrandr": ("xrandr", "--query"),
        "systemd_analyze": ("systemd-analyze", "blame"),
        "critical_chain": ("systemd-analyze", "critical-chain", "graphical.target"),
        "network_devices": ("nmcli", "-t", "--escape", "no", "-f", "DEVICE,TYPE,STATE", "device", "status"),
        "network_route": ("ip", "route", "show", "default"),
        "network_connectivity": ("nmcli", "networking", "connectivity", "check"),
        "desktop_proxy_mode": ("gsettings", "get", "org.gnome.system.proxy", "mode"),
        "pipewire_version": ("pw-play", "--version"),
        "wpctl_volume": ("wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"),
        "wpctl_inspect": ("wpctl", "inspect", "@DEFAULT_AUDIO_SINK@"),
        "pactl_sinks": ("pactl", "list", "short", "sinks"),
        "pactl_cards": ("pactl", "list", "cards"),
        "pactl_full_sinks": ("pactl", "list", "sinks"),
        "time_sync_status": ("timedatectl", "show", "--property=Timezone", "--property=NTPSynchronized", "--property=NTP", "--property=LocalRTC", "--property=TimeUSec"),
        "chrony_tracking": ("chronyc", "tracking"),
        "chrony_sources": ("chronyc", "sources", "-v"),
        "alsa_playback_devices": ("aplay", "-l"),
        "audio_journal": ("journalctl", "--user", "--no-pager", "--output=short-monotonic", "--since=-15min", "-u", "pipewire", "-u", "pipewire-pulse", "-u", "wireplumber"),
    }
    PRIVILEGED_BOOT_COMMAND = (
        "/usr/bin/sudo", "-n", "--", "/usr/local/libexec/atlasos-privileged-diagnostics",
    )

    def __init__(self, sys_root="/sys", proc_root="/proc", run_root="/run", command_runner=None,
                 mountinfo_path="/proc/self/mountinfo", volatile_root=None):
        self.sys_root = Path(sys_root)
        self.proc_root = Path(proc_root)
        self.run_root = Path(run_root)
        self.volatile_root = Path(volatile_root) if volatile_root else None
        self.command_runner = command_runner or self._run_command
        self.storage = StorageSafetyPolicy(sys_root, mountinfo_path, self.proc_root / "cmdline")
        self.errors = []

    @staticmethod
    def _run_command(argv, timeout=8):
        if not argv or Path(argv[0]).name in FORBIDDEN_COMMANDS:
            raise PermissionError("Collector command is not allowed.")
        if tuple(argv) == DiagnosticsCollector.PRIVILEGED_BOOT_COMMAND:
            timeout = 45
        return subprocess.run(list(argv), stdin=subprocess.DEVNULL, capture_output=True, text=True,
                              timeout=timeout, check=False, shell=False, env={**os.environ, "LC_ALL": "C"})

    def _collect_command(self, key):
        argv = self.COMMANDS[key]
        try:
            result = self.command_runner(argv)
            if result.returncode:
                self.errors.append({"collector": key, "error": "Unavailable or access denied", "returncode": result.returncode})
            return sanitize_text((result.stdout or "") + ("\n[stderr]\n" + result.stderr if result.stderr else ""))
        except (OSError, subprocess.TimeoutExpired, PermissionError) as exc:
            self.errors.append({"collector": key, "error": type(exc).__name__})
            return "Mevcut değil: " + type(exc).__name__

    def cpu_snapshot(self):
        cpuinfo = _read(self.proc_root / "cpuinfo")
        model = next((line.split(":", 1)[1].strip() for line in cpuinfo.splitlines() if line.lower().startswith("model name")), None)
        processors = sum(line.startswith("processor\t:") for line in cpuinfo.splitlines())
        def counters():
            first = _read(self.proc_root / "stat").splitlines()
            values = first[0].split()[1:] if first and first[0].startswith("cpu ") else []
            try:
                values = [int(value) for value in values]
                return (sum(values), values[3] + (values[4] if len(values) > 4 else 0))
            except (ValueError, IndexError):
                return None
        previous = counters()
        samples = []
        for _ in range(3):
            time.sleep(0.2)
            current = counters()
            if previous and current and current[0] > previous[0]:
                usage = 100.0 * (1.0 - (current[1] - previous[1]) / (current[0] - previous[0]))
                samples.append(max(0.0, min(100.0, usage)))
            previous = current
        return {"model": model, "logical_processors": processors or None,
                "usage_percent_average": round(sum(samples) / len(samples), 1) if samples else None,
                "usage_percent_peak": round(max(samples), 1) if samples else None,
                "sample_window_seconds": round(0.2 * len(samples), 1) if samples else None}

    def memory_snapshot(self):
        values = {}
        for line in _read(self.proc_root / "meminfo").splitlines():
            match = re.match(r"^(MemTotal|MemAvailable|SwapTotal|SwapFree):\s+(\d+)\s+kB", line)
            if match:
                values[match.group(1)] = int(match.group(2)) * 1024
        total = values.get("MemTotal")
        available = values.get("MemAvailable")
        return {"total_bytes": total, "available_bytes": available,
                "used_bytes": total - available if total is not None and available is not None else None,
                "swap_total_bytes": values.get("SwapTotal"), "swap_free_bytes": values.get("SwapFree")}

    def process_snapshot(self):
        def total_ticks():
            lines = _read(self.proc_root / "stat").splitlines()
            try:
                return sum(int(value) for value in lines[0].split()[1:]) if lines and lines[0].startswith("cpu ") else None
            except ValueError:
                return None

        def sample():
            found = {}
            for item in self.proc_root.glob("[0-9]*"):
                if not item.name.isdigit():
                    continue
                try:
                    statline = _read(item / "stat")
                    close = statline.rfind(")")
                    fields = statline[close + 2:].split()
                    ticks = int(fields[11]) + int(fields[12])
                    name = _read(item / "comm")
                    status = _read(item / "status")
                    rss = next((int(line.split()[1]) * 1024 for line in status.splitlines() if line.startswith("VmRSS:")), None)
                    found[item.name] = {"name": name, "rss_bytes": rss, "cpu_ticks": ticks}
                except (OSError, ValueError, IndexError):
                    continue
            return found

        total_before = total_ticks()
        before = sample()
        time.sleep(0.2)
        total_after = total_ticks()
        after = sample()
        cpu = []
        memory = []
        total_delta = (total_after - total_before) if total_before is not None and total_after is not None else 0
        cores = os.cpu_count() or 1
        for pid, current in after.items():
            previous = before.get(pid)
            delta = current["cpu_ticks"] - previous["cpu_ticks"] if previous else 0
            current["cpu_percent"] = round(100 * delta * cores / total_delta, 1) if total_delta > 0 else None
            current.pop("cpu_ticks", None)
            cpu.append(current)
            memory.append(current)
        cpu.sort(key=lambda value: value["cpu_percent"] or 0, reverse=True)
        memory.sort(key=lambda value: value["rss_bytes"] or 0, reverse=True)
        return {"top_cpu": cpu[:20], "top_memory": memory[:20],
                "atlas_processes": [item for item in after.values() if item["name"] in {"atlasos-ui", "xfwm4", "Xorg"}]}

    def system_snapshot(self):
        cpu = self.cpu_snapshot()
        memory = self.memory_snapshot()
        try:
            uptime = float(_read(self.proc_root / "uptime").split()[0])
        except (ValueError, IndexError):
            uptime = None
        release = {}
        for line in _read(Path("/etc/os-release")).splitlines():
            if "=" in line:
                key, value = line.split("=", 1)
                if key in {"PRETTY_NAME", "VERSION_ID"}:
                    release[key] = value.strip('"')
        graphics = []
        for card in (self.sys_root / "class/drm").glob("card[0-9]*"):
            if "-" in card.name:
                continue
            try:
                driver = (card / "device/driver").resolve(strict=True).name
            except OSError:
                driver = None
            graphics.append({"device": card.name, "driver": driver,
                             "pci_vendor_id": _read(card / "device/vendor", None),
                             "pci_device_id": _read(card / "device/device", None)})
        connectors = []
        for connector in (self.sys_root / "class/drm").glob("card[0-9]*-*" ):
            state = _read(connector / "status", None)
            mode_lines = _read(connector / "modes").splitlines()
            if state:
                connectors.append({"connector": connector.name, "status": state,
                                   "modes": mode_lines[:20]})
        framebuffer_size = None
        virtual_size = _read(self.sys_root / "class/graphics/fb0/virtual_size")
        if re.fullmatch(r"\d+,\d+", virtual_size):
            framebuffer_size = virtual_size.replace(",", " × ")
        network = []
        for interface in (self.sys_root / "class/net").glob("*"):
            if interface.name == "lo":
                continue
            network.append({"interface": interface.name, "state": _read(interface / "operstate", "unknown")})
        temperatures = []
        for zone in (self.sys_root / "class/thermal").glob("thermal_zone*"):
            try:
                temperatures.append({"zone": zone.name, "millidegrees_c": int(_read(zone / "temp"))})
            except ValueError:
                pass
        cmdline = sanitize_text(_read(self.proc_root / "cmdline"))
        kernel = _read(self.proc_root / "sys/kernel/osrelease", None)
        atlas_ui_running = None
        try:
            process_entries = [item for item in self.proc_root.glob("[0-9]*") if item.name.isdigit()]
            atlas_ui_running = any(
                _read(item / "comm") == "atlasos-ui"
                or any(Path(argument).name == "atlasos-ui" for argument in _read(item / "cmdline").split("\0"))
                for item in process_entries
            )
        except OSError:
            pass
        storage = self.storage.inventory()
        live_ids = set(storage.get("live_source") or [])
        live_devices = [item["device"] for item in storage["devices"] if item["major_minor"] in live_ids]
        return {"atlas_version": VERSION, "os": release, "kernel": kernel, "uptime_seconds": uptime,
                "cpu": cpu, "memory": memory, "gpu": graphics or None, "graphics_driver": graphics[0]["driver"] if graphics else None,
                "display": {"resolution": framebuffer_size, "connection": connectors or None,
                            "session": os.environ.get("XDG_SESSION_TYPE")},
                "network": network, "temperature": temperatures or None,
                "atlas_ui": {"process": "atlasos-ui", "running": atlas_ui_running},
                "boot_source": {"state": "DETECTED", "devices": live_devices} if live_devices else {"state": "UNKNOWN", "devices": None}, "storage": storage,
                "load_average": _read(self.proc_root / "loadavg", None), "kernel_cmdline": cmdline}

    @staticmethod
    def _timeline_timestamp(line):
        match = re.match(r"^\[\s*(\d+(?:\.\d+)?)\]", line)
        if match:
            return {"seconds_since_boot": float(match.group(1)), "wall_clock_timestamp": None,
                    "timestamp_kind": "monotonic"}
        match = re.match(r"^\[([^\]]*(?:19|20)\d{2}[^\]]*)\]", line)
        if match:
            return {"seconds_since_boot": None, "wall_clock_timestamp": match.group(1).strip(),
                    "timestamp_kind": "wall_clock"}
        return {"seconds_since_boot": None, "wall_clock_timestamp": None, "timestamp_kind": None}

    def _boot_timeline(self, sources):
        # Match concrete messages from the physical journals. Never merge
        # previous-boot or systemd-analyze output into the current boot clock.
        patterns = {
            "kernel_start": re.compile(r"\bLinux version \d", re.I),
            "framebuffer_or_simpledrm": re.compile(
                r"(?:simpledrm.*(?:initialized|registered)|initialized simpledrm|"
                r"simple-framebuffer.*(?:framebuffer|registered)|fb0:.*frame buffer device)", re.I),
            "native_drm_init": re.compile(
                r"\[drm\].*initialized (?:i915|amdgpu|nouveau|xe)\b|"
                r"\b(?:i915|amdgpu|nouveau|xe)\b.*\binitialized\b", re.I),
            "fbcon_takeover": re.compile(
                r"fbcon:.*(?:taking over|switching|is primary device|primary device)", re.I),
            "plymouth_start": re.compile(
                r"(?:starting|started) plymouth(?:d)?(?:[-\w]*\.service)?\b", re.I),
            "display_manager_start": re.compile(
                r"(?:starting|started) (?:lightdm|display-manager)(?:\.service)?\b|"
                r"lightdm[^\n]*\bstarting\b", re.I),
            "xorg_start": re.compile(
                r"comm=\"Xorg\.wrap\"|\bX\.Org X Server\b|\bXorg\b[^\n]*\b(?:started|starting)\b", re.I),
            "atlas_session_start": re.compile(
                r"session opened for user atlas\b|\batlasos-session(?:\s|$)", re.I),
            "atlas_ui_start": re.compile(
                r"comm=\"atlasos-ui\"|/usr/local/bin/atlasos-ui(?:\s|$)|"
                r"(?:starting|started) atlasos-ui(?:\.service)?\b", re.I),
        }
        candidates = {key: [] for key in patterns}
        for source_name in ("dmesg", "journal_current"):
            for line in (sources.get(source_name) or "").splitlines():
                stamp = self._timeline_timestamp(line)
                for key, pattern in patterns.items():
                    if pattern.search(line):
                        candidates[key].append({**stamp, "source": source_name, "event": line.strip()[:240]})

        timeline = {}
        for key, matches in candidates.items():
            monotonic = [item for item in matches if item["seconds_since_boot"] is not None]
            if monotonic:
                chosen = min(monotonic, key=lambda item: item["seconds_since_boot"])
            elif matches:
                chosen = matches[0]
            else:
                chosen = {"seconds_since_boot": None, "wall_clock_timestamp": None,
                          "timestamp_kind": None, "source": None, "event": None}
            timeline[key] = chosen
        return {"events": timeline, "timestamps_are_exact": True,
                "note": "Only timestamps present in current-boot source lines are retained; wall-clock values are never converted to monotonic time."}

    @staticmethod
    def _curl_category(returncode):
        return {
            5: "proxy", 6: "dns", 7: "connection", 28: "timeout",
            35: "tls_handshake", 51: "certificate", 56: "connection_reset_or_interrupted",
            58: "tls_client_certificate", 60: "certificate", 77: "ca_store",
            97: "proxy",
        }.get(returncode, "ok" if returncode == 0 else "other")

    def _https_probe(self, label, host):
        # Fixed destinations only; strict curl certificate validation remains on.
        # Verbose output is parsed in memory and never written raw to the bundle.
        url = f"https://{host}/"
        argv = ("curl", "--verbose", "--silent", "--show-error", "--head",
                "--location", "--max-redirs", "3", "--connect-timeout", "2",
                "--max-time", "6", "--output", "/dev/null", "--write-out",
                "%{http_code}|%{ssl_verify_result}", "--", url)
        record = {"label": label, "host": host, "tool": "curl", "tls_verification": "enabled"}
        try:
            result = self.command_runner(argv)
            fields = (result.stdout or "").strip().split("|", 1)
            record["http_status"] = fields[0] if fields and fields[0].isdigit() else None
            try:
                record["tls_verify_result"] = int(fields[1]) if len(fields) > 1 else None
            except ValueError:
                record["tls_verify_result"] = None
            record["curl_exit"] = int(result.returncode)
            record["category"] = self._curl_category(record["curl_exit"])
            if record["curl_exit"] == 0 and record["tls_verify_result"] == 0:
                record["category"] = "verified"
            issuer = re.search(r"(?im)^\s*\*\s+issuer:\s*(.+)$", result.stderr or "")
            record["presented_issuer"] = sanitize_text(issuer.group(1).strip())[:180] if issuer else None
        except (OSError, subprocess.TimeoutExpired, PermissionError) as exc:
            record.update({"curl_exit": None, "tls_verify_result": None,
                           "category": "unavailable" if isinstance(exc, FileNotFoundError) else type(exc).__name__,
                           "presented_issuer": None})
            self.errors.append({"collector": "https_probe:" + label, "error": type(exc).__name__})
        return record

    def _network_diagnostics(self, progress=None):
        devices = self._collect_command("network_devices")
        route = self._collect_command("network_route")
        connectivity = self._collect_command("network_connectivity")
        desktop_proxy_mode = self._collect_command("desktop_proxy_mode")
        proxies_present = any(os.environ.get(name) for name in
                              ("http_proxy", "https_proxy", "all_proxy", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY"))
        probe_targets = (
            ("atlasos_site", "chavooosss.github.io"),
            ("independent_control", "example.com"),
            ("eba", "www.eba.gov.tr"),
            ("ogm_material", "ogmmateryal.eba.gov.tr"),
            ("mebi", "mebi.eba.gov.tr"),
        )
        probes = []
        for index, (label, host) in enumerate(probe_targets):
            if progress:
                progress(f"HTTPS bağlantısı kontrol ediliyor: {label}", 94 + index)
            probes.append(self._https_probe(label, host))
        return {
            "networkmanager_device_status": devices[:12000],
            "default_route_summary": route[:4000],
            "networkmanager_connectivity_check": connectivity[:1000],
            "desktop_proxy_mode": desktop_proxy_mode[:500],
            "proxy_environment_configured": proxies_present,
            "probes": probes,
            "limitations": [
                "curl probes are not Chrome navigation and can use a different certificate store.",
                "Only fixed public hosts are tested; school-specific TLS interception needs a test against the affected school URL.",
                "No proxy values, URL paths, query strings, response bodies, DNS answers or browser history are collected.",
            ],
        }

    @staticmethod
    def _filter_audio_inspection(text):
        allowed = re.compile(
            r"^\s*(?:id|node\.(?:name|description|state)|media\.class|device\.(?:api|name|description|profile\.name)|"
            r"api\.alsa\.(?:card|card\.name|path)|audio\.(?:channels|rate))\s*=\s*.*$"
        )
        return "\n".join(sanitize_text(line) for line in text.splitlines() if allowed.match(line))[:12000]

    @staticmethod
    def _filter_audio_cards(text):
        kept = []
        section = None
        for line in text.splitlines():
            stripped = line.strip()
            if re.match(r"^(?:Card|Sink) #\d+$", stripped):
                kept.append(stripped)
                section = None
            elif re.match(r"^(Name|Description|Active Profile|Active Port):\s*", stripped):
                kept.append(sanitize_text(stripped))
                section = None
            elif stripped in ("Profiles:", "Ports:"):
                section = stripped[:-1].lower()
                kept.append(stripped)
            elif section in ("profiles", "ports") and "available:" in stripped.lower():
                if re.match(r"^[^:]+:.+available:\s*(yes|no|unknown)", stripped, re.I):
                    kept.append(sanitize_text(stripped))
            elif not stripped:
                section = None
        return "\n".join(kept)[:12000]

    def _audio_diagnostics(self):
        services = {}
        for unit in ("pipewire.service", "pipewire-pulse.service", "wireplumber.service"):
            try:
                result = self.command_runner(("systemctl", "--user", "is-active", unit))
                services[unit] = result.stdout.strip() if result.returncode == 0 else "inactive_or_unavailable"
            except (OSError, subprocess.TimeoutExpired, PermissionError) as exc:
                services[unit] = "unavailable:" + type(exc).__name__
        volume = self._collect_command("wpctl_volume")
        inspection_raw = self._collect_command("wpctl_inspect")
        inspection = self._filter_audio_inspection(inspection_raw)
        sinks = self._collect_command("pactl_sinks")
        cards_raw = self._collect_command("pactl_cards")
        cards = self._filter_audio_cards(cards_raw)
        sinks_raw = self._collect_command("pactl_full_sinks")
        sink_ports = self._filter_audio_cards(sinks_raw)
        alsa = self._collect_command("alsa_playback_devices")
        alsa_cards = []
        cards_text = _read(self.proc_root / "asound/cards")
        card_ids = []
        for line in cards_text.splitlines():
            match = re.match(r"^\s*(\d+)\s+\[", line)
            if match and len(card_ids) < 8:
                card_ids.append(match.group(1))
        for card_id in card_ids:
            try:
                result = self.command_runner(("amixer", "-c", card_id, "scontents"))
                alsa_cards.append({"card_index": int(card_id), "returncode": result.returncode,
                                   "controls": sanitize_text((result.stdout or "") + (result.stderr or ""))[:6000]})
            except (OSError, subprocess.TimeoutExpired, PermissionError) as exc:
                alsa_cards.append({"card_index": int(card_id), "error": type(exc).__name__})
        journal = self._collect_command("audio_journal")
        version = self._collect_command("pipewire_version")
        return {
            "services": services,
            "default_sink_volume_and_mute": volume[:2000],
            "default_sink_properties": inspection,
            "available_pipewire_sinks": sinks[:8000],
            "audio_card_profiles_and_ports": cards,
            "sink_ports_and_active_port": sink_ports,
            "alsa_playback_devices": alsa[:8000],
            "alsa_mixer_controls_read_only": alsa_cards,
            "recent_user_audio_service_log": journal[:12000],
            "player_version": version[:1000],
            "test_tone_played": False,
            "microphone_recording_performed": False,
            "limitations": [
                "This is a read-only route/device snapshot and does not prove that physical speakers emit sound.",
                "No sink/profile/route is changed and no test tone is played automatically.",
            ],
        }

    def _browser_diagnostics(self):
        candidates = ("google-chrome-stable", "google-chrome", "chromium", "chromium-browser")
        selected = next((shutil.which(item) for item in candidates if shutil.which(item)), None)
        browser = {"available": bool(selected), "executable": Path(selected).name if selected else None, "version": None}
        if selected:
            try:
                result = self.command_runner((selected, "--version"))
                if result.returncode == 0:
                    browser["version"] = sanitize_text((result.stdout or "").strip())[:200]
            except (OSError, subprocess.TimeoutExpired, PermissionError):
                pass
        ca_bundle = Path("/etc/ssl/certs/ca-certificates.crt")
        try:
            info = ca_bundle.stat()
            ca = {"available": True, "size_bytes": info.st_size,
                  "modified_utc": datetime.fromtimestamp(info.st_mtime, timezone.utc).isoformat()}
        except OSError:
            ca = {"available": False, "size_bytes": None, "modified_utc": None}
        log_path = Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache"))) / "atlasos" / "browser.log"
        launcher_log = None
        try:
            if log_path.is_file() and not log_path.is_symlink():
                lines = log_path.read_text(encoding="utf-8", errors="replace").splitlines()[-100:]
                launcher_log = sanitize_text("\n".join(lines))[-16000:]
        except OSError:
            launcher_log = None
        return {"browser": browser, "system_ca_bundle": ca,
                "atlasos_browser_launcher_log": launcher_log,
                "browser_history_collected": False,
                "limitations": [
                    "Chrome internal navigation diagnostics and its profile trust store are not collected.",
                    "Launcher logs and curl probes cannot alone identify the school network root cause.",
                ]}

    def _collect_privileged_boot(self):
        try:
            result = self.command_runner(self.PRIVILEGED_BOOT_COMMAND)
            if result.returncode:
                self.errors.append({"collector": "privileged_boot", "error": "Unavailable or access denied",
                                    "returncode": result.returncode})
                return {}
            payload = json.loads(result.stdout)
            if payload.get("schema_version") != 1 or not isinstance(payload.get("operations"), dict):
                raise ValueError("Invalid privileged diagnostics response")
            operations = {}
            for key in ("dmesg", "journal_current"):
                operation = payload["operations"].get(key)
                if not isinstance(operation, dict) or not isinstance(operation.get("stdout"), str):
                    self.errors.append({"collector": key, "error": "Invalid privileged diagnostics response"})
                    continue
                if operation.get("returncode"):
                    self.errors.append({"collector": key, "error": "Unavailable or access denied",
                                        "returncode": operation.get("returncode")})
                text = operation["stdout"]
                if operation.get("stderr"):
                    text += "\n[stderr]\n" + operation["stderr"]
                operations[key] = sanitize_text(text)
            return operations
        except (OSError, subprocess.TimeoutExpired, PermissionError, json.JSONDecodeError, ValueError) as exc:
            self.errors.append({"collector": "privileged_boot", "error": type(exc).__name__})
            return {}

    def _write_json(self, root: Path, relative: str, data):
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2, default=_json_default) + "\n", encoding="utf-8")

    def _write_text(self, root: Path, relative: str, text):
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text[:MAX_LOG_BYTES], encoding="utf-8")

    @staticmethod
    def _validate_runtime_directory(runtime_dir, expected_uid=None, user_root="/run/user"):
        uid = os.geteuid() if expected_uid is None else expected_uid
        runtime_dir = Path(runtime_dir)
        expected = Path(user_root) / str(uid)
        if runtime_dir != expected:
            raise OSError("Tanılama geçici dizini yalnızca çağıran kullanıcının /run/user alanında oluşturulabilir")
        try:
            info = runtime_dir.lstat()
        except OSError as exc:
            raise OSError("Kullanıcıya ait geçici /run/user alanı kullanılamıyor") from exc
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != uid:
            raise OSError("Kullanıcıya ait geçici /run/user alanı doğrulanamadı")
        if stat.S_IMODE(info.st_mode) & 0o077 or stat.S_IMODE(info.st_mode) & 0o300 != 0o300:
            raise OSError("Kullanıcıya ait geçici /run/user alanının izinleri güvenli değil")
        return runtime_dir

    def _bundle_root(self):
        if self.volatile_root:
            root = self.volatile_root
            root.mkdir(parents=True, exist_ok=True)
            return Path(tempfile.mkdtemp(prefix="atlasos-diagnostics-", dir=root))
        if not self.run_root.is_dir():
            raise OSError("/run volatile runtime storage is unavailable; internal fallback is forbidden")
        # Production use is pinned to /run, which is volatile in the live system.
        if str(self.run_root) != "/run":
            raise OSError("Diagnostics bundle storage must be under volatile /run")
        mounts = StorageSafetyPolicy(mountinfo_path="/proc/self/mountinfo")._mounts()
        run_mounts = []
        for mount in mounts:
            point = Path(mount["mountpoint"])
            if Path("/run") == point or point in Path("/run").parents:
                run_mounts.append(mount)
        if not run_mounts or max(run_mounts, key=lambda mount: len(Path(mount["mountpoint"]).parts))["fstype"] != "tmpfs":
            raise OSError("/run tmpfs olarak doğrulanamadı; dahili depolama fallback'i yasak")
        runtime_dir = self._validate_runtime_directory(os.environ.get("XDG_RUNTIME_DIR", ""))
        if shutil.disk_usage(runtime_dir).free < 48 * 1024 * 1024:
            raise OSError("Kullanıcıya ait volatile /run/user alanında güvenli tanılama paketi için yeterli alan yok")
        return Path(tempfile.mkdtemp(prefix="atlasos-diagnostics-", dir=runtime_dir))

    def collect_all(self, progress=None, observations=None):
        self.errors = []
        stages = [
            ("Sistem bilgileri alınıyor", 10), ("Performans ölçülüyor", 25),
            ("Grafik altyapısı inceleniyor", 40), ("Boot günlükleri toplanıyor", 60),
            ("Atlas servisleri kontrol ediliyor", 78), ("Rapor hazırlanıyor", 92),
        ]
        root = self._bundle_root()
        def report(label, value):
            if progress:
                try:
                    progress(label, value)
                except Exception:
                    shutil.rmtree(root, ignore_errors=True)
                    raise
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        summary = self.system_snapshot()
        report(*stages[0])
        cpu = self.cpu_snapshot()
        memory = self.memory_snapshot()
        processes = self.process_snapshot()
        load = _read(self.proc_root / "loadavg", None)
        report(*stages[1])
        graphics = {key: self._collect_command(key) for key in ("lspci", "modules", "xrandr")}
        drm_tree = []
        for card in (self.sys_root / "class/drm").glob("card[0-9]*"):
            if "-" not in card.name:
                drm_tree.append({"name": card.name, "device": _read(card / "dev", None)})
        report(*stages[2])
        privileged_boot = self._collect_privileged_boot()
        boot_data = {key: privileged_boot.get(key) or self._collect_command(key)
                     for key in ("dmesg", "journal_current")}
        boot_keys = ("journal_previous", "systemd_analyze", "critical_chain")
        boot_data.update({key: self._collect_command(key) for key in boot_keys})
        boot_blob = "\n".join(boot_data.values())
        timeline = self._boot_timeline(boot_data)
        report(*stages[3])
        services = {}
        for service in ("atlasos-live-account", "lightdm", "NetworkManager", "atlasos-ui-status"):
            try:
                result = self.command_runner(("systemctl", "is-active", service))
                services[service] = result.stdout.strip() if result.returncode == 0 else "Mevcut değil"
            except (OSError, subprocess.TimeoutExpired, PermissionError):
                services[service] = "Mevcut değil"
                self.errors.append({"collector": "service:" + service, "error": "Unavailable"})
        report(*stages[4])
        self._write_json(root, "system/cpu.json", cpu)
        self._write_json(root, "system/memory.json", memory)
        self._write_json(root, "system/graphics.json", summary.get("gpu"))
        self._write_json(root, "system/display.json", summary.get("display"))
        self._write_json(root, "system/storage-inventory.json", summary["storage"])
        self._write_json(root, "system/network-summary.json", summary["network"])
        self._write_json(root, "system/time-sync.json", {
            "timedatectl": self._collect_command("time_sync_status")[:4000],
            "chrony_tracking": self._collect_command("chrony_tracking")[:6000],
            "chrony_sources": self._collect_command("chrony_sources")[:8000],
            "limitations": ["Time synchronization state is a snapshot; it does not prove the clock is correct.",
                            "Network source addresses are sanitized; no time service configuration is changed."],
        })
        self._write_json(root, "performance/idle.json", {"load_average": load, "cpu": cpu, "memory": memory, "processes": processes})
        self._write_json(root, "performance/cpu.json", {"mode": "snapshot", "cpu": cpu})
        self._write_json(root, "performance/memory.json", memory)
        self._write_json(root, "performance/processes.json", processes)
        self._write_json(root, "performance/real-world.json", {"capture": "manual_snapshot", "video_or_history_collected": False, "cpu": cpu, "memory": memory, "load_average": load, "processes": processes})
        self._write_json(root, "boot/timeline.json", timeline)
        self._write_text(root, "boot/cmdline.txt", sanitize_text(_read(self.proc_root / "cmdline", "Mevcut değil")))
        for source, target in (("dmesg", "dmesg.txt"), ("journal_current", "journal-current.txt"), ("journal_previous", "journal-previous.txt"), ("systemd_analyze", "systemd-analyze.txt"), ("critical_chain", "critical-chain.txt")):
            self._write_text(root, "boot/" + target, boot_data[source])
        self._write_text(root, "boot/drm.txt", sanitize_text("\n".join(line for line in boot_blob.splitlines() if re.search(r"drm|kms|simpledrm|fbcon|i915|amdgpu|nouveau", line, re.I))))
        self._write_text(root, "boot/framebuffer.txt", sanitize_text("\n".join(line for line in boot_blob.splitlines() if re.search(r"fbcon|framebuffer|efifb|vesafb", line, re.I))))
        self._write_text(root, "boot/plymouth.txt", sanitize_text("\n".join(line for line in boot_blob.splitlines() if "plymouth" in line.lower())))
        physical = {"first_black_rectangle": None, "plymouth_visible": None,
                    "second_black_transition": None, "desktop_visible": None}
        if isinstance(observations, dict):
            for key in physical:
                if key in observations and isinstance(observations[key], (type(None), bool, str, int, float)):
                    physical[key] = observations[key]
        self._write_json(root, "boot/physical-video-observations.json", physical)
        for key, filename in (("lspci", "lspci.txt"), ("modules", "modules.txt"), ("xrandr", "xrandr.txt")):
            self._write_text(root, "graphics/" + filename, graphics[key])
        self._write_json(root, "graphics/drm-tree.json", drm_tree)
        self._write_json(root, "atlas/version.json", {"version": VERSION})
        self._write_json(root, "atlas/services.json", services)
        self._write_json(root, "atlas/session.json", {"session_type": os.environ.get("XDG_SESSION_TYPE"), "desktop": os.environ.get("XDG_CURRENT_DESKTOP")})
        summary.update({"schema_version": 2, "collection_timestamp": datetime.now(timezone.utc).isoformat(),
                        "live_session": True, "boot_timeline": timeline, "performance_summary": {"cpu": cpu, "memory": memory, "load_average": load},
                        "warnings": ["Internal storage is protected; no storage benchmark is available."],
                        "collection_errors": self.errors, "storage_safety_state": "INTERNAL_READ_ONLY_UNKNOWN_PROTECTED"})
        self._write_json(root, "summary.json", summary)
        self._write_json(root, "collection/errors.json", self.errors)
        relative_files = sorted(str(path.relative_to(root)) for path in root.rglob("*") if path.is_file())
        relative_files.extend(["collection/manifest.json", "README.txt"])
        manifest = {"schema_version": 2, "sanitization": "home paths, UID paths, MAC/IP addresses, UUIDs, URL paths and query strings, SSIDs and Wi-Fi profile names in supported log formats, credential-like key/value strings",
                    "privacy_rules": PRIVACY_RULES, "files": relative_files,
                    "storage_writes": "volatile /run bundle only until explicit removable export",
                    "filesystem_scanning": False, "auto_mount": False}
        self._write_json(root, "collection/manifest.json", manifest)
        self._write_text(root, "README.txt", "AtlasOS 0.6.4 Tanılama Paketi\nBu paket salt okunur sistem gözlemlerini içerir. Dahili depolama korunur.\nSes/ağ/TLS verileri sınırlı ve salt okunurdur; fiziksel sonuç seçimi kullanıcı bildirimidir.\nGünlükler sınırlı ve sanitize edilmiştir; manifest.json ayrıntıları listeler.\n")
        report(*stages[5])
        report("Ses çıkış rotası inceleniyor", 93)
        audio_data = self._audio_diagnostics()
        self._write_json(root, "audio/output-route.json", audio_data)
        self._write_text(root, "audio/recent-audio-service-log.txt", audio_data["recent_user_audio_service_log"])
        network_data = self._network_diagnostics(progress=report)
        self._write_json(root, "network/https-connectivity.json", network_data)
        journal_lines = boot_data["journal_current"].splitlines()
        nm_events = "\n".join(line for line in journal_lines if re.search(r"NetworkManager|networkmanager|wpa_supplicant|dhclient|dhcpcd", line, re.I))
        self._write_text(root, "network/recent-network-events.txt", sanitize_text(nm_events[-12000:]))
        self._write_json(root, "browser/browser-and-ca-status.json", self._browser_diagnostics())
        allowed_observations = {
            "speaker_test": {"not_tested", "audible", "silent"},
            "chrome_navigation": {"not_tested", "loaded", "connection_reset",
                                  "certificate_authority_invalid", "other_error"},
        }
        recorded = {}
        for key, allowed in allowed_observations.items():
            item = observations.get(key) if isinstance(observations, dict) else None
            value = item.get("value") if isinstance(item, dict) else None
            if value not in allowed:
                value = "not_tested"
            recorded[key] = {
                "value": value,
                "recorded_at_utc": item.get("recorded_at_utc") if isinstance(item, dict) and value != "not_tested" else None,
                "source": "user_reported_manual_observation",
            }
        self._write_json(root, "field/physical-observations.json", {
            "observations": recorded,
            "interpretation": "Selections are user-reported observations, not independently measured hardware results.",
            "urls_or_page_contents_collected": False,
        })
        relative_files = sorted(
            str(path.relative_to(root)) for path in root.rglob("*")
            if path.is_file() and path.relative_to(root).as_posix() != "collection/manifest.json"
        )
        manifest = {
            "schema_version": 2,
            "sanitization": "home paths, UID paths, MAC/IP addresses, UUIDs, URL paths and query strings, SSIDs and Wi-Fi profile names in supported log formats, credential-like key/value strings",
            "privacy_rules": PRIVACY_RULES,
            "files": relative_files + ["collection/manifest.json"],
            "storage_writes": "volatile /run bundle only until explicit removable export",
            "filesystem_scanning": False,
            "auto_mount": False,
        }
        self._write_json(root, "collection/manifest.json", manifest)
        report("Tanılama arşivi oluşturuluyor", 99)
        archive = root.parent / f"AtlasOS-Diagnostics-{VERSION}-{timestamp}.zip"
        partial_archive = None
        try:
            fd, partial_text = tempfile.mkstemp(prefix=".atlasos-diagnostics-", suffix=".partial", dir=root.parent)
            partial_archive = Path(partial_text)
            os.close(fd)
            with zipfile.ZipFile(partial_archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=5) as bundle:
                for path in sorted(root.rglob("*")):
                    if path.is_file() and not path.is_symlink():
                        bundle.write(path, path.relative_to(root))
            with partial_archive.open("rb") as stream:
                if partial_archive.stat().st_size <= 0 or partial_archive.stat().st_size > MAX_BUNDLE_BYTES:
                    raise OSError("Tanılama paketi boş veya boyut sınırını aşıyor; yayımlanmadı.")
                StorageSafetyPolicy._validate_bundle_stream(stream)
                os.fsync(stream.fileno())
            # Publish the final .zip name only when its central directory and
            # required contents have passed validation. Hard-link creation is
            # atomic on the private /run tmpfs and refuses to overwrite.
            os.link(partial_archive, archive)
            partial_archive.unlink()
            partial_archive = None
        except Exception:
            if partial_archive is not None:
                partial_archive.unlink(missing_ok=True)
            shutil.rmtree(root, ignore_errors=True)
            raise
        shutil.rmtree(root, ignore_errors=True)
        return {"ok": True, "bundle": str(archive), "bundle_name": archive.name,
                "size_bytes": archive.stat().st_size, "summary": summary, "storage": summary["storage"],
                "targets": self.storage.export_targets(), "errors": self.errors}
