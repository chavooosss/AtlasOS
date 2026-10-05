fn main() {
    println!("cargo:rerun-if-env-changed=ATLAS_BOOT_TARGET");
    if let Ok(target) = std::env::var("ATLAS_BOOT_TARGET") {
        println!("cargo:rustc-env=ATLAS_BOOT_TARGET={target}");
    }
    println!("cargo:rerun-if-changed=assets/generated/landscape.rgba");
    for size in [16, 20, 28, 42, 52] {
        println!("cargo:rerun-if-changed=assets/generated/glyphs-{size}.alpha");
    }
    println!("cargo:rerun-if-changed=assets/generated/boot-mark.rgba");
    for icon in 0..5 {
        println!("cargo:rerun-if-changed=assets/generated/icon-{icon}.alpha");
    }
    println!("cargo:rerun-if-changed=src/glyph_metrics.rs");
}
