#!/usr/bin/env python3
"""Builds game/data/explore/crypt_v2.json: the crypt redesign prototype ([USER] 2026-10-30, card
builder-crypt-redesign-present: courtyard start, a bridge, big crypt doors, branching paths and rooms inside, several
routes, an outline that is not a rectangle). Graybox, no story. Its own level next to the live crypt.

Flow (x right, y down): courtyard (SW, forest) -> stone bridge east over a chasm -> gatehouse and the big door -> the hall
(branch 1 north, branch 2 east) ->
  north: corridor -> junction room -> grand stair -> throne terrace (the Lich King);
  from the junction: a west stair to the gallery (a dead-end stub, the boost) and a west corridor up to the terrace's west
  end (where the way out is); a bridge east over a drop to the east wing;
  east: passage -> chapel -> stair north -> east wing (the key) -> east corridor up to the terrace's east lobe.
Rooms are carved from rock, so the outline is whatever the rooms make: it winds. Run again: python3 tools/explore/build_crypt_v2.py
"""
import json
import os

HD = "0123456789abcdefghijklmnopqrstuvwxyz"
W, H = 56, 44
terrain = [["r"] * W for _ in range(H)]
height = [[0] * W for _ in range(H)]


def fill(x0, y0, x1, y1, t, h):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            terrain[y][x] = t
            height[y][x] = h


def fe(x0, y0, x1, y1, t, h, p=3.0):
    """A rounded room: a superellipse inside the box, so the outline curves instead of squaring off."""
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    rx, ry = (x1 - x0) / 2.0 + 0.5, (y1 - y0) / 2.0 + 0.5
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if abs((x - cx) / rx) ** p + abs((y - cy) / ry) ** p <= 1.0:
                terrain[y][x] = t
                height[y][x] = h


def pillar(x, y, h):
    if terrain[y][x] not in "r.":
        put(x, y, "u", h)


def put(x, y, t, h=None):
    terrain[y][x] = t
    if h is not None:
        height[y][x] = h


# Courtyard (start, outdoors): two lobes so its edge is not square.
fe(2, 30, 14, 42, "g", 2, 2.4)
fill(6, 27, 11, 31, "g", 2)
fill(1, 35, 3, 39, "g", 2)
for x, y in [(4, 33), (5, 40), (12, 40), (13, 32), (7, 28), (10, 28), (2, 36), (9, 33)]:
    put(x, y, "f")
# The bridge: a narrow stone span over a chasm, one cell wide.
fill(15, 33, 20, 39, "w", 0)
fill(15, 36, 20, 36, "s", 2)
# Gatehouse and the big door, then the hall.
fill(21, 34, 23, 38, "s", 2)
fill(24, 34, 24, 38, "r", 2)
put(24, 36, "u", 2)  # the big door
fe(25, 30, 38, 42, "s", 2, 2.8)
for x, y in [(28, 33), (28, 39), (33, 33), (33, 39), (36, 33), (36, 39)]:
    pillar(x, y, 2)
# North: corridor (with a stub that goes nowhere) up to the junction room.
fill(30, 22, 32, 30, "d", 2)
fill(33, 26, 36, 26, "d", 2)
fill(30, 21, 32, 21, "t", 2)
fe(25, 12, 41, 22, "s", 3, 2.8)
fill(31, 16, 32, 17, "w", 3)
for x, y in [(28, 15), (28, 19), (38, 15), (38, 19)]:
    pillar(x, y, 3)
# West: stair to the gallery, a dead-end stub with the boost, and the west corridor to the terrace.
fe(8, 12, 25, 24, "s", 4, 2.6)
for x, y in [(13, 15), (13, 20), (18, 15), (18, 20), (22, 15), (22, 20)]:
    pillar(x, y, 4)
put(25, 17, "t", 3)
fill(5, 18, 9, 18, "d", 4)  # the stub
fill(12, 9, 14, 12, "d", 4)
fill(12, 8, 14, 8, "t", 4)
fill(12, 7, 14, 7, "t", 5)
# East: passage, chapel, stair north, east wing, bridge from the junction, east corridor.
fill(38, 35, 45, 37, "d", 2)
fe(45, 30, 55, 42, "s", 2, 2.6)
for x, y in [(48, 33), (52, 33), (48, 38), (52, 38)]:
    pillar(x, y, 2)
fill(49, 30, 50, 30, "t", 2)
fe(45, 15, 55, 30, "s", 3, 2.6)
fill(41, 16, 45, 18, "w", 0)
fill(41, 17, 45, 17, "s", 3)
for x, y in [(48, 20), (52, 20), (48, 26), (52, 26)]:
    pillar(x, y, 3)
