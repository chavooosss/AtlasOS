#!/usr/bin/env python3
"""Render a pre-integration contact sheet for either icon design iteration."""
from pathlib import Path
import argparse
from iconography import create_contact_sheet

parser = argparse.ArgumentParser()
parser.add_argument("--iteration", type=int, choices=(1, 2), required=True)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
out = root / "dist/validation/atlas-boot/phase6/finalvisual/icon-contact-sheet" / f"iteration-{args.iteration}.png"
create_contact_sheet(out, args.iteration)
print(out)
