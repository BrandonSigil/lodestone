#!/usr/bin/env python3
"""Builds game/data/explore/village_v2.json: a second village build, its own level on the launch menu ([USER]
2026-10-30, after docs/art/references/village-v2-layout.webp; layout only, the look stays the fall set).

Pass 2 after Brandon's review ("so flat and square... I want a lot more verticality... much more dynamically
shaped"): every district is an organic blob (noisy outline, no rectangles) at its own height, with cliffs several
levels tall between them, so the town climbs from the lake to the ruins:

  22 the ruins and the cemetery on their cliff top (screen top left), the town hall's crag (top right)
  6  the square's plateau with the smithy (the middle, room to breathe), the ruins' foot over the gorge
  5  the farm's shelf with the windmill (left)
  4  the tavern's shelf under the square
  3  the south town (the hero's cottage) and the east homes
  2  the meadow at the front, the gate road
  1  the lake shore;  0  the lake with its dock (bottom left)

The stream runs down a gorge between the ruins and the square; its floor drops 6, 4, 2, 0, so it falls at each
step into the lake. Roads wind between the districts and a stair flight is cut wherever one meets a cliff
(road()). A stone bridge crosses the gorge high up, a wooden footbridge lower down (decks, docs/systems/decks.md).
Afterwards tools/dress_explore.gd runs the game's own authoring rules (V9 tidy edges, V10 pillars).

Its doors and gate stay shut (door_stuck): nothing leads from it into the game. Graybox (ph_) for art we don't
have: graves, the crypt gate, the windmill, the boathouse, a boat, crop rows, reeds. Companions' home spots are
data only (`companion_spots`).

Run again after editing: python3 tools/explore/build_village_v2.py [--dump]
"""
import json
import math
import os
import shutil
import subprocess
import sys

from village_kit import *  # noqa: F401,F403 (Map, shapes, check_village)
from village_kit import FLIGHTS, _prop_cells  # noqa: F401

W = H = 56
V = Map("village_v2", W, H)
V.fill(0, 0, W - 1, H - 1, ".", 0)
DECKS = {}  # (x, y) -> deck height (CombatGrid.decks)
SPOTS = []  # companions' home spots: {"district", "cell"}
KEEP_OPEN = set()  # cells the scattered trees leave alone (roads, yards, things...)


def blob(cx, cy, rx, ry, seed, wob=0.22):
    """The cells inside a noisy ellipse: an organic outline, never a rectangle."""
    out = []
    for y in range(H):
        for x in range(W):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            a = math.atan2(dy, dx)
            lim = 1.0 + wob * (0.55 * math.sin(3 * a + seed) + 0.3 * math.sin(5 * a + 2.1 * seed) + 0.15 * math.sin(9 * a + seed * 0.7))
            if math.hypot(dx, dy) < lim:
                out.append((x, y))
    return out


def raise_to(cells, h, t="g"):
    for x, y in cells:
        if V.terrain[y][x] != ".":
            V.put(x, y, t, h)


# --- the island and its districts (lowest first; each higher one is laid over) -----------------------------
ISLAND = blob(27.5, 27.5, 29.5, 29.5, 1.3, 0.09)
SHORE = blob(13, 47, 13, 10, 2.2, 0.2)
LAKE = blob(12.5, 51, 8.5, 5, 4.1, 0.18)
SOUTH = blob(31, 45, 9, 6, 0.4)  # the hero's cottage and the gate road
EAST = blob(49, 35, 7, 10, 3.3)  # the east homes
TAVERN = blob(39, 33, 9, 6, 5.0)
FARM = blob(7, 34, 7.5, 7, 2.7)
PLATEAU = blob(30, 21, 11, 9.5, 0.9, 0.16) + blob(43, 15, 7.5, 7.5, 1.8)  # the square and the smithy
FOOT = blob(8, 25, 7, 4.5, 3.9)  # the ruins' foot, where the stone bridge lands
RUINS = blob(7, 13, 7.5, 10, 4.6)
HALL = blob(29, 5.5, 9, 5.5, 2.4)
inside = set(ISLAND)
RIM = [c for c in ISLAND if any((c[0] + dx, c[1] + dy) not in inside for dx in (-1, 0, 1) for dy in (-1, 0, 1))]
DISTRICTS = [(SHORE, 2), (SOUTH, 9), (EAST, 9), (TAVERN, 13), (FARM, 13), (PLATEAU, 18), (FOOT, 18), (RUINS, 24), (HALL, 24)]
TERRACE = 3  # the ground between districts steps down in terraces this many levels apart


