#!/usr/bin/env python3
"""Sprite grid template and facing pictures for the character prompt workflow.

    ~/.lodestone/venv/bin/python tools/art/sprite_grid.py

Writes art/templates/characters/sprite_grid.png (1536 x 1024, flat magenta, five labelled rows of empty 192 px
cells with a faint ground diamond at the feet anchor (96, 160), a frame number in each used cell and a cross through
the unused ones: IDLE 4 + BLINK 1, WALK 6, ATTACK 6, CAST 6, HURT 2 + DOWN 2) and facing_<dir>.png for the five drawn
facings, cropped from docs/art/characters/02-directions.png. Boxes, lines and numbers only; no art is painted.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

CELL = 192
MAG = (255, 0, 255)
LINE = (255, 255, 255)
ROWS = [("IDLE", 4, "BLINK", 1), ("WALK", 6, "", 0), ("ATTACK", 6, "", 0), ("CAST", 6, "", 0), ("HURT", 2, "DOWN", 2)]
FONT = "/System/Library/Fonts/Helvetica.ttc"


def font(n):
    try:
        return ImageFont.truetype(FONT, n)
    except OSError:
        return ImageFont.load_default()


def grid(out):
    W, H = 1536, 1024
    im = Image.new("RGB", (W, H), MAG)
    d = ImageDraw.Draw(im)
    x0, y0 = 320, 32  # cells start here; labels sit to the left
    for r, (a, na, b, nb) in enumerate(ROWS):
        y = y0 + r * CELL
        label = f"{a} {na}" + (f" + {b} {nb}" if b else "")
        d.text((24, y + CELL // 2 - 20), a + (f" {na}" if not b else f" {na}"), fill=LINE, font=font(30))
        if b:
            d.text((24, y + CELL // 2 + 18), f"+ {b} {nb}", fill=LINE, font=font(30))
        used = na + nb
        for c in range(6):
            x = x0 + c * CELL
            box = [x + 4, y + 4, x + CELL - 4, y + CELL - 4]
            d.rectangle(box, outline=LINE, width=3)
            if c < used:
                fx, fy = x + 96, y + 160  # foot anchor
                dia = [(fx, fy - 32), (fx + 64, fy), (fx, fy + 32), (fx - 64, fy)]
                d.polygon(dia, outline=(255, 190, 255), width=2)
                d.text((x + 14, y + 10), str(c + 1), fill=LINE, font=font(24))
            else:
                d.line([box[0], box[1], box[2], box[3]], fill=LINE, width=3)
                d.line([box[0], box[3], box[2], box[1]], fill=LINE, width=3)
    im.save(out)
    return out


def facings(dest):
    src = Image.open("docs/art/characters/02-directions.png").convert("RGB")
    centres = {"n": (660, 240), "ne": (1095, 240), "e": (1095, 640), "se": (1095, 1040), "s": (660, 1040)}
    outs = []
    for k, (cx, cy) in centres.items():
        crop = src.crop((cx - 130, cy - 130, cx + 130, cy + 130)).resize((520, 520), Image.LANCZOS)
        p = dest / f"facing_{k}.png"
        crop.save(p)
        outs.append(p)
    return outs


def main():
    dest = Path("art/templates/characters")
    print(grid(dest / "sprite_grid.png"))
    for p in facings(dest):
        print(p)


if __name__ == "__main__":
    main()
