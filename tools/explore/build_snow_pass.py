#!/usr/bin/env python3
"""Builds the snowy mountain pass and the wolf den for the end-to-end loop.

- snow_pass: the party climbs from a frozen meadow at the front (level 0) to a summit at the back
             (level 8) in five terraces two levels apart, joined by stair flights that switch back left
             and right, so every terrace is walked across. A frozen stream falls down the terraces on the
             right; wolves on the first terrace, a cave mouth into the wolf den at the back of it, a high
             ledge only a rope reaches, a bandit choke under the summit, a hidden nook, and at the top the
             stair down into the Lich King's dungeon (the crypt map).
- wolf_den:  a winding cave of nine levels (dungeon set, cave_kit.py): wolves in the bone chamber, an elite wolf's lair at the top.

The pass is laid out in screen terms: u = x - y runs left to right across the screen, d = x + y runs from
the back (top of the screen, d small) to the front (d large). Terraces are bands of d, so cliffs face the
camera and the climb runs up the screen (map-look rules V1 to V7).

Run again after editing: python3 tools/explore/build_snow_pass.py
"""
import json
import math
import os

HEIGHT_DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"  # one digit a cell, as CombatGrid saves heights (0-24)
from collections import deque

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "game", "data", "explore")
STAIRS_CLIMB = 2  # CombatGrid.STAIRS_CLIMB
JUMP = 1  # the leader's jump
BLOCKED = set("ru.")  # rock, ruin, void (forest and water are slow but walkable)


class Map:
    def __init__(self, name, w, h, art_set, t=".", hgt=0):
        self.name, self.w, self.h, self.art_set = name, w, h, art_set
        self.terrain = [[t] * w for _ in range(h)]
        self.height = [[hgt] * w for _ in range(h)]
        self.props, self.things, self.groups, self.start = [], [], [], []

    def inb(self, x, y):
        return 0 <= x < self.w and 0 <= y < self.h

    def t(self, x, y):
        return self.terrain[y][x]

    def ht(self, x, y):
        return self.height[y][x]

    def put(self, x, y, t=None, h=None):
        if t is not None:
            self.terrain[y][x] = t
        if h is not None:
            self.height[y][x] = h

    def prop(self, sprite, x, y, foot=(1, 1), tall=0.0, sight=0.0, **extra):
        p = {"sprite": sprite, "cell": [x, y], "foot": list(foot), "tall": tall, "sight": sight, "walk": False}
        p.update(extra)
        self.props.append(p)

    def blob(self, name, x, y, foot, tall, sight=1.0):
        self.prop("ph_" + name, x, y, foot, tall, sight, blob=True, name=name)

    def prop_cells(self):
        out = set()
        for p in self.props:
            for dy in range(p["foot"][1]):
                for dx in range(p["foot"][0]):
                    out.add((p["cell"][0] + dx, p["cell"][1] + dy))
        return out

    def passable(self, x, y):
        return self.inb(x, y) and self.t(x, y) not in BLOCKED and (x, y) not in self.prop_cells()

    def can_step(self, a, b):
        limit = JUMP + (STAIRS_CLIMB if "t" in (self.t(*a), self.t(*b)) else 0)
        return abs(self.ht(*a) - self.ht(*b)) <= limit

    def reach(self, start, blocked=()):
        """Every cell the leader can walk to from start (4-way steps, like ExploreRules.find_path)."""
        blocked = set(blocked)
        props = self.prop_cells()
        seen, q = {start}, deque([start])
        while q:
            c = q.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (c[0] + dx, c[1] + dy)
                if n in seen or not self.inb(*n) or self.t(*n) in BLOCKED or n in props or n in blocked:
                    continue
                if self.can_step(c, n):
                    seen.add(n)
                    q.append(n)
        return seen

    def usable_from(self, cells, thing):
        """ExploreRules.can_use_from: a neighbour (diagonals too) within 2 levels."""
        tx, ty = thing
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                c = (tx + dx, ty + dy)
                if c != thing and c in cells and abs(self.ht(*c) - self.ht(tx, ty)) <= 2:
                    return True
        return False

    def save(self, strangeness=0.0, view=0, turn=False, fog=True, walls=False, level=1):
        data = {
            "name": self.name, "art_set": self.art_set, "strangeness": strangeness, "view": view, "level": level,
            **({"walls": True, "wall_kit": "dungeon"} if walls else {}), "turn": turn, "fog": fog,
            "grid": {"w": self.w, "h": self.h,
                     "terrain": ["".join(r) for r in self.terrain],
                     "heights": ["".join(HEIGHT_DIGITS[v] for v in r) for r in self.height],
                     "props": self.props},
            "start": self.start, "groups": self.groups, "things": self.things,
        }
        path = os.path.normpath(os.path.join(OUT_DIR, self.name + ".json"))
        with open(path, "w") as f:
            json.dump(data, f, indent=1)
            f.write("\n")
        print("wrote", path, "%dx%d" % (self.w, self.h), len(self.props), "props", len(self.things), "things")

    def dump(self):
        for y in range(self.h):
            print("".join(self.terrain[y]), " ", "".join(str(v) if self.terrain[y][x] != "." else " " for x, v in enumerate(self.height[y])))


