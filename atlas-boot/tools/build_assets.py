#!/usr/bin/env python3
"""Build compact, deterministic raw UEFI assets from the checked-in sources.

Requires Pillow 12.x. The EFI application never decodes PNG or TTF files.
"""
from pathlib import Path
from PIL import Image, ImageFont, ImageDraw
from iconography import render_icon_mask

ROOT = Path(__file__).resolve().parents[1]
FONT = ROOT / "fonts/source/UbuntuSans.ttf"
LANDSCAPE = ROOT / "assets/source/atlas-boot-landscape.png"
OUT = ROOT / "assets/generated"
OUT.mkdir(parents=True, exist_ok=True)

# The UI uses text up to this set plus all Turkish Latin letters.
chars = set(chr(i) for i in range(32, 127))
chars.update("ÇĞİÖŞÜçğıöşü↑↓·’–×")
chars = sorted(chars, key=ord)
atlas_w = 768
atlas_heights = (512, 512, 512, 1024, 1280)
font_raster_scale = 2
glyph_pad = 4
sizes = (16, 20, 28, 42, 52)
entries = []

for face, size in enumerate(sizes):
    variation = ("Regular", "Regular", "SemiBold", "Bold", "Bold")[face]
    font = ImageFont.truetype(str(FONT), size=size)
    font.set_variation_by_name(variation)
    raster_font = ImageFont.truetype(str(FONT), size=size * font_raster_scale)
    raster_font.set_variation_by_name(variation)
    atlas_h = atlas_heights[face]
    atlas = Image.new("L", (atlas_w, atlas_h), 0)
    draw = ImageDraw.Draw(atlas)
    x = y = row_h = 0
    for ch in chars:
        bbox = draw.textbbox((0, 0), ch, font=font, stroke_width=0)
        logical_left, logical_top, logical_right, logical_bottom = bbox
        raster_bbox = draw.textbbox((0, 0), ch, font=raster_font, stroke_width=0)
        raster_left, raster_top, raster_right, raster_bottom = raster_bbox
        raster_w = max(1, raster_right - raster_left)
        raster_h = max(1, raster_bottom - raster_top)
        cell_w = raster_w + glyph_pad * 2
        cell_h = raster_h + glyph_pad * 2
        if x + cell_w > atlas_w:
            x = 0
            y += row_h + glyph_pad
            row_h = 0
        if y + cell_h > atlas_h:
            raise SystemExit(f"Glyph atlas overflow at {size}px for {ch!r}")
        # Store 2x antialiased source coverage with four pixels of clear padding.
        draw.text((x + glyph_pad - raster_left, y + glyph_pad - raster_top),
                  ch, font=raster_font, fill=255)
        advance = int(round(font.getlength(ch)))
        entries.append((face, ord(ch), x + glyph_pad, y + glyph_pad,
                        raster_w, raster_h,
                        max(1, logical_right - logical_left),
                        max(1, logical_bottom - logical_top),
                        logical_left, logical_top, max(1, advance)))
        x += cell_w + glyph_pad
        row_h = max(row_h, cell_h)
    (OUT / f"glyphs-{size}.alpha").write_bytes(atlas.tobytes())

expected_atlases = {f"glyphs-{size}.alpha" for size in sizes}
for stale in OUT.glob("glyphs-*.alpha"):
    if stale.name not in expected_atlases:
        stale.unlink()

# The source is the exact, separately reviewed landscape crop. The menu is
# drawn on top of it by the shared renderer.
landscape = Image.open(LANDSCAPE).convert("RGBA")
if landscape.size != (1672, 275):
    raise SystemExit(f"Unexpected Atlas Boot landscape dimensions: {landscape.size}")
(OUT / "landscape.rgba").write_bytes(landscape.tobytes())

# Create a project-owned boot mark from AtlasOS's A/book/star visual language.
# It is intentionally simpler than the detailed dashboard lockup; the wordmark
# and slogan are rendered separately with the antialiased text pipeline.
mark_scale = 4
mark_size = 256
S = mark_size * mark_scale
mask = Image.new("L", (S, S), 0)
d = ImageDraw.Draw(mask)
def pts(values):
    return [(int(x * mark_scale), int(y * mark_scale)) for x, y in values]
