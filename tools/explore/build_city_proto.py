#!/usr/bin/env python3
"""Builds game/data/explore/city_proto.json: a dense town layout test ([USER] 2026-10-29, after Brandon's
references docs/art/references/city-bustle-*.webp; layout only, the look stays the fall set).

- Two towns: an upper terrace at the back (streets at level 4) and the lower town in front (streets at 1),
  joined by a grand stair and a narrow stair along the terrace wall.
- Houses are masonry blocks two or three levels over the street. Their flat roofs are walkable: stairs
  climb onto some, the terrace steps down onto others, and neighbouring roofs a level apart hop.
- Streets are one or two cells wide, wind and fork, and open into two small squares.
- A house over a lane you walk under is faked with a graybox arch (CombatGrid.under_arch): its pillars stand
  on the houses either side and its top spans the lane. The grid holds one height per cell, so the span
  can't be walked on; a real two-level cell is a question on the studio desk.
- The fall village's houses, stalls and props fill in; anything without art is a graybox.

Run again after editing: python3 tools/explore/build_city_proto.py [--dump]
"""
import json
import os
import sys

W, H = 30, 30
LOW, HIGH = 1, 4  # street levels: the lower town and the upper terrace
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "game", "data", "explore", "city_proto.json")
BLOCKED = "ru."
JUMP, STAIRS_CLIMB = 1, 2  # the lead's jump; CombatGrid.STAIRS_CLIMB

terrain = [["s"] * W for _ in range(H)]
height = [[0] * W for _ in range(H)]
props, things = [], []


def fill(x0, y0, x1, y1, t=None, h=None):
    """Inclusive rect; None keeps what is there."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if t is not None:
                terrain[y][x] = t
            if h is not None:
                height[y][x] = h


def block(x0, y0, x1, y1, lvl):
    """A masonry house (or a run of them) with a flat roof at `lvl`. Roofs take the warm road top and
    streets the pale stone, so a roof reads apart from the street below it."""
    fill(x0, y0, x1, y1, "d", lvl)


def prop(sprite, x, y, foot=(1, 1), tall=0.0, sight=0.0, walk=False, **extra):
    props.append({"sprite": sprite, "cell": [x, y], "foot": list(foot), "tall": tall, "sight": sight,
                  "walk": walk, **extra})


def house(sprite, x, y, fx, fy, door_dx):
    """A fall village house on flat street ground; returns the cell in front of its door (left wall)."""
    lvl = height[y + fy][x + door_dx]
    fill(x, y, x + fx - 1, y + fy - 1, "s", lvl)
    prop(sprite, x, y, (fx, fy), 0.0, 3.0)
    return (x + door_dx, y + fy)


def overpass(x, y, foot, top):
    """A house over the lane, faked: an arch whose pillars are cut into the house walls either side, down at
    street level, and whose top spans the lane flush with the roofs at `top` (graybox until art; ph_
    sprites have none). The span can't be walked on: one height per cell."""
    fx, fy = foot
    ends = [(x, y), (x + fx - 1, y + fy - 1)]
    lvl = min(height[c[1]][c[0]] for c in [(x + dx, y + dy) for dy in range(fy) for dx in range(fx)] if c not in ends)
    for cx, cy in ends:
        terrain[cy][cx] = "s"
        height[cy][cx] = lvl
    prop("ph_overpass", x, y, foot, tall=(top - lvl) / 2.0, sight=2.0, arch=True)


def stair(cells):
    """A flight: [(x, y, level), ...] in climbing order."""
    for x, y, lvl in cells:
        terrain[y][x] = "t"
        height[y][x] = lvl


# --- ground: streets everywhere at their town's level; the houses go on top ------------------------------
fill(0, 0, W - 1, 9, "s", HIGH)  # the upper terrace
fill(0, 10, W - 1, H - 1, "s", LOW)  # the lower town

