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
# The town plates with a sky and horizon drop the rule against them (docs/art/environments.md, Q8).
CAMERA_SKY = ("Isometric game backdrop, 2:1 dimetric camera (tile diamonds exactly twice as wide as tall), "
              "orthographic, no perspective, no tilt-shift, no depth of field. ")
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

# Wide strips that are not plates: the skyline behind the whole board (docs/art/environments.md, section 8).
ASPECT = {"skyline_village": "16:9", "foreground_village": "16:9"}

JOBS = {
    # Foreground treeline for the village: dense flat navy pines along the bottom, fading into dark blue.
    "foreground_village": (
        "A wide foreground strip of a forest seen from above at the bottom of the picture: dense dark navy pine "
        "tree silhouettes packed tightly along the bottom edge, overlapping in tiers, flat solid navy with no "
        "outlines, no highlights and no detail. The top edge of the tree row is ragged and irregular. Below the "
        "trees the colour fades smoothly into deep dark blue reaching the bottom edge of the picture. Colours: tree "
        "navy #0f1830, fade from #1f2b4d at the top to #0d1429 at the bottom. Flat, simple, few details. No text, "
        "no watermark.",
        [EX_SNOW]),
    "skyline_village": (
        "A wide horizon strip, no ground and no floor: a pale blue sky with a few soft clouds at the top, "
        "snow-capped blue-grey mountains across the whole width, and dark pine forest silhouettes along the bottom "
        "edge fading into deep blue. Flat painted colours, big flat shapes, few details. No text, no watermark.",
        [EX_SNOW]),
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
    "surround_town_interior": (CAMERA + LOOK +
        "A plain town hall room at ground level: the floor is flat honey-brown wood planks, flush on the ground, "
        "with a bare, empty centre and no furniture on the floor. Low plaster walls with a dark timber band at the "
        "back, one level tall, a doorway and a shuttered window. Any furniture only against the walls, never on "
        "the floor. Past the floor's edge the ground drops into a dark violet-grey void, plain and empty. Few "
        "details, big flat fields, one small accent of faded brick red. " + EDGE + AVOID,
        [EX_SNOW]),
    "surround_forest": (CAMERA + LOOK + FLOOR +
        "A forest clearing floor: flat grass tops with a few packed dirt paths and mossy stones. Around it, pines "
        "and round trees, bushes, boulders and a fallen log, and far behind them dark pine silhouettes fading into "
        "deep green-teal dusk. Green palette with one warm accent. Big flat fields, few details. " + EDGE + AVOID,
        [EX_SNOW]),
    "surround_dungeon_inner": (CAMERA + LOOK + FLOOR +
        "An inner dungeon chamber of cold dark stone: a flagstone floor of big calm slabs, low walls of rough block "
        "courses, one iron brazier with a small warm flame, a shallow drain channel. Around it the walls and pillars "
        "continue into slate-blue gloom, with far faint archways fading into deep indigo. Muted slate and blue-grey "
        "stone, one warm ember accent. Big flat fields, few details. " + EDGE + AVOID,
        [EX_SNOW]),
    # Town test: bigger cliffs and a mountain range from the user's town sample, in our flat look. Two
    # versions: one with a sky and horizon, one that fades into dark like the other plates.
    "surround_village_sky": (CAMERA_SKY + LOOK + FLOOR +
        "A grassy plateau with dirt paths and stone steps. Around it, tall cliffs of layered grey rock with green "
        "grass tops drop into a blue river, with one waterfall on the side and pine trees on the cliff tops. Far "
        "behind, a range of blue-grey mountains with snow caps, and a pale blue sky with a few soft clouds fills "
        "the top of the frame, with a clear horizon line where the mountains meet the sky. Flat painted colours, "
        "one warm accent, big flat fields, few details. " + AVOID,
        [EX_SNOW]),
    "surround_village_dark": (CAMERA + LOOK + FLOOR +
        "A grassy plateau with dirt paths and stone steps. Around it, tall cliffs of layered grey rock with green "
        "grass tops drop into a blue river, with one waterfall on the side and pine trees on the cliff tops. Far "
        "behind, mountain silhouettes and pine forest fading into deep navy dusk toward the frame edges. Flat painted "
        "colours, one warm accent, big flat fields, few details. " + EDGE + AVOID,
        [EX_SNOW]),
}


def run(key, name, prompt, refs):
    urls = [upload(key, Image.open(p).convert("RGB")) for p in refs]
    aspect = ASPECT.get(name, "3:2")
    params = {"prompt": prompt, "aspectRatio": aspect, "resolution": "2K", "count": 1, "imageUrls": urls}
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
