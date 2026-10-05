#!/usr/bin/env bash
set -euo pipefail

base="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:-bios}"
iso="${2:-${base}/dist/AtlasOS-0.6.2-FINAL-PHYSICAL/AtlasOS-0.6.2-live-amd64.iso}"
case "${mode}" in bios|uefi) ;; *) echo "Usage: $0 [bios|uefi] [iso-path]" >&2; exit 64;; esac
[[ -f "${iso}" ]] || { echo "ISO not found: ${iso}" >&2; exit 66; }

validation="${base}/dist/validation"
mkdir -p "${validation}"
tmp="$(mktemp -d "/tmp/atlasos-qemu-${mode}.XXXXXX")"
socket="${tmp}/qmp.sock"
qemu=(qemu-system-x86_64 -accel tcg,thread=multi -m 4096 -smp 4 -vga std -display none -no-reboot -no-shutdown
      -boot order=d -cdrom "${iso}" -serial none -qmp "unix:${socket},server=on,wait=off")
if [[ "${mode}" == uefi ]]; then
  firmware="/usr/share/OVMF"
  [[ -f "${firmware}/OVMF_CODE_4M.fd" && -f "${firmware}/OVMF_VARS_4M.fd" ]] || {
    echo "OVMF 4 MiB firmware files are not installed." >&2; exit 69;
  }
  cp "${firmware}/OVMF_VARS_4M.fd" "${tmp}/OVMF_VARS.fd"
  qemu+=(-drive "if=pflash,format=raw,readonly=on,file=${firmware}/OVMF_CODE_4M.fd"
         -drive "if=pflash,format=raw,file=${tmp}/OVMF_VARS.fd")
fi

"${qemu[@]}" &
qemu_pid=$!
cleanup() {
  kill "${qemu_pid}" 2>/dev/null || true
  wait "${qemu_pid}" 2>/dev/null || true
  rm -rf -- "${tmp}"
}
trap cleanup EXIT

python3 - "${socket}" "${validation}" "${mode}" <<'PY'
import json
import pathlib
import socket
import sys
import time

socket_path, output_dir, mode = sys.argv[1:]
output_dir = pathlib.Path(output_dir)
deadline = time.monotonic() + 30
while not pathlib.Path(socket_path).exists():
    if time.monotonic() > deadline:
        raise SystemExit("QEMU QMP socket did not appear")
    time.sleep(0.2)

connection = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
connection.settimeout(15)
connection.connect(socket_path)
stream = connection.makefile("rwb", buffering=0)
greeting = json.loads(stream.readline())
if "QMP" not in greeting:
    raise SystemExit(f"Unexpected QMP greeting: {greeting}")

def command(name, **arguments):
    stream.write((json.dumps({"execute": name, "arguments": arguments}) + "\r\n").encode())
    while True:
        response = json.loads(stream.readline())
        if "return" in response:
            return response["return"]
        if "error" in response:
            raise RuntimeError(response["error"])

command("qmp_capabilities")
for seconds in (5, 15, 30, 60, 90, 120, 180):
    time.sleep(seconds if seconds == 5 else seconds - previous)
    previous = seconds
    ppm = pathlib.Path(output_dir) / f"atlasos-062-stabilization-qemu-{mode}-{seconds:02d}s.ppm"
    command("human-monitor-command", **{"command-line": f"screendump {ppm}"})
    if not ppm.is_file() or ppm.stat().st_size < 100_000:
        raise SystemExit(f"QEMU produced no usable display capture at {seconds}s")
    print(f"Captured {mode} boot display at {seconds}s: {ppm.name} ({ppm.stat().st_size} bytes)")

command("quit")
connection.close()
PY

for ppm in "${validation}/atlasos-062-stabilization-qemu-${mode}-"*.ppm; do
  [[ -f "${ppm}" ]] || continue
  magick "${ppm}" "${ppm%.ppm}.png"
  rm -f -- "${ppm}"
done
echo "AtlasOS 0.6.2 ${mode} QEMU boot reached the 180-second capture point."
