"""Flat, top-down grey guide for the hex world map as an inked scroll map (Brandon, 2026-11-01: "a flat handdrawn
map of these regions in hexagons. It should look like an old scroll that a cartopgrapher inked").

The same twelve tiles and layout as hex_world_guide.py, seen straight from above: thin hex grid lines only, no height,
no cliffs, on cream paper. No words or numbers.
Run: ~/.lodestone/venv/bin/python tools/art/hex_flat_guide.py [out.png]
"""
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, "tools/art")
import hex_world_guide as g  # noqa: E402

OUT = sys.argv[1] if len(sys.argv) > 1 else "art/templates/world/hex_flat_guide.png"
W, H, R = 2400, 1600, 190


def main():
    pts = {k: g.centre(c, r) for k, (c, r, _) in g.HEXES.items()}
    scale = R / g.R
    pts = {k: (x * scale, y * scale) for k, (x, y) in pts.items()}
    xs = [p[0] for p in pts.values()]
    ys = [p[1] for p in pts.values()]
    ox = W / 2 - (min(xs) + max(xs)) / 2
    oy = H / 2 - (min(ys) + max(ys)) / 2 + 60  # a little low, leaving room for the wall and the fog at the top
    img = Image.new("RGB", (W, H), g.CREAM)
    d = ImageDraw.Draw(img)
    for key, (cx, cy) in pts.items():
        ring = [(ox + x, oy + y) for x, y in g.corners(cx, cy, R)]
        d.polygon(ring, fill=(222, 222, 216))
        d.line(ring + [ring[0]], fill=(90, 84, 86), width=5)
    img.save(OUT)
    print(OUT, img.size)


if __name__ == "__main__":
    main()
