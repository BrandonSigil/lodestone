#!/usr/bin/env python3
"""What the hand-built town maps share (build_village.py, build_village_v2.py): the Map they write, shapes to
paint with (ribbon, poly, flight), and check_village, the rules the game walks by.

Not run on its own.
"""
import json
import math
import os
import sys

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "game", "data", "explore")


class Map:
    def __init__(self, name, w, h, t="g", hgt=1, art_set="village"):
        self.name, self.w, self.h = name, w, h
        self.terrain = [[t] * w for _ in range(h)]
        self.height = [[hgt] * w for _ in range(h)]
        self.zones = [["-"] * w for _ in range(h)]
        self.props, self.things, self.start = [], [], []
        self.art_set = art_set
        self.walls = False  # rock is plain gray walls (ExploreMap.walls): the interiors
        self.wall_tall = 0  # back walls this many levels over the floor (ExploreMap.wall_tall; 0: the game's default)
        self.wall_kit = ""  # the art set its back walls' pieces come from (ExploreMap.wall_kit); "" = block walls

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

    def prop(self, sprite, x, y, foot=(1, 1), tall=0.0, sight=0.0, walk=False, arch=False):
        self.props.append({"sprite": sprite, "cell": [x, y], "foot": list(foot), "tall": tall,
                           "sight": sight, "walk": walk})
        if arch:
            self.props[-1]["arch"] = True

    def arch(self, sprite, x, y, foot):
        """A gateway (CombatGrid.under_arch): pillars on the two end cells of its long side, a walkable gap
        between them."""
        self.prop(sprite, x, y, foot, tall=1.8, sight=2.0, arch=True)

    def building(self, sprite, x, y, fx, fy, door_dx, yard=None):
        """A whole house on an fx x fy footprint; returns the cell in front of its door (left wall). A `yard`
        offset inside the footprint is left open and is the door cell instead (a door painted inside a ^ shape)."""
        self.prop(sprite, x, y, (fx, fy), 0.0, 3.0)
        if yard:
            self.props[-1]["open"] = "%d,%d" % yard
            return [x + yard[0], y + yard[1]]
        return [x + door_dx, y + fy]

    def thing(self, **t):
        self.things.append(t)

    def save(self, view=0, turn=False, fog=True):
        data = {
            "name": self.name, "art_set": self.art_set, "strangeness": 0.0, "view": view,
            **({"walls": True} if self.walls else {}), **({"wall_tall": self.wall_tall} if self.wall_tall else {}),
            **({"wall_kit": self.wall_kit} if self.wall_kit else {}),
            "turn": turn, "fog": fog,
            "grid": {"w": self.w, "h": self.h,
                     "terrain": ["".join(r) for r in self.terrain],
                     "heights": ["".join(HEIGHT_DIGITS[v] for v in r) for r in self.height],
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
    """A room on [x0..x1] x [y0..y1]: walls along its back edges only (low x, low y); the front edges are open
    floor, so the camera sees in ([USER] 2026-10-30). On arrival each back-wall cell gets a piece from the map's
    wall kit (plain, or a corner where the walls meet); window() and door() set a cell's piece."""
    m.fill(x0, y0, x1, y1, floor, h)
    for x in range(x0, x1 + 1):
        m.put(x, y0, "r", h + wall)
    for y in range(y0, y1 + 1):
        m.put(x0, y, "r", h + wall)


HEIGHT_DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"  # one digit a cell, as CombatGrid saves heights (0-24)
BLOCKED = "ru."  # rock, rubble and void can't be walked (CombatGrid.STEP_COST)
WALK_OUT = "wf"  # nor, on the explore maps, water and woods (CombatGrid.WALK_OUT)
JUMP, STAIRS_CLIMB, INTERACT_CLIMB = 1, 2, 2  # the lead's jump; CombatGrid and ExploreRules


def _under_arch(pr, dx, dy):
    fx, fy = pr["foot"]
    if not pr.get("arch"):
        return False
    return 0 < dy < fy - 1 if fy > fx else 0 < dx < fx - 1


def _open(pr):
    """Footprint offsets a prop leaves free ("open": "x,y|x,y", CombatGrid.open_offsets)."""
    return {tuple(int(v) for v in part.split(",")) for part in pr.get("open", "").split("|") if part}


def _prop_cells(m):
    """Every cell a prop blocks (an arch's gap and its open cells are left out)."""
    cells = {}
    for pr in m.props:
        for dy in range(pr["foot"][1]):
            for dx in range(pr["foot"][0]):
                if not _under_arch(pr, dx, dy) and (dx, dy) not in _open(pr):
                    cells[(pr["cell"][0] + dx, pr["cell"][1] + dy)] = pr
    return cells


def check_village(m, decks=None):
    """The rules the game walks by, checked as the map is built: every walkable cell reachable from the
    start on jump 1, every thing usable, buildings on flat clear ground, and stair flights that read the way
    they climb (MapDress.stair_run picks the axis with the most stairs and height change)."""
    problems = []
    props = _prop_cells(m)
    W, H = m.w, m.h

    def ok_cell(c):
        x, y = c
        return 0 <= x < W and 0 <= y < H

    def passable(c):
        p = props.get(c)
        return ok_cell(c) and m.terrain[c[1]][c[0]] not in BLOCKED + WALK_OUT and (p is None or p["walk"])

    def hgt(c):
        return m.height[c[1]][c[0]]

    def can_step(a, b):
        limit = JUMP + (STAIRS_CLIMB if "t" in (m.terrain[a[1]][a[0]], m.terrain[b[1]][b[0]]) else 0)
        return abs(hgt(a) - hgt(b)) <= limit

    decks = decks or {}

    def places(c, blocked):
        """A cell's walkable places: its ground, unless a deck too low over it closes it, and its deck."""
        out = []
        if passable(c) and c not in blocked and (c not in decks or decks[c] - hgt(c) >= 2):
            out.append((c, 0))
        if c in decks and ok_cell(c):
            out.append((c, 1))
        return out

    def level(q):
        return decks[q[0]] if q[1] else hgt(q[0])

    def step(a, b):
        stairs = (not a[1] and m.terrain[a[0][1]][a[0][0]] == "t") or (not b[1] and m.terrain[b[0][1]][b[0][0]] == "t")
        return abs(level(a) - level(b)) <= JUMP + (STAIRS_CLIMB if stairs else 0)

    def reach(start, blocked):
        """The ground cells reached from start (decks walked over on the way: docs/systems/decks.md)."""
        seen, todo = {(start, 0)}, [(start, 0)]
        while todo:
            q = todo.pop()
            for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (q[0][0] + d[0], q[0][1] + d[1])
                for r in places(n, blocked):
                    if r not in seen and step(q, r):
                        seen.add(r)
                        todo.append(r)
        return {q[0] for q in seen if not q[1]}

    start = tuple(m.start[0])
    if not passable(start):
        problems.append("start %s is not walkable" % (start,))
    everywhere = reach(start, set())
    lost = [(x, y) for y in range(H) for x in range(W) if passable((x, y)) and (x, y) not in everywhere]
    if lost:  # since woods block walking (3aa981f) a pocket behind a building can be cut off; a note, not a fault
        print("  NOTE %d walkable cells can't be reached: %s" % (len(lost), lost[:12]))
    thing_cells = {tuple(t["cell"]) for t in m.things} - {start}
    walked = reach(start, thing_cells)
    for t in m.things:
        tc = tuple(t["cell"])
        if not any((tc[0] + dx, tc[1] + dy) in walked and abs(hgt((tc[0] + dx, tc[1] + dy)) - hgt(tc)) <= INTERACT_CLIMB
                   for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx, dy) != (0, 0)) and tc != start:
            problems.append("thing %s at %s can't be used" % (t["id"], tc))
    # Buildings: flat, on ground, nothing else on them; their door cell open.
    owners = {}
    for pr in m.props:
        for dy in range(pr["foot"][1]):
            for dx in range(pr["foot"][0]):
                if (dx, dy) not in _open(pr):
                    c = (pr["cell"][0] + dx, pr["cell"][1] + dy)
                    owners[c] = owners.get(c, 0) + 1
    for pr in m.props:
        x0, y0 = pr["cell"]
        fx, fy = pr["foot"]
        cells = [(x0 + dx, y0 + dy) for dy in range(fy) for dx in range(fx) if (dx, dy) not in _open(pr)]
        for c in cells:
            if not ok_cell(c) or m.terrain[c[1]][c[0]] in ".wt":
                problems.append("%s at %s stands on %s" % (pr["sprite"], (x0, y0), "void/water/stairs"))
                break
        if len({hgt(c) for c in cells if ok_cell(c)}) > 1:
            problems.append("%s at %s straddles a height change" % (pr["sprite"], (x0, y0)))
        for c in cells:
            if owners[c] > 1:
                problems.append("%s at %s overlaps another prop" % (pr["sprite"], (x0, y0)))
                break
        if not pr["sprite"].startswith(("b_", "ph_")) and m.terrain[y0][x0] in "dt":
            problems.append("%s at %s sits on a lane or stair" % (pr["sprite"], (x0, y0)))
    # Stair flights: the run axis the board will draw must be the flight's own, with a slope to show.
    for (x, y), axis in FLIGHTS.items():
        h = hgt((x, y))
        best, best_score = None, 0.0
        # MapDress.stair_run: when only one axis has a stair at another height, that axis is the climb
        climbs = {d for d in ((1, 0), (0, 1)) for e in (d, (-d[0], -d[1]))
                  if passable((x + e[0], y + e[1])) and m.terrain[y + e[1]][x + e[0]] == "t" and hgt((x + e[0], y + e[1])) != h}
        for d in (list(climbs) if len(climbs) == 1 else ((1, 0), (0, 1))):
            score = 0.0
            for e in (d, (-d[0], -d[1])):
                n = (x + e[0], y + e[1])
                if not passable(n):
                    continue
                if m.terrain[n[1]][n[0]] == "t":
                    score += 100
                score += abs(hgt(n) - h)
            if score > best_score:
                best, best_score = d, score
        if best != axis:
            problems.append("stair %s reads along %s, not %s" % ((x, y), best, axis))
    for msg in problems:
        print("  CHECK", msg)
    if problems:
        raise SystemExit("%s: %d problems" % (m.name, len(problems)))
    print("%s checks out: %d walkable cells reached, every thing usable" % (m.name, len(everywhere)))


def dump(m):
    """The map as text, terrain and height side by side (python3 build_village.py --dump)."""
    for y in range(m.h):
        props = _prop_cells(m)
        row_t = "".join("#" if (x, y) in props and m.props and props[(x, y)]["sprite"].startswith("b_")
                        else ("*" if (x, y) in props else m.terrain[y][x]) for x in range(m.w))
        row_h = "".join(str(m.height[y][x]) if m.terrain[y][x] != "." else " " for x in range(m.w))
        print("%2d %s   %s" % (y, row_t, row_h))


def _seg_dist(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = 0.0 if dx == 0 and dy == 0 else max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def ribbon(m, pts, r, t=None, h=None, only=None):
    """Cells whose centre lies within r of the polyline. `only`: a test (x, y) -> bool to limit it."""
    out = []
    for y in range(m.h):
        for x in range(m.w):
            if only is not None and not only(x, y):
                continue
            if any(_seg_dist(x + 0.5, y + 0.5, *pts[i], *pts[i + 1]) <= r for i in range(len(pts) - 1)):
                out.append((x, y))
                m.put(x, y, t, h)
    return out


def poly(m, pts, t=None, h=None):
    """Cells whose centre lies inside the polygon (corner coordinates)."""
    out = []
    for y in range(m.h):
        for x in range(m.w):
            px, py, inside = x + 0.5, y + 0.5, False
            for i in range(len(pts)):
                (ax, ay), (bx, by) = pts[i], pts[i - 1]
                if (ay > py) != (by > py) and px < ax + (py - ay) * (bx - ax) / (by - ay):
                    inside = not inside
            if inside:
                out.append((x, y))
                m.put(x, y, t, h)
    return out


FLIGHTS = {}  # stair cell -> the axis its flight runs along, for check_village


def flight(m, cells, top):
    """A stair flight: `cells` is a list of rows from the top of the flight down, each row a list of cells
    side by side (one or two). The first row stands at `top`, each next one a level lower."""
    a, b = cells[0][0], cells[1][0]
    axis = (1, 0) if a[0] != b[0] else (0, 1)
    for i, row in enumerate(cells):
        for x, y in row:
            m.put(x, y, "t", top - i)
            FLIGHTS[(x, y)] = axis


def _bump(v, spans):
    """Edge inset at position v along an edge: the deepest of the spans (lo, hi, depth), rounded at the ends."""
    d = 0
    for lo, hi, depth in spans:
        if lo <= v <= hi:
            d = max(d, min(depth, 1 + min(v - lo, hi - v)))
    return d
