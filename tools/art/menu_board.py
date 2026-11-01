#!/usr/bin/env python3
"""Reference board v2 for the round 2 menu mockups: the approved kit, the style, the characters and two LAYOUT panels.

    ~/.lodestone/venv/bin/python tools/art/menu_board.py   # writes art/templates/ui/menu_mockup_board_v2.png

2400 x 1580, cream paper, big plain labels, built only from pictures we already have, nothing painted:
  1 THE GAME      panel 1 of board v1 (art/templates/ui/menu_mockup_board.png): world and bottom frame
  2 MENU KIT      panel 2 of board v1: the approved green felt pieces
  3 CHARACTERS    panel 4 of board v1: the party, to use as small portraits
  4 STYLE         panel 3 of board v1: the painting style
  5 LAYOUT HOME   round 1 draft 2 (art/picsart/out/menu-mockups/02_home_cards.png): arrangement to keep
  6 LAYOUT WIN    round 1 draft 3 (art/picsart/out/menu-mockups/03_win.png): arrangement to keep
The round 2 prompts (art/prompts/menu-mockups-r2.txt) refer to the panels by these labels.
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
V1 = ROOT / "art/templates/ui/menu_mockup_board.png"
DRAFTS = ROOT / "art/picsart/out/menu-mockups"
OUT = ROOT / "art/templates/ui/menu_mockup_board_v2.png"

CREAM = (234, 232, 214)
INK = (55, 51, 53)
FONT = "/System/Library/Fonts/Helvetica.ttc"
W, H = 2400, 1580
LAB = 46
GAP = 20

# crops of board v1 (2400 x 1600), in its pixels
CROP_GAME = (40, 130, 1400, 979)
CROP_KIT = (1440, 180, 2358, 786)
CROP_STYLE = (1698, 1062, 2100, 1467)
CROP_CHARS = (180, 1242, 1260, 1428)


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


def main():
    v1 = Image.open(V1).convert("RGB")
    board = Image.new("RGB", (W, H), CREAM)
    d = ImageDraw.Draw(board)

    def panel(x, y, w, h, label, im):
        d.rectangle([x, y, x + w, y + h], outline=INK, width=3)
        d.text((x + 14, y + 4), label, fill=INK, font=font(32))
        pic = fit(im, w - 20, h - LAB - 10)
        board.paste(pic, (x + (w - pic.width) // 2, y + LAB + (h - LAB - pic.height) // 2))

    # row A: the game (left), kit over characters (right)
    game = v1.crop(CROP_GAME)
    gw, gh = game.size
    panel(GAP, GAP, gw + 20, gh + LAB + 10, "1  THE GAME (world + bottom frame)", game)
    rx = GAP + gw + 20 + GAP
    rw = W - GAP - rx
    ah = gh + LAB + 10
    kit_h = int(ah * 0.66)
    panel(rx, GAP, rw, kit_h, "2  MENU KIT (approved pieces)", v1.crop(CROP_KIT))
    panel(rx, GAP + kit_h + GAP, rw, ah - kit_h - GAP, "3  CHARACTERS (for portraits)", v1.crop(CROP_CHARS))

    # row B: style, then the two layouts
    by = GAP + ah + GAP
    bh = H - by - GAP
    sw = 440
    panel(GAP, by, sw, bh, "4  STYLE", v1.crop(CROP_STYLE))
    lw = (W - GAP * 4 - sw) // 2
    home = Image.open(DRAFTS / "02_home_cards.png").convert("RGB")
    win = Image.open(DRAFTS / "03_win.png").convert("RGB")
    panel(GAP + sw + GAP, by, lw, bh, "5  LAYOUT: HOME AGAIN (keep this arrangement)", home)
    panel(GAP + sw + GAP + lw + GAP, by, lw, bh, "6  LAYOUT: WIN (keep this arrangement)", win)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    board.save(OUT, optimize=True)
    print(OUT, board.size)


if __name__ == "__main__":
    main()