def spread(cells):
    """Steps from the nearest of cells, over the island."""
    dist = {c: 0 for c in cells if c in inside}
    todo = list(dist)
    while todo:
        nxt = []
        for x, y in todo:
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if n in inside and n not in dist:
                    dist[n] = dist[(x, y)] + 1
                    nxt.append(n)
        todo = nxt
    return dist


# The districts stand at their own levels; the ground between follows the districts round it, weighted by
# nearness, falls toward the island's rim, and is cut into terraces: a stack of shelves and cliffs, not a meadow.
fields = [(spread(cells), lvl) for cells, lvl in DISTRICTS] + [(spread(RIM), 4)]
owner = {}
for cells, lvl in DISTRICTS:
    for c in cells:
        if c in inside:
            owner[c] = lvl
for x, y in ISLAND:
    if (x, y) in owner:
        V.put(x, y, "g", owner[(x, y)])
        continue
    num = den = 0.0
    for dist, lvl in fields:
        d = dist.get((x, y))
        if d is not None:
            w = 1.0 / (d + 1) ** 3
            num += w * lvl
            den += w
    V.put(x, y, "g", max(1, int(num / den) // TERRACE * TERRACE))
for x, y in LAKE:
    if (x, y) in inside:
        V.put(x, y, "w", 0)

# --- the gorge and the stream: the floor drops 6, 4, 2 and the water falls at each step into the lake ---------
GORGE = [((14.5, -1), (15.5, 11.5), 16), ((15.5, 11.5), (17, 27), 11), ((17, 27), (16.5, 40), 5), ((16.5, 40), (15, 45), 0)]
for a, b, floor in GORGE:
    for c in ribbon(V, [a, b], 2.4, only=lambda x, y: V.terrain[y][x] != "."):
        if V.height[c[1]][c[0]] > floor:
            # a real gorge: cut down to the water's step; its head, above the stone bridge, is a wooded ravine
            V.put(c[0], c[1], "f" if floor == GORGE[0][2] else "g", max(floor, 1))
    for c in ribbon(V, [a, b], 0.85, "w", floor, only=lambda x, y: V.terrain[y][x] != "."):
        KEEP_OPEN.add(c)

# The square: one big paved floor, room to breathe (an irregular octagon).
SQUARE = [c for c in blob(30, 21.5, 7.5, 7, 1.1, 0.12) if V.height[c[1]][c[0]] == 18]
for x, y in SQUARE:
    V.put(x, y, "s", 18)
KEEP_OPEN.update(SQUARE)


# --- roads: winding courses; a flight is cut where one meets a cliff ----------------------------------------
def course(pts):
    """The cells along a polyline, 4-connected, in order."""
    out = []
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        n = max(1, int(math.hypot(bx - ax, by - ay) * 3))
        for i in range(n + 1):
            c = (int(ax + (bx - ax) * i / n), int(ay + (by - ay) * i / n))
            if out and c == out[-1]:
                continue
            if out and abs(c[0] - out[-1][0]) + abs(c[1] - out[-1][1]) == 2:
                out.append((c[0], out[-1][1]))  # turn the corner, so every step is a side step
            out.append(c)
    return out


def road(pts, t="d"):
    """A road along the course. Where it meets a cliff more than a level high, a flight is cut into the low side
    along the course (or back into the high side when the low side has no room), climbing two levels a step: the
    lead's jump is 1, and a stair lets it climb 2 more (CombatGrid.STAIRS_CLIMB)."""
    cells = [c for c in course(pts) if 0 <= c[0] < W and 0 <= c[1] < H and V.terrain[c[1]][c[0]] != "."]
    hs = [V.height[y][x] for x, y in cells]
    stairs = {}
    props = _prop_cells(V)
    open_at = lambda c, h: (0 <= c[0] < W and 0 <= c[1] < H and V.terrain[c[1]][c[0]] in "gds" and c not in props
                            and V.height[c[1]][c[0]] == h and c not in stairs)
    for i in range(len(cells) - 1):
        a, b = hs[i], hs[i + 1]
        if abs(a - b) <= 1:
            continue
        hi_c, lo_c = (cells[i], cells[i + 1]) if a > b else (cells[i + 1], cells[i])
        hi, lo = max(a, b), min(a, b)
        e = (lo_c[0] - hi_c[0], lo_c[1] - hi_c[1])  # straight out from the cliff, whatever the road's bend
        axis = (1, 0) if e[0] else (0, 1)
        done = False
        for rise in (1, 2):  # one level a step; two where there's no room for one (a stair climbs up to 3)
            n = (hi - lo - 1) // rise
            low = [(lo_c[0] + e[0] * k, lo_c[1] + e[1] * k) for k in range(n + 1)]  # the flight, then its landing
            high = [(hi_c[0] - e[0] * k, hi_c[1] - e[1] * k) for k in range(n + 1)]
            if n and all(open_at(c, lo) for c in low):
                for k, c in enumerate(low[:-1]):
                    stairs[c] = (hi - rise * (k + 1), axis)
                done = True
            elif n and all(open_at(c, hi) for c in high):
                for k, c in enumerate(high[:-1]):
                    stairs[c] = (lo + rise * (k + 1), axis)
                done = True
            elif not n:  # a step of 2 or 3: the cliff top cell is the stair
                stairs[hi_c] = (hi, None)
                done = True
            if done:
                break
        if not done and hi - lo <= 3:  # no room for a run: the cliff top cell is the stair (it climbs up to 3)
            stairs[hi_c] = (hi, None)  # a lone step: the game reads which way it climbs
            done = True
        if not done:
            raise SystemExit("road at %s: no straight run either side for a flight of %s" % (cells[i], hi - lo))
    for c in cells:
        x, y = c
        if V.terrain[y][x] == "w":
            continue
        if c in stairs:
            continue  # laid below, straight out from the cliff
        elif V.terrain[y][x] != "t":
            V.put(x, y, t)
        KEEP_OPEN.add(c)
    for (x, y), (h, axis) in stairs.items():
        V.put(x, y, "t", h)
        if axis:
            FLIGHTS[(x, y)] = axis
        KEEP_OPEN.add((x, y))
    return cells


def deck(cells, h):
    """A bridge floor over the cells, at least two levels over the ground under it."""
    for x, y in cells:
        assert h - V.height[y][x] >= 2, "a deck too low over %s" % ((x, y),)
        DECKS[(x, y)] = h
        KEEP_OPEN.add((x, y))


# The bridges first, so the roads run onto them.
STONE_BRIDGE = [(x, y) for x in range(13, 21) for y in (22, 23) if V.height[y][x] <= 16 and (x, y) in set(ISLAND)]
deck(STONE_BRIDGE, 18)  # the square's west bridge, high over the gorge, to the ruins' foot
FOOT_BRIDGE = [(x, y) for x in range(12, 27) for y in (37,) if V.height[y][x] <= 10]
deck(FOOT_BRIDGE, 12)  # the wooden footbridge lower down, level with the farm (13) at its west end
_east = (max(x for x, _ in FOOT_BRIDGE) + 1, 37)  # its east end steps down to the south town's lane (9)
V.put(_east[0], _east[1], "t", 10)
KEEP_OPEN.add(_east)

road([(36.5, 56), (35.5, 51), (32.5, 49), (33.5, 46.5)])  # the gate road up to the south town
road([(33.5, 46.5), (36, 43), (33, 39), (31.5, 33), (31.5, 29.5), (30.5, 26.5)])  # the south town up to the square (switchback)
# (the square up to the hall: a grand staircase, below)
road([(36.5, 21.5), (41, 17.5), (44, 15.5)])  # to the smithy
road([(36.5, 26.5), (43.5, 27.5), (43.5, 33.5), (38.5, 33.5)])  # down round the tavern to its front door
road([(43, 34.5), (47, 33), (49.5, 36)])  # on to the east homes
road([(22.5, 22.5), (21, 22.5)])  # onto the stone bridge
road([(12.5, 22.5), (12.5, 24.5), (9.5, 25.5), (8, 27.5), (7.5, 28.5), (7.5, 33.5)])  # the ruins' foot down to the farm
# (the ruins' foot up into the cemetery: a grand staircase, below)
road([(10.5, 37.5), (11.5, 37.5)])  # the farm onto the footbridge
road([(28.5, 37.5), (28.5, 42), (31, 44.5)])  # off the footbridge to the south town
road([(27.5, 46.5), (24, 47), (21, 46.5), (18, 45.5), (14, 44.5), (11, 45.5)])  # the south town down to the lake shore

# --- grand staircases: straight, wide, one level a step, a landing every few steps ([USER] 2026-10-30) ------
def grand_stair(start, up, width, lo, hi, landing_every=3):
    """A flight from a bottom landing at `lo` to a top landing at `hi`. `start` is the first step's cell on one
    edge of the flight; `up` the direction it climbs; `width` cells across (toward +x or +y, whichever is across).
    Cells are cut or built to the flight's levels, so it reads as a stair laid into the cliff."""
    ux, uy = up
    across = (0, 1) if ux else (1, 0)
    rows = []
    lvl, run = lo, 0
    while lvl < hi - 1:
        lvl += 1
        rows.append(("t", lvl))
        run += 1
        if run == landing_every and lvl < hi - 1:
            rows.append(("s", lvl))  # a landing
            run = 0
    rows = [("s", lo)] + rows + [("s", hi), ("s", hi)]
    cells = []
    for k, (t, h) in enumerate(rows):
        for w in range(width):
            x = start[0] + ux * (k - 1) + across[0] * w
            y = start[1] + uy * (k - 1) + across[1] * w
            V.put(x, y, t, h)
            if t == "t":
                FLIGHTS[(x, y)] = (1, 0) if ux else (0, 1)
            KEEP_OPEN.add((x, y))
            cells.append((x, y))
    return cells


HALL_STAIR = grand_stair((28, 14), (0, -1), 3, 18, 24)  # from the square straight up to the town hall
CEMETERY_STAIR = grand_stair((9, 26), (0, -1), 3, 18, 24)  # from the ruins' foot up into the cemetery

# The dock: planks from the shore's edge out over the lake, five cells long.
DOCK = []
for x in (10, 11):
    y0 = next(y for y in range(40, H) if V.terrain[y][x] == "w")
    DOCK += [(x, y) for y in range(y0, y0 + 5)]
for x, y in DOCK:
    V.put(x, y, "d", 1)
    KEEP_OPEN.add((x, y))
DOCK_END = max(DOCK, key=lambda c: c[1])


# --- buildings, each with a yard ---------------------------------------------------------------------------
def house(sprite, x, y, fx, fy, door_dx, yard=None):
    hit = [(xx, yy) for yy in range(y, y + fy) for xx in range(x, x + fx) if V.terrain[yy][xx] == "t"]
    assert not hit, "%s at %s would stand on a stair: %s" % (sprite, (x, y), hit)
    h = V.height[y + fy - 1][x + door_dx]
    V.fill(x, y, x + fx - 1, y + fy - 1, "g", h)
    for yy in range(y, y + fy):
        for xx in range(x, x + fx):
            FLIGHTS.pop((xx, yy), None)
    door = V.building(sprite, x, y, fx, fy, door_dx, yard)
    V.put(door[0], door[1], "d", h)
    for yy in range(y - 1, y + fy + 2):
        for xx in range(x - 1, x + fx + 2):
            KEEP_OPEN.add((xx, yy))
    return door


def p(sprite, x, y, tall, sight=0.0, foot=(1, 1)):
    V.prop(sprite, x, y, foot, tall=tall, sight=sight)
    KEEP_OPEN.add((x, y))


TREE = {"prop_tree_2": 1.6, "prop_tree_3": 1.6, "prop_tree_4": 1.5, "prop_tree_5": 1.5, "prop_tree_bare": 1.5,
        "prop_pine_1": 1.25, "prop_pine_2": 1.25, "prop_pine_3": 1.25}


def tree(sprite, x, y):
    p(sprite, x, y, TREE[sprite], 1.0)


def fence(cells):
    for x, y in cells:
        p("prop_fence", x, y, 0.6)


def spot(district, x, y):
    SPOTS.append({"district": district, "cell": [x, y]})
    KEEP_OPEN.add((x, y))


hall_door = house("b_townhall", 26, 2, 7, 5, 3)
smithy_door = house("b_smithy", 42, 11, 3, 4, 0, yard=(2, 2))
tavern_door = house("b_tavern", 36, 29, 6, 4, 2)
hero_door = house("b_home_hero", 29, 41, 3, 3, 1)
east_a = house("b_home_a", 47, 30, 3, 3, 1)
east_b = house("b_home_b", 48, 38, 4, 3, 1)
farm_door = house("b_home_a", 4, 30, 3, 3, 1)
dog_door = house("b_home_a", 3, 25, 3, 3, 1)  # the dog's house on the ruins' foot
lake_door = house("b_home_c", 3, 41, 4, 3, 1)  # on the lake's shore, for the companions drawn to the water

# Yards: a fence, a garden bed and a bench round each home.
fence([(28, 44), (28, 43)])
p("prop_planter", 32, 44, 0.8, 0.5)
fence([(46, 30), (46, 31), (46, 32)])
p("prop_bench", 50, 32, 0.6)
p("prop_planter", 52, 40, 0.8, 0.5)
fence([(47, 41), (47, 40)])
fence([(3, 30), (3, 31), (3, 32)])
p("prop_bench", 3, 29, 0.6)
fence([(2, 26), (2, 27)])  # the dog's garden
p("prop_planter", 6, 26, 0.8, 0.5)
p("prop_bench", 7, 42, 0.6)

# The square, the smithy, the tavern.
V.prop("ph_statue", 30, 20, (2, 2), tall=2.2, sight=2.0)
p("prop_well", 25, 18, 1.8, 1.0, (2, 2))
p("prop_stall", 33, 16, 1.8, 1.0, (2, 2))
p("prop_stall", 25, 24, 1.8, 1.0, (2, 2))
p("prop_crates", 35, 17, 0.8)
for x, y in [(27, 15), (34, 24), (24, 21)]:
    p("prop_lamp", x, y, 1.5)
p("prop_bench", 28, 18, 0.6)
p("prop_bench", 32, 24, 0.6)
p("prop_rack", 45, 12, 1.0)  # against the smithy's east wall, by the yard
p("prop_grindstone", 41, 14, 0.85)  # by the forge
p("prop_barrel", 47, 15, 0.7)
p("prop_bench", 35, 33, 0.6)
p("prop_lamp", 40, 34, 1.5)
p("prop_barrel", 42, 30, 0.7)
gx, gy = next((x, y) for y in range(54, 44, -1) for x in range(31, 38)
              if V.terrain[y][x + 1] == "d" and len({V.height[y][x + k] for k in range(3)}) == 1
              and all(V.terrain[y][x + k] in "dg" for k in range(3)))
V.arch("prop_arch", gx, gy, (3, 1))  # the town gate, across the gate road on a flat stretch
KEEP_OPEN.update((x, gy) for x in range(gx, gx + 3))

# The ruins and the cemetery (graybox where we have no art).
V.prop("ruins/prop_ruin", 10, 9, (1, 1), tall=1.1, sight=1.0)
V.prop("ruins/prop_landmark", 9, 5, (1, 1), tall=1.6, sight=1.0)
for x, y in [(3, 10), (3, 16), (12, 12)]:
    V.prop("dungeon/prop_pillar", x, y, (1, 1), tall=1.6, sight=1.0)
V.arch("prop_arch", 5, 8, (4, 1))
for x in (4, 6, 8):
    for y in (12, 14, 16):
        V.prop("ph_grave", x, y, (1, 1), tall=0.4, sight=0.3)
V.prop("ph_crypt_gate", 5, 19, (2, 1), tall=1.5, sight=2.0)
p("prop_tree_bare", 10, 17, 1.5, 1.0)
KEEP_OPEN.update((x, y) for x in range(2, 13) for y in range(4, 21))

# The farm (windmill and fields).
V.prop("ph_windmill", 9, 32, (2, 2), tall=3.0, sight=3.0)
for y in (35, 37):
    V.prop("ph_crops", 3, y, (3, 1), tall=0.3, sight=0.0)
p("prop_hay", 8, 36, 0.65, 0.5)
KEEP_OPEN.update((x, y) for x in range(2, 13) for y in range(29, 39))

# The lake.
bx, by = next((x, y) for y in range(DOCK[0][1] - 2, 36, -1) for x in range(12, 20)
              if len({V.height[y + dy][x + dx] for dx in (0, 1) for dy in (0, 1)}) == 1
              and all(V.terrain[y + dy][x + dx] == "g" for dx in (0, 1) for dy in (0, 1)))
V.prop("ph_boathouse", bx, by, (2, 2), tall=1.5, sight=2.0)  # on flat shore beside the dock's root
V.prop("ph_boat", 8, DOCK[0][1] - 2, (1, 2), tall=0.4, sight=0.0)  # pulled up on the shore by the dock
KEEP_OPEN.update((x, y) for x in range(8, 15) for y in range(DOCK[0][1] - 4, DOCK[0][1] + 6))
reeds = [(x, y) for y in range(40, H) for x in range(0, 24) if V.terrain[y][x] == "g" and V.height[y][x] == 1
         and any(V.terrain[y + dy][x + dx] == "w" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if 0 <= x + dx < W and 0 <= y + dy < H)
         and (x, y) not in KEEP_OPEN]
for x, y in reeds[::5][:4]:
    V.prop("ph_reeds", x, y, (1, 1), tall=0.4, sight=0.0)  # at the water's edge
    KEEP_OPEN.add((x, y))

# --- things (shut doors and gate: v2 is its own level) ---------------------------------------------------------
V.thing(id="gate", kind="exit", event="door_stuck", cell=[35, 53])  # shut: v2 is its own level
for i, d in enumerate([hall_door, smithy_door, tavern_door, hero_door, east_a, east_b, farm_door, dog_door, lake_door]):
    V.thing(id="door_%d" % i, kind="enter", event="door_stuck", cell=list(d))
V.thing(id="statue", kind="statue", event="statue_lodestone", cell=[31, 22], once="has_lodestone")
V.thing(id="weapon_rack", kind="rack", event="smithy_rack", cell=[45, 12], once="weapon_sword|weapon_daggers|weapon_bow")
V.thing(id="smithy_restore", kind="restore", event="smithy", cell=[42, 15])  # in front of the forge
V.thing(id="smith", kind="settler", event="settler_smith", cell=[38, 18], once="settler_smith")
V.thing(id="inn_restore", kind="restore", event="inn", cell=[40, 33])
V.thing(id="chef", kind="settler", event="settler_chef", cell=[35, 30], once="settler_chef")
V.thing(id="dog_home", kind="companion", event="companion_dog", cell=[6, 27], when="met_dog")
V.thing(id="food_barrel", kind="cache", event="cache_food", cell=[43, 30], once="got_food_barrel")
V.thing(id="smithy_rope", kind="cache", event="cache_rope", cell=[47, 15], once="got_rope")
V.thing(id="dock_fish", kind="fish", event="fish_dock", cell=[DOCK_END[0], DOCK_END[1] + 1])  # off the dock's end
rod = next((DOCK[0][0] - 1, y) for y in range(DOCK[0][1], 0, -1) if V.terrain[y][DOCK[0][0] - 1] == "g")
V.thing(id="dock_rod", kind="find", event="rod:+1", cell=list(rod))  # the first fishing rod, on the shore by the dock's root (5130f86)
# Two shore spots, west and east, on the water beside the shore (a spot rests until the next trip out: 306accc).
shore = [(x, y) for y in range(40, H - 1) for x in range(1, 26) if V.terrain[y][x] == "g" and V.height[y][x] == 1
         and (x, y) not in _prop_cells(V) and any(V.terrain[y + dy][x + dx] == "w" for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1)))]
