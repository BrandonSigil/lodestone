#!/usr/bin/env python3
"""Village v2 as a quaint little hillside village ([USER] 2026-10-30, card builder-village-v2-present: "Fewer bigger
districts and more quaint, all the big bridges and high plateaus make this seem like a huge city or something. It should
be a quaint windy little village that looks like it's built in the side of a mountain.").

The built town (build_village_v2.py) is eased into a mountainside:
  * heights are scaled down so the districts step up the slope in low terraces, not tall plateaus;
  * the bridge decks become short stone causeways (no spans);
  * everything away from the homes, lanes, stairs, shore and yards falls away: rock rising behind the village on its
    uphill (north) side, open air on the others, so the outline winds along the slope;
  * each home gets a 2 x 2 landing outside its door, the bounding box is cropped to what is left.

    python3 tools/explore/hillside_village_v2.py [in.json [out.json]]
Run by build_village_v2.py at its end.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import unfold_village_v2 as U  # noqa: E402

HD = U.HD
SCALE = 0.42  # heights: 24 -> 10, so the cemetery and the hall sit ten steps above the lake
REACH = 1  # cells of open ground kept round anything that matters
MOUNTAIN = 5  # levels the rock stands over the top of the village at its foot, growing to this


def scaled(h):
    return int(round(h * SCALE))


def build_state(d):
    g = d["grid"]
    W, H = g["w"], g["h"]
    ter = [list(r) for r in g["terrain"]]
    hts = [[scaled(HD.index(c)) for c in r] for r in g["heights"]]
    for k in g.get("decks", []):  # a bridge deck becomes a causeway: road at the deck's (scaled) height
        x, y = k["x"], k["y"]
        ter[y][x] = "d"
        hts[y][x] = scaled(k["h"])
    g["decks"] = []
    blocked = {(p["cell"][0] + dx, p["cell"][1] + dy) for p in g["props"] if not p.get("walk")
               for dx in range(p["foot"][0]) for dy in range(p["foot"][1])}
    return {"w": W, "h": H, "ter": ter, "hts": hts, "decks": {}, "blocked": blocked}


def routes(d, st, start):
    """The lanes: the shortest walk (the game's rules) from the start to every thing and companion spot, as cells."""
    W, H, ter, hts = st["w"], st["h"], st["ter"], st["hts"]
    ok = lambda c: 0 <= c[0] < W and 0 <= c[1] < H and ter[c[1]][c[0]] in U.WALK and c not in st["blocked"]
    step = lambda a, b: abs(hts[a[1]][a[0]] - hts[b[1]][b[0]]) <= 1 + (2 if "t" in (ter[a[1]][a[0]], ter[b[1]][b[0]]) else 0)
    parent = {start: None}
    todo = [start]
    while todo:
        nxt = []
        for c in todo:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (c[0] + dx, c[1] + dy)
                if n not in parent and ok(n) and step(c, n):
                    parent[n] = c
                    nxt.append(n)
        todo = nxt
    out = set()
    goals = [(int(t["cell"][0]), int(t["cell"][1])) for t in d["things"]]
    goals += [(int(sp["cell"][0]), int(sp["cell"][1])) for sp in d.get("companion_spots", [])]
    for g in goals:
        end = g if g in parent else next((n for n in ((g[0] + 1, g[1]), (g[0] - 1, g[1]), (g[0], g[1] + 1), (g[0], g[1] - 1)) if n in parent), None)
        while end is not None:
            out.add(end)
            end = parent[end]
    return out


def important(d, st):
    """Cells the village is made of: the lanes between everything, the buildings, things, the start."""
    out = routes(d, st, tuple(d["start"][0]))
    for t in d["things"]:
        out.add((int(t["cell"][0]), int(t["cell"][1])))
    for p in d["grid"]["props"]:
        if any(k in p["sprite"] for k in U.DECOR):
            continue
        for dx in range(p["foot"][0]):
            for dy in range(p["foot"][1]):
                out.add((p["cell"][0] + dx, p["cell"][1] + dy))
    return out


def carve(d, st):
    """Away from the village: rock behind it (uphill, north), air elsewhere. Keeps the walk connected through roads."""
    W, H, ter, hts = st["w"], st["h"], st["ter"], st["hts"]
    imp = important(d, st)
    lane = routes(d, st, tuple(d["start"][0]))
    near = set()
    for (x, y) in imp:
        r = REACH if (x, y) in lane else REACH + 1  # a lane keeps a verge, buildings and things a yard  # lanes and stairs keep a narrow verge, buildings and things more
        for dx in range(-r, r + 1):
            for dy in range(-r, r + 1):
                if abs(dx) + abs(dy) <= r + 1:
                    near.add((x + dx, y + dy))
    keep = {c for c in near if 0 <= c[0] < W and 0 <= c[1] < H and ter[c[1]][c[0]] != "."}
    top = {}
    for x in range(W):
        ys = [y for y in range(H) if (x, y) in keep]
        if ys:
            top[x] = (min(ys), hts[min(ys)][x])
    for y in range(H):
        for x in range(W):
            if (x, y) in keep or ter[y][x] == ".":
                continue
            ter[y][x] = "."
            hts[y][x] = 0
    # the mountain: above the village's top edge in each column (a few cells deep), rock stepping up
    for x, (ty, th) in top.items():
        for k in range(1, 7):
            y = ty - k
            if y < 0:
                break
            if ter[y][x] == ".":
                ter[y][x] = "r"
                hts[y][x] = min(24, th + 1 + min(k, MOUNTAIN))
    return keep


def crop(d, st):
    W, H, ter = st["w"], st["h"], st["ter"]
    xs = [x for y in range(H) for x in range(W) if ter[y][x] != "."]
    ys = [y for y in range(H) for x in range(W) if ter[y][x] != "."]
    x0, y0, x1, y1 = min(xs) - 1, min(ys) - 1, max(xs) + 1, max(ys) + 1
    x0, y0 = max(0, x0), max(0, y0)
    x1, y1 = min(W - 1, x1), min(H - 1, y1)
    st["ter"] = [r[x0:x1 + 1] for r in ter[y0:y1 + 1]]
    st["hts"] = [r[x0:x1 + 1] for r in st["hts"][y0:y1 + 1]]
    st["w"], st["h"] = x1 - x0 + 1, y1 - y0 + 1
    st["blocked"] = {(x - x0, y - y0) for x, y in st["blocked"]}
    sh = lambda c: [int(c[0]) - x0, int(c[1]) - y0]
    for p in d["grid"]["props"]:
        p["cell"] = sh(p["cell"])
    for t in d["things"]:
        t["cell"] = sh(t["cell"])
    d["start"] = [sh(s) for s in d["start"]]
    for s in d.get("companion_spots", []):
        s["cell"] = sh(s["cell"])
    for gr in d["groups"]:
        for u in gr["units"]:
            u["cell"] = sh(u["cell"])


def main(src, dst):
    d = U.load(src)
    st = build_state(d)
    carve(d, st)
    start = tuple(d["start"][0])
    got = U.components(st, start)
    miss = [t["id"] for t in d["things"] if not U.reached(st, got, t)]
    print("unreached things:", miss)
    if miss:
        return False
    keep_cells = {tuple(t["cell"]) for t in d["things"]}
    for y in range(st["h"]):
        for x in range(st["w"]):
            if st["ter"][y][x] in U.WALK and (x, y) not in got and (x, y) not in st["blocked"] and (x, y) not in keep_cells:
                st["ter"][y][x] = "."
                st["hts"][y][x] = 0
    d["grid"]["props"] = [p for p in d["grid"]["props"] if st["ter"][p["cell"][1]][p["cell"][0]] != "."]
    U.inlets(st, d, start, count=60, seed=5)
    d["grid"]["props"] = [p for p in d["grid"]["props"] if st["ter"][p["cell"][1]][p["cell"][0]] != "."]
    U.landings(st, d)
    crop(d, st)
    U.export(st, d)
    with open(dst, "w") as f:
        json.dump(d, f, indent=1)
        f.write("\n")
    print("wrote", dst, st["w"], "x", st["h"])
    return U.clear_lost(dst) if os.path.basename(dst) == "village_v2.json" else True


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else "game/data/explore/village_v2.json"
    sys.exit(0 if main(src, sys.argv[2] if len(sys.argv) > 2 else src) else 1)
