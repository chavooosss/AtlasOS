#!/usr/bin/env bash
# Read-only AtlasOS diagnostics-export troubleshooting report.
# Does not mount, write to, or scan user files on removable media.
set +e
export LC_ALL=C

echo "=== ATLASOS DIAGNOSTICS EXPORT CHECK ==="
echo "BEGIN"
. /etc/os-release 2>/dev/null
printf 'OS=%s %s\n' "${ID:-unknown}" "${VERSION_ID:-unknown}"
printf 'KERNEL=%s\n' "$(uname -sr)"
printf 'UID=%s\n' "$(id -u)"
if pgrep -x atlasos-ui >/dev/null 2>&1; then
    echo 'ATLASOS_UI_PROCESS=running'
else
    echo 'ATLASOS_UI_PROCESS=not_found'
fi
if [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ]; then
    echo 'XDG_RUNTIME_DIR=present'
else
    echo 'XDG_RUNTIME_DIR=missing_or_unavailable'
fi
echo
echo '--- Collector, removable-media classification, and recent bundles ---'

python3 - "$(id -u)" <<'PY'
import hashlib
import importlib.util
import json
import re
import stat
import sys
import zipfile
from pathlib import Path

uid = int(sys.argv[1])
module_path = Path('/usr/local/bin/atlasos_diagnostics.py')

def out(key, value):
    print(f'{key}={value}')

def safe_mount(path):
    path = str(path)
    path = re.sub(r'^(/media|/run/media)/[^/]+/[^/]+', r'\1/[USER]/[VOLUME]', path)
    path = re.sub(r'^/mnt/[^/]+', '/mnt/[MOUNT]', path)
    return path

if not module_path.is_file():
    out('COLLECTOR', 'missing: /usr/local/bin/atlasos_diagnostics.py')
    raise SystemExit(0)

try:
    digest = hashlib.sha256(module_path.read_bytes()).hexdigest()
    spec = importlib.util.spec_from_file_location('atlasos_diagnostics_runtime_check', module_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    collector = module.DiagnosticsCollector()
    out('COLLECTOR_VERSION', getattr(module, 'VERSION', 'unknown'))
    out('COLLECTOR_SHA256', digest)

    runtime = Path(f'/run/user/{uid}')
    if runtime.is_dir():
        info = runtime.stat()
        out('RUNTIME_DIR', f'present owner_uid={info.st_uid} mode={stat.S_IMODE(info.st_mode):04o}')
    else:
        out('RUNTIME_DIR', 'missing')

    inventory = collector.storage.inventory()
    out('LIVE_SOURCE_DEVICE_IDS', ','.join(inventory.get('live_source') or []) or 'not_identified')
    devices = inventory.get('devices') or []
    out('BLOCK_DEVICE_COUNT', len(devices))
    for item in devices:
        out('DEVICE', json.dumps({
            'name': item.get('device'),
            'major_minor': item.get('major_minor'),
            'size_bytes': item.get('size_bytes'),
            'class': item.get('class'),
            'partition': item.get('partition'),
            'mountpoint_count': len(item.get('mountpoints') or []),
            'write_policy': item.get('write_policy'),
        }, ensure_ascii=False, sort_keys=True))

    mounts = collector.storage._mounts()
    known_numbers = {d.get('major_minor') for d in devices}
    for mount in mounts:
        if mount.get('major_minor') in known_numbers:
            out('MOUNT', json.dumps({
                'id': mount.get('id'),
                'major_minor': mount.get('major_minor'),
                'mountpoint': safe_mount(mount.get('mountpoint', '')),
                'filesystem': mount.get('fstype'),
                'root_is_filesystem_root': mount.get('root') == '/',
                'read_write': 'rw' in (mount.get('options') or []),
            }, ensure_ascii=False, sort_keys=True))

    targets = collector.storage.export_targets()
    out('APP_EXPORT_TARGET_COUNT', len(targets))
    for target in targets:
        out('APP_EXPORT_TARGET', json.dumps({
            'id': target.get('id'),
            'device': target.get('device'),
            'size_bytes': target.get('size_bytes'),
            'class': target.get('class'),
            'mountpoint': safe_mount(target.get('mountpoint', '')),
        }, ensure_ascii=False, sort_keys=True))

    archives = sorted(runtime.glob('AtlasOS-Diagnostics-*.zip'),
                      key=lambda p: p.stat().st_mtime, reverse=True)
    out('RUNTIME_BUNDLE_COUNT', len(archives))
    for archive in archives[:3]:
        record = {
            'name': archive.name,
            'size_bytes': archive.stat().st_size,
            'sha256': hashlib.sha256(archive.read_bytes()).hexdigest(),
        }
        try:
            with zipfile.ZipFile(archive, 'r') as zf:
                infos = zf.infolist()
                names = {item.filename for item in infos}
                required = {'README.txt', 'summary.json', 'collection/manifest.json'}
                record['zip_integrity'] = 'PASS' if zf.testzip() is None else 'FAIL'
                record['member_count'] = len(infos)
                record['required_members_present'] = sorted(required & names)
                record['required_members_missing'] = sorted(required - names)
                record['total_uncompressed_bytes'] = sum(item.file_size for item in infos)
                record['member_names'] = sorted(names)[:80]
                try:
                    summary = json.loads(zf.read('summary.json'))
                    record['summary_top_level_keys'] = sorted(summary.keys()) if isinstance(summary, dict) else []
                    errors = summary.get('collection_errors', []) if isinstance(summary, dict) else []
                    record['collector_errors'] = [
                        {'collector': e.get('collector', 'unknown'),
                         'error': module.sanitize_text(str(e.get('error', 'unknown')))}
                        for e in errors[:20] if isinstance(e, dict)
                    ]
                except Exception as exc:
                    record['summary_read_error'] = type(exc).__name__
        except Exception as exc:
            record['zip_integrity'] = 'FAIL'
            record['zip_error'] = type(exc).__name__
        out('BUNDLE', json.dumps(record, ensure_ascii=False, sort_keys=True))

except Exception as exc:
    try:
        message = module.sanitize_text(str(exc))
    except Exception:
        message = type(exc).__name__
    out('COLLECTOR_CHECK_ERROR', f'{type(exc).__name__}: {message}')
PY

echo
echo '--- Relevant service state ---'
if command -v systemctl >/dev/null 2>&1; then
    for service in atlasos-ui udisks2; do
        printf '%s=' "$service"
        systemctl is-active "$service" 2>/dev/null || echo unavailable
    done
else
    echo 'systemctl=unavailable'
fi
echo 'END'
echo '=== END CHECK ==='
