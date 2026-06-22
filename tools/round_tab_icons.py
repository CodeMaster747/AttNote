#!/usr/bin/env python3
"""Generate rounded-corner web favicon + PWA icons from logo/AttNote_Logo_Tab.png.

The source artwork sits on a white square with whitespace padding around the
glyph. We trim the padding, square the result, resize to each target, then
apply a rounded-rect alpha mask so the browser tab actually shows rounded
corners (instead of a square white box).
"""

from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "logo" / "AttNote_Logo_Tab.png"
WEB = ROOT / "web"

# Output: (path, edge length, corner radius as fraction of edge)
TARGETS = [
    (WEB / "favicon.png", 64, 0.22),
    (WEB / "icons" / "Icon-192.png", 192, 0.22),
    (WEB / "icons" / "Icon-512.png", 512, 0.22),
    # Maskable icons are intended to be cropped by the platform; keep a
    # generous safe zone and don't pre-round (the platform applies its own
    # mask). We still trim padding so the glyph fills the safe area.
    (WEB / "icons" / "Icon-maskable-192.png", 192, 0.0),
    (WEB / "icons" / "Icon-maskable-512.png", 512, 0.0),
]


def trim_white(img: Image.Image, threshold: int = 240) -> Image.Image:
    """Crop the largest centered square that hugs non-white pixels."""
    gray = img.convert("L")
    px = gray.load()
    w, h = gray.size

    def is_content(x: int, y: int) -> bool:
        return px[x, y] < threshold

    # Find bounding box of content
    left = next((x for x in range(w) if any(is_content(x, y) for y in range(h))), 0)
    right = next((x for x in range(w - 1, -1, -1) if any(is_content(x, y) for y in range(h))), w - 1)
    top = next((y for y in range(h) if any(is_content(x, y) for x in range(w))), 0)
    bottom = next((y for y in range(h - 1, -1, -1) if any(is_content(x, y) for x in range(w))), h - 1)

    # Square it up around the content's center, with a small inset margin.
    cx = (left + right) // 2
    cy = (top + bottom) // 2
    side = max(right - left, bottom - top)
    margin = int(side * 0.06)  # 6% breathing room
    side += margin * 2
    half = side // 2

    x0 = max(0, cx - half)
    y0 = max(0, cy - half)
    x1 = min(w, cx + half)
    y1 = min(h, cy + half)
    return img.crop((x0, y0, x1, y1))


def rounded(img: Image.Image, radius_frac: float) -> Image.Image:
    """Apply a rounded-rect alpha mask. radius_frac is fraction of edge length."""
    img = img.convert("RGBA")
    w, h = img.size
    if radius_frac <= 0:
        return img
    r = int(min(w, h) * radius_frac)
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([(0, 0), (w - 1, h - 1)], radius=r, fill=255)
    img.putalpha(mask)
    return img


def main() -> None:
    print(f"Source: {SOURCE.relative_to(ROOT)}")
    src = Image.open(SOURCE)
    src = trim_white(src)
    print(f"Trimmed to {src.size}")

    for path, size, radius in TARGETS:
        resized = src.resize((size, size), Image.LANCZOS)
        out = rounded(resized, radius)
        out.save(path, format="PNG", optimize=True)
        print(f"  wrote {path.relative_to(ROOT)} ({size}x{size}, r={radius:.0%})")


if __name__ == "__main__":
    main()
