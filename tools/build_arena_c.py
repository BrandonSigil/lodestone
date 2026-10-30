#!/usr/bin/env python3
"""Builds game/data/maps/arena_c.json: the scale-C test arena (docs/design/scale-study.md), 21 x 18, for a three-piece
party (a knight, a fast rogue, a slow ranged mage) against 4 or 5 foes. Graybox, no story.

Party zone: x 0-2, y 7-10 (west). Foe zone: x 18-20, y 6-11 (east). The start gap is 18 cells.
Terrain: open grass; forest clumps for cover (they take 1 off ranged hits); rock blocks to break sight; a central
ridge with gaps (the middle lane stays open, two flank lanes run past its ends); a low hill behind each side for the
mage and the foes' archer; the party's flank steps up in single levels so every piece can climb.
Run again after editing: python3 tools/build_arena_c.py
"""
import json

W, H = 21, 18
terrain = [["g"] * W for _ in range(H)]
height = [[0] * W for _ in range(H)]


def fill(x0, y0, x1, y1, t=None, h=None):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if t:
                terrain[y][x] = t
            if h is not None:
                height[y][x] = h


# The central ridge: rock walls with gaps, a lane in the middle and a flank lane each side.
fill(9, 0, 11, 4, "r", 3)
fill(9, 13, 11, 17, "r", 3)
fill(9, 6, 10, 6, "r", 2)  # a low wall in the middle lane: cover, climbable
fill(10, 11, 11, 11, "r", 2)
# Rock blocks that break sight on each side.
for x, y in [(5, 4), (5, 13), (15, 4), (15, 13), (13, 8), (7, 9)]:
    fill(x, y, x, y, "r", 2)
# Forest clumps (cover from ranged).
for x0, y0, x1, y1 in [(4, 7, 5, 8), (14, 9, 15, 10), (6, 15, 7, 16), (13, 1, 14, 2), (7, 1, 7, 2), (14, 15, 15, 16)]:
    fill(x0, y0, x1, y1, "f", 0)
# Hills: a stepped one behind the party's flank (mage perch), a mirrored one behind the foes.
for (x, y, h) in [(1, 13, 1), (2, 13, 1), (1, 14, 2), (2, 14, 2), (1, 15, 2), (2, 15, 2), (3, 14, 1), (3, 15, 1), (1, 16, 1), (2, 16, 1)]:
    height[y][x] = h
for (x, y, h) in [(19, 3, 1), (18, 3, 1), (19, 2, 2), (18, 2, 2), (19, 1, 2), (18, 1, 2), (17, 2, 1), (17, 1, 1), (19, 0, 1), (18, 0, 1)]:
    height[y][x] = h
# A road across the middle: easy walking, no cover.
for x in range(0, W):
    terrain[8][x] = terrain[8][x] if terrain[8][x] in "rf" else "d"
    terrain[9][x] = terrain[9][x] if terrain[9][x] in "rf" else "d"

HD = "0123456789abcdefghijklmnopqrstuvwxyz"
base = json.load(open("game/data/maps/ridge.json"))
base["name"] = "arena_c"
base["map"] = {"w": W, "h": H, "terrain": ["".join(r) for r in terrain], "heights": ["".join(HD[v] for v in r) for r in height]}
base["party"] = [{"id": "lead", "x": 1, "y": 8}, {"id": "stardrop", "x": 0, "y": 9}, {"id": "hunter", "x": 1, "y": 10}]
base["enemies"] = [{"id": "bandit", "x": 19, "y": 7}, {"id": "bandit", "x": 19, "y": 9}, {"id": "bandit_archer", "x": 19, "y": 2},
                   {"id": "wolf", "x": 18, "y": 11}, {"id": "bandit", "x": 20, "y": 8}]
json.dump(base, open("game/data/maps/arena_c.json", "w"), indent=1)
print("wrote game/data/maps/arena_c.json", W, "x", H)
