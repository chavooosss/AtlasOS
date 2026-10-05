#!/usr/bin/env python3
"""Read-only AtlasOS diagnostics with fail-closed removable-media export.

The collector never mounts storage and never opens a block device for writing.
Its only persistent write API creates one generated archive on a filesystem
whose removable USB ancestry and mount source have been revalidated.
"""
from __future__ import annotations

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

VERSION = "0.6.3"
FORBIDDEN_COMMANDS = {
    "mkfs", "mkfs.ext4", "mkfs.vfat", "wipefs", "fdisk", "sfdisk",
    "parted", "dd", "fio", "fsck", "ntfsfix", "resize2fs", "blkdiscard",
    "badblocks", "sgdisk", "gdisk", "nvme", "hdparm",
}
PRIVACY_RULES = [
    "Browser histories, cookies, passwords, tokens, profiles and page contents are not collected.",
    "Wi-Fi credentials, SSH keys, clipboard, home documents and personal files are not collected.",
    "Storage inventory reads device metadata only; filesystems are never traversed or mounted.",
    "Logs are bounded and sanitized for home paths, account IDs, MAC addresses and credential-like values.",
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
    text = re.sub(r"(?i)(password|passwd|psk|token|cookie|secret|username|user|account|_uid|uid)(\s*[=:]\s*)\S+", r"\1\2[REDACTED]", text)
    text = re.sub(r"\b(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}\b", "[MAC]", text)
    text = re.sub(r"\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b", "[IP]", text)
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
        if not archive.is_file() or archive.is_symlink() or archive.stat().st_size > MAX_BUNDLE_BYTES:
            raise ValueError("Tanılama paketi geçersiz veya boyut sınırını aşıyor.")
        mount = self.authorize_destination(destination, expected_mount_id)
        target_dir = Path(destination)
        usage = shutil.disk_usage(target_dir)
        required = archive.stat().st_size + 1024 * 1024
        if usage.free < required:
            raise OSError("USB bellekte tanılama paketi için yeterli boş alan yok.")
        name = archive.name
        if not re.fullmatch(r"AtlasOS-Diagnostics-0\.6\.2-[0-9TZ-]+\.zip", name):
            raise ValueError("Yalnızca oluşturulmuş AtlasOS tanılama arşivleri dışa aktarılabilir.")
        output = target_dir / name
        dir_flags = os.O_RDONLY | getattr(os, "O_DIRECTORY", 0) | getattr(os, "O_NOFOLLOW", 0)
        dir_fd = os.open(target_dir, dir_flags)
        file_fd = None
        try:
            # Pin writes to the already-open verified mount root. This prevents a
            # later path/symlink swap from redirecting data onto another mount.
            self.authorize_destination(destination, mount["id"])
            flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
            file_fd = os.open(name, flags, 0o600, dir_fd=dir_fd)
            with os.fdopen(file_fd, "wb", closefd=True) as dest, archive.open("rb") as src:
                file_fd = None
                while True:
                    self.authorize_destination(destination, mount["id"])
                    chunk = src.read(1024 * 1024)
                    if not chunk:
                        break
                    dest.write(chunk)
                dest.flush()
                os.fsync(dest.fileno())
            self.authorize_destination(destination, mount["id"])
            return str(output)
        except Exception:
            try:
                if file_fd is not None:
                    os.close(file_fd)
                os.unlink(name, dir_fd=dir_fd)
            except OSError:
                pass
            raise
        finally:
            os.close(dir_fd)


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
        timestamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
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
                if isinstance(observations.get(key), (type(None), bool, str, int, float)):
                    physical[key] = observations[key]
        self._write_json(root, "boot/physical-video-observations.json", physical)
        for key, filename in (("lspci", "lspci.txt"), ("modules", "modules.txt"), ("xrandr", "xrandr.txt")):
            self._write_text(root, "graphics/" + filename, graphics[key])
        self._write_json(root, "graphics/drm-tree.json", drm_tree)
        self._write_json(root, "atlas/version.json", {"version": VERSION})
        self._write_json(root, "atlas/services.json", services)
        self._write_json(root, "atlas/session.json", {"session_type": os.environ.get("XDG_SESSION_TYPE"), "desktop": os.environ.get("XDG_CURRENT_DESKTOP")})
        summary.update({"schema_version": 1, "collection_timestamp": datetime.now(timezone.utc).isoformat(),
                        "live_session": True, "boot_timeline": timeline, "performance_summary": {"cpu": cpu, "memory": memory, "load_average": load},
                        "warnings": ["Internal storage is protected; no storage benchmark is available."],
                        "collection_errors": self.errors, "storage_safety_state": "INTERNAL_READ_ONLY_UNKNOWN_PROTECTED"})
        self._write_json(root, "summary.json", summary)
        self._write_json(root, "collection/errors.json", self.errors)
        relative_files = sorted(str(path.relative_to(root)) for path in root.rglob("*") if path.is_file())
        relative_files.extend(["collection/manifest.json", "README.txt"])
        manifest = {"schema_version": 1, "sanitization": "home paths, UID paths, MAC/IP addresses, UUIDs, credential-like key/value strings",
                    "privacy_rules": PRIVACY_RULES, "files": relative_files,
                    "storage_writes": "volatile /run bundle only until explicit removable export",
                    "filesystem_scanning": False, "auto_mount": False}
        self._write_json(root, "collection/manifest.json", manifest)
        self._write_text(root, "README.txt", "AtlasOS 0.6.3 Tanılama Paketi\nBu paket salt okunur sistem gözlemlerini içerir. Dahili depolama korunur.\nGünlükler sınırlı ve sanitize edilmiştir; manifest.json ayrıntıları listeler.\n")
        report(*stages[5])
        archive = root.parent / f"AtlasOS-Diagnostics-{VERSION}-{timestamp}.zip"
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=5) as bundle:
            for path in sorted(root.rglob("*")):
                if path.is_file() and not path.is_symlink():
                    bundle.write(path, path.relative_to(root))
        if archive.stat().st_size > MAX_BUNDLE_BYTES:
            archive.unlink()
            shutil.rmtree(root, ignore_errors=True)
            raise OSError("Tanılama paketi boyut sınırını aşıyor; /run üzerinde tutulmadı.")
        shutil.rmtree(root, ignore_errors=True)
        return {"ok": True, "bundle": str(archive), "bundle_name": archive.name,
                "size_bytes": archive.stat().st_size, "summary": summary, "storage": summary["storage"],
                "targets": self.storage.export_targets(), "errors": self.errors}
