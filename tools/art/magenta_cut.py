#!/usr/bin/env python3
"""Cut a sheet of UI pieces painted on flat magenta (art/prompts/hand-dock-pieces.txt) into named PNGs.

    ~/.lodestone/venv/bin/python tools/art/magenta_cut.py SHEET.png --rows "a,b,c,d;e,f,g;..." --out DIR

Magenta is keyed out with its fringe unmixed (a pixel part piece, part magenta gets the magenta taken back
out), so pale parchment rims stay clean, and within a few px of the edge any magenta spill on dark ink is taken back out. Pieces are found as blobs of non-magenta, nearby blobs merged (a
leaf touching a crest), then grouped into rows top to bottom and named left to right from --rows. A piece
whose box touches the sheet edge is reported as possibly clipped. Writes to a staging folder; approved pieces
are copied into the game.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image

MAGENTA = np.array([255.0, 0.0, 255.0])
LO, HI = 60.0, 140.0  # distance from magenta: below LO fully keyed, above HI fully solid
MERGE = 10  # px: blobs closer than this are one piece
MIN_AREA = 150
EDGE = 4  # px from the keyed area where magenta spill is taken back out


def key(rgb: np.ndarray) -> np.ndarray:
    """RGBA with magenta keyed out and the fringe unmixed."""
    d = np.sqrt(((rgb - MAGENTA) ** 2).sum(-1))
    a = np.clip((d - LO) / (HI - LO), 0, 1)
    safe = np.maximum(a, 1e-3)[..., None]
    f = np.clip((rgb - (1 - a[..., None]) * MAGENTA) / safe, 0, 255)
    # Despill near the edge: dark ink mixed with magenta reads purple yet is opaque, so the unmix above
    # misses it. Within a few px of the keyed area, take back the part of red and blue that stands above green.
    clear = a < 0.5
    near = clear.copy()
    for _ in range(EDGE):
        near = near | np.roll(near, 1, 0) | np.roll(near, -1, 0) | np.roll(near, 1, 1) | np.roll(near, -1, 1)
    spill = np.clip(np.minimum(f[..., 0], f[..., 2]) - f[..., 1], 0, None) * (near & ~clear)
    f = f - np.dstack([spill, np.zeros_like(spill), spill])
    return np.dstack([np.where(a[..., None] > 0, f, 0), a * 255]).astype(np.uint8)


def blobs(mask: np.ndarray) -> list:
    """Bounding boxes (x0, y0, x1, y1, area) of the blobs, found on a half-size mask."""
    m = mask[::2, ::2]
    h, w = m.shape
    seen = np.zeros_like(m)
    out = []
    for y0, x0 in zip(*np.nonzero(m)):
        if seen[y0, x0]:
            continue
        stack, ys, xs = [(y0, x0)], [], []
        seen[y0, x0] = True
        while stack:
            y, x = stack.pop()
            ys.append(y)
            xs.append(x)
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < h and 0 <= nx < w and m[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        out.append([min(xs) * 2, min(ys) * 2, max(xs) * 2 + 2, max(ys) * 2 + 2, len(ys) * 4])
    return out


def merge(boxes: list) -> list:
    boxes = [b[:] for b in boxes]
    changed = True
    while changed:
        changed = False
        for i in range(len(boxes)):
            for j in range(i + 1, len(boxes)):
                a, b = boxes[i], boxes[j]
                if a[0] - MERGE <= b[2] and b[0] - MERGE <= a[2] and a[1] - MERGE <= b[3] and b[1] - MERGE <= a[3]:
                    boxes[i] = [min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3]), a[4] + b[4]]
                    del boxes[j]
                    changed = True
                    break
            if changed:
                break
    return [b for b in boxes if b[4] >= MIN_AREA]


def rows_of(boxes: list) -> list:
    """Group boxes into rows: a box joins a row when its middle falls inside the row's span."""
    rows = []
    for b in sorted(boxes, key=lambda b: (b[1] + b[3]) / 2):
        mid = (b[1] + b[3]) / 2
        for r in rows:
            if r["y0"] <= mid <= r["y1"]:
                r["boxes"].append(b)
                r["y0"], r["y1"] = min(r["y0"], b[1]), max(r["y1"], b[3])
                break
        else:
            rows.append({"y0": b[1], "y1": b[3], "boxes": [b]})
    return [sorted(r["boxes"], key=lambda b: b[0]) for r in rows]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet")
    ap.add_argument("--rows", required=True, help="names per row, comma-separated, rows split by ;")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    rgb = np.asarray(Image.open(args.sheet).convert("RGB"), float)
    rgba = key(rgb)
    H, W = rgba.shape[:2]
    rows = rows_of(merge(blobs(rgba[..., 3] > 127)))
    names = [r.split(",") for r in args.rows.split(";")]
    if [len(r) for r in rows] != [len(n) for n in names]:
        raise SystemExit("found rows of %s pieces, expected %s" % ([len(r) for r in rows], [len(n) for n in names]))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    for row, nrow in zip(rows, names):
        for (x0, y0, x1, y1, _), name in zip(row, nrow):
            pad = 3
            crop = Image.fromarray(rgba[max(0, y0 - pad):min(H, y1 + pad), max(0, x0 - pad):min(W, x1 + pad)], "RGBA")
            crop = crop.crop(crop.getchannel("A").getbbox())
            crop.save(out / (name + ".png"))
            edge = x0 <= 1 or y0 <= 1 or x1 >= W - 2 or y1 >= H - 2
            print("%-16s %4d x %-4d%s" % (name, crop.width, crop.height, "  CLIPPED? touches the sheet edge" if edge else ""))


if __name__ == "__main__":
    main()
