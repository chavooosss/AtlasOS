#![cfg_attr(not(feature = "host"), no_std)]

extern crate alloc;

use alloc::vec::Vec;

pub const DESIGN_W: u32 = 1672;
pub const DESIGN_H: u32 = 941;

/// Preferred GOP modes for the classroom displays currently targeted by Atlas.
/// A build-time request is tried first for explicit validation builds; normal
/// builds start with 1080p and fall back to the supported classroom modes.
pub fn gop_mode_preferences(requested: Option<(usize, usize)>) -> [Option<(usize, usize)>; 5] {
    [
        requested,
        Some((1920, 1080)),
        Some((1366, 768)),
        // OVMF's QEMU std-VGA GOP surface is eight-pixel aligned.
        Some((1368, 768)),
        Some((1280, 720)),
    ]
}

pub const GLYPH_ATLAS_W: usize = 768;
pub const LANDSCAPE_W: usize = 1672;
pub const LANDSCAPE_H: usize = 275;
pub const BOOT_MARK_SIZE: usize = 256;
pub const ICON_SIZE: usize = 64;
pub const LANDSCAPE: &[u8] = include_bytes!("../assets/generated/landscape.rgba");
pub const BOOT_MARK: &[u8] = include_bytes!("../assets/generated/boot-mark.rgba");
pub const ICONS: [&[u8]; 5] = [
    include_bytes!("../assets/generated/icon-0.alpha"),
    include_bytes!("../assets/generated/icon-1.alpha"),
    include_bytes!("../assets/generated/icon-2.alpha"),
    include_bytes!("../assets/generated/icon-3.alpha"),
    include_bytes!("../assets/generated/icon-4.alpha"),
];

mod glyph_metrics;
use glyph_metrics::{GLYPH_ATLAS_HEIGHTS, GLYPH_ATLASES, GLYPHS};

pub type Color = [u8; 4];

pub fn text_width(text: &str, face: u8) -> u32 {
    text.chars().fold(0_u32, |width, ch| {
        width.saturating_add(
            GLYPHS
                .iter()
                .find(|glyph| glyph.ch == ch && glyph.face == face.min(4))
                .map_or(18, |glyph| glyph.advance as u32),
        )
    })
}

fn countdown_message(seconds: u32) -> alloc::string::String {
    alloc::format!(
        "{} saniye içinde otomatik olarak başlatılacak...",
        seconds.min(10)
    )
}

fn round_sat(value: f32) -> i32 {
    if value.is_nan() {
        0
    } else if value >= i32::MAX as f32 {
        i32::MAX
    } else if value <= i32::MIN as f32 {
        i32::MIN
    } else {
        libm::roundf(value) as i32
    }
}

fn sample_axis(position: i32, origin: i32, destination: i32, source: usize) -> (usize, usize, u32) {
    let den = 2_i64 * destination as i64;
    let relative = position as i64 - origin as i64;
    let max = (source.saturating_sub(1) as i64) * den;
    let num = ((2 * relative + 1) * source as i64 - destination as i64).clamp(0, max);
    let first = (num / den).min(source.saturating_sub(1) as i64) as usize;
    let second = (first + 1).min(source - 1);
    let fraction = (((num - first as i64 * den) * 256) / den) as u32;
    (first, second, fraction)
}

fn sample_gray_bilinear(
    src: &[u8],
    source_stride: usize,
    source_x: usize,
    source_y: usize,
    region_width: usize,
    region_height: usize,
    x: i32,
    y: i32,
    dest_x: i32,
    dest_y: i32,
    dest_width: usize,
    dest_height: usize,
) -> u8 {
    let (sx0, sx1, fx) = sample_axis(x, dest_x, dest_width as i32, region_width);
    let (sy0, sy1, fy) = sample_axis(y, dest_y, dest_height as i32, region_height);
    let a00 = src[(source_y + sy0) * source_stride + source_x + sx0] as u32;
    let a10 = src[(source_y + sy0) * source_stride + source_x + sx1] as u32;
    let a01 = src[(source_y + sy1) * source_stride + source_x + sx0] as u32;
    let a11 = src[(source_y + sy1) * source_stride + source_x + sx1] as u32;
    let top = a00 * (256 - fx) + a10 * fx;
    let bottom = a01 * (256 - fx) + a11 * fx;
    ((top * (256 - fy) + bottom * fy + 32768) >> 16).min(255) as u8
}

fn glyph_is_within_atlas(glyph: &glyph_metrics::Glyph) -> bool {
    let face = glyph.face as usize;
    face < GLYPH_ATLAS_HEIGHTS.len()
        && glyph.x as usize + glyph.raster_width as usize <= GLYPH_ATLAS_W
        && glyph.y as usize + glyph.raster_height as usize <= GLYPH_ATLAS_HEIGHTS[face]
}

