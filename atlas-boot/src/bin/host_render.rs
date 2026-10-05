use atlas_boot_manager::{UiState, render};
use std::{env, fs, path::PathBuf};

fn main() {
    let args: Vec<String> = env::args().collect();
    let out = args
        .get(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("../dist/validation/atlas-boot"));
    fs::create_dir_all(&out).expect("create output directory");
    let state = UiState::new();
    for (w, h) in [(1920usize, 1080usize), (1366, 768), (1280, 720)] {
        let canvas = render(w, h, state.selected, state.seconds_left, None)
            .expect("valid framebuffer geometry");
        let mut rgba = Vec::with_capacity(w * h * 4);
        for px in canvas.pixels {
            rgba.extend_from_slice(&px);
        }
        image::save_buffer(
            out.join(format!("host-{w}x{h}.png")),
            &rgba,
            w as u32,
            h as u32,
            image::ColorType::Rgba8,
        )
        .expect("write screenshot");
    }
    println!("Host renders saved under {}", out.display());
}