fill(49, 16, 50, 16, "t", 3)
fill(49, 12, 50, 15, "d", 4)
fill(49, 11, 50, 11, "t", 4)
fill(49, 10, 50, 10, "t", 5)
# Grand stair and the throne terrace.
fill(31, 13, 35, 13, "t", 3)
fill(31, 12, 35, 12, "t", 4)
fill(31, 11, 35, 11, "t", 5)
fe(9, 0, 53, 7, "s", 6, 6.0)
fe(26, 6, 40, 10, "s", 6, 2.4)
fe(45, 6, 53, 9, "s", 6, 2.4)
# Stairs go in last, over the rooms' rounded edges.
for x in range(31, 36):
    put(x, 13, "t", 3); put(x, 12, "t", 4); put(x, 11, "t", 5)
for x in (12, 13, 14):
    put(x, 8, "t", 4); put(x, 7, "t", 5)
for x in (49, 50):
    put(x, 30, "t", 2); put(x, 16, "t", 3); put(x, 11, "t", 4); put(x, 10, "t", 5)
put(25, 17, "t", 3)
for x in (31, 32):
    pass
for x in range(30, 33):
    put(x, 21, "t", 2)
put(38, 2, "u", 6)  # throne
for x, y in [(18, 2), (18, 5), (26, 2), (26, 5), (32, 2), (32, 5), (44, 2), (44, 5)]:
    pillar(x, y, 6)

# Walls: rock rises 2 above its tallest open neighbour; rock with no ground near is void (as build_crypt.py).
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
            height[y][x] = 0
        elif height[y][x] < best + 2:
            height[y][x] = min(8, best + 2)
put(24, 36, "u", 2)
# The outline: rock more than 2 cells from any ground is void, so the map's edge follows its rooms, not a rectangle.
near = [[False] * W for _ in range(H)]
for y in range(H):
    for x in range(W):
        if terrain[y][x] != "r":
            for dy in range(-2, 3):
                for dx in range(-2, 3):
                    if 0 <= x + dx < W and 0 <= y + dy < H:
                        near[y + dy][x + dx] = True
for y in range(H):
    for x in range(W):
        if terrain[y][x] == "r" and not near[y][x]:
            terrain[y][x] = "."
            height[y][x] = 0

zones = [["-"] * W for _ in range(H)]
for y in range(26, H):
    for x in range(0, 21):
        zones[y][x] = "f"
for y in range(0, 26):
    for x in range(0, 14):
        if x < 4:
            zones[y][x] = "-"
data = {
    "name": "crypt_v2", "art_set": "ruins", "strangeness": 0.0, "level": 1, "view": 0, "walls": True,
    "wall_kit": "dungeon", "outdoors": ["forest"],
    "grid": {"w": W, "h": H, "terrain": ["".join(r) for r in terrain], "heights": ["".join(HD[v] for v in r) for r in height],
             "zones": ["".join(r) for r in zones], "zone_key": {"f": "forest", "d": "dungeon"}},
    "start": [[8, 37], [9, 38], [7, 38]],
    "groups": [
        {"id": "junction", "event": "spot_people", "sight": 4, "loot": "food:+6;gold:+10",
         "units": [{"id": "bandit", "cell": [30, 18]}, {"id": "bandit", "cell": [34, 16]}, {"id": "bandit_archer", "cell": [28, 15]}]},
        {"id": "gallery", "event": "spot_people", "sight": 4, "loot": "food:+10",
         "units": [{"id": "bandit_archer", "cell": [16, 16]}, {"id": "bandit", "cell": [19, 19]}]},
        {"id": "east_wing", "event": "spot_people", "sight": 5, "loot": "medicine:+2",
         "units": [{"id": "bandit_archer", "cell": [52, 22]}, {"id": "bandit", "cell": [50, 25]}]},
        {"id": "throne", "event": "spot_boss", "sight": 4, "loot": "medicine:+3;gold:+20;unlock:beat_lich",
         "boss": True, "end": True, "goals": "defeat|exit",
         "exit": [[11, 1], [12, 1], [11, 2], [12, 2], [11, 3], [12, 3]],
         "summon": [[36, 3], [40, 3], [37, 4], [39, 4]],
         "units": [{"id": "lich", "cell": [38, 3]}]},
    ],
    "things": [
        {"id": "gate", "kind": "door", "event": "locked_door", "cell": [24, 36], "floor": "s"},
        {"id": "yard_stone", "kind": "shrine", "event": "shrine", "cell": [9, 30]},
        {"id": "hall_chest", "kind": "chest", "event": "chest", "cell": [35, 40]},
        {"id": "gallery_boost", "kind": "boost", "event": "hp:2", "cell": [5, 18]},
        {"id": "chapel_chest", "kind": "chest", "event": "chest", "cell": [53, 39]},
        {"id": "wing_key", "kind": "key", "event": "crypt_key", "cell": [53, 28]},
        {"id": "way_out", "kind": "exit", "event": "exit", "cell": [11, 2]},
        {"id": "up_stair", "kind": "enter", "event": "", "cell": [4, 38], "to": "snow_pass", "at": [9, 8]},
    ],
}
out = os.path.join(os.path.dirname(__file__), "..", "..", "game", "data", "explore", "crypt_v2.json")
with open(out, "w") as f:
    json.dump(data, f, indent=1)
    f.write("\n")
print("wrote", os.path.normpath(out), W, "x", H)
