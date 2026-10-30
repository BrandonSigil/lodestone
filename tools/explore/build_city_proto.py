#!/usr/bin/env python3
"""Builds game/data/explore/city_proto.json: a dense town layout test ([USER] 2026-10-29, after Brandon's
references docs/art/references/city-bustle-*.webp; layout only, the look stays the fall set).

Pass 2, after Brandon's review (desk card builder-city-proto-review): a much bigger map, gray boxes for the
other buildings, lanes two cells wide at least, walkable roofs a full storey higher, and a grand stair four
levels high and three flights wide that climbs the right way (MapDress.stair_run).

- Two towns: an upper terrace at the back (streets at 5) over the lower town (streets at 1), joined by the
  grand stair and two narrow stairs along the terrace wall.
- Streets are laid out as rects; the lots between them are cut into parcels. A parcel becomes a fall village
  house (when its door opens onto a street) or a gray box building (no art: CombatBoard draws a graybox).
  A few lots are walkable roof blocks level with the terrace, reached by flights of three steps.
- A house over a lane you walk under is faked with a graybox arch (CombatGrid.under_arch) whose span sits
  flush with the roofs; the real two-level cell is engine work Brandon approved (builder-city-overpass).

Run again after editing: python3 tools/explore/build_city_proto.py [--dump]
"""
import json
import os
import random
import sys

W, H = 44, 44
LOW, HIGH = 1, 5  # street levels: the lower town and the upper terrace (four levels apart)
ROOF = HIGH  # walkable roofs stand level with the terrace, a full storey over the lower street
TERRACE = 13  # last row of the upper terrace
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "game", "data", "explore", "city_proto.json")
BLOCKED = "ru."
JUMP, STAIRS_CLIMB = 1, 2  # the lead's jump; CombatGrid.STAIRS_CLIMB
rng = random.Random(7)

terrain = [["s"] * W for _ in range(H)]
height = [[HIGH if y <= TERRACE else LOW] * W for y in range(H)]
props, things = [], []
street = set()
reserved = set()  # lot cells kept out of the parcels (stair flights, roof blocks, overpass pillars)


