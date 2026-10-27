#!/usr/bin/env python3
"""Cut the village Picsart raws (tools/art/picsart_village.py) into game art.

Usage:
  ~/.lodestone/venv/bin/python tools/art/village_cut.py [--preview art/picsart/village_contact.png]

- kit_village / kit_house -> tile sets game/art/source/battle/village/ and village_in/ (kit_cut.py)
- props_out / props_in (4 x 4 prop sheets) -> prop_<name>.png in those sets, keyed off the paper
- b_* buildings -> b_<name>.png in village/, 512 wide. Prints each building's wall split (left wall
  share of the width), which says how long its footprint is along x (left wall) and y (right wall).
"""

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

from char_art import key_background
from kit_cut import OUT, cut, ink_mask, runs
from picsart_village import BUILDINGS, REPO

RAW = REPO / "art" / "picsart" / "out" / "village"
PROP_H = 256
BUILDING_W = 512

NAMES_OUT = ["well", "stall", "barrel", "crates", "cart", "hay", "fence", "board",
             "lamp", "bench", "planter", "anvil", "rack", "grindstone", "stump", "tree"]
NAMES_IN = ["bed", "table", "chair", "bookshelf", "hearth", "chest", "cupboard", "rug",
            "stool", "pots", "long_table", "bar", "ale_barrel", "desk", "jar_shelf", "broken_chair"]


def cut_props(sheet, names, set_name):
    # The sheet is an even 4 x 4 grid, so each prop is the ink inside its quarter cell.
    img = Image.open(sheet).convert("RGB")
    mask = ink_mask(np.asarray(img))
    h, w = mask.shape
    out = []
    for i, name in enumerate(names):
        x0, y0 = (i % 4) * w // 4, (i // 4) * h // 4
        x1, y1 = x0 + w // 4, y0 + h // 4
        sub = mask[y0:y1, x0:x1]
        # Keep the biggest blob of rows and columns: stray bits of the neighbouring cell drop out.
        ra, rb = max(runs(sub.any(1), 4, 12), key=lambda r: r[1] - r[0])
        sub = sub.copy()
        sub[:ra] = False
        sub[rb:] = False
        ca, cb = max(runs(sub.any(0), 4, 12), key=lambda r: r[1] - r[0])
        sub[:, :ca] = False
        sub[:, cb:] = False
        ys, xs = np.where(sub)
        pad = 6
        box = (max(x0 + xs.min() - pad, 0), max(y0 + ys.min() - pad, 0),
               min(x0 + xs.max() + 1 + pad, w), min(y0 + ys.max() + 1 + pad, h))
        prop = key_background(img.crop(box))
        prop = prop.crop(prop.getchannel("A").getbbox())
        prop = prop.resize((max(1, round(prop.width * PROP_H / prop.height)), PROP_H), Image.LANCZOS)
        prop.save(OUT / set_name / ("prop_" + name + ".png"))
        out.append(("prop_" + name, prop))
    return out


def cut_building(name):
    img = key_background(Image.open(RAW / (name + ".png")).convert("RGB"))
    img = img.crop(img.getchannel("A").getbbox())
    alpha = np.asarray(img.getchannel("A")) > 128
    # The front corner is the lowest solid pixel; walls run up-left and up-right from it.
    ys, xs = np.where(alpha)
    bottom = ys.max()
    front_x = xs[ys >= bottom - 3].mean()
    split = front_x / img.width
    img = img.resize((BUILDING_W, round(img.height * BUILDING_W / img.width)), Image.LANCZOS)
    img.save(OUT / "village" / (name + ".png"))
    print("%s: left wall share %.2f" % (name, split))
    return (name, img)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview")
    args = ap.parse_args()
    written = []
    cut(RAW / "kit_village.png", "village")
    cut(RAW / "kit_house.png", "village_in")
    written += cut_props(RAW / "props_out.png", NAMES_OUT, "village")
    written += cut_props(RAW / "props_in.png", NAMES_IN, "village_in")
    for name in BUILDINGS:
        written.append(cut_building(name))
    if args.preview:
        cell = 200
        n = len(written)
        sheet = Image.new("RGB", (cell * 8, cell * ((n + 7) // 8)), (234, 232, 214))
        for i, (_, im) in enumerate(written):
            t = im.copy()
            t.thumbnail((cell - 10, cell - 10))
            sheet.paste(t, ((i % 8) * cell + 5, (i // 8) * cell + 5), t)
        sheet.save(args.preview)
    print("cut %d props and buildings" % len(written))


if __name__ == "__main__":
    main()
