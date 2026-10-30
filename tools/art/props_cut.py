#!/usr/bin/env python3
"""Cut a props sheet (equal cells on cream paper) into game-ready prop sprites.

Each cell is keyed off the paper the way kit_cut.py does it (flood from the edges, tight tolerance so
white snow stays), then any paper left inside the prop (the hole of an arch) is cleared, the sprite is
trimmed to its outline and scaled to 256 px tall. Writes to a staging folder, never the game folder.

    python3 tools/art/props_cut.py SHEET.png --grid 5x3 --names a,b,c,... --out art/picsart/out/<batch>/cut
Names go left to right, top to bottom; "-" skips a cell. Needs Pillow and numpy.
Icons: add --icon 128 to fit each one, centred, in a 128 square instead (art/prompts/sheet-icons-asks.txt).
Buildings: add --width 512 to scale to that width instead; it also prints each building's left wall share
(as tools/art/village_cut.py does), to check against its footprint.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image

from char_art import key_background

PROP_H = 256
PAPER_TOL = 10  # how close to the paper colour a pixel inside a prop must be to be cleared


def _runs(on: np.ndarray, min_gap: int) -> list:
    """Spans of True along an axis, joining spans split by gaps shorter than min_gap."""
    spans, start = [], None
    for i, v in enumerate(on):
        if v and start is None:
            start = i
        elif not v and start is not None:
            spans.append([start, i])
            start = None
    if start is not None:
        spans.append([start, len(on)])
    merged = []
    for sp in spans:
        if merged and sp[0] - merged[-1][1] < min_gap:
            merged[-1][1] = sp[1]
        else:
            merged.append(sp)
    return merged


def _drop_edge_bits(a: np.ndarray, share: float = 0.15) -> None:
    """Clear small pieces touching the cell's edge (a neighbour's spark or tip poking in), in place."""
    on = a[..., 3] > 0
    h, w = on.shape
    seen = np.zeros_like(on)
    total = on.sum()
    for y0, x0 in zip(*np.nonzero(on)):
        if seen[y0, x0]:
            continue
        stack, comp, edge = [(y0, x0)], [], False
        seen[y0, x0] = True
        while stack:
            y, x = stack.pop()
            comp.append((y, x))
            edge |= y in (0, h - 1) or x in (0, w - 1)
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < h and 0 <= nx < w and on[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        if edge and len(comp) < share * total:
            ys, xs = zip(*comp)
            a[list(ys), list(xs), 3] = 0


def cut(sheet: str, cols: int, rows: int, names: list, out: Path, width: int = 0, scale: float = 0.0, icon: int = 0, even: bool = False) -> list:
    """Rows and props are found from the paper gaps between them, so uneven rows still cut cleanly."""
    img = Image.open(sheet).convert("RGB")
    rgb = np.asarray(img).astype(int)
    h, w = rgb.shape[:2]
    paper = np.median(np.concatenate([rgb[0], rgb[-1]]), axis=0)
    ink = np.abs(rgb - paper).max(-1) > 24
    row_spans = [r for r in _runs(ink.mean(1) > 0.002, h // 60) if r[1] - r[0] > h // 20]
    if even:  # equal cells, for sheets whose sparkles and rays bridge the paper gaps
        row_spans = [[h * r // rows, h * (r + 1) // rows] for r in range(rows)]
    if len(row_spans) != rows:
        raise SystemExit(f"found {len(row_spans)} rows, expected {rows}")
    out.mkdir(parents=True, exist_ok=True)
    written = []
    for r, (y0, y1) in enumerate(row_spans):
        col_spans = [c for c in _runs(ink[y0:y1].mean(0) > 0.002, w // 80) if c[1] - c[0] > w // 40]
        if even:
            col_spans = [[w * c // cols, w * (c + 1) // cols] for c in range(cols)]
        if len(col_spans) != cols:
            print(f"row {r + 1}: found {len(col_spans)} props, expected {cols}; named left to right")
        for c, (x0, x1) in enumerate(col_spans):
            i = r * cols + c
            if i >= len(names) or names[i] == "-":
                continue
            pad = 0 if even else 8
            box = (max(x0 - pad, 0), max(y0 - pad, 0), min(x1 + pad, w), min(y1 + pad, h))
            p = key_background(img.crop(box), tol=14)
            a = np.asarray(p).copy()
            a[np.abs(a[..., :3].astype(int) - paper).max(-1) <= PAPER_TOL, 3] = 0
            if even:
                _drop_edge_bits(a)
            p = Image.fromarray(a, "RGBA")
            p = p.crop(p.getchannel("A").getbbox())
            if icon:  # fit the longer side to 90% of the square, centred, so every icon sits the same way
                f = icon * 0.9 / max(p.width, p.height)
                p = p.resize((max(1, round(p.width * f)), max(1, round(p.height * f))), Image.LANCZOS)
                sq = Image.new("RGBA", (icon, icon))
                sq.paste(p, ((icon - p.width) // 2, (icon - p.height) // 2))
                p = sq
            elif scale:  # one factor for every prop, so figures from one sheet keep their sizes
                p = p.resize((max(1, round(p.width * scale)), max(1, round(p.height * scale))), Image.LANCZOS)
            elif width:
                # The front corner is the lowest solid pixel; walls run up-left and up-right from it.
                ys, xs = np.where(np.asarray(p.getchannel("A")) > 128)
                print("%s: left wall share %.2f" % (names[i], xs[ys >= ys.max() - 3].mean() / p.width))
                p = p.resize((width, max(1, round(p.height * width / p.width))), Image.LANCZOS)
            else:
                p = p.resize((max(1, round(p.width * PROP_H / p.height)), PROP_H), Image.LANCZOS)
            p.save(out / f"{names[i]}.png")
            written.append(names[i])
    return written


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet")
    ap.add_argument("--grid", default="5x3")
    ap.add_argument("--names", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--width", type=int, default=0, help="scale to this width (buildings) instead of 256 tall")
    ap.add_argument("--scale", type=float, default=0.0, help="scale every prop by this one factor (1 = as painted), instead of 256 tall")
    ap.add_argument("--icon", type=int, default=0, help="fit each one, centred, in a square this many px wide")
    ap.add_argument("--even", action="store_true", help="split the sheet into equal cells instead of finding the paper gaps")
    args = ap.parse_args()
    cols, rows = (int(x) for x in args.grid.split("x"))
    done = cut(args.sheet, cols, rows, args.names.split(","), Path(args.out), args.width, args.scale, args.icon, args.even)
    print("cut", len(done), "props to", args.out)


if __name__ == "__main__":
    main()
