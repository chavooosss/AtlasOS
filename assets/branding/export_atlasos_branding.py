#!/usr/bin/env python3
"""Export the approved two-color emblem into AtlasOS' system logo variants."""

from pathlib import Path
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[2]
BRAND = ROOT / "config/includes.chroot/usr/share/atlasos/branding"
THEME = ROOT / "config/includes.chroot/usr/share/plymouth/themes/atlasos"
TREE = ET.parse(ROOT / "assets/branding/atlasos-emblem-traced.svg")
NS = "{http://www.w3.org/2000/svg}"
paths = {node.attrib["id"]: node.attrib["d"] for node in TREE.findall(f".//{NS}path")}
cyan = paths["atlas-cyan"]
navy = paths["atlas-navy"]


def mark(transform: str = "", mono: bool = False, dark: bool = False) -> str:
    c, n = ("#ffffff", "#ffffff") if mono else ("#0b9bdd", "#f4fbff" if dark else "#102e63")
    return f'''<g transform="{transform}">
  <path d="{cyan}" fill="{c}" fill-rule="evenodd"/>
  <path d="{navy}" fill="{n}" fill-rule="evenodd"/>
</g>'''


def save(path: Path, width: int, height: int, content: str, label: str) -> None:
    path.write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-label="{label}">\n{content}\n</svg>\n',
        encoding="utf-8",
    )


symbol_transform = "translate(10 10) scale(0.80)"
save(BRAND / "atlas-symbol.svg", 1000, 900, mark(symbol_transform), "AtlasOS pusula amblemi")
save(BRAND / "atlas-mono.svg", 1000, 900, mark(symbol_transform, mono=True), "AtlasOS tek renkli amblem")

primary = mark("translate(7 17) scale(0.078)") + '''
<text x="119" y="77" font-family="DejaVu Sans, sans-serif" font-size="48" font-weight="700">
  <tspan fill="#102e63">Atlas</tspan><tspan fill="#0b9bdd">OS</tspan>
</text>
<text x="121" y="101" font-family="DejaVu Sans, sans-serif" font-size="11" letter-spacing="2.4" fill="#61788c">ÖĞRENME ALANI</text>'''
save(BRAND / "atlas-primary.svg", 520, 128, primary, "AtlasOS")

plymouth = mark("translate(28 22) scale(0.50)", dark=True) + '''
<text x="330" y="662" text-anchor="middle" font-family="DejaVu Sans, sans-serif" font-size="54" font-weight="700" fill="#f4fbff">AtlasOS</text>
<text x="330" y="706" text-anchor="middle" font-family="DejaVu Sans, sans-serif" font-size="16" letter-spacing="4" fill="#9dbdcc">ÖĞRENME ALANI</text>'''
save(THEME / "atlas-plymouth.svg", 660, 740, plymouth, "AtlasOS açılış ve kapanış logosu")

boot = '''<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#071c31"/><stop offset="1" stop-color="#123f60"/></linearGradient>
  <radialGradient id="glow"><stop offset="0" stop-color="#0b9bdd" stop-opacity=".28"/><stop offset="1" stop-color="#0b9bdd" stop-opacity="0"/></radialGradient>
</defs>
<rect width="1920" height="1080" fill="url(#bg)"/>
<circle cx="1510" cy="510" r="640" fill="url(#glow)"/>
<g fill="none" stroke="#70d6cf" stroke-opacity=".10" stroke-width="2"><path d="M1080 0v1080M1200 0v1080M1320 0v1080M1440 0v1080M1560 0v1080M1680 0v1080M1800 0v1080"/><path d="M960 120h960M960 240h960M960 360h960M960 480h960M960 600h960M960 720h960M960 840h960M960 960h960"/></g>
<g transform="translate(1188 160) scale(0.49)">'''+mark(dark=True)+'''</g>
<text x="1484" y="790" text-anchor="middle" font-family="DejaVu Sans, sans-serif" font-size="64" font-weight="700" fill="#f4fbff">AtlasOS</text>
<text x="1484" y="836" text-anchor="middle" font-family="DejaVu Sans, sans-serif" font-size="20" letter-spacing="4" fill="#a9c9d7">ÖĞRENME ALANI</text>'''
save(BRAND / "atlas-boot.svg", 1920, 1080, boot, "AtlasOS önyükleme menüsü")
print("Exported symbol, horizontal wordmark, Plymouth lockup, and boot menu branding")