for i, (sx, sy) in enumerate([min(shore), max(shore)]):
    wx, wy = next((sx + dx, sy + dy) for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1)) if V.terrain[sy + dy][sx + dx] == "w")
    V.thing(id="shore_fish_%d" % i, kind="fish", event="fish_dock", cell=[wx, wy])
V.start = [list(hero_door)]
for t in V.things:
    KEEP_OPEN.add(tuple(t["cell"]))

# Companions' home spots (data only: no names).
for x, y in [(6, 7), (10, 15), (3, 18)]:
    spot("ruins", x, y)
for x, y in [(8, 44), (16, 44), (5, 45)]:
    spot("lake", x, y)
for x, y in [(6, 33), (11, 30)]:
    spot("farm", x, y)
for x, y in [(36, 22), (50, 35)]:
    spot("town", x, y)

# --- every shelf on a planned route ([USER] 2026-10-30: "make sure that all these places are accessible and
# stairs get built"): walk the map as the game does; for each piece of ground nobody can reach, cut a flight
# up or down its nearest cliff to ground that is reached (one level a step, two wide where it fits). Slivers
# too small to be a place (under 4 cells) grow trees instead. Whatever is left fails the build. ------------
def _walk_places(start):
    blocked = _prop_cells(V)
    def ok(c):
        x, y = c
        return 0 <= x < W and 0 <= y < H and V.terrain[y][x] not in "ru.wf" and c not in blocked
    def places(c):
        out = []
        if ok(c) and (c not in DECKS or DECKS[c] - V.height[c[1]][c[0]] >= 2):
            out.append((c, 0))
        if c in DECKS:
            out.append((c, 1))
        return out
    def lvl(q):
        return DECKS[q[0]] if q[1] else V.height[q[0][1]][q[0][0]]
    def step(a, b):
        st = (not a[1] and V.terrain[a[0][1]][a[0][0]] == "t") or (not b[1] and V.terrain[b[0][1]][b[0][0]] == "t")
        return abs(lvl(a) - lvl(b)) <= 1 + (2 if st else 0)
    seen, todo = {(start, 0)}, [(start, 0)]
    while todo:
        q = todo.pop()
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            for r in places((q[0][0] + d[0], q[0][1] + d[1])):
                if r not in seen and step(q, r):
                    seen.add(r)
                    todo.append(r)
    ground = [(x, y) for y in range(H) for x in range(W) if ok((x, y)) and not perch((x, y))]
    deck_lost = [q[0] for q in ((c, 1) for c in DECKS) if q not in seen]
    assert not deck_lost, "bridge decks nobody can step onto: %s" % deck_lost
    return {q[0] for q in seen if not q[1]}, ground