def lay(x0, y0, x1, y1):
    """A street, square or lane (inclusive rect)."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            street.add((x, y))


def prop(sprite, x, y, foot=(1, 1), tall=0.0, sight=0.0, walk=False, **extra):
    props.append({"sprite": sprite, "cell": [x, y], "foot": list(foot), "tall": tall, "sight": sight,
                  "walk": walk, **extra})


def stair(cells):
    """A flight: [(x, y, level), ...]. Its cells leave the lot."""
    for x, y, lvl in cells:
        terrain[y][x] = "t"
        height[y][x] = lvl
        reserved.add((x, y))


def overpass(x, y, foot, top):
    """A house over the lane, faked: an arch whose pillars are cut into the buildings either side, down at
    street level, and whose span sits flush with the roofs at `top` (graybox until art)."""
    fx, fy = foot
    ends = [(x, y), (x + fx - 1, y + fy - 1)]
    lvl = min(height[cy][cx] for cy in range(y, y + fy) for cx in range(x, x + fx) if (cx, cy) not in ends)
    for cx, cy in ends:
        terrain[cy][cx] = "s"
        height[cy][cx] = lvl
        reserved.add((cx, cy))
    prop("ph_overpass", x, y, foot, tall=(top - lvl) / 2.0, sight=2.0, arch=True)


# --- streets ---------------------------------------------------------------------------------------------
# Upper terrace (level 5): the promenade along its edge, lanes to the back, a square.
lay(0, 10, W - 1, TERRACE)
lay(6, 0, 7, 9)
lay(16, 0, 17, 9)
lay(18, 3, 29, 9)  # the upper square
lay(34, 0, 35, 9)
# Lower town (level 1).
lay(16, 17, 26, 19)  # the foot of the grand stair
lay(26, 17, 33, 19)  # on east
lay(20, 20, 21, 29)  # main street
lay(3, 14, 4, H - 1)  # the west lane, from the wall stair to the front
lay(5, 14, 5, 16)  # three wide beside the wall stair, so the flight leaves two
lay(5, 22, 19, 23)  # a cross lane
lay(8, 30, 21, 36)  # square A
lay(14, 37, 15, H - 1)  # out the front
lay(5, 39, 13, 40)  # the front-left lane
lay(22, 22, 31, 23)  # the alley (two wide)
lay(32, 20, 33, 27)  # the east street
lay(24, 28, 39, 33)  # square B, the market
lay(39, 14, 40, 27)  # the east lane, from the east wall stair
lay(38, 14, 38, 16)
lay(34, 21, 38, 22)  # a link from the east street to the east lane
lay(30, 34, 31, H - 1)  # out the front, right
lay(16, 40, 29, 41)  # the front lane
lay(32, 40, W - 1, 41)

# --- stairs (each climbs four levels in three steps) -------------------------------------------------------
stair([(x, y, lvl) for x in (20, 21, 22) for y, lvl in ((14, 4), (15, 3), (16, 2))])  # the grand stair
stair([(3, 16, 2), (3, 15, 3), (3, 14, 4)])  # along the terrace wall, west
stair([(40, 16, 2), (40, 15, 3), (40, 14, 4)])  # along the terrace wall, east
# Up a floor onto the roofs: two-wide flights out of a street, into the roof block.
stair([(x, y, lvl) for x in (6, 7) for y, lvl in ((21, 2), (20, 3), (19, 4))])  # off the cross lane
stair([(x, y, lvl) for x in (28, 29) for y, lvl in ((27, 2), (26, 3), (25, 4))])  # off the market
stair([(x, y, lvl) for y in (25, 26) for x, lvl in ((38, 2), (37, 3), (36, 4))])  # off the east lane

# --- walkable roof blocks (level with the terrace) ---------------------------------------------------------
ROOFS = [(5, 17, 15, 21), (22, 24, 31, 27), (34, 23, 38, 27), (22, 20, 31, 21)]
for x0, y0, x1, y1 in ROOFS:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if (x, y) not in street and (x, y) not in reserved:
                terrain[y][x] = "d"  # roofs take the warm road top, streets the pale stone
                height[y][x] = ROOF
                reserved.add((x, y))

# --- houses over lanes (faked) ---------------------------------------------------------------------------
overpass(26, 21, (1, 4), ROOF)  # over the alley
overpass(31, 25, (4, 1), ROOF)  # over the east street
overpass(19, 25, (4, 1), ROOF)  # over main street (approved)


# --- the lots: everything else, cut into parcels ----------------------------------------------------------
def rects(cells):
    """Greedy cover of a cell set by rects, row-major."""
    left, out = set(cells), []
    for y in range(H):
        for x in range(W):
            if (x, y) not in left:
                continue
            x1 = x
            while (x1 + 1, y) in left:
                x1 += 1
            y1 = y
            while all((cx, y1 + 1) in left for cx in range(x, x1 + 1)):
                y1 += 1
            for cy in range(y, y1 + 1):
                for cx in range(x, x1 + 1):
                    left.discard((cx, cy))
            out.append((x, y, x1, y1))
    return out


def parcels(r):
    """Guillotine a rect into parcels two to six cells a side."""
    x0, y0, x1, y1 = r
    w, h = x1 - x0 + 1, y1 - y0 + 1
    if w > 6 or (w > 4 and rng.random() < 0.3 and w >= h):
        cut = x0 + rng.randint(2, w - 3) if w >= 5 else x0 + w // 2
        return parcels((x0, y0, cut, y1)) + parcels((cut + 1, y0, x1, y1))
    if h > 6 or (h > 4 and rng.random() < 0.3):
        cut = y0 + rng.randint(2, h - 3) if h >= 5 else y0 + h // 2
        return parcels((x0, y0, x1, cut)) + parcels((x0, cut + 1, x1, y1))
    return [r]


HOUSES = {(3, 3): ["b_home_a"], (4, 3): ["b_home_b", "b_home_c"], (3, 4): ["b_smithy"], (6, 4): ["b_tavern"]}
DOOR_DX = {"b_home_a": 1, "b_home_b": 1, "b_home_c": 1, "b_smithy": 0, "b_tavern": 2}
doors = []
lots = {(x, y) for y in range(H) for x in range(W)} - street - reserved
for r in rects(lots):
    for x0, y0, x1, y1 in parcels(r):
        w, h = x1 - x0 + 1, y1 - y0 + 1
        # A house along the street side (its door faces +y), a gray box behind it if the parcel runs deeper.
        fh = 4 if (w, h) == (6, 4) else 3
        names = HOUSES.get((w, fh), []) if h >= fh else []
        if names and rng.random() < 0.8:
            name = rng.choice(names)
            door = (x0 + DOOR_DX[name], y1 + 1)
            if door in street:
                prop(name, x0, y1 - fh + 1, (w, fh), 0.0, 3.0)
                doors.append(door)
                if h > fh:
                    prop("ph_building", x0, y0, (w, h - fh), rng.choice([2.0, 2.5, 3.0]), 3.0)
                continue
        tall = rng.choice([1.5, 2.0, 2.0, 2.5, 3.0]) if y0 > TERRACE else rng.choice([1.5, 2.0, 2.5])
        prop("ph_building", x0, y0, (w, h), tall, 3.0)

# --- street life -----------------------------------------------------------------------------------------
LIFE = [
    ("prop_well", 14, 33, 0.8, 0.5), ("prop_tree_3", 10, 31, 1.6, 1.0), ("prop_bench", 11, 35, 0.6, 0.0),
    ("prop_lamp", 18, 31, 1.2, 0.0), ("prop_stall", 17, 34, 0.9, 1.0), ("prop_crates", 19, 35, 0.6, 0.5),
    ("prop_stall", 26, 30, 0.9, 1.0), ("prop_stall", 30, 30, 0.9, 1.0), ("prop_stall", 34, 30, 0.9, 1.0),
    ("prop_barrel", 37, 29, 0.6, 0.5), ("prop_crates", 25, 32, 0.6, 0.5), ("prop_cart", 36, 32, 0.8, 0.5),
    ("prop_lamp", 24, 18, 1.2, 0.0), ("prop_lamp", 17, 18, 1.2, 0.0),
    ("prop_tree_2", 23, 5, 1.6, 1.0), ("prop_well", 26, 6, 0.8, 0.5), ("prop_bench", 20, 7, 0.6, 0.0),
    ("prop_lamp", 12, 11, 1.2, 0.0), ("prop_lamp", 30, 11, 1.2, 0.0), ("prop_planter", 9, 12, 0.8, 0.5),
    ("prop_planter", 33, 12, 0.8, 0.5), ("prop_bench", 40, 11, 0.6, 0.0),
    # on the roofs
    ("prop_planter", 9, 18, 0.8, 0.5), ("prop_bench", 12, 19, 0.6, 0.0), ("prop_crates", 24, 26, 0.6, 0.5),
    ("prop_planter", 30, 24, 0.8, 0.5), ("prop_hay", 35, 24, 0.65, 0.5),
]
taken = {}
for pr in props:
    for dy in range(pr["foot"][1]):
        for dx in range(pr["foot"][0]):
            taken[(pr["cell"][0] + dx, pr["cell"][1] + dy)] = pr["sprite"]
for sprite, x, y, tall, sight in LIFE:
    if (x, y) in taken or terrain[y][x] == "t" or (x, y) in doors:
        print("skipped", sprite, "at", (x, y), "on", taken.get((x, y), terrain[y][x]))
        continue
    prop(sprite, x, y, (1, 1), tall, sight)

start = (14, 42)


# --- checks ------------------------------------------------------------------------------------------
def inb(x, y):
    return 0 <= x < W and 0 <= y < H


def prop_cells():
    cells = set()
    for pr in props:
        fx, fy = pr["foot"]
        for dy in range(fy):
            for dx in range(fx):
                gap = pr.get("arch") and (0 < dy < fy - 1 if fy > fx else 0 < dx < fx - 1)
                if not gap and not pr["walk"]:
                    cells.add((pr["cell"][0] + dx, pr["cell"][1] + dy))
    return cells


def walk(a, b):
    limit = JUMP + (STAIRS_CLIMB if "t" in (terrain[a[1]][a[0]], terrain[b[1]][b[0]]) else 0)
    return abs(height[a[1]][a[0]] - height[b[1]][b[0]]) <= limit


def reach(frm):
    blocked = prop_cells()
    seen, todo = {frm}, [frm]
    while todo:
        c = todo.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (c[0] + dx, c[1] + dy)
            if inb(*n) and n not in seen and n not in blocked and terrain[n[1]][n[0]] not in BLOCKED and walk(c, n):
                seen.add(n)
                todo.append(n)
    return seen


def dump(r):
    pc = prop_cells()
    for y in range(H):
        row = ""
        for x in range(W):
            if (x, y) == start:
                row += " @"
            elif (x, y) in pc:
                row += " #"
            elif terrain[y][x] == "t":
                row += "/" + str(height[y][x])
            else:
                row += (" " if (x, y) in r else "x") + str(height[y][x])
        print("%2d %s" % (y, row))
    print("   " + "".join("%2d" % (x % 100) for x in range(W)))


def _cells(pr):
    return {(pr["cell"][0] + dx, pr["cell"][1] + dy) for dy in range(pr["foot"][1]) for dx in range(pr["foot"][0])}


def narrow():
    """Street cells pinched to one cell across (Brandon: two cells wide at least). Flights don't count, and
    street furniture (one-cell props) doesn't either."""
    pc = {c for pr in props if pr["foot"] != [1, 1] for c in _cells(pr)} & prop_cells()
    is_open = lambda c: c in street and c not in pc and terrain[c[1]][c[0]] != "t"
    bad = []
    for (x, y) in sorted(street):
        if not is_open((x, y)):
            continue
        if not is_open((x - 1, y)) and not is_open((x + 1, y)):
            bad.append((x, y))
        elif not is_open((x, y - 1)) and not is_open((x, y + 1)):
            bad.append((x, y))
    return bad


