#!/usr/bin/env python3
"""Lay the game's tile grid and the hero over a building sprite, the way CombatBoard places it. Read-only.

    ~/.lodestone/venv/bin/python tools/art/building_grid.py art/picsart/out/village-fall/cut/b_home_b.png --foot 4x3
    ~/.lodestone/venv/bin/python tools/art/building_grid.py cut/b_smithy.png --foot 3x4 --out /tmp/smithy_grid.png

A building (catalog `tall` 0) is drawn with its image spanning the footprint's width and its bottom on the
footprint's front corner (CombatBoard._prop_rect). --foot is catalog foot_w x foot_h: foot_w runs along the
LEFT front wall (the door wall), foot_h along the right. The overlay draws the footprint cells and one ring
of cells round them, and stands the hero (lead_stand_se at the board's 0.5 sprite scale) on the cell in front
of the middle of the left wall, where the door goes, so door height and footprint fit can be checked by eye.
Prints how far the building's painted base strays from the footprint diamond.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]
TW, TH = 64.0, 32.0  # CombatBoard tile size on screen
HERO = REPO / "game/art/source/characters/lead/lead_stand_se.png"
HERO_ANCHOR, HERO_SCALE = (96, 160), 0.5


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--foot", required=True, help="foot_w x foot_h from game/data/catalog.csv, e.g. 4x3")
    ap.add_argument("--out", help="default: <image>_grid.png beside the image")
    args = ap.parse_args()
    fw, fh = (int(v) for v in args.foot.lower().split("x"))

    img = Image.open(args.image).convert("RGBA")
    span = (fw + fh) * TW * 0.5
    s = img.width / span
    pad = int(2 * TW * s)
    canvas = Image.new("RGBA", (img.width + 2 * pad, img.height + 2 * pad), (234, 232, 214, 255))
    canvas.alpha_composite(img, (pad, pad))

    lo_x, hi_y = -fh * TW * 0.5, (fw + fh) * TH * 0.5

    def px(x, y):  # grid point (x along the left wall, y along the right wall) -> canvas pixel
        sx, sy = (x - y) * TW * 0.5, (x + y) * TH * 0.5
        # iso() puts +x to the lower right; the door wall runs from the left corner (0, fh) to the front (fw, fh)
        return pad + (sx - lo_x) * s, pad + img.height - (hi_y - sy) * s

    over = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for i in range(-1, fw + 2):
        d.line([px(i, -1), px(i, fh + 1)], fill=(40, 120, 200, 90), width=2)
    for j in range(-1, fh + 2):
        d.line([px(-1, j), px(fw + 1, j)], fill=(40, 120, 200, 90), width=2)
    for i in range(fw + 1):
        d.line([px(i, 0), px(i, fh)], fill=(0, 150, 255, 200), width=3)
    for j in range(fh + 1):
        d.line([px(0, j), px(fw, j)], fill=(0, 150, 255, 200), width=3)
    d.polygon([px(0, 0), px(fw, 0), px(fw, fh), px(0, fh)], outline=(255, 60, 60, 230), width=4)
    canvas.alpha_composite(over)
    # Grid on top of the building would hide it; draw the building again at half strength over the grid.
    ghost = img.copy()
    ghost.putalpha(Image.fromarray((np.asarray(img)[:, :, 3] * 0.55).astype(np.uint8)))
    canvas.alpha_composite(ghost, (pad, pad))
    over2 = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d2 = ImageDraw.Draw(over2)
    d2.polygon([px(0, 0), px(fw, 0), px(fw, fh), px(0, fh)], outline=(255, 60, 60, 230), width=4)
    canvas.alpha_composite(over2)

    hero = Image.open(HERO).convert("RGBA")
    k = HERO_SCALE * s
    hero = hero.resize((round(hero.width * k), round(hero.height * k)), Image.LANCZOS)
    door = px(fw * 0.5, fh + 0.5)  # middle of the cell row in front of the left wall
    canvas.alpha_composite(hero, (round(door[0] - HERO_ANCHOR[0] * k), round(door[1] - HERO_ANCHOR[1] * k)))

    # How far the painted base strays: lowest opaque row against the footprint's front corner.
    a = np.asarray(img)[:, :, 3] > 40
    rows = np.nonzero(a.any(1))[0]
    print("%s: foot %dx%d, scale %.2f px per screen px, base %d px %s the front corner, hero %d px tall"
          % (Path(args.image).name, fw, fh, s, abs(img.height - 1 - rows[-1]),
             "above" if rows[-1] < img.height - 1 else "at", round(108 * k)))
    out = Path(args.out) if args.out else Path(args.image).with_name(Path(args.image).stem + "_grid.png")
    canvas.convert("RGB").save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
