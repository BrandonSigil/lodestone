#!/usr/bin/env python3
"""Example battle maps that blend two tile sets on one floating island (combat tester maps).

    python3 tools/maps/build_blend_maps.py        # writes game/data/maps/<name>.json

Each map is an irregular island (VOID '.' cells cut its outline), the map's own tile set on one side
and a second set painted onto the other side as a zone. Heights, stairs and the route between the two
halves are checked: every party and enemy cell must be reachable for a jump-1 piece.
Layout only; no names or text beyond the map ids.
"""
from __future__ import annotations

import json
import math
import random
from collections import deque
from pathlib import Path

OUT = Path(__file__).resolve().parents[2] / "game" / "data" / "maps"
BLOCKED = set("ru.")  # rock, ruin, void
STAIRS_CLIMB = 2


class Map:
    def __init__(self, name, w, h, seed):
        self.name, self.w, self.h = name, w, h
        self.rng = random.Random(seed)
        self.t = [["g"] * w for _ in range(h)]
        self.hgt = [[1] * w for _ in range(h)]
        self.zone = [[""] * w for _ in range(h)]

    def cells(self):
        for y in range(self.h):
            for x in range(self.w):
                yield x, y

    def island(self, wobble=0.22, bites=3):
        """Keep an irregular blob: an ellipse with a noisy rim and a few bites out of the edge."""
        cx, cy = (self.w - 1) / 2, (self.h - 1) / 2
        phase = [self.rng.uniform(0, math.tau) for _ in range(3)]
        bite = [(self.rng.uniform(0, math.tau), self.rng.uniform(0.18, 0.3)) for _ in range(bites)]
        for x, y in self.cells():
            dx, dy = (x - cx) / (self.w / 2), (y - cy) / (self.h / 2)
            ang, r = math.atan2(dy, dx), math.hypot(dx, dy)
            rim = 1.08 + wobble * (math.sin(3 * ang + phase[0]) * 0.5 + math.sin(5 * ang + phase[1]) * 0.3
                                   + math.sin(7 * ang + phase[2]) * 0.2)
            for a, size in bite:
                if abs(math.remainder(ang - a, math.tau)) < size * 1.6:
                    rim -= size
            if r > rim:
                self.t[y][x] = "."

    def fill(self, x0, y0, x1, y1, t=None, h=None, zone=None, keep_void=True):
        for y in range(max(0, y0), min(self.h, y1 + 1)):
            for x in range(max(0, x0), min(self.w, x1 + 1)):
                if keep_void and self.t[y][x] == ".":
                    continue
                if t is not None:
                    self.t[y][x] = t
                if h is not None:
                    self.hgt[y][x] = h
                if zone is not None:
                    self.zone[y][x] = zone

    def scatter(self, t, where, chance):
        for x, y in self.cells():
            if self.t[y][x] == "g" and where(x, y) and self.rng.random() < chance:
                self.t[y][x] = t

    def stairs_on_jumps(self):
        """Stairs on the low side of any 2-level jump between walkable cells (keeps ledges crossable)."""
        for x, y in self.cells():
            if self.t[y][x] not in "gd":
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < self.w and 0 <= ny < self.h and self.t[ny][nx] not in BLOCKED:
                    if self.hgt[ny][nx] - self.hgt[y][x] in (2, 3):
                        self.t[y][x] = "t"
                        break

    def reachable(self, start):
        def ok(c):
            x, y = c
            return 0 <= x < self.w and 0 <= y < self.h and self.t[y][x] not in BLOCKED
        seen, q = {start}, deque([start])
        while q:
            x, y = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n in seen or not ok(n):
                    continue
                limit = 1 + (STAIRS_CLIMB if "t" in (self.t[y][x], self.t[n[1]][n[0]]) else 0)
                if abs(self.hgt[n[1]][n[0]] - self.hgt[y][x]) <= limit:
                    seen.add(n)
                    q.append(n)
        return seen

    def save(self, art_set, party, enemies, strangeness=0.0):
        for _, (x, y) in party + enemies:  # pieces always stand on open ground
            if self.t[y][x] in BLOCKED or self.t[y][x] == "w":
                self.t[y][x] = "g"
        self.stairs_on_jumps()
        reach = self.reachable(party[0][1])
        for _, c in party + enemies:
            assert c in reach, "%s: %s not reachable from the party" % (self.name, c)
        names = sorted({z for row in self.zone for z in row if z})
        key = {chr(97 + i): n for i, n in enumerate(names)}
        inv = {n: k for k, n in key.items()}
        d = {
            "name": self.name, "seed": 1, "view": 0, "strangeness": strangeness, "art_set": art_set,
            "counters": True, "mercy": True, "extra_enemies": 0,
            "supplies": {"food": 10, "medicine": 3},
            "party_mods": {"attack": 0, "damage": 0, "defense": 0, "hp_pct": 100, "move": 0},
            "enemy_mods": {"attack": 0, "damage": 0, "defense": 0, "hp_pct": 100, "move": 0},
            "party": [{"id": i, "x": x, "y": y} for i, (x, y) in party],
            "enemies": [{"id": i, "x": x, "y": y} for i, (x, y) in enemies],
            "map": {"w": self.w, "h": self.h,
                    "terrain": ["".join(r) for r in self.t],
                    "heights": ["".join(str(v) for v in r) for r in self.hgt],
                    "zones": ["".join(inv[z] if z else "-" for z in r) for r in self.zone],
                    "zone_key": key},
        }
        path = OUT / (self.name + ".json")
        path.write_text(json.dumps(d, indent="\t") + "\n")
        print("wrote", path)