# --- the pass --------------------------------------------------------------------------------------------
N = 38
P = Map("snow_pass", N, N, "snow")


def uv(x, y):
    return x - y, x + y


def cell(u, d):
    """The grid cell at screen position (u, d); u and d must have the same parity."""
    return (u + d) // 2, (d - u) // 2


def at(u, d):
    """Nearest cell to (u, d), nudging d to u's parity."""
    if (u + d) % 2:
        d += 1
    return cell(u, d)


# Band edges: the back edge (smallest d) of each terrace, as a step function of u so each cliff runs
# straight for a few cells before it jogs (V9). Terraces: 0 meadow, 1 wolf shelf, 2 middle shelf,
# 3 high shelf, 4 summit.
LEVELS = [0, 2, 4, 6, 8]


def edge(i, u):
    base = [52, 41, 31, 21][i]  # back edge of terraces 0..3 (the cliff up to the next terrace)
    jog = [(0, 1, 2, 1, 0, -1, -1, 0), (1, 0, -1, -1, 0, 2, 2, 1), (0, -1, 0, 1, 2, 1, 0, 0), (1, 2, 1, 0, -1, 0, 1, 2)][i]
    return base + jog[((u + 16) // 4) % len(jog)]


def terrace(u, d):
    for i in range(4):
        if d >= edge(i, u):
            return i
    return 4


def half_width(d):
    """The pass narrows toward the summit; a ragged outline (V7)."""
    w = 12.0 if d > 26 else 8.0 + (d - 12) * 0.28
    w += 1.4 * math.sin(d * 0.55) + 0.8 * math.sin(d * 1.7 + 1.0)
    return w


def centre(d):
    return 2.5 * math.sin(d / 9.0)


D_TOP, D_FRONT = 12, 64
for y in range(N):
    for x in range(N):
        u, d = uv(x, y)
        if d < D_TOP or d > D_FRONT - (abs(u) // 5) or abs(u - centre(d)) > half_width(d):
            continue
        i = terrace(u, d)
        P.put(x, y, "g", LEVELS[i])

# Stair flights. Each runs up the screen (toward -x on the left of the pass, -y on the right), one cell
# wide and straight up the slope, as the painted look wants (map maker notes, V9); the lower cell sits one
# level up, the upper one on the terrace's level. They switch back:
# meadow -> wolf shelf on the right, wolf shelf -> middle on the left, middle -> high on the right,
# high -> summit in the middle (the choke the bandits hold).


def flight(u0, i, axis):
    """A flight from terrace i to i+1 at screen column u0; axis 'x' climbs along -x, 'y' along -y."""
    lo, hi = LEVELS[i], LEVELS[i + 1]
    lanes = [0]
    made = []
    for lane in lanes:
        # Start on terrace i just in front of its back edge, on this lane.
        d = edge(i, u0) + 3
        x, y = at(u0, d)
        if axis == "x":
            y += lane
        else:
            x += lane
        # Walk up the screen until the next terrace.
        for _ in range(8):
            nx, ny = (x - 1, y) if axis == "x" else (x, y - 1)
            if not P.inb(nx, ny) or P.t(nx, ny) == ".":
                break
            if P.ht(nx, ny) >= hi:
                P.put(x, y, "t", lo + 1)
                P.put(nx, ny, "t", hi)
                made += [(x, y), (nx, ny)]
                break
            x, y = nx, ny
    # Two wide where the lane beside lands on the same two terraces at the same place (playtest recheck 2026-10-30):
    # a one-wide flight reads as loose blocks on the snow.
    if made:
        (ax, ay), (bx, by) = made
        for side in (1, -1):
            sx, sy = (0, side) if axis == "x" else (side, 0)
            a2, b2 = (ax + sx, ay + sy), (bx + sx, by + sy)
            below = (2 * a2[0] - b2[0], 2 * a2[1] - b2[1])  # the ground the flight starts from
            above = (2 * b2[0] - a2[0], 2 * b2[1] - a2[1])  # and the ground it climbs onto
            if all(P.inb(*c) and P.t(*c) in "gd" for c in (a2, b2, below, above)) and P.ht(*a2) == lo \
                    and P.ht(*below) == lo and P.ht(*b2) == hi and P.ht(*above) == hi:
                P.put(*a2, "t", lo + 1)
                P.put(*b2, "t", hi)
                made += [a2, b2]
                break
    return made


FLIGHTS = [flight(6, 0, "x"), flight(-5, 1, "y"), flight(5, 2, "x"), flight(-1, 3, "x")]

# The frozen stream: from a spring on the summit's right it runs down the screen along the right side,
# two cells wide, falling at each cliff (V5, V11). Its bed keeps the bank's level, so it never makes a ramp between terraces.
for y in range(N):
    for x in range(N):
        u, d = uv(x, y)
        if P.t(x, y) != "g":
            continue
        c = 8.5 + 1.5 * math.sin(d / 6.0) if d < 46 else 9.5 - (d - 46) * 0.45
        if d >= 16 and c <= u <= c + 2.2:
            P.put(x, y, "w")
# The meadow pond the stream ends in.
for y in range(N):
    for x in range(N):
        u, d = uv(x, y)
        if P.t(x, y) in "gw" and terrace(u, d) == 0 and (u - 9) ** 2 / 9.0 + (d - 58) ** 2 / 16.0 <= 1.0:
            P.put(x, y, "w", 0)

# The rope ledge: a block on the left of the middle shelf, level 8, four levels over the shelf and two over
# the high shelf behind it, with no stair: only the rope reaches it.
LEDGE = []
for y in range(20, 25):
    for x in range(11, 15):
        if P.t(x, y) != ".":
            P.put(x, y, "g" if (x + y) % 4 else "s", 8)
            LEDGE.append((x, y))

# Rocky ground: pines in clumps at the back and along the rims, a few on the front terraces (V6);
# boulders (rock cells one level up) on rims, pillars in front of cliffs (V10).
def noise(x, y, s):
    return (math.sin(x * 12.9898 + y * 78.233 + s) * 43758.5453) % 1.0


for y in range(N):
    for x in range(N):
        if P.t(x, y) != "g" or (x, y) in LEDGE:
            continue
        u, d = uv(x, y)
        rim = abs(u - centre(d)) > half_width(d) - 2.2
        back = d < 26
        n = noise(x, y, 1.0)
        if (rim and n < 0.42) or (back and n < 0.18) or n < 0.05:
            P.put(x, y, "f")

# Boulders and pillars: rock a level or two over the ground, kept off paths below.
ROCKS = [(-9, 47), (-3, 45), (4, 36), (-8, 26), (10, 25), (-5, 17), (3, 15), (-10, 56), (12, 53)]
for u, d in ROCKS:
    x, y = at(u, d)
    if P.t(x, y) in "gf":
        P.put(x, y, "r", P.ht(x, y) + 1)

# The choke under the summit: rock shoulders either side of the last flight leave a narrow way up.
for u in range(-8, 9):
    if -3 <= u <= 2:
        continue
    x, y = at(u, edge(3, u) + 1)
    if P.inb(x, y) and P.t(x, y) in "gf":
        P.put(x, y, "r", 7)

# Placed props from the snow set on clear ground.
SNOW_PROPS = [("prop_pine_3", 3, 22, 1.4), ("prop_pine_4", -6, 22, 1.4), ("prop_bush_2", -2, 50, 0.6),
              ("prop_boulder_2", 5, 43, 0.6), ("prop_bush", -9, 40, 0.6), ("prop_pine_5", 8, 34, 1.3)]
for sprite, u, d, tall in SNOW_PROPS:
    x, y = at(u, d)
    if P.t(x, y) == "g":
        P.prop(sprite, x, y, tall=tall, sight=1.0 if tall > 1 else 0.5)

# --- things on the pass ---
START = at(1, 61)
P.put(*START, "d")
P.start = [list(START)]
exit_cell = (START[0] + 1, START[1])  # beside the start, toward the front
P.put(*exit_cell, "d")
P.things.append({"id": "pass_exit", "kind": "exit", "event": "exit", "cell": list(exit_cell)})
# A packed-snow path up the middle of the meadow toward the first flight.
for k in range(6):
    x, y = at(2 + k, 59 - k)
    if P.t(x, y) == "g":
        P.put(x, y, "d")

# The cave mouth: at the back of the wolf shelf, in the cliff up to the middle shelf. The blob stands on the
# middle shelf's front edge right behind the thing.
DEN_U = 3
den = at(DEN_U, edge(1, DEN_U))
while P.ht(*den) != LEVELS[1] or P.t(*den) not in "gfd":  # step forward until on the wolf shelf
    den = (den[0] + 1, den[1])
P.put(*den, "d")
for k in range(1, 4):
    P.put(den[0] + k, den[1], "d") if P.t(den[0] + k, den[1]) == "f" else None
den_front = (den[0] + 1, den[1])
P.put(*den_front, "d")
P.blob("cave_mouth", den[0] - 1, den[1] - 1, (2, 1), 0.5, 1.0)
for c in [(den[0] - 1, den[1] - 1), (den[0], den[1] - 1)]:
    if P.t(*c) not in "gs":
        P.put(*c, "g")
P.things.append({"id": "den_mouth", "kind": "enter", "event": "", "cell": list(den), "to": "wolf_den", "at": [3, 9]})

# The wolves: on the wolf shelf, back from its front cliff, so the party meets them on the shelf and not
# from the meadow two levels below (a fight from below lost every time: -4 to hit, wolves +4).
P.groups.append({"id": "pass_wolves", "event": "spot_beasts", "sight": 4, "loot": "food:+6",
                 "units": [{"id": "wolf", "cell": list(at(-4, 44))}, {"id": "wolf", "cell": list(at(-6, 44))}]})

# The cache: in the meadow's far left corner behind the pines.
cache = at(-9, 59)
P.put(*cache, "g")
P.things.append({"id": "pass_cache", "kind": "chest", "event": "pass_cache", "cell": list(cache), "once": "got_pass_cache"})

# The rope: at the foot of the ledge on the middle shelf. It lands on the ledge's front; a second rope on
# the ledge lets the party back down to the foot.
foot = None
for (x, y) in sorted(LEDGE, key=lambda c: -(c[0] + c[1])):
    for n in [(x + 1, y), (x, y + 1)]:
        if P.inb(*n) and P.t(*n) in "gf" and P.ht(*n) == LEVELS[2] and n not in LEDGE:
            foot = (n, (x, y))
            break
    if foot:
        break
rope_cell, ledge_front = foot
P.put(*rope_cell, "g")
rope_land = (rope_cell[0] + (1 if (rope_cell[0] + 1, rope_cell[1]) not in LEDGE else 0), rope_cell[1] + (1 if (rope_cell[0], rope_cell[1] + 1) not in LEDGE else 0))
if rope_land == rope_cell or not P.passable(*rope_land) or P.ht(*rope_land) != LEVELS[2]:
    for n in [(rope_cell[0] + 1, rope_cell[1]), (rope_cell[0], rope_cell[1] + 1), (rope_cell[0] - 1, rope_cell[1]), (rope_cell[0], rope_cell[1] - 1)]:
        if n not in LEDGE and P.passable(*n) and P.ht(*n) == LEVELS[2]:
            rope_land = n
            break
P.put(*rope_land, "g")
P.things.append({"id": "rope_ledge", "kind": "climb", "event": "rope_climb", "cell": list(rope_cell), "to": "snow_pass", "at": list(ledge_front)})
# Ledge middle (all eight neighbours on the ledge) for the chest; the down rope on the front edge.
inner = [c for c in LEDGE if all((c[0] + dx, c[1] + dy) in LEDGE for dx in (-1, 0, 1) for dy in (-1, 0, 1))]
# The chest never shares a screen column (x - y) with the down rope, or their markers stack.
def near_front(cells, skip):
    return next(c for c in sorted(cells, key=lambda c: abs(c[0] - ledge_front[0]) + abs(c[1] - ledge_front[1]))
                if c not in skip)
for chest in sorted(inner, key=lambda c: abs(c[0] - ledge_front[0]) + abs(c[1] - ledge_front[1]))[1:]:
    down = near_front(LEDGE, (ledge_front, chest))
    if chest[0] - chest[1] != down[0] - down[1]:
        break
P.things.append({"id": "ledge_chest", "kind": "chest", "event": "ledge_chest", "cell": list(chest), "once": "got_ledge_chest"})
P.things.append({"id": "rope_down", "kind": "climb", "event": "rope_down", "cell": list(down), "to": "snow_pass", "at": list(rope_land)})
P.prop("prop_crate", *[c for c in inner if c != chest][-1], tall=0.6, sight=0.5)

# The bandits: on the high shelf, in front of the choke to the summit flight. The archer holds the foot
# of the summit stair and leads: drop him and the rest flee ([USER] 2026-10-29, card design-fight-goals-pick).
P.groups.append({"id": "pass_bandits", "event": "spot_people", "sight": 5, "loot": "food:+4;gold:+8", "goals": "leader",
                 "units": [{"id": "bandit", "cell": list(at(1, edge(3, 1) + 4))},
                           {"id": "bandit_archer", "cell": list(at(-3, edge(3, -3) + 2)), "leader": True}]})

# The secret: a dead-end nook at the high shelf's far right, behind a boulder and pines.
nook = at(9, 24)
P.put(*nook, "g")
P.things.append({"id": "snow_secret", "kind": "hidden", "event": "snow_secret", "cell": list(nook), "once": "got_snow_secret"})

# The crypt stair at the summit's back: the way down into the Lich King's dungeon, under a placeholder door.
top = at(0, 15)
while P.t(*top) == "." or P.ht(*top) != 8:
    top = (top[0] + 1, top[1] + 1)
for c in [top, (top[0] + 1, top[1]), (top[0], top[1] + 1), (top[0] + 1, top[1] + 1), (top[0] - 1, top[1] - 1), (top[0] - 1, top[1]), (top[0], top[1] - 1)]:
    if P.inb(*c) and P.t(*c) != ".":
        P.put(*c, "s", 8)
P.blob("crypt_door", top[0] - 1, top[1] - 1, (2, 1), 1.2, 2.0)
P.things.append({"id": "crypt_stair", "kind": "enter", "event": "", "cell": [top[0], top[1] + 0], "to": "crypt", "at": [10, 55]})
P.things[-1]["cell"] = [top[0], top[1]]
P.prop("prop_brazier", top[0] + 1, top[1] - 1, tall=0.9, sight=0.5) if P.t(top[0] + 1, top[1] - 1) == "s" else None

# Ground the walk can't reach (pockets cut off by the ledge and the rocks) grows pines, so nothing
# looks walkable that isn't.
_walk = P.reach(tuple(P.start[0]))
for y in range(N):
    for x in range(N):
        if P.t(x, y) in "gsd" and (x, y) not in _walk and (x, y) not in LEDGE:
            P.put(x, y, "f")

# Shelves ([USER] 2026-10-30: never a box, "jut outs, dynamics, verticality"; tools/map_shape.py): small pads that jut out
# of the terraces into the empty rock, each reached by a short stair run (a level a cell) up or down, so the pass has a
# ragged outline and more climbs. Each sits clear of every thing and foe and of the other shelves.
import random
_rng = random.Random(11)
_walk = P.reach(tuple(P.start[0]))
_keep = {tuple(t["cell"]) for t in P.things} | {tuple(u["cell"]) for g in P.groups for u in g["units"]}
_taken = []
_added = 0
_cands = [c for c in sorted(_walk) if P.t(*c) in "gds" and all(abs(c[0] - k[0]) + abs(c[1] - k[1]) > 3 for k in _keep)]
_rng.shuffle(_cands)
for c in _cands:
    if _added >= 14:
        break
    if any(abs(c[0] - q[0]) + abs(c[1] - q[1]) < 5 for q in _taken):
        continue
    for d in _rng.sample([(1, 0), (-1, 0), (0, 1), (0, -1)], 4):
        ph = P.ht(*c)
        L = _rng.choice((3, 4, 5))
        sign = _rng.choice((1, -1))
        if ph + sign * L < 0 or ph + sign * L > 12:
            sign = -sign
            if ph + sign * L < 0 or ph + sign * L > 12:
                continue
        side = (-d[1], d[0])
        run = [(c[0] + d[0] * i, c[1] + d[1] * i) for i in range(1, L + 1)]
        FL = _rng.choice((0, 3, 5))  # a finger of 2-wide ground before the pad, so some shelves reach out
        pad = [(c[0] + d[0] * (L + 1 + i) + side[0] * j, c[1] + d[1] * (L + 1 + i) + side[1] * j) for i in range(FL) for j in (0, 1)]
        pad += [(c[0] + d[0] * (L + 1 + FL + i) + side[0] * j, c[1] + d[1] * (L + 1 + FL + i) + side[1] * j) for i in range(3) for j in (-1, 0, 1)]
        cells = run + pad
        if not all(P.inb(*q) and P.t(*q) == "." for q in cells):
            continue
        # keep a ring of void round it so shelves don't fuse with the terraces
        ring = [(q[0] + dx, q[1] + dy) for q in cells[1:] for dx in (-1, 0, 1) for dy in (-1, 0, 1)]
        if any(P.inb(*r) and r not in cells and r != c and P.t(*r) != "." for r in ring):
            continue
        for i, q in enumerate(run, 1):
            P.put(*q, "d", ph + sign * i)
        for i in range(1, len(run)):  # the lower cell of each rise is a stair
            lo = run[i - 1] if sign > 0 else run[i]
            P.put(*lo, "t")
        for q in pad:
            P.put(*q, "g", ph + sign * L)
        _taken.append(c)
        _added += 1
        break
print("shelves added:", _added)
# Rock outcrops standing in the terraces (cover for fights, and a broken-up edge inside the map): short columns of rock,
# kept off the roads, stairs, things and foes, never cutting the walk.
_walk = P.reach(tuple(P.start[0]))
_outs = []
_cands = [c for c in sorted(_walk) if P.t(*c) in "gf" and all(abs(c[0] - k[0]) + abs(c[1] - k[1]) > 3 for k in _keep)]
_rng.shuffle(_cands)
for c in _cands:
    if len(_outs) >= 13:
        break
    if any(abs(c[0] - q[0]) + abs(c[1] - q[1]) < 4 for q in _outs):
        continue
    d = _rng.choice(((1, 0), (0, 1)))
    cells = [(c[0] + i * d[0] + j * d[1], c[1] + i * d[1] + j * d[0]) for i in range(3) for j in range(2)]  # a bigger mass, fewer of them
    if not all(P.inb(*q) and P.t(*q) in "gf" and P.ht(*q) == P.ht(*c) for q in cells):
        continue
    ring = [(q[0] + dx, q[1] + dy) for q in cells for dx in (-1, 0, 1) for dy in (-1, 0, 1)]
    if any(P.inb(*r) and P.t(*r) in "t" for r in ring):
        continue
    saved = [(q, P.t(*q), P.ht(*q)) for q in cells]
    _before = len(P.reach(tuple(P.start[0])))
    for q in cells:
        P.put(*q, "r", P.ht(*q) + 2)
    after = P.reach(tuple(P.start[0]))
    if len(after) < _before - len(cells):  # it would cut the walk
        for q, t0, h0 in saved:
            P.put(*q, t0, h0)
        continue
    _outs.append(c)
print("outcrops:", len(_outs))
# Inlets: bites out of the terrace rims, so the outline winds in as well as out ([USER] 2026-10-30: "push the shape").
_bites = 0
_rim = [c for c in sorted(P.reach(tuple(P.start[0]))) if P.t(*c) in "gf" and any(P.inb(c[0] + dx, c[1] + dy) and P.t(c[0] + dx, c[1] + dy) == "." for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        and all(abs(c[0] - k[0]) + abs(c[1] - k[1]) > 4 for k in _keep)]
_rng.shuffle(_rim)
for c in _rim:
    if _bites >= 0:
        break
    for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
        cells = [(c[0] + i * sx, c[1] + j * sy) for i in range(3) for j in range(2)]
        if not all(P.inb(*q) and P.t(*q) in "gf" for q in cells):
            continue
        ring = [(q[0] + dx, q[1] + dy) for q in cells for dx in (-1, 0, 1) for dy in (-1, 0, 1)]
        if any(P.inb(*r) and P.t(*r) in "dt" for r in ring):
            continue
        saved = [(q, P.t(*q), P.ht(*q)) for q in cells]
        _before = len(P.reach(tuple(P.start[0])))
        for q in cells:
            P.put(*q, ".", 0)
        if len(P.reach(tuple(P.start[0]))) < _before - len(cells):
            for q, t0, h0 in saved:
                P.put(*q, t0, h0)
            continue
        _bites += 1
        break
print("inlets:", _bites)

# --- checks ---
things = {t["id"]: tuple(t["cell"]) for t in P.things}
thing_cells = set(things.values())
start = tuple(P.start[0])
reach = P.reach(start, thing_cells)
for tid in ["pass_exit", "den_mouth", "pass_cache", "snow_secret", "crypt_stair", "rope_ledge"]:
    assert P.usable_from(reach, things[tid]), "can't use " + tid
assert not P.usable_from(reach, things["ledge_chest"]), "ledge chest reachable without the rope"
# The rope down lands beside the rope's foot, on the walk.
rope_land = next(n for n in [(rope_cell[0] + dx, rope_cell[1] + dy) for dx, dy in
                              ((1, 0), (0, 1), (-1, 0), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1))] if n in reach)
for t in P.things:
    if t["id"] == "rope_down":
        t["at"] = list(rope_land)
ledge_reach = P.reach(tuple(ledge_front), thing_cells)
assert P.usable_from(ledge_reach, things["ledge_chest"]) and P.usable_from(ledge_reach, things["rope_down"])
assert not (ledge_reach & reach), "the ledge joins the main walk"
for g in P.groups:
    for u in g["units"]:
        assert tuple(u["cell"]) in reach, g["id"] + " stands off the walk"
for c in P.prop_cells():
    assert c not in thing_cells, "a prop covers a thing"
DEN_FRONT = None
for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, 1)):
    n = (den[0] + dx, den[1] + dy)
    if n in reach and abs(P.ht(*n) - P.ht(*den)) <= 1:
        DEN_FRONT = n
        break
assert DEN_FRONT is not None

# --- the wolf den --------------------------------------------------------------------------------------
# The den is a winding cave ([USER] 2026-10-30: unique shapes, jut outs, verticality; tools/map_shape.py): an entry hall at
# the front, a hall, a bone chamber with the wolf pair, a nook, a ledge, and the elite wolf's lair at the top, joined by
# climbs, with a second way up through an alcove and a chimney. Built from rounded rooms (cave_kit.py).
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cave_kit import Cave
C = Cave(30, 30)
C.room("entry", 6, 26, 3, 2, 1)
C.room("hall", 16, 22, 4, 2, 3)
C.room("bones", 8, 14, 3, 3, 5, "s")
C.room("nook", 3, 6, 2, 1, 8, "s")
C.room("ledge", 18, 12, 2, 2, 7, "s")
C.room("lair", 23, 4, 4, 2, 9, "s")
C.room("alcove", 26, 26, 2, 2, 3)
C.room("chimney", 27, 15, 1, 2, 5, "s")
C.link("entry_hall", "entry", "hall", "x", 1)
C.link("hall_bones", "hall", "bones", "x", 1)
C.link("bones_nook", "bones", "nook", "y", 1)
C.link("bones_ledge", "bones", "ledge", "y", 1)
C.link("hall_ledge", "hall", "ledge", "y", 1)
C.link("ledge_lair", "ledge", "lair", "y", 1)
C.link("hall_alcove", "hall", "alcove", "x", 1)
C.link("alcove_chimney", "alcove", "chimney", "y", 1)
C.link("chimney_lair", "chimney", "lair", "y", 1)
C.link("entry_alcove", "entry", "alcove", "y", 1, to_off=(20, 3))  # the long way round, along the south edge
C.room("pocket_w", 3, 20, 1, 1, 1)  # two dead-end pockets
C.room("pocket_e", 28, 21, 1, 1, 3)
C.link("entry_pocket", "entry", "pocket_w", "y", 1)
C.link("alcove_pocket", "alcove", "pocket_e", "x", 1)
C.finish()
W = Map("wolf_den", 30, 30, "dungeon")
for y in range(30):
    for x in range(30):
        W.put(x, y, C.t[y][x], C.hts[y][x])
W.start = [[6, 25]]
W.put(6, 28, "d", 1)
W.things.append({"id": "den_out", "kind": "enter", "event": "", "cell": [6, 28], "to": "snow_pass", "at": list(DEN_FRONT)})
# Two packs, not one: the pair in the bone chamber and a lone wolf in the lair at the top, far apart so
# they fight separately (a party of two loses most three-wolf fights). The pair is a hold-out: last 4
# rounds and they give up ([USER] 2026-10-29, card design-fight-goals-pick).
W.groups.append({"id": "den_wolves", "event": "spot_beasts", "sight": 4, "loot": "food:+6", "goals": "hold:4",
                 "units": [{"id": "wolf", "cell": [9, 15]}, {"id": "wolf", "cell": [7, 13]}]})
# The lone wolf is elite ([USER] 2026-10-30, card design-elite-pick): its lair can be skipped, and it is far from the
# pair, so it never joins their hold-out (groups don't move; JOIN_RANGE is 3).
W.groups.append({"id": "den_lone", "event": "spot_beasts", "sight": 4, "loot": "food:+3", "elite": True,
                 "units": [{"id": "wolf", "cell": [22, 5]}]})
W.things.append({"id": "den_bones", "kind": "chest", "event": "den_bones", "cell": [6, 12], "once": "got_den_bones"})
W.things.append({"id": "den_rare", "kind": "rare", "event": "rare:+1;metal:+2", "cell": [25, 3]})  # behind the elite wolf (omr-10)
W.prop("prop_bush", 12, 22, tall=0.6, sight=0.5)
W.prop("prop_boulder", 10, 14, tall=0.6, sight=0.5)
wt = {t["id"]: tuple(t["cell"]) for t in W.things}
wreach = W.reach((6, 25), set(wt.values()))
assert W.usable_from(wreach, wt["den_bones"]) and W.usable_from(wreach, wt["den_out"]) and W.usable_from(wreach, wt["den_rare"])
for u in W.groups[0]["units"] + W.groups[1]["units"]:
    assert tuple(u["cell"]) in wreach, u
assert min(abs(a["cell"][0] - b["cell"][0]) + abs(a["cell"][1] - b["cell"][1])
           for a in W.groups[0]["units"] for b in W.groups[1]["units"]) > 3, "the elite wolf would join the hold-out"

# The den mouth leads to the den's start.
for t in P.things:
    if t["id"] == "den_mouth":
        t["at"] = W.start[0]

# The strip across the stream from the exit, on the map's edge: water is WALK_OUT in the game, so nobody walks
# there. It grows woods instead of reading as a place (playtest sweep, 2026-10-30).
for y in range(23, 31):
    for x in range(33, 38):
        if P.t(x, y) == "g":
            P.put(x, y, "f")

P.save(strangeness=0.1)  # level 1 (design-to-builder-map-levels)
W.save(walls=True, level=2)  # plain gray walls (ExploreMap.walls); foes a level deeper than the pass

# The painted look's authoring rules (V9 tidy edges, V10 pillars, V12 a beige road from the foot of the pass
# to the crypt stair) come from the game's own MapOps, as the map maker's Generate menu applies them.
import shutil
import subprocess
GODOT = os.environ.get("GODOT") or shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot"
GAME = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "..", "game"))
GUARD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mem_guard.sh")  # killed over GODOT_MEM_CAP_MB
subprocess.run([GUARD, GODOT, "--headless", "--path", GAME, "-s", "res://tools/dress_explore.gd", "--",
                "snow_pass", "pass_exit", "crypt_stair", "3"], check=True)


