# Atlas Paper Refinement — 2026-10-24

## Result and source

Atlas Paper second refinement and a separate 0.6.4 test ISO build completed in `/home/no-labell/atlasos-consolidated-064`. Branch/HEAD: `recovery/primary-0aaa581` / `0aaa581f51b016f21ab6b66d1d647b63b12f03fd`. No commit, push, merge, GitHub action, or source cleanup occurred. The checkout already had multiple unrelated dirty files; these were preserved.

This turn changed only `config/includes.chroot/usr/local/share/atlasos/ui/components/AtlasPdf.qml` and added `tests/test_atlas_paper.py`. Existing dirty work in browser, diagnostics, system UI, build configuration, and other tests remains untouched.

## Atlas Paper changes

- Grouped the toolbar into consistent document/page and viewing/search/presentation rows using Atlas colors and controls.
- Added distinct PDF-engine `fit-page` and `fit-width` modes plus custom zoom; the displayed percentage follows the actual render scale and fitting is reapplied after geometry changes.
- Added Page Up/Down, left/right, Home/End navigation in windowed and immersive modes; search input retains typing behavior and Escape exits immersive mode.
- Added asynchronous, cached real `PdfPageImage` thumbnails with page labels, active-page highlighting, and click-to-navigate. The cache is bounded for longer documents.
- Close the thumbnail rail before switching document source, preventing stale delegates and Qt's document/source conflict warning.
- Kept the vector PDF renderer and `PdfMultiPageView` scroll implementation; no competing gesture layer was introduced.

## Captures

Rendered from current AtlasOS QML/Main.qml using Qt offscreen software rendering and a generated three-page PDF whose pages have distinct text and colors. Not physical-device captures. The full-window screenshots show page 1 with thumbnail rail closed; thumbnail image content and selection were verified in runtime tests.

- Fixture: `/home/no-labell/atlasos-consolidated-064/reports/atlas-paper-refinement-captures/atlas-paper-multipage-fixture.pdf`
- 1366×768: `/home/no-labell/atlasos-consolidated-064/reports/atlas-paper-refinement-captures/atlas-paper-refinement-1366x768.png`
- 1920×1080: `/home/no-labell/atlasos-consolidated-064/reports/atlas-paper-refinement-captures/atlas-paper-refinement-1920x1080.png`
- 3840×2160: `/home/no-labell/atlasos-consolidated-064/reports/atlas-paper-refinement-captures/atlas-paper-refinement-3840x2160.png`

The PNG dimensions were verified with `file` and match their names.

## Validation

- Atlas Paper focused suite, Qt runtime enabled: **13 passed, 0 failed** (4 runtime, 9 static). Verified distinct real page thumbnails and navigation, keyboard controls/fullscreen/search focus, fit modes/scale, scrollable PDF surface, document switching, and invalid-PDF handling. The invalid fixture produces the expected Qt “failed to load page” diagnostic.
- Full Python suite: **172 total, 167 passed, 0 failed, 5 skipped**; opt-in runtime tests ran separately above.
- Atlas Boot Rust tests: **16 passed, 0 failed**.
- `git diff --check`: **PASS**.
- Synthetic offscreen drag did not prove an actual scroll gesture. Physical touch/drag and laptop mouse behavior remain unverified.

## New ISO artifacts

Separate output root: `/home/no-labell/atlasos-consolidated-064/dist/validation/consolidated-064-atlas-paper-refinement/`.

Base ISO: `/home/no-labell/atlasos-consolidated-064/dist/validation/consolidated-064-atlas-paper-refinement/base/AtlasOS-0.6.4-Atlas-Paper-Refined-base-amd64.iso` — 3,275,960,320 bytes; SHA-256 `939021a16516a00814103e1246c3b1dc75de4b8189f0c2b9ff7cdfe63f54bee8`. Build metadata says 0.6.4; the embedded squashfs `AtlasPdf.qml` byte-matches the source.

Integrated ISO: `/home/no-labell/atlasos-consolidated-064/dist/validation/consolidated-064-atlas-paper-refinement/final/AtlasOS-0.6.4-Atlas-Paper-Refined-Integrated-amd64.iso` — 3,275,292,672 bytes; SHA-256 `e0c7bca465dfb9da14d86f7556436a4c45b685857d655fcc9386e759ed52a8ad`. Embedded manifest was regenerated and compared. Extracted EFI frontend/backend match in both ISO root and EFI image: BOOTX64 `73badfd43213efbdf53ae0417c07243b6bce1d199e1f30071ec10e5c61ea2ac2`; ATLASGRUB `b4e833c68a116d38abce823f7e923dd8a2ef7b8692e4d09f16c5841c3cb8932b`.

QEMU/OVMF 1920×1080: **PASS**. Atlas Boot handed off to Live; desktop capture at 180 seconds shows AtlasOS 0.6.4. Evidence: `/home/no-labell/atlasos-consolidated-064/dist/validation/consolidated-064-atlas-paper-refinement/qemu-1920x1080-live/` (`result.txt`, `live-180s.ppm`). This is a VM smoke, not hardware acceptance.

## Existing ISO preservation and remaining work

Re-hashed values match recorded hashes: previous Atlas Paper ISO `2004da15e99561608da219464244b4f37cc7579b610e22442d365ccf4b6ea52a`; SSID privacy ISO `d26e45f0bf46f6b90574c342bd7911b76b5c2afbe6c64db7cacfa803bf271c07`; Consolidated ISO `91ab89e8991671fa872acf361794e9d6931e99e8e871bae2b26616b8c6c6fc4d`; protected Test3 ISO `a96f40df1730cfdd7045bab9619ee565b8bc83d7108fcf95d3c44142db0214a5`. None was overwritten or removed.

A laptop test is still needed for packaged keyboard/mouse behavior, native-DPI sharpness, and touch-target comfort. Physical smartboard touch testing remains required. No large-document soak or physical PDF readability test was performed. No commit, push, merge, tag, or release was made.