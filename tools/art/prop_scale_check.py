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

import csv

# The numbers live in game/data (shared with the map maker's QA panel, MapQA): map_qa.csv and prop_scale.csv.
_DATA = Path(__file__).resolve().parents[2] / "game" / "data"
_CFG = {r["key"]: float(r["value"]) for r in csv.DictReader(open(_DATA / "map_qa.csv"))}
HERO_TALL = _CFG["hero_tall"]
# sprite -> [door or opening height as a share of the sprite's height, headroom factor, aspect (w / h of the picture)]
DOOR = {r["sprite"]: [float(r["door"]), float(r["headroom"]), float(r["aspect"])] for r in csv.DictReader(open(_DATA / "prop_scale.csv"))}
BUILDING_MIN = _CFG["building_min"]  # hero heights


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
        if not _CFG["width_min"] <= width_ratio <= _CFG["width_max"]:
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
