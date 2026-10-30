#!/usr/bin/env python3
"""Builds the starting village explore maps: the hero's home, the village outside, and two interiors.

- home:     the hero's one-room cottage (the run starts here); its door leads out to the village.
- village:  a quiet, half-empty village in a valley that falls toward the front: a big flat square, the town
            hall up a terrace at the back, a stream that falls off a high wood and winds past the smithy
            shelf (weapon rack in its yard), round the hero's cottage and under the gate road, two homes up
            a bluff in the north-east (a ledge half way up), the tavern, the dog's house over a footbridge,
            two more homes, an irregular outline. Fully visible (no fog). Checked as it is built
            (check_village); `--dump` prints the map as text.
- house_ne: an ordinary home a little off the square, with an inner room; the hidden book sits on a
            shelf against its back wall, out of sight from the door (docs/design/empty-village.md s7).
- tavern:   the tavern's ground floor.
- house_dog: the west home on the ridge, door locked; the dog is shut inside. The way in is the window on
            its right front wall ([USER] 2026-10-28, the E2E loop); once he is out the door opens.

The E2E loop also puts the statue with the Lodestone in the square (a placeholder blob until art), and
spare food, a rope and potions in a tavern barrel, the smithy yard and the hero's own chest.

Buildings and furniture are placed props (CombatGrid.props) drawn from the village and village_in tile
sets (art cut by tools/art/village_cut.py). Interiors are floors with walls of rock terrain; the walls
nearest the camera stand only one level tall so the room reads from above, like a cutaway.

Run again after editing: python3 tools/explore/build_village.py
"""
import json
import math
import os
import sys

from village_kit import *  # noqa: F401,F403 (Map, shapes, check_village)
from village_kit import _bump, _open, _prop_cells, _seg_dist  # noqa: F401


# --- the village ------------------------------------------------------------------------------------
# Rot 0: +x runs down-right on screen, +y down-left; the front (nearest the camera) is high x + y.
# Every building's door is on its left front wall, so it opens toward +y.
#
# The town sits in a valley that falls from the back (top of the screen) to the front:
#   5  the high wood in the north-west, where the stream rises, and the bluff in the north-east (two homes)
#   3  the town hall terrace at the back, the smithy shelf over the stream, the ledge half way up the bluff
#   1  the square, the lanes, the yards and the meadows
#   0  the stream: it falls off the high wood, runs past the smithy, bends round the hero's cottage and
#      across the front under the gate road, and spills off the south edge.
# Every two-level climb has a stair flight (the lead's jump is 1); flights are two cells long, cut into
# the higher ground, so their sides stay level with the top (MapDress.stair_run then lays the treads the
# right way). The gate road, the statue, the hall stair and the hall door sit on one line (x 20 to 21),
# so the town hall is in view from the gate and from the square.

V = Map("village", 40, 38)
V.fill(0, 0, 39, 37, "g", 1)

# The outline: the valley floor breaks into bays and points instead of a rectangle.
EDGE_N = [(12, 18, 2), (25, 28, 3)]  # y = 0 edge, along x: behind the hall, the notch between hall and bluff
EDGE_S = [(8, 15, 2), (24, 28, 2)]  # y = 37 edge (the front), along x
EDGE_W = [(9, 14, 1)]  # x = 0 edge, along y
EDGE_E = [(11, 16, 3), (21, 25, 2)]  # x = 39 edge, along y
OPEN = set()  # cells the outline must leave alone (the gate road, the stream's mouth)


def is_void(x, y):
    if (x, y) in OPEN:
        return False
    return (y < _bump(x, EDGE_N) or 37 - y < _bump(x, EDGE_S) or x < _bump(y, EDGE_W)
            or 39 - x < _bump(y, EDGE_E) or x + y < 3 or (39 - x) + y < 4 or x + (37 - y) < 7
            or (39 - x) + (37 - y) < 6)