PARTY = ["lead", "stardrop", "hunter", "wizard"]


def forest_to_castle():
    """West: forest trail climbing gently. A stream cuts north to south and spills off the island.
    East: a broken castle on a raised stone shelf (ruins set), walls with a gate gap and a stair up."""
    m = Map("blend_forest_castle", 16, 12, 11)
    m.island(wobble=0.18, bites=2)
    for x, y in m.cells():
        m.hgt[y][x] = 1 + (1 if x > 3 and (x + y) % 5 == 0 else 0)
    m.scatter("f", lambda x, y: x < 7, 0.28)
    for x in range(0, 8):  # trail
        m.fill(x, 5, x, 6, t="d", h=1)
    m.fill(7, 0, 8, 11, t="w", h=0)  # stream
    m.fill(7, 5, 8, 6, t="d", h=1)  # ford
    m.fill(9, 0, 15, 11, h=3, zone="ruins")  # castle shelf
    m.fill(9, 0, 15, 11, t="s")
    m.fill(9, 5, 9, 6, t="t", h=1)  # stair up from the ford
    for x, y in [(11, 1), (11, 2), (11, 3), (11, 8), (11, 9), (11, 10), (12, 1), (13, 1), (14, 2), (12, 10), (13, 10)]:
        if m.t[y][x] != ".":
            m.t[y][x] = "u"  # broken walls; the gap at rows 4-7 is the gate
    m.fill(13, 4, 14, 7, h=4)  # the keep's floor, one step up
    m.stairs_on_jumps()
    party = list(zip(PARTY, [(2, 5), (1, 6), (2, 4), (1, 5)]))
    enemies = [("bandit", (12, 5)), ("bandit", (12, 6)), ("bandit_archer", (14, 5)), ("bandit_archer", (13, 7))]
    m.save("", party, enemies)


