#!/usr/bin/env python3
"""Silhouette check for a character concept grid: can each figure be told apart at game size?

    ~/.lodestone/venv/bin/python tools/art/silhouette_check.py art/picsart/out/concepts-lead_v1.png
    ~/.lodestone/venv/bin/python tools/art/silhouette_check.py grid.png --cols 4 --rows 2 --zoom 4

Cuts the grid into equal cells (4 x 2 for art/prompts/sheet-character-concepts.txt), keys the paper
out with char_art.key_background (the sprite exporter's flood fill), trims each figure to its ink and
shrinks it to --height px tall (48 px is the engine size, C14). The sheet has one column per figure,
numbered in reading order, and two rows, both feet on the same baseline:
  top:    the figure as a solid silhouette, what the shape alone says
  bottom: the figure in colour on the cream board, as it reads in play
--zoom enlarges the sheet with nearest-neighbour so it can be looked at; the sizes printed are true.

The script judges nothing. It prints each figure's size at --height and how much of its box is ink,
so a thin stick or a solid blob shows up early. Writes <grid>-silhouette.png beside the input unless
--out is given.
"""

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from char_art import key_background

PAPER = (234, 232, 214)  # #eae8d6, the cream board
INK = (55, 51, 53)  # #373335
MARGIN = 0.03  # share of each cell's edge trimmed, so a neighbour never leaks in
PAD = 4
LABEL_H = 12


def cells(img, cols, rows):
    w, h = img.size
    for r in range(rows):
        for c in range(cols):
            x0, y0 = c * w // cols, r * h // rows
            x1, y1 = (c + 1) * w // cols, (r + 1) * h // rows
            mx, my = int((x1 - x0) * MARGIN), int((y1 - y0) * MARGIN)
            yield img.crop((x0 + mx, y0 + my, x1 - mx, y1 - my))


def figure(cell):
    """The figure in one cell as an RGBA image trimmed to its ink, or None if the cell is empty."""
    cut = key_background(cell.convert("RGB"))
    box = cut.getchannel("A").getbbox()
    return cut.crop(box) if box else None


def shrink(fig, height):
    width = max(1, round(fig.width * height / fig.height))
    return fig.resize((width, height), Image.LANCZOS)


def compose(figs, height, zoom):
    col_w = max(fig.width for _, fig in figs) + 2 * PAD
    row_h = height + 2 * PAD
    canvas = Image.new("RGB", (len(figs) * col_w + PAD, LABEL_H + 2 * row_h), PAPER)
    draw = ImageDraw.Draw(canvas)
    for i, (n, fig) in enumerate(figs):
        x = i * col_w + PAD + (col_w - 2 * PAD - fig.width) // 2
        draw.text((i * col_w + PAD, 0), str(n), fill=INK)
        alpha = np.asarray(fig.getchannel("A")) > 127
        silhouette = Image.new("RGB", fig.size, INK)
        mask = Image.fromarray((alpha * 255).astype(np.uint8))
        canvas.paste(silhouette, (x, LABEL_H + PAD + height - fig.height), mask)
        canvas.paste(fig.convert("RGB"), (x, LABEL_H + row_h + PAD + height - fig.height), fig.getchannel("A"))
    return canvas.resize((canvas.width * zoom, canvas.height * zoom), Image.NEAREST)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("grid", type=Path, help="the concept grid picture")
    ap.add_argument("--cols", type=int, default=4)
    ap.add_argument("--rows", type=int, default=2)
    ap.add_argument("--height", type=int, default=48, help="figure height in px (48 = engine size)")
    ap.add_argument("--zoom", type=int, default=4, help="enlarge the sheet to look at it")
    ap.add_argument("--out", type=Path, help="default: <grid>-silhouette.png beside the input")
    args = ap.parse_args()

    img = Image.open(args.grid).convert("RGB")
    figs = []
    for n, cell in enumerate(cells(img, args.cols, args.rows), 1):
        fig = figure(cell)
        if fig is None:
            print("%d: no figure found in this cell" % n)
            continue
        small = shrink(fig, args.height)
        ink = (np.asarray(small.getchannel("A")) > 127).mean()
        print("%d: %d x %d px at %d tall, ink %.0f%% of its box" % (n, small.width, small.height, args.height, ink * 100))
        figs.append((n, small))
    if not figs:
        raise SystemExit("no figures found: check --cols and --rows")

    out = args.out or args.grid.with_name(args.grid.stem + "-silhouette.png")
    compose(figs, args.height, args.zoom).save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
