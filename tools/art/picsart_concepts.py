#!/usr/bin/env python3
"""Concept pictures for the open battle-map look questions (docs/research/hades-iso-maps.md).

These are reference pictures for Brandon to react to, not game art. Nothing here is cut or
imported; the outputs stay under art/picsart/out/hades-concepts/.

Usage:
  ~/.lodestone/venv/bin/python tools/art/picsart_concepts.py              # every concept without a raw yet
  ~/.lodestone/venv/bin/python tools/art/picsart_concepts.py --only ring_chamber --regen

The key is read as in picsart_render.py and never printed.
"""

import argparse
import io
from concurrent.futures import ThreadPoolExecutor

import requests
from PIL import Image

from picsart_render import REPO, api_key, generate, upload

MODEL = "gpt-image-2.5-sunburst"
OUT = REPO / "art" / "picsart" / "out" / "hades-concepts"

CAMERA = ("Isometric game art, 2:1 dimetric camera (tile diamonds exactly twice as wide as tall, grid "
          "lines at 26.565 degrees), orthographic, no perspective, no horizon, no tilt-shift, no depth of field. ")
PAINT = ("Hand-painted look: visible gouache-like brushwork on the stone and moss, with pen-and-ink "
         "linework on the stone joints. Warm dark plum-grey outlines (#373335), never pure black. Soft light "
         "from the upper left. Muted sage green moss, warm stone grey, teal water, cream paper tones. "
         "Clean, readable game art. ")
AVOID = ("No text, no letters, no labels, no UI, no watermark, no logo. No photorealism, no 3D render, "
         "no fisheye, no neon.")

CONCEPTS = {
    # Question 1: island on paper (control) against the painted ring around the floor.
    "island_paper": (CAMERA + PAINT +
        "A stepped isometric arena floor of chunky mossy stone blocks, two height levels, centred in the "
        "frame, as a floating island diorama on plain cream paper. Cliffs drop into the paper, a few loose "
        "cubes fall away. Nothing behind the island. " + AVOID, "16:9"),
    "ring_chamber": (CAMERA + PAINT +
        "The same stepped isometric arena floor of chunky mossy stone blocks, two height levels, centred in "
        "the frame. Around it the floor continues into a painted underworld chamber: tall broken columns, "
        "statues, a far colonnade and dim arches, all fading into deep teal-violet darkness toward the "
        "edges. The floor's outer cells dissolve into the dark. Nothing stands on the floor's edge. " + AVOID, "16:9"),
    # Question 2 and the rim: the cliff edge of a floor sitting in the dark.
    "rim_cliff": (CAMERA + PAINT +
        "Close isometric view of the outer edge of a stone arena floor: a chunky block cliff rim two levels "
        "tall with a stone course for each level, moss caps overhanging the top edge, a small waterfall "
        "pouring over one corner into dark mist, a few loose stones falling below. The base of the rim fades "
        "into a deep teal tint, never black. " + AVOID, "1:1"),
    # Question 3: how a wall hides a piece behind it.
    "wall_cutaway": (CAMERA + PAINT +
        "A two-level stone ruin wall running diagonally through the frame. A small hooded figure with a "
        "sword and a cream and ochre cloak stands behind it, about the size of a token. The wall is cut "
        "away in a round hole centred on the figure; the edge of the hole breaks into a fine dithered "
        "pattern, and the rest of the wall stays solid. " + AVOID, "1:1"),
    # Question 2 detail: shaded faces, pure black against hue-shifted.
    "shade_compare": (CAMERA + PAINT +
        "Two identical chunky stone blocks side by side on cream paper, each with a grass top and a stone "
        "front. Left block: the shaded right face is pure black. Right block: the shaded right face is a "
        "deep cool teal-plum with a hue shift, the same value step darker, and the same pen-line on the stone "
        "joints. " + AVOID, "16:9"),
}


FLAT = ("Simple handdrawn flat game art, exactly the style of image 1: one flat colour per surface plus one "
        "flat shadow tone, a few medium-weight hand-drawn outlines in warm dark plum-grey (#373335) around big "
        "shapes only, big solid blocks and terraces, silhouette props, soft muted greens and warm stone, no "
        "gradients, no painted texture, no scattered pebbles. Keep the layout of image 2 (the floor, the "
        "ring of architecture around it, the darkness at the edge), but redraw everything in that flat style. ")

# Concepts that take Brandon's style picture (and an earlier concept for layout) as image inputs.
FLAT_REF = REPO / "docs" / "art" / "references" / "style-flat-forest.png"
REFS = {"crypt_overview": [OUT / "castle_forest.png", OUT / "explore_current_graybox.png"],
        "castle_forest": [OUT / "mountain_snow.png", OUT / "ring_forest.png"],
        "mountain_snow": [FLAT_REF, OUT / "ring_snow.png"],
        "ring_flat": [FLAT_REF, OUT / "ring_chamber.png"],
        "ring_forest": [FLAT_REF, OUT / "ring_flat.png"],
        "ring_snow": [FLAT_REF, OUT / "ring_flat.png"]}
