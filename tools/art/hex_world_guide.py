"""Grey block-out guide for the hex world map mockup (Brandon's 13-hex layout, 2026-11-01).

Each explorable map is one raised hex block on the 2:1 camera (flat-top hexes squashed to half height),
taller where the land is higher, with a thin dark gap between blocks so the hex structure survives the
painting. No words or numbers are drawn: the prompt names each hex by its place in the grid.
Run: ~/.lodestone/venv/bin/python tools/art/hex_world_guide.py [out.png]
"""
import math
import sys

from PIL import Image, ImageDraw

OUT = sys.argv[1] if len(sys.argv) > 1 else "art/templates/world/hex_world_guide.png"
W, H = 2400, 1600
CREAM = (234, 232, 214)
R = 210            # hex radius in the flat layout
SQ = 0.5           # 2:1 camera: depth squashed to half
LEVEL = 16         # px per height level (kept low so a block never hides the top behind it)
GAP = 18           # gap between neighbouring blocks, flat-layout px

# (column, row, height levels): flat-top grid, even columns sit half a row lower (Brandon's sketch).
HEXES = {
    "snowy_plains": (1, 0, 2), "frozen_dam": (0, 0, 2), "enchanted_woods_2": (2, 0, 2),
    "dwarven_mines": (1, 1, 3), "coastal_beach": (0, 1, 1), "skyrim_grass_snow": (2, 1, 2),
    "enchanted_woods": (3, 1, 2), "highlands_1": (1, 2, 3), "forest_roads": (0, 2, 2),
    "farmland": (2, 2, 1), "capital_city": (3, 2, 2), "home": (1, 3, 1),
}


def centre(col, row):
    x = col * 1.5 * R
    y = (row + (0.5 if col % 2 == 0 else 0)) * math.sqrt(3) * R
    return x, y


def corners(cx, cy, r):
    return [(cx + r * math.cos(math.radians(60 * i)), cy + r * math.sin(math.radians(60 * i))) for i in range(6)]


def main():
    pts = {k: centre(c, r) for k, (c, r, _) in HEXES.items()}
    xs = [p[0] for p in pts.values()]
    ys = [p[1] for p in pts.values()]
    ox = W / 2 - (min(xs) + max(xs)) / 2
    oy = H / 2 - (min(ys) + max(ys)) / 2 * SQ + 40
    img = Image.new("RGB", (W, H), CREAM)
    d = ImageDraw.Draw(img)
    # Back to front so nearer blocks cover the ones behind.
    for key in sorted(HEXES, key=lambda k: pts[k][1]):
        cx, cy = pts[key]
        h = HEXES[key][2] * LEVEL + 26
        ring = [(ox + x, oy + y * SQ) for x, y in corners(cx, cy, R - GAP / 2)]
        top = [(x, y - h) for x, y in ring]
        # Corners 0..5 run clockwise from the right; 0-1, 1-2, 2-3 face the viewer.
        faces = {(0, 1): (150, 150, 146), (1, 2): (170, 170, 165), (2, 3): (190, 190, 185)}
        for (a, b), col in faces.items():
            d.polygon([top[a], top[b], ring[b], ring[a]], fill=col, outline=(55, 51, 53))
        d.polygon(top, fill=(222, 222, 216), outline=(55, 51, 53), width=3)
    img.save(OUT)
    print(OUT, img.size)


if __name__ == "__main__":
    main()
