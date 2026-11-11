import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
UEFI_MAIN = ROOT / "atlas-boot/src/bin/uefi_main.rs"


class AtlasBootFirstFrameTests(unittest.TestCase):
    def test_first_full_frame_is_submitted_as_one_complete_gop_blit(self):
        source = UEFI_MAIN.read_text(encoding="utf-8")
        full_frame = source.split("fn present_full(", 1)[1].split("\nfn present_region(", 1)[0]
        self.assertIn("gop.blt(BltOp::BufferToVideo", full_frame)
        self.assertIn("BltRegion::Full", full_frame)
        self.assertIn("dims: (width, height)", full_frame)
        self.assertIn("pixels.extend(src.iter().map(|p| BltPixel::new(p[0], p[1], p[2])))", full_frame)
        self.assertNotIn("frame_buffer()", full_frame)
        self.assertNotIn("dst[i]", full_frame)

    def test_canvas_is_complete_before_first_gop_submission(self):
        source = UEFI_MAIN.read_text(encoding="utf-8")
        present_frame = source.split("fn present_frame(", 1)[1].split("\nfn select_preferred_mode(", 1)[0]
        self.assertLess(present_frame.index("render_base("), present_frame.index("draw_countdown("))
        self.assertLess(present_frame.index("draw_countdown("), present_frame.index("present_full("))
        self.assertIn("select_preferred_mode(&mut gop)", present_frame)

    def test_partial_countdown_updates_keep_existing_path(self):
        source = UEFI_MAIN.read_text(encoding="utf-8")
        present_region = source.split("fn present_region(", 1)[1].split("\n#[derive(Clone, Copy, Debug)]", 1)[0]
        self.assertIn("gop.blt(BltOp::BufferToVideo", present_region)
        self.assertIn("dest: (x, y)", present_region)


if __name__ == "__main__":
    unittest.main()