# --- upper terrace houses (streets at 4; the promenade along its edge, y 8-9, looks down on the lower town)
block(0, 0, 4, 3, HIGH + 2)
block(6, 0, 10, 2, HIGH + 2)
block(6, 3, 8, 7, HIGH + 1)  # a one-floor annex: its roof hops up to the house behind
block(13, 0, 18, 2, HIGH + 3)
block(16, 3, 18, 7, HIGH + 2)
block(20, 0, 23, 2, HIGH + 2)
block(26, 0, 29, 2, HIGH + 2)
block(20, 4, 23, 7, HIGH + 2)

# --- lower town houses (streets at 1) ------------------------------------------------------------------
# Against the terrace wall: tall houses that stand a floor over the promenade, and one low roof the
# promenade steps down onto.
block(0, 10, 1, 18, LOW + 6)  # stairs climb three: houses beside a flight stand four over it
block(4, 10, 9, 13, HIGH - 1)  # the roof off the promenade
block(10, 10, 12, 13, LOW + 6)
block(16, 10, 21, 11, LOW + 6)
block(22, 10, 29, 11, LOW + 4)
# The middle: blocks two or three floors high, one-cell lanes between them, roofs that hop.
block(4, 14, 9, 16, LOW + 3)
block(10, 14, 12, 16, LOW + 4)
block(15, 14, 22, 15, LOW + 3)  # north of the alley
block(15, 17, 22, 17, LOW + 2)  # south of the alley, over the market
block(15, 18, 17, 20, LOW + 2)
block(25, 12, 29, 17, LOW + 4)
block(4, 17, 4, 18, LOW + 2)
block(7, 17, 9, 20, LOW + 3)
block(12, 18, 13, 20, LOW + 3)
# The front: lower houses, so the camera sees into the streets.
block(0, 19, 1, 29, LOW + 2)
block(2, 21, 4, 25, LOW + 3)
block(12, 25, 18, 29, LOW + 2)
block(14, 21, 17, 24, LOW + 3)
block(5, 28, 8, 29, LOW + 2)
block(19, 23, 21, 29, LOW + 3)

# --- stairs ------------------------------------------------------------------------------------------
stair([(13, 11, 2), (14, 11, 2), (15, 11, 2), (13, 10, 3), (14, 10, 3), (15, 10, 3)])  # the grand stair
stair([(2, 10, 2), (3, 10, 3)])  # the narrow stair along the terrace wall
# Up a floor onto a roof: a flight along the house wall, then the roof is a terrace.
stair([(4, 16, 2), (4, 15, 3)])  # from the west lane, along the west wall
stair([(15, 14, 2), (16, 14, 3)])  # from main street, along the back wall
stair([(18, 18, 2)])  # from the market onto the low roofs over it
stair([(4, 26, 2), (4, 25, 3)])  # from the front-left lane

# --- houses over the lanes (faked) -------------------------------------------------------------------
overpass(9, 19, (4, 1), LOW + 3)  # over main street, house to house
overpass(18, 15, (1, 3), LOW + 3)  # over the alley
overpass(22, 14, (4, 1), LOW + 4)  # over the east street

