#!/usr/bin/env python3
"""Capture the first seconds of the Atlas UEFI menu in QEMU/OVMF."""

import argparse
import shutil
import socket
import subprocess
import tempfile
import time
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("iso", type=Path)
parser.add_argument("output_dir", type=Path)
args = parser.parse_args()
args.output_dir.mkdir(parents=True, exist_ok=True)

with tempfile.TemporaryDirectory(prefix="atlas-grub-qemu-") as temporary:
    base = Path(temporary)
    vars_file = base / "OVMF_VARS.fd"
    shutil.copyfile("/usr/share/OVMF/OVMF_VARS_4M.fd", vars_file)
    monitor_path = base / "monitor.sock"
    process = subprocess.Popen(
        [
            "qemu-system-x86_64", "-machine", "q35", "-m", "2048",
            "-drive", "if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd",
            "-drive", f"if=pflash,format=raw,file={vars_file}",
            "-cdrom", str(args.iso), "-boot", "d",
            "-display", "none", "-vnc", ":15", "-serial", "none", "-S",
            "-monitor", f"unix:{monitor_path},server,nowait",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        for _ in range(100):
            if monitor_path.exists():
                break
            if process.poll() is not None:
                raise RuntimeError("QEMU exited before creating its monitor")
            time.sleep(0.1)
        with socket.socket(socket.AF_UNIX) as monitor:
            monitor.connect(str(monitor_path))
            monitor.recv(4096)
            monitor.sendall(b"cont\n")
            for second in range(1, 7):
                time.sleep(1)
                path = args.output_dir / f"uefi-{second:02d}s.ppm"
                monitor.sendall(f"screendump {path}\n".encode())
                time.sleep(0.2)
            monitor.sendall(b"quit\n")
    finally:
        if process.poll() is None:
            process.kill()
        process.wait(timeout=10)
