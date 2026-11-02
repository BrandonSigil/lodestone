#!/usr/bin/env python3
"""Writes the starter plots ([USER] 2026-11-01, battle-maps plan: "pre-seed it with 5-6 that seem good to you and
that I can tinker with later"; then more forest plots and a few per road-fight region) to
game/data/plots/<region>/<id>.json. A plot is two character layers (MapPlot in
game/scripts/combat/map_plot.gd): levels ("." outside, "0"-"3" terraces) and marks (" " ground, "d" road, "w" water,
"b" bridge, "s" stairs, "r" rock, "t" woods). This script only seeds them: after that the json files are Brandon's to
edit in the map maker's plot mode (or by hand), and re-running this would overwrite his edits, so it refuses to touch a
file that already exists unless --force.

    python3 tools/plots/seed_plots.py [--force] [region]

Each plot is drawn here from simple pieces (a ragged island, terrace bands, a road line with stairs where it climbs, a
river line, rock outcrops) and scored with tools/map_shape.py's measures on its own footprint before it is written.
"""
import json
import math
import sys
from pathlib import Path

W, H = 21, 18
OUT = Path(__file__).resolve().parents[2] / "game" / "data" / "plots"


def hsh(x, y, s):
    v = (x * 73856093) ^ (y * 19349663) ^ (s * 83492791)
    return ((v >> 7) % 1000) / 1000.0


