#!/usr/bin/env python3
"""Draw a grey block-out of a building on its game footprint, to send as image 1 with a building prompt.

    python3 tools/art/building_guide.py smithy            # writes art/templates/buildings/guide_smithy.png
    python3 tools/art/building_guide.py --all

The block-out uses CombatBoard's own projection (64 x 32 tiles, 16 px per height level), so whatever the
model paints over it already sits on the footprint from game/data/catalog.csv when cut with
`props_cut.py --width 512`. Light walls face lower left (the door wall), darker walls lower right, roofs
darker still; the door is drawn at its real size, and a plain grey figure the hero's height
(lead_stand, 54 screen px with hair) stands beside it as a size guide. Masses are simple boxes,
gabled or pyramid roofs; the prompt asks the model to keep them and paint the building over them.

Coordinates per part are grid cells: x runs along the LEFT front wall (foot_w), y along the right one
(foot_h); (0, 0) is the back corner. h is wall height in levels, rh roof height, roof "x" puts the ridge
along x (a long left wall, gable on the right), "y" along y, "pyr" a pyramid, None a flat top.
"""
import argparse
from functools import cmp_to_key
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "art" / "templates" / "buildings"
TW, TH, HS = 64.0, 32.0, 16.0
SIZE = 1024
STOREY = 4.5  # wall levels per storey: 72 screen px, 1.35 x the hero
DOOR = (0.7, 4.0)  # door width in cells, height in levels (64 px; the hero is 54 with his hair)
HERO_H = 3.4  # levels

BUILDINGS = {
    # The approved fall houses are one storey and a roof; a home stays that size.
    "home_b": {"foot": (4, 3), "parts": [
        {"box": (0, 0, 4, 3), "h": STOREY, "roof": "x", "rh": 4.5, "door": ("left", 1.0)},
        {"box": (2.9, 0.9, 3.4, 1.4), "h": STOREY + 6.5, "roof": None, "chimney": True}]},
    "home_c": {"foot": (4, 3), "parts": [
        {"box": (0, 0, 4, 3), "h": STOREY - 0.5, "roof": "x", "rh": 5.0, "door": ("left", 1.0)},
        {"box": (3.0, 0.6, 3.5, 1.1), "h": STOREY + 6.0, "roof": None, "chimney": True}]},
    # Brandon: the forge should jut out, a ^ shape. Two wings meet at the back corner: the house runs
    # to the right corner, the open forge wing comes forward at the lower left, a yard between them.
    "smithy": {"foot": (3, 4), "parts": [
        {"box": (0, 0, 3, 1.7), "h": STOREY, "roof": "x", "rh": 3.5, "door": ("left", 2.3)},
        {"box": (0, 1.7, 1.6, 4), "h": STOREY - 0.8, "roof": "y", "rh": 2.6, "open": ("right", 2.85)},
        {"box": (0.2, 3.2, 0.7, 3.7), "h": STOREY + 4.0, "roof": None, "chimney": True}]},
    # Brandon: sign hanging by the front door, one chimney.
    "tavern": {"foot": (4, 4), "parts": [
        {"box": (0, 0, 4, 4), "h": STOREY * 2, "roof": "x", "rh": 5.0, "door": ("left", 1.4), "sign": 2.15},
        {"box": (0.5, 1.75, 1.0, 2.25), "h": STOREY * 2 + 6.5, "roof": None, "chimney": True}]},
    # Brandon: read like a town hall (he pointed at World of Warcraft's): a big stout hall, steps up to
    # wide double doors in a gabled entrance that juts out, a big roof, and a square tower behind it
    # that tops everything in town.
    "townhall": {"foot": (5, 5), "parts": [
        {"box": (0.1, 0.1, 1.9, 1.9), "h": STOREY * 3, "roof": "pyr", "rh": 6.0},
        {"box": (0, 0.6, 5, 4.1), "h": STOREY * 1.8, "roof": "x", "rh": 7.0},
        {"box": (1.6, 4.1, 3.4, 5), "h": STOREY * 1.5, "roof": "y", "rh": 4.0, "door": ("left", 2.5), "wide": True}]},
}

C_LEFT, C_RIGHT, C_TOP = (206, 202, 190), (172, 168, 156), (190, 186, 174)
C_ROOF, C_ROOF_DARK = (140, 134, 126), (112, 107, 100)
C_LINE, C_DOOR, C_FIG = (70, 66, 62), (78, 70, 64), (120, 124, 132)


def iso(x, y, h):
    return ((x - y) * TW * 0.5, (x + y) * TH * 0.5 - h * HS)


