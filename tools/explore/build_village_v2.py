#!/usr/bin/env python3
"""Builds game/data/explore/village_v2.json: a second village build to compare with the live one ([USER] 2026-10-30,
after docs/art/references/village-v2-layout.webp; layout only, the look stays the fall set). It keeps everything
decided for the village and lays it out as a bigger, winding town of terraces:

  7  the ruins and the cemetery (screen top left: the low-x edge), and the town hall's terrace (top right)
  5  the square (big, room to breathe), the smithy shelf east of it, the ruins' foot and the farm in the west
  4  the tavern terrace, a step down from the square
  3  the south town (the hero's cottage, the gate road) and the east homes, each with its own yard
  0  the lake (screen bottom left: the high-y edge) with a dock; the stream runs down a valley between the
     ruins and the square, through a gorge, and falls into it

Bridges are decks (docs/systems/decks.md) where a road crosses the valley or the gorge. The doors stay shut in
this test town (door_stuck): the interiors lead back to the live village. Art we don't have yet stands in as
graybox (ph_ sprites): graves, the crypt gate, the windmill, the boathouse, a boat, crop rows, reeds.
Companions' home spots are data only (`companion_spots`: district and cell, no names).

Run again after editing: python3 tools/explore/build_village_v2.py [--dump]
"""
import json
import os
import sys

from village_kit import *  # noqa: F401,F403 (Map, shapes, check_village)
from village_kit import _prop_cells  # noqa: F401

W = H = 56
V = Map("village_v2", W, H)
V.fill(0, 0, W - 1, H - 1, "g", 3)
DECKS = {}  # (x, y) -> deck height (CombatGrid.decks)
SPOTS = []  # companions' home spots: {"district", "cell"}
OPEN = set()  # cells the outline and the woods leave alone


