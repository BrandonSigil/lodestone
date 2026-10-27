#!/usr/bin/env python3
"""Generate the starting village art with Picsart: two tile kits, two prop sheets and the buildings.

Usage:
  ~/.lodestone/venv/bin/python tools/art/picsart_village.py            # every job without a raw yet
  ~/.lodestone/venv/bin/python tools/art/picsart_village.py --only tavern,props_out --regen

Raws go to art/picsart/out/village/<job>.png. Cut them into the game with tools/art/village_cut.py.
Prompts: art/prompts/sheet-tile-kit.txt, sheet-prop-grid.txt, sheet-building.txt. The key is read as
in picsart_render.py and never printed.
"""

import argparse
import io
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import requests
from PIL import Image

from picsart_render import REPO, api_key, generate, upload

MODEL = "gpt-image-2.5-sunburst"
PROMPTS = REPO / "art" / "prompts"
OUT = REPO / "art" / "picsart" / "out" / "village"
REF = REPO / "docs" / "art" / "references" / "style-flat-forest.png"
REF_TILES = REPO / "docs" / "art" / "references" / "style-flat-forest-tiles.png"

OUTSIDE = ("an old, quiet human village in a green valley, about fifty years empty: warm timber, "
           "pale plaster, grey-tan field stone, faded straw and moss green, one small accent of "
           "faded brick red")
INSIDE = ("inside an old empty village cottage: warm honey wood, pale plaster, grey hearth stone, "
          "faded cloth, dust; one small accent of faded brick red")

# Prop sheet order; village_cut.py names the cut sprites in the same order.
PROPS_OUT = ["stone well with a little wooden roof", "market stall with a torn cloth awning",
             "wooden barrel", "stack of two crates", "hand cart with a broken wheel",
             "round hay bale", "short wooden fence section", "notice board on two posts (blank, no paper)",
             "iron lamp post", "wooden bench", "stone planter overgrown with a round bush",
             "blacksmith anvil on a stump", "empty wooden weapon rack with three pegs",
             "grindstone wheel on a frame", "tree stump", "round leafy village tree"]
PROPS_IN = ["simple wooden bed with a folded blanket", "small square wooden table",
            "wooden chair", "tall bookshelf with a few books", "stone fireplace hearth (cold)",
            "wooden chest", "tall wooden cupboard", "small round rug (flat on the floor)",
            "wooden stool", "clay pot and jug", "long tavern table", "tavern bar counter section",
            "big ale barrel on its side on a stand", "writing desk", "small wall shelf with a few jars",
            "cobwebbed broken chair"]

BUILDINGS = {
    "b_home_hero": "a small one-room cottage, pale plaster walls with dark timber frame, steep faded straw thatch roof, one chimney, a round window",
    "b_home_a": "a narrow two-storey village house, grey field stone ground floor, timber and plaster upper floor, slate roof with a few tiles missing",
    "b_home_b": "a wide village house with two rooms, pale plaster walls, faded red clay tile roof, a small side chimney, shuttered windows",
    "b_home_c": "a cosy old village house, warm timber walls, mossy straw thatch roof, a small porch roof over the door, a stack of firewood",
    "b_tavern": "a big two-storey village tavern, stone ground floor, timber upper floor with a jetty, wide clay tile roof, a hanging blank wooden sign on an iron bracket, two chimneys",
    "b_smithy": "a blacksmith's forge, stone walls with a big open front side under a deep timber roof, a tall stone chimney, a cold forge hearth inside",
    "b_townhall": "a village town hall, the largest building, grey cut stone walls, tall slate roof with a small open bell tower on top, wide double doors, two tall windows",
}


def jobs():
    kit = (PROMPTS / "sheet-tile-kit.txt").read_text(encoding="utf-8").strip()
    grid = (PROMPTS / "sheet-prop-grid.txt").read_text(encoding="utf-8").strip()
    bld = (PROMPTS / "sheet-building.txt").read_text(encoding="utf-8").strip()
    out = {
        "kit_village": (kit.replace("[ZONE]", OUTSIDE + ". Tops: village green grass, packed dirt lane, worn cobbles, "
                                    "flat paving, rubble. Walls: field stone and plaster. Tree: round leafy tree."), [REF, REF_TILES]),
        "kit_house": (kit.replace("[ZONE]", INSIDE + ". Tops: plank floor, plank floor variant, rush matting, "
                                  "hearth flagstones, broken boards. Walls: plaster with a timber band. "
                                  "Props as listed but indoor (crate, candle, small pot)."), [REF, REF_TILES]),
        "props_out": (grid.replace("[ZONE]", OUTSIDE).replace("[LIST]", "; ".join(PROPS_OUT)), [REF, REF_TILES]),
        "props_in": (grid.replace("[ZONE]", INSIDE).replace("[LIST]", "; ".join(PROPS_IN)), [REF, REF_TILES]),
    }
    for name, desc in BUILDINGS.items():
        out[name] = (bld.replace("[ZONE]", desc), [REF])
    return out


def run(key, name, prompt, refs, urls):
    params = {"prompt": prompt, "aspectRatio": "1:1", "resolution": "2K", "count": 1,
              "imageUrls": [urls[r] for r in refs]}
    for attempt in range(3):
        try:
            got, charged = generate(key, MODEL, params)
            break
        except SystemExit as e:  # vendor 5xx errors are usually transient
            print("  %s: %s, retrying" % (name, str(e)[:120]), flush=True)
    else:
        return "%s: gave up" % name
    img = Image.open(io.BytesIO(requests.get(got[0], timeout=120).content))
    img.save(OUT / (name + ".png"))
    return "%s: %dx%d, charged %s" % (name, img.width, img.height, charged)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--regen", action="store_true")
    args = ap.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    todo = jobs()
    if args.only:
        todo = {k: v for k, v in todo.items() if k in args.only.split(",")}
    if not args.regen:
        todo = {k: v for k, v in todo.items() if not (OUT / (k + ".png")).exists()}
    if not todo:
        print("nothing to do")
        return
    key = api_key()
    urls = {r: upload(key, Image.open(r).convert("RGB")) for r in (REF, REF_TILES)}
    with ThreadPoolExecutor(4) as pool:
        for line in pool.map(lambda kv: run(key, kv[0], kv[1][0], kv[1][1], urls), todo.items()):
            print(line, flush=True)


if __name__ == "__main__":
    main()