def line(values, width, fill=255):
    scaled = pts(values)
    w = width * mark_scale
    d.line(scaled, fill=fill, width=w, joint="curve")
    radius = w // 2
    for px, py in (scaled[0], scaled[-1]):
        d.ellipse((px-radius, py-radius, px+radius, py+radius), fill=fill)

# Bold A silhouette and a restrained open-book base.
line(((45, 183), (126, 43), (210, 183)), 31)
line(((82, 128), (171, 128)), 22)
line(((34, 193), (75, 187), (111, 194), (128, 207)), 10)
line(((222, 193), (181, 187), (145, 194), (128, 207)), 10)
# Four-point compass star above the A echoes Atlas's canonical navigation mark.
d.polygon(pts(((128, 12), (138, 31), (157, 41), (138, 51),
               (128, 70), (118, 51), (99, 41), (118, 31))), fill=255)
mask = mask.resize((mark_size, mark_size), Image.Resampling.LANCZOS)
mark = Image.new("RGBA", (mark_size, mark_size), (0, 0, 0, 0))
pix = mark.load()
mp = mask.load()
for yy in range(mark_size):
    for xx in range(mark_size):
        alpha = mp[xx, yy]
        if alpha:
            # Atlas cyan-to-blue vertical field, blended by antialiased coverage.
            t = yy / max(1, mark_size - 1)
            pix[xx, yy] = (int(32 + 8*t), int(199 - 72*t), int(250 - 20*t), alpha)
(OUT / "boot-mark.rgba").write_bytes(mark.tobytes())
legacy_logo = OUT / "logo.rgba"
if legacy_logo.exists():
    legacy_logo.unlink()

# The standalone icon geometry lives in one source module shared by the
# contact-sheet tool and asset builder. The selected final design is iteration
# 2; UEFI still composites compact supersampled grayscale masks at runtime.
icon_size = 64
for index in range(5):
    (OUT / f"icon-{index}.alpha").write_bytes(
        render_icon_mask(index, iteration=2, size=icon_size).tobytes()
    )
with (ROOT / "src/glyph_metrics.rs").open("w", encoding="utf-8", newline="\n") as f:
    f.write("// Generated by tools/build_assets.py. Do not edit by hand.\n")
    f.write("#[derive(Clone, Copy)]\n")
    f.write("pub struct Glyph {\n")
    for field, kind in (("face", "u8"), ("ch", "char"), ("x", "u16"),
                        ("y", "u16"), ("raster_width", "u8"),
                        ("raster_height", "u8"), ("width", "u8"),
                        ("height", "u8"), ("left", "i8"), ("top", "i8"),
                        ("advance", "u8")):
        f.write(f"    pub {field}: {kind},\n")
    f.write("}\n")
    f.write("pub const GLYPHS: &[Glyph] = &[\n")
    for face, code, x, y, rw, rh, w, h, left, top, adv in entries:
        f.write("    Glyph {\n")
        f.write(f"        face: {face}, ch: '\\u{{{code:x}}}', x: {x}, y: {y},\n")
        f.write(f"        raster_width: {rw}, raster_height: {rh},\n")
        f.write(f"        width: {w}, height: {h}, left: {left}, top: {top}, advance: {adv},\n")
        f.write("    },\n")
    f.write("];\n")
    f.write(f"pub const GLYPH_ATLASES: [&[u8]; {len(sizes)}] = [\n")
    for size in sizes:
        f.write(f'    include_bytes!("../assets/generated/glyphs-{size}.alpha"),\n')
    f.write("];\n")
    heights = ", ".join(map(str, atlas_heights))
    f.write(f"pub const GLYPH_ATLAS_HEIGHTS: [usize; {len(atlas_heights)}] = [{heights}];\n")

print(f"generated {len(entries)} glyphs across {len(sizes)} raster sizes")
print(f"glyph atlases {atlas_w}x{atlas_heights}; 2x font rasterization; padding={glyph_pad}px")
print(f"landscape {landscape.width}x{landscape.height}; raw bytes={len(landscape.tobytes())}")
print(f"boot mark {mark_size}x{mark_size}; raw bytes={len(mark.tobytes())}")
print(f"generated {5 * icon_size * icon_size} antialiased icon-mask pixels")
