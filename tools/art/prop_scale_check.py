#!/usr/bin/env python3
"""Is a prop the right size for the hero? ([USER] 2026-10-30: "Does it make sense that a crypt gate would be that small?
Or a boat house the size of our character? Things should make spacial sense." Run before a map goes on his desk.)

    python3 tools/art/prop_scale_check.py game/data/explore/village_v2.json [more maps...]

The hero is HERO_TALL prop-height units tall (measured from a windowed shot: a door of 0.8 hero height on a 5.5 tall windmill).
A prop's `tall` is its height in units of one tile width; its sprite's door or opening is DOOR[sprite] of that height. Rules:
  door     a door must be at least as tall as the hero (a gate: 1.2 times, so there is room above);
  width    the sprite's drawn width over its footprint's screen width stays between 0.5 and 1.6 (the footprint grows with it);
  minimum  houses and other buildings are at least 2 hero heights tall.
Exit status 1 if any prop fails.
"""
import json
import sys
from pathlib import Path

HERO_TALL = 1.25
# sprite -> [door or opening height as a share of the sprite's height, headroom factor, aspect (w / h of the picture)]
DOOR = {"prop_windmill": [0.18, 1.0, 201 / 256], "prop_boathouse": [0.30, 1.0, 369 / 256], "prop_crypt_gate": [0.55, 1.2, 291 / 256],
        "b_home_a": [0.22, 1.0, 1.0], "b_home_b": [0.22, 1.0, 1.0], "b_home_c": [0.22, 1.0, 1.0], "b_home_hero": [0.22, 1.0, 1.0]}
BUILDING_MIN = 2.0  # hero heights


def check(path):
    d = json.loads(Path(path).read_text())
    problems = []
    for p in d["grid"].get("props", []):
        name = p["sprite"].split("/")[-1]
        if name not in DOOR:
            continue
        frac, head, aspect = DOOR[name]
        tall = float(p["tall"]) if float(p["tall"]) > 0 else 0.0
        if tall <= 0:
            continue
        door = tall * frac / HERO_TALL
        if door < head:
            problems.append(f"{name} at {p['cell']}: its door is {door:.2f} hero heights (needs {head:.1f}); make it taller")
        fx, fy = p["foot"]
        width_ratio = (tall * 64 * aspect) / ((fx + fy) * 32 * 1.18)
        if not 0.5 <= width_ratio <= 1.6:
            problems.append(f"{name} at {p['cell']}: drawn {width_ratio:.2f}x the width of its {fx} x {fy} footprint; resize the footprint with it")
        if tall / HERO_TALL < BUILDING_MIN:
            problems.append(f"{name} at {p['cell']}: only {tall / HERO_TALL:.1f} hero heights tall")
    return problems


if __name__ == "__main__":
    bad = False
    for f in sys.argv[1:]:
        pr = check(f)
        bad |= bool(pr)
        print(("ok   " if not pr else "FAIL ") + f + "".join("\n     " + x for x in pr))
    sys.exit(1 if bad else 0)
