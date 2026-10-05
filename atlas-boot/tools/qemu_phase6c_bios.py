#!/usr/bin/env python3
"""Boot an AtlasOS candidate ISO with SeaBIOS and capture the legacy path."""
import json
import os
import socket
import sys
import time


class Qmp:
    def __init__(self, path):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        deadline = time.monotonic() + 30
        while True:
            try:
                self.sock.connect(path)
                break
            except OSError:
                if time.monotonic() >= deadline:
                    raise
                time.sleep(0.2)
        self.file = self.sock.makefile("rwb", buffering=0)
        self.read()
        self.command("qmp_capabilities")

    def read(self):
        while True:
            item = json.loads(self.file.readline())
            if "return" in item or "error" in item or "QMP" in item:
                return item

    def command(self, name, args=None):
        self.file.write((json.dumps({"execute": name, "arguments": args or {}, "id": name}) + "\r\n").encode())
        while True:
            response = self.read()
            if response.get("id") == name:
                if "error" in response:
                    raise RuntimeError(response["error"])
                return response.get("return")

    def capture(self, path):
        self.command("human-monitor-command", {"command-line": f"screendump {path}"})

    def key(self, key):
        self.command("send-key", {"keys": [{"type": "qcode", "data": key}], "hold-time": 120})


def live(path):
    try:
        data = open(path, "rb").read()
        header, pixels = data.split(b"\n255\n", 1)
        width, height = map(int, header.splitlines()[-1].split())
        if width < 30 or height < 230:
            return False
        nav = pixels[(220 * width + 10) * 3 : (220 * width + 10) * 3 + 3]
        top = pixels[(10 * width + 10) * 3 : (10 * width + 10) * 3 + 3]
        return nav[0] < 100 and nav[1] < 150 and nav[2] < 200 and min(top) > 210
    except (OSError, ValueError):
        return False


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: qemu_phase6c_bios.py SOCKET OUTPUT_DIR TIMEOUT_SECONDS")
    sock, out, timeout = sys.argv[1], sys.argv[2], int(sys.argv[3])
    os.makedirs(out, exist_ok=True)
    qmp = Qmp(sock)
    time.sleep(8)
    qmp.capture(os.path.join(out, "01-seabios-and-isolinux.ppm"))
    qmp.key("ret")
    started = time.monotonic()
    points = (15, 30, 45, 60, 90, 120, 180, 240, 300, timeout)
    for elapsed_target in points:
        if elapsed_target > timeout:
            break
        wait = elapsed_target - (time.monotonic() - started)
        if wait > 0:
            time.sleep(wait)
        frame = os.path.join(out, f"live-{int(time.monotonic() - started):03d}s.ppm")
        qmp.capture(frame)
        status = qmp.command("query-status")
        if live(frame):
            with open(os.path.join(out, "result.txt"), "w", encoding="utf-8") as report:
                report.write(f"bios_live_detected=true\nelapsed_seconds={int(time.monotonic() - started)}\nqemu_status={status.get('status')}\n")
            return
        if status.get("status") in ("shutdown", "guest-panicked"):
            break
    with open(os.path.join(out, "result.txt"), "w", encoding="utf-8") as report:
        report.write(f"bios_live_detected=false\nqemu_status={status.get('status')}\nmanual_review=inspect final capture\n")


if __name__ == "__main__":
    main()