# Heights first; the outline, the woods and the paving go over them.
# The high wood (5) in the north-west.
# The smithy shelf (3) under it, over the stream.
poly(V, [(6, 7), (15, 7), (15, 13), (14, 15), (6, 15)], "g", 3)
poly(V, [(0, 0), (14, 0), (14, 9), (10, 9), (10, 8), (5, 8), (5, 9), (0, 9)], "f", 5)  # the high wood
# The town hall terrace (3) at the back.
poly(V, [(14, 0), (26, 0), (26, 10), (24, 12), (16, 12), (14, 10)], "g", 3)
V.fill(17, 12, 24, 13, "g", 3)  # the bastion the hall stair is cut into
# The bluff (5) in the north-east, and the ledge (3) half way up it.
poly(V, [(29, 0), (40, 0), (40, 10), (29, 10)], "g", 5)
poly(V, [(28, 10), (36, 10), (36, 14), (35, 16), (28, 16)], "g", 3)
# A rise (2) on the far bank, over the bend of the stream.
poly(V, [(1, 25), (5, 24), (7, 27), (6, 31), (1, 32)], "g", 2)
# A knoll (2) across the stream, west of the gate road.
poly(V, [(3, 33), (9, 31.5), (16, 32), (18, 34), (18, 37), (3, 37)], "g", 2)

# The stream (0) and its head in the high wood (4); it falls four levels off the wood's edge.
HEAD = ribbon(V, [(6.5, -1), (6.5, 3), (5.8, 6), (5.6, 7.9)], 0.75, "w", 4)
STREAM_PTS = [(5.4, 8.6), (4.5, 11), (4.4, 14), (5.8, 16.6), (8, 19.5), (8.2, 23.5), (9, 26.5), (11, 29.4),
              (14.5, 31.6), (19, 32.8), (24, 33.6), (28, 35), (30.5, 36.4), (31.5, 38.5)]
STREAM = ribbon(V, STREAM_PTS, 0.95, "w", 0)
for c in STREAM:
    if c[1] >= 34:
        OPEN.add(c)

# The square (1): one big flat floor, an octagon with the lanes leaving its corners.
SQUARE = []
for y in range(V.h):
    for x in range(V.w):
        dx, dy = abs(x + 0.5 - 21), abs(y + 0.5 - 20)
        if dx <= 7 and dy <= 6 and dx + dy <= 10.5:
            SQUARE.append((x, y))
            V.put(x, y, "s", 1)

# The hall stair: on the line of the statue and the gate road, cut into the bastion.
flight(V, [[(20, 12), (21, 12)], [(20, 13), (21, 13)]], 3)
V.fill(17, 8, 24, 11, "s", 3)  # the hall's forecourt
# The smithy: its yard drops to the square by a stair, and a stair climbs from the yard to the high wood.
flight(V, [[(12, 13), (13, 13)], [(12, 14), (13, 14)]], 3)
flight(V, [[(11, 7), (12, 7)], [(11, 8), (12, 8)]], 5)
V.fill(11, 9, 14, 12, "s", 3)  # the yard
V.fill(9, 13, 11, 14, "d", 3)  # from the smithy door to the stair
V.fill(9, 14, 9, 14, "d")
# The bluff: the east lane climbs to the ledge (an overlook on the square), then on to the top.
flight(V, [[(29, 14), (30, 14)], [(29, 15), (30, 15)]], 3)
flight(V, [[(31, 8), (32, 8)], [(31, 9), (32, 9)]], 5)
V.fill(29, 10, 33, 13, "d", 3)  # ledge path between the flights
V.fill(31, 5, 32, 7, "d", 5)  # up top, to the quiet house
V.fill(33, 7, 35, 7, "d", 5)  # and along to the second home

