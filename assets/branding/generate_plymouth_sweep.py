#!/usr/bin/env python3
"""Generate the lightweight, deterministic Plymouth orbit-light frames."""

from pathlib import Path
import math
import numpy as np

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[2]
THEME_DIR = ROOT / "config/includes.chroot/usr/share/plymouth/themes/atlasos"
FRAME_COUNT = 24
SIZE = 512
SCALE = 3
CYAN = (75, 220, 255)
PREVIEW = ROOT / "dist/validation/atlasos-plymouth-logo-animation-preview.gif"


def main() -> None:
    THEME_DIR.mkdir(parents=True, exist_ok=True)
    high_size = SIZE * SCALE
    center = high_size // 2
    radius = 226 * SCALE
    box = (center - radius, center - radius, center + radius, center + radius)

    for index in range(FRAME_COUNT):
        base = Image.new("RGBA", (high_size, high_size), (0, 0, 0, 0))
        draw = ImageDraw.Draw(base, "RGBA")
        draw.ellipse(box, outline=(*CYAN, 17), width=2 * SCALE)

        start = index * 360 / FRAME_COUNT - 82
        end = index * 360 / FRAME_COUNT
        draw.arc(box, start=start, end=end, fill=(*CYAN, 44), width=18 * SCALE)
        glow = base.filter(ImageFilter.GaussianBlur(12 * SCALE))

        core = Image.new("RGBA", base.size, (0, 0, 0, 0))
        ImageDraw.Draw(core, "RGBA").arc(
            box, start=start, end=end, fill=(*CYAN, 190), width=4 * SCALE
        )
        head_angle = end * math.pi / 180
        head_x = center + int(radius * math.cos(head_angle))
        head_y = center + int(radius * math.sin(head_angle))
        head_r = 5 * SCALE
        ImageDraw.Draw(core, "RGBA").ellipse(
            (head_x - head_r, head_y - head_r, head_x + head_r, head_y + head_r),
            fill=(225, 250, 255, 220),
        )

        frame = Image.alpha_composite(glow, base)
        frame = Image.alpha_composite(frame, core)
        frame = frame.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
        frame.save(THEME_DIR / f"atlas-sweep-{index:02d}.png", optimize=True)

    logo_path = THEME_DIR / "atlas-logo.png"
    if logo_path.exists():
        frames = []
        width, height = 960, 540
        y = np.linspace(0, 1, height, dtype=np.float32)[:, None, None]
        top = np.array([7, 28, 49], dtype=np.float32)[None, None, :]
        bottom = np.array([18, 65, 98], dtype=np.float32)[None, None, :]
        background = np.repeat(top * (1 - y) + bottom * y, width, axis=1)
        yy, xx = np.mgrid[0:height, 0:width]
        glow = np.clip(1 - np.sqrt(((xx - width * .5) / 440) ** 2 + ((yy - height * .43) / 360) ** 2), 0, 1)
        background += glow[..., None] * np.array([0, 22, 30], dtype=np.float32)
        background = Image.fromarray(np.clip(background, 0, 255).astype(np.uint8), "RGB").convert("RGBA")

        logo = Image.open(logo_path).convert("RGBA")
        logo_h = 378
        logo_w = round(logo.width * logo_h / logo.height)
        logo = logo.resize((logo_w, logo_h), Image.Resampling.LANCZOS)
        sweep_size = round(logo_w * 1.08)
        for index in range(FRAME_COUNT):
            frame_path = THEME_DIR / f"atlas-sweep-{index:02d}.png"
            sweep = Image.open(frame_path).convert("RGBA").resize((sweep_size, sweep_size), Image.Resampling.LANCZOS)
            canvas = background.copy()
            logo_y = round(height*.46-logo_h/2)
            canvas.alpha_composite(sweep, ((width-sweep_size)//2, round(logo_y+logo_h*.37-sweep_size/2)))
            canvas.alpha_composite(logo, ((width-logo_w)//2, logo_y))
            logo_alpha = min(1.0, (index + 1) / 12.0)
            if logo_alpha < 1:
                logo_layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
                faded_logo = logo.copy()
                faded_logo.putalpha(faded_logo.getchannel("A").point(lambda value: round(value * logo_alpha)))
                logo_layer.alpha_composite(faded_logo, ((width-logo_w)//2, (height-logo_h)//2))
                canvas = background.copy()
                canvas.alpha_composite(sweep, ((width-sweep_size)//2, round(logo_y+logo_h*.37-sweep_size/2)))
                canvas.alpha_composite(logo_layer)
            frames.append(canvas.convert("RGB").quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG))
        PREVIEW.parent.mkdir(parents=True, exist_ok=True)
        frames[0].save(PREVIEW, save_all=True, append_images=frames[1:], duration=80, loop=0, optimize=True)
        print(f"Rendered animation preview: {PREVIEW}")
    print(f"Generated {FRAME_COUNT} orbit-light frames in {THEME_DIR}")


if __name__ == "__main__":
    main()