def check():
    r = reach(start)
    if "--dump" in sys.argv:
        dump(r)
    for d in doors:
        assert d in r, "door %s can't be reached" % (d,)
    for name, cell in [("upper square", (24, 6)), ("market", (31, 31)), ("square A", (12, 33)),
                       ("roof off the cross lane", (10, 17)), ("roof off the market", (25, 25)),
                       ("roof off the east lane", (35, 26)), ("terrace by the grand stair", (21, 12)),
                       ("under the main street house", (20, 25)), ("under the alley house", (26, 22)),
                       ("under the east street house", (32, 25)), ("the west wall stair top", (3, 13)),
                       ("the east wall stair top", (40, 13))]:
        assert cell in r, name + " can't be reached"
    seen = {}
    for pr in props:
        for dy in range(pr["foot"][1]):
            for dx in range(pr["foot"][0]):
                c = (pr["cell"][0] + dx, pr["cell"][1] + dy)
                assert c not in seen, "%s and %s overlap at %s" % (pr["sprite"], seen[c], c)
                seen[c] = pr["sprite"]
        if pr["sprite"].startswith(("b_", "ph_building")):
            x0, y0 = pr["cell"]
            lv = {height[y0 + dy][x0 + dx] for dy in range(pr["foot"][1]) for dx in range(pr["foot"][0])}
            assert len(lv) == 1, pr["sprite"] + " isn't on flat ground"
    bad = narrow()
    if bad:
        print("one cell wide at", bad)
    return r


reached = check()
data = {
    "name": "city_proto", "art_set": "village", "strangeness": 0.0, "view": 0, "turn": False, "fog": False,
    "grid": {"w": W, "h": H, "terrain": ["".join(r) for r in terrain],
             "heights": ["".join(str(v) for v in r) for r in height], "props": props},
    "start": [list(start)], "groups": [], "things": things,
}
with open(OUT, "w") as f:
    json.dump(data, f, indent=1)
    f.write("\n")
print("wrote", os.path.normpath(OUT), "%dx%d" % (W, H), len(props), "props (%d houses, %d gray boxes);" % (
    len(doors), sum(p["sprite"] == "ph_building" for p in props)), len(reached), "cells walkable from the start")