def wood_strays(path, most=2):
    """After the dressing: one- and two-cell bits of open ground nobody can walk to (tidy leftovers, pillar tops)
    grow woods, so they don't read as places (playtest recheck 2026-10-30). The game's walking: jump 1, a stair
    2 more, water and woods WALK_OUT, doors, rubble and hidden ways opened. Bigger pieces (the rope ledge) stay."""
    with open(path) as f:
        data = json.load(f)
    g = data["grid"]
    ter = [list(r) for r in g["terrain"]]
    hts = [[HEIGHT_DIGITS.index(c) for c in r] for r in g["heights"]]
    w, h = g["w"], g["h"]
    blocked = {(p["cell"][0] + dx, p["cell"][1] + dy) for p in g["props"] if not p.get("walk")
               for dy in range(p.get("foot", [1, 1])[1]) for dx in range(p.get("foot", [1, 1])[0])}
    opened = {tuple(t["cell"]) for t in data["things"] if t["kind"] in ("door", "rubble", "hidden")}
    ok = lambda c: (0 <= c[0] < w and 0 <= c[1] < h and (ter[c[1]][c[0]] not in "ru.wf" or c in opened)
                    and c not in blocked)
    start = tuple(int(v) for v in data["start"][0])
    seen, todo = {start}, [start]
    while todo:
        x, y = todo.pop()
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if n not in seen and ok(n) and abs(hts[n[1]][n[0]] - hts[y][x]) <= JUMP + (
                    STAIRS_CLIMB if "t" in (ter[y][x], ter[n[1]][n[0]]) else 0):
                seen.add(n)
                todo.append(n)
    lost = {(x, y) for y in range(h) for x in range(w) if ok((x, y)) and (x, y) not in seen}
    while lost:
        c = lost.pop()
        piece, todo = {c}, [c]
        while todo:
            x, y = todo.pop()
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if n in lost and abs(hts[n[1]][n[0]] - hts[y][x]) <= 1:
                    lost.discard(n)
                    piece.add(n)
                    todo.append(n)
        if len(piece) <= most:
            for x, y in piece:
                if ter[y][x] in "gds":
                    ter[y][x] = "f"
    g["terrain"] = ["".join(r) for r in ter]
    with open(path, "w") as f:
        json.dump(data, f, indent=1)
        f.write("\n")


