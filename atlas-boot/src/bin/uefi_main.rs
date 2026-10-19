#![no_std]
#![no_main]

use alloc::vec::Vec;
use atlas_boot_manager::{
    COUNTDOWN_REGION, Canvas, Key, UiState, draw_countdown, gop_fallback_score,
    gop_mode_preferences, render_base,
};
use core::time::Duration;
use uefi::prelude::*;
use uefi::proto::console::gop::{BltOp, BltPixel, GraphicsOutput, PixelFormat};
use uefi::proto::console::text::ScanCode;
use uefi::proto::device_path::{DevicePath, build};
use uefi::proto::loaded_image::LoadedImage;

extern crate alloc;

const BACKEND_FILE: &uefi::CStr16 = uefi::cstr16!("\\EFI\\BOOT\\ATLASGRUB.EFI");

#[entry]
fn main() -> Status {
    if uefi::helpers::init().is_err() {
        return Status::ABORTED;
    }
    if let Err(e) = run() {
        uefi::println!("Atlas Boot Manager: {:?}", e);
        return Status::ABORTED;
    }
    Status::SUCCESS
}

fn run() -> uefi::Result {
    let timer = unsafe {
        uefi::boot::create_event(
            uefi::boot::EventType::TIMER,
            uefi::boot::Tpl::APPLICATION,
            None,
            None,
        )?
    };
    uefi::boot::set_timer(
        &timer,
        uefi::boot::TimerTrigger::Periodic(Duration::from_secs(1)),
    )?;
    let input = uefi::system::with_stdin(|stdin| stdin.wait_for_key_event())?;
    let events = [input, timer];
    let mut state = UiState::new();
    let mut frame = present_frame(&state)?;

    loop {
        if state.take_boot_request() {
            // The child may change the GOP mode. Do not retain an exclusive GOP
            // protocol handle while LoadImage/StartImage runs.
            match start_live_backend() {
                Ok(()) => state.boot_failed("Başlatma tamamlanmadı · EFI-S4"),
                Err(BackendError::Path) => {
                    state.boot_failed("Başlangıç aygıtı bulunamadı · EFI-P1")
                }
                Err(BackendError::Load(_status)) => {
                    state.boot_failed("Başlangıç bileşeni yüklenemedi · EFI-L2")
                }
                Err(BackendError::Start(_status)) => {
                    state.boot_failed("Başlangıç bileşeni çalıştırılamadı · EFI-S3")
                }
            }
            frame = present_frame(&state)?;
        }

        match uefi::boot::wait_for_event(&events) {
            Ok(0) => {
                let key = uefi::system::with_stdin(|stdin| stdin.read_key());
                if let Ok(Some(key)) = key {
                    match key {
                        uefi::proto::console::text::Key::Special(ScanCode::UP) => {
                            state.key(Key::Up)
                        }
                        uefi::proto::console::text::Key::Special(ScanCode::DOWN) => {
                            state.key(Key::Down)
                        }
                        uefi::proto::console::text::Key::Printable(c) if c == '\r' => {
                            state.key(Key::Enter)
                        }
                        uefi::proto::console::text::Key::Special(ScanCode::ESCAPE) => {
                            state.key(Key::Escape)
                        }
                        _ => state.key(Key::Other),
                    }
                    frame = present_frame(&state)?;
                }
            }
            Ok(1) => {
                let seconds_before = state.seconds_left;
                let message_before = state.message;
                state.tick_second();
                if state.message != message_before {
                    frame = present_frame(&state)?;
                } else if state.seconds_left != seconds_before
                    && !present_countdown(&mut frame, &state)?
                {
                    // A child or firmware component changed the display mode.
                    // Rebuild the full frame only when the cached dimensions no
                    // longer match the active GOP mode.
                    frame = present_frame(&state)?;
                }
            }
            Err(_) => {}
            _ => {}
        }
        if state.message == Some("Kapatma isteği gönderiliyor…") {
            uefi::runtime::reset(uefi::runtime::ResetType::SHUTDOWN, Status::SUCCESS, None);
        }
    }
}

struct FrameCache {
    canvas: Canvas,
    countdown_rect: (usize, usize, usize, usize),
    countdown_background: Vec<[u8; 4]>,
}

