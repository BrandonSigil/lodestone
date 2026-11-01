#!/usr/bin/env python3
"""Does a map read as a big box? The gate every map passes before it goes on Brandon's desk
([USER] 2026-10-30: "is the entire map basically just a big box? if yes, don't show it to me and work on it. Unique
shapes, jut outs, dynamics, verticality!").

    python3 tools/map_shape.py game/data/explore/crypt.json [more maps...] [--strict]   (strict: the higher bar for a map pushed further)
    python3 tools/map_shape.py game/data/maps/x.json --fight   (fight: the bar for a road fight up to 26 x 26, see FIGHT)

Measures the walkable footprint (cells a piece can stand on: not rock, void or deep water) and prints:
  fill       share of the bounding box the footprint covers          (a box is near 1; winding is low)
  edge       footprint edge cells over the bounding box's perimeter  (a box is about 1; winding is well over 1.8)
  corners    2 x 2 windows holding 1 or 3 footprint cells, per 100 footprint cells (jut-outs and inlets)
  bays       share of the bounding box's four corner quarters left empty (a windy shape leaves bays)
  levels     distinct heights under the footprint
  climbs     separate stair runs (a climb is a run of stair cells) and the tallest drop beside walkable ground
A map passes when it is not a box: fill <= MAX_FILL, edge >= MIN_EDGE, corners >= MIN_CORNERS, bays >= MIN_BAYS, and for
verticality levels >= MIN_LEVELS and climbs >= MIN_CLIMBS. Exit status 1 when any map fails; the verdict lists why.
Calibration (2026-10-30): the live crypt, crypt v1, snow pass, wolf den, village and village_v2 all fail it today, as does the
first crypt_v2 (rounded rooms in a full box: fill 0.62, edge 1.9). A new map has to be built to pass; thresholds move only with a reason here.
"""
import json
import sys
from pathlib import Path

HD = "0123456789abcdefghijklmnopqrstuvwxyz"
MAX_FILL = 0.45
MIN_EDGE = 1.8
MIN_CORNERS = 14.0
MIN_BAYS = 0.30
MIN_LEVELS = 8
MIN_CLIMBS = 8
WALK_NOT = set("r.")  # rock and void are not footprint


def load(path):
    d = json.loads(Path(path).read_text())
    g = d.get("grid", d.get("map", d))
    terr = g["terrain"]
    heights = g["heights"]
    decks = g.get("decks", [])
    return terr, [[HD.index(c) for c in row] for row in heights], decks