def perch(c):
    """A rock pillar's top (CombatGrid.perch): two levels over every neighbour; nobody walks up there."""
    x, y = c
    h = V.height[y][x]
    return all(not (0 <= x + dx < W and 0 <= y + dy < H) or V.terrain[y + dy][x + dx] in "." or V.height[y + dy][x + dx] <= h - 2
               for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))


def _flight(cells, levels, axis):
    for (x, y), h in zip(cells, levels):
        V.put(x, y, "t", h)
        FLIGHTS[(x, y)] = axis
        KEEP_OPEN.add((x, y))


def connect_shelves(start, rounds=200):
    """Cut flights until every shelf joins the route network. Returns the cells still cut off."""
    for _ in range(rounds):
        reached, ground = _walk_places(start)
        lost = set(ground) - reached
        if not lost:
            return []
        comps, left = [], set(lost)
        while left:
            c = left.pop()
            comp, todo = {c}, [c]
            while todo:
                x, y = todo.pop()
                for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if n in left and abs(V.height[n[1]][n[0]] - V.height[y][x]) <= 1:  # one walkable piece
                        left.discard(n)
                        comp.add(n)
                        todo.append(n)
            comps.append(comp)
        comps.sort(key=len, reverse=True)
        comp = comps[0]
        if len(comp) < 4:
            for x, y in comp:
                if V.terrain[y][x] == "g":
                    V.put(x, y, "f")
            if all(V.terrain[y][x] == "f" for x, y in comp):
                continue
            return sorted(comp)
        free = lambda c: (0 <= c[0] < W and 0 <= c[1] < H and V.terrain[c[1]][c[0]] == "g" and c not in KEEP_OPEN
                          and c not in _prop_cells(V) and c not in DECKS)
        best = None
        for u in comp:
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                v = (u[0] + d[0], u[1] + d[1])
                if v not in reached:
                    continue
                hu, hv = V.height[u[1]][u[0]], V.height[v[1]][v[0]]
                if abs(hu - hv) < 2:
                    continue
                hi_c, lo_c = (u, v) if hu > hv else (v, u)
                hi, lo = max(hu, hv), min(hu, hv)
                e = (lo_c[0] - hi_c[0], lo_c[1] - hi_c[1])  # away from the cliff, on the low side
                n = hi - lo - 1
                run = [(lo_c[0] + e[0] * k, lo_c[1] + e[1] * k) for k in range(n)]
                land = (lo_c[0] + e[0] * n, lo_c[1] + e[1] * n)
                axis = (1, 0) if e[0] else (0, 1)
                ok_low = all(free(c) and V.height[c[1]][c[0]] == lo for c in run) and 0 <= land[0] < W \
                    and 0 <= land[1] < H and V.height[land[1]][land[0]] == lo and V.terrain[land[1]][land[0]] not in "ru.wf"
                if ok_low and (best is None or n < best[0]):
                    best = (n, run, [hi - 1 - k for k in range(n)], axis, e)
                # or cut back into the high side, when the low side has no room
                back = [(hi_c[0] - e[0] * k, hi_c[1] - e[1] * k) for k in range(n)]
                top = (hi_c[0] - e[0] * n, hi_c[1] - e[1] * n)
                ok_high = all(free(c) and V.height[c[1]][c[0]] == hi for c in back) and 0 <= top[0] < W \
                    and 0 <= top[1] < H and V.height[top[1]][top[0]] == hi and V.terrain[top[1]][top[0]] not in "ru.wf"
                if ok_high and (best is None or n + 0.5 < best[0]):
                    best = (n + 0.5, back, [lo + 1 + k for k in range(n)], axis, e)
        if best is None:
            on_rim = any(not (0 <= x + dx < W and 0 <= y + dy < H) or V.terrain[y + dy][x + dx] == "."
                         for x, y in comp for dx in (-2, -1, 0, 1, 2) for dy in (-2, -1, 0, 1, 2))
            if not on_rim:
                return sorted(comp)  # a shelf inside the town with no way to it: the build fails
            for x, y in comp:
                if V.terrain[y][x] == "g":
                    V.put(x, y, "f")  # a ledge hanging on the rim: woods, like the rest of the rim
            if any(V.terrain[y][x] != "f" for x, y in comp):
                return sorted(comp)
            continue
        _, run, levels, axis, e = best
        _flight(run, levels, axis)
        side = (e[1], e[0])  # two wide where the cells beside are free and level too
        twin = [(x + side[0], y + side[1]) for x, y in run]
        if all(free(c) and V.height[c[1]][c[0]] == V.height[run[0][1]][run[0][0]] for c in twin):
            _flight(twin, levels, axis)
    return sorted(set(_walk_places(start)[1]) - _walk_places(start)[0])