fn clip_line(
    mut x0: i64,
    mut y0: i64,
    mut x1: i64,
    mut y1: i64,
    max_x: i64,
    max_y: i64,
) -> Option<(i64, i64, i64, i64)> {
    const LEFT: u8 = 1;
    const RIGHT: u8 = 2;
    const TOP: u8 = 4;
    const BOTTOM: u8 = 8;
    let code = |x: i64, y: i64| -> u8 {
        let mut c = 0;
        if x < 0 {
            c |= LEFT
        } else if x > max_x {
            c |= RIGHT
        }
        if y < 0 {
            c |= TOP
        } else if y > max_y {
            c |= BOTTOM
        }
        c
    };
    for _ in 0..16 {
        let c0 = code(x0, y0);
        let c1 = code(x1, y1);
        if c0 | c1 == 0 {
            return Some((x0, y0, x1, y1));
        }
        if c0 & c1 != 0 {
            return None;
        }
        let out = if c0 != 0 { c0 } else { c1 };
        let (x, y) = if out & TOP != 0 {
            (
                x0 + (((x1 - x0) as i128) * (-(y0 as i128)) / (y1 - y0) as i128) as i64,
                0,
            )
        } else if out & BOTTOM != 0 {
            (
                x0 + (((x1 - x0) as i128) * (max_y - y0) as i128 / (y1 - y0) as i128) as i64,
                max_y,
            )
        } else if out & RIGHT != 0 {
            (
                max_x,
                y0 + (((y1 - y0) as i128) * (max_x - x0) as i128 / (x1 - x0) as i128) as i64,
            )
        } else {
            (
                0,
                y0 + (((y1 - y0) as i128) * (-(x0 as i128)) / (x1 - x0) as i128) as i64,
            )
        };
        if out == c0 {
            x0 = x;
            y0 = y
        } else {
            x1 = x;
            y1 = y
        }
    }
    None
}

pub mod tokens {
    use super::Color;
    pub const NAVY: Color = [10, 31, 73, 255];
    pub const NAVY_SOFT: Color = [33, 72, 123, 255];
    pub const BLUE: Color = [26, 116, 255, 255];
    pub const CYAN: Color = [39, 190, 255, 255];
    pub const SKY: Color = [239, 247, 255, 255];
    pub const WHITE: Color = [255, 255, 255, 255];
    pub const MUTED: Color = [95, 124, 166, 255];
    pub const LINE: Color = [213, 229, 248, 255];
    pub const RED: Color = [239, 49, 57, 255];
    pub const AMBER: Color = [255, 171, 46, 255];
    pub const VIOLET: Color = [112, 91, 240, 255];
    pub const CARD_RADIUS: i32 = 22;
    pub const ICON_RADIUS: i32 = 16;
    pub const MENU_ROW_H: i32 = 112;
    pub const MENU_GAP: i32 = 10;
    pub const PANEL_PAD: i32 = 26;
}

pub struct Canvas {
    pub width: usize,
    pub height: usize,
    pub pixels: Vec<Color>,
    scale: f32,
    offset_x: f32,
    offset_y: f32,
}

impl Canvas {
    pub fn new(width: usize, height: usize) -> Option<Self> {
        let area = width.checked_mul(height)?;
        if width < 640 || height < 360 || width > 8192 || height > 8192 || area > 16_777_216 {
            return None;
        }
        let scale = (width as f32 / DESIGN_W as f32).min(height as f32 / DESIGN_H as f32);
        let offset_x = (width as f32 - DESIGN_W as f32 * scale) * 0.5;
        let offset_y = (height as f32 - DESIGN_H as f32 * scale) * 0.5;
        let mut pixels = Vec::new();
        pixels.try_reserve_exact(area).ok()?;
        pixels.resize(area, [0, 0, 0, 255]);
        Some(Self {
            width,
            height,
            pixels,
            scale,
            offset_x,
            offset_y,
        })
    }