CONCEPTS["ring_flat"] = (CAMERA + FLAT + AVOID, "16:9")
# Same layout and camera, other open ground. The ring turns from architecture into landscape.
CONCEPTS["ring_forest"] = (CAMERA + FLAT +
    "Keep the layout of image 2 but make it a forest clearing: the stepped floor is packed earth and "
    "mossy roots with flat green grass tops and a few stones. Around it the ring is pines, round trees, "
    "boulders and a fallen log, fading into deep green-teal darkness at the edge. No statues, no "
    "architecture, one small pool at most. " + AVOID, "16:9")
# Stress test for a complicated map: several heights, branching paths, a river, a climb.
CONCEPTS["mountain_snow"] = (CAMERA + FLAT +
    "A snowy mountainside seen from the same camera, climbing from the bottom-left corner toward the "
    "top-right. Stepped rock ledges and cliffs at many heights, one height step per level. A winding "
    "stone-and-snow path climbs the slope and forks in two at a ledge: one branch goes along a narrow "
    "ledge, the other goes up a steep stair cut into the rock. A frozen river runs down through the middle, "
    "with a waterfall stepping down one ledge into a dark gorge. Snow-covered pines and boulders low on "
    "the slope, bare grey rock higher up. The slope fades at its edges into deep blue-violet night, with "
    "snowy peaks dark in the distance. Keep the paths, river and ledges clearly readable. " + AVOID, "16:9")
# The whole crypt explore map (34 x 30 cells) as one wide picture, not the zoomed-in follow camera.
CONCEPTS["crypt_overview"] = (CAMERA + "Match the rendering of image 1 exactly. Image 2 is the current "
    "graybox explore screen, for layout only: the water channels, the stepped terraces, the pillared hall and "
    "the rooms. " +
    "The whole crypt complex seen at once from the same camera, big and wide: a walled crypt on a rise with "
    "corridors and rooms, stone stairs that climb or drop one level between terraces, a still water channel "
    "with a narrow stone bridge, a pillared hall with a raised altar, a sealed crypt door, a locked iron gate, "
    "a wooden chest in a side room, a bandit camp in the open plaza, wolves in a cave mouth at the far corner. "
    "A small party of three stands at the bottom-left entrance. Part of the map at the far edges is still "
    "unexplored: cover it in a soft dark fog, with the explored rooms bright. Walls are clearly two levels "
    "tall at the back and one level at the front. " + AVOID, "16:9")

# Multi-room exploration map: a ruined castle with a courtyard, throne room and stairs down.
CONCEPTS["castle_forest"] = (CAMERA + "Match the rendering of image 1 exactly: the same brushwork, outlines, "
    "value steps and fills. Image 2 is a forest reference only. " +
    "A huge ruined castle in a dense forest, seen from the same camera and filling the frame as one walled "
    "complex on a rise: a broken outer wall with a gate, a courtyard with a cracked fountain and a fallen "
    "statue, a great hall, a throne room with a long central carpet, columns and a raised dais at the far end, "
    "several smaller rooms with doorways between them, and a stone stair going down into a cellar behind a "
    "grate. Walls are two levels tall on the back side and one level on the front. Roofs are gone, walls are "
    "broken, tree roots push through the floors, moss on the stone, trees all around outside and some inside "
    "the courtyard. Keep the room layout and doorways clear and readable. The edge fades into dark green-teal "
    "night. " + AVOID, "16:9")
CONCEPTS["ring_snow"] = (CAMERA + FLAT +
    "Keep the layout of image 2 but make it a snowy field: the stepped floor is packed snow and grey-blue "
    "ice blocks with pale blue-white tops. Around it the ring is snow-covered pines, snowdrifts and frozen "
    "boulders, fading into deep blue-violet night at the edge. One tiny warm light from a cabin window. No "
    "statues, no architecture, no water channels. " + AVOID, "16:9")


def run(key, name, prompt, aspect):
    params = {"prompt": prompt, "aspectRatio": aspect, "resolution": "1K", "count": 1}
    if name in REFS:
        params["resolution"] = "2K"
        params["imageUrls"] = [upload(key, Image.open(p).convert("RGB")) for p in REFS[name]]
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
    todo = dict(CONCEPTS)
    if args.only:
        todo = {k: v for k, v in todo.items() if k in args.only.split(",")}
    if not args.regen:
        todo = {k: v for k, v in todo.items() if not (OUT / (k + ".png")).exists()}
    if not todo:
        print("nothing to do")
        return
    key = api_key()
    with ThreadPoolExecutor(3) as pool:
        for line in pool.map(lambda kv: run(key, kv[0], kv[1][0], kv[1][1]), todo.items()):
            print(line, flush=True)


if __name__ == "__main__":
    main()
