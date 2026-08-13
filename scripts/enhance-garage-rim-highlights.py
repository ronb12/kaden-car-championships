#!/usr/bin/env python3
"""Subtle rim highlights on top-down garage car PNGs (tire edge brightening)."""
from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image, ImageFilter, ImageEnhance
except ImportError:
    print("Install Pillow: pip install Pillow", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]
GARAGE = ROOT / "garage-cars"


def enhance(path: Path) -> None:
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()

  # Mask: dark tire-like pixels in lower corners (wheel wells in top-down art)
    mask = Image.new("L", (w, h), 0)
    mp = mask.load()
    for y in range(int(h * 0.42), h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 40:
                continue
            lum = (r + g + b) / 3
            in_corner = x < w * 0.34 or x > w * 0.66
            if in_corner and lum < 72:
                mp[x, y] = min(255, int((72 - lum) * 3.2))

    highlight = Image.new("RGBA", (w, h), (220, 225, 235, 0))
    hp = highlight.load()
    for y in range(h):
        for x in range(w):
            m = mp[x, y]
            if m:
                hp[x, y] = (235, 240, 255, min(48, m // 3))

    highlight = highlight.filter(ImageFilter.GaussianBlur(radius=1.2))
    out = Image.alpha_composite(im, highlight)
    out = ImageEnhance.Contrast(out).enhance(1.03)
    out.save(path, optimize=True)
    print("enhanced", path.name)


def main() -> None:
    if not GARAGE.is_dir():
        print("Missing garage-cars/", file=sys.stderr)
        sys.exit(1)
    for png in sorted(GARAGE.glob("*.png")):
        if png.name == "car-police.png":
            continue
        enhance(png)


if __name__ == "__main__":
    main()
