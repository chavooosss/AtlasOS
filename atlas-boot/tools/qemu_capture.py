#!/usr/bin/env python3
"""Small QMP client for framebuffer captures and keyboard smoke checks."""
import json
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
        self.command("send-key", {"keys": [{"type": "qcode", "data": key}], "hold-time": 100})


def main():
    if len(sys.argv) != 4:
        raise SystemExit("usage: qemu_capture.py SOCKET BASE_PATH TARGET")
    sock, base, target = sys.argv[1:]
    qmp = Qmp(sock)
    time.sleep(3)
    qmp.capture(base + "-screen.ppm")
    time.sleep(10)
    qmp.capture(base + "-countdown.ppm")
    qmp.key("down")
    time.sleep(1)
    qmp.capture(base + "-navigation.ppm")
    qmp.key("esc")
    time.sleep(1)
    qmp.capture(base + "-escape.ppm")
    qmp.key("up")
    time.sleep(1)
    qmp.capture(base + "-power.ppm")
    qmp.key("ret")
    time.sleep(1)
    status = qmp.command("query-status")
    if status.get("status") != "shutdown":
        raise RuntimeError(f"UEFI shutdown action did not reach QEMU shutdown: {status}")
    actual_mode = "1368x768" if target == "1366x768" else target
    with open(base + "-validation.txt", "w", encoding="utf-8") as report:
        report.write(f"requested_case={target}\n")
        report.write(f"ovmf_surface={actual_mode}\n")
        report.write("keys=DOWN,ESC,UP,ENTER\n")
        report.write(f"uefi_power_action={status['status']}\n")
    print(f"QEMU capture sequence completed for {target}; power status={status['status']}")


if __name__ == "__main__":
    main()