def measure(path):
    terr, hs, decks = load(path)
    H, W = len(terr), len(terr[0])
    walk = [[terr[y][x] not in WALK_NOT and terr[y][x] != "w" for x in range(W)] for y in range(H)]
    for dk in decks:
        walk[int(dk["y"])][int(dk["x"])] = True
    cells = [(x, y) for y in range(H) for x in range(W) if walk[y][x]]
    if not cells:
        return None
    xs = [c[0] for c in cells]
    ys = [c[1] for c in cells]
    bw, bh = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
    x0, y0 = min(xs), min(ys)
    fill = len(cells) / (bw * bh)
    edge = sum(1 for x, y in cells if any(not (0 <= x + dx < W and 0 <= y + dy < H and walk[y + dy][x + dx])
                                          for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))))
    edge_ratio = edge / (2.0 * (bw + bh))
    corners = 0
    for y in range(-1, H):
        for x in range(-1, W):
            n = sum(1 for dx in (0, 1) for dy in (0, 1)
                    if 0 <= x + dx < W and 0 <= y + dy < H and walk[y + dy][x + dx])
            corners += n in (1, 3)
    corners_100 = 100.0 * corners / len(cells)
    qw, qh = max(1, bw // 4), max(1, bh // 4)
    bays = []
    for (cx0, cy0) in ((x0, y0), (x0 + bw - qw, y0), (x0, y0 + bh - qh), (x0 + bw - qw, y0 + bh - qh)):
        n = sum(1 for y in range(cy0, cy0 + qh) for x in range(cx0, cx0 + qw) if walk[y][x])
        bays.append(1.0 - n / (qw * qh))
    bays_avg = sum(bays) / 4.0
    levels = len({hs[y][x] for x, y in cells})
    seen = set()
    runs = 0
    for x, y in cells:
        if terr[y][x] != "t" or (x, y) in seen:
            continue
        runs += 1
        stack = [(x, y)]
        while stack:
            cx, cy = stack.pop()
            if (cx, cy) in seen:
                continue
            seen.add((cx, cy))
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = cx + dx, cy + dy
                if 0 <= nx < W and 0 <= ny < H and terr[ny][nx] == "t" and (nx, ny) not in seen:
                    stack.append((nx, ny))
    drop = 0
    for x, y in cells:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < W and 0 <= ny < H and terr[ny][nx] not in "r." and terr[y][x] != "t" and terr[ny][nx] != "t":
                drop = max(drop, hs[y][x] - hs[ny][nx])
    return {"map": Path(path).stem, "size": f"{W}x{H}", "fill": round(fill, 2), "edge": round(edge_ratio, 2),
            "corners": round(corners_100, 1), "bays": round(bays_avg, 2), "levels": levels, "climbs": runs, "drop": drop}


STRICT = {"MAX_FILL": 0.42, "MIN_EDGE": 2.0, "MIN_CORNERS": 25.0, "MIN_BAYS": 0.6, "MIN_LEVELS": 11, "MIN_CLIMBS": 12}  # the standard bar is 0.45 / 1.8 / 14 / 0.3 / 8 / 8


## [AI] 2026-11-01: a road fight is 21 x 18, and both starts need a full, flat deploy band at each end, so it cannot wind like
## an explore map: the standard bar's fill and edge assume room to snake. Fill <= 0.62 and edge >= 1.3 still fail a box
## (a box is fill ~1, edge ~1); corners and bays stay as standard; levels 7 and 4 climbs suit the smaller map.
FIGHT = {"MAX_FILL": 0.62, "MIN_EDGE": 1.3, "MIN_CORNERS": 14.0, "MIN_BAYS": 0.3, "MIN_LEVELS": 7, "MIN_CLIMBS": 4}


def verdict(m, strict=False, fight=False):
    global MAX_FILL, MIN_EDGE, MIN_CORNERS, MIN_BAYS, MIN_LEVELS, MIN_CLIMBS
    keys = ("MAX_FILL", "MIN_EDGE", "MIN_CORNERS", "MIN_BAYS", "MIN_LEVELS", "MIN_CLIMBS")
    if strict:  # the higher bar: a map Brandon asked to push further
        MAX_FILL, MIN_EDGE, MIN_CORNERS, MIN_BAYS, MIN_LEVELS, MIN_CLIMBS = [STRICT[k] for k in keys]
    elif fight:  # a road fight up to 26 x 26
        MAX_FILL, MIN_EDGE, MIN_CORNERS, MIN_BAYS, MIN_LEVELS, MIN_CLIMBS = [FIGHT[k] for k in keys]
    why = []
    if m["fill"] > MAX_FILL:
        why.append(f"fills {m['fill']:.0%} of its box (max {MAX_FILL:.0%})")
    if m["edge"] < MIN_EDGE:
        why.append(f"edge {m['edge']} (min {MIN_EDGE})")
    if m["corners"] < MIN_CORNERS:
        why.append(f"corners {m['corners']} (min {MIN_CORNERS})")
    if m["bays"] < MIN_BAYS:
        why.append(f"bays {m['bays']} (min {MIN_BAYS})")
    if m["levels"] < MIN_LEVELS:
        why.append(f"{m['levels']} levels (min {MIN_LEVELS})")
    if m["climbs"] < MIN_CLIMBS:
        why.append(f"{m['climbs']} climbs (min {MIN_CLIMBS})")
    return why


if __name__ == "__main__":
    bad = False
    strict = "--strict" in sys.argv
    fight = "--fight" in sys.argv
    for f in [a for a in sys.argv[1:] if not a.startswith("--")]:
        m = measure(f)
        why = verdict(m, strict, fight)
        bad |= bool(why)
        print(("ok   " if not why else "BOX  ") + json.dumps(m) + ("" if not why else "  <- " + "; ".join(why)))
    sys.exit(1 if bad else 0)
