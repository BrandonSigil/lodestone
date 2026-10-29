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
along x (a long left wall, gable on the right), "y" along y, "pyr" a pyramid, "shed" a lean-to
sloping down to the front, None a flat top; "curve": True bows a gabled roof's slopes. "windows" lists ("left" | "right", place along that wall).
"""
import argparse
import math
from functools import cmp_to_key
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "art" / "templates" / "buildings"
TW, TH, HS = 64.0, 32.0, 16.0
SIZE = 1024
STOREY = 5.5  # wall levels per storey: 88 screen px, 1.6 x the hero
DOOR = (0.85, 4.6)  # door width in cells, height in levels (74 px; the hero is 54 with his hair)
HERO_H = 3.4  # levels

BUILDINGS = {
    # Brandon 2026-10-29: every building in the village is single storey (a bigger building gets a bigger
    # footprint), homes are less generic and have windows on their east (right) walls, and the village
    # should look less like a stock fantasy village.
    # Home B: the house with a low lean-to woodshed on the front right end.
    "home_b": {"foot": (4, 3), "parts": [
        {"box": (0, 0, 4, 2.3), "h": STOREY, "roof": "x", "rh": 4.5, "door": ("left", 1.2),
         "windows": [("right", 1.15)]},
        {"box": (2.4, 2.3, 4, 3), "h": 3.4, "roof": "shed", "rh": 1.8, "windows": [("right", 2.65)]},
        {"box": (0.5, 0.9, 1.0, 1.4), "h": STOREY + 6.0, "roof": None, "chimney": True}]},
    # Home C: the thatched cottage with a big stone chimney stack on its east gable.
    "home_c": {"foot": (4, 3), "parts": [
        {"box": (0, 0, 3.55, 3), "h": STOREY - 0.5, "roof": "x", "rh": 5.0, "door": ("left", 1.0),
         "windows": [("left", 2.6), ("right", 0.55), ("right", 2.45)]},
        {"box": (3.55, 1.1, 4.0, 1.9), "h": STOREY + 6.5, "roof": None, "chimney": True}]},
    # Brandon: the forge should jut out, a ^ shape. Two wings meet at the back corner: the house runs
    # to the right corner, the open forge wing comes forward at the lower left, a yard between them.
    # Approved 2026-10-29; kept at the sizes it was painted from.
    "smithy": {"foot": (3, 4), "parts": [
        {"box": (0, 0, 3, 1.7), "h": 4.5, "roof": "x", "rh": 3.5, "door": ("left", 2.3)},
        {"box": (0, 1.7, 1.6, 4), "h": 3.7, "roof": "y", "rh": 2.6, "open": ("right", 2.85)},
        {"box": (0.2, 3.2, 0.7, 3.7), "h": 8.5, "roof": None, "chimney": True}]},
    # Tavern: one long low common room under a big roof, one chimney, the sign by the door. Brandon on the
    # rooted review: roofs a bit more curved and less steep (tavern and town hall).
    "tavern": {"foot": (6, 4), "parts": [
        {"box": (0, 0, 6, 4), "h": STOREY, "roof": "x", "rh": 4.2, "curve": True, "door": ("left", 2.2), "sign": 3.05,
         "windows": [("left", 0.9), ("left", 4.3), ("left", 5.3), ("right", 1.2), ("right", 2.8)]},
        {"box": (4.4, 1.7, 4.9, 2.2), "h": STOREY + 7.0, "roof": None, "chimney": True}]},
    # Town hall: the biggest single-storey hall in town, a tall gabled entrance that juts out with wide
    # double doors, and a lantern on the ridge instead of a church-like bell tower.
    "townhall": {"foot": (7, 5), "parts": [
        {"box": (3.1, 1.65, 3.9, 2.45), "h": STOREY * 1.25 + 6.5, "roof": "pyr", "rh": 3.0},
        {"box": (0, 0, 7, 4.1), "h": STOREY * 1.25, "roof": "x", "rh": 4.8, "curve": True,
         "windows": [("left", 1.1), ("left", 5.9), ("right", 1.0), ("right", 3.0)]},
        {"box": (2.6, 4.1, 4.4, 5), "h": STOREY * 1.1, "roof": "y", "rh": 2.8, "curve": True, "door": ("left", 3.5), "wide": True}]},
}

C_LEFT, C_RIGHT, C_TOP = (206, 202, 190), (172, 168, 156), (190, 186, 174)
C_ROOF, C_ROOF_DARK = (140, 134, 126), (112, 107, 100)
C_LINE, C_DOOR, C_FIG = (70, 66, 62), (78, 70, 64), (120, 124, 132)
C_WINDOW = (112, 106, 100)


def iso(x, y, h):
    return ((x - y) * TW * 0.5, (x + y) * TH * 0.5 - h * HS)


def profile(eave, ridge, h, rh, curve):
    """Points (across, height) of one roof slope from its eave up to the ridge: straight, or bowed
    (a gentle bow: a little steeper at the eave, flatter at the ridge) when curve is set."""
    if not curve:
        return [(eave, h), (ridge, h + rh)]
    steps = 8
    return [(eave + (ridge - eave) * i / steps, h + rh * (0.45 * i / steps + 0.55 * math.sin(math.pi / 2 * i / steps))) for i in range(steps + 1)]


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
    roof, e = part["roof"], 0.15
    out.append(([(x0, y1, 0), (x1, y1, 0), (x1, y1, h), (x0, y1, h)], C_LEFT))
    if roof == "shed":  # a lean-to: high at the back (y0), low at the front
        out.append(([(x1, y0, 0), (x1, y1, 0), (x1, y1, h), (x1, y0, h + rh)], C_RIGHT))
        out.append(([(x0 - e, y0, h + rh), (x1 + e, y0, h + rh), (x1 + e, y1 + e, h), (x0 - e, y1 + e, h)], C_ROOF))
    else:
        out.append(([(x1, y0, 0), (x1, y1, 0), (x1, y1, h), (x1, y0, h)], C_RIGHT))
    if roof is None:
        out.append(([(x0, y0, h), (x1, y0, h), (x1, y1, h), (x0, y1, h)], C_TOP))
    elif roof == "x":
        ym = (y0 + y1) / 2
        back = profile(y0 - e, ym, h, rh, part.get("curve"))  # [(y, z)] from the back eave up to the ridge
        front = profile(y1 + e, ym, h, rh, part.get("curve"))
        out.append(([(x0 - e, y, z) for y, z in back] + [(x1 + e, y, z) for y, z in reversed(back)], C_ROOF_DARK))
        gable = profile(y1, ym, h, rh, part.get("curve")) + list(reversed(profile(y0, ym, h, rh, part.get("curve"))))[1:]
        out.append(([(x1, y, z) for y, z in gable], C_RIGHT))
        out.append(([(x0 - e, y, z) for y, z in front] + [(x1 + e, y, z) for y, z in reversed(front)], C_ROOF))
    elif roof == "y":
        xm = (x0 + x1) / 2
        back = profile(x0 - e, xm, h, rh, part.get("curve"))
        front = profile(x1 + e, xm, h, rh, part.get("curve"))
        out.append(([(x, y0 - e, z) for x, z in back] + [(x, y1 + e, z) for x, z in reversed(back)], C_ROOF))
        out.append(([(x, y0 - e, z) for x, z in front] + [(x, y1 + e, z) for x, z in reversed(front)], C_ROOF_DARK))
        gable = profile(x0, xm, h, rh, part.get("curve")) + list(reversed(profile(x1, xm, h, rh, part.get("curve"))))[1:]
        out.append(([(x, y1, z) for x, z in gable], C_LEFT))
    elif roof == "pyr":
        xm, ym, H = (x0 + x1) / 2, (y0 + y1) / 2, h + rh
        out.append(([(x0 - e, y1 + e, h), (x1 + e, y1 + e, h), (xm, ym, H)], C_ROOF))
        out.append(([(x1 + e, y0 - e, h), (x1 + e, y1 + e, h), (xm, ym, H)], C_ROOF_DARK))
    for side, c in part.get("windows", []):  # small windows, sill 1.6 levels up
        w, s0, s1 = 0.42, 1.6, 3.4
        if side == "left":
            out.append(([(c - w / 2, y1, s0), (c + w / 2, y1, s0), (c + w / 2, y1, s1), (c - w / 2, y1, s1)], C_WINDOW))
        else:
            out.append(([(x1, c - w / 2, s0), (x1, c + w / 2, s0), (x1, c + w / 2, s1), (x1, c - w / 2, s1)], C_WINDOW))
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
