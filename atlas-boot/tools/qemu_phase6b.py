#!/usr/bin/env python3
"""Capture Atlas Boot Manager handoff and Live-session frames over QMP."""
import json
import os
import socket
import struct
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
        self._read()
        self.command("qmp_capabilities")

    def _read(self):
        while True:
            item = json.loads(self.file.readline())
            if "return" in item or "error" in item or "QMP" in item:
                return item

    def command(self, name, args=None):
        self.file.write((json.dumps({"execute": name, "arguments": args or {}, "id": name}) + "\r\n").encode())
        while True:
            response = self._read()
            if response.get("id") == name:
                if "error" in response:
                    raise RuntimeError(response["error"])
                return response.get("return")

    def capture(self, path):
        self.command("human-monitor-command", {"command-line": f"screendump {path}"})

    def key(self, key):
        self.command("send-key", {"keys": [{"type": "qcode", "data": key}], "hold-time": 120})


def ppm_rgb(path, x, y):
    data = open(path, "rb").read()
    if not data.startswith(b"P6\n"):
        return None
    header, pixels = data.split(b"\n255\n", 1)
    width, height = map(int, header.splitlines()[-1].split())
    if x >= width or y >= height:
        return None
    offset = (y * width + x) * 3
    return tuple(pixels[offset : offset + 3])


def looks_like_atlas_live(path):
    # At x=10,y=220 the Live shell has its dark navigation rail. The boot
    # manager's pale background and Plymouth are intentionally different.
    nav = ppm_rgb(path, 10, 220)
    header = ppm_rgb(path, 10, 10)
    return (
        nav is not None
        and header is not None
        and nav[0] < 100
        and nav[1] < 150
        and nav[2] < 200
        and min(header) > 210
    )


def main():
    if len(sys.argv) != 6:
        raise SystemExit("usage: qemu_phase6b.py SOCKET OUTPUT_DIR MODE TIMEOUT_SECONDS RESOLUTION")
    sock, out_dir, mode, timeout, _resolution = sys.argv[1:]
    timeout = int(timeout)
    os.makedirs(out_dir, exist_ok=True)
    qmp = Qmp(sock)
    time.sleep(5)
    qmp.capture(os.path.join(out_dir, "01-atlas-menu.ppm"))
    if mode != "timeout":
        if mode == "navigation":
            qmp.key("down")
            time.sleep(1)
            qmp.capture(os.path.join(out_dir, "02-menu-down.ppm"))
            qmp.key("up")
            time.sleep(1)
            qmp.capture(os.path.join(out_dir, "03-menu-up.ppm"))
            qmp.key("ret")
            time.sleep(2)
            qmp.capture(os.path.join(out_dir, "04-transition-or-error.ppm"))
            with open(os.path.join(out_dir, "result.txt"), "w", encoding="utf-8") as f:
                f.write("mode=navigation-smoke\nkeys=DOWN,UP,ENTER\nenter_sent=true\n")
            return
        qmp.key("ret")
    time.sleep(2)
    qmp.capture(os.path.join(out_dir, "02-transition-or-error.ppm"))

    if mode == "failure":
        time.sleep(2)
        qmp.capture(os.path.join(out_dir, "03-atlas-error.ppm"))
        with open(os.path.join(out_dir, "result.txt"), "w", encoding="utf-8") as f:
            f.write("mode=failure-injection\nresult=LoadImage was attempted; inspect Atlas-native error capture\n")
        return

    started = time.monotonic()
    for seconds in (15, 30, 45, 60, 75, 90, 120, 150, 180, 240, 300, timeout):
        wait = min(seconds, timeout) - (time.monotonic() - started)
        if wait > 0:
            time.sleep(wait)
        capture = os.path.join(out_dir, f"live-{int(time.monotonic() - started):03d}s.ppm")
        qmp.capture(capture)
        status = qmp.command("query-status")
        if status.get("status") in ("shutdown", "guest-panicked"):
            raise RuntimeError(f"QEMU stopped before an interactive Live session: {status}")
        if looks_like_atlas_live(capture):
            elapsed = int(time.monotonic() - started)
            with open(os.path.join(out_dir, "result.txt"), "w", encoding="utf-8") as f:
                f.write(f"mode=live-handoff-{mode}\n")
                f.write(f"live_session_detected=true\nelapsed_seconds={elapsed}\n")
                f.write(f"qemu_status={status.get('status')}\n")
                f.write("visual_acceptance=Atlas navigation panel and header pixel check; final capture retained\n")
            return
        if seconds >= timeout:
            break
    with open(os.path.join(out_dir, "result.txt"), "w", encoding="utf-8") as f:
        f.write(f"mode=live-handoff\nqemu_status={status.get('status')}\n")
        f.write("visual_acceptance=manual review of final capture required\n")


if __name__ == "__main__":
    main()
