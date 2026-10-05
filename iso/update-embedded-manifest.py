#!/usr/bin/env python3
"""Update the three Atlas Boot Manager payload entries in an ISO SHA256SUMS."""
from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    if len(sys.argv) != 6:
        print("Usage: update-embedded-manifest.py BASE_SHA256SUMS FRONTEND_EFI BACKEND_EFI EFI_IMAGE OUTPUT", file=sys.stderr)
        return 64
    source, frontend, backend, efi_image, output = map(Path, sys.argv[1:])
    for path in (source, frontend, backend, efi_image):
        if not path.is_file() or path.is_symlink():
            print(f"Required regular input file missing/unsafe: {path}", file=sys.stderr)
            return 2
    entries: dict[str, str] = {}
    lines = source.read_text(encoding="ascii").splitlines()
    for line_no, line in enumerate(lines, 1):
        match = re.fullmatch(r"([0-9a-fA-F]{64})  (.+)", line)
        if not match:
            print(f"Invalid SHA256SUMS row {line_no}", file=sys.stderr)
            return 3
        name = match.group(2)
        if name in entries:
            print(f"Duplicate SHA256SUMS path: {name}", file=sys.stderr)
            return 3
        entries[name] = match.group(1).lower()

    replacements = {
        "./EFI/BOOT/BOOTX64.EFI": digest(frontend),
        "./EFI/BOOT/ATLASGRUB.EFI": digest(backend),
        "./boot/grub/efi.img": digest(efi_image),
    }
    # The frontend and EFI image must already be part of the base manifest.
    for name in ("./EFI/BOOT/BOOTX64.EFI", "./boot/grub/efi.img"):
        if name not in entries:
            print(f"Base manifest is missing required entry: {name}", file=sys.stderr)
            return 4
    entries.update(replacements)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("".join(f"{value}  {name}\n" for name, value in sorted(entries.items())), encoding="ascii", newline="\n")
    print(f"Updated {len(replacements)} embedded payload entries in {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
