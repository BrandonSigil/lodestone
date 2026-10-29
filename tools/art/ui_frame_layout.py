#!/usr/bin/env python3
"""Graybox layout of the UI frame: where every band, socket and ornament sits, with no colour.

Follows the shape of Brandon's leaf frame (docs/art/references/ui-frame-leaf-reference.png): thin
double-ruled bands, leaf sprigs at the corners and beside the centre diamonds, small diamond stamps
and rods, a diamond clasp at the middle of each side. The bottom band is deeper and holds the UI:
bag socket left, the Lodestone diamond in the centre, four portrait sockets with two bar troughs right.

Attach it as the layout picture with art/prompts/ui-frame.txt so the model keeps the positions.
Plain greys only, the window is flat magenta, no text.

    ~/.lodestone/venv/bin/python tools/art/ui_frame_layout.py   # writes art/templates/ui/

Outputs ui-frame-layout.png (for the model) and ui-frame-layout-labeled.png (for people).
"""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art/templates/ui"
W, H = 1920, 1080

M = 22               # paper margin outside the frame
BAND = 56            # top and side band
BAND_Y = 892         # top of the bottom band, which runs to H - M
CORNER_R = 70        # the window's bottom corners curve in
BAG = (196, 922, 312, 1038)
PORTRAIT = 84
PORTRAIT_X = [1262, 1362, 1462, 1562]
PORTRAIT_Y = 912
TROUGH_H = 10
CENTRE = (960, 958)  # bottom diamond; it breaks the band's top edge
CENTRE_HALF = (84, 112)

INK = (55, 51, 53)
BANDC = (120, 120, 120)
RULE = (215, 215, 215)
LIGHT = (175, 175, 175)
SOCKET = (80, 80, 80)
LEAF = (160, 160, 160)
WINDOW = (255, 0, 255)
PAPER = (234, 232, 214)


def rect(d: ImageDraw.ImageDraw, box, fill, r: int = 0, width: int = 4) -> None:
    d.rounded_rectangle(box, radius=r, fill=fill, outline=INK, width=width)


def socket(d: ImageDraw.ImageDraw, box, r: int = 12) -> None:
    x0, y0, x1, y1 = box
    rect(d, (x0 - 6, y0 - 6, x1 + 6, y1 + 6), RULE, r + 4)
    rect(d, box, SOCKET, r)


def diamond(d: ImageDraw.ImageDraw, cx: float, cy: float, hw: float, hh: float, fill, width: int = 3) -> None:
    d.polygon([(cx, cy - hh), (cx + hw, cy), (cx, cy + hh), (cx - hw, cy)], fill=fill, outline=INK, width=width)


def leaf(d: ImageDraw.ImageDraw, x: float, y: float, length: float, angle: float) -> None:
    # an almond leaf whose stem end sits at (x, y), pointing along angle (degrees, 0 = right, 90 = down)
    a = math.radians(angle)
    ux, uy = math.cos(a), math.sin(a)
    px, py = -uy, ux
    pts = []
    for i in range(13):
        t = i / 12
        w = math.sin(math.pi * t) * length * 0.22
        pts.append((x + ux * length * t + px * w, y + uy * length * t + py * w))
    for i in range(11, 0, -1):
        t = i / 12
        w = math.sin(math.pi * t) * length * 0.22
        pts.append((x + ux * length * t - px * w, y + uy * length * t - py * w))
    d.polygon(pts, fill=LEAF, outline=INK, width=3)
    d.line((x, y, x + ux * length * 0.8, y + uy * length * 0.8), fill=INK, width=2)


def sprig(d: ImageDraw.ImageDraw, x: float, y: float, angle: float, n: int = 3, size: float = 50) -> None:
    # a stem from (x, y) along angle with leaves branching off alternate sides and one at the tip
    a = math.radians(angle)
    step = size * 0.7
    d.line((x, y, x + math.cos(a) * step * n, y + math.sin(a) * step * n), fill=INK, width=3)
    for i in range(n):
        bx, by = x + math.cos(a) * step * (i + 0.6), y + math.sin(a) * step * (i + 0.6)
        side = 1 if i % 2 == 0 else -1
        leaf(d, bx, by, size * (1.0 - i * 0.12), angle + side * 40)
    leaf(d, x + math.cos(a) * step * n, y + math.sin(a) * step * n, size * 0.8, angle)


def rod(d: ImageDraw.ImageDraw, x0: float, x1: float, y: float) -> None:
    # the band stamp: a thin rod with a small diamond at each end
    d.line((x0, y, x1, y), fill=RULE, width=6)
    diamond(d, x0, y, 9, 9, LIGHT, 2)
    diamond(d, x1, y, 9, 9, LIGHT, 2)


def vrod(d: ImageDraw.ImageDraw, x: float, y0: float, y1: float) -> None:
    d.line((x, y0, x, y1), fill=RULE, width=6)
    diamond(d, x, y0, 9, 9, LIGHT, 2)
    diamond(d, x, y1, 9, 9, LIGHT, 2)