    fn map_point(&self, x: f32, y: f32) -> (i32, i32) {
        (
            round_sat(self.offset_x + x * self.scale),
            round_sat(self.offset_y + y * self.scale),
        )
    }
    fn map_rect(&self, x: i32, y: i32, w: i32, h: i32) -> (i32, i32, i32, i32) {
        let (x0, y0) = self.map_point(x as f32, y as f32);
        let x1 = round_sat(self.offset_x + (x as f32 + w as f32) * self.scale);
        let y1 = round_sat(self.offset_y + (y as f32 + h as f32) * self.scale);
        (
            x0,
            y0,
            (x1 as i64 - x0 as i64).clamp(0, i32::MAX as i64) as i32,
            (y1 as i64 - y0 as i64).clamp(0, i32::MAX as i64) as i32,
        )
    }
    pub fn clear(&mut self, c: Color) {
        self.pixels.fill(c);
    }
    fn blend_at(&mut self, x: i32, y: i32, c: Color) {
        if x < 0 || y < 0 || x as usize >= self.width || y as usize >= self.height || c[3] == 0 {
            return;
        }
        let i = y as usize * self.width + x as usize;
        let a = c[3] as u32;
        let inv = 255 - a;
        let d = self.pixels[i];
        self.pixels[i] = [
            ((c[0] as u32 * a + d[0] as u32 * inv + 127) / 255) as u8,
            ((c[1] as u32 * a + d[1] as u32 * inv + 127) / 255) as u8,
            ((c[2] as u32 * a + d[2] as u32 * inv + 127) / 255) as u8,
            255,
        ];
    }
    pub fn rect(&mut self, x: i32, y: i32, w: i32, h: i32, c: Color) {
        let (x, y, w, h) = self.map_rect(x, y, w.max(0), h.max(0));
        let x0 = x.max(0);
        let y0 = y.max(0);
        let x1 = (x as i64 + w as i64).min(self.width as i64) as i32;
        let y1 = (y as i64 + h as i64).min(self.height as i64) as i32;
        for yy in y0..y1 {
            for xx in x0..x1 {
                self.blend_at(xx, yy, c);
            }
        }
    }
    pub fn rounded(&mut self, x: i32, y: i32, w: i32, h: i32, r: i32, c: Color) {
        let (x, y, w, h) = self.map_rect(x, y, w.max(0), h.max(0));
        let radius = (libm::roundf(r.max(0) as f32 * self.scale).max(0.0) as i64)
            .min((w.min(h).max(0) as f32 * self.scale / 2.0) as i64);
        let x0 = x.max(0);
        let y0 = y.max(0);
        let x1 = (x as i64 + w as i64).min(self.width as i64) as i32;
        let y1 = (y as i64 + h as i64).min(self.height as i64) as i32;
        for yy in y0..y1 {
            for xx in x0..x1 {
                let xx = xx as i64;
                let yy = yy as i64;
                let cx = if xx < x as i64 + radius {
                    x as i64 + radius
                } else if xx >= x as i64 + w as i64 - radius {
                    x as i64 + w as i64 - radius - 1
                } else {
                    xx
                };
                let cy = if yy < y as i64 + radius {
                    y as i64 + radius
                } else if yy >= y as i64 + h as i64 - radius {
                    y as i64 + h as i64 - radius - 1
                } else {
                    yy
                };
                let dx = xx - cx;
                let dy = yy - cy;
                if (dx as i128 * dx as i128 + dy as i128 * dy as i128)
                    <= radius as i128 * radius as i128
                {
                    self.blend_at(xx as i32, yy as i32, c);
                }
            }
        }
    }
    pub fn round_outline(&mut self, x: i32, y: i32, w: i32, h: i32, r: i32, t: i32, c: Color) {
        let (rx, ry, rw, rh) = self.map_rect(x, y, w.max(0), h.max(0));
        let rx = rx as i64;
        let ry = ry as i64;
        let rw = rw as i64;
        let rh = rh as i64;
        let outer =
            (libm::roundf(r.max(0) as f32 * self.scale).max(0.0) as i64).min(rw.min(rh).max(0) / 2);
        let thick = libm::roundf(t.max(1) as f32 * self.scale).max(1.0) as i64;
        let ix = rx + thick;
        let iy = ry + thick;
        let iw = rw - 2 * thick;
        let ih = rh - 2 * thick;
        let inner = (outer - thick).max(0);
        for yy in ry.max(0)..(ry + rh).min(self.height as i64) {
            for xx in rx.max(0)..(rx + rw).min(self.width as i64) {
                let ocx = if xx < rx + outer {
                    rx + outer
                } else if xx >= rx + rw - outer {
                    rx + rw - outer - 1
                } else {
                    xx
                };
                let ocy = if yy < ry + outer {
                    ry + outer
                } else if yy >= ry + rh - outer {
                    ry + rh - outer - 1
                } else {
                    yy
                };
                let odx = xx - ocx;
                let ody = yy - ocy;
                let outside_ok = (odx as i128 * odx as i128 + ody as i128 * ody as i128)
                    <= outer as i128 * outer as i128;
                let inside_inner =
                    if iw > 0 && ih > 0 && xx >= ix && yy >= iy && xx < ix + iw && yy < iy + ih {
                        let icx = if xx < ix + inner {
                            ix + inner
                        } else if xx >= ix + iw - inner {
                            ix + iw - inner - 1
                        } else {
                            xx
                        };
                        let icy = if yy < iy + inner {
                            iy + inner
                        } else if yy >= iy + ih - inner {
                            iy + ih - inner - 1
                        } else {
                            yy
                        };
                        let dx = xx - icx;
                        let dy = yy - icy;
                        (dx as i128 * dx as i128 + dy as i128 * dy as i128)
                            <= inner as i128 * inner as i128
                    } else {
                        false
                    };
                if outside_ok && !inside_inner {
                    self.blend_at(xx as i32, yy as i32, c)
                }
            }
        }
    }
    pub fn line(&mut self, x0: i32, y0: i32, x1: i32, y1: i32, width: i32, c: Color) {
        let (ax, ay) = self.map_point(x0 as f32, y0 as f32);
        let (bx, by) = self.map_point(x1 as f32, y1 as f32);
        let Some((x0, y0, x1, y1)) = clip_line(
            ax as i64,
            ay as i64,
            bx as i64,
            by as i64,
            self.width as i64 - 1,
            self.height as i64 - 1,
        ) else {
            return;
        };
        let dx = (x1 - x0).abs();
        let sx = if x0 < x1 { 1 } else { -1 };
        let dy = -(y1 - y0).abs();
        let sy = if y0 < y1 { 1 } else { -1 };
        let mut err = dx + dy;
        let (mut x, mut y) = (x0, y0);
        let r = (libm::roundf((width.max(1) as f32 * self.scale) / 2.0).max(1.0) as i64)
            .min(self.width.max(self.height) as i64);
        loop {
            for yy in (y - r).max(0)..=(y + r).min(self.height as i64 - 1) {
                for xx in (x - r).max(0)..=(x + r).min(self.width as i64 - 1) {
                    let ddx = xx - x;
                    let ddy = yy - y;
                    if (ddx as i128 * ddx as i128 + ddy as i128 * ddy as i128)
                        <= r as i128 * r as i128
                    {
                        self.blend_at(xx as i32, yy as i32, c);
                    }
                }
            }
            if x == x1 && y == y1 {
                break;
            }
            let e2 = 2 * err;
            if e2 >= dy {
                err += dy;
                x += sx
            }
            if e2 <= dx {
                err += dx;
                y += sy
            }
        }
    }
    pub fn circle(&mut self, cx: i32, cy: i32, r: i32, color: Color) {
        let (cx, cy) = self.map_point(cx as f32, cy as f32);
        let cx = cx as i64;
        let cy = cy as i64;
        let r = (libm::roundf(r.max(0) as f32 * self.scale) as i64)
            .min(self.width.max(self.height) as i64);
        for y in (cy - r).max(0)..=(cy + r).min(self.height as i64 - 1) {
            for x in (cx - r).max(0)..=(cx + r).min(self.width as i64 - 1) {
                let dx = x - cx;
                let dy = y - cy;
                if (dx as i128 * dx as i128 + dy as i128 * dy as i128) <= r as i128 * r as i128 {
                    self.blend_at(x as i32, y as i32, color)
                }
            }
        }
    }
    pub fn image_rgba(&mut self, x: i32, y: i32, w: i32, h: i32, src: &[u8], sw: usize, sh: usize) {
        if sw == 0
            || sh == 0
            || sw
                .checked_mul(sh)
                .and_then(|n| n.checked_mul(4))
                .map_or(true, |n| n > src.len())
            || w <= 0
            || h <= 0
        {
            return;
        }
        let (dx, dy, dw, dh) = self.map_rect(x, y, w, h);
        if dw <= 0 || dh <= 0 {
            return;
        }
        let x0 = dx.max(0);
        let y0 = dy.max(0);
        let x1 = (dx as i64 + dw as i64).min(self.width as i64) as i32;
        let y1 = (dy as i64 + dh as i64).min(self.height as i64) as i32;
        for py in y0..y1 {
            for px in x0..x1 {
                let (sx0, sx1, fx) = sample_axis(px, dx, dw, sw);
                let (sy0, sy1, fy) = sample_axis(py, dy, dh, sh);
                let i00 = (sy0 * sw + sx0) * 4;
                let i10 = (sy0 * sw + sx1) * 4;
                let i01 = (sy1 * sw + sx0) * 4;
                let i11 = (sy1 * sw + sx1) * 4;
                let mut color = [0_u8; 4];
                for channel in 0..4 {
                    let top =
                        src[i00 + channel] as u32 * (256 - fx) + src[i10 + channel] as u32 * fx;
                    let bottom =
                        src[i01 + channel] as u32 * (256 - fx) + src[i11 + channel] as u32 * fx;
                    color[channel] = ((top * (256 - fy) + bottom * fy + 32768) >> 16) as u8;
                }
                self.blend_at(px, py, color);
            }
        }
    }
    pub fn image_alpha_tinted(
        &mut self,
        x: i32,
        y: i32,
        w: i32,
        h: i32,
        src: &[u8],
        sw: usize,
        sh: usize,
        color: Color,
    ) {
        if sw == 0
            || sh == 0
            || sw.checked_mul(sh).map_or(true, |n| n > src.len())
            || w <= 0
            || h <= 0
        {
            return;
        }
        let (dx, dy, dw, dh) = self.map_rect(x, y, w, h);
        if dw <= 0 || dh <= 0 {
            return;
        }
        let x0 = dx.max(0);
        let y0 = dy.max(0);
        let x1 = (dx as i64 + dw as i64).min(self.width as i64) as i32;
        let y1 = (dy as i64 + dh as i64).min(self.height as i64) as i32;
        for py in y0..y1 {
            for px in x0..x1 {
                let coverage = sample_gray_bilinear(
                    src,
                    sw,
                    0,
                    0,
                    sw,
                    sh,
                    px,
                    py,
                    dx,
                    dy,
                    dw as usize,
                    dh as usize,
                );
                let alpha = (coverage as u16 * color[3] as u16 + 127) / 255;
                if alpha > 0 {
                    self.blend_at(px, py, [color[0], color[1], color[2], alpha as u8]);
                }
            }
        }
    }
    pub fn text(&mut self, x: i32, y: i32, s: &str, color: Color) {
        self.text_size(x, y, s, color, 0);
    }
    pub fn text_size(&mut self, x: i32, y: i32, s: &str, color: Color, face: u8) {
        let mut pen = x;
        for ch in s.chars() {
            if let Some(g) = GLYPHS
                .iter()
                .find(|g| g.ch == ch && g.face == face)
                .filter(|g| glyph_is_within_atlas(g))
            {
                let (gx, gy, gw, gh) = self.map_rect(
                    pen.saturating_add(g.left as i32),
                    y.saturating_add(g.top as i32),
                    g.width as i32,
                    g.height as i32,
                );
                let dw = gw.max(0) as usize;
                let dh = gh.max(0) as usize;
                let atlas = GLYPH_ATLASES[face.min(4) as usize];
                for oy in 0..dh {
                    for ox in 0..dw {
                        let alpha = sample_gray_bilinear(
                            atlas,
                            GLYPH_ATLAS_W,
                            g.x as usize,
                            g.y as usize,
                            g.raster_width as usize,
                            g.raster_height as usize,
                            gx + ox as i32,
                            gy + oy as i32,
                            gx,
                            gy,
                            dw,
                            dh,
                        );
                        if alpha > 0 {
                            let c = [
                                color[0],
                                color[1],
                                color[2],
                                ((alpha as u16 * color[3] as u16 + 127) / 255) as u8,
                            ];
                            self.blend_at(gx + ox as i32, gy + oy as i32, c)
                        }
                    }
                }
                pen = pen.saturating_add(g.advance as i32);
            } else {
                pen = pen.saturating_add(18);
            }
        }
    }
    pub fn present_bytes(&self) -> &[Color] {
        &self.pixels
    }
}