fn present_frame(state: &UiState) -> uefi::Result<FrameCache> {
    let handle = uefi::boot::get_handle_for_protocol::<GraphicsOutput>()?;
    let mut gop = uefi::boot::open_protocol_exclusive::<GraphicsOutput>(handle)?;
    select_preferred_mode(&mut gop);
    let (width, height) = gop.current_mode_info().resolution();
    let mut canvas =
        render_base(width, height, state.selected).ok_or(uefi::Status::OUT_OF_RESOURCES)?;
    let countdown_rect = canvas.mapped_rect(
        COUNTDOWN_REGION.0,
        COUNTDOWN_REGION.1,
        COUNTDOWN_REGION.2,
        COUNTDOWN_REGION.3,
    );
    let countdown_background = canvas
        .copy_region(countdown_rect)
        .ok_or(uefi::Status::OUT_OF_RESOURCES)?;
    draw_countdown(&mut canvas, state.seconds_left, state.message);
    present_full(&mut gop, &canvas)?;
    Ok(FrameCache {
        canvas,
        countdown_rect,
        countdown_background,
    })
}

fn select_preferred_mode(gop: &mut GraphicsOutput) {
    let current = gop.current_mode_info().resolution();
    for (want_w, want_h) in gop_mode_preferences(preferred_mode()).into_iter().flatten() {
        if current == (want_w, want_h) {
            return;
        }
        if let Some(mode) = gop
            .modes()
            .find(|mode| mode.info().resolution() == (want_w, want_h))
            && gop.set_mode(&mode).is_ok()
        {
            return;
        }
    }
    if let Some(mode) = gop
        .modes()
        .filter(|mode| {
            let (w, h) = mode.info().resolution();
            w >= 640 && h >= 360 && w.saturating_mul(h) <= 16_777_216
        })
        .min_by_key(|mode| {
            let (w, h) = mode.info().resolution();
            gop_fallback_score(w, h)
        })
    {
        let (fallback_w, fallback_h) = mode.info().resolution();
        if gop.current_mode_info().resolution() != (fallback_w, fallback_h) {
            let _ = gop.set_mode(&mode);
        }
    }
}

fn present_countdown(frame: &mut FrameCache, state: &UiState) -> uefi::Result<bool> {
    let handle = uefi::boot::get_handle_for_protocol::<GraphicsOutput>()?;
    let mut gop = uefi::boot::open_protocol_exclusive::<GraphicsOutput>(handle)?;
    if gop.current_mode_info().resolution() != (frame.canvas.width, frame.canvas.height) {
        return Ok(false);
    }
    if !frame
        .canvas
        .restore_region(frame.countdown_rect, &frame.countdown_background)
    {
        return Err(uefi::Status::DEVICE_ERROR.into());
    }
    draw_countdown(&mut frame.canvas, state.seconds_left, state.message);
    present_region(&mut gop, &frame.canvas, frame.countdown_rect)?;
    Ok(true)
}

fn present_full(gop: &mut GraphicsOutput, canvas: &Canvas) -> uefi::Result {
    let mode = gop.current_mode_info();
    let (width, height) = mode.resolution();
    let stride = mode.stride();
    let src = canvas.present_bytes();
    if canvas.width != width || canvas.height != height || src.len() != width * height {
        return Err(uefi::Status::DEVICE_ERROR.into());
    }
    match mode.pixel_format() {
        PixelFormat::Rgb | PixelFormat::Bgr if stride == width => {
            let mut fb = gop.frame_buffer();
            let needed = stride
                .checked_mul(height)
                .and_then(|n| n.checked_mul(4))
                .ok_or(uefi::Status::OUT_OF_RESOURCES)?;
            if fb.size() < needed {
                return Err(uefi::Status::DEVICE_ERROR.into());
            }
            let dst = unsafe { core::slice::from_raw_parts_mut(fb.as_mut_ptr(), needed) };
            for y in 0..height {
                for x in 0..width {
                    let p = src[y * width + x];
                    let i = (y * stride + x) * 4;
                    if mode.pixel_format() == PixelFormat::Rgb {
                        dst[i] = p[0];
                        dst[i + 1] = p[1];
                        dst[i + 2] = p[2]
                    } else {
                        dst[i] = p[2];
                        dst[i + 1] = p[1];
                        dst[i + 2] = p[0]
                    }
                    dst[i + 3] = 0;
                }
            }
        }
        _ => {
            let mut pixels: Vec<BltPixel> = Vec::new();
            pixels
                .try_reserve_exact(src.len())
                .map_err(|_| uefi::Status::OUT_OF_RESOURCES)?;
            pixels.extend(src.iter().map(|p| BltPixel::new(p[0], p[1], p[2])));
            gop.blt(BltOp::BufferToVideo {
                buffer: &pixels,
                src: uefi::proto::console::gop::BltRegion::Full,
                dest: (0, 0),
                dims: (width, height),
            })?;
        }
    }
    Ok(())
}