def bands(d: ImageDraw.ImageDraw) -> None:
    # the frame is one band: the whole screen minus the window, whose bottom corners curve in
    rect(d, (M, M, W - M, H - M), BANDC, 0, 5)
    x0, y0, x1, y1 = M + BAND, M + BAND, W - M - BAND, BAND_Y
    d.rectangle((x0, y0, x1, y1), fill=WINDOW)
    for cx, sx in ((x0, 1), (x1, -1)):
        d.rectangle((min(cx, cx + sx * CORNER_R), y1 - CORNER_R, max(cx, cx + sx * CORNER_R), y1), fill=BANDC)
        ex = cx + sx * CORNER_R
        box = (ex - CORNER_R, y1 - 2 * CORNER_R, ex + CORNER_R, y1)
        d.pieslice(box, 0, 360, fill=WINDOW)
        d.arc(box, 90 if sx > 0 else 0, 180 if sx > 0 else 90, fill=INK, width=5)
    d.line((x0, y0, x1, y0), fill=INK, width=5)
    d.line((x0 + CORNER_R, y1, x1 - CORNER_R, y1), fill=INK, width=5)
    d.line((x0, y0, x0, y1 - CORNER_R), fill=INK, width=5)
    d.line((x1, y0, x1, y1 - CORNER_R), fill=INK, width=5)
    # the reference's double lines: a light rule just inside the outer edge and along the window
    d.rectangle((M + 10, M + 10, W - M - 10, H - M - 10), outline=RULE, width=4)
    d.line((x0 - 10, y0 - 10, x1 + 10, y0 - 10), fill=RULE, width=4)
    d.line((x0 + CORNER_R, y1 + 10, x1 - CORNER_R, y1 + 10), fill=RULE, width=4)
    d.line((x0 - 10, y0 - 10, x0 - 10, y1 - CORNER_R), fill=RULE, width=4)
    d.line((x1 + 10, y0 - 10, x1 + 10, y1 - CORNER_R), fill=RULE, width=4)


def ornaments(d: ImageDraw.ImageDraw) -> None:
    top = M + BAND // 2
    left, right = M + BAND // 2, W - M - BAND // 2
    # top: centre diamond with a sprig either side, small diamonds and rods running out to the corners
    sprig(d, W // 2 - 40, top + 4, 180, 2, 46)
    sprig(d, W // 2 + 40, top + 4, 0, 2, 46)
    diamond(d, W // 2, top, 40, 52, LIGHT, 4)
    diamond(d, W // 2, top, 20, 28, SOCKET, 3)
    for sx in (-1, 1):
        diamond(d, W // 2 + sx * 190, top, 12, 12, LIGHT)
        rod(d, min(W // 2 + sx * 250, W // 2 + sx * 720), max(W // 2 + sx * 250, W // 2 + sx * 720), top)
        diamond(d, W // 2 + sx * 800, top, 12, 12, LIGHT)
    # top corners: a small diamond block and a sprig running down the side
    for cx in (left, right):
        diamond(d, cx, top, 20, 20, LIGHT, 3)
        sprig(d, cx, top + 30, 90, 3, 44)
    # sides: diamond clasp at mid height, small diamonds and rods above and below
    cy = (M + BAND + BAND_Y) // 2
    for cx in (left, right):
        for sy in (-1, 1):
            vrod(d, cx, min(cy + sy * 110, cy + sy * 240), max(cy + sy * 110, cy + sy * 240))
        diamond(d, cx, cy, 40, 64, LIGHT, 4)
        diamond(d, cx, cy, 20, 34, SOCKET, 3)
    # bottom corners: leaf clusters filling the curve
    for cx, sx in ((left + 6, 1), (right - 6, -1)):
        sprig(d, cx, H - M - 40, -90 + sx * 30, 3, 52)
        sprig(d, cx + sx * 16, H - M - 30, 90 - sx * 105, 2, 46)


def bottom(d: ImageDraw.ImageDraw) -> None:
    mid = (BAND_Y + H - M) // 2
    socket(d, BAG, 18)
    diamond(d, BAG[2] + 50, mid, 14, 14, LIGHT)
    rod(d, BAG[2] + 90, 600, mid)
    for x in PORTRAIT_X:
        socket(d, (x, PORTRAIT_Y, x + PORTRAIT, PORTRAIT_Y + PORTRAIT))
        for i in range(2):
            y = PORTRAIT_Y + PORTRAIT + 12 + i * (TROUGH_H + 8)
            rect(d, (x, y, x + PORTRAIT, y + TROUGH_H), SOCKET, TROUGH_H // 2, 3)
    cx, cy = CENTRE
    hw, hh = CENTRE_HALF
    sprig(d, cx - hw + 10, cy + 10, 180, 3, 62)
    sprig(d, cx + hw - 10, cy + 10, 0, 3, 62)
    diamond(d, cx, cy, hw, hh, LIGHT, 5)
    diamond(d, cx, cy, hw - 16, hh - 22, RULE, 3)
    diamond(d, cx, cy, hw - 30, hh - 42, SOCKET, 4)


def draw() -> Image.Image:
    img = Image.new("RGB", (W, H), PAPER)
    d = ImageDraw.Draw(img)
    bands(d)
    ornaments(d)
    bottom(d)
    return img


def label(img: Image.Image) -> Image.Image:
    out = img.copy()
    d = ImageDraw.Draw(out)
    notes = [
        ((W // 2 - 120, 420), "window: cut out (magenta)"),
        ((BAG[0], BAG[1] - 50), "bag"),
        ((CENTRE[0] - 110, 790), "Lodestone (sprite)"),
        ((PORTRAIT_X[0], PORTRAIT_Y - 50), "portraits + HP / MP troughs"),
        ((110, (M + BAND + BAND_Y) // 2 - 12), "side clasp"),
    ]
    for xy, text in notes:
        d.text(xy, text, fill=INK, font_size=24)
    return out


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    img = draw()
    img.save(OUT / "ui-frame-layout.png")
    label(img).save(OUT / "ui-frame-layout-labeled.png")
    print("wrote", OUT / "ui-frame-layout.png")
