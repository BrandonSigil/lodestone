#!/usr/bin/env python3
"""Builds game/data/explore/crypt.json, the first walkable exploration map (graybox layout test).

Layout follows the reference Brandon posted (layout only, not style): an entry yard in front, a corridor
with a locked door, a side crypt, a sunken water channel with a raised bridge, a cave room, a central
plaza on a terrace, a graveyard with a watch tower, and a throne terrace up a grand stair at the back.

Rooms are carved out of rock; every rock cell is then raised 2 levels above its tallest open neighbour,
so walls stand over the floor and block sight. Run it again after editing: python3 tools/explore/build_crypt.py
"""
import json
import os

W, H = 34, 30
LETTERS = "gfwrdstu"  # grass forest water rock road stone stairs ruin

terrain = [["r"] * W for _ in range(H)]
height = [[0] * W for _ in range(H)]


def fill(x0, y0, x1, y1, t, h):
    """Inclusive rect."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            terrain[y][x] = t
            height[y][x] = h


def put(x, y, t, h=None):
    terrain[y][x] = t
    if h is not None:
        height[y][x] = h


# 1. Entry yard (front corner), grass at level 1 with a few trees.
fill(21, 22, 31, 28, "g", 1)
for x, y in [(30, 23), (31, 24), (22, 27), (23, 28), (31, 28)]:
    put(x, y, "f")
# Low meadow running west from the yard toward the water.
fill(12, 23, 20, 27, "g", 1)
for x, y in [(13, 26), (14, 27), (16, 24)]:
    put(x, y, "f")

# 2. Road corridor north from the yard, locked door across it.
fill(25, 15, 27, 21, "d", 1)
fill(25, 14, 27, 14, "t", 2)  # stair up to the plaza
put(25, 18, "u", 1)
put(27, 18, "u", 1)
put(26, 18, "u", 1)  # the door (a thing turns it into floor when opened)

# 3. Side crypt east of the corridor, behind a sealed door.
fill(29, 12, 32, 17, "s", 1)
put(28, 15, "u", 1)  # crypt door
put(30, 13, "r", 1)  # sarcophagi
put(30, 16, "r", 1)

# 4. Central plaza on a terrace (level 3), pillars and a sunken pool.
fill(12, 8, 27, 13, "s", 3)
for x, y in [(14, 9), (14, 12), (21, 9), (21, 12), (25, 9), (25, 12)]:
    put(x, y, "u")
fill(17, 10, 18, 11, "w", 2)

# 5. West water channel: a high pool spilling into a low stream, crossed by a raised stone bridge.
fill(5, 14, 10, 16, "w", 2)
fill(5, 17, 10, 28, "w", 0)
fill(4, 20, 11, 20, "s", 2)  # the bridge
fill(11, 19, 11, 27, "g", 1)  # bank between meadow and bridge

# 6. Cave room west of the channel (level 2) with trees, stairs up to the west terrace.
fill(1, 15, 4, 24, "g", 2)
for x, y in [(1, 16), (2, 23), (1, 22), (4, 15)]:
    put(x, y, "f")
put(2, 14, "t", 3)  # one-wide stair, so the rubble on it closes the west route

# 7. West terrace (level 4) joining the plaza from the side.
fill(1, 8, 11, 13, "g", 4)
for x, y in [(2, 9), (3, 11), (6, 9), (9, 12)]:
    put(x, y, "f")
fill(4, 13, 11, 13, "r", 6)  # low wall along the channel side
fill(2, 13, 3, 13, "g", 4)

# 8. Graveyard terrace east (level 4) with a watch tower (level 6).
fill(28, 3, 32, 10, "g", 4)
put(28, 10, "t", 4)  # stair from the plaza edge
put(28, 9, "t", 4)
for x, y in [(29, 7), (31, 7), (29, 9), (31, 9)]:
    put(x, y, "r", 4)  # gravestones
for x, y in [(32, 5), (28, 3)]:
    put(x, y, "f")
fill(30, 3, 31, 4, "s", 6)  # tower top
put(29, 4, "t", 5)  # tower stair

# 9. Grand stair and the throne terrace at the back (level 6).
fill(17, 7, 19, 7, "t", 4)
fill(17, 6, 19, 6, "t", 5)
fill(12, 1, 24, 5, "s", 6)
put(18, 1, "u", 6)  # throne
for x, y in [(14, 2), (22, 2), (14, 4), (22, 4)]:
    put(x, y, "u")

# Walls: rock rises 2 above its tallest open neighbour (nothing to stand on, blocks sight).
for y in range(H):
    for x in range(W):
        if terrain[y][x] != "r":
            continue
        best = None
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and terrain[ny][nx] != "r":
                    best = max(best or 0, height[ny][nx])
        if best is None:
            height[y][x] = 0  # deep rock nobody sees; fog keeps it hidden
        elif height[y][x] < best + 2:
            height[y][x] = min(8, best + 2)
# Sarcophagi and gravestones placed above are rock at floor height; keep them low.
for x, y in [(30, 13), (30, 16)]:
    height[y][x] = 1
for x, y in [(29, 7), (31, 7), (29, 9), (31, 9)]:
    height[y][x] = 4

# Tile sets: the map is ruins (plaza, graveyard, throne); the yard, meadow, water channel and west
# terrace are outdoors (forest, the base set); the corridor, side crypt and cave are dungeon.
# Later rects win. Rock walls take the set of the rect they sit in.
zones = [["-"] * W for _ in range(H)]
ZONE_KEY = {"f": "forest", "d": "dungeon"}  # "-" = the map's own set (ruins)


def zone(x0, y0, x1, y1, z):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            zones[y][x] = z


zone(11, 19, W - 1, H - 1, "f")  # yard and meadow
zone(0, 8, 11, H - 1, "f")  # channel and west terrace
zone(0, 14, 4, 24, "d")  # cave room
zone(24, 11, W - 1, 21, "d")  # corridor and side crypt

data = {
    "name": "crypt",
    "art_set": "ruins",
    "strangeness": 0.0,
    "view": 0,
    "grid": {
        "w": W,
        "h": H,
        "terrain": ["".join(row) for row in terrain],
        "heights": ["".join(str(v) for v in row) for row in height],
        "zones": ["".join(row) for row in zones],
        "zone_key": ZONE_KEY,
    },
    "start": [[27, 26], [28, 27], [26, 27]],
    "groups": [
        {"id": "plaza", "event": "spot_people", "sight": 4, "loot": "food:+6;gold:+10",
         "units": [{"id": "bandit", "cell": [19, 9]}, {"id": "bandit", "cell": [20, 12]}, {"id": "bandit_archer", "cell": [16, 8]}]},
        {"id": "cave", "event": "spot_beasts", "sight": 4, "loot": "food:+10",
         "units": [{"id": "wolf", "cell": [2, 18]}, {"id": "wolf", "cell": [3, 20]}]},
        {"id": "tower", "event": "spot_people", "sight": 5, "loot": "medicine:+2",
         "units": [{"id": "bandit_archer", "cell": [30, 3]}, {"id": "bandit", "cell": [30, 8]}]},
        {"id": "throne", "event": "spot_strange", "sight": 4, "loot": "medicine:+3;gold:+20",
         "units": [{"id": "strange_thing", "cell": [18, 2]}, {"id": "strange_thing", "cell": [16, 4]}, {"id": "wolf", "cell": [20, 4]}]},
    ],
    "things": [
        {"id": "gate", "kind": "door", "event": "locked_door", "cell": [26, 18], "floor": "d"},
        {"id": "crypt_door", "kind": "door", "event": "sealed_door", "cell": [28, 15], "floor": "s"},
        {"id": "crypt_chest", "kind": "chest", "event": "chest", "cell": [31, 14]},
        {"id": "yard_stone", "kind": "shrine", "event": "shrine", "cell": [24, 24]},
        {"id": "cave_rubble", "kind": "rubble", "event": "rubble", "cell": [2, 14], "floor": "t"},
        {"id": "tower_chest", "kind": "chest", "event": "chest", "cell": [31, 3]},
        {"id": "way_out", "kind": "exit", "event": "exit", "cell": [13, 2]},
    ],
}
# The rubble sits on the cave stair: it blocks the west route until cleared.
terrain[14][2] = "u"
data["grid"]["terrain"] = ["".join(row) for row in terrain]

out = os.path.join(os.path.dirname(__file__), "..", "..", "game", "data", "explore", "crypt.json")
os.makedirs(os.path.dirname(out), exist_ok=True)
with open(out, "w") as f:
    json.dump(data, f, indent=1)
    f.write("\n")
print("wrote", os.path.normpath(out))
for y in range(H):
    print("".join(terrain[y]), " ", "".join(str(v) for v in height[y]))
