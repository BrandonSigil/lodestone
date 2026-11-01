"""Grey block-out for the hex world map, overlay version (Brandon, 2026-11-01: "the map isnt strictly hexagon
shaped little islands, but we're putting that shape over each section").

One continuous island in the shape of the twelve tiles (softened at the coast), one raised slab with cliffs only
at the outer coast, and the hex grid drawn on top as thin lines. Same layout and camera as hex_world_guide.py.
Run: ~/.lodestone/venv/bin/python tools/art/hex_overlay_guide.py [out.png]
"""
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter

sys.path.insert(0, "tools/art")
import hex_world_guide as g  # noqa: E402

OUT = sys.argv[1] if len(sys.argv) > 1 else "art/templates/world/hex_overlay_guide.png"
SLAB = 60  # px of cliff at the coast


def main():
    pts = {k: g.centre(c, r) for k, (c, r, _) in g.HEXES.items()}
    xs = [p[0] for p in pts.values()]
    ys = [p[1] for p in pts.values()]
    ox = g.W / 2 - (min(xs) + max(xs)) / 2
    oy = g.H / 2 - (min(ys) + max(ys)) / 2 * g.SQ + 40
    rings = {k: [(ox + x, oy + y * g.SQ) for x, y in g.corners(cx, cy, g.R)] for k, (cx, cy) in pts.items()}
    # island mask: the union of the hexes, softened so the coast is natural, not a hard hex edge
    mask = Image.new("L", (g.W, g.H), 0)
    md = ImageDraw.Draw(mask)
    for ring in rings.values():
        md.polygon(ring, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(26)).point(lambda v: 255 if v > 110 else 0)
    img = Image.new("RGB", (g.W, g.H), g.CREAM)
    cliff = Image.new("RGB", (g.W, g.H), (160, 160, 155))
    top = Image.new("RGB", (g.W, g.H), (222, 222, 216))
    img.paste(cliff, (0, 0), mask.transform(mask.size, Image.AFFINE, (1, 0, 0, 0, 1, -SLAB)))
    for dy in range(SLAB, 0, -4):  # fill the cliff band between the shifted and the top mask
        img.paste(cliff, (0, 0), mask.transform(mask.size, Image.AFFINE, (1, 0, 0, 0, 1, -dy)))
    img.paste(top, (0, 0), mask)
    edge = mask.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.MaxFilter(5))
    img.paste((55, 51, 53), (0, 0), edge)
    lines = Image.new("L", (g.W, g.H), 0)  # the overlay: thin grid lines, clipped to the land
    ld = ImageDraw.Draw(lines)
    for ring in rings.values():
        ld.line(ring + [ring[0]], fill=255, width=5)
    inner = mask.filter(ImageFilter.MinFilter(9))
    img.paste((90, 84, 86), (0, 0), ImageChops.darker(lines, inner))
    img.save(OUT)
    print(OUT, img.size)


if __name__ == "__main__":
    main()
