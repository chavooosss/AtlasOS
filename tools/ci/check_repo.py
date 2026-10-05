#!/usr/bin/env python3
"""Fast source-tree, publication-manifest, version, and public-doc checks."""
from __future__ import annotations

import argparse
import fnmatch
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[2]
MANIFEST_PATH = ROOT / "docs/project/first-commit-manifest.json"
PUBLIC_DOCS = (
    "README.md",
    "CHANGELOG.md",
    "ROADMAP.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "docs/README.md",
    "docs/architecture/overview.md",
    "docs/architecture/source-map.md",
    "docs/build/README.md",
    "docs/build/integrity.md",
    "docs/legal/third-party-inventory.md",
    "docs/legal/project-license-scope.md",
    "docs/legal/package-distribution-policy.md",
    "docs/legal/third-party-repositories.md",
    "docs/legal/brand-use-review.md",
    "docs/legal/ai-generated-assets.md",
    "docs/legal/asset-provenance-attestation.md",
    "docs/legal/ai-provider-terms-matrix.md",
    "docs/project/status.md",
    "docs/project/publication-manifest.md",
    "docs/project/privacy-inventory.md",
    "docs/project/history-roadmap.md",
    "docs/testing/README.md",
    "docs/validation/physical-0.6.2.md",
    "docs/validation/release-integrity.md",
    "docs/development/ci.md",
    "docs/release/README.md",
    "docs/release/versioning.md",
    "docs/release/artifact-policy.md",
    "docs/release/validation-policy.md",
    "docs/release/checklist.md",
    "docs/release/process.md",
    "docs/release/release-notes-0.6.2.md",
    "docs/release/github-release-0.6.2.md",
    "docs/release/third-party-notices.md",
    "docs/release/decisions/0001-first-public-release.md",
)
PATH_LEAKS = re.compile(r"(?i)(?:C:\\Users\\[^\\\s]+\\|C:\\[^\\\s]+\\|/home/[^/\s]+/|/mnt/[cd]/)")
FORBIDDEN_ROOTS = {"build", "dist", "binary", "chroot", "target"}
PRIVATE_PARTS = {".codex", ".cursor", ".agents", "__pycache__", "node_modules"}
GENERATED_PARTS = {"dist", "binary", "chroot", "target", "diagnostics", "raw-diagnostics"}
FORBIDDEN_SUFFIXES = {
    ".iso", ".img", ".efi", ".squashfs", ".qcow2", ".vdi", ".vmdk",
    ".vhd", ".vhdx", ".ova", ".ovf", ".vbox", ".vbox-prev", ".vmem",
    ".vmsd", ".vmsn", ".vmsw", ".nvram", ".raw", ".ppm", ".zip",
}
FORBIDDEN_CLAIMS = (
    re.compile(r"(?i)\bproduction[- ]ready\b"),
    re.compile(r"(?i)\bofficial\s+MEB\s+integration\b"),
    re.compile(r"(?i)\bSecure Boot\s+(?:is\s+)?supported\b"),
    re.compile(r"(?i)\ball\s+smart\s+boards\s+(?:are\s+)?supported\b"),
    re.compile(r"(?i)\bLegacy BIOS\s+(?:is\s+)?supported\b"),
)


def fail(message: str, errors: list[str]) -> None:
    errors.append(message)


def manifest_patterns(values: list[str]) -> list[str]:
    patterns = []
    for value in values:
        item = value.split(" (", 1)[0]
        item = re.sub(r"\s+(?:source only|from Git history)$", "", item)
        if item and not item.startswith(("root ", "every ", "temporary/", "VM ")):
            patterns.append(item)
    return patterns


def manifest_source_files(manifest: dict) -> set[str]:
    files: set[str] = set()
    excluded = manifest_patterns(manifest.get("sets", {}).get("EXCLUDE", []))
    for pattern in manifest_patterns(manifest["sets"]["INCLUDE"]):
        matches = {path for path in ROOT.glob(pattern) if path.is_file()}
        # pathlib's handling of a trailing ** differs across supported Python
        # versions. Expand directory-only matches explicitly so CI and local
        # publication checks resolve the same candidate set.
        if pattern.endswith("/**"):
            base = ROOT / pattern[:-3]
            if base.is_dir():
                matches.update(path for path in base.rglob("*") if path.is_file())
        file_matches = sorted(matches)
        if not file_matches:
            raise ValueError(f"INCLUDE pattern has no source file: {pattern}")
        for path in file_matches:
            relative = path.relative_to(ROOT).as_posix()
            if not any(fnmatch.fnmatchcase(relative, excluded_pattern) for excluded_pattern in excluded):
                files.add(relative)
    return files