# Lanes (packed dirt, level 1).
ribbon(V, [(21, 26), (21, 37.5)], 0.6, "d", 1)  # the gate road, straight at the statue and the hall
V.fill(20, 32, 21, 33, "s", 1)  # its bridge over the stream
V.fill(19, 32, 19, 33, "s", 1)
V.fill(22, 32, 22, 33, "s", 1)
for x in (19, 20, 21, 22):
    for y in (36, 37):
        OPEN.add((x, y))
ribbon(V, [(13.5, 21.5), (9.5, 21.8), (6, 21.8), (4.2, 21.5)], 0.75, "d", 1)  # the west lane to the far bank
V.fill(7, 21, 8, 22, "s", 1)  # its footbridge
ribbon(V, [(12.6, 15.4), (14.6, 16.6)], 0.7, "d", 1)  # smithy stair to the square
ribbon(V, [(28, 17), (36.5, 17)], 0.6, "d", 1)  # the east lane past the tavern
ribbon(V, [(25.5, 25.5), (27, 28.5), (30, 29.3), (33, 30.3), (35.5, 31.5)], 0.7, "d", 1)  # south-east lane to the homes
ribbon(V, [(12.5, 28.5), (15.5, 29.5), (18, 28.8), (20, 28.5)], 0.65, "d", 1)  # the hero's path
ribbon(V, [(25.6, 14.4), (26.5, 12), (27, 8), (27, 4.5)], 0.6, "d", 1)  # the glade behind the hall

# Woods: a band of forest round the rim, thinner where the town presses against it.
for y in range(V.h):
    for x in range(V.w):
        if is_void(x, y):
            V.put(x, y, ".", 0)
for y in range(V.h):
    for x in range(V.w):
        if V.terrain[y][x] not in "gf":
            continue
        near = min((abs(x - a) + abs(y - b) for b in range(max(0, y - 3), min(V.h, y + 4))
                    for a in range(max(0, x - 3), min(V.w, x + 4)) if V.terrain[b][a] == "."), default=99)
        near = min(near, x + 1, y + 1, V.w - x, V.h - y)
        if near <= 1 or (near == 2 and (x * 7 + y * 3) % 3 != 0) or (near == 3 and (x * 5 + y * 11) % 7 == 0):
            V.put(x, y, "f")
# The high wood is forest except a clearing at the head of the falls (an overlook on the town).
poly(V, [(8, 2), (12, 2), (13, 4), (13, 7), (9, 7), (8, 5)], "g", 5)
V.put(7, 4, "g")
V.put(7, 5, "g")

# Buildings. Footprints are cleared to grass at their own level; door cells get a dirt step.
BUILT = []


def house(sprite, x, y, fx, fy, door_dx, yard=None):
    h = V.height[y][x]
    V.fill(x, y, x + fx - 1, y + fy - 1, "g", h)
    BUILT.append((sprite, x, y, fx, fy))
    door = V.building(sprite, x, y, fx, fy, door_dx, yard)
    V.put(door[0], door[1], "d", h)
    return door


hall_door = house("b_townhall", 17, 3, 7, 5, 3)  # door at (20, 8), on the line of the stair and the statue
smithy_door = house("b_smithy", 8, 9, 3, 4, 0, yard=(2, 2))  # on the shelf; the door faces its own yard, inside the ^
quiet_door = house("b_home_c", 30, 2, 4, 3, 1)  # the quiet house (the hidden book), up on the bluff
bluff_door = house("b_home_a", 34, 4, 3, 3, 1)  # a second home on the bluff
tavern_door = house("b_tavern", 29, 18, 6, 4, 2)  # east of the square, its garden facing the front
west_door = house("b_home_a", 2, 18, 3, 3, 1)  # the dog's house, over the footbridge on the far bank
hero_door = house("b_home_hero", 11, 25, 3, 3, 1)  # the hero's cottage, on the bend of the stream
south_east_door = house("b_home_b", 28, 25, 4, 3, 1)
far_door = house("b_home_a", 34, 28, 3, 3, 1)

V.fill(20, 9, 21, 11, "s")  # the forecourt runs straight from the hall door to the stair