CUT_OFF = connect_shelves(tuple(V.start[0]))

# --- lone trees and rocks on the open grass, the rim wooded ------------------------------------------------------
LONE = ["prop_tree_2", "prop_pine_1", "prop_tree_4", "prop_pine_2", "prop_tree_5", "prop_tree_3", "prop_pine_3"]
near = {(x + dx, y + dy) for x, y in KEEP_OPEN for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
inside = set(ISLAND)
for y in range(H):
    for x in range(W):
        if V.terrain[y][x] != "g" or (x, y) in near:
            continue
        rim = any((x + dx, y + dy) not in inside for dx in (-2, 0, 2) for dy in (-2, 0, 2))
        r = (x * 73 + y * 151 + x * y * 7) % 100
        if rim and r < 35:
            V.put(x, y, "f")
        elif r < 11:
            tree(LONE[(x + y * 3) % len(LONE)], x, y)
        elif r < 14:
            p("prop_boulder" if (x + y) % 2 else "prop_boulder_2", x, y, 0.6, 1.0)

def save_all():
    V.save()
    path = os.path.normpath(os.path.join(OUT_DIR, "village_v2.json"))
    with open(path) as f:
        data = json.load(f)
    data["grid"]["decks"] = [{"x": x, "y": y, "h": h, "t": "s"} for (x, y), h in sorted(DECKS.items())]
    data["companion_spots"] = SPOTS
    with open(path, "w") as f:
        json.dump(data, f, indent=1)
        f.write("\n")
    return path


# The painted look's authoring rules, as the map maker's Generate menu applies them: V9 tidy edges, V10 pillars
# (on this map up to its full height, 24). Then the dressed ground comes back and every shelf is joined again.
UNDER = {c: (V.terrain[c[1]][c[0]], V.height[c[1]][c[0]]) for pr in V.props
         for c in [(pr["cell"][0] + dx, pr["cell"][1] + dy) for dy in range(pr["foot"][1]) for dx in range(pr["foot"][0])]}
path = save_all()
GODOT = os.environ.get("GODOT") or shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot"
GAME = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "game"))
subprocess.run([GODOT, "--headless", "--path", GAME, "-s", "res://tools/dress_explore.gd", "--", "village_v2", "", "", "4", "24"],
               check=True)
with open(path) as f:
    dressed = json.load(f)["grid"]
for y in range(H):
    for x in range(W):
        V.put(x, y, dressed["terrain"][y][x], HEIGHT_DIGITS.index(dressed["heights"][y][x]))
for (x, y), (t, h) in UNDER.items():
    V.put(x, y, t, h)  # the tidy never reshapes the ground under a building or a prop
CUT_OFF = connect_shelves(tuple(V.start[0]))  # again: a tree or the tidy may have closed a narrow way
if "--dump" in sys.argv:
    dump(V)
if CUT_OFF:
    raise SystemExit("village_v2: %d walkable cells no route reaches: %s" % (len(CUT_OFF), CUT_OFF[:12]))
check_village(V, DECKS)
save_all()
