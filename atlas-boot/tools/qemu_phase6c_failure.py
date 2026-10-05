#!/usr/bin/env python3
"""Capture post-StartImage output for isolated Phase 6C backend failures."""
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


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: qemu_phase6c_failure.py SOCKET OUTPUT_DIR")
    qmp = Qmp(sys.argv[1])
    out = sys.argv[2]
    time.sleep(5)
    qmp.capture(os.path.join(out, "01-atlas-menu.ppm"))
    qmp.key("ret")
    for second in (2, 5, 15, 30):
        time.sleep(second if second == 2 else (second - previous))
        frame = os.path.join(out, f"post-startimage-{second:02d}s.ppm")
        qmp.capture(frame)
        previous = second
    status = qmp.command("query-status")
    with open(os.path.join(out, "result.txt"), "w", encoding="utf-8") as report:
        report.write("frontend_enter_sent=true\n")
        report.write("captures=2s,5s,15s,30s after StartImage\n")
        report.write(f"qemu_status={status.get('status')}\n")
        report.write("manual_screen_classification=required\n")


if __name__ == "__main__":
    main()