pub fn render(
    width: usize,
    height: usize,
    selected: usize,
    countdown: u32,
    status: Option<&str>,
) -> Option<Canvas> {
    use tokens::*;
    let mut c = Canvas::new(width, height)?;
    // Full-HD-first light canvas with subtle Atlas-blue organic shapes.
    c.clear(SKY);
    for y in 0..DESIGN_H as i32 {
        let t = y as u32 * 14 / DESIGN_H;
        c.rect(
            0,
            y,
            DESIGN_W as i32,
            1,
            [((249 - t / 3) as u8), ((252 - t / 5) as u8), 255, 255],
        );
    }
    c.circle(360, 360, 440, [255, 255, 255, 30]);
    c.circle(720, 525, 470, [210, 231, 255, 20]);
    c.circle(1515, 420, 520, [206, 229, 255, 22]);
    c.image_rgba(
        0,
        548,
        DESIGN_W as i32,
        275,
        LANDSCAPE,
        LANDSCAPE_W,
        LANDSCAPE_H,
    );
    // Soft translucent horizon wash keeps the bottom artwork integrated.
    c.rounded(0, 823, DESIGN_W as i32, 118, 0, [7, 52, 108, 242]);
    c.rect(0, 822, DESIGN_W as i32, 2, [106, 164, 218, 255]);
    // The boot-specific A/book/compass mark is simplified and text-free;
    // wordmark and slogan use the high-resolution glyph renderer separately.
    c.image_rgba(
        104,
        151,
        136,
        136,
        BOOT_MARK,
        BOOT_MARK_SIZE,
        BOOT_MARK_SIZE,
    );
    c.text_size(260, 193, "Atlas OS", NAVY, 4);
    c.text_size(263, 257, "DAHA İYİ BİR YARIN İÇİN", MUTED, 1);
    c.rect(103, 411, 6, 84, BLUE);
    c.text_size(139, 414, "Bugünün Sınıfında", NAVY, 3);
    c.text_size(139, 462, "Daha İleriye", NAVY, 3);
    c.text_size(
        139,
        518,
        "Güvenli, hafif ve modern bir eğitim işletim sistemi.",
        MUTED,
        1,
    );
    // Right hand premium surface and five actual capabilities / clearly disabled items.
    c.rounded(866, 140, 770, 602, 28, [52, 82, 124, 20]);
    c.rounded(870, 132, 762, 602, 26, [255, 255, 255, 255]);
    c.round_outline(870, 132, 762, 602, 26, 1, [255, 255, 255, 255]);
    let rows = [
        (
            "AtlasOS’u Başlat (Canlı Mod)",
            "USB üzerinden AtlasOS’u başlat",
            BLUE,
            true,
        ),
        (
            "Gelişmiş Seçenekler",
            "Çekirdek seçenekleri ve kurtarma modları",
            BLUE,
            false,
        ),
        (
            "Diskten Başlat",
            "Bilgisayarınızdaki sistemden başlat",
            AMBER,
            false,
        ),
        (
            "Sistem Araçları",
            "Bellek testi ve donanım tanılama",
            VIOLET,
            false,
        ),
        (
            "Bilgisayarı Kapat",
            "Sistemi güvenli şekilde kapat",
            RED,
            true,
        ),
    ];
    for (i, (title, subtitle, accent, enabled)) in rows.iter().enumerate() {
        let y = 155 + i as i32 * 112;
        let active = i == selected;
        if active {
            c.rounded(898, y, 710, 112, 20, [26, 116, 255, 255]);
            c.rounded(901, y + 3, 704, 106, 17, [215, 235, 255, 255]);
        } else if *enabled {
            c.rounded(900, y, 706, 106, 18, [255, 255, 255, 0]);
        } else {
            c.rounded(900, y, 706, 106, 18, [255, 255, 255, 0]);
        }
        if i > 0 {
            c.rect(919, y, 669, 1, LINE);
        }
        let icon_c = if *enabled {
            *accent
        } else {
            [231, 239, 249, 255]
        };
        c.rounded(
            918,
            y + 18,
            78,
            78,
            ICON_RADIUS,
            [icon_c[0], icon_c[1], icon_c[2], 255],
        );
        c.image_alpha_tinted(
            931,
            y + 31,
            52,
            52,
            ICONS[i],
            ICON_SIZE,
            ICON_SIZE,
            if *enabled {
                WHITE
            } else {
                [104, 132, 168, 255]
            },
        );
        let label = if *enabled { NAVY } else { [107, 127, 154, 255] };
        c.text_size(1028, y + 25, title, label, 2);
        c.text_size(
            1028,
            y + 68,
            subtitle,
            if *enabled {
                MUTED
            } else {
                [125, 146, 173, 255]
            },
            1,
        );
        c.line(
            1563,
            y + 42,
            1575,
            y + 55,
            3,
            if active { BLUE } else { NAVY_SOFT },
        );
        c.line(
            1575,
            y + 55,
            1563,
            y + 68,
            3,
            if active { BLUE } else { NAVY_SOFT },
        );
    }
    // Footer is a translucent navy dock aligned to the reference composition.
    c.round_outline(56, 837, 38, 38, 8, 1, [152, 193, 236, 255]);
    c.line(75, 862, 75, 850, 2, WHITE);
    c.line(75, 850, 69, 856, 2, WHITE);
    c.line(75, 850, 81, 856, 2, WHITE);
    c.round_outline(100, 837, 38, 38, 8, 1, [152, 193, 236, 255]);
    c.line(119, 850, 119, 862, 2, WHITE);
    c.line(119, 862, 113, 856, 2, WHITE);
    c.line(119, 862, 125, 856, 2, WHITE);
    c.text(153, 850, "Seçeneklerde Gezin", [221, 237, 255, 255]);
    c.rounded(332, 837, 74, 38, 8, [255, 255, 255, 38]);
    c.round_outline(332, 837, 74, 38, 8, 1, [152, 193, 236, 255]);
    c.text(347, 843, "Enter", WHITE);
    c.text(423, 850, "Seçili Seçeneği Başlat", [221, 237, 255, 255]);
    c.round_outline(628, 837, 64, 38, 8, 1, [152, 193, 236, 255]);
    c.text(638, 850, "Esc", WHITE);
    c.text(708, 850, "Başlangıç seçeneğine dön", [221, 237, 255, 255]);
    c.rect(1188, 835, 1, 44, [130, 169, 209, 255]);
    if let Some(msg) = status {
        c.text(1238, 834, msg, [183, 211, 241, 255]);
    } else {
        let msg = countdown_message(countdown);
        c.text(1238, 834, &msg, [183, 211, 241, 255]);
    }
    c.rounded(1238, 879, 374, 9, 5, [63, 98, 140, 255]);
    let fill = (countdown.min(10) as i32 * 374 / 10).max(0);
    c.rounded(1238, 879, fill, 9, 5, CYAN);
    // Date/time shown only when populated by firmware runtime and validated by caller.
    Some(c)
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Action {
    LiveBoot,
    Shutdown,
    Disabled,
}
pub fn action_for(index: usize) -> Action {
    match index {
        0 => Action::LiveBoot,
        4 => Action::Shutdown,
        _ => Action::Disabled,
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Key {
    Up,
    Down,
    Enter,
    Escape,
    Other,
}
pub struct UiState {
    pub selected: usize,
    pub seconds_left: u32,
    pub countdown_active: bool,
    pub message: Option<&'static str>,
    pub boot_requested: bool,
    pub boot_in_progress: bool,
}
impl UiState {
    pub const fn new() -> Self {
        Self {
            selected: 0,
            seconds_left: 10,
            countdown_active: true,
            message: None,
            boot_requested: false,
            boot_in_progress: false,
        }
    }
    pub fn key(&mut self, key: Key) {
        match key {
            Key::Up => {
                self.selected = if self.selected == 0 {
                    4
                } else {
                    self.selected - 1
                };
                self.countdown_active = false;
                self.message = None;
            }
            Key::Down => {
                self.selected = (self.selected + 1) % 5;
                self.countdown_active = false;
                self.message = None;
            }
            Key::Escape => {
                self.selected = 0;
                self.countdown_active = false;
                self.message = Some("Başlangıç seçeneğine dönüldü.");
            }
            Key::Enter => {
                match action_for(self.selected) {
                    Action::LiveBoot if !self.boot_in_progress => {
                        self.boot_in_progress = true;
                        self.boot_requested = true;
                        self.message = Some("AtlasOS başlatılıyor…");
                    }
                    Action::LiveBoot => {}
                    Action::Shutdown => self.message = Some("Kapatma isteği gönderiliyor…"),
                    Action::Disabled => {
                        self.message = Some("Bu seçenek bu prototipte kullanılamıyor.")
                    }
                };
                self.countdown_active = false;
            }
            Key::Other => {
                self.countdown_active = false;
            }
        }
    }
    pub fn take_boot_request(&mut self) -> bool {
        core::mem::replace(&mut self.boot_requested, false)
    }
    pub fn boot_failed(&mut self, message: &'static str) {
        self.boot_in_progress = false;
        self.boot_requested = false;
        self.countdown_active = false;
        self.message = Some(message);
    }
    pub fn tick_second(&mut self) {
        if self.countdown_active {
            if self.seconds_left > 0 {
                self.seconds_left -= 1;
            }
            if self.seconds_left == 0 {
                self.countdown_active = false;
                self.boot_in_progress = true;
                self.boot_requested = true;
                self.message = Some("AtlasOS başlatılıyor…");
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn required_turkish_glyphs_exist_at_every_raster_size() {
        for face in 0..5 {
            for ch in "ÇĞİÖŞÜçğıöşü".chars() {
                assert!(
                    GLYPHS.iter().any(|g| g.ch == ch && g.face as usize == face),
                    "missing {ch} in face {face}"
                );
            }
        }
    }

    #[test]
    fn required_turkish_glyphs_have_visible_pixels_at_every_raster_size() {
        for face in 0..5 {
            let atlas = GLYPH_ATLASES[face];
            for ch in "çÇğĞıİöÖşŞüÜ".chars() {
                let glyph = GLYPHS
                    .iter()
                    .find(|glyph| glyph.ch == ch && glyph.face as usize == face)
                    .unwrap_or_else(|| panic!("missing {ch} in face {face}"));
                let visible = (0..glyph.raster_height as usize).any(|y| {
                    let start = (glyph.y as usize + y) * GLYPH_ATLAS_W + glyph.x as usize;
                    atlas[start..start + glyph.raster_width as usize]
                        .iter()
                        .any(|coverage| *coverage != 0)
                });
                assert!(visible, "blank raster for {ch} in face {face}");
            }
        }
    }

    #[test]
    fn gop_resolution_preferences_keep_the_1080p_primary_and_documented_fallbacks() {
        assert_eq!(
            gop_mode_preferences(None),
            [
                None,
                Some((1920, 1080)),
                Some((1366, 768)),
                Some((1368, 768)),
                Some((1280, 720)),
            ]
        );
        assert_eq!(
            gop_mode_preferences(Some((1368, 768))),
            [
                Some((1368, 768)),
                Some((1920, 1080)),
                Some((1366, 768)),
                Some((1368, 768)),
                Some((1280, 720)),
            ]
        );
        let preferred = gop_mode_preferences(None);
        let available = [(1024, 768), (1366, 768), (1280, 720)];
        assert_eq!(
            preferred
                .into_iter()
                .flatten()
                .find(|resolution| available.contains(resolution)),
            Some((1366, 768))
        );
        let available = [(1024, 768), (1280, 720)];
        assert_eq!(
            preferred
                .into_iter()
                .flatten()
                .find(|resolution| available.contains(resolution)),
            Some((1280, 720))
        );
    }

    #[test]
    fn embedded_phase5_assets_have_expected_dimensions() {
        assert_eq!(LANDSCAPE.len(), LANDSCAPE_W * LANDSCAPE_H * 4);
        assert_eq!(BOOT_MARK.len(), BOOT_MARK_SIZE * BOOT_MARK_SIZE * 4);
        for (face, atlas) in GLYPH_ATLASES.iter().enumerate() {
            assert_eq!(atlas.len(), GLYPH_ATLAS_W * GLYPH_ATLAS_HEIGHTS[face]);
        }
        for icon in ICONS {
            assert_eq!(icon.len(), ICON_SIZE * ICON_SIZE);
            assert!(icon.iter().any(|alpha| *alpha > 0));
        }
    }

    #[test]
    fn glyphs_have_supersampled_sources_and_clear_atlas_padding() {
        for glyph in GLYPHS {
            assert!(glyph.raster_width >= glyph.width);
            assert!(glyph.raster_height >= glyph.height);
            assert!(glyph.x >= 4 && glyph.y >= 4);
            assert!(glyph.x as usize + glyph.raster_width as usize + 4 <= GLYPH_ATLAS_W);
            assert!(
                glyph.y as usize + glyph.raster_height as usize + 4
                    <= GLYPH_ATLAS_HEIGHTS[glyph.face as usize]
            );
        }
    }

    #[test]
    fn grayscale_resampling_preserves_partial_edge_coverage() {
        let mask = [0, 255, 0, 255];
        let sample = sample_gray_bilinear(&mask, 2, 0, 0, 2, 2, 0, 0, 0, 0, 1, 1);
        assert!(sample > 0 && sample < 255);
    }

    #[test]
    fn full_hd_layout_text_and_footer_fit_their_regions() {
        assert!(870 + 762 <= DESIGN_W as i32);
        assert!(548 + LANDSCAPE_H as i32 == 823);
        assert!(823 + 118 <= DESIGN_H as i32);
        assert!(139 + (text_width("Bugünün Sınıfında", 3) as i32) < 850);
        assert!(
            139 + (text_width("Güvenli, hafif ve modern bir eğitim işletim sistemi.", 1) as i32)
                < 850
        );
        assert!(263 + (text_width("DAHA İYİ BİR YARIN İÇİN", 1) as i32) < 850);
        assert!(104 + 136 <= 850);
        for title in [
            "AtlasOS’u Başlat (Canlı Mod)",
            "Gelişmiş Seçenekler",
            "Diskten Başlat",
            "Sistem Araçları",
            "Bilgisayarı Kapat",
        ] {
            assert!(text_width(title, 2) < 520, "menu title overflow: {title}");
        }
        assert!(text_width("Çekirdek seçenekleri ve kurtarma modları", 1) < 520);
        assert!(text_width("10 saniye içinde otomatik olarak başlatılacak...", 0) < 374);
    }

    #[test]
    fn countdown_is_real_and_navigation_cancels_it() {
        let mut s = UiState::new();
        assert_eq!(s.seconds_left, 10);
        assert!(s.countdown_active);
        for expected in (1..=9).rev() {
            s.tick_second();
            assert_eq!(s.seconds_left, expected);
        }
        s.key(Key::Down);
        assert_eq!(s.selected, 1);
        assert!(!s.countdown_active);
        s.tick_second();
        assert_eq!(s.seconds_left, 1);
    }

    #[test]
    fn countdown_expiry_requests_the_live_boot_once() {
        let mut s = UiState::new();
        for _ in 0..10 {
            s.tick_second();
        }
        assert_eq!(s.seconds_left, 0);
        assert_eq!(s.message, Some("AtlasOS başlatılıyor…"));
        assert_eq!(action_for(s.selected), Action::LiveBoot);
        assert!(s.take_boot_request());
        assert!(!s.take_boot_request());
    }

    #[test]
    fn countdown_copy_tracks_the_remaining_seconds() {
        assert_eq!(
            countdown_message(10),
            "10 saniye içinde otomatik olarak başlatılacak..."
        );
        assert_eq!(
            countdown_message(3),
            "3 saniye içinde otomatik olarak başlatılacak..."
        );
        assert_eq!(
            countdown_message(0),
            "0 saniye içinde otomatik olarak başlatılacak..."
        );
    }

    #[test]
    fn only_proven_prototype_actions_are_enabled() {
        assert_eq!(action_for(0), Action::LiveBoot);
        assert_eq!(action_for(4), Action::Shutdown);
        for index in 1..4 {
            assert_eq!(action_for(index), Action::Disabled);
        }
    }

    #[test]
    fn live_enter_requests_only_one_boot_until_failure_or_return() {
        let mut s = UiState::new();
        s.key(Key::Enter);
        assert!(s.boot_in_progress);
        assert!(s.take_boot_request());
        assert!(!s.take_boot_request());
        s.key(Key::Enter);
        assert!(!s.take_boot_request());
        s.boot_failed("Başlatılamadı · EFI-L1");
        assert!(!s.boot_in_progress);
        assert_eq!(s.message, Some("Başlatılamadı · EFI-L1"));
        s.key(Key::Enter);
        assert!(s.take_boot_request());
    }

    #[test]
    fn live_enter_routes_only_from_the_live_menu_item() {
        let mut s = UiState::new();
        s.key(Key::Down);
        s.key(Key::Enter);
        assert!(!s.boot_in_progress);
        assert!(!s.take_boot_request());
        assert_eq!(s.message, Some("Bu seçenek bu prototipte kullanılamıyor."));
    }

    #[test]
    fn all_reference_resolutions_render_inside_bounds() {
        for (w, h) in [(1920, 1080), (1366, 768), (1280, 720)] {
            let mut c = render(w, h, 0, 10, None).unwrap();
            let expected_scale = (w as f32 / DESIGN_W as f32).min(h as f32 / DESIGN_H as f32);
            assert!((c.scale - expected_scale).abs() < 0.000_01);
            let (_, _, render_w, render_h) = c.map_rect(0, 0, DESIGN_W as i32, DESIGN_H as i32);
            assert!(render_w <= w as i32 && render_h <= h as i32);
            assert!(
                (render_w as f32 / DESIGN_W as f32 - render_h as f32 / DESIGN_H as f32).abs()
                    < 0.002
            );
            assert_eq!(c.pixels.len(), w * h);
            c.line(-100, -100, 2000, 1200, 6, [255, 255, 255, 255]);
            c.rounded(-30, -20, 100, 80, 28, [255, 255, 255, 200]);
            assert!(c.pixels.iter().all(|p| p[3] == 255));
        }
    }
}