class Plot:
    def __init__(self, pid, note, river="", flip=None, region="forest"):
        self.region = region
        self.id, self.note, self.river_job, self.flip = pid, note, river, flip
        self.bites = False
        self.draft = False  # true: road fights skip it (still being drawn; Brandon's to finish)  # ragged rim bites (bite); the smooth plots leave them off
        self.lv = [["." for _ in range(W)] for _ in range(H)]
        self.mk = [[" " for _ in range(W)] for _ in range(H)]

    def island(self, lobes, seed, jag=0.9):
        """Ground where any lobe (cx, cy, rx, ry) covers the cell, the rim made ragged by a little noise."""
        for y in range(H):
            for x in range(W):
                for (cx, cy, rx, ry) in lobes:
                    d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                    if d <= 1.0 + (hsh(x, y, seed) - 0.5) * jag * 0.6:
                        self.lv[y][x] = "0"
                        break

    def corridor(self, pts, half, seed, jag=0.0):
        """Ground within `half` cells of the path through pts (a little noise on the rim): a footprint that follows a
        road, a spine or a bank, so the map winds instead of filling a box."""
        segs = list(zip(pts, pts[1:])) or [(pts[0], pts[0])]
        for y in range(H):
            for x in range(W):
                d = min(seg_dist(x, y, a, b) for a, b in segs)
                if d <= half + (hsh(x, y, seed) - 0.5) * jag:
                    self.lv[y][x] = "0"

    def spurs(self, lines):
        """Narrow promontories: each (a, b) is a two-cell-wide finger of ground from a to b (a ledge, a point, a bluff),
        a jut-out the eye reads as a place, where rim bites read as noise."""
        for (a, b) in lines:
            self.corridor([a, b], 0.75, 0)

    def cut(self, cells):
        """Clefts: these cells go back outside the map (an inlet into a mass, a gully in a slope)."""
        for (x, y) in cells:
            if 0 <= x < W and 0 <= y < H:
                self.lv[y][x] = "."
                self.mk[y][x] = " "

    def lake(self, cx, cy, rx, ry):
        """Still water filling an ellipse of ground (a pond or a lake; no bridge, the road goes round)."""
        for y in range(H):
            for x in range(W):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0 and self.lv[y][x] != ".":
                    self.mk[y][x] = "w"

    def terraces(self, fn):
        for y in range(H):
            for x in range(W):
                if self.lv[y][x] != ".":
                    self.lv[y][x] = str(max(0, min(3, fn(x, y))))

    def keep_starts(self, rows, left=True, right=True):
        """The deploy edges (x 0-1 and W-2..W-1) are ground on these rows, on the terrace next to them."""
        for y in rows:
            for x in ((0, 1) if left else ()):
                self.lv[y][x] = self.lv[y][2] if self.lv[y][2] != "." else "0"
            for x in ((W - 2, W - 1) if right else ()):
                self.lv[y][x] = self.lv[y][W - 3] if self.lv[y][W - 3] != "." else "0"

    def line(self, pts):
        cells = []
        for (a, b) in zip(pts, pts[1:]):
            (x0, y0), (x1, y1) = a, b
            n = max(abs(x1 - x0), abs(y1 - y0))
            for i in range(n + 1):
                c = (round(x0 + (x1 - x0) * i / max(1, n)), round(y0 + (y1 - y0) * i / max(1, n)))
                if not cells or cells[-1] != c:
                    if cells and c[0] != cells[-1][0] and c[1] != cells[-1][1]:  # no diagonal steps: go round the corner
                        cells.append((c[0], cells[-1][1]))
                    cells.append(c)
        return cells

    def road(self, pts):
        """A road along the points; where it meets a step between terraces it gets a stair on the lower side."""
        cells = self.line(pts)
        for (x, y) in cells:
            if self.lv[y][x] == ".":
                self.lv[y][x] = "0"
            self.mk[y][x] = "b" if self.mk[y][x] in "wb" else "d"  # over the river: the bridge
        for (a, b) in zip(cells, cells[1:]):
            if "b" in (self.mk[a[1]][a[0]], self.mk[b[1]][b[0]]):
                continue  # a bridge spans from bank to bank: the water under it keeps its own level
            la, lb = int(self.lv[a[1]][a[0]]), int(self.lv[b[1]][b[0]])
            if abs(la - lb) == 1:
                lo = a if la < lb else b
                if self.mk[lo[1]][lo[0]] == "d":
                    self.mk[lo[1]][lo[0]] = "s"
            elif abs(la - lb) > 1:  # flatten: the road never jumps two terraces
                self.lv[b[1]][b[0]] = str(la + (1 if lb > la else -1))
        return cells

    def river(self, pts, width=1):
        for (x, y) in self.line(pts):
            for k in range(width):
                yy = y + k
                if 0 <= yy < H and 0 <= x < W and self.lv[yy][x] != ".":
                    self.mk[yy][x] = "b" if self.mk[yy][x] in "ds" else "w"

    def mark(self, cells, ch):
        for (x, y) in cells:
            if 0 <= x < W and 0 <= y < H and self.lv[y][x] != "." and self.mk[y][x] == " ":
                self.mk[y][x] = ch

    def stair(self, cells):
        self.mark(cells, "s")

    def rocks(self, cells):
        self.mark(cells, "r")

    def woods(self, cells):
        self.mark(cells, "t")

    def bite(self, seed, fill_max=0.52, edge_min=1.45, cells_min=150, tries=400):
        """Ragged enough without eating the fight: small void bites into the rim (never the road, stairs, water, rocks or
        the start edges, nor next to them) while the footprint fills more than fill_max of its box and stays above
        cells_min; then single rock outcrops on quiet ground, two apart, while its edge is under edge_min (cover, too)."""
        quiet = lambda xx, yy: not any(0 <= xx + dx < W and 0 <= yy + dy < H and self.mk[yy + dy][xx + dx] in "dswbr"
                                       for dx in (-1, 0, 1) for dy in (-1, 0, 1))
        for k in range(tries):
            sc = score(self)
            if sc["fill"] <= fill_max or sc["cells"] <= cells_min:
                break
            rim = [(x, y) for y in range(H) for x in range(2, W - 2) if self.lv[y][x] != "." and self.mk[y][x] in " t"
                   and any(not (0 <= x + dx < W and 0 <= y + dy < H) or self.lv[y + dy][x + dx] == "." for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
            if not rim:
                break
            rim.sort(key=lambda c: hsh(c[0], c[1], seed + k))
            x, y = rim[0]
            r = 1.0 + hsh(x, y, seed + 99 + k) * 0.6
            for yy in range(max(0, y - 2), min(H, y + 3)):
                for xx in range(max(2, x - 2), min(W - 2, x + 3)):
                    if math.hypot(xx - x, yy - y) <= r and self.lv[yy][xx] != "." and quiet(xx, yy):
                        self.lv[yy][xx] = "."
                        self.mk[yy][xx] = " "
        for k in range(tries):
            if score(self)["edge"] >= edge_min:
                break
            clear4 = lambda xx, yy: not any(self.mk[yy + dy][xx + dx] in "dswbr" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            spots = [(x, y) for y in range(1, H - 1) for x in range(3, W - 3) if self.lv[y][x] != "." and self.mk[y][x] == " " and clear4(x, y)
                     and all(self.lv[y + dy][x + dx] != "." for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
            if not spots:
                break
            spots.sort(key=lambda c: hsh(c[0], c[1], seed + 500 + k))
            self.mk[spots[0][1]][spots[0][0]] = "r"

    def mirrored(self, pid, note, region):
        """This plot drawn left to right the other way (each start keeps its edge), as a new plot of a region: a proven
        plan in another region's look, a separate file Brandon can change on its own."""
        q = Plot(pid, note, self.river_job, self.flip, region)
        q.lv = [list(reversed(r)) for r in self.lv]
        q.mk = [list(reversed(r)) for r in self.mk]
        q.bites, q.draft = self.bites, False
        return q

    def data(self):
        d = {"id": self.id, "region": self.region, "river": self.river_job, "note": self.note,
             "levels": ["".join(r) for r in self.lv], "marks": ["".join(r) for r in self.mk]}
        if self.draft:
            d["draft"] = True
        if self.flip is not None:  # pinned: the side the plot faces the camera with (a bowl's open side, a river's bank)
            d["flip"] = self.flip
        return d


def path_y(pts, x):
    """The path's y at column x (straight between its points): terraces that follow a bending road."""
    for (a, b) in zip(pts, pts[1:]):
        if a[0] <= x <= b[0]:
            return a[1] + (b[1] - a[1]) * (x - a[0]) / max(1, b[0] - a[0])
    return pts[-1][1] if x > pts[-1][0] else pts[0][1]


def seg_dist(x, y, a, b):
    (ax, ay), (bx, by) = a, b
    vx, vy = bx - ax, by - ay
    t = 0.0 if vx == vy == 0 else max(0.0, min(1.0, ((x - ax) * vx + (y - ay) * vy) / float(vx * vx + vy * vy)))
    return math.hypot(x - (ax + vx * t), y - (ay + vy * t))


def score(p):
    """tools/map_shape.py's measures on the plot's own walkable footprint (ground, road, stairs, woods, bridges)."""
    walk = [[p.lv[y][x] != "." and p.mk[y][x] not in "wr" for x in range(W)] for y in range(H)]
    for y in range(H):
        for x in range(W):
            if p.mk[y][x] == "b":
                walk[y][x] = True
    cells = [(x, y) for y in range(H) for x in range(W) if walk[y][x]]
    xs, ys = [c[0] for c in cells], [c[1] for c in cells]
    bw, bh = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1
    x0, y0 = min(xs), min(ys)
    fill = len(cells) / (bw * bh)
    edge = sum(1 for x, y in cells if any(not (0 <= x + dx < W and 0 <= y + dy < H and walk[y + dy][x + dx]) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))))
    corners = sum(1 for y in range(-1, H) for x in range(-1, W)
                  if sum(1 for dx in (0, 1) for dy in (0, 1) if 0 <= x + dx < W and 0 <= y + dy < H and walk[y + dy][x + dx]) in (1, 3))
    qw, qh = max(1, bw // 4), max(1, bh // 4)
    bays = sum(1.0 - sum(1 for y in range(cy, cy + qh) for x in range(cx, cx + qw) if walk[y][x]) / (qw * qh)
               for (cx, cy) in ((x0, y0), (x0 + bw - qw, y0), (x0, y0 + bh - qh), (x0 + bw - qw, y0 + bh - qh))) / 4.0
    levels = len({p.lv[y][x] for x, y in cells})
    seen, runs = set(), 0
    for x, y in cells:
        if p.mk[y][x] != "s" or (x, y) in seen:
            continue
        runs += 1
        st = [(x, y)]
        while st:
            c = st.pop()
            if c in seen:
                continue
            seen.add(c)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (c[0] + dx, c[1] + dy)
                if 0 <= n[0] < W and 0 <= n[1] < H and p.mk[n[1]][n[0]] == "s":
                    st.append(n)
    return {"cells": len(cells), "fill": round(fill, 2), "edge": round(edge / (2.0 * (bw + bh)), 2),
            "corners": round(100.0 * corners / len(cells), 1), "bays": round(bays, 2), "terraces": levels, "climbs": runs}


PLOTS = []


def plot(fn):
    PLOTS.append(fn)
    return fn


@plot
def bend():
    p = Plot("bend", "A road bends round a high shoulder; a flank river follows the same bend along the low side.", "flank", flip=False)
    road = [(0, 9), (6, 9), (9, 6), (14, 6), (20, 8)]
    river = [(x, y + 4) for (x, y) in road]
    p.corridor(road, 1.6, 1)
    p.corridor(river, 1.2, 11)
    p.spurs([((3, 7), (2, 3)), ((11, 4), (11, 1)), ((17, 6), (19, 2)), ((7, 5), (6, 2)), ((14, 4), (15, 2))])
    p.terraces(lambda x, y: (lambda dy: 0 if dy >= 2 else (1 if dy >= -1 else (2 if dy >= -3 else 3)))(y - path_y(road, x)))
    p.keep_starts(range(7, 12))
    p.river(river, 2)
    p.road([(0, 9), (6, 9), (6, 7), (9, 7), (9, 6), (14, 6), (14, 8), (20, 8)])
    p.stair([(11, 4), (3, 6), (17, 5), (14, 3)])
    p.rocks([(13, 3), (12, 9), (3, 10), (19, 7), (16, 7)])
    p.woods([(2, 4), (16, 3), (8, 9), (18, 10)])
    return p


@plot
def bridge_crossing():
    p = Plot("bridge_crossing", "A crossing river cuts between the starts; the road takes its one bridge at the narrows.", "crossing")
    p.island([(4, 6, 3.6, 3.4), (5, 13, 3, 2.2), (16, 12, 3.6, 3.4), (16, 4, 2.6, 2.2)], 2, jag=0)
    p.corridor([(0, 9), (20, 9)], 1.6, 22)
    p.corridor([(10, 1), (10, 16)], 2.2, 12)
    p.spurs([((6, 3), (7, 0)), ((15, 14), (14, 17)), ((19, 5), (20, 2)), ((1, 13), (0, 16)), ((16, 5), (16, 8))])
    p.terraces(lambda x, y: (3 if y < 4 and x < 7 else (2 if y < 7 or y > 12 else 1)) if x < 10 else (2 if x > 16 and y > 12 else (0 if y < 5 and x < 18 else 1)))
    p.keep_starts(range(8, 11))
    p.river([(10, 0), (10, 17)], 1)
    p.river([(11, 0), (11, 17)], 1)
    p.road([(0, 9), (20, 9)])
    p.stair([(4, 6), (6, 12), (15, 5), (17, 12), (17, 3)])
    p.rocks([(2, 4), (14, 13)])
    p.woods([(2, 11), (3, 11), (17, 7), (18, 7)])
    return p


@plot
def hollow():
    p = Plot("hollow", "The road dips through a round sunken clearing; terraces ring it and a pool sits under the back rim.", flip=False)
    p.island([(10, 9, 7.6, 6.4)], 4, jag=0)
    p.corridor([(0, 9), (20, 9)], 1.4, 24)
    p.spurs([((4, 4), (1, 1)), ((16, 4), (19, 1)), ((5, 14), (2, 17)), ((15, 14), (18, 17))])
    ring = lambda x, y: math.hypot((x - 10) / 1.25, (y - 9) / 1.0)
    p.terraces(lambda x, y: 0 if ring(x, y) < 3.4 else (1 if ring(x, y) < 4.6 or (y > 9 and ring(x, y) < 5.8) else (2 if ring(x, y) < 5.8 or y > 9 else 3)))
    p.keep_starts(range(8, 11))
    p.road([(0, 9), (20, 9)])
    p.river([(8, 6), (12, 6)], 2)
    p.stair([(10, 4), (5, 7), (15, 7), (6, 12), (14, 12), (4, 5), (16, 5)])
    p.cut([(10, 0), (10, 1), (10, 17), (10, 16)])
    p.woods([(7, 3), (13, 3), (3, 12), (17, 12), (12, 11)])
    p.draft = True  # failed the look check on 2026-11-01 (read as a box / a maze): a start for Brandon to tinker with
    return p


@plot
def switchback():
    p = Plot("switchback", "The road switches back and forth up three terraces to the foes' shelf; a stair is the steep short cut.")
    path = [(0, 14), (3, 14), (3, 4), (9, 4), (9, 13), (15, 13), (15, 5), (20, 5)]
    p.corridor(path, 1.7, 5, jag=1.6)
    p.island([(18, 9, 2.6, 2.4)], 25)
    p.terraces(lambda x, y: 0 if x < 6 else (1 if x < 12 else (2 if x < 17 else 3)))
    p.keep_starts(range(12, 16), right=False)
    p.keep_starts(range(3, 8), left=False)
    p.cut([(19, 11)])
    p.road(path)
    p.road([(3, 9), (15, 9)])  # the steep short cut: a goat path straight up the slope
    p.stair([(17, 9)])
    p.rocks([(7, 7), (13, 10), (1, 11)])
    p.woods([(10, 15), (11, 15), (16, 2), (2, 6)])
    p.bites = True
    return p


@plot
def rocky_pass():
    p = Plot("rocky_pass", "Two high rock shoulders, one each side, bend the road into a narrow dogleg pass; ledges on each shoulder look down on it.")
    p.corridor([(0, 8), (7, 8), (9, 10), (13, 10), (20, 10)], 1.5, 6)
    p.island([(6, 3.5, 4.5, 3.2), (14, 15, 4.5, 3.0)], 16, jag=0)
    p.spurs([((3, 4), (0, 2)), ((9, 2), (12, 0)), ((17, 15), (20, 17)), ((11, 16), (8, 17)), ((13, 7), (16, 5)), ((7, 12), (4, 14))])
    p.terraces(lambda x, y: 3 if math.hypot((x - 6) / 4.5, (y - 3.5) / 3.2) < 0.7 or math.hypot((x - 14) / 4.5, (y - 15) / 3.0) < 0.7 else (2 if y < 6 or y > 12 else 1))
    p.keep_starts(range(6, 11))
    p.road([(0, 8), (7, 8), (7, 10), (20, 10)])
    p.stair([(4, 6), (14, 12), (6, 2), (14, 13), (2, 6), (17, 12)])
    p.rocks([(8, 6), (12, 12), (16, 8), (3, 10)])
    p.woods([(9, 4), (11, 14), (15, 6), (5, 12)])
    p.draft = True  # failed the look check on 2026-11-01 (read as a box / a maze): a start for Brandon to tinker with
    return p


@plot
def fork():
    p = Plot("fork", "The road forks round a tall wooded knoll and joins again; the knoll looks down on both branches.")
    north = [(4, 9), (4, 4), (16, 4), (16, 9)]
    south = [(4, 9), (4, 14), (16, 14), (16, 9)]
    for path in ([(0, 9), (4, 9)], north, south, [(16, 9), (20, 9)]):
        p.corridor(path, 0.9, 7)
    p.island([(10, 9, 6.2, 5.0)], 17, jag=0)
    p.spurs([((10, 3), (10, 0)), ((10, 15), (10, 17)), ((4, 6), (1, 3)), ((16, 12), (19, 15)), ((6, 3), (6, 0)), ((14, 3), (14, 0)), ((6, 15), (6, 17)), ((14, 15), (14, 17))])
    knoll = lambda x, y: math.hypot((x - 10) / 5.0, (y - 9) / 3.8)
    p.terraces(lambda x, y: 3 if knoll(x, y) < 0.22 else (2 if knoll(x, y) < 0.5 else (1 if knoll(x, y) < 1.0 or y < 3 or y > 15 else 0)))
    p.keep_starts(range(8, 11))
    p.road([(0, 9), (4, 9), (4, 4), (16, 4), (16, 9), (20, 9)])
    p.road([(4, 9), (4, 14), (16, 14), (16, 9)])
    p.stair([(10, 5), (10, 7), (10, 8), (10, 13), (10, 11), (10, 10), (5, 9), (15, 9), (10, 3), (10, 15), (6, 3), (14, 3), (6, 15), (14, 15)])
    p.rocks([(2, 8), (18, 10), (8, 4), (12, 14), (1, 3), (19, 15)])
    p.cut([(6, 6), (6, 12), (14, 12), (14, 6), (7, 5), (13, 5), (7, 13), (13, 13), (6, 7), (14, 11), (6, 11), (14, 7)])
    p.woods([(9, 9), (11, 9), (8, 10), (12, 8), (2, 4), (18, 14), (10, 1), (10, 17)])
    p.draft = True  # failed the look check on 2026-11-01 (the knoll reads too low, a ring road on a slab)
    return p


@plot
def lakeshore():
    p = Plot("lakeshore", "The road curves along a lake shore under a wooded bluff; the far shore is a high bank with a lookout.", flip=False)
    road = [(0, 8), (5, 12), (14, 12), (20, 8)]
    p.corridor(road, 1.6, 8)
    p.island([(10, 6.5, 6.5, 4.2), (10, 1.6, 2.6, 1.4)], 18, jag=0)
    p.spurs([((5, 4), (1, 2)), ((15, 4), (19, 1)), ((9, 13), (8, 16)), ((13, 13), (14, 16)), ((3, 11), (1, 14)), ((17, 11), (19, 14))])
    p.cut([(6, 15), (14, 15), (4, 13), (16, 13), (9, 11), (11, 11), (0, 7), (1, 7), (19, 7), (20, 7), (14, 16), (14, 17)])
    p.terraces(lambda x, y: 0 if math.hypot((x - 10) / 4.2, (y - 6.5) / 2.6) <= 1.0 else (3 if y < 3 else (2 if y < 8 else 1)))
    p.lake(10, 6.5, 4.2, 2.6)
    p.keep_starts(range(8, 11))
    p.road([(0, 8), (2, 8), (2, 10), (5, 10), (5, 12), (14, 12), (14, 10), (18, 10), (18, 8), (20, 8)])
    p.stair([(4, 8), (16, 8), (10, 3), (2, 3), (17, 3)])
    p.rocks([(3, 4), (17, 3), (6, 6), (14, 6), (12, 10)])
    p.woods([(2, 3), (3, 3), (18, 4), (11, 14), (7, 14)])
    return p


@plot
def gorge():
    p = Plot("gorge", "A river has cut a deep gorge between the starts; the road crosses it high up on one bridge.", "crossing", flip=False)
    gorge = [(8, 0), (10, 8), (12, 17)]
    p.corridor(gorge, 3.2, 9)
    p.corridor([(0, 9), (20, 9)], 1.6, 19)
    p.island([(3, 5, 3, 2.6), (17, 13, 3, 2.6)], 29, jag=0)
    p.spurs([((7, 12), (2, 15)), ((13, 6), (18, 3)), ((7, 3), (4, 1)), ((13, 15), (16, 17))])
    deep = lambda x, y: min(seg_dist(x, y, a, b) for a, b in zip(gorge, gorge[1:]))
    p.terraces(lambda x, y: 0 if deep(x, y) < 1.1 or (x <= 3 and abs(y - 9) <= 2) else (3 if (x < 6 and y < 7) or (x > 14 and y > 11) else (2 if abs(y - 9) >= 3 else 1)))
    for y in range(H):  # the gorge floor is all river
        for x in range(W):
            if p.lv[y][x] == "0" and deep(x, y) < 1.1:
                p.mk[y][x] = "w"
    p.keep_starts(range(8, 11))
    p.cut([(5, 0), (4, 1), (5, 1), (5, 2), (15, 16), (15, 17), (16, 16), (16, 17), (17, 17)])
    p.road([(0, 9), (20, 9)])
    p.stair([(6, 5), (14, 13), (7, 7), (12, 7), (8, 11), (13, 11)])
    p.woods([(3, 4), (4, 4), (17, 14), (16, 14), (6, 14), (14, 4)])
    p.draft = True  # failed the look check on 2026-11-01 (the gorge read as thin and hidden, slabs round it)
    return p


# --- snow (the snowy roads: pass, mines, dam, plains) ---------------------------------------------

@plot
def zigzag():
    p = Plot("zigzag", "The road climbs a snowy slope in long zigzags to the foes' shelf; a goat path cuts straight up.", region="snow", flip=False)
    path = [(0, 15), (14, 15), (14, 11), (5, 11), (5, 7), (16, 7), (16, 3), (20, 3)]
    p.corridor(path, 1.5, 3)
    p.island([(18, 3, 2.6, 2.6)], 13, jag=0)
    p.spurs([((2, 15), (1, 12)), ((12, 11), (13, 8)), ((7, 7), (6, 4)), ((9, 15), (9, 17)), ((3, 11), (2, 9)), ((12, 7), (12, 4))])
    p.terraces(lambda x, y: 0 if y >= 13 else (1 if y >= 9 else (2 if y >= 5 else 3)))
    p.keep_starts(range(13, 18), right=False)
    p.keep_starts(range(1, 6), left=False)
    p.road(path)
    p.road([(10, 15), (10, 7)])  # the goat path straight up the slope
    p.stair([(3, 12), (17, 8)])
    p.rocks([(7, 13), (12, 9), (8, 5), (2, 16)])
    p.woods([(1, 13), (13, 13), (3, 9), (14, 5), (6, 5)])
    p.cut([(19, 6), (20, 6), (6, 4), (12, 4), (1, 12)])
    p.draft = True  # failed the look check on 2026-11-01 (read as a slab with trails on it)
    return p


@plot
def ice_bridge():
    p = Plot("ice_bridge", "A river steps down the slope in frozen falls between the starts; the road crosses it on one bridge.", "crossing", region="snow")
    river = [(5, 0), (10, 9), (15, 17)]
    p.corridor(river, 2.6, 4)
    p.corridor([(0, 9), (20, 9)], 1.6, 14)
    p.island([(3, 4, 2.8, 3.0), (17, 13, 2.8, 3.2), (3, 14, 2.4, 3.0), (17, 4, 2.4, 3.0)], 24, jag=0)
    p.spurs([((6, 4), (8, 1)), ((14, 13), (12, 16)), ((1, 11), (0, 14)), ((19, 6), (20, 3)), ((15, 4), (13, 1)), ((5, 13), (7, 16))])
    p.terraces(lambda x, y: 3 if y < 3 and x < 6 else (2 if y < 6 else (1 if y < 12 else 0)))
    p.river(river, 1)
    p.river([(6, 0), (11, 9), (16, 17)], 1)
    p.keep_starts(range(8, 11))
    p.cut([(9, 2), (9, 3), (10, 4), (10, 5), (11, 6), (11, 7), (9, 12), (10, 13), (11, 15), (13, 15), (12, 16), (13, 16), (12, 17), (13, 17), (14, 17), (9, 1), (10, 3), (11, 5), (10, 12), (11, 14), (12, 15), (8, 1), (11, 12), (11, 13), (12, 14)])
    p.road([(0, 9), (20, 9)])
    p.stair([(3, 3), (7, 6), (17, 6), (3, 12), (17, 12), (12, 12)])
    p.rocks([(14, 7), (5, 11), (2, 9), (18, 9), (4, 15), (16, 3)])
    p.woods([(2, 3), (3, 3), (18, 15), (17, 15), (2, 15), (18, 3)])
    return p


@plot
def cliff_road():
    p = Plot("cliff_road", "The road runs along a ledge cut into a high cliff; the snowfield below has its own way up at each end.", region="snow", flip=False)
    road = [(0, 7), (6, 6), (14, 6), (20, 8)]
    p.corridor(road, 1.2, 5)
    p.island([(10, 2.6, 6.5, 2.2)], 15, jag=0)
    p.corridor([(2, 10), (8, 11), (13, 11), (18, 10)], 1.2, 25)
    p.island([(5, 14, 3, 2.2), (15, 14, 3, 2.2)], 35, jag=0)
    p.terraces(lambda x, y: (lambda dy: 3 if dy < -1.5 else (2 if dy < 1.5 else (1 if dy < 4.6 else 0)))(y - path_y(road, x)))
    for y in range(6, 10):  # the foes' start: the end of the ledge, flush with it
        for x in (W - 2, W - 1):
            p.lv[y][x] = "2"
    p.road(road)
    p.stair([(10, 4), (4, 4), (16, 5), (17, 9), (6, 11), (14, 11), (3, 9)])
    p.rocks([(8, 2), (12, 3), (10, 15)])
    p.woods([(5, 15), (6, 15), (15, 15), (9, 11), (13, 2)])
    p.draft = True  # failed the look check on 2026-11-01 (read as one long slab)
    return p


# --- proven plans in the other region's look (mirrored left to right) ------------------------------

@plot
def falls():
    return ice_bridge().mirrored("falls", "A river steps down the slope in falls between the starts; the road crosses it on one bridge.", "forest")


@plot
def frozen_lake():
    return lakeshore().mirrored("frozen_lake", "The road curves along a frozen lake under a bluff; the far shore is a high bank with a lookout.", "snow")


@plot
def snow_switchback():
    p = switchback()
    if p.bites:
        p.bite(sum(ord(ch) for ch in p.id))
    q = p.mirrored("snow_switchback", "The road switches back and forth across a snowy slope; a goat path is the steep short cut.", "snow")
    q.bites = False
    q.draft = True  # failed the look check on 2026-11-01 (snow terraces read as stacked boxes)
    return q


def main():
    """--force overwrites existing files; --only=a,b writes just those plots (use it: the rest may be Brandon's now);
    a bare word limits it to one region."""
    force = "--force" in sys.argv
    only = next((a.split("=", 1)[1].split(",") for a in sys.argv if a.startswith("--only=")), None)
    region = next((a for a in sys.argv[1:] if not a.startswith("--")), None)
    for fn in PLOTS:
        p = fn()
        if (only and p.id not in only) or (region and p.region != region):
            continue
        if p.bites:
            p.bite(sum(ord(ch) for ch in p.id))
        s = score(p)
        out = OUT / p.region
        out.mkdir(parents=True, exist_ok=True)
        path = out / f"{p.id}.json"
        if path.exists() and not force:
            print(f"kept   {p.region}/{path.name} (exists; --force overwrites)  {s}")
            continue
        path.write_text(json.dumps(p.data(), indent=1) + "\n")
        print(f"wrote  {p.region}/{path.name}  {s}")


if __name__ == "__main__":
    main()
