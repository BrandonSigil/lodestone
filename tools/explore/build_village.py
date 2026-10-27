#!/usr/bin/env python3
"""Builds the starting village explore maps: the hero's home, the village outside, and two interiors.

- home:     the hero's one-room cottage (the run starts here); its door leads out to the village.
- village:  a quiet, half-empty village around a big flat square: town hall up a terrace at the back,
            two homes up a bluff in the north-east, the smithy on the river bank with the weapon rack,
            the tavern, five more homes, a gate out to the trail at the front. Fully visible (no fog).
- house_ne: an ordinary home a little off the square, with an inner room; the hidden book sits on a
            shelf against its back wall, out of sight from the door (docs/design/empty-village.md s7).
- tavern:   the tavern's ground floor.

Buildings and furniture are placed props (CombatGrid.props) drawn from the village and village_in tile
sets (art cut by tools/art/village_cut.py). Interiors are floors with walls of rock terrain; the walls
nearest the camera stand only one level tall so the room reads from above, like a cutaway.

Run again after editing: python3 tools/explore/build_village.py
"""
import json
import os

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "game", "data", "explore")


class Map:
    def __init__(self, name, w, h, t="g", hgt=1, art_set="village"):
        self.name, self.w, self.h = name, w, h
        self.terrain = [[t] * w for _ in range(h)]
        self.height = [[hgt] * w for _ in range(h)]
        self.zones = [["-"] * w for _ in range(h)]
        self.props, self.things, self.start = [], [], []
        self.art_set = art_set

    def fill(self, x0, y0, x1, y1, t=None, h=None):
        """Inclusive rect; None keeps what is there."""
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if t is not None:
                    self.terrain[y][x] = t
                if h is not None:
                    self.height[y][x] = h

    def put(self, x, y, t=None, h=None):
        self.fill(x, y, x, y, t, h)

    def prop(self, sprite, x, y, foot=(1, 1), tall=0.0, sight=0.0, walk=False):
        self.props.append({"sprite": sprite, "cell": [x, y], "foot": list(foot), "tall": tall,
                           "sight": sight, "walk": walk})

    def building(self, sprite, x, y, fx, fy, door_dx):
        """A whole house on an fx x fy footprint; returns the cell in front of its door (left wall)."""
        self.prop(sprite, x, y, (fx, fy), 0.0, 3.0)
        return [x + door_dx, y + fy]

    def thing(self, **t):
        self.things.append(t)

    def save(self, view=0, turn=False, fog=True):
        data = {
            "name": self.name, "art_set": self.art_set, "strangeness": 0.0, "view": view, "turn": turn,
            "fog": fog,
            "grid": {"w": self.w, "h": self.h,
                     "terrain": ["".join(r) for r in self.terrain],
                     "heights": ["".join(str(v) for v in r) for r in self.height],
                     "props": self.props},
            "start": self.start, "groups": [], "things": self.things,
        }
        if any(z != "-" for r in self.zones for z in r):
            data["grid"]["zones"] = ["".join(r) for r in self.zones]
            data["grid"]["zone_key"] = {"i": "village_in"}
        path = os.path.normpath(os.path.join(OUT_DIR, self.name + ".json"))
        with open(path, "w") as f:
            json.dump(data, f, indent=1)
            f.write("\n")
        print("wrote", path, "%dx%d" % (self.w, self.h), len(self.props), "props", len(self.things), "things")


def room(m, x0, y0, x1, y1, floor="s", h=1, wall=2):
    """A walled room on [x0..x1] x [y0..y1] (walls included). Back walls (low x, low y) stand `wall`
    levels over the floor; front walls one level, so the camera sees in."""
    m.fill(x0, y0, x1, y1, floor, h)
    for x in range(x0, x1 + 1):
        m.put(x, y0, "r", h + wall)
        m.put(x, y1, "r", h + 1)
    for y in range(y0, y1 + 1):
        m.put(x0, y, "r", h + wall)
        m.put(x1, y, "r", h + 1)


# --- the village ------------------------------------------------------------------------------------
# Rot 0: +x runs down-right on screen, +y down-left; the front (nearest the camera) is high x + y.
# Every building's door is on its left front wall, so it opens toward +y.
# Levels: 0 the stream bed, 1 the flat ground (square, lanes, yards), 2 the town hall terrace and the
# stairs up to it, 3 the bluff in the north-east. Each step is one level, so every climb reads from above.

V = Map("village", 40, 38)
# Ground: grass at level 1, a ring of trees, a stream down the west side.
V.fill(0, 0, 39, 37, "g", 1)
for y in range(38):
    for x in range(40):
        edge = min(x, y, 39 - x, 37 - y)
        if edge == 0 or (edge == 1 and (x * 7 + y * 3) % 3 != 0) or (edge == 2 and (x * 5 + y * 11) % 5 == 0):
            V.put(x, y, "f")
