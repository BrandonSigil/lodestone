#!/usr/bin/env python3
"""Cut a tile kit picture (art/prompts/sheet-tile-kit.txt layout) into a battle tile set.

Usage:
  python3 tools/art/kit_cut.py KIT.png --set forest [--out game/art/source/battle] [--preview out.png]

The kit is three rows of five square tiles (tops, tops, sides) on cream paper, then two rows of
props. The rows and cells are found from the cream gaps, so the picture's exact size doesn't
matter. Each slot becomes the file name the engine already reads (battle_art.csv), written to
game/art/source/battle/<set>/; files the engine doesn't use yet are written too, for later.
Tiles are trimmed inside their rounded corners and outline and resized to 512; props are keyed
off the paper and scaled to 256 tall, like the base art.
"""

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

from char_art import key_background

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "game" / "art" / "source" / "battle"

# Slot names, row by row (docs: art/prompts/terrain-sheets.md).
TILE_ROWS = [
    ["top_grass", "top_grass_b", "top_road", "top_stone", "top_rock"],
    ["top_water", "top_hazard", "top_stone_b", "top_forest", "top_special"],
    ["side_cliff", "side_masonry", "side_water", "side_cliff_b", "side_hazard"],
]
PROP_ROWS = [
    ["prop_bush", "prop_boulder", "prop_crate", "prop_brazier", "prop_detail"],
    ["prop_pine_2", "prop_pine_1", "prop_pillar", "prop_landmark", "prop_ruin"],
]
TILE_PX = 512
PROP_H = 256
INSET = 0.07  # trim this share off each tile edge (rounded corners, outline, paper grain at the rim)


def ink_mask(a, tol=28):
    """True where the picture isn't paper: far from the median colour of the border."""
    edge = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])
    bg = np.median(edge, axis=0)
    return np.abs(a.astype(np.int16) - bg).max(-1) > tol


def runs(profile, min_len, min_gap):
    """[start, end) spans where profile is True, merging gaps shorter than min_gap."""
    spans, start = [], None
    for i, v in enumerate(list(profile) + [False]):
        if v and start is None:
            start = i
        elif not v and start is not None:
            spans.append([start, i])
            start = None
    merged = []
    for s in spans:
        if merged and s[0] - merged[-1][1] < min_gap:
            merged[-1][1] = s[1]
        else:
            merged.append(s)
    return [s for s in merged if s[1] - s[0] >= min_len]


def cut(kit_path, set_name, out_root=OUT, preview=None):
    img = Image.open(kit_path).convert("RGB")
    a = np.asarray(img)
    h, w = a.shape[:2]
    mask = ink_mask(a)
    rows = runs(mask.mean(1) > 0.02, min_len=h // 40, min_gap=h // 100)
    if len(rows) < 5:
        raise SystemExit("found %d rows, expected 3 tile rows and 2 prop rows" % len(rows))
    out = Path(out_root) / set_name
    out.mkdir(parents=True, exist_ok=True)
    written = []

    for r, names in enumerate(TILE_ROWS):
        y0, y1 = rows[r]
        cols = runs(mask[y0:y1].mean(0) > 0.5, min_len=w // 20, min_gap=w // 200)
        if len(cols) != 5:
            raise SystemExit("tile row %d: found %d cells, expected 5" % (r + 1, len(cols)))
        for (x0, x1), name in zip(cols, names):
            dx, dy = int((x1 - x0) * INSET), int((y1 - y0) * INSET)
            tile = img.crop((x0 + dx, y0 + dy, x1 - dx, y1 - dy)).resize((TILE_PX, TILE_PX), Image.LANCZOS)
            tile.save(out / (name + ".png"))
            written.append((name, tile))

    for r, names in enumerate(PROP_ROWS):
        y0, y1 = rows[3 + r]
        cols = runs(mask[y0:y1].mean(0) > 0.01, min_len=w // 60, min_gap=w // 60)
        if len(cols) != 5:  # a missing or merged prop: name what is there left to right, say so
            print("prop row %d: found %d props, expected 5; named left to right" % (r + 1, len(cols)))
        for (x0, x1), name in zip(cols, names):
            sub = mask[y0:y1, x0:x1]
            ys = np.where(sub.any(1))[0]
            pad = 6
            box = (max(x0 - pad, 0), max(y0 + ys[0] - pad, 0), min(x1 + pad, w), min(y0 + ys[-1] + 1 + pad, h))
            prop = key_background(img.crop(box))
            bb = prop.getchannel("A").getbbox()
            prop = prop.crop(bb)
            prop = prop.resize((max(1, round(prop.width * PROP_H / prop.height)), PROP_H), Image.LANCZOS)
            prop.save(out / (name + ".png"))
            written.append((name, prop))

    if preview:
        cell = 200
        sheet = Image.new("RGB", (cell * 5, cell * 5 + 20 * 5), (234, 232, 214))
        for i, (name, im) in enumerate(written):
            t = im.copy()
            t.thumbnail((cell - 10, cell - 10))
            x, y = (i % 5) * cell, (i // 5) * (cell + 20)
            sheet.paste(t, (x + 5, y + 5), t if t.mode == "RGBA" else None)
        sheet.save(preview)
    return [n for n, _ in written]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("kit")
    ap.add_argument("--set", required=True, help="tile set folder name, e.g. forest")
    ap.add_argument("--out", default=str(OUT))
    ap.add_argument("--preview")
    args = ap.parse_args()
    names = cut(args.kit, args.set, args.out, args.preview)
    print("wrote %d files to %s/%s/" % (len(names), args.out, args.set))


if __name__ == "__main__":
    main()
