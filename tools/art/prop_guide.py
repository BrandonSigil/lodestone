#!/usr/bin/env python3
"""Grey block-out guide for village v2 props, drawn on the true 2:1 dimetric grid (tile diamond 256 x 128).

    ~/.lodestone/venv/bin/python tools/art/prop_guide.py   # writes art/templates/props/guide_village_v2_redo.png

Four cells (crops, grave mound, headstone, iron fence); each is a plain grey box block-out whose ground edges run at
exactly 26.565 degrees. It goes to Picsart as Image 1 so the painted prop follows those edges (the same guided flow
the buildings use). No art is painted: boxes and lines only.
"""
from pathlib import Path

from PIL import Image, ImageDraw

W, H = 1536, 1024
TW, TH = 128, 64  # half-tile: x = (i - j) * TW, y = (i + j) * TH


def box(d, ox, oy, i0, i1, j0, j1, z0, z1):
    def p(i, j, z):
        return (ox + (i - j) * TW, oy + (i + j) * TH - z)
    top = [p(i0, j0, z1), p(i1, j0, z1), p(i1, j1, z1), p(i0, j1, z1)]
    left = [p(i0, j1, z1), p(i1, j1, z1), p(i1, j1, z0), p(i0, j1, z0)]  # faces lower-left
    right = [p(i1, j0, z1), p(i1, j1, z1), p(i1, j1, z0), p(i1, j0, z0)]  # faces lower-right
    d.polygon(left, fill=(150, 150, 150), outline=(70, 70, 70))
    d.polygon(right, fill=(110, 110, 110), outline=(70, 70, 70))
    d.polygon(top, fill=(205, 205, 205), outline=(70, 70, 70))


def main():
    im = Image.new("RGB", (W, H), (234, 232, 214))
    d = ImageDraw.Draw(im)
    cx = (W // 4, 3 * W // 4)
    cy = (H // 4, 3 * H // 4)
    # crops: a 2 x 2 tile bed, low
    ox, oy = cx[0], cy[0] - 150
    box(d, ox, oy, 0, 2, 0, 2, 0, 18)
    # grave mound: one tile, low mound block, a thin upright cross post at the back
    ox, oy = cx[1], cy[0] - 40
    box(d, ox, oy, 0.1, 0.9, 0.1, 0.9, 0, 34)
    box(d, ox, oy, 0.1, 0.3, 0.4, 0.6, 34, 130)
    # headstone: a thin slab, long side along the down-right axis
    ox, oy = cx[0], cy[1] - 90
    box(d, ox, oy, 0.4, 0.6, 0.1, 0.9, 0, 150)
    # iron fence: a thin wall along one tile edge with a post at each end
    ox, oy = cx[1], cy[1] - 90
    box(d, ox, oy, 0.4, 0.6, 0.0, 1.0, 20, 120)
    box(d, ox, oy, 0.35, 0.65, 0.0, 0.18, 0, 150)
    box(d, ox, oy, 0.35, 0.65, 0.82, 1.0, 0, 150)
    out = Path("art/templates/props/guide_village_v2_redo.png")
    im.save(out)
    print(out)


if __name__ == "__main__":
    main()