def p(sprite, x, y, tall, sight=0.0, foot=(1, 1)):
    if V.terrain[y][x] == "f":
        V.put(x, y, "g")
    V.prop(sprite, x, y, foot, tall=tall, sight=sight)


TREE = {"prop_tree": 1.6, "prop_tree_2": 1.6, "prop_tree_3": 1.6, "prop_tree_4": 1.5, "prop_tree_5": 1.5,
        "prop_tree_bare": 1.5, "prop_pine_1": 1.25, "prop_pine_2": 1.25, "prop_pine_3": 1.25}


def tree(sprite, x, y):
    p(sprite, x, y, TREE[sprite], 1.0)


def bush(x, y, n=1):
    p("prop_bush" if n == 1 else "prop_bush_%d" % n, x, y, 0.55, 0.5)


# The square: open in the middle; the statue on the line from the gate to the hall.
# The statue that wasn't there yesterday (an elf woman holding out the Lodestone): a placeholder blob.
V.prop("ph_statue", 20, 21, (2, 2), tall=2.2, sight=2.0)
p("prop_well", 16, 18, 1.8, 1.0, (2, 2))
p("prop_stall", 24, 15, 1.8, 1.0, (2, 2))
p("prop_crates", 26, 16, 0.8)
p("prop_stall", 16, 23, 1.8, 1.0, (2, 2))
p("prop_barrel", 15, 23, 0.7)
for x, y in [(15, 21), (26, 23)]:
    p("prop_lamp", x, y, 1.5)
p("prop_bench", 18, 19, 0.6)
p("prop_bench", 24, 21, 0.6)
p("prop_planter", 18, 24, 0.8)
p("prop_planter", 23, 24, 0.8)
p("prop_planter", 19, 15, 0.8)
p("prop_planter", 22, 15, 0.8)

# The hall terrace: the notice board by the door, fall trees at its corners.
p("prop_board", 23, 9, 1.0)
p("prop_planter", 18, 10, 0.8)
p("prop_planter", 23, 11, 0.8)
tree("prop_tree_3", 16, 3)
tree("prop_tree_4", 24, 3)
tree("prop_tree", 25, 6)
tree("prop_tree_2", 16, 8)
bush(15, 10, 2)
bush(24, 12, 3)
V.arch("prop_arch_timber", 19, 11, (4, 1))  # the hall gate, at the head of the stair

# The smithy yard (its anvil and forge are in the building art, on its front wall): the rack against the
# smithy wall on the yard side, the grindstone on the grass beside the forge, the rope barrel; the yard
# between its two stairs and the door stays open ([USER] 2026-10-30).
p("prop_rack", 11, 12, 1.0)
p("prop_grindstone", 8, 13, 0.85)
p("prop_barrel", 14, 9, 0.7)
p("prop_crates", 14, 12, 0.8)
p("prop_hay", 7, 13, 0.65)

# The high wood's clearing at the head of the falls.
p("prop_bench", 9, 4, 0.6)
p("prop_boulder", 8, 6, 0.6, 1.0)
p("prop_stump", 12, 3, 0.5)
tree("prop_pine_2", 13, 5)

# The far bank: the dog's house with its garden.
p("prop_fence", 2, 22, 0.6)
p("prop_hay", 1, 20, 0.65)
p("prop_planter", 5, 23, 0.8)
bush(1, 22, 2)
# The rise: a few fall trees and a bench looking over the stream at the hero's cottage.
tree("prop_tree_5", 2, 26)
tree("prop_tree_3", 3, 29)
tree("prop_tree_bare", 5, 30)
p("prop_bench", 5, 27, 0.6)
p("prop_stump", 2, 28, 0.5)
p("prop_boulder_2", 6, 25, 0.6, 1.0)

# The hero's cottage on the bend.
p("prop_fence", 14, 27, 0.6)
p("prop_hay", 14, 25, 0.65)
p("prop_stump", 10, 25, 0.5)
bush(10, 26, 3)
tree("prop_tree_2", 16, 26)

