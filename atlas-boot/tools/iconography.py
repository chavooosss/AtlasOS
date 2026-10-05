"""Original Atlas Boot Manager icon geometry and review contact sheets."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ICON_SIZE = 64
SUPERSAMPLE = 4
LABELS = ("LIVE", "ADVANCED", "DISK", "TOOLS", "POWER")
ACCENTS = (
    (25, 112, 245),
    (94, 135, 190),
    (20, 156, 163),
    (83, 113, 160),
    (239, 56, 69),
)


def render_icon_mask(index: int, iteration: int = 2, size: int = ICON_SIZE) -> Image.Image:
    """Return a project-owned monochrome icon with transparent padding."""
    if index not in range(5):
        raise ValueError(f"icon index out of range: {index}")
    if iteration not in (1, 2):
        raise ValueError(f"unknown design iteration: {iteration}")
    scale = SUPERSAMPLE
    canvas = ICON_SIZE * scale
    mask = Image.new("L", (canvas, canvas), 0)
    draw = ImageDraw.Draw(mask)

    # Iteration 1 was a first coherent sketch. Iteration 2 slightly strengthens
    # the line weight and resolves the controls, disk divider, and wrench jaws.
    stroke = (5 if iteration == 1 else 5.5) * scale

    def xy(points):
        return [(round(x * scale), round(y * scale)) for x, y in points]

    def line(points, width=stroke):
        pts = xy(points)
        w = round(width)
        draw.line(pts, fill=255, width=w, joint="curve")
        radius = w // 2
        for px, py in (pts[0], pts[-1]):
            draw.ellipse((px-radius, py-radius, px+radius, py+radius), fill=255)

    def ellipse(box, width=stroke, fill=None):
        x0, y0, x1, y1 = box
        draw.ellipse((round(x0*scale), round(y0*scale),
                      round(x1*scale), round(y1*scale)),
                     outline=255 if fill is None else None,
                     fill=fill, width=round(width))

    if index == 0:  # Forward/start arrow, with a small Atlas compass star.
        line([(17, 47), (45, 19)], 6.2 * scale)
        line([(30, 20), (45, 19), (44, 34)], 6.2 * scale)
        star = xy([(19, 10), (21, 16), (27, 18), (21, 20),
                   (19, 26), (17, 20), (11, 18), (17, 16)])
        draw.polygon(star, fill=255)
    elif index == 1:  # Three adjustable controls.
        for y, knob_x in ((16, 26), (32, 41), (48, 22)):
            if iteration == 1:
                line([(12, y), (52, y)], 4.8 * scale)
            else:
                line([(12, y), (knob_x-7, y)], 4.8 * scale)
                line([(knob_x+7, y), (52, y)], 4.8 * scale)
            radius = 5 if iteration == 1 else 5.5
            box = (round((knob_x-radius)*scale), round((y-radius)*scale),
                   round((knob_x+radius)*scale), round((y+radius)*scale))
            if iteration == 1:
                draw.ellipse(box, fill=0, outline=255, width=round(4.8*scale))
            else:
                draw.ellipse(box, fill=255, outline=255)
                inner = 2.4
                draw.ellipse((round((knob_x-inner)*scale), round((y-inner)*scale),
                              round((knob_x+inner)*scale), round((y+inner)*scale)),
                             fill=0)
    elif index == 2:  # Storage drive body, divider, one status light.
        radius = (7 if iteration == 1 else 8) * scale
        draw.rounded_rectangle((12*scale, 15*scale, 52*scale, 49*scale),
                               radius=radius, outline=255, width=round(stroke))
        line([(16, 34), (48, 34)], 4.8 * scale)
        status_radius = (2 if iteration == 1 else 2.6) * scale
        draw.ellipse((round(42*scale-status_radius), round(40*scale-status_radius),
                      round(42*scale+status_radius), round(40*scale+status_radius)),
                     fill=255)
    elif index == 3:  # One open-end wrench, not crossed tools.
        # Iteration 1 used an undersized open jaw; iteration 2 broadens its
        # mouth and shifts the shaft for a clearer wrench silhouette.
        if iteration == 1:
            draw.arc((35*scale, 9*scale, 57*scale, 31*scale),
                     start=45, end=315, fill=255, width=round(stroke))
            line([(44, 24), (18, 50)], 5.7 * scale)
            ellipse((13, 45, 23, 55), width=stroke)
        else:
            draw.arc((34*scale, 8*scale, 58*scale, 32*scale),
                     start=58, end=302, fill=255, width=round(stroke))
            line([(43, 25), (18, 50)], 6 * scale)
            ellipse((12, 44, 24, 56), width=stroke)
    else:  # Universal power ring and vertical stroke, with a clean top gap.
        outer = (14*scale, 14*scale, 50*scale, 50*scale)
        draw.ellipse(outer, outline=255, width=round(stroke))
        # Clear a short top segment before drawing the centered power stroke.
        draw.rectangle((27*scale, 9*scale, 37*scale, 21*scale), fill=0)
        line([(32, 9), (32, 33)], 5.5 * scale)

    return mask.resize((size, size), Image.Resampling.LANCZOS)


def _scaled(mask: Image.Image, width: int) -> Image.Image:
    return mask.resize((width, width), Image.Resampling.LANCZOS)


def create_contact_sheet(path: Path, iteration: int) -> None:
    """Create enlarged, 1366-sized, and 1920-sized actual UI comparisons."""
    width, height = 1580, 740
    sheet = Image.new("RGB", (width, height), (244, 248, 253))
    d = ImageDraw.Draw(sheet)
    title_font = ImageFont.truetype("arial.ttf", 30)
    label_font = ImageFont.truetype("arial.ttf", 20)
    note_font = ImageFont.truetype("arial.ttf", 15)
    d.text((38, 24), f"ATLAS BOOT ICON FAMILY — ITERATION {iteration}",
           font=title_font, fill=(16, 43, 86))
    columns = [130 + i*300 for i in range(5)]

    def place_row(y, icon_width, caption, enlarged=False):
        d.text((38, y), caption, font=label_font, fill=(37, 73, 120))
        for i, x in enumerate(columns):
            d.text((x, y + 25), LABELS[i], font=label_font, fill=(16, 43, 86), anchor="mt")
            icon = render_icon_mask(i, iteration, ICON_SIZE)
            shown = _scaled(icon, icon_width)
            if enlarged:
                bg_size = icon_width + 32
            else:
                bg_size = round(icon_width * 78 / 52)
            box = (x - bg_size//2, y + 52, x + bg_size//2, y + 52 + bg_size)
            d.rounded_rectangle(box, radius=max(12, bg_size//5), fill=ACCENTS[i])
            layer = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
            layer.alpha_composite(Image.merge("RGBA", (
                Image.new("L", shown.size, 255),
                Image.new("L", shown.size, 255),
                Image.new("L", shown.size, 255),
                shown,
            )), (x - icon_width//2, y + 52 + (bg_size-icon_width)//2))
            sheet.paste(layer, (0, 0), layer)

    place_row(72, 160, "ENLARGED REVIEW", enlarged=True)
    place_row(336, 43, "1366×768 — 52 logical px renders at 42.5 px")
    place_row(478, 60, "1920×1080 — 52 logical px renders at 59.7 px")
    d.text((38, 690), "White symbols use semantic accent containers for family comparison; final UI preserves existing enabled/disabled tinting.",
           font=note_font, fill=(90, 113, 143))
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path, optimize=True)

