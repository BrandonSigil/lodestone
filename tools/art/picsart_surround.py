#!/usr/bin/env python3
"""Backdrop plates: the world that keeps going past a map's floor (docs/art/environments.md).

One 3:2 picture per art set, drawn behind the board. The floor is covered by the board's own tiles, so the
plate is mostly seen at its edges: the surround, the far layer and the fade into the dark. The look follows
the example pictures in docs/art/references/surround-*-example.png (the user's pick, 2026-10-27).

Usage:
  ~/.lodestone/venv/bin/python tools/art/picsart_surround.py              # every plate without a raw yet
  ~/.lodestone/venv/bin/python tools/art/picsart_surround.py --only surround_snow --regen

Raws go to art/picsart/out/surround/<job>.png. Nothing is cut into the game until Brandon approves a raw.
The key is read as in picsart_render.py and never printed.
"""

import argparse
import io
from concurrent.futures import ThreadPoolExecutor

import requests
from PIL import Image

from picsart_render import REPO, api_key, generate, upload

MODEL = "gpt-image-2.5-sunburst"
OUT = REPO / "art" / "picsart" / "out" / "surround"
REFS = REPO / "docs" / "art" / "references"
EX_SNOW = REFS / "surround-snow-example.png"
EX_CRYPT = REFS / "surround-crypt-example.png"

CAMERA = ("Isometric game backdrop, 2:1 dimetric camera (tile diamonds exactly twice as wide as tall), "
          "orthographic, no perspective, no horizon line, no sky, no moon, no tilt-shift, no depth of field. ")
LOOK = ("Painted pixel-art look like the first reference image: chunky shapes, thick dark plum-grey outlines "
        "(#373335, never pure black) around the big shapes, one soft light from the upper left, flat colour "
        "fields with a few clear value steps. ")
FLOOR = ("A large stepped floor platform sits in the middle of the frame, plain and open in its centre, with "
         "its outer edge dropping into the dark. ")
EDGE = ("The world continues past the floor's edge: the surround fades into deep, cool, darkened tones of the "
        "set's own colour at the outer edge of the frame, never black. Nothing stands on the very edge of the "
        "floor. ")
AVOID = ("No text, no letters, no labels, no UI, no watermark, no logo, no people, no animals, no photorealism, "
         "no 3D render, no fisheye, no neon, no grain.")

JOBS = {
    "surround_snow": (CAMERA + LOOK + FLOOR +
        "Snowy rock platform: grey stone blocks with snow caps, packed snow tops, a few snow-covered pines and "
        "shrubs on the outer ground, a frozen stream on one side. Around it, rock outcrops and snow-covered pine "
        "trees, and far behind them, snowy mountain silhouettes, all fading into deep navy dusk toward the "
        "frame edges. Cool palette: navy, slate, pale blue-white snow, one warm straw accent on the path. " + EDGE + AVOID,
        [EX_SNOW]),
    "surround_ruins": (CAMERA + LOOK + FLOOR +
        "Same layout and simple shapes as the first reference image, forest-ified: a plain stone courtyard "
        "floor of flat grey-tan stone with big calm areas and only a few cracks, a few low stone walls with "
        "green moss tops, a little stone stair. Around it, grass and dark green pine trees and round bushes "
        "instead of the snow, far dark forest silhouettes fading into deep teal-green dusk toward the frame "
        "edges. Fewer details than the reference: big flat fields, no cobbles drawn on the stone, no ivy, no "
        "carvings. " + EDGE + AVOID,
        [EX_SNOW]),
    "surround_interior": (CAMERA + LOOK +
        "A plain room of an old village house, seen at ground level: the floor is flat honey-brown wood planks "
        "with a few plank seams, and it sits flush on the ground with no stilts, no legs and no underside. Low "
        "plaster walls with a dark timber band only at the back, one level tall, with a simple doorway. Past the "
        "floor's edge the ground drops into a dark violet-grey void, plain and empty. Few details, big flat "
        "fields, one small accent of faded brick red. " + EDGE + AVOID,
        [EX_SNOW]),
}


def run(key, name, prompt, refs):
    urls = [upload(key, Image.open(p).convert("RGB")) for p in refs]
    params = {"prompt": prompt, "aspectRatio": "3:2", "resolution": "2K", "count": 1, "imageUrls": urls}
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
    todo = dict(JOBS)
    if args.only:
        todo = {k: v for k, v in todo.items() if k in args.only.split(",")}
    if not args.regen:
        todo = {k: v for k, v in todo.items() if not (OUT / (k + ".png")).exists()}
    if not todo:
        print("nothing to do")
        return
    key = api_key()
    with ThreadPoolExecutor(3) as pool:
        futures = [pool.submit(run, key, name, prompt, refs) for name, (prompt, refs) in todo.items()]
        for f in futures:
            print(f.result(), flush=True)


if __name__ == "__main__":
    main()