# The bluff: an overlook at its west end, a hay yard at the back of the second home.
p("prop_bench", 29, 6, 0.6)
p("prop_hay", 37, 5, 0.65)
p("prop_fence", 37, 7, 0.6)
tree("prop_tree_4", 36, 8)
tree("prop_tree_2", 33, 9)
bush(34, 2, 2)
# The ledge half way up: a bench looking over the square.
p("prop_bench", 28, 12, 0.6)
p("prop_lamp", 28, 14, 1.5)
p("prop_barrel", 34, 11, 0.7)
tree("prop_tree_5", 35, 13)

# The glade behind the hall: a quiet nook between the terrace and the bluff.
tree("prop_tree_bare", 28, 6)
p("prop_boulder", 28, 4, 0.6, 1.0)
p("prop_stump", 28, 9, 0.5)
bush(27, 14, 1)

# The tavern: barrels on its east side, a garden of benches at its front.
p("prop_barrel", 35, 19, 0.7)
p("prop_barrel", 35, 20, 0.7)
p("prop_crates", 35, 21, 0.8)
p("prop_bench", 33, 23, 0.6)
p("prop_bench", 29, 23, 0.6)
p("prop_lamp", 30, 22, 1.5)  # by the door
tree("prop_tree_3", 36, 22)

# The south-east: two homes, an old cart, an orchard going wild toward the front.
p("prop_cart", 25, 29, 1.3, 1.0, (2, 2))
p("prop_stump", 33, 27, 0.5)
for s, x, y in [("prop_tree_2", 32, 32), ("prop_tree_4", 34, 33), ("prop_tree_3", 31, 34), ("prop_tree", 36, 32),
                ("prop_tree_5", 33, 35)]:
    tree(s, x, y)
bush(37, 30, 2)

# The front: boulders at the stream, the knoll's pines, the gate posts.
p("prop_boulder", 16, 30, 0.6, 1.0)
p("prop_boulder_2", 24, 32, 0.6, 1.0)
p("prop_boulder", 9, 30, 0.6, 1.0)
tree("prop_pine_3", 13, 34)
tree("prop_tree_4", 7, 33)
tree("prop_tree_2", 10, 34)
p("prop_boulder", 5, 33, 0.6, 1.0)
p("prop_stump", 9, 33, 0.5)
tree("prop_pine_1", 15, 35)
tree("prop_tree_bare", 16, 33)
V.arch("prop_arch", 19, 30, (4, 1))  # the town gate, where the south road comes off the bridge
p("prop_fence", 18, 36, 0.6)
p("prop_fence", 23, 36, 0.6)
tree("prop_tree_4", 24, 30)
bush(25, 35, 3)

# Fifty years of quiet: tumbled garden walls.
for x, y in [(36, 25), (37, 26), (24, 27)]:
    V.put(x, y, "u")

# The gate: the south road runs out of the village to the overworld (only once the Lodestone is taken).
V.thing(id="gate", kind="exit", event="village_gate", cell=[20, 37])