fn present_region(
    gop: &mut GraphicsOutput,
    canvas: &Canvas,
    rect: (usize, usize, usize, usize),
) -> uefi::Result {
    let (x, y, width, height) = rect;
    let mode = gop.current_mode_info();
    let (frame_width, frame_height) = mode.resolution();
    let stride = mode.stride();
    let src = canvas.copy_region(rect).ok_or(uefi::Status::DEVICE_ERROR)?;
    if x.checked_add(width)
        .map_or(true, |right| right > frame_width)
        || y.checked_add(height)
            .map_or(true, |bottom| bottom > frame_height)
    {
        return Err(uefi::Status::DEVICE_ERROR.into());
    }
    match mode.pixel_format() {
        PixelFormat::Rgb | PixelFormat::Bgr if stride >= frame_width => {
            let mut fb = gop.frame_buffer();
            let needed = stride
                .checked_mul(frame_height)
                .and_then(|n| n.checked_mul(4))
                .ok_or(uefi::Status::OUT_OF_RESOURCES)?;
            if fb.size() < needed {
                return Err(uefi::Status::DEVICE_ERROR.into());
            }
            let dst = unsafe { core::slice::from_raw_parts_mut(fb.as_mut_ptr(), needed) };
            for row in 0..height {
                for col in 0..width {
                    let p = src[row * width + col];
                    let i = ((y + row) * stride + x + col) * 4;
                    if mode.pixel_format() == PixelFormat::Rgb {
                        dst[i] = p[0];
                        dst[i + 1] = p[1];
                        dst[i + 2] = p[2]
                    } else {
                        dst[i] = p[2];
                        dst[i + 1] = p[1];
                        dst[i + 2] = p[0]
                    }
                    dst[i + 3] = 0;
                }
            }
        }
        _ => {
            let mut pixels: Vec<BltPixel> = Vec::new();
            pixels
                .try_reserve_exact(src.len())
                .map_err(|_| uefi::Status::OUT_OF_RESOURCES)?;
            pixels.extend(src.iter().map(|p| BltPixel::new(p[0], p[1], p[2])));
            gop.blt(BltOp::BufferToVideo {
                buffer: &pixels,
                src: uefi::proto::console::gop::BltRegion::Full,
                dest: (x, y),
                dims: (width, height),
            })?;
        }
    }
    Ok(())
}

#[derive(Clone, Copy, Debug)]
enum BackendError {
    Path,
    Load(Status),
    Start(Status),
}

fn start_live_backend() -> Result<(), BackendError> {
    let parent = uefi::boot::image_handle();
    let parent_image = uefi::boot::open_protocol_exclusive::<LoadedImage>(parent)
        .map_err(|_| BackendError::Path)?;
    let device = parent_image.device().ok_or(BackendError::Path)?;
    drop(parent_image);

    let device_path = uefi::boot::open_protocol_exclusive::<DevicePath>(device)
        .map_err(|_| BackendError::Path)?;
    let mut path_bytes = Vec::new();
    let mut path_builder = build::DevicePathBuilder::with_vec(&mut path_bytes);
    for node in device_path.node_iter() {
        path_builder = path_builder.push(&node).map_err(|_| BackendError::Path)?;
    }
    path_builder = path_builder
        .push(&build::media::FilePath {
            path_name: BACKEND_FILE,
        })
        .map_err(|_| BackendError::Path)?;
    let full_path = path_builder.finalize().map_err(|_| BackendError::Path)?;
    drop(device_path);

    let child = uefi::boot::load_image(
        parent,
        uefi::boot::LoadImageSource::FromDevicePath {
            device_path: full_path,
            boot_policy: uefi::proto::BootPolicy::ExactMatch,
        },
    )
    .map_err(|error| BackendError::Load(error.status()))?;

    uefi::boot::start_image(child).map_err(|error| BackendError::Start(error.status()))
}

fn preferred_mode() -> Option<(usize, usize)> {
    match option_env!("ATLAS_BOOT_TARGET")? {
        "1920x1080" => Some((1920, 1080)),
        "1366x768" => Some((1366, 768)),
        "1368x768" => Some((1368, 768)),
        "1280x720" => Some((1280, 720)),
        _ => None,
    }
}