V.fill(3, 0, 4, 37, "w", 0)  # the stream
V.fill(2, 0, 2, 37, "g", 1)  # its bank
V.fill(3, 21, 4, 21, "s", 1)  # footbridge on the west lane
V.fill(0, 0, 1, 37, "f", 1)

# The bluff in the north-east: a flat top at level 3, reached by a two-high stair from the east lane.
V.fill(30, 3, 37, 11, "g", 3)
V.fill(28, 7, 29, 9, "t", 2)  # stairs up from the lane to the bluff
V.fill(30, 6, 30, 8, "d")  # up-top path from the stairs (keeps level 3)
V.fill(31, 6, 35, 6, "d")  # along the front of the two bluff homes
V.prop("prop_fence", 34, 8, tall=0.6)
V.prop("prop_hay", 37, 7, tall=0.65)
V.prop("prop_tree", 36, 10, tall=1.6, sight=1.0)
V.prop("prop_tree", 33, 10, tall=1.6, sight=1.0)
quiet_door = V.building("b_home_c", 30, 3, 4, 3, 1)  # the quiet house (the hidden book), on the bluff
bluff_door = V.building("b_home_a", 34, 3, 3, 3, 1)  # a second home on the bluff

# Town square: one big flat floor at level 1, open in the middle; the well is the only centrepiece.
V.fill(12, 14, 27, 25, "s", 1)
V.prop("prop_well", 20, 19, tall=1.25, sight=1.0)
V.prop("prop_stall", 14, 15, tall=1.2)
V.prop("prop_crates", 15, 15, tall=0.8)
V.prop("prop_stall", 25, 23, tall=1.2)
V.prop("prop_barrel", 24, 23, tall=0.7)
for x, y in [(12, 14), (27, 14), (12, 25), (27, 25)]:
    V.prop("prop_lamp", x, y, tall=1.5)
V.prop("prop_bench", 16, 21, tall=0.6)
V.prop("prop_bench", 23, 17, tall=0.6)
V.prop("prop_planter", 17, 23, tall=0.8)
V.prop("prop_planter", 23, 21, tall=0.8)

# Lanes (packed dirt) out of the square.
V.fill(19, 13, 22, 13, "d")  # up to the town hall stair
V.fill(19, 26, 22, 37, "d")  # south road to the gate
V.fill(5, 21, 11, 22, "d")  # west lane over the bridge
V.fill(27, 19, 36, 20, "d")  # east lane past the tavern
V.fill(27, 9, 27, 13, "d")  # north lane up to the bluff stairs

# Town hall on a raised terrace at the back (level 2), a stair down to the square.
V.fill(14, 3, 25, 11, "g", 2)
V.fill(17, 10, 23, 11, "s", 2)
V.fill(19, 12, 22, 12, "t", 2)
hall_door = V.building("b_townhall", 17, 5, 5, 5, 3)
V.prop("prop_board", 23, 10, tall=1.0)
V.prop("prop_tree", 15, 4, tall=1.6, sight=1.0)
V.prop("prop_tree", 24, 4, tall=1.6, sight=1.0)
V.prop("prop_planter", 16, 10, tall=0.8)

# Smithy on the river bank: the stream is two cells west of it, and its yard opens onto the square.
smithy_door = V.building("b_smithy", 6, 10, 3, 4, 1)
V.fill(9, 10, 11, 14, "s")
V.fill(7, 15, 11, 15, "d")  # from the smithy door along the yard to the square
V.prop("prop_grindstone", 9, 10, tall=0.85)
V.prop("prop_rack", 10, 12, tall=1.0)
V.prop("prop_anvil", 10, 14, tall=0.75)
V.prop("prop_barrel", 11, 10, tall=0.7)

# Tavern east of the square.
tavern_door = V.building("b_tavern", 29, 15, 4, 4, 1)
V.prop("prop_barrel", 33, 16, tall=0.7)
V.prop("prop_barrel", 33, 17, tall=0.7)
V.prop("prop_crates", 34, 15, tall=0.8)
V.prop("prop_bench", 28, 17, tall=0.6)

# Homes. The hero's cottage south-west of the square (the run starts inside it).
hero_door = V.building("b_home_hero", 10, 26, 3, 3, 1)
V.fill(11, 29, 11, 31, "d")
V.fill(11, 31, 18, 31, "d")  # path from the cottage to the south road
V.prop("prop_fence", 9, 30, tall=0.6)
V.prop("prop_fence", 13, 30, tall=0.6)
V.prop("prop_hay", 14, 27, tall=0.65)
V.prop("prop_stump", 9, 25, tall=0.5)