# --- fall village houses and street life --------------------------------------------------------------
doors = []
doors.append(house("b_home_b", 0, 4, 4, 3, 1))  # upper town
doors.append(house("b_home_c", 26, 4, 4, 3, 1))
doors.append(house("b_home_a", 26, 18, 3, 3, 1))  # on the market
doors.append(house("b_tavern", 22, 23, 6, 4, 2))  # down the front-right street
prop("prop_stall", 20, 19, (1, 1), 0.9, 1.0)
prop("prop_stall", 23, 19, (1, 1), 0.9, 1.0)
prop("prop_crates", 19, 21, (1, 1), 0.6, 0.5)
prop("prop_barrel", 24, 21, (1, 1), 0.6, 0.5)
prop("prop_well", 11, 23, (1, 1), 0.8, 0.5)
prop("prop_bench", 7, 24, (1, 1), 0.6, 0.0)
prop("prop_lamp", 13, 21, (1, 1), 1.2, 0.0)
prop("prop_lamp", 16, 12, (1, 1), 1.2, 0.0)
prop("prop_planter", 12, 6, (1, 1), 0.8, 0.5)
prop("prop_tree_3", 14, 4, (1, 1), 1.6, 1.0)
prop("prop_bench", 10, 4, (1, 1), 0.6, 0.0)
prop("prop_lamp", 19, 9, (1, 1), 1.2, 0.0)
prop("prop_cart", 27, 9, (1, 1), 0.8, 0.5)
# Timber houses standing on the stone blocks nobody climbs: a stone floor below, the house above.
prop("b_home_a", 0, 0, (3, 3), 0.0, 3.0)
prop("b_home_b", 13, 0, (4, 3), 0.0, 3.0)
prop("b_home_b", 26, 0, (4, 3), 0.0, 3.0)
prop("b_home_c", 20, 4, (4, 3), 0.0, 3.0)
prop("b_home_a", 10, 10, (3, 3), 0.0, 3.0)
# On the walkable roofs, so they read as lived on.
prop("prop_planter", 6, 11, (1, 1), 0.8, 0.5)
prop("prop_bench", 7, 15, (1, 1), 0.6, 0.0)
prop("prop_crates", 20, 14, (1, 1), 0.6, 0.5)
prop("prop_barrel", 16, 19, (1, 1), 0.6, 0.5)
prop("prop_planter", 3, 22, (1, 1), 0.8, 0.5)
prop("prop_hay", 27, 15, (1, 1), 0.65, 0.5)
prop("prop_crates", 26, 12, (1, 1), 0.6, 0.5)
prop("prop_planter", 24, 10, (1, 1), 0.8, 0.5)
prop("prop_bench", 15, 26, (1, 1), 0.6, 0.0)
prop("prop_planter", 20, 27, (1, 1), 0.8, 0.5)
prop("prop_barrel", 9, 12, (1, 1), 0.6, 0.5)

start = (10, 28)

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


def check():
    r = reach(start)
    if "--dump" in sys.argv:
        dump(r)
    for d in doors:
        assert d in r, "door %s can't be reached" % (d,)
    for name, cell in [("upper square", (12, 5)), ("market", (22, 19)), ("square A", (9, 22)),
                       ("roof off main street", (19, 14)), ("roof off the west lane", (6, 14)),
                       ("roofs over the market", (16, 18)), ("front-left roof", (3, 23)),
                       ("roof off the promenade", (6, 12)), ("under the main street house", (10, 19)),
                       ("under the alley house", (18, 16)), ("under the east street house", (23, 14))]:
        assert cell in r, name + " can't be reached"
    for pr in props:
        if pr["sprite"].startswith("b_"):
            x0, y0 = pr["cell"]
            lv = {height[y0 + dy][x0 + dx] for dy in range(pr["foot"][1]) for dx in range(pr["foot"][0])}
            assert len(lv) == 1, pr["sprite"] + " isn't on flat ground"
    taken = {}
    for pr in props:
        for dy in range(pr["foot"][1]):
            for dx in range(pr["foot"][0]):
                c = (pr["cell"][0] + dx, pr["cell"][1] + dy)
                assert c not in taken, "%s and %s overlap at %s" % (pr["sprite"], taken[c], c)
                taken[c] = pr["sprite"]
    walkable = {(x, y) for y in range(H) for x in range(W) if terrain[y][x] not in BLOCKED} - prop_cells()
    return r, walkable - r


reached, cut_off = check()

data = {
    "name": "city_proto", "art_set": "village", "strangeness": 0.0, "view": 0, "turn": False, "fog": False,
    "grid": {"w": W, "h": H, "terrain": ["".join(r) for r in terrain],
             "heights": ["".join(str(v) for v in r) for r in height], "props": props},
    "start": [list(start)], "groups": [], "things": things,
}
with open(OUT, "w") as f:
    json.dump(data, f, indent=1)
    f.write("\n")
print("wrote", os.path.normpath(OUT), "%dx%d" % (W, H), len(props), "props;", len(reached), "cells walkable from the start,",
      len(cut_off), "roof cells with no way up")