def git_index_files() -> list[str] | None:
    result = subprocess.run(
        ["git", "ls-files", "--cached", "-z"],
        cwd=ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if result.returncode != 0:
        return None
    return [item.decode("utf-8", "surrogateescape") for item in result.stdout.split(b"\0") if item]


def check_file_policy(files: list[str], errors: list[str]) -> None:
    for relative in files:
        path = Path(relative)
        parts = {part.lower() for part in path.parts}
        suffix = path.suffix.lower()
        root = path.parts[0].lower() if path.parts else ""
        if root in FORBIDDEN_ROOTS:
            fail(f"generated root path must not be in Git: {relative}", errors)
        if parts & PRIVATE_PARTS:
            fail(f"private/cache directory must not be in Git: {relative}", errors)
        if root not in FORBIDDEN_ROOTS and parts & GENERATED_PARTS:
            fail(f"generated/raw-data directory must not be in Git: {relative}", errors)
        if suffix in FORBIDDEN_SUFFIXES:
            fail(f"generated/release artifact must not be in Git: {relative}", errors)
        if "diagnostic" in path.name.lower() and suffix in {".zip", ".tar", ".gz"}:
            fail(f"raw diagnostic archive must not be in Git: {relative}", errors)
        if path.is_file():
            size = path.stat().st_size
            if size > 50 * 1024 * 1024:
                fail(f"tracked file exceeds the 50 MiB hard limit: {relative} ({size} bytes)", errors)
            elif size > 10 * 1024 * 1024:
                print(f"WARN tracked source candidate exceeds 10 MiB: {relative} ({size} bytes)")

def check_manifest_and_version(errors: list[str]) -> set[str]:
    try:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        fail(f"first-commit manifest is not valid JSON: {exc}", errors)
        return set()

    version = (ROOT / "VERSION").read_text(encoding="ascii").strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+(?:[-.][A-Za-z0-9.-]+)?", version):
        fail("VERSION is not a valid dotted release version", errors)
    if manifest.get("project_version") != version:
        fail(f"manifest project_version disagrees with VERSION ({version})", errors)
    license_path = ROOT / "LICENSE"
    if not license_path.is_file() or "MIT License" not in license_path.read_text(encoding="utf-8"):
        fail("root MIT LICENSE is missing or malformed", errors)

    inventory_path = ROOT / "docs/legal/asset-inventory.json"
    try:
        asset_inventory = json.loads(inventory_path.read_text(encoding="utf-8"))
        allowed_asset_statuses = {"OWNED", "UPSTREAM-LICENSED", "CLEARED", "NEEDS-REVIEW", "EXCLUDE-FROM-PUBLICATION", "AI-GENERATED-CLEARED"}
        for asset in asset_inventory.get("assets", []):
            if asset.get("owner_status") not in allowed_asset_statuses or asset.get("redistribution_status") not in allowed_asset_statuses:
                fail(f"invalid asset rights status for {asset.get('path', '<unknown>')}", errors)
            if asset.get("redistribution_status") == "AI-GENERATED-CLEARED":
                required_asset_fields = (
                    "creation_method", "provider", "provider_terms_status",
                    "third_party_content_status", "publication_status",
                )
                missing_fields = [field for field in required_asset_fields if not asset.get(field)]
                if missing_fields:
                    fail(f"AI-cleared asset lacks provenance fields {missing_fields}: {asset.get('path', '<unknown>')}", errors)
    except (OSError, json.JSONDecodeError, TypeError) as exc:
        fail(f"asset inventory is invalid: {exc}", errors)

    includes = manifest.get("sets", {}).get("INCLUDE", [])
    required = {".github/**", "tools/ci/**", "docs/development/ci.md", "docs/release/**", "tests/test_release_metadata.py"}
    if not required.issubset(set(includes)):
        fail("first-commit manifest does not include all G5 infrastructure paths", errors)
    try:
        source_files = manifest_source_files(manifest)
    except (KeyError, TypeError, ValueError) as exc:
        fail(f"first-commit manifest source paths are invalid: {exc}", errors)
        source_files = set()
    critical_sources = {
        "LICENSE",
        "docs/legal/project-license-scope.md",
        "docs/legal/asset-inventory.json",
        "docs/legal/package-distribution-policy.md",
        "docs/legal/third-party-repositories.md",
        "docs/legal/brand-use-review.md",
        "docs/project/first-commit-manifest.json",
        "tools/release/package_inventory.py",
        "tests/test_distribution_policy.py",
        "tests/test_package_inventory.py",
        ".github/workflows/ci.yml",
        ".github/workflows/uefi-check.yml",
        "docs/development/ci.md",
        "iso/check-build-env.sh",
        "iso/update-embedded-manifest.py",
        "tests/test_build_safety.py",
        "tests/test_embedded_manifest.py",
        "atlas-boot/Cargo.lock",
        "docs/release/README.md",
        "docs/release/release-notes-0.6.2.md",
        "docs/release/decisions/0001-first-public-release.md",
        "tests/test_release_metadata.py",
        "docs/release/release-manifest-0.6.2.json",
    }
    missing_critical = critical_sources - source_files
    if missing_critical:
        fail(f"first-commit manifest is missing critical source paths: {sorted(missing_critical)}", errors)

    for relative in ("README.md", "CHANGELOG.md", "SECURITY.md", "docs/project/status.md", "docs/build/README.md"):
        content = (ROOT / relative).read_text(encoding="utf-8")
        if version not in content:
            fail(f"current authoritative document does not mention VERSION {version}: {relative}", errors)
    changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8").splitlines()
    sections = [line for line in changelog if line.startswith("## ")]
    release_sections = [line for line in sections if re.match(r"^##\s+\[?\d+\.\d+\.\d+", line)]
    if not release_sections or not re.match(rf"^##\s+\[?{re.escape(version)}(?:\]|\s|$)", release_sections[0]):
        fail("CHANGELOG latest released section does not match VERSION", errors)
    return source_files


def check_future_browser_policy(errors: list[str]) -> None:
    active_paths = (
        "config/package-lists/atlasos-live.list.chroot",
        "iso/build-atlasos.sh",
        "config/hooks/normal/010-atlasos-branding.hook.chroot",
        "config/includes.chroot/usr/local/bin/atlasos-browser",
        "config/includes.chroot/usr/local/bin/atlasos-open-request",
        "config/includes.chroot/usr/local/share/atlasos/ui/Main.qml",
    )
    forbidden = re.compile(r"(?i)(?:google-chrome(?:-stable)?|dl\.google\.com)")
    for relative in active_paths:
        path = ROOT / relative
        if not path.is_file():
            fail(f"active future-build browser policy file is missing: {relative}", errors)
            continue
        if forbidden.search(path.read_text(encoding="utf-8", errors="replace")):
            fail(f"Chrome vendor package/repository reference found in active future-build configuration: {relative}", errors)


def check_public_docs(errors: list[str]) -> None:
    link_pattern = re.compile(r"!?\[[^\]]*\]\(([^)]+)\)")
    for relative in PUBLIC_DOCS:
        path = ROOT / relative
        if not path.is_file():
            fail(f"authoritative public doc is missing: {relative}", errors)
            continue
        content = path.read_text(encoding="utf-8")
        if PATH_LEAKS.search(content):
            fail(f"local machine path found in public doc: {relative}", errors)
        for forbidden in FORBIDDEN_CLAIMS:
            for match in forbidden.finditer(content):
                sentence = content[max(0, content.rfind("\n", 0, match.start()) + 1):content.find("\n", match.end()) if "\n" in content[match.end():] else len(content)]
                if re.search(r"(?i)\b(?:not|never|unsupported|unvalidated|no longer)\b", sentence):
                    continue
                fail(f"review outdated/unsupported claim in {relative}: {match.group(0)}", errors)

        for match in link_pattern.finditer(content):
            target = match.group(1).strip()
            if target.startswith("<") and ">" in target:
                target = target[1:target.index(">")]
            else:
                target = target.split(None, 1)[0]
            parsed = urlsplit(target)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            decoded = unquote(parsed.path)
            if decoded.startswith("/") or re.match(r"^[A-Za-z]:", decoded):
                fail(f"absolute local link found in public doc {relative}: {decoded}", errors)
                continue
            linked = (path.parent / decoded).resolve()
            if not linked.exists():
                fail(f"broken relative Markdown link in {relative}: {parsed.path}", errors)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-tree", action="store_true", help="check manifest source candidates when this checkout has no Git index")
    args = parser.parse_args()
    errors: list[str] = []
    source_files = check_manifest_and_version(errors)
    check_public_docs(errors)
    check_future_browser_policy(errors)
    files = git_index_files()
    if files is None:
        if not args.source_tree:
            fail("Git index unavailable; pass --source-tree for pre-publication local validation", errors)
        else:
            files = sorted(source_files)
            print("INFO no Git index; repository policy evaluated against first-commit INCLUDE candidates")
    if files is not None:
        check_file_policy(files, errors)
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        print(f"Repository checks failed: {len(errors)} issue(s)", file=sys.stderr)
        return 1
    print(f"Repository checks passed ({len(files or [])} paths; {len(PUBLIC_DOCS)} public docs checked).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