def polys(part):
    """[(points, fill)] for one part, back to front."""
    x0, y0, x1, y1 = part["box"]
    h, rh = part["h"], part.get("rh", 0)
    out = []
    if part.get("steps"):
        for i, (d, top) in enumerate(((0.6, 0.5), (0.35, 1.0))):
            out.append(([(x0, y1 + d, 0), (x1, y1 + d, 0), (x1, y1 + d, top), (x0, y1 + d, top)], C_LEFT))
            out.append(([(x0, y1, top), (x1, y1, top), (x1, y1 + d, top), (x0, y1 + d, top)], C_TOP))
        return out
    out.append(([(x0, y1, 0), (x1, y1, 0), (x1, y1, h), (x0, y1, h)], C_LEFT))
    out.append(([(x1, y0, 0), (x1, y1, 0), (x1, y1, h), (x1, y0, h)], C_RIGHT))
    roof, e = part["roof"], 0.15
    if roof is None:
        out.append(([(x0, y0, h), (x1, y0, h), (x1, y1, h), (x0, y1, h)], C_TOP))
    elif roof == "x":
        ym, H = (y0 + y1) / 2, h + rh
        out.append(([(x0 - e, y0 - e, h), (x1 + e, y0 - e, h), (x1 + e, ym, H), (x0 - e, ym, H)], C_ROOF_DARK))
        out.append(([(x1, y1, h), (x1, y0, h), (x1, ym, H)], C_RIGHT))
        out.append(([(x0 - e, ym, H), (x1 + e, ym, H), (x1 + e, y1 + e, h), (x0 - e, y1 + e, h)], C_ROOF))
    elif roof == "y":
        xm, H = (x0 + x1) / 2, h + rh
        out.append(([(x0 - e, y0 - e, h), (x0 - e, y1 + e, h), (xm, y1 + e, H), (xm, y0 - e, H)], C_ROOF))
        out.append(([(xm, y0 - e, H), (xm, y1 + e, H), (x1 + e, y1 + e, h), (x1 + e, y0 - e, h)], C_ROOF_DARK))
        out.append(([(x0, y1, h), (x1, y1, h), (xm, y1, H)], C_LEFT))
    elif roof == "pyr":
        xm, ym, H = (x0 + x1) / 2, (y0 + y1) / 2, h + rh
        out.append(([(x0 - e, y1 + e, h), (x1 + e, y1 + e, h), (xm, ym, H)], C_ROOF))
        out.append(([(x1 + e, y0 - e, h), (x1 + e, y1 + e, h), (xm, ym, H)], C_ROOF_DARK))
    if "door" in part:
        side, c = part["door"]
        w = DOOR[0] * (1.6 if part.get("wide") else 1.0)
        dh = DOOR[1] * (1.3 if part.get("wide") else 1.0)
        if side == "left":
            out.append(([(c - w / 2, y1, 0), (c + w / 2, y1, 0), (c + w / 2, y1, dh), (c - w / 2, y1, dh)], C_DOOR))
        else:
            out.append(([(x1, c - w / 2, 0), (x1, c + w / 2, 0), (x1, c + w / 2, dh), (x1, c - w / 2, dh)], C_DOOR))
    if "open" in part:  # the forge bay: an open front on the right wall
        side, c = part["open"]
        w = (y1 - y0) * 0.7
        out.append(([(x1, c - w / 2, 0), (x1, c + w / 2, 0), (x1, c + w / 2, h * 0.75), (x1, c - w / 2, h * 0.75)], C_DOOR))
    if "sign" in part:  # a blank sign on an arm off the left wall, beside the door
        c = part["sign"]
        out.append(([(c, y1, 3.6), (c, y1 + 0.45, 3.6), (c, y1 + 0.45, 3.4), (c, y1, 3.4)], C_LINE))
        out.append(([(c, y1 + 0.15, 3.4), (c, y1 + 0.45, 3.4), (c, y1 + 0.45, 1.8), (c, y1 + 0.15, 1.8)], C_ROOF_DARK))
    return out


def behind(a, b):
    """Painter's order: a part wholly in front of another (past its far x or y edge) draws later; parts that
    overlap (a chimney or tower inside a roof) go by front corner, so the roof covers their foot."""
    ax0, ay0, ax1, ay1 = a["box"]
    bx0, by0, bx1, by1 = b["box"]
    if ay0 >= by1 or ax0 >= bx1:
        return 1
    if by0 >= ay1 or bx0 >= ax1:
        return -1
    return (ax1 + ay1) - (bx1 + by1)


def draw(name):
    spec = BUILDINGS[name]
    fw, fh = spec["foot"]
    parts = sorted(spec["parts"], key=cmp_to_key(behind))
    shapes = [(pts, col) for p in parts for pts, col in polys(p)]
    # The size figure: beside the door of the part that has one, so the door stays in view.
    door_part = next(p for p in spec["parts"] if "door" in p)
    fx = door_part["door"][1] + (1.25 if door_part.get("wide") else 0.95)
    fy = door_part["box"][3] + 0.3
    base = iso(fx, fy, 0)
    pts = [iso(*q) for s, _ in shapes for q in s] + [iso(0, 0, 0), iso(fw, fh, 0), (base[0], base[1] - HERO_H * HS)]
    lo_x, hi_x = min(p[0] for p in pts), max(p[0] for p in pts)
    lo_y, hi_y = min(p[1] for p in pts), max(p[1] for p in pts)
    k = SIZE * 0.8 / max(hi_x - lo_x, hi_y - lo_y)
    ox = SIZE / 2 - (lo_x + hi_x) / 2 * k
    oy = SIZE / 2 - (lo_y + hi_y) / 2 * k

    def px(q):
        sx, sy = iso(*q)
        return (ox + sx * k, oy + sy * k)

    img = Image.new("RGB", (SIZE, SIZE), (234, 232, 214))
    d = ImageDraw.Draw(img)
    for s, col in shapes:
        d.polygon([px(q) for q in s], fill=col, outline=C_LINE, width=3)
    # The size figure: a plain capsule, not a person, so the model has nothing to copy.
    bx, by = ox + base[0] * k, oy + base[1] * k
    r = 0.42 * TW * 0.5 * k
    top = by - HERO_H * HS * k
    d.rounded_rectangle([bx - r, top, bx + r, by], radius=r, fill=C_FIG, outline=C_LINE, width=2)
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / ("guide_%s.png" % name)
    img.save(path)
    print("%s: foot %dx%d, %s" % (name, fw, fh, path.relative_to(REPO)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name", nargs="?", choices=sorted(BUILDINGS))
    ap.add_argument("--all", action="store_true")
    args = ap.parse_args()
    for n in (sorted(BUILDINGS) if args.all or not args.name else [args.name]):
        draw(n)


if __name__ == "__main__":
    main()
