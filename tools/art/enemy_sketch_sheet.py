#!/usr/bin/env python3
"""Draws the enemy sketch sheet: 8 slots, each a FRONT box (faces lower right) and a BACK box (faces upper right),
with a tile diamond, a token base and height lines for small, person and big foes. Brandon scribbles a foe per slot
(any pen, any app); the game mirrors the two views to get all four combat facings.
Usage: python3 tools/art/enemy_sketch_sheet.py [out.png]"""
import sys
from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 else "art/templates/enemies/enemy-sketch-sheet.png"
PAPER, INK, GUIDE, SOFT = (234, 232, 214), (55, 51, 53), (190, 182, 160), (214, 208, 186)
W, H = 3000, 2000
COLS, ROWS = 4, 2
im = Image.new("RGB", (W, H), PAPER)
d = ImageDraw.Draw(im)
try:
    font = ImageFont.truetype("DejaVuSans.ttf", 30)
    small = ImageFont.truetype("DejaVuSans.ttf", 22)
except OSError:
    font = small = ImageFont.load_default()

d.text((60, 40), "ENEMY SKETCHES: one foe per slot. Draw it facing you (top box) and walking away (bottom box). "
       "Rough is fine.", fill=INK, font=font)
cw, ch = (W - 120) / COLS, (H - 140) / ROWS
for r in range(ROWS):
    for c in range(COLS):
        x0, y0 = 60 + c * cw, 110 + r * ch
        d.rounded_rectangle([x0 + 10, y0 + 10, x0 + cw - 10, y0 + ch - 10], 24, outline=GUIDE, width=4)
        d.text((x0 + 34, y0 + 26), f"{r * COLS + c + 1}.  ____________", fill=INK, font=font)
        for k, label in enumerate(["FRONT: faces you (lower right)", "BACK: walks away (upper right)"]):
            by = y0 + 80 + k * (ch - 90) / 2
            bh = (ch - 110) / 2
            cx, ground = x0 + cw / 2, by + bh - 75
            d.text((x0 + 34, by + 4), label, fill=(120, 110, 100), font=small)
            # tile diamond and token base
            tw = 110
            d.polygon([(cx - tw, ground), (cx, ground - tw / 2), (cx + tw, ground), (cx, ground + tw / 2)],
                      outline=SOFT, width=3)
            d.ellipse([cx - 70, ground - 24, cx + 70, ground + 24], outline=GUIDE, width=4)
            # height lines: small (wolf), person, big (bear, ogre)
            for frac, name in [(0.35, "small"), (0.62, "person"), (0.82, "big")]:
                y = ground - frac * (bh - 70)
                for xx in range(int(x0 + 40), int(x0 + cw - 120), 22):
                    d.line([(xx, y), (xx + 10, y)], fill=SOFT, width=2)
                d.text((x0 + cw - 110, y - 14), name, fill=GUIDE, font=small)
            # facing arrow
            sy = 1 if k == 0 else -1
            tip = (cx + 150, ground + 34 * sy)
            d.line([(cx + 90, ground + 4 * sy), tip], fill=GUIDE, width=4)
            d.polygon([tip, (tip[0] - 24, tip[1] - 2 * sy), (tip[0] - 8, tip[1] - 22 * sy)], fill=GUIDE)
im.save(OUT)
print(OUT)
