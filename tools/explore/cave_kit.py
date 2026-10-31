"""Winding cave and dungeon layouts from rounded rooms and climbing links (the crypt's method, shared).

    c = Cave(30, 30)
    c.room("entry", 6, 26, 4, 3, 1)
    c.link("a_b", "entry", "hall", "x", 3)       # climbs a level a cell, centred; stairs ('t') on each rise
    c.finish()                                    # walls rise over open ground; rock far from ground is void
    c.t[y][x], c.h[y][x]

Rooms are superellipses inside their box, so outlines curve. A link carves from room a's centre to room b's centre
(x first or y first), outside both rooms, and asserts it is long enough for the climb.
"""


class Cave:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.t = [["r"] * w for _ in range(h)]
        self.h_ = [[0] * w for _ in range(h)]
        self.rooms = {}
        self.links = {}

    @property
    def hts(self):
        return self.h_

    def inside(self, r, x, y):
        cx, cy, rx, ry, h, p = r["box"]
        return abs((x - cx) / (rx + 0.5)) ** p + abs((y - cy) / (ry + 0.5)) ** p <= 1.0

    def room(self, name, cx, cy, rx, ry, h, t="g", p=2.6):
        r = self.rooms[name] = {"box": (cx, cy, rx, ry, h, p), "h": h}
        for y in range(max(0, cy - ry - 1), min(self.h, cy + ry + 2)):
            for x in range(max(0, cx - rx - 1), min(self.w, cx + rx + 2)):
                if self.inside(r, x, y):
                    self.t[y][x] = t
                    self.h_[y][x] = h

    def link(self, name, a, b, first="x", width=3, to_off=(0, 0), floor="d"):
        ra, rb = self.rooms[a], self.rooms[b]
        pa = ra["box"][:2]
        pb = (rb["box"][0] + to_off[0], rb["box"][1] + to_off[1])
        x, y = pa
        path = []
        order = [("x", pb[0]), ("y", pb[1])] if first == "x" else [("y", pb[1]), ("x", pb[0])]
        for axis, target in order:
            while (x if axis == "x" else y) != target:
                if axis == "x":
                    x += 1 if target > x else -1
                else:
                    y += 1 if target > y else -1
                path.append((x, y))
        path = [c for c in path if not self.inside(ra, *c) and not self.inside(rb, *c)]
        ha, hb = ra["h"], rb["h"]
        n, dh = len(path), abs(hb - ha)
        assert n >= max(dh, 1), f"{a}->{b}: {n} cells for a {dh} level climb"
        sign = 1 if hb > ha else -1
        hs = [ha + sign * max(0, min(dh, i + 1 - (n - dh) // 2)) for i in range(n)]
        cells = set()
        for i, (x, y) in enumerate(path):
            horizontal = (i + 1 < n and path[i + 1][1] == y) or (i + 1 >= n and i > 0 and path[i - 1][1] == y)
            for o in range(-(width // 2), width // 2 + 1):
                cx, cy = (x, y + o) if horizontal else (x + o, y)
                if not (0 <= cx < self.w and 0 <= cy < self.h) or self.t[cy][cx] != "r":
                    continue
                cells.add((cx, cy))
                self.h_[cy][cx] = hs[i]
                self.t[cy][cx] = floor
                if i + 1 < n and hs[i + 1] == hs[i] + 1:
                    self.t[cy][cx] = "t"
                if i > 0 and hs[i - 1] == hs[i] + 1:
                    self.t[cy][cx] = "t"
        self.links[name] = cells
        return path

    def finish(self, max_wall=24):
        w, h = self.w, self.h
        for y in range(h):
            for x in range(w):
                if self.t[y][x] != "r":
                    continue
                best = None
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and self.t[ny][nx] not in "r.":
                            best = max(best or 0, self.h_[ny][nx])
                self.h_[y][x] = 0 if best is None else min(max_wall, best + 2)
        for y in range(h):
            for x in range(w):
                if self.t[y][x] == "r" and self.h_[y][x] == 0:
                    self.t[y][x] = "."
