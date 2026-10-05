from pathlib import Path
from PIL import Image

root=Path(__file__).resolve().parents[2]/"dist/validation/atlas-boot/phase6/finalvisual/qemu"
for ppm in sorted(root.glob("qemu-*.ppm")):
    with Image.open(ppm) as im:
        im.save(ppm.with_suffix(".png"), optimize=True)
        print(f"{ppm.name}: {im.size[0]}x{im.size[1]} -> {ppm.with_suffix('.png').name}")
    ppm.unlink()
