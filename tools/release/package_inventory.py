#!/usr/bin/env python3
"""Generate a small package inventory from a dpkg root or live-build manifest.

This records where package copyright/licence metadata is available. It does
not guess SPDX identifiers or replace the upstream copyright files.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


def parse_manifest(path: Path) -> list[dict]:
    rows = []
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line:
            continue
        match = re.fullmatch(r"(\S+)\s+(\S+)(?:\s+(\S+))?", line)
        if not match:
            raise ValueError(f"malformed package manifest row {line_number}: {line!r}")
        package, version, architecture = match.groups()
        rows.append({
            "package": package,
            "version": version,
            "architecture": architecture,
            "source_package": None,
            "section": None,
            "component": None,
            "license": "UNKNOWN",
            "license_metadata_source": None,
            "homepage": None,
        })
    return rows


def parse_dpkg_status(root: Path) -> list[dict]:
    status = root / "var/lib/dpkg/status"
    if not status.is_file():
        raise FileNotFoundError(f"dpkg status not found under rootfs: {status}")
    records: list[dict[str, str]] = []
    current: dict[str, str] = {}
    for line in status.read_text(encoding="utf-8", errors="replace").splitlines() + [""]:
        if not line:
            if current.get("Status", "").endswith(" installed"):
                records.append(current)
            current = {}
            continue
        if line[:1].isspace() or ": " not in line:
            continue
        key, value = line.split(": ", 1)
        current[key] = value

    rows = []
    for record in records:
        package = record.get("Package")
        if not package:
            continue
        copyright_path = Path("usr/share/doc") / package / "copyright"
        metadata_exists = (root / copyright_path).is_file()
        source_field = record.get("Source", "").strip()
        source_package = source_field.split(" ", 1)[0] if source_field else package
        rows.append({
            "package": package,
            "version": record.get("Version"),
            "architecture": record.get("Architecture"),
            "source_package": source_package,
            "section": record.get("Section"),
            "component": None,
            "license": "REVIEW_REQUIRED" if metadata_exists else "UNKNOWN",
            "license_metadata_source": copyright_path.as_posix() if metadata_exists else None,
            "homepage": record.get("Homepage"),
        })
    return sorted(rows, key=lambda row: row["package"].casefold())


def write_notices(rows: list[dict], destination: Path) -> None:
    lines = [
        "AtlasOS third-party package inventory",
        "License conclusions are not normalized here. Review the referenced package copyright files.",
        "",
    ]
    for row in rows:
        source = row["license_metadata_source"] or "No installed copyright metadata path found; review required."
        lines.append(f"- {row['package']} {row['version']} ({row['architecture'] or 'architecture unknown'}): {source}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--manifest", type=Path, help="live-build filesystem.manifest file")
    source.add_argument("--rootfs", type=Path, help="root of an extracted/built dpkg filesystem")
    parser.add_argument("--output", type=Path, required=True, help="JSON output path")
    parser.add_argument("--notices-output", type=Path, help="optional concise package-to-copyright pointers")
    args = parser.parse_args()
    rows = parse_manifest(args.manifest) if args.manifest else parse_dpkg_status(args.rootfs)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({"schema": "atlasos-package-inventory-v1", "packages": rows}, indent=2) + "\n", encoding="utf-8")
    if args.notices_output:
        args.notices_output.parent.mkdir(parents=True, exist_ok=True)
        write_notices(rows, args.notices_output)
    print(f"Wrote {len(rows)} package records to {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
