#!/usr/bin/env python3
"""Build only the five Phase 6A.1 UEFI icon masks, preserving other assets."""
from pathlib import Path
from iconography import render_icon_mask

root = Path(__file__).resolve().parents[1]
out = root / "assets/generated"
out.mkdir(parents=True, exist_ok=True)
for index in range(5):
    target = out / f"icon-{index}.alpha"
    mask = render_icon_mask(index, iteration=2)
    bounds = mask.getbbox()
    if bounds is None or bounds[0] < 4 or bounds[1] < 4 or bounds[2] > 60 or bounds[3] > 60:
        raise SystemExit(f"unsafe icon bounds for {index}: {bounds}")
    target.write_bytes(mask.tobytes())
    print(f"{target.name}: {target.stat().st_size} bytes")
