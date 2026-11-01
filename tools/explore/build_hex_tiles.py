#!/usr/bin/env python3
"""Builds game/data/explore/forest_roads.json and farmland.json: the first two tiles of the hex world map, one step out
from the village ([USER] 2026-11-01, card pm-world-paths). Graybox (props are the village set's), small and friendly: a road
through, one or two foe groups, a container or two, a way back out.

Each is a winding band of land climbing a hillside in terraces: a spine of axis-aligned legs (a staircase of W and N legs),
a road down the middle, a stair flight (stair kit, two levels a flight) in the middle of the legs that rise or fall, clearings
where things happen, void outside the band (the game grows its forest skirt there), so neither map is a box.

Run: python3 tools/explore/build_hex_tiles.py [forest_roads|farmland]  (tools/check.sh runs the QA panel's checks on them)
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from village_kit import *  # noqa: F401,F403
from village_kit import FLIGHTS, _prop_cells  # noqa: F401

DIRS = {"W": (-1, 0), "E": (1, 0), "N": (0, -1), "S": (0, 1)}


def hsh(x, y, k=0):
    return (x * 73 + y * 151 + x * y * 7 + k * 31) % 100


class Spine:
    """Legs of straight road; a leg with dh stands a flight (two cells) in its middle."""

    def __init__(self, start, legs, level=1):
        self.cells = []   # (x, y, level, leg index)
        self.flights = []  # (row cells top-down as [(x, y)], top, axis, across)
        x, y = start
        lvl = level
        self.cells.append((x, y, lvl, 0))
        for li, (d, n, dh) in enumerate(legs):
            dx, dy = DIRS[d]
            mid = n // 2
            for k in range(1, n + 1):
                x, y = x + dx, y + dy
                if dh and k in (mid, mid + 1):
                    first = k == mid
                    hi = max(lvl, lvl + dh)
                    h = (hi - 1 if first else hi) if dh > 0 else (hi if first else hi - 1)
                    self.cells.append((x, y, h, li))
                else:
                    self.cells.append((x, y, lvl + (dh if dh and k > mid + 1 else 0), li))
            lvl += dh
            if dh:
                axis = (1, 0) if dx else (0, 1)
                across = (0, 1) if dx else (1, 0)
                a = [c for c in self.cells if c[3] == li][mid - 1:mid + 1]
                self.flights.append((a, max(lvl - dh, lvl) if dh else lvl, axis, across, dh))
        self.end_level = lvl


def build(name, start, legs, clear, radius=4.3, road_w=1.0, rock_pct=15, rim_pct=40):
    """clear: {spine index: radius} for clearings."""
    sp = Spine(start, legs)
    xs = [c[0] for c in sp.cells]
    ys = [c[1] for c in sp.cells]
    pad = 7
    ox, oy = min(xs) - pad, min(ys) - pad
    W, H = max(xs) - ox + pad + 1, max(ys) - oy + pad + 1
    m = Map(name, W, H, t=".", hgt=0)
    cells = [(x - ox, y - oy, l, li) for x, y, l, li in sp.cells]
    flat = [(i, c) for i, c in enumerate(cells)]
    fl_rows = {(c[0], c[1]) for f in sp.flights for c in [(a[0] - ox, a[1] - oy) for a in f[0]]}
    # land: every cell within the leg's radius of a spine cell; height of the nearest flat spine cell
    land = {}
    for y in range(H):
        for x in range(W):
            best = None
            for i, (cx, cy, lv, li) in flat:
                r = clear.get(i, radius)
                d = math.hypot(x - cx, y - cy)
                if d <= r and ((cx, cy) not in fl_rows):
                    if best is None or d < best[0]:
                        best = (d, lv, i)
                elif d <= r and best is None:
                    pass
            if best:
                land[(x, y)] = (best[1], best[2])
    # clearings need bumpy edges: trim cells by noise on the rim
    # jut-outs: a small lobe off the band every few cells, alternating sides, so the outline winds
    for i in range(3, len(cells) - 2, 5):
        cx, cy, lv, li = cells[i]
        if (cx, cy) in fl_rows or any((cells[j][0], cells[j][1]) in fl_rows for j in range(max(0, i - 2), min(len(cells), i + 3))):
            continue
        leg = legs[li - 1] if li >= 1 else legs[0]
        across = (0, 1) if leg[0] in "WE" else (1, 0)
        sgn = 1 if (i // 5) % 2 else -1
        lx, ly = cx + across[0] * sgn * 3, cy + across[1] * sgn * 3
        for y in range(H):
            for x in range(W):
                if math.hypot(x - lx, y - ly) <= 2.3 and (x, y) not in land:
                    land[(x, y)] = (lv, i)
    for (x, y) in list(land):
        i = land[(x, y)][1]
        r = clear.get(i, radius)
        cx, cy = cells[i][0], cells[i][1]
        d = math.hypot(x - cx, y - cy)
        if d > r - 1.4 and hsh(x, y, 3) < 45 and d > 1.6:
            del land[(x, y)]
    for (x, y), (lv, i) in land.items():
        m.put(x, y, "g", lv)
    spine_set = {(c[0], c[1]) for c in cells}
    for (cx, cy, lv, li) in cells:
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                p = (cx + dx, cy + dy)
                if p in land and math.hypot(dx, dy) <= 1.2 + road_w - 1.0:
                    m.put(p[0], p[1], "d", land[p][0])
    # flights: three wide, rock either side
    for rows, top, axis, across, dh in sp.flights:
        r2 = [(a[0] - ox, a[1] - oy) for a in rows]
        top_down = r2 if dh < 0 else list(reversed(r2))
        band = [[(c[0] + across[0] * o, c[1] + across[1] * o) for o in (-1, 0, 1)] for c in top_down]
        topv = top if dh > 0 else max(cells[[(c[0], c[1]) for c in cells].index(r2[0])][2], 0)
        hi = top if dh > 0 else cells[[(c[0], c[1]) for c in cells].index(r2[0])][2]
        flight(m, band, hi)
        for c in r2:
            for o in (-2, 2):
                p = (c[0] + across[0] * o, c[1] + across[1] * o)
                if 0 <= p[0] < W and 0 <= p[1] < H:
                    m.put(p[0], p[1], "r", hi)
    # rim woods
    for (x, y) in list(land):
        if m.terrain[y][x] != "g":
            continue
        if any(not (0 <= x + dx < W and 0 <= y + dy < H) or m.terrain[y + dy][x + dx] == "." for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            if hsh(x, y, 5) < rim_pct:
                m.put(x, y, "f")
    # rock outcrops: single cells of rock standing in the open ground, off the road, never touching each other
    near_spine = {(c[0] + dx, c[1] + dy) for c in cells for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
    for y in range(1, H - 1):
        for x in range(1, W - 1):
            if m.terrain[y][x] == "g" and (x, y) not in near_spine and hsh(x, y, 21) < rock_pct and \
                    all(m.terrain[y + dy][x + dx] != "r" for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                m.put(x, y, "r")
    # a fringe of woods round the land, two cells deep and ragged: the forest the band is cut from
    for ring, pct in ((1, 70), (2, 22)):
        add = []
        for y in range(H):
            for x in range(W):
                if m.terrain[y][x] != ".":
                    continue
                nb = [(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx or dy) and 0 <= x + dx < W and 0 <= y + dy < H]
                near = [q for q in nb if m.terrain[q[1]][q[0]] in ("g", "d", "f") and (ring == 1 or m.terrain[q[1]][q[0]] == "f")]
                if near and hsh(x, y, 11 + ring) < pct:
                    add.append((x, y, m.height[near[0][1]][near[0][0]]))
        for x, y, h in add:
            m.put(x, y, "f", h)
    return m, cells, sp, (ox, oy)


def scatter(m, cells, keep, trees=("prop_pine_1", "prop_tree_2", "prop_pine_2", "prop_tree_4"), tree_pct=9, rock_pct=2):
    near = set()
    for c in cells:
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                near.add((c[0] + dx, c[1] + dy))
    near |= keep
    blocked = _prop_cells(m)
    n = 0
    for y in range(m.h):
        for x in range(m.w):
            if m.terrain[y][x] != "g" or (x, y) in near or (x, y) in blocked:
                continue
            r = hsh(x, y, 9)
            if r < tree_pct:
                m.prop(trees[(x + y) % len(trees)], x, y, tall=1.6 if "tree" in trees[(x + y) % len(trees)] else 1.25, sight=1.0)
            elif r < tree_pct + rock_pct:
                m.prop("prop_boulder" if (x + y) % 2 else "prop_boulder_2", x, y, tall=0.6, sight=1.0)


def free_block(m, fx, fy, near, avoid, reach=14):
    """The nearest flat block of open grass fx x fy to `near`, off the cells in `avoid`, clear of props and things."""
    taken = set(_prop_cells(m)) | {tuple(t["cell"]) for t in m.things} | avoid
    best = None
    for y in range(max(0, near[1] - reach), min(m.h - fy, near[1] + reach)):
        for x in range(max(0, near[0] - reach), min(m.w - fx, near[0] + reach)):
            cs = [(x + dx, y + dy) for dx in range(fx) for dy in range(fy)]
            ring = [(x + dx, y + dy) for dx in range(-1, fx + 1) for dy in range(-1, fy + 1)]
            if all(0 <= c[0] < m.w and 0 <= c[1] < m.h and m.terrain[c[1]][c[0]] == "g" and c not in taken for c in cs) \
                    and len({m.height[c[1]][c[0]] for c in cs}) == 1 \
                    and all(0 <= c[0] < m.w and 0 <= c[1] < m.h and m.terrain[c[1]][c[0]] not in "t" for c in ring):
                d = abs(x + fx / 2 - near[0]) + abs(y + fy / 2 - near[1])
                if best is None or d < best[0]:
                    best = (d, (x, y))
    return best[1] if best else None


def carve_pad(m, fx, fy, near, level, avoid, reach=10):
    """Level a fx x fy pad of open grass (ring of one cell too) beside `near` at `level`: land is made where there is none,
    but never over stairs, the road or `avoid`; it must touch walkable ground within a level of its own."""
    best = None
    for y in range(max(2, near[1] - reach), min(m.h - fy - 2, near[1] + reach)):
        for x in range(max(2, near[0] - reach), min(m.w - fx - 2, near[0] + reach)):
            ring = [(x + dx, y + dy) for dx in range(-1, fx + 1) for dy in range(-1, fy + 1)]
            if any(m.terrain[c[1]][c[0]] in "tdr" or c in avoid for c in ring):
                continue
            edge = [(x + dx, y + dy) for dx in range(-2, fx + 2) for dy in range(-2, fy + 2) if (x + dx, y + dy) not in ring]
            touch = [c for c in edge if 0 <= c[0] < m.w and 0 <= c[1] < m.h and m.terrain[c[1]][c[0]] in "gd" and abs(m.height[c[1]][c[0]] - level) <= 1]
            if not touch:
                continue
            d = abs(x + fx / 2 - near[0]) + abs(y + fy / 2 - near[1])
            if best is None or d < best[0]:
                best = (d, (x, y))
    if best is None:
        return None
    x, y = best[1]
    for dx in range(-1, fx + 1):
        for dy in range(-1, fy + 1):
            m.put(x + dx, y + dy, "g", level)
    return x, y


def around(c, n=2):
    return {(c[0] + dx, c[1] + dy) for dx in range(-n, n + 1) for dy in range(-n, n + 1)}


def finish(m, groups, level=1):
    """Cells nobody can reach grow woods (the village builder's rule), then the map is written with its foes."""
    check_village(m, wood_lost=True)
    m.save()
    path = os.path.normpath(os.path.join(OUT_DIR, m.name + ".json"))
    d = json.load(open(path))
    d["groups"] = groups
    d["level"] = level
    with open(path, "w") as f:
        json.dump(d, f, indent=1)
        f.write("\n")


def forest_roads():
    legs = [("W", 7, 2), ("N", 6, 2), ("W", 7, -2), ("N", 6, 2), ("W", 7, -2), ("N", 6, 2), ("W", 7, 2), ("N", 6, 2), ("W", 7, -2)]
    start = (50, 40)
    clear = {}
    sp0 = Spine(start, legs)
    ends = [i for i in range(1, len(sp0.cells)) if sp0.cells[i][3] != sp0.cells[i - 1][3]]
    for j, i in enumerate(ends):
        clear[i] = 5.4
    clear[len(sp0.cells) - 1] = 5.4
    clear[0] = 5.4
    m, cells, sp, off = build("forest_roads", start, legs, clear)
    sx, sy = cells[0][0], cells[0][1]
    ex, ey = cells[-1][0], cells[-1][1]
    ce = [cells[i] for i in ends]  # leg corners: clearings
    keep = set()
    m.start = [[sx - 2, sy]]
    things = []

    def thing(**t):
        m.thing(**t)
        keep.update(around(t["cell"], 1))

    thing(id="exit_home", kind="exit", event="exit", cell=[sx, sy])
    thing(id="exit_far", kind="exit", event="exit", cell=[ex, ey])
    c2, c4, c6, c8 = ce[1], ce[3], ce[5], ce[7]
    thing(id="forest_cache", kind="cache", event="forest_cache", cell=[c2[0] + 1, c2[1] + 1], once="got_forest_cache")
    # beside the road, not in the middle of it ([USER] 2026-11-01 X8: "a random barrel here in the middle of the road")
    thing(id="forest_stash", kind="cache", event="forest_stash", cell=[c6[0] - 1, c6[1] - 2], once="got_forest_stash")
    groups = [
        {"id": "forest_bandits", "event": "spot_people", "sight": 5, "loot": "food:+3;gold:+6",
         "units": [{"id": "bandit", "cell": [c4[0] - 1, c4[1] - 1]}, {"id": "bandit_archer", "cell": [c4[0] + 2, c4[1] - 2], "leader": True}]},
        {"id": "forest_wolves", "event": "spot_beasts", "sight": 4, "loot": "food:+4",
         "units": [{"id": "wolf", "cell": [c8[0] - 2, c8[1]]}, {"id": "wolf", "cell": [c8[0], c8[1] + 2]}]},
        # Bushberry's captors (design-bb-recruit). [USER] 2026-11-01: Bushberry fights beside the ogre with his rank 1 kit
        # ("char": a companion on the foes' side), then lies fallen where he stood and is helped up (rescue_bushberry).
        # Both stand in the open on the road (pm-occlusion: the hidden-spots QA check). The road loops back past this
        # clearing, so the party can back out down it or go round by the woods.
        {"id": "forest_ogre", "event": "spot_people", "sight": 4, "elite": True, "loot": "gold:+10;unlock:bushberry_down",
         "units": [{"id": "ogre", "cell": [c6[0] + 2, c6[1] - 1]}, {"id": "bushberry", "char": "bushberry", "cell": [c6[0] + 1, c6[1]]}]},
    ]
    thing(id="captive_bushberry", kind="companion", event="rescue_bushberry", cell=[c6[0] + 1, c6[1]], once="rescued_bushberry",
          when="bushberry_down", fallen=True)
    for g in groups:
        for u in g["units"]:
            keep.add(tuple(u["cell"]))
    scatter(m, cells, keep)
    finish(m, groups)


def farmland():
    """Flat open fields ([USER] 2026-11-01): gentle one-level rises, a path with a fence line along it that the party
    can walk away from, a barn and a windmill, and in the north-east corner a tiny path through dense woods to a rocky
    outcrop with a lit bonfire where Amber sleeps (events amber_fire, companion_fire_mage)."""
    W, H = 60, 38
    m = Map("farmland", W, H, t=".", hgt=0)

    def yc(x):
        return 20 + 3.2 * math.sin(x / 8.5)

    bounds = (8, 15, 22, 29, 36, 43)  # seven plateaus, two levels apart, with a stair flight or two at each rise

    def lvl(x, y):
        return 2 * sum(1 for b_ in bounds if x >= b_)

    land = set()
    for x in range(3, W - 3):
        hh = 4.8 + 4.0 * math.sin(x / 3.7 + 1) + 2.2 * math.sin(x / 1.9) + hsh(x, 0) % 2
        hh = min(max(hh, 5.0), 3.0 + (x - 3) * 0.8, 3.0 + (W - 4 - x) * 0.8)
        for y in range(H):
            if abs(y - yc(x)) <= hh:
                land.add((x, y))
    # the outcrop corner: a lobe in the north-east, cut off from the fields by woods
    ox, oy = W - 11, 7
    lobe = {(x, y) for y in range(H) for x in range(W) if math.hypot(x - ox, y - oy) <= 4.6}
    land |= lobe
    for (x, y) in land:
        m.put(x, y, "g", lvl(x, y))
    # the path along the field's middle, two cells wide in places
    path = []
    for x in range(3, W - 3):
        y = round(yc(x))
        path.append((x, y))
        for yy in ((y, y + 1) if (x // 6) % 2 else (y,)):
            if (x, yy) in land:
                m.put(x, yy, "d", m.height[yy][x])
    # woods round the outcrop: a dense belt between the lobe and the fields, a one-cell path winding through it
    belt = {(x, y) for y in range(H) for x in range(W)
            if 4.6 < math.hypot(x - ox, y - oy) <= 9.5 and (x, y) in land and y < yc(x) - 3}
    for (x, y) in belt:
        m.put(x, y, "f", m.height[y][x])
    tp = []
    px, py = ox - 1, oy + 5
    tp.append((px, py))
    while py < round(yc(px)) - 3:
        py += 1
        tp.append((px, py))
        if py % 3 == 0:
            px += 1 if (py // 3) % 2 else -1
            tp.append((px, py))
    for (x, y) in tp:
        m.put(x, y, "d", m.height[y][x])
    py2 = tp[-1][1]
    while m.terrain[py2 + 1][tp[-1][0]] != "d" and py2 < H - 3:
        py2 += 1
        tp.append((tp[-1][0], py2))
        m.put(tp[-1][0], py2, "d", m.height[py2][tp[-1][0]])
    join = (tp[-1][0], tp[-1][1] + 1)
    top = m.height[join[1]][join[0]]  # the whole tiny path and the outcrop stand level with the field where it joins
    for (x, y) in tp:
        m.put(x, y, "d", top)
    for (x, y) in lobe:
        m.put(x, y, "g", top)
    # the outcrop: ringed with rock, open on the south where the path comes in
    for (x, y) in lobe:
        d = math.hypot(x - ox, y - oy)
        if d > 3.4 and not (y > oy and abs(x - (ox - 1)) <= 1):
            m.put(x, y, "r", top)
    for dy in range(1, 5):
        m.put(ox - 1, oy + dy, "d", top)
    flown_ = {}
    # the rises: a flight (two columns, three wide, rock either side) at the path and one more at each rise
    nfl = 0
    for b_ in bounds:
        done_ = 0
        for y0 in sorted(range(4, H - 4), key=lambda v: abs(v - yc(b_))):
            if done_ == 3:
                break
            cols = (b_, b_ - 1)
            if all(c2 in (b_, b_ - 1, b_ - 2, b_ + 1) for c2 in cols) and all(0 <= y0 + dy < H and (c, y0 + dy) in land and m.terrain[y0 + dy][c] in "gd" for c in cols for dy in (-1, 0, 1)) \
                    and not any(abs(y0 - q) < 5 for q in flown_.get(b_, [])):
                band = [[(c, y0 + dy) for dy in (-1, 0, 1)] for c in cols]
                flight(m, band, 2 * (sum(1 for b2 in bounds if b2 <= b_)))
                for c in cols:
                    for dy in (-2, 2):
                        if (c, y0 + dy) in land and m.terrain[y0 + dy][c] == "g":
                            m.put(c, y0 + dy, "r", m.height[y0 + dy][c])
                flown_.setdefault(b_, []).append(y0)
                done_ += 1
                nfl += 1
    # rim woods and a ragged forest fringe round the fields
    for (x, y) in list(land):
        if m.terrain[y][x] == "g" and any(not (0 <= x + dx < W and 0 <= y + dy < H) or m.terrain[y + dy][x + dx] == "." for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) and hsh(x, y, 5) < 22:
            m.put(x, y, "f")
    for ring, pct in ((1, 60), (2, 20)):
        add = []
        for y in range(H):
            for x in range(W):
                if m.terrain[y][x] != ".":
                    continue
                near = [(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx or dy) and 0 <= x + dx < W and 0 <= y + dy < H
                        and m.terrain[y + dy][x + dx] in ("g", "d", "f") and (ring == 1 or m.terrain[y + dy][x + dx] == "f")]
                if near and hsh(x, y, 11 + ring) < pct:
                    add.append((x, y, m.height[near[0][1]][near[0][0]]))
        for x, y, h in add:
            m.put(x, y, "f", h)
    # things and props
    sx, sy = path[0]
    ex, ey = path[-1]
    m.start = [[sx + 2, sy]]
    keep = set(path) | set(tp)
    things = []
    far = path[-3]

    def thing(**t):
        m.thing(**t)
        keep.update(around(t["cell"], 1))

    thing(id="exit_home", kind="exit", event="exit", cell=[sx, sy])
    thing(id="exit_far", kind="exit", event="exit", cell=[ex, ey])
    # the fence line: a post every cell on the north side of the path with gaps, walked round or through the gaps
    fence = []
    for (x, y) in path[4:-4]:
        c = (x, y - 3)
        if (x // 7) % 3 != 2 and m.terrain[c[1]][c[0]] == "g" and c not in keep:
            m.prop("prop_fence", c[0], c[1], tall=0.5, sight=0.0)
            fence.append(c)
    keep.update(fence)
    mid = path[len(path) // 2]
    barn = carve_pad(m, 4, 3, (18, round(yc(18)) + 7), lvl(18, 0), keep | around(mid, 3), reach=12)
    m.prop("b_home_c", barn[0], barn[1], (4, 3), tall=0.0, sight=3.0)
    keep.update({(barn[0] + dx, barn[1] + dy) for dx in range(-1, 5) for dy in range(-1, 4)})
    wind = carve_pad(m, 4, 4, (32, round(yc(32)) + 7), lvl(32, 0), keep | around(mid, 3), reach=12)
    m.prop("prop_windmill", wind[0], wind[1], (4, 4), tall=7.0, sight=6.0)
    keep.update({(wind[0] + dx, wind[1] + dy) for dx in range(-1, 5) for dy in range(-1, 5)})
    cc = next(c for c in ((barn[0] + 1, barn[1] + 4), (barn[0] + 1, barn[1] - 2), (barn[0] + 5, barn[1] + 1), (barn[0] - 2, barn[1] + 1)) if 0 <= c[0] < W and 0 <= c[1] < H and m.terrain[c[1]][c[0]] == "g")
    thing(id="farm_cache", kind="cache", event="farm_cache", cell=list(cc), once="got_farm_cache")
    thing(id="farm_stash", kind="cache", event="farm_stash", cell=[wind[0] - 1, wind[1] + 4], once="got_farm_stash")  # in the open (pm-occlusion hidden-spots check, 2026-11-01)
    bc = path[len(path) * 2 // 3]
    groups = [
        {"id": "farm_bandits", "event": "spot_people", "sight": 5, "loot": "food:+3;gold:+6",
         "units": [{"id": "bandit", "cell": [bc[0] + 1, bc[1] - 2]}, {"id": "bandit_archer", "cell": [bc[0] + 4, bc[1] - 3], "leader": True}]},
    ]
    for g in groups:
        for u in g["units"]:
            keep.add(tuple(u["cell"]))
    # the bonfire (a brazier, graybox), Amber asleep on the far side, a log beside her
    fire = (ox, oy)
    m.prop("prop_brazier", fire[0], fire[1], tall=0.9, sight=0.0)
    thing(id="amber_fire", kind="cache", event="amber_fire", cell=[fire[0] - 1, fire[1]])
    thing(id="amber_log", kind="companion", event="companion_fire_mage", cell=[fire[0] + 1, fire[1] + 1], once="met_fire_mage")
    m.prop("prop_bench", fire[0] + 2, fire[1] + 1, tall=0.5, sight=0.0)
    keep.update(around(fire, 3))
    taken_p = set(_prop_cells(m))
    # ponds in the fields and rock clusters: open water and stone, so the open ground has a ragged edge of its own
    pond_keep = set(keep)
    for (px_, py_, pr) in ((14, 12, 3.5), (22, 28, 3.7), (38, 28, 3.3), (30, 11, 3.1), (46, 28, 3.1), (6, 27, 2.7), (52, 15, 2.9), (22, 11, 3.3), (44, 22, 2.7), (34, 14, 2.9), (28, 32, 3.2)):
        for y in range(H):
            for x in range(W):
                c = (x, y)
                if math.hypot(x - px_, y - py_) <= pr and m.terrain[y][x] == "g" and (x, y) not in taken_p and not any(abs(x - q[0]) <= 1 and abs(y - q[1]) <= 1 for q in pond_keep):
                    m.put(x, y, "w", m.height[y][x])
    # hay by the barn and crop strips on flat open grass
    for dx, dy in ((5, 1), (-2, 4), (5, -3), (-2, -2)):
        hc = (barn[0] + dx, barn[1] + dy)
        if 0 <= hc[0] < W and 0 <= hc[1] < H and m.terrain[hc[1]][hc[0]] == "g" and hc not in _prop_cells(m) and hc not in keep:
            m.prop("prop_hay", hc[0], hc[1], tall=0.65, sight=0.5)
    taken = _prop_cells(m)
    for y in range(1, H - 4):
        for x in range(1, W - 1):
            if x % 3 != 0:
                continue
            cs = [(x, y + k) for k in range(3)]
            if all(m.terrain[c[1]][c[0]] == "g" and c not in keep and c not in taken and all((c[0] + a, c[1] + b) not in keep for a in (-1, 0, 1) for b in (-1, 0, 1)) for c in cs) \
                    and len({m.height[c[1]][c[0]] for c in cs}) == 1:
                m.prop("prop_crops", x, y, (1, 3), tall=0.7, sight=0.0)
                taken = _prop_cells(m)
    scatter(m, path, keep | set(_prop_cells(m)), tree_pct=3, rock_pct=1)
    finish(m, groups)


if __name__ == "__main__":
    which = sys.argv[1:] or ["forest_roads", "farmland"]
    for w in which:
        {"forest_roads": forest_roads, "farmland": farmland}[w]()
