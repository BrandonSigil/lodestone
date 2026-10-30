#!/usr/bin/env python3
"""Grey block-out guide for the bridge kit, on the true 2:1 dimetric grid (tile diamond 256 x 128, one level = 32).

    ~/.lodestone/venv/bin/python tools/art/bridge_guide.py   # writes art/templates/props/guide_bridge_kit.png

Six one-tile pieces, 3 x 2, deck top at 64 (two levels) above the ground line z = 0:
  1 deck_a    a straight deck running down-right (along i), rails both sides, runs the full tile so tiles join
  2 deck_b    the same running down-left (along j)
  3 corner    an L deck joining the up-left edge to the lower-left edge, rails round the outside
  4 landing_a a ramp from the ground (z 0) up to the deck height along i, rails on both sides
  5 landing_b the same along j
  6 pillar    a stone or timber support, from under the deck down to the water (z -128 to 48)
Boxes and wedges only, no art. It goes to Picsart as Image 1 for each material.
"""
from pathlib import Path

from PIL import Image, ImageDraw

W, H = 1536, 1024
TW, TH = 128, 64
OUT = (70, 70, 70)
LEFT, RIGHT, TOP = (150, 150, 150), (110, 110, 110), (205, 205, 205)


def P(ox, oy, i, j, z):
    return (ox + (i - j) * TW, oy + (i + j) * TH - z)


def box(d, o, i0, i1, j0, j1, z0, z1):
    p = lambda i, j, z: P(o[0], o[1], i, j, z)
    d.polygon([p(i0, j1, z1), p(i1, j1, z1), p(i1, j1, z0), p(i0, j1, z0)], fill=LEFT, outline=OUT)
    d.polygon([p(i1, j0, z1), p(i1, j1, z1), p(i1, j1, z0), p(i1, j0, z0)], fill=RIGHT, outline=OUT)
    d.polygon([p(i0, j0, z1), p(i1, j0, z1), p(i1, j1, z1), p(i0, j1, z1)], fill=TOP, outline=OUT)


def main():
    im = Image.new("RGB", (W, H), (234, 232, 214))
    d = ImageDraw.Draw(im)
    cell = lambda c, r: (256 + c * 512, 256 + r * 512)
    def org(c, r):
        cx, cy = cell(c, r)
        return (cx, cy - 64)  # the tile's top corner, so the tile centre sits at the cell centre
    DT, DB, RL = 64, 48, 36  # deck top, deck bottom, rail height above the deck
    # 1 deck_a
    o = org(0, 0)
    box(d, o, 0, 1, 0.1, 0.9, DB, DT)
    box(d, o, 0, 1, 0.1, 0.16, DT, DT + RL)
    box(d, o, 0, 1, 0.84, 0.9, DT, DT + RL)
    # 2 deck_b
    o = org(1, 0)
    box(d, o, 0.1, 0.9, 0, 1, DB, DT)
    box(d, o, 0.1, 0.16, 0, 1, DT, DT + RL)
    box(d, o, 0.84, 0.9, 0, 1, DT, DT + RL)
    # 3 corner: arms to the i = 0 edge and the j = 1 edge
    o = org(2, 0)
    box(d, o, 0, 0.9, 0.1, 0.9, DB, DT)
    box(d, o, 0.1, 0.9, 0.1, 1, DB, DT)
    # 4 landing_a: ramp along i, z 0 at i = 0 up to the deck at i = 1
    o = org(0, 1)
    p = lambda i, j, z: P(o[0], o[1], i, j, z)
    d.polygon([p(0, .9, 0), p(1, .9, DT), p(1, .9, 0)], fill=LEFT, outline=OUT)
    d.polygon([p(1, .1, 0), p(1, .1, DT), p(1, .9, DT), p(1, .9, 0)], fill=RIGHT, outline=OUT)
    d.polygon([p(0, .1, 0), p(1, .1, DT), p(1, .9, DT), p(0, .9, 0)], fill=TOP, outline=OUT)
    # 5 landing_b: ramp along j, z 0 at j = 0 up to the deck at j = 1
    o = org(1, 1)
    p = lambda i, j, z: P(o[0], o[1], i, j, z)
    d.polygon([p(.9, 0, 0), p(.9, 1, DT), p(.9, 1, 0)], fill=RIGHT, outline=OUT)
    d.polygon([p(.1, 1, 0), p(.1, 1, DT), p(.9, 1, DT), p(.9, 1, 0)], fill=LEFT, outline=OUT)
    d.polygon([p(.1, 0, 0), p(.1, 1, DT), p(.9, 1, DT), p(.9, 0, 0)], fill=TOP, outline=OUT)
    # 6 pillar
    o = org(2, 1)
    box(d, o, 0.3, 0.7, 0.3, 0.7, -128, DB)
    out = Path("art/templates/props/guide_bridge_kit.png")
    im.save(out)
    print(out)


if __name__ == "__main__":
    main()