wood_strays(os.path.normpath(os.path.join(OUT_DIR, "snow_pass.json")))


def hide_ambusher(path, cell=(7, 15)):
    """An ambusher (design-foe-roles, 96c8714) joins the bandits after the dressing, so the dressing (which keeps
    the cells round each unit as built) lays the ground as before. It waits in the pines at the west end of the
    bandits' road, behind the two rocks: unseen from the road, spotted by a piece that goes round the rocks."""
    with open(path) as f:
        data = json.load(f)
    g = data["grid"]
    if not (g["terrain"][cell[1]][cell[0]] == "f" and g["heights"][cell[1]][cell[0]] == "6"):  # the pines moved: the nearest ones
        near = sorted(((abs(x - cell[0]) + abs(y - cell[1]), (x, y)) for y in range(g["h"]) for x in range(g["w"])
                       if g["terrain"][y][x] == "f" and g["heights"][y][x] == "6" and abs(x - cell[0]) + abs(y - cell[1]) <= 3))
        assert near, "no pines near the ambusher's spot"
        cell = near[0][1]
    for grp in data["groups"]:
        if grp["id"] == "pass_bandits":
            grp["units"].append({"id": "ambusher", "cell": list(cell), "hidden": True})
    with open(path, "w") as f:
        json.dump(data, f, indent=1)
        f.write("\n")


