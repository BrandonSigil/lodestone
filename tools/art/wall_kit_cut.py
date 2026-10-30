#!/usr/bin/env python3
"""Cut a wall kit picture (art/prompts/sheet-wall-kit.txt: a 3 x 3 grid of square pieces) into the files the
board reads for a wall kit (the map builder's wiring, 0f2070c).

    python3 tools/art/wall_kit_cut.py KIT.png --kit interior --out art/picsart/out/wall-kits/cut_interior_v1

Cells are found from the cream gaps; each is trimmed by INSET (the soft painted rim) and resized to 512
square. Writes to a staging folder; approved pieces are copied into game/art/source/battle/<set>/.
"""

import argparse
from pathlib import Path

from PIL import Image
import numpy as np

from kit_cut import ink_mask, runs

TILE_PX = 512
INSET = 0.04
NAMES = {
    "interior": ["wall_plain", "wall_worn", "wall_timber", "wall_window", "wall_door", "wall_top",
                 "top_stone", "top_stone_b", "side_masonry"],
    "dungeon": ["wall_plain", "wall_cracked", "wall_corner", "wall_door", "wall_cap", "wall_foot",
                "top_stone", "top_stone_b", "side_masonry"],
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("kit_png")
    ap.add_argument("--kit", required=True, choices=sorted(NAMES))
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    img = Image.open(args.kit_png).convert("RGB")
    a = np.asarray(img)
    h, w = a.shape[:2]
    mask = ink_mask(a, tol=8)  # pale plaster sits close to the paper
    rows = runs(mask.mean(1) > 0.5, min_len=h // 8, min_gap=h // 200)
    if len(rows) != 3:
        raise SystemExit("found %d rows, expected 3" % len(rows))
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    names = iter(NAMES[args.kit])
    for r, (y0, y1) in enumerate(rows):
        cols = runs(mask[y0:y1].mean(0) > 0.5, min_len=w // 8, min_gap=w // 200)
        if len(cols) != 3:
            raise SystemExit("row %d: found %d cells, expected 3" % (r + 1, len(cols)))
        for x0, x1 in cols:
            dx, dy = int((x1 - x0) * INSET), int((y1 - y0) * INSET)
            name = next(names)
            img.crop((x0 + dx, y0 + dy, x1 - dx, y1 - dy)).resize((TILE_PX, TILE_PX), Image.LANCZOS).save(out / (name + ".png"))
            print("%s: cell %d x %d" % (name, x1 - x0, y1 - y0))


if __name__ == "__main__":
    main()
