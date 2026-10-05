#!/usr/bin/env python3
"""Apply only the reviewed /run/user diagnostics temp-dir fix to an older rootfs."""
from __future__ import annotations

import ast
import sys
from pathlib import Path


def method_range(text: str, name: str) -> tuple[int, int]:
    tree = ast.parse(text)
    collector = next(
        node for node in tree.body
        if isinstance(node, ast.ClassDef) and node.name == "DiagnosticsCollector"
    )
    method = next(
        node for node in collector.body
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name == name
    )
    start = min([method.lineno] + [decorator.lineno for decorator in method.decorator_list])
    return start - 1, method.end_lineno


def main(source_path: Path, target_path: Path) -> None:
    source = source_path.read_text(encoding="utf-8")
    target = target_path.read_text(encoding="utf-8")
    if 'dir="/run"' not in target or "def _validate_runtime_directory" in target:
        raise RuntimeError("Target is not the expected old /run diagnostics implementation")
    if "import stat\n" not in target:
        raise RuntimeError("Target lacks stat import required by the reviewed fix")

    source_lines = source.splitlines(keepends=True)
    target_lines = target.splitlines(keepends=True)
    validation_start, _ = method_range(source, "_validate_runtime_directory")
    _, bundle_end = method_range(source, "_bundle_root")
    target_start, target_end = method_range(target, "_bundle_root")
    replacement = source_lines[validation_start:bundle_end]
    patched = "".join(target_lines[:target_start] + replacement + target_lines[target_end:])
    ast.parse(patched)
    if patched.count("def _bundle_root") != 1 or patched.count("def _validate_runtime_directory") != 1:
        raise RuntimeError("Unexpected diagnostics method count after patch")
    target_path.write_text(patched, encoding="utf-8")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: patch-diagnostics-runtime-in-squashfs.py SOURCE TARGET")
    main(Path(sys.argv[1]), Path(sys.argv[2]))
