#!/usr/bin/env python3
"""One labelled reference board for the hex world map prompt: CONTENT, HEX STRUCTURE, STYLE on one picture.

    ~/.lodestone/venv/bin/python tools/art/world_board.py   # writes art/templates/world/world_board.png

1536 x 1024 (3:2), cream paper, built only from pictures we already have, nothing painted:
  CONTENT        Brandon's latest Picsart try (art/templates/world/hex_closest_try_2.png), big on the left
  HEX OVERLAY    one continuous island with the hex grid as thin lines (hex_overlay_guide.png, from hex_overlay_guide.py)
  STYLE          the approved look (docs/art/references/style-flat-forest.png)
The prompt (art/prompts/hand-world-hex-mockup-v3.txt) refers to the panels by these labels.
Brandon (2026-11-01): "append all references images into one image with labels. That way I just send 1 image and 1 prompt".
"""
from PIL import Image, ImageDraw, ImageFont

CREAM = (234, 232, 214)
INK = (55, 51, 53)
FONT = "/System/Library/Fonts/Helvetica.ttc"
W, H, M, LAB = 1536, 1024, 24, 52
OUT = "art/templates/world/world_board.png"
PANELS = [  # label, source, box (x, y, w, h) including the label strip
    ("CONTENT", "art/templates/world/hex_closest_try_2.png", (M, M, 980, H - 2 * M)),
    ("HEX OVERLAY", "art/templates/world/hex_overlay_guide.png", (980 + 2 * M, M, W - 980 - 3 * M, (H - 3 * M) // 2)),
    ("STYLE", "docs/art/references/style-flat-forest.png", (980 + 2 * M, M * 2 + (H - 3 * M) // 2, W - 980 - 3 * M, (H - 3 * M) // 2)),
]


def font(n):
    try:
        return ImageFont.truetype(FONT, n, index=1)
    except OSError:
        return ImageFont.load_default()


def main():
    board = Image.new("RGB", (W, H), CREAM)
    d = ImageDraw.Draw(board)
    f = font(34)
    for label, src, (x, y, w, h) in PANELS:
        d.rectangle([x, y, x + w, y + h], outline=INK, width=4)
        d.rectangle([x, y, x + w, y + LAB], fill=INK)
        d.text((x + 16, y + LAB // 2), label, fill=CREAM, font=f, anchor="lm")
        im = Image.open(src).convert("RGB")
        # crop the plain cream margin so the picture fills its panel
        bg = Image.new("RGB", im.size, im.getpixel((2, 2)))
        from PIL import ImageChops
        box = ImageChops.difference(im, bg).convert("L").point(lambda v: 255 if v > 18 else 0).getbbox()
        if box:
            im = im.crop((max(0, box[0] - 12), max(0, box[1] - 12), min(im.width, box[2] + 12), min(im.height, box[3] + 12)))
        iw, ih = w - 24, h - LAB - 24
        s = min(iw / im.width, ih / im.height)
        im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
        board.paste(im, (x + (w - im.width) // 2, y + LAB + 12 + (ih - im.height) // 2))
    board.save(OUT)
    print(OUT, board.size)


if __name__ == "__main__":
    main()