# More homes on the west bank and in the south-east (doors stuck for now).
west_door = V.building("b_home_a", 6, 17, 3, 3, 1)
south_east_door = V.building("b_home_b", 29, 24, 4, 3, 2)
V.fill(23, 27, 31, 27, "d")  # lane from the south road to the south-east home
far_door = V.building("b_home_a", 31, 30, 3, 3, 1)
V.fill(32, 33, 32, 34, "d")
V.fill(23, 34, 32, 34, "d")

# Fifty years of quiet: a broken cart in the lane, fallen fence, crumbled garden walls, stumps.
V.prop("prop_cart", 24, 29, tall=0.8)
V.prop("prop_fence", 25, 30, tall=0.6)
V.prop("prop_stump", 36, 25, tall=0.5)
V.prop("prop_stump", 8, 33, tall=0.5)
for x, y in [(6, 27), (7, 27), (24, 31)]:
    V.put(x, y, "u")
for x, y in [(34, 27), (12, 6), (6, 31), (23, 36), (36, 34)]:
    V.prop("prop_tree", x, y, tall=1.6, sight=1.0)
V.fill(5, 25, 8, 28, "d")  # an old yard gone to dirt
V.fill(33, 22, 36, 23, "u")  # tumbled wall along the east lane
V.put(35, 22, "d")

# The gate: the south road runs out of the village to the trail.
V.thing(id="gate", kind="exit", event="exit", cell=[20, 37])
V.put(20, 37, "d")
V.put(21, 37, "d")

V.thing(id="hero_home", kind="enter", event="", cell=hero_door, to="home", at=[3, 5])
V.thing(id="quiet_house", kind="enter", event="", cell=quiet_door, to="house_ne", at=[3, 7])
V.thing(id="tavern_door", kind="enter", event="", cell=tavern_door, to="tavern", at=[3, 9])
V.thing(id="hall_door", kind="enter", event="door_stuck", cell=hall_door)
V.thing(id="smithy_door", kind="enter", event="door_stuck", cell=smithy_door)
V.thing(id="west_door", kind="enter", event="door_stuck", cell=west_door)
V.thing(id="se_door", kind="enter", event="door_stuck", cell=south_east_door)
V.thing(id="far_door", kind="enter", event="door_stuck", cell=far_door)
V.thing(id="bluff_door", kind="enter", event="door_stuck", cell=bluff_door)
V.thing(id="weapon_rack", kind="rack", event="smithy_rack", cell=[10, 12],
        once="weapon_sword|weapon_daggers|weapon_bow")
for c in [hero_door, quiet_door, tavern_door, hall_door, smithy_door, west_door, south_east_door, far_door,
          bluff_door]:
    if V.terrain[c[1]][c[0]] in "gfu":
        V.put(c[0], c[1], "d")
V.start = [hero_door]
V.save(fog=False)  # the whole town is in view: fog of war is for the bigger maps


# --- interiors (the village_in set: plank floors, plaster walls) ----------------------------------------

def interior(name, w, h):
    m = Map(name, w, h, ".", 0, "village_in")
    return m


# The hero's cottage: one room.
H = interior("home", 8, 7)
room(H, 0, 0, 7, 6)
H.put(3, 6, "s", 1)  # doorway in the front-left wall
H.prop("prop_bed", 1, 1, tall=0.75)
H.prop("prop_hearth", 4, 1, tall=0.95, sight=1.0)
H.prop("prop_cupboard", 6, 1, tall=1.3, sight=1.0)
H.prop("prop_table", 4, 3, tall=0.7)
H.prop("prop_chair", 5, 3, tall=0.75)
H.prop("prop_rug", 2, 4, tall=0.45, sight=0.0, walk=True)
H.prop("prop_chest", 1, 3, tall=0.6)
H.prop("prop_pots", 6, 4, tall=0.6)
H.thing(id="out", kind="enter", event="", cell=[3, 6], to="village", at=hero_door)
H.start = [[3, 4]]
H.save()

# The quiet house: a front room and an inner room behind a wall, the book on a shelf at the back.
Q = interior("house_ne", 11, 9)
room(Q, 0, 0, 10, 8)
Q.fill(6, 0, 6, 8, "r", 3)  # inner wall between the front room (x < 6) and the inner room (x > 6)
Q.put(6, 8, "r", 2)
Q.put(6, 6, "s", 1)  # gap into the inner room, near the front
Q.put(3, 8, "s", 1)  # front door
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

# The tavern: one long room with the bar at the back.
T = interior("tavern", 12, 11)
room(T, 0, 0, 11, 10)
T.put(3, 10, "s", 1)
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
T.prop("prop_barrel", 10, 9, tall=0.7)
T.thing(id="out", kind="enter", event="", cell=[3, 10], to="village", at=tavern_door)
T.start = [[3, 9]]
T.save()