def mountain_to_marsh():
    """North-west: snowy highland terraces with pines and rock. They step down by stairs to a
    south-east marsh (marsh set) of shallow water, reeds and boardwalk mud."""
    m = Map("blend_mountain_marsh", 16, 12, 23)
    m.island(wobble=0.24, bites=3)
    for x, y in m.cells():
        d = x + y  # high in the north-west corner
        m.hgt[y][x] = max(0, min(6, 6 - d // 3))
        m.zone[y][x] = "snow" if d < 13 else "marsh"
    m.scatter("f", lambda x, y: x + y < 11, 0.22)
    m.scatter("r", lambda x, y: x + y < 8, 0.15)
    for x, y in m.cells():
        if x + y >= 15 and m.t[y][x] == "g" and m.rng.random() < 0.45:
            m.t[y][x], m.hgt[y][x] = "w", 0
        elif x + y >= 13 and m.t[y][x] == "g" and m.rng.random() < 0.25:
            m.t[y][x] = "f"  # reeds and willows
    for k in range(0, 16):  # a switchback path from the peak to the marsh
        x, y = min(15, k), min(11, max(0, k - 2))
        if m.t[y][x] != ".":
            m.t[y][x] = "d" if m.t[y][x] != "w" else "d"
            m.hgt[y][x] = max(0, min(6, 6 - (x + y) // 3))
    m.stairs_on_jumps()
    party = [(PARTY[i], c) for i, c in enumerate([(3, 1), (4, 2), (3, 3), (5, 2)])]
    enemies = [("wolf", (12, 8)), ("wolf", (11, 9)), ("bandit", (10, 10)), ("strange_thing", (9, 9))]
    for _, (x, y) in party + enemies:
        if m.t[y][x] in BLOCKED or m.t[y][x] == "w":
            m.t[y][x] = "g"
    m.stairs_on_jumps()
    m.save("", party, enemies)


def farm_to_crypt():
    """West: a hamlet's fields and fences (farmland set). East: the ground sinks into a crypt (dungeon
    set): a sunken stone yard two levels down, ruin walls, a stair in."""
    m = Map("blend_farm_crypt", 15, 11, 37)
    m.island(wobble=0.2, bites=2)
    m.fill(0, 0, 7, 10, h=2, zone="farmland")
    m.scatter("f", lambda x, y: x < 7 and y < 3, 0.5)  # orchard
    for y in range(4, 9):
        for x in range(1, 6):
            if m.t[y][x] == "g" and x % 2 == 0:
                m.t[y][x] = "s"  # tilled rows (the farmland set's hard floor is soil rows)
    m.fill(0, 5, 8, 5, t="d", h=2)  # cart track
    m.fill(8, 0, 14, 10, t="s", h=0, zone="dungeon")
    m.fill(8, 5, 8, 5, t="t", h=0)
    for x, y in [(9, 1), (10, 1), (12, 1), (13, 2), (9, 9), (10, 9), (12, 9), (13, 8), (11, 4), (11, 6)]:
        if m.t[y][x] != ".":
            m.t[y][x] = "u"
    m.fill(12, 4, 13, 6, t="w", h=0)  # a dark pool in the crypt yard
    m.stairs_on_jumps()
    party = list(zip(PARTY, [(2, 5), (1, 5), (3, 6), (2, 4)]))
    enemies = [("bandit_archer", (13, 3)), ("strange_thing", (10, 5)), ("bandit", (12, 7)), ("wolf", (10, 3))]
    m.save("farmland", party, enemies)


def canyon_to_crystal():
    """West: red canyon shelves with spires (canyon set). East, past a dry gully: the ground turns to
    glassy crystal wilds (crystal set), stranger colours (strangeness 0.4)."""
    m = Map("blend_canyon_crystal", 15, 12, 53)
    m.island(wobble=0.26, bites=3)
    for x, y in m.cells():
        m.hgt[y][x] = 2 + ((x // 3 + y // 4) % 3) if x < 7 else 1 + (1 if (x * 7 + y * 3) % 5 == 0 else 0)
        m.zone[y][x] = "canyon" if x < 7 else "crystal"
    m.scatter("r", lambda x, y: x < 7, 0.16)
    m.scatter("f", lambda x, y: x > 8, 0.2)  # crystal clusters and twisted trees
    m.fill(7, 0, 7, 11, t="d", h=1)  # gully floor
    m.fill(0, 6, 6, 6, t="d")  # a ledge road out of the canyon
    for x in range(0, 7):
        m.hgt[6][x] = 2
    m.fill(10, 8, 12, 9, t="w", h=0)  # a still violet pool
    m.stairs_on_jumps()
    party = list(zip(PARTY, [(1, 6), (2, 6), (3, 6), (1, 7)]))
    enemies = [("strange_thing", (11, 4)), ("strange_thing", (12, 6)), ("wolf", (9, 5)), ("wolf", (10, 2))]
    for _, (x, y) in party + enemies:
        if m.t[y][x] in BLOCKED:
            m.t[y][x] = "g"
    m.stairs_on_jumps()
    m.save("", party, enemies, strangeness=0.4)


if __name__ == "__main__":
    forest_to_castle()
    mountain_to_marsh()
    farm_to_crypt()
    canyon_to_crystal()
