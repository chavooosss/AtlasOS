#!/usr/bin/env python3
"""Trace the approved Seedream logo into clean, two-color SVG paths.

Optional regeneration helper; requires Pillow, NumPy, and OpenCV. The original
PNG is preserved as the visual source of truth. This helper is not used by the
ISO build, so image-processing dependencies are not added to the live system.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


PROJECT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = PROJECT_ROOT / "assets/branding/atlasos-logo-seedream-master.png"
DEFAULT_OUTPUT = PROJECT_ROOT / "assets/branding/atlasos-emblem-traced.svg"
NAVY = "#102e63"
CYAN = "#0b9bdd"


def traced_path(mask: np.ndarray) -> str:
    contours, _ = cv2.findContours(mask, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    path_parts: list[str] = []
    for contour in contours:
        if abs(cv2.contourArea(contour)) < 24:
            continue
        simplified = cv2.approxPolyDP(contour, 1.1, True).reshape(-1, 2)
        if len(simplified) < 3:
            continue
        path_parts.append("M" + " L".join(f"{x},{y}" for x, y in simplified) + " Z")
    return " ".join(path_parts)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()

    source = np.asarray(Image.open(args.source).convert("RGB"), dtype=np.uint8)
    # This crop contains the emblem only; the original title is typeset
    # separately for the horizontal AtlasOS system wordmark.
    left, top, right, bottom = 395, 260, 1655, 1385
    crop = source[top:bottom, left:right].astype(np.float32)
    corner_pixels = np.concatenate(
        (crop[:24, :24].reshape(-1, 3), crop[:24, -24:].reshape(-1, 3),
         crop[-24:, :24].reshape(-1, 3), crop[-24:, -24:].reshape(-1, 3))
    )
    background = corner_pixels.mean(axis=0)

    # Estimate how much each pixel belongs to the two blue fills over the
    # generated near-white background. This preserves antialiased boundaries.
    palette = (np.array([13.0, 45.0, 99.0]), np.array([10.0, 145.0, 213.0]))
    coverages: list[np.ndarray] = []
    errors: list[np.ndarray] = []
    for color in palette:
        direction = background - color
        coverage = np.clip(((background - crop) @ direction) / (direction @ direction), 0, 1)
        fitted = background - coverage[..., None] * direction
        coverages.append(coverage)
        errors.append(np.sqrt(np.sum((crop - fitted) ** 2, axis=2)))
    selected = np.argmin(np.stack(errors), axis=0)
    best_coverage = np.take_along_axis(np.stack(coverages), selected[None, ...], axis=0)[0]
    best_error = np.take_along_axis(np.stack(errors), selected[None, ...], axis=0)[0]

    class_masks = []
    for color_index in range(2):
        mask = ((selected == color_index) & (best_coverage > 0.18) & (best_error < 60)).astype(np.uint8) * 255
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8))
        class_masks.append(mask)

    all_mask = cv2.bitwise_or(class_masks[0], class_masks[1])
    ys, xs = np.where(all_mask > 0)
    pad = 18
    x0, y0 = max(0, int(xs.min()) - pad), max(0, int(ys.min()) - pad)
    x1, y1 = min(all_mask.shape[1], int(xs.max()) + pad + 1), min(all_mask.shape[0], int(ys.max()) + pad + 1)
    bounds = (x0, y0, x1, y1)
    width, height = x1 - x0, y1 - y0
    paths = [traced_path(mask[y0:y1, x0:x1]) for mask in class_masks]

    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" role="img" aria-label="AtlasOS pusula amblemi">
  <title>AtlasOS amblemi</title>
  <path id="atlas-cyan" d="{paths[1]}" fill="{CYAN}" fill-rule="evenodd"/>
  <path id="atlas-navy" d="{paths[0]}" fill="{NAVY}" fill-rule="evenodd"/>
</svg>
'''
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(svg, encoding="utf-8")
    print(f"Wrote {args.output} (viewBox {width}x{height}; crop {bounds})")


if __name__ == "__main__":
    main()
