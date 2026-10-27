#!/usr/bin/env python3
"""Zone palette cards: one picture per zone that an image model (or a person) can read as the palette.

Each card is 1536 x 1024 (3:2, the same shape as the map pictures) on the cream paper:
  * top: one iso block per material (grass, forest, path, rock, stone, water) painted in the zone's
    top / lit / shade values with the ink outline, so the card also shows how light falls (B10, B11)
  * bottom: the same colours as flat swatch columns (top, lit, shade), then pine, ink and paper

    python3 tools/art/palette_cards.py      # writes art/palettes/

Outputs per zone: <zone>.png (no text: use this one as a reference image in Picsart / GPT / Krita),
<zone>-labeled.png (names and hex codes, for people), and lodestone-zones.gpl (Krita / GIMP swatches).
The zone colours live in battle_art.py (P for home, FOREST, SNOW, DESERT, DUNGEON).
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import battle_art as ba  # noqa: E402

OUT = ba.ROOT / "art/palettes"
SIZE = (1536, 1024)
ZONES = {"home": {}, **ba.ZONES}

# material -> (terrain letter for the block, top key, lit key, shade key)
MATERIALS = [
    ("grass", "g", "grass_light", "stone_lit", "stone_shade"),
    ("forest", "f", "moss", "stone_lit", "stone_shade"),
    ("path", "d", "path", "stone_lit", "stone_shade"),
    ("rock", "r", "stone_pale", "stone_lit", "stone_shade"),
    ("stone", "s", "stone_top", "stone_lit", "stone_shade"),
    ("water", "w", "water", "water_deep", "foam"),  # water: surface, falls and deep, foam
]
EXTRA = ["pine", "moss_dark", "stone_mid", "stone_deep", "ink", "paper"]


def luma(c):
    return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]


def card(labeled: bool) -> Image.Image:
    im = Image.new("RGB", SIZE, ba.PAPER)
    dr = ImageDraw.Draw(im)
    col_w = SIZE[0] // len(MATERIALS)
    small = ba.font(18)
    # iso blocks: one cell, 2 levels tall, drawn at 2/3 size then scaled up 1.5x to fill each column
    k = 1.5
    blocks = Image.new("RGBA", (int(SIZE[0] / k), int(340 / k)), (0, 0, 0, 0))
    bd = ImageDraw.Draw(blocks)
    for i, (name, t, *_keys) in enumerate(MATERIALS):
        cx = (col_w * i + col_w / 2) / k
        iso = ba.Iso(1, 1, (cx, 92), 0)
        faces = ba.map_faces([[2]], [[t]], iso, base=0)
        layer = ba.render_blocking(faces, blocks.size, iso)
        blocks.alpha_composite(layer)
        for kind, _t, pts, _w in faces:
            bd.polygon(pts, outline=ba.INK + (255,), width=2)
    blocks = blocks.resize((SIZE[0], 340), Image.LANCZOS)
    im.paste(blocks, (0, 10), blocks)
    if labeled:
        for i, (name, *_r) in enumerate(MATERIALS):
            dr.text((col_w * i + col_w / 2 - 30, 356), name, fill=ba.INK, font=ba.font(22))
    # swatch columns: top, lit, shade per material
    sw = col_w - 60
    sh = 110
    y0 = 400
    for i, (name, t, top, lit, shade) in enumerate(MATERIALS):
        x = col_w * i + 30
        for j, key in enumerate((top, lit, shade)):
            y = y0 + j * (sh + 14)
            dr.rectangle([x, y, x + sw, y + sh], fill=ba.rgb(key), outline=ba.INK, width=3)
            if labeled:
                dr.text((x + 8, y + 8), f"{key}\n{ba.P[key]}", fill=ba.INK if luma(ba.rgb(key)) > 110 else ba.PAPER, font=small)
    # extras strip
    ew = (SIZE[0] - 60) // len(EXTRA)
    y = y0 + 3 * (sh + 14) + 10
    for k, key in enumerate(EXTRA):
        x = 30 + k * ew
        dr.rectangle([x, y, x + ew - 16, y + 120], fill=ba.rgb(key), outline=ba.INK, width=3)
        if labeled:
            dr.text((x + 8, y + 8), f"{key}\n{ba.P[key]}", fill=ba.INK if luma(ba.rgb(key)) > 110 else ba.PAPER, font=small)
    return im


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    gpl = ["GIMP Palette", "Name: Lodestone zones", "Columns: 8", "#"]
    for zone, over in ZONES.items():
        def build():
            card(False).save(OUT / f"{zone}.png")
            card(True).save(OUT / f"{zone}-labeled.png")
            gpl.append(f"# {zone}")
            keys = list(dict.fromkeys([k for m in MATERIALS for k in m[2:]] + EXTRA))
            for key in keys:
                r, g, b = ba.rgb(key)
                gpl.append(f"{r:3d} {g:3d} {b:3d}\t{zone} {key}")
            # B11 check: lit and shade against the stone top (the one top every zone shares)
            top = luma(ba.rgb("stone_top"))
            print(f"{zone:8s} lit {luma(ba.rgb('stone_lit')) / top:.0%}  shade {luma(ba.rgb('stone_shade')) / top:.0%}  (aim 75% / 55%)")
        ba.with_palette(over, build)
    (OUT / "lodestone-zones.gpl").write_text("\n".join(gpl) + "\n")
    print("wrote", OUT.relative_to(ba.ROOT))


if __name__ == "__main__":
    main()