def deck(x0, y0, x1, y1, h):
    """A bridge floor over the cells (inclusive rect), at least DECK_CLEAR over the ground under it."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            assert h - V.height[y][x] >= 2, "a deck too low over %s" % ((x, y),)
            DECKS[(x, y)] = h


def spot(district, x, y):
    SPOTS.append({"district": district, "cell": [x, y]})


# --- ground: terraces first, then water, paving and roads over them ----------------------------------------
poly(V, [(0, 2), (15, 2), (15, 22), (0, 22)], "g", 7)  # the ruins and the cemetery
poly(V, [(0, 22), (15, 22), (15, 30), (0, 30)], "g", 5)  # the ruins' foot
poly(V, [(0, 30), (15, 30), (15, 40), (11, 42), (0, 41)], "g", 5)  # the farm
poly(V, [(19, 0), (39, 0), (39, 10), (36, 12), (21, 12), (19, 10)], "g", 7)  # the town hall's terrace
poly(V, [(19, 12), (38, 12), (38, 31), (19, 31)], "g", 5)  # round the square
poly(V, [(39, 2), (54, 2), (54, 20), (38, 20)], "g", 5)  # the smithy shelf
poly(V, [(38, 20), (54, 20), (54, 35), (38, 35)], "g", 4)  # the tavern terrace
# The stream's valley between the ruins and the square: high at the back, a step down half way.
poly(V, [(15, 0), (19, 0), (19, 12), (15, 12)], "g", 5)
poly(V, [(15, 12), (19, 12), (19, 29), (15, 29)], "g", 3)
poly(V, [(15, 29), (20, 29), (20, 41), (15, 41)], "g", 2)  # the gorge
# The lake and its shore.
poly(V, [(0, 41), (11, 42), (16, 41), (24, 43), (26, 50), (24, 55), (0, 55)], "g", 1)
LAKE = poly(V, [(1, 47), (8, 46), (15, 46.5), (20, 48), (21, 52), (19, 55), (1, 55)], "w", 0)

STREAM = ribbon(V, [(17, -1), (17, 11.5)], 0.75, "w", 4)
STREAM += ribbon(V, [(17, 12.5), (16.6, 20), (17.2, 28.5)], 0.75, "w", 2)
STREAM += ribbon(V, [(17.4, 29.5), (17.8, 36), (17.5, 47)], 0.8, "w", 1)
for c in STREAM + LAKE:
    OPEN.add(c)

# The square (5): one big paved floor, an octagon, room to breathe.
SQUARE = []
for y in range(H):
    for x in range(W):
        dx, dy = abs(x + 0.5 - 28.5), abs(y + 0.5 - 21.5)
        if dx <= 8 and dy <= 8 and dx + dy <= 12:
            SQUARE.append((x, y))
            V.put(x, y, "s", 5)

# --- stairs and bridges ----------------------------------------------------------------------------------
flight(V, [[(27, 11), (28, 11)], [(27, 12), (28, 12)]], 6)  # the square up to the hall's terrace
V.fill(27, 4, 28, 10, "s", 7)  # the hall's forecourt
flight(V, [[(29, 31), (30, 31)], [(29, 32), (30, 32)]], 4)  # the square down to the south town
flight(V, [[(6, 22), (7, 22)], [(6, 23), (7, 23)]], 6)  # the ruins' foot up to the ruins
flight(V, [[(21, 41), (22, 41)], [(21, 42), (22, 42)]], 2)  # the south town down to the lake shore
deck(15, 6, 18, 7, 7)  # the stone bridge from the hall's terrace into the ruins, over the valley
deck(15, 24, 18, 25, 5)  # the square's west bridge over the valley, to the ruins' foot
deck(15, 35, 19, 36, 4)  # the farm's bridge over the gorge, to the south town

# --- roads (packed dirt) -----------------------------------------------------------------------------------
ribbon(V, [(36.5, 56), (36.5, 49), (34.5, 44), (32, 38), (30, 33.5)], 0.95, "d", 3)  # the gate road
ribbon(V, [(36.5, 18.5), (41, 16), (45, 14.5)], 0.75, "d", 5)  # east to the smithy
ribbon(V, [(36, 26), (40, 28.5), (42.5, 30.5)], 0.75, "d", 4)  # down to the tavern
ribbon(V, [(45, 33), (46, 37), (45, 42.5), (40, 47)], 0.75, "d", 3)  # the east homes' lane
ribbon(V, [(36, 45), (40, 47)], 0.7, "d", 3)
ribbon(V, [(20, 36), (25, 37), (30, 39), (33, 41)], 0.75, "d", 3)  # from the gorge bridge to the gate road
ribbon(V, [(14, 25), (10, 26.5), (8, 29), (8, 33)], 0.75, "d", 5)  # the ruins' foot to the farm
ribbon(V, [(7, 21), (7, 16), (10, 12), (12, 7), (14.5, 6.5)], 0.7, "s", 7)  # the ruins' path to the bridge
ribbon(V, [(21, 43.5), (16.5, 44.2), (12, 44.5), (10.5, 45.5)], 0.75, "d", 1)  # the lake shore to the dock

# --- the dock: planks out over the lake --------------------------------------------------------------------
V.fill(9, 46, 11, 51, "d", 1)
OPEN.update((x, y) for x in (9, 10, 11) for y in range(46, 52))

# --- the outline and the woods -----------------------------------------------------------------------------
def is_void(x, y):
    if (x, y) in OPEN:
        return False
    return x + y < 5 or (W - 1 - x) + y < 5 or x + (H - 1 - y) < 3 or (W - 1 - x) + (H - 1 - y) < 5


for y in range(H):
    for x in range(W):
        if is_void(x, y):
            V.put(x, y, ".", 0)
for y in range(H):
    for x in range(W):
        if V.terrain[y][x] != "g" or (x, y) in OPEN:
            continue
        near = min(x, y, W - 1 - x, H - 1 - y) + 1
        if near <= 1 or (near == 2 and (x * 7 + y * 3) % 3 != 0) or (near == 3 and (x * 5 + y * 11) % 7 == 0):
            V.put(x, y, "f")
for x0, y0, x1, y1 in [(19, 0, 22, 3), (35, 0, 38, 2), (50, 2, 54, 5), (50, 31, 54, 35), (0, 30, 2, 33),
                       (12, 37, 14, 40), (23, 32, 26, 34), (50, 48, 54, 54)]:
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if V.terrain[y][x] == "g":
                V.put(x, y, "f")  # copses between the districts

# --- buildings, each with its own yard ---------------------------------------------------------------------
def house(sprite, x, y, fx, fy, door_dx, yard=None):
    h = V.height[y][x]
    V.fill(x, y, x + fx - 1, y + fy - 1, "g", h)
    door = V.building(sprite, x, y, fx, fy, door_dx, yard)
    V.put(door[0], door[1], "d", h)
    return door


def p(sprite, x, y, tall, sight=0.0, foot=(1, 1)):
    V.prop(sprite, x, y, foot, tall=tall, sight=sight)


def fence(cells):
    for x, y in cells:
        p("prop_fence", x, y, 0.6)


hall_door = house("b_townhall", 24, 3, 7, 5, 3)
smithy_door = house("b_smithy", 44, 6, 3, 4, 0, yard=(2, 2))
V.fill(47, 7, 50, 11, "s", 5)  # the smithy yard
tavern_door = house("b_tavern", 42, 24, 6, 4, 2)
hero_door = house("b_home_hero", 29, 42, 3, 3, 1)
east_a = house("b_home_a", 44, 38, 3, 3, 1)
east_b = house("b_home_b", 48, 43, 4, 3, 1)
east_c = house("b_home_c", 38, 48, 4, 3, 1)
farm_door = house("b_home_a", 3, 32, 3, 3, 1)
dog_door = house("b_home_a", 9, 24, 3, 3, 1)  # the dog's house, on the ruins' foot, its garden toward the farm
lake_door = house("b_home_c", 3, 42, 4, 3, 1)  # on the lake's north shore, for the companions drawn to the water

# Yards: a fence, a garden bed and a bench round each home.
fence([(28, 41), (28, 42), (28, 43)])
p("prop_planter", 28, 45, 0.8, 0.5)
p("prop_bench", 27, 44, 0.6)
fence([(43, 37), (47, 37), (47, 38), (47, 39)])
p("prop_planter", 47, 41, 0.8, 0.5)
p("prop_bench", 43, 41, 0.6)
fence([(47, 42), (52, 42), (52, 43)])
p("prop_planter", 52, 46, 0.8, 0.5)
p("prop_hay", 47, 46, 0.65, 0.5)
fence([(37, 47), (42, 47)])
p("prop_planter", 42, 51, 0.8, 0.5)
fence([(8, 24), (8, 25), (8, 26)])  # the dog's garden, on the house's west side
p("prop_planter", 8, 23, 0.8, 0.5)
p("prop_bench", 12, 24, 0.6)
fence([(2, 31), (6, 31), (6, 32)])
p("prop_bench", 8, 43, 0.6)

# --- the square, the smithy, the tavern ----------------------------------------------------------------------
V.prop("ph_statue", 28, 21, (2, 2), tall=2.2, sight=2.0)
p("prop_well", 23, 17, 1.8, 1.0, (2, 2))
p("prop_stall", 32, 16, 1.8, 1.0, (2, 2))
p("prop_stall", 23, 25, 1.8, 1.0, (2, 2))
p("prop_crates", 34, 17, 0.8)
p("prop_barrel", 25, 26, 0.7)
for x, y in [(21, 21), (35, 22), (28, 14), (28, 29)]:
    p("prop_lamp", x, y, 1.5)
p("prop_bench", 26, 18, 0.6)
p("prop_bench", 31, 25, 0.6)
p("prop_tree_3", 33, 27, 1.6, 1.0)
p("prop_tree_5", 22, 14, 1.5, 1.0)
p("prop_rack", 46, 10, 1.0)  # against the smithy wall, by the door
p("prop_grindstone", 43, 10, 0.85)
p("prop_barrel", 50, 8, 0.7)
p("prop_crates", 50, 11, 0.8)
p("prop_bench", 40, 31, 0.6)
p("prop_bench", 47, 29, 0.6)
p("prop_lamp", 45, 29, 1.5)
p("prop_barrel", 48, 24, 0.7)
p("prop_crates", 48, 25, 0.8)
V.arch("prop_arch", 35, 51, (4, 1))  # the town gate on the gate road
V.arch("prop_arch_timber", 26, 9, (4, 1))  # the hall gate, at the head of its stair

# --- the ruins and the cemetery (graybox where we have no art) ---------------------------------------------------
V.prop("ruins/prop_ruin", 3, 4, (1, 1), tall=1.1, sight=1.0)
V.prop("ruins/prop_ruin", 4, 4, (1, 1), tall=1.1, sight=1.0)
V.prop("ruins/prop_landmark", 10, 4, (1, 1), tall=1.6, sight=1.0)
V.prop("dungeon/prop_pillar", 2, 9, (1, 1), tall=1.6, sight=1.0)
V.prop("dungeon/prop_pillar", 2, 13, (1, 1), tall=1.6, sight=1.0)
V.prop("dungeon/prop_pillar", 12, 15, (1, 1), tall=1.6, sight=1.0)
V.arch("prop_arch", 4, 8, (4, 1))  # a broken gateway into the cemetery
for x in (3, 5, 7, 9):
    for y in (11, 13, 15):
        V.prop("ph_grave", x, y, (1, 1), tall=0.4, sight=0.3)
V.prop("ph_crypt_gate", 3, 18, (2, 1), tall=1.5, sight=2.0)
fence([(2, 10), (2, 11), (2, 12), (11, 10), (11, 11), (11, 12), (11, 13), (11, 14)])
p("prop_tree_bare", 9, 18, 1.5, 1.0)
p("prop_tree_bare", 13, 9, 1.5, 1.0)

# --- the farm (windmill and fields) --------------------------------------------------------------------------
V.prop("ph_windmill", 9, 35, (2, 2), tall=3.0, sight=3.0)
for y in (37, 39):
    V.prop("ph_crops", 2, y, (4, 1), tall=0.3, sight=0.0)
p("prop_hay", 7, 38, 0.65, 0.5)
p("prop_hay", 7, 39, 0.65, 0.5)
fence([(1, 36), (1, 37), (1, 38), (1, 39), (1, 40)])

# --- the lake ------------------------------------------------------------------------------------------------------
V.prop("ph_boathouse", 13, 42, (2, 2), tall=1.5, sight=2.0)
V.prop("ph_boat", 9, 49, (1, 2), tall=0.4, sight=0.0)  # moored on the dock's edge
for x, y in [(2, 46), (14, 45), (20, 47)]:
    V.prop("ph_reeds", x, y, (1, 1), tall=0.4, sight=0.0)  # on the shore at the water's edge

# --- things (doors stay shut in this test town; see the doc string) -------------------------------------------
GATE = (36, 54)
V.thing(id="gate", kind="exit", event="village_gate", cell=list(GATE))
for i, d in enumerate([hall_door, smithy_door, tavern_door, hero_door, east_a, east_b, east_c, farm_door, dog_door,
                       lake_door]):
    V.thing(id="door_%d" % i, kind="enter", event="door_stuck", cell=list(d))
V.thing(id="statue", kind="statue", event="statue_lodestone", cell=[29, 23], once="has_lodestone")
V.thing(id="weapon_rack", kind="rack", event="smithy_rack", cell=[46, 10], once="weapon_sword|weapon_daggers|weapon_bow")
V.thing(id="smithy_restore", kind="restore", event="smithy", cell=[44, 11])  # in front of the forge
V.thing(id="smith", kind="settler", event="settler_smith", cell=[41, 15], once="settler_smith")
V.thing(id="inn_restore", kind="restore", event="inn", cell=[46, 28])  # beside the tavern door
V.thing(id="chef", kind="settler", event="settler_chef", cell=[40, 26], once="settler_chef")
V.thing(id="dog_home", kind="companion", event="companion_dog", cell=[12, 23], when="met_dog")
V.thing(id="food_barrel", kind="cache", event="cache_food", cell=[49, 24], once="got_food_barrel")
V.thing(id="smithy_rope", kind="cache", event="cache_rope", cell=[50, 9], once="got_rope")
V.thing(id="dock_fish", kind="fish", event="fish_dock", cell=[10, 52])  # off the end of the dock
V.start = [list(hero_door)]

# --- companions' home spots (data only: no names) ------------------------------------------------------------
for x, y in [(6, 6), (8, 19), (12, 17)]:
    spot("ruins", x, y)
for x, y in [(8, 44), (16, 43), (11, 45)]:
    spot("lake", x, y)
for x, y in [(5, 36), (11, 31)]:
    spot("farm", x, y)
for x, y in [(36, 31), (49, 39)]:
    spot("town", x, y)

# --- woods: grass well away from the roads, yards, squares and things grows trees, so the districts read as
# clearings and the roads wind through the woods between them (woods block walking: 3aa981f) ---------------
KEEP = set()
for y in range(H):
    for x in range(W):
        if V.terrain[y][x] in "dst":
            KEEP.add((x, y))
for c in _prop_cells(V):
    KEEP.add(c)
KEEP.update(tuple(t["cell"]) for t in V.things)
KEEP.update(DECKS)
KEEP.update(tuple(sp["cell"]) for sp in SPOTS)
KEEP.update(c for c in LAKE)
ROOM = 2  # cells of open ground kept round all of that
open_ground = {(x + dx, y + dy) for x, y in KEEP for dx in range(-ROOM, ROOM + 1) for dy in range(-ROOM, ROOM + 1)
               if abs(dx) + abs(dy) <= ROOM + 1}
for y in range(H):
    for x in range(W):
        if V.terrain[y][x] == "g" and (x, y) not in open_ground and (x, y) not in OPEN:
            V.put(x, y, "f")

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
