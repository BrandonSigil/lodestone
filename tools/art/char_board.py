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
    if len(sys.argv) > 1 and sys.argv[1] == "ne-flow":
        return main_ne_flow(sys.argv[2] if len(sys.argv) > 2 else "art/templates/characters/char_board_ne_flow.png")
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


def main_ne_flow(out):
    """The NE board for Brandon's chained Picsart flow (the SE sheet comes in on its own): LAYOUT, FACING NE, and
    ATTACK NE, the back-view pose with drawn arrows for the weapon's path, so the swing goes up and away, not toward the
    camera ([USER] 2026-11-01: "he's still attacking in the SE direction").
        ~/.lodestone/venv/bin/python tools/art/char_board.py ne-flow [out png]"""
    board = Image.new("RGB", (W, H), CREAM)
    d = ImageDraw.Draw(board)
    area_h = PH - LAB

    def frame(x, y, w, h, label):
        d.rectangle([x, y, x + w, y + h], outline=INK, width=3)
        d.text((x + 14, y + 4), label, fill=INK, font=font(34))
        return x, y + LAB, w, h - LAB

    x, y, w, h = frame(20, 20, PW, PH, "LAYOUT")
    im = fit(Image.open("art/templates/characters/sprite_grid.png").convert("RGB"), w - 20, h - 10)
    board.paste(im, (x + (w - im.width) // 2, y + (h - im.height) // 2))
    x, y, w, h = frame(20 + PW + 16, 20, PW, PH, "FACING NE")
    im = fit(Image.open("art/templates/characters/facing_ne.png").convert("RGB"), w - 20, h - 10)
    board.paste(im, (x + (w - im.width) // 2, y + (h - im.height) // 2))
    # ATTACK NE: the back-view pose with one straight arrow from the weapon arm toward the top right: the strike goes up
    # and away from the camera. A diagram, not art; the hero's own NE attack shows his face, so it can't serve.
    x, y, w, h = frame(20, 20 + PH + 20, W - 40, PH, "ATTACK NE: THE STRIKE GOES UP AND RIGHT, AWAY FROM US")
    pose = Image.open("art/templates/characters/facing_ne.png").convert("RGB")
    box = pose.getbbox()
    pose = pose.crop((max(0, box[0] - 30), max(0, box[1] - 30), min(pose.width, box[2] + 30), min(pose.height, box[3] + 30)))
    pose = fit(pose, w // 3, h - 50)
    px, py = x + w // 2 - pose.width // 2 - 140, y + (h - pose.height) // 2
    board.paste(pose, (px, py))
    import math
    sx, sy = px + pose.width * 0.78, py + pose.height * 0.42  # the right shoulder, seen from behind
    ex, ey = sx + 250, sy - 150  # toward the top right corner
    red = (196, 70, 40)
    d.line([(sx, sy), (ex, ey)], fill=red, width=12)
    ang = math.atan2(ey - sy, ex - sx)
    for s2 in (-0.45, 0.45):
        d.line([(ex, ey), (ex - 46 * math.cos(ang + s2), ey - 46 * math.sin(ang + s2))], fill=red, width=12)
    d.text((ex + 24, ey - 10), "STRIKE", fill=red, font=font(34))
    board.save(out)
    print(out)


if __name__ == "__main__":
    main()