V.thing(id="hero_home", kind="enter", event="", cell=hero_door, to="home", at=[3, 5])
V.thing(id="quiet_house", kind="enter", event="", cell=quiet_door, to="house_ne", at=[3, 7])
V.thing(id="tavern_door", kind="enter", event="", cell=tavern_door, to="tavern", at=[3, 9])
V.thing(id="hall_door", kind="enter", event="door_stuck", cell=hall_door)
V.thing(id="smithy_door", kind="enter", event="door_stuck", cell=smithy_door)
# The dog's house: the door is locked until he is out; the window on the right front wall gets you in.
V.thing(id="west_door", kind="enter", event="door_dog", cell=west_door, to="house_dog", at=[3, 5], once="met_dog")
V.thing(id="west_door_open", kind="enter", event="", cell=west_door, to="house_dog", at=[3, 5], when="met_dog")
V.thing(id="dog_window", kind="window", event="dog_window", cell=[5, 19], to="house_dog", at=[5, 3], once="met_dog")
# Once he's out, the dog lives here: walk up to invite him or send him home ([USER] pc-10). No figure of
# its own (the "!" only), since he may be in the party and following the lead.
V.thing(id="dog_home", kind="companion", event="companion_dog", cell=[3, 23], when="met_dog")
V.thing(id="se_door", kind="enter", event="door_stuck", cell=south_east_door)
V.thing(id="far_door", kind="enter", event="door_stuck", cell=far_door)
V.thing(id="bluff_door", kind="enter", event="door_stuck", cell=bluff_door)
# The restore loop ([USER] omr-5): walk up to a building to see its next step. The settlers who run them
# move in by a placeholder WELCOME and are gone once welcomed (unlock:<flag>;remove, then `once`).
V.thing(id="smithy_restore", kind="restore", event="smithy", cell=[9, 13])  # in front of the forge
V.thing(id="smith", kind="settler", event="settler_smith", cell=[14, 15], once="settler_smith")  # at the foot of the yard stairs, clear of the yard's own marks
V.thing(id="inn_restore", kind="restore", event="inn", cell=[33, 22])  # beside the tavern door
V.thing(id="weapon_rack", kind="rack", event="smithy_rack", cell=[11, 12],
        once="weapon_sword|weapon_daggers|weapon_bow")
V.thing(id="statue", kind="statue", event="statue_lodestone", cell=[21, 22], once="has_lodestone")
V.thing(id="food_barrel", kind="cache", event="cache_food", cell=[35, 19], once="got_food_barrel")
V.thing(id="smithy_rope", kind="cache", event="cache_rope", cell=[14, 9], once="got_rope")
V.start = [hero_door]
if "--dump" in sys.argv:
    dump(V)
check_village(V)
V.save(fog=False)  # the whole town is in view: fog of war is for the bigger maps



# --- interiors (the village_in set: plank floors, plaster walls) ----------------------------------------

def window(m, x, y):
    """A window piece in a back wall (the wall kit's wall_window)."""
    m.prop("wall_window", x, y)


def door(m, x, y):
    """A doorway piece in a back wall (the wall kit's wall_door; for show, the way out is the front edge)."""
    m.prop("wall_door", x, y)


def interior(name, w, h):
    m = Map(name, w, h, ".", 0, "village_in")
    m.walls = True
    m.wall_kit = "village_in"  # thin plaster-and-timber back walls from the house wall kit ([USER] 2026-10-30)
    return m


# The hero's cottage: one room.
H = interior("home", 8, 7)
room(H, 0, 0, 7, 6)
H.put(3, 6, "s", 1)  # doorway in the front-left wall
window(H, 2, 0)  # over the bed
window(H, 0, 4)
H.prop("prop_bed", 1, 1, tall=0.75)
H.prop("prop_hearth", 4, 1, tall=0.95, sight=1.0)
H.prop("prop_cupboard", 6, 1, tall=1.3, sight=1.0)
H.prop("prop_table", 4, 3, tall=0.7)
H.prop("prop_chair", 5, 3, tall=0.75)
H.prop("prop_rug", 2, 4, tall=0.45, sight=0.0, walk=True)
H.prop("prop_chest", 1, 3, tall=0.6)
H.prop("prop_pots", 6, 4, tall=0.6)
H.thing(id="out", kind="enter", event="", cell=[3, 6], to="village", at=hero_door)
H.thing(id="home_chest", kind="cache", event="cache_potion", cell=[1, 3], once="got_potion")
H.start = [[3, 4]]
H.save()

