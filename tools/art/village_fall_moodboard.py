#!/usr/bin/env python3
"""One reference picture for the fall village sheet (art/prompts/village-fall-sheet.txt).

Left: Brandon's River Village sheet (docs/art/references/village-fall-style-sheet.png), the feel:
fall colours, building shapes, how houses sit on the ground. Its title and section labels are covered
with paper so the model doesn't copy text.
Right: the Forest and Farmland panels from the zones sampler
(docs/art/references/picsart/zones-gpt-simple_v1.png), the detail level to simplify down to. Cropped
below their name banners for the same reason.

    ~/.lodestone/venv/bin/python tools/art/village_fall_moodboard.py

Writes docs/art/references/village-fall-moodboard.png.
"""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
REFS = ROOT / "docs/art/references"
FEEL = REFS / "village-fall-style-sheet.png"
ZONES = REFS / "picsart/zones-gpt-simple_v1.png"
OUT = REFS / "village-fall-moodboard.png"

PAPER = (234, 232, 214)  # #eae8d6, the house cream
FEEL_PAPER = (246, 238, 227)  # the River Village sheet's own paper, so the covers don't show
HEIGHT = 1024
GAP = 32

# Text on the River Village sheet, in its own 1536 x 1024 pixels.
FEEL_TEXT = [
    (0, 0, 370, 100),  # title
    (975, 22, 1536, 56),  # tiles / terrain
    (975, 366, 1536, 398),  # buildings
    (0, 746, 1536, 780),  # foliage, props, palette, variants
]

# Zone panels, measured on the 1100 px wide copy of the sampler, below the name banners.
ZONES_BASE_W = 1100
ZONE_PANELS = {
    "forest": (28, 102, 278, 660),
    "farmland": (822, 102, 1072, 660),
}


def feel_panel() -> Image.Image:
    im = Image.open(FEEL).convert("RGB")
    draw = ImageDraw.Draw(im)
    for box in FEEL_TEXT:
        draw.rectangle(box, fill=FEEL_PAPER)
    return im.resize((round(im.width * HEIGHT / im.height), HEIGHT), Image.LANCZOS)


def zone_panel(name: str) -> Image.Image:
    im = Image.open(ZONES).convert("RGB")
    k = im.width / ZONES_BASE_W
    crop = im.crop(tuple(round(v * k) for v in ZONE_PANELS[name]))
    return crop.resize((round(crop.width * HEIGHT / crop.height), HEIGHT), Image.LANCZOS)


def main() -> None:
    parts = [feel_panel(), zone_panel("forest"), zone_panel("farmland")]
    width = sum(p.width for p in parts) + GAP * (len(parts) + 1)
    board = Image.new("RGB", (width, HEIGHT + GAP * 2), PAPER)
    x = GAP
    for part in parts:
        board.paste(part, (x, GAP))
        x += part.width + GAP
    board.save(OUT)
    print(f"{OUT.relative_to(ROOT)} {board.width} x {board.height}")


if __name__ == "__main__":
    main()
