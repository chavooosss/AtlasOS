#!/usr/bin/env python3
"""Build isolated GRUB EFI payloads for Phase 6C D/E/F failure probes."""
from pathlib import Path
import subprocess
import sys


MODULES = "normal part_gpt part_msdos fat iso9660 search search_fs_file linux"
BASE = """insmod part_gpt
insmod part_msdos
insmod fat
insmod iso9660
insmod search_fs_file
insmod linux
search --no-floppy --file --set=root /casper/vmlinuz
"""
ARGS = "boot=live config boot=casper username=atlas hostname=atlasos locales=tr_TR.UTF-8 keyboard-layouts=tr keyboard-configuration/layoutcode=tr console-setup/layoutcode=tr timezone=Europe/Istanbul quiet splash vt.handoff=7"


def build(out: Path, name: str, config: str | None) -> None:
    output = out / f"{name}.efi"
    command = [
        "grub-mkstandalone", "--format=x86_64-efi",
        "--directory=/usr/lib/grub/x86_64-efi",
        f"--install-modules={MODULES}", "--locales=", "--fonts=", "--themes=",
        f"--output={output}",
    ]
    if config is not None:
        cfg = out / f"{name}.cfg"
        cfg.write_text(config, encoding="utf-8")
        command.append(f"boot/grub/grub.cfg={cfg}")
    subprocess.run(command, check=True)
    subprocess.run(["grub-file", "--is-x86_64-efi", str(output)], check=True)
    print(f"{name}: {output.stat().st_size} bytes")


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit("usage: build_phase6c_failure_variants.py OUTPUT_DIR")
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    build(out, "D-no-embedded-config", None)
    build(out, "E-invalid-kernel", BASE + f"linux /casper/missing-vmlinuz {ARGS}\ninitrd /casper/initrd.img\nboot\n")
    build(out, "F-invalid-initrd", BASE + f"linux /casper/vmlinuz {ARGS}\ninitrd /casper/missing-initrd.img\nboot\n")


if __name__ == "__main__":
    main()
