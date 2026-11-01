#!/usr/bin/env python3
"""One labelled reference board for the character prompt: LAYOUT, STYLE, FACING SE, SIZE on one picture.

    ~/.lodestone/venv/bin/python tools/art/char_board.py   # writes art/templates/characters/char_board.png

1536 x 1024 (3:2), cream paper. Four panels with big plain labels, built only from pictures we already have, nothing painted:
  LAYOUT     the magenta sprite grid template (art/templates/characters/sprite_grid.png)
  STYLE      the green-cloak style sheet (docs/art/characters/00-reference-sheet.png)
  FACING SE  the SE pose picture (art/templates/characters/facing_se.png)
  SIZE       the hero's SE idle next to the fire mage's, feet on one ground line
The prompt (art/prompts/hand-character-board.txt) refers to the panels by these labels.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

CREAM = (234, 232, 214)
INK = (55, 51, 53)
FONT = "/System/Library/Fonts/Helvetica.ttc"
W, H = 1536, 1024
PW, PH, LAB = 740, 478, 46  # panel width, panel height incl. label


def font(n):
    try:
        return ImageFont.truetype(FONT, n, index=1)
    except OSError:
        try:
            return ImageFont.truetype(FONT, n)
        except OSError:
            return ImageFont.load_default()


def fit(im, w, h):
    s = min(w / im.width, h / im.height)
    return im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)


def trim_alpha(im):
    box = im.getchannel("A").point(lambda v: 255 if v > 20 else 0).getbbox()
    return box


def main():
    import sys
    if len(sys.argv) > 2 and sys.argv[1] == "ne":
        return main_ne(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "art/templates/characters/char_board_ne.png")
    board = Image.new("RGB", (W, H), CREAM)
    d = ImageDraw.Draw(board)
    area_h = PH - LAB

    def panel(col, row, label):
        x, y = 20 + col * (PW + 16), 20 + row * (PH + 20)
        d.rectangle([x, y, x + PW, y + PH], outline=INK, width=3)
        d.text((x + 14, y + 4), label, fill=INK, font=font(34))
        return x, y + LAB

    # LAYOUT
    x, y = panel(0, 0, "LAYOUT")
    im = fit(Image.open("art/templates/characters/sprite_grid.png").convert("RGB"), PW - 20, area_h - 10)
    board.paste(im, (x + (PW - im.width) // 2, y + (area_h - im.height) // 2))
    # STYLE
    x, y = panel(1, 0, "STYLE")
    im = fit(Image.open("docs/art/characters/00-reference-sheet.png").convert("RGB"), PW - 20, area_h - 10)
    board.paste(im, (x + (PW - im.width) // 2, y + (area_h - im.height) // 2))
    # FACING SE
    x, y = panel(0, 1, "FACING SE")
    im = fit(Image.open("art/templates/characters/facing_se.png").convert("RGB"), PW - 20, area_h - 10)
    board.paste(im, (x + (PW - im.width) // 2, y + (area_h - im.height) // 2))
    # SIZE: two stands, same scale, same feet
    x, y = panel(1, 1, "SIZE")
    hero = Image.open("game/art/source/characters/lead/lead_stand_se.png").convert("RGBA")
    mage = Image.open("game/art/source/characters/fire_mage/fire_mage_stand_se.png").convert("RGBA")
    k = 2.0
    hh, mh = (trim_alpha(i) for i in (hero, mage))
    pct = round((mh[3] - mh[1]) / (hh[3] - hh[1]) * 100)  # measured on the frames the game draws, never a separate scale
    ground = y + area_h - 70
    for i, im in enumerate((hero, mage)):
        big = im.resize((round(im.width * k), round(im.height * k)), Image.LANCZOS)
        cx = x + PW // 4 + i * PW // 2
        board.paste(big, (cx - big.width // 2, ground - round(160 * k)), big)  # feet at frame y 160
    d.line([x + 30, ground, x + PW - 30, ground], fill=INK, width=2)
    d.text((x + PW // 4 - 40, ground + 10), "HERO", fill=INK, font=font(28))
    d.text((x + 3 * PW // 4 - 80, ground + 10), f"{pct} PER CENT", fill=INK, font=font(28))
    out = Path("art/templates/characters/char_board.png")
    board.save(out)
    print(out)


def main_ne(se_sheet, out):
    """The NE turn as one picture ([USER] 2026-11-01: one image and one prompt): LAYOUT, STYLE, FACING NE, and the
    character's own approved SE sheet as CHARACTER.
        ~/.lodestone/venv/bin/python tools/art/char_board.py ne <se sheet png> [out png]"""
    board = Image.new("RGB", (W, H), CREAM)
    d = ImageDraw.Draw(board)
    area_h = PH - LAB

    def panel(col, row, label, src):
        x, y = 20 + col * (PW + 16), 20 + row * (PH + 20)
        d.rectangle([x, y, x + PW, y + PH], outline=INK, width=3)
        d.text((x + 14, y + 4), label, fill=INK, font=font(34))
        im = fit(Image.open(src).convert("RGB"), PW - 20, area_h - 10)
        board.paste(im, (x + (PW - im.width) // 2, y + LAB + (area_h - im.height) // 2))

    panel(0, 0, "LAYOUT", "art/templates/characters/sprite_grid.png")
    panel(1, 0, "CHARACTER (FACING SE)", se_sheet)
    panel(0, 1, "FACING NE", "art/templates/characters/facing_ne.png")
    panel(1, 1, "STYLE", "docs/art/characters/00-reference-sheet.png")
    board.save(out)
    print(out)


if __name__ == "__main__":
    main()
