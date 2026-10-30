#!/usr/bin/env python3
"""Draw the grey block-out for a wall kit picture (image 1 of art/prompts/sheet-wall-kit.txt).

    python3 tools/art/wall_guide.py            # writes art/templates/walls/guide_walls.png

Top row: the four wall-kit pieces the board stands on a back-wall cell (CombatBoard._wall_piece), drawn
on the game's own projection exactly as the graybox draws them: plain, window, doorway, corner. Each is
a thin wall PIECE_THIN deep and PIECE_HIGH levels tall on the cell edge it shares with the room, facing
the lit side (+y, down-left on screen). The corner is an inside corner: no wall faces, only a post
CORNER_POST cells square and CORNER_HIGH levels tall at the cell's front corner, where the walls of the
cells beside it meet. Bottom row: three grey squares for the floor top, the worn floor top (both
straight down) and the floor edge (straight on).

SLOTS lists each piece's box in the picture (cell width W, bottom on the cell's front corner), the same
box the board fits the sprite into, so a painted picture is cut with these boxes (`--boxes` prints them).
"""

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "art" / "templates" / "walls" / "guide_walls.png"

SIZE = (2400, 1600)  # 3:2
W = 440  # one cell's width on the picture
LEVEL = W / 4  # TW 64 : HS 16
HIGH, THIN = 6.0, 0.14  # CombatBoard.PIECE_HIGH, PIECE_THIN
CORNER_POST, CORNER_HIGH = 0.22, 6.3  # the corner post's graybox
BOX_H = 1.9 * W  # each piece's box: W wide, this tall, bottom on the cell's front corner
HOLES = {"wall_window": (0.3, 2.6, 0.7, 4.2), "wall_door": (0.25, 0.0, 0.75, 4.0)}  # along 0..1, up in levels
PIECES = ["wall_plain", "wall_window", "wall_door", "wall_corner"]
TOP_Y = 90  # top of the piece boxes
FLOOR = [("top_stone", 0.22), ("top_stone_b", 0.50), ("side_masonry", 0.78)]  # centre x share of the picture
FLOOR_S, FLOOR_Y = 520, 1010

C_BG, C_LIT, C_SHADE, C_TOP, C_HOLE, C_FLOOR = (234, 232, 214), (150, 147, 140), (112, 109, 104), (182, 179, 171), (40, 37, 34), (160, 156, 148)
C_LINE = (70, 66, 62)


def iso(o, x, y, z):
    """Cell coords (x, y) and height z in levels -> picture point, o the cell's front corner (x=1, y=1)."""
    return (o[0] + (x - y) * W / 2, o[1] + (x + y - 2) * W / 4 - z * LEVEL)


def wall(d, o, lo, hi, hole=None, high=HIGH):
    """A box from lo to hi (cell coords), 0..high levels, its lit face (+y), shade face (+x) and top showing."""
    (x0, y0), (x1, y1) = lo, hi
    top = [iso(o, x0, y0, high), iso(o, x1, y0, high), iso(o, x1, y1, high), iso(o, x0, y1, high)]
    front_y = [iso(o, x0, y1, 0), iso(o, x1, y1, 0), iso(o, x1, y1, high), iso(o, x0, y1, high)]
    front_x = [iso(o, x1, y0, 0), iso(o, x1, y1, 0), iso(o, x1, y1, high), iso(o, x1, y0, high)]
    for poly, col in ((front_y, C_LIT), (front_x, C_SHADE), (top, C_TOP)):
        d.polygon(poly, fill=col, outline=C_LINE, width=3)
    if hole:
        a, z0, b, z1 = hole
        xa, xb = x0 + (x1 - x0) * a, x0 + (x1 - x0) * b
        d.polygon([iso(o, xa, y1, z0), iso(o, xb, y1, z0), iso(o, xb, y1, z1), iso(o, xa, y1, z1)], fill=C_HOLE)


def slots():
    """{name: (left, top, right, bottom)} for every piece and floor square in the picture."""
    out = {}
    gap = (SIZE[0] - len(PIECES) * W) / (len(PIECES) + 1)
    for i, name in enumerate(PIECES):
        left = gap + i * (W + gap)
        out[name] = (round(left), TOP_Y, round(left + W), round(TOP_Y + BOX_H))
    for name, share in FLOOR:
        cx = SIZE[0] * share
        out[name] = (round(cx - FLOOR_S / 2), FLOOR_Y, round(cx + FLOOR_S / 2), FLOOR_Y + FLOOR_S)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(OUT))
    ap.add_argument("--boxes", action="store_true", help="print the piece boxes as JSON and exit")
    args = ap.parse_args()
    boxes = slots()
    if args.boxes:
        print(json.dumps(boxes))
        return
    img = Image.new("RGB", SIZE, C_BG)
    d = ImageDraw.Draw(img)
    for name in PIECES:
        l, t, r, b = boxes[name]
        o = ((l + r) / 2, b)  # the cell's front corner
        if name == "wall_corner":
            wall(d, o, (1 - CORNER_POST, 1 - CORNER_POST), (1, 1), high=CORNER_HIGH)
        else:
            wall(d, o, (0, 1 - THIN), (1, 1), HOLES.get(name))
    for name, _ in FLOOR:
        d.rectangle(boxes[name], fill=C_FLOOR, outline=C_LINE, width=3)
    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    img.save(args.out)
    print(args.out)


if __name__ == "__main__":
    main()