def inlets(path, count=60, seed=5):
    """Bites out of the terrace rims after the dressing (which would round them away), so the outline winds in as well as
    out ([USER] 2026-10-30: "push the shape"). 2 x 3 bites of open ground, never within 4 cells of a thing or foe,
    never touching a road or stair, and never cutting the walk (the game's walking, as in wood_strays)."""
    with open(path) as f:
        data = json.load(f)
    g = data["grid"]
    ter = [list(r) for r in g["terrain"]]
    hts = [[HEIGHT_DIGITS.index(c) for c in r] for r in g["heights"]]
    w, h = g["w"], g["h"]
    blocked = {(p["cell"][0] + dx, p["cell"][1] + dy) for p in g["props"] if not p.get("walk")
               for dy in range(p.get("foot", [1, 1])[1]) for dx in range(p.get("foot", [1, 1])[0])}
    opened = {tuple(t["cell"]) for t in data["things"] if t["kind"] in ("door", "rubble", "hidden")}
    keep = {tuple(t["cell"]) for t in data["things"]} | {tuple(u["cell"]) for gr in data["groups"] for u in gr["units"]}
    ok = lambda c: (0 <= c[0] < w and 0 <= c[1] < h and (ter[c[1]][c[0]] not in "ru.wf" or c in opened) and c not in blocked)
    start = tuple(int(v) for v in data["start"][0])

    def walk():
        seen, todo = {start}, [start]
        while todo:
            x, y = todo.pop()
            for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if n not in seen and ok(n) and abs(hts[n[1]][n[0]] - hts[y][x]) <= JUMP + (
                        STAIRS_CLIMB if "t" in (ter[y][x], ter[n[1]][n[0]]) else 0):
                    seen.add(n)
                    todo.append(n)
        return seen
    rng = random.Random(seed)
    rim = [(x, y) for y in range(h) for x in range(w) if ter[y][x] in "gf"
           and any(0 <= x + dx < w and 0 <= y + dy < h and ter[y + dy][x + dx] == "." for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
           and all(abs(x - k[0]) + abs(y - k[1]) > 3 for k in keep)]
    rng.shuffle(rim)
    done = 0
    for c in rim:
        if done >= count:
            break
        for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
            cells = [(c[0] + i * sx, c[1] + j * sy) for i in range(2 + rng.randrange(2)) for j in range(2)]
            if not all(0 <= q[0] < w and 0 <= q[1] < h and ter[q[1]][q[0]] in "gf" for q in cells):
                continue
            if any(0 <= r[0] < w and 0 <= r[1] < h and ter[r[1]][r[0]] in "dt" for q in cells for r in
                   [(q[0] + dx, q[1] + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)]):
                continue
            before = len(walk())
            saved = [(q, ter[q[1]][q[0]], hts[q[1]][q[0]]) for q in cells]
            for q in cells:
                ter[q[1]][q[0]] = "."
                hts[q[1]][q[0]] = 0
            if len(walk()) < before - len(cells):
                for q, t0, h0 in saved:
                    ter[q[1]][q[0]] = t0
                    hts[q[1]][q[0]] = h0
                continue
            done += 1
            break
    g["terrain"] = ["".join(r) for r in ter]
    g["heights"] = ["".join(HEIGHT_DIGITS[v] for v in r) for r in hts]
    with open(path, "w") as f:
        json.dump(data, f, indent=1)
        f.write("\n")
    print("inlets after the dressing:", done)


inlets(os.path.normpath(os.path.join(OUT_DIR, "snow_pass.json")))
hide_ambusher(os.path.normpath(os.path.join(OUT_DIR, "snow_pass.json")))
if __name__ == "__main__":
    P.dump()
    print("start", start, "den_mouth", den, "den front", DEN_FRONT, "rope", rope_cell, "->", ledge_front,
          "chest", chest, "down", down, "->", rope_land, "crypt_stair", top)
    W.dump()