# The quiet house: a front room and an inner room behind a wall, the book on a shelf at the back.
Q = interior("house_ne", 11, 9)
room(Q, 0, 0, 10, 8)
Q.fill(6, 0, 6, 8, "r", 3)  # inner wall between the front room (x < 6) and the inner room (x > 6)
Q.put(6, 8, "r", 2)
Q.put(6, 6, "s", 1)  # gap into the inner room, near the front
Q.put(3, 8, "s", 1)  # front door
window(Q, 3, 0)
window(Q, 0, 5)
window(Q, 9, 0)
Q.prop("prop_table", 2, 3, tall=0.7)
Q.prop("prop_stool", 3, 3, tall=0.5)
Q.prop("prop_broken_chair", 2, 5, tall=0.75)
Q.prop("prop_hearth", 1, 1, tall=0.95, sight=1.0)
Q.prop("prop_jar_shelf", 4, 1, tall=0.55)
Q.prop("prop_cupboard", 5, 1, tall=1.3, sight=1.0)
Q.prop("prop_bed", 7, 4, tall=0.75)
Q.prop("prop_chest", 9, 6, tall=0.6)
Q.prop("prop_desk", 9, 4, tall=0.75)
Q.prop("prop_bookshelf", 8, 1, tall=1.3, sight=1.0)  # against the back wall, the book's shelf
Q.prop("prop_rug", 3, 6, tall=0.45, sight=0.0, walk=True)
Q.thing(id="out", kind="enter", event="", cell=[3, 8], to="village", at=quiet_door)
Q.thing(id="book", kind="hidden", event="hidden_book", cell=[8, 1], once="found_book")
Q.start = [[3, 7]]
Q.save()

# The dog's house: one room; the dog is shut in at the back. In through the window, out by the door.
D = interior("house_dog", 8, 7)
room(D, 0, 0, 7, 6)
D.put(3, 6, "s", 1)
window(D, 5, 0)
window(D, 0, 3)
D.prop("prop_bed", 1, 1, tall=0.75)
D.prop("prop_cupboard", 3, 1, tall=1.3, sight=1.0)
D.prop("prop_table", 2, 3, tall=0.7)
D.prop("prop_broken_chair", 1, 4, tall=0.75)
D.prop("prop_pots", 6, 1, tall=0.6)
D.thing(id="out", kind="enter", event="", cell=[3, 6], to="village", at=west_door)
D.thing(id="dog", kind="dog", event="dog_free", cell=[5, 2], once="met_dog")
D.start = [[5, 3]]
D.save()

# The tavern: one long room with the bar at the back.
T = interior("tavern", 12, 11)
room(T, 0, 0, 11, 10)
T.put(3, 10, "s", 1)
window(T, 6, 0)
window(T, 9, 0)
window(T, 0, 5)
door(T, 0, 8)  # the back door
T.prop("prop_bar", 2, 2, (2, 1), tall=0.8)
T.prop("prop_bar", 4, 2, (2, 1), tall=0.8)
T.prop("prop_ale_barrel", 1, 1, tall=0.8)
T.prop("prop_ale_barrel", 7, 1, tall=0.8)
T.prop("prop_jar_shelf", 4, 1, tall=0.55)
T.prop("prop_hearth", 10, 3, tall=0.95, sight=1.0)
T.prop("prop_long_table", 3, 5, (2, 1), tall=0.7)
T.prop("prop_long_table", 7, 5, (2, 1), tall=0.7)
T.prop("prop_long_table", 7, 8, (2, 1), tall=0.7)
for x, y in [(3, 6), (4, 4), (7, 4), (8, 6), (7, 7), (9, 8)]:
    T.prop("prop_stool", x, y, tall=0.5)
T.prop("prop_broken_chair", 5, 8, tall=0.75)
T.prop("village/prop_barrel", 10, 9, tall=0.7)  # village_in has no barrel of its own
T.thing(id="out", kind="enter", event="", cell=[3, 10], to="village", at=tavern_door)
T.thing(id="chef", kind="settler", event="settler_chef", cell=[9, 3], once="settler_chef")  # at the hearth
T.start = [[3, 9]]
T.save()
