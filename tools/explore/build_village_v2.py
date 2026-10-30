#!/usr/bin/env python3
"""Builds game/data/explore/village_v2.json: a second village build, its own level on the launch menu ([USER]
2026-10-30, after docs/art/references/village-v2-layout.webp; layout only, the look stays the fall set).

Pass 2 after Brandon's review ("so flat and square... I want a lot more verticality... much more dynamically
shaped"): every district is an organic blob (noisy outline, no rectangles) at its own height, with cliffs several
levels tall between them, so the town climbs from the lake to the ruins:

  8  the ruins and the cemetery on their cliff top (screen top left), the town hall's crag (top right)
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
for x, y in ISLAND:
    V.put(x, y, "g", 2)  # the meadow
SHORE = blob(13, 47, 13, 10, 2.2, 0.2)
raise_to(SHORE, 1)
LAKE = blob(12.5, 51, 8.5, 5, 4.1, 0.18)
raise_to(LAKE, 0, "w")
SOUTH = blob(31, 45, 9, 6, 0.4)  # the hero's cottage and the gate road
raise_to(SOUTH, 3)
EAST = blob(49, 35, 7, 10, 3.3)  # the east homes
raise_to(EAST, 3)
TAVERN = blob(39, 33, 9, 6, 5.0)
raise_to(TAVERN, 4)
FARM = blob(7, 34, 7.5, 7, 2.7)
raise_to(FARM, 5)
PLATEAU = blob(30, 21, 11, 9.5, 0.9, 0.16) + blob(43, 15, 7.5, 7.5, 1.8)  # the square and the smithy
raise_to(PLATEAU, 6)
FOOT = blob(8, 25, 7, 4.5, 3.9)  # the ruins' foot, where the stone bridge lands
raise_to(FOOT, 6)
RUINS = blob(7, 13, 7.5, 10, 4.6)
raise_to(RUINS, 8)
HALL = blob(29, 5.5, 9, 5.5, 2.4)
raise_to(HALL, 8)

# --- the gorge and the stream: the floor drops 6, 4, 2 and the water falls at each step into the lake ---------
GORGE = [((14.5, -1), (15.5, 11.5), 6), ((15.5, 11.5), (17, 27), 4), ((17, 27), (16.5, 40), 2), ((16.5, 40), (15, 45), 0)]
for a, b, floor in GORGE:
    for c in ribbon(V, [a, b], 2.4, only=lambda x, y: V.terrain[y][x] != "."):
        if V.height[c[1]][c[0]] > floor:
            V.put(c[0], c[1], "g", max(floor, 1))
    for c in ribbon(V, [a, b], 0.85, "w", floor, only=lambda x, y: V.terrain[y][x] != "."):
        KEEP_OPEN.add(c)

# The square: one big paved floor, room to breathe (an irregular octagon).
SQUARE = [c for c in blob(30, 21.5, 7.5, 7, 1.1, 0.12) if V.height[c[1]][c[0]] == 6]
for x, y in SQUARE:
    V.put(x, y, "s", 6)
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
    """A road along the course. Where it meets a cliff more than a level high, a flight one level a step is cut
    into the low side along the course (so it reads as stairs built up the cliff face)."""
    cells = [c for c in course(pts) if 0 <= c[0] < W and 0 <= c[1] < H and V.terrain[c[1]][c[0]] != "."]
    hs = [V.height[y][x] for x, y in cells]
    stairs = {}
    for i in range(len(cells) - 1):
        a, b = hs[i], hs[i + 1]
        if abs(a - b) <= 1:
            continue
        hi, lo = max(a, b), min(a, b)
        n = hi - lo - 1
        low = range(i + 1, i + 1 + n) if a > b else range(i, i - n, -1)  # along the low side, away from the cliff
        high = range(i, i - n, -1) if a > b else range(i + 1, i + 1 + n)  # or cut back into the high side
        if all(0 <= j < len(cells) and hs[j] == lo for j in low):
            run, levels = list(low), [hi - 1 - k for k in range(n)]
        elif all(0 <= j < len(cells) and hs[j] == hi for j in high):
            run, levels = list(high), [lo + 1 + k for k in range(n)]
        else:
            raise SystemExit("road at %s: no room either side for a flight of %s: %s" % (cells[i], hi - lo, list(zip(cells, hs))))
        top = (i if a > b else i + 1) if run == list(low) else run[-1] + (-1 if a > b else 1)
        along_x = cells[i][0] != cells[i + 1][0]  # the flight climbs the way the road crosses the cliff
        for j, lvl in list(zip(run, levels)) + [(top, hi)]:  # the top step too, so the flight reads up its course
            stairs[cells[j]] = (lvl, along_x)
    for c in cells:
        x, y = c
        if V.terrain[y][x] == "w":
            continue
        if c in stairs:
            h, along_x = stairs[c]
            V.put(x, y, "t", h)
            k = cells.index(c)
            nb = [cells[j] for j in (k - 1, k + 1) if 0 <= j < len(cells)]
            if len({q[0] for q in nb + [c]}) == 1 or len({q[1] for q in nb + [c]}) == 1:
                FLIGHTS[c] = (1, 0) if along_x else (0, 1)  # a straight run: hold the drawing to it (on a
                # diagonal the steps zig-zag and the game's own reading stands)
        elif V.terrain[y][x] != "t":
            V.put(x, y, t)
        KEEP_OPEN.add(c)
    return cells


def deck(cells, h):
    """A bridge floor over the cells, at least two levels over the ground under it."""
    for x, y in cells:
        assert h - V.height[y][x] >= 2, "a deck too low over %s" % ((x, y),)
        DECKS[(x, y)] = h
        KEEP_OPEN.add((x, y))


# The bridges first, so the roads run onto them.
STONE_BRIDGE = [(x, y) for x in range(13, 21) for y in (22, 23) if V.height[y][x] < 6 and (x, y) in set(ISLAND)]
deck(STONE_BRIDGE, 6)  # the square's west bridge, high over the gorge, to the ruins' foot
FOOT_BRIDGE = [(x, y) for x in range(12, 22) for y in (37,) if V.height[y][x] <= 2]
deck(FOOT_BRIDGE, 4)  # the wooden footbridge lower down, from the farm to the south town

road([(36.5, 56), (35.5, 51), (32.5, 49), (33.5, 46.5)])  # the gate road up to the south town
road([(33.5, 46.5), (36, 43), (33, 39), (31.5, 33), (31.5, 29.5), (30.5, 26.5)])  # the south town up to the square (switchback)
road([(29.5, 14.2), (28.5, 11.5), (29.5, 8.5)])  # the square up to the hall
road([(36.5, 21.5), (41, 17.5), (44, 15.5)])  # to the smithy
road([(35.5, 26.5), (38, 29.5), (40.5, 31.5)])  # down to the tavern
road([(43, 34.5), (47, 33), (49.5, 36)])  # on to the east homes
road([(22.5, 22.5), (21, 22.5)])  # onto the stone bridge
road([(12.5, 22.5), (10, 24), (8, 27.5), (6.5, 29.5), (7.5, 31)])  # the ruins' foot down to the farm
road([(8.5, 21), (7.5, 18), (9.5, 14), (11.5, 10.5)])  # the ruins' foot up into the cemetery
road([(10.5, 37.5), (11.5, 37.5)])  # the farm onto the footbridge
road([(22.5, 37.5), (25, 39.5), (28, 42), (31, 44.5)])  # off the footbridge to the south town
road([(27.5, 46.5), (24, 47), (21, 46.5), (18, 45.5), (14, 44.5), (11, 45.5)])  # the south town down to the lake shore

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
dog_door = house("b_home_a", 4, 23, 3, 3, 1)  # the dog's house on the ruins' foot
lake_door = house("b_home_c", 3, 41, 4, 3, 1)  # on the lake's shore, for the companions drawn to the water

# Yards: a fence, a garden bed and a bench round each home.
fence([(28, 44), (28, 43)])
p("prop_planter", 32, 44, 0.8, 0.5)
fence([(46, 30), (46, 31), (46, 32)])
p("prop_bench", 50, 32, 0.6)
p("prop_planter", 52, 40, 0.8, 0.5)
fence([(47, 41), (47, 40)])
fence([(3, 30), (3, 31), (3, 32)])
p("prop_bench", 7, 29, 0.6)
fence([(3, 23), (3, 24)])  # the dog's garden
p("prop_planter", 7, 23, 0.8, 0.5)
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
V.arch("prop_arch", 34, 52, (3, 1))  # the town gate, across the gate road
KEEP_OPEN.update((x, 52) for x in range(34, 37))

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
V.prop("ph_boathouse", 12, DOCK[0][1] - 3, (2, 2), tall=1.5, sight=2.0)  # on the shore beside the dock's root
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
V.thing(id="dog_home", kind="companion", event="companion_dog", cell=[7, 24], when="met_dog")
V.thing(id="food_barrel", kind="cache", event="cache_food", cell=[43, 30], once="got_food_barrel")
V.thing(id="smithy_rope", kind="cache", event="cache_rope", cell=[47, 15], once="got_rope")
V.thing(id="dock_fish", kind="fish", event="fish_dock", cell=[DOCK_END[0], DOCK_END[1] + 1])  # off the dock's end
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
        if rim and r < 70:
            V.put(x, y, "f")
        elif r < 11:
            tree(LONE[(x + y * 3) % len(LONE)], x, y)
        elif r < 14:
            p("prop_boulder" if (x + y) % 2 else "prop_boulder_2", x, y, 0.6, 1.0)

if "--dump" in sys.argv:
    dump(V)
check_village(V, DECKS)
V.save()
path = os.path.normpath(os.path.join(OUT_DIR, "village_v2.json"))
with open(path) as f:
    data = json.load(f)
data["grid"]["decks"] = [{"x": x, "y": y, "h": h, "t": "s"} for (x, y), h in sorted(DECKS.items())]
data["companion_spots"] = SPOTS
with open(path, "w") as f:
    json.dump(data, f, indent=1)
    f.write("\n")

# The painted look's authoring rules, as the map maker's Generate menu applies them: V9 tidy edges, V10 pillars.
GODOT = os.environ.get("GODOT") or shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot"
GAME = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "game"))
subprocess.run([GODOT, "--headless", "--path", GAME, "-s", "res://tools/dress_explore.gd", "--", "village_v2", "", "", "4"],
               check=True)
