#!/usr/bin/env python3
"""Build the in-app brand mark (assets/logo/AttNote_Inside_App.png) from source.

The source artwork in logo/AttNote_Inside_App.png is a 1024x1024 canvas where
the glyph only fills the top-left ~42% width / ~49% height, surrounded by a sea
of transparent padding (plus faint near-transparent ghost pixels trailing
downward). Because AppLogo renders it with BoxFit.contain, that padding gets
scaled in too — so the *visible* mark looks tiny relative to the box it's given.

We trim to the solid content bounds, add a small breathing margin, then center
it on a square transparent canvas so the glyph fills its allotted size at any
AppLogo(size: ...). Output is downscaled to 512x512 (ample for in-app use,
and a fraction of the 1.3 MB source).
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "logo" / "AttNote_Inside_App.png"
DEST = ROOT / "assets" / "logo" / "AttNote_Inside_App.png"

ALPHA_THRESHOLD = 32  # ignore anti-aliased / ghost pixels below this opacity
OUT_SIZE = 512

# The glyph is bottom-heavy: its centre of mass sits ~12% below its geometric
# centre (thin checkmark up top, dense notebook + figures down low). Centring
# the bounding box geometrically therefore reads as "stretching down". We give
# it more room below than above so the visual weight lands in the middle.
TOP_MARGIN_FRAC = 0.04     # space above the glyph, as fraction of glyph height
BOTTOM_MARGIN_FRAC = 0.11  # space below the glyph, as fraction of glyph height


def solid_bbox(img: Image.Image) -> tuple[int, int, int, int]:
    """Bounding box of pixels more opaque than ALPHA_THRESHOLD."""
    alpha = img.split()[3]
    mask = alpha.point(lambda p: 255 if p > ALPHA_THRESHOLD else 0)
    bbox = mask.getbbox()
    if bbox is None:
        raise SystemExit("Source image appears fully transparent")
    return bbox


def main() -> None:
    print(f"Source: {SOURCE.relative_to(ROOT)}")
    img = Image.open(SOURCE).convert("RGBA")
    left, top, right, bottom = solid_bbox(img)
    glyph = img.crop((left, top, right, bottom))
    print(f"Trimmed to glyph {glyph.size} (from {img.size})")

    # Square canvas big enough to hold the glyph plus its top/bottom margins.
    # Horizontal margins fall out symmetrically so the canvas stays square; the
    # asymmetric vertical margins lift the bottom-heavy glyph into optical centre.
    gw, gh = glyph.size
    top_m = round(gh * TOP_MARGIN_FRAC)
    bottom_m = round(gh * BOTTOM_MARGIN_FRAC)
    side = gh + top_m + bottom_m
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    ox = (side - gw) // 2
    oy = top_m
    canvas.paste(glyph, (ox, oy), glyph)

    out = canvas.resize((OUT_SIZE, OUT_SIZE), Image.LANCZOS)
    DEST.parent.mkdir(parents=True, exist_ok=True)
    out.save(DEST, format="PNG", optimize=True)
    print(f"Wrote {DEST.relative_to(ROOT)} ({OUT_SIZE}x{OUT_SIZE})")


if __name__ == "__main__":
    main()
