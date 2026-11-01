#!/usr/bin/env python3
"""Builds game/data/explore/crypt.json: the crypt ([USER] 2026-10-30, redesign card
builder-crypt-redesign-present: courtyard start, a bridge, big crypt doors, branching paths and interesting rooms, several
routes, a windy outline that is not a rectangle; then "unique shapes, jut outs, dynamics, verticality!"). Graybox, no story.

A winding chain of rooms at different heights with voids between them, joined by corridors that climb a level a cell,
a long bridge over a chasm and a lookout jut-out. Rooms are rounded; rock far from any ground is void, so the outline is
what the rooms and links make. Three routes reach the throne: up the middle (hall, gallery, junction, grand stair), east
(chapel, east wing), and west (gate, cellar, library); the junction and the east wing are also joined by the long bridge.
Run: python3 tools/explore/build_crypt.py   Check: python3 tools/map_shape.py game/data/explore/crypt.json
"""
import json
import os

HD = "0123456789abcdefghijklmnopqrstuvwxyz"
W, H = 76, 62
terrain = [["r"] * W for _ in range(H)]
height = [[0] * W for _ in range(H)]
ROOMS = {}
LINKS = {}  # name -> set of cells, for the route checks


def inside(r, x, y):
    cx, cy, rx, ry, h, p = r["box"]
    return abs((x - cx) / (rx + 0.5)) ** p + abs((y - cy) / (ry + 0.5)) ** p <= 1.0


def room(name, cx, cy, rx, ry, h, t="s", p=2.6):
    ROOMS[name] = {"box": (cx, cy, rx, ry, h, p), "t": t, "h": h}
    for y in range(max(0, cy - ry - 1), min(H, cy + ry + 2)):
        for x in range(max(0, cx - rx - 1), min(W, cx + rx + 2)):
            if inside(ROOMS[name], x, y):
                terrain[y][x] = t
                height[y][x] = h


def pillars(name, pts):
    r = ROOMS[name]
    for dx, dy in pts:
        x, y = r["box"][0] + dx, r["box"][1] + dy
        if inside(r, x, y):
            terrain[y][x] = "u"


def cells_between(a, b, first):
    (x0, y0), (x1, y1) = a, b
    out = []
    x, y = x0, y0
    if first == "x":
        while x != x1:
            x += 1 if x1 > x else -1
            out.append((x, y))
        while y != y1:
            y += 1 if y1 > y else -1
            out.append((x, y))
    else:
        while y != y1:
            y += 1 if y1 > y else -1
            out.append((x, y))
        while x != x1:
            x += 1 if x1 > x else -1
            out.append((x, y))
    return out


def link(name, a, b, first="x", width=3, bridge=False, door=None, to_off=(0, 0)):
    """Carve a way from room a's centre to room b's centre, outside both. Heights climb a level a cell, centred; a
    bridge stays flat over a chasm."""
    ra, rb = ROOMS[a], ROOMS[b]
    pa, pb = ra["box"][:2], (rb["box"][0] + to_off[0], rb["box"][1] + to_off[1])
    path = [c for c in cells_between(pa, pb, first) if not inside(ra, *c) and not inside(rb, *c)]
    ha, hb = ra["h"], rb["h"]
    n = len(path)
    dh = abs(hb - ha)
    assert n >= max(dh, 1) or bridge, f"{a}->{b}: {n} cells for a {dh} level climb"
    sign = 1 if hb > ha else -1
    hs = []
    for i in range(n):
        if bridge:
            hs.append(min(ha, hb))
        else:
            s = max(0, min(dh, i + 1 - (n - dh) // 2))
            hs.append(ha + sign * s)
    cells = set()
    for i, (x, y) in enumerate(path):
        horizontal = (i + 1 < n and path[i + 1][1] == y) or (i + 1 >= n and i > 0 and path[i - 1][1] == y)
        for o in range(-(width // 2), width // 2 + 1):
            cx, cy = (x, y + o) if horizontal else (x + o, y)
            if not (0 <= cx < W and 0 <= cy < H) or terrain[cy][cx] not in "r.w":
                if terrain[cy][cx] != "r" or not (0 <= cx < W and 0 <= cy < H):
                    continue
            cells.add((cx, cy))
            height[cy][cx] = hs[i]
            terrain[cy][cx] = "s" if bridge else "d"
            if not bridge and i + 1 < n:
                nxt = hs[i + 1]
                if nxt == hs[i] + 1:
                    terrain[cy][cx] = "t"
                elif nxt == hs[i] - 1 and False:
                    pass
            if not bridge and i > 0 and hs[i - 1] == hs[i] + 1:
                terrain[cy][cx] = "t"  # the lower cell of a rise, going down
    if bridge:  # a chasm either side
        for i, (x, y) in enumerate(path):
            horizontal = (i + 1 < n and path[i + 1][1] == y) or (i + 1 >= n and i > 0 and path[i - 1][1] == y)
            for o in (-3, -2, 2, 3):
                cx, cy = (x, y + o) if horizontal else (x + o, y)
                if 0 <= cx < W and 0 <= cy < H and terrain[cy][cx] == "r":
                    terrain[cy][cx] = "w"
                    height[cy][cx] = 0
    if door:
        # the door sits on the last straight cell (the way in runs on both sides of it), so it reads as a doorway
        idx = len(path) // 2
        for i in range(len(path) - 2, 0, -1):
            if path[i - 1][0] - path[i][0] == path[i][0] - path[i + 1][0] and path[i - 1][1] - path[i][1] == path[i][1] - path[i + 1][1]:
                idx = i
                break
        dx, dy = path[idx]
        terrain[dy][dx] = "u"
        door["cell"] = [dx, dy]
    LINKS[name] = cells
    return path


# --- rooms: an S-curve from the south-west courtyard to the throne at the top ---------------------------------------
room("court", 9, 54, 7, 6, 2, "g", 2.2)
room("lookout", 6, 41, 3, 3, 4, "g", 2.4)  # a jut-out north of the courtyard, a dead end with a boost
room("gate", 23, 48, 4, 3, 3, "s")
room("hall", 37, 44, 7, 5, 3, "s")
room("chapel", 55, 52, 4, 5, 3, "s")
room("cellar", 24, 37, 6, 4, 1, "s")
room("gallery", 49, 28, 7, 4, 7, "s")
room("library", 13, 25, 5, 7, 6, "s")
room("junction", 30, 20, 6, 4, 10, "s")
room("wing", 65, 21, 4, 6, 9, "s")
room("throne", 52, 7, 13, 5, 13, "s", 4.0)
room("vault", 40, 57, 3, 2, 3, "s")  # a small locked room south of the hall (sealed door)
room("tower", 5, 7, 3, 3, 16, "s", 2.4)  # a tall jut-out at the top-left, a dead end with a chest
pillars("hall", [(-5, -4), (-5, 4), (0, -4), (0, 4), (5, -4), (5, 4)])
pillars("gallery", [(-5, -3), (-5, 3), (0, -3), (0, 3), (5, -3), (5, 3)])
pillars("junction", [(-4, -3), (-4, 3), (4, -3), (4, 3)])
pillars("library", [(-3, -5), (3, -5), (-3, 5), (3, 5)])
pillars("wing", [(-2, -4), (2, -4), (-2, 4), (2, 4)])
pillars("chapel", [(-2, -3), (2, -3), (-2, 3), (2, 3)])
# pools: the cellar's sink and the junction's basin
for (r, offs) in (("cellar", [(-1, 0), (0, 0), (1, 0), (0, 1), (0, -1)]), ("junction", [(0, 0), (1, 0)])):
    cx, cy = ROOMS[r]["box"][:2]
    for dx, dy in offs:
        terrain[cy + dy][cx + dx] = "w"
        height[cy + dy][cx + dx] = ROOMS[r]["h"] - (1 if r == "cellar" else 0)

gate_thing = {"id": "gate", "kind": "door", "event": "locked_door", "floor": "s"}
# the courtyard's chasm bridge (flat, over a drop), the big door, then the climbs
link("bridge_in", "court", "gate", "x", 1, bridge=True, door=gate_thing)  # the big door ends the bridge
link("door", "gate", "hall", "x", 1)
link("lookout_up", "court", "lookout", "y", 2)
crypt_door_thing = {"id": "crypt_door", "kind": "door", "event": "sealed_door", "floor": "s"}
link("hall_vault", "hall", "vault", "y", 1, door=crypt_door_thing)
link("hall_gallery", "hall", "gallery", "y", 3)
link("hall_chapel", "hall", "chapel", "x", 3)
link("chapel_wing", "chapel", "wing", "x", 3)
link("gate_cellar", "gate", "cellar", "y", 3)
link("cellar_library", "cellar", "library", "x", 2)
link("gallery_junction", "gallery", "junction", "x", 3)
link("junction_throne", "junction", "throne", "y", 3)
link("library_throne", "library", "throne", "y", 1, to_off=(0, -3))
link("wing_throne", "wing", "throne", "y", 1)
link("library_tower", "library", "tower", "x", 1)
link("bridge_wing", "junction", "wing", "y", 1, bridge=True) if False else None
# the long bridge from the junction's east edge to the east wing, over a drop (heights 10 and 9)
ROOMS["junction"]["h"], ROOMS["wing"]["h"] = 10, 9
link("bridge_long", "junction", "wing", "x", 1, bridge=True)
# the bridge starts and ends one level off a room's floor; level it to the lower room
for (x, y) in LINKS["bridge_long"]:
    height[y][x] = 9

# The throne room: big doors in at the west end, a carpet lane down the middle, the throne on a platform two levels up
# with a stair to it (the lich stands on it); the way out is round the platform's south side, so an escape walks by him.
tx, ty = ROOMS["throne"]["box"][:2]
for x in range(41, 58):
    for y in (6, 7, 8):
        terrain[y][x] = "d"
        height[y][x] = 13  # the carpet
for y in (6, 7, 8):
    terrain[y][58], height[y][58] = "t", 13
    terrain[y][59], height[y][59] = "t", 14
for y in range(4, 11):
    for x in range(60, 66):
        terrain[y][x], height[y][x] = "s", 15  # the platform
for x in range(42, 57, 4):
    for y in (4, 10):
        if terrain[y][x] == "s":
            terrain[y][x] = "u"  # pillars flank the lane
for y in (5, 9):
    terrain[y][39] = "u"  # the door posts
for x in range(62, 65):
    for y in (11, 12):
        terrain[y][x], height[y][x] = "s", 13  # the way out, past the platform
terrain[2][66] = terrain[2][66]

# Walls: rock rises 2 above its tallest open neighbour; rock with no ground next to it is void (the outline).
for y in range(H):
    for x in range(W):
        if terrain[y][x] != "r":
            continue
        best = None
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and terrain[ny][nx] not in "r.":
                    best = max(best or 0, height[ny][nx])
        height[y][x] = 0 if best is None else min(24, best + 2)
near = [[False] * W for _ in range(H)]
for y in range(H):
    for x in range(W):
        if terrain[y][x] not in "r.":
            for dy in range(-1, 2):
                for dx in range(-1, 2):
                    if 0 <= x + dx < W and 0 <= y + dy < H:
                        near[y + dy][x + dx] = True
for y in range(H):
    for x in range(W):
        if terrain[y][x] == "r" and not near[y][x]:
            terrain[y][x] = "."
            height[y][x] = 0

zones = [["-"] * W for _ in range(H)]
for y in range(34, H):
    for x in range(0, 22):
        zones[y][x] = "f"
for y in range(26, 62):
    for x in range(0, 14):
        if zones[y][x] == "-" and y > 33:
            zones[y][x] = "f"


def c(name, dx=0, dy=0):
    r = ROOMS[name]["box"]
    return [r[0] + dx, r[1] + dy]


data = {
    "name": "crypt", "art_set": "ruins", "strangeness": 0.0, "level": 1, "view": 0, "walls": True,
    "wall_kit": "dungeon", "outdoors": ["forest"],
    "grid": {"w": W, "h": H, "terrain": ["".join(r) for r in terrain], "heights": ["".join(HD[v] for v in r) for r in height],
             "zones": ["".join(r) for r in zones], "zone_key": {"f": "forest", "d": "dungeon"}},
    "start": [c("court", -2, 2), c("court", -1, 3), c("court", -3, 3)],
    "groups": [
        {"id": "plaza", "event": "spot_people", "sight": 4, "loot": "food:+6;gold:+10",
         "units": [{"id": "bandit", "cell": c("junction", -2, 2)}, {"id": "bandit", "cell": c("junction", 3, -1)},
                   {"id": "bandit_archer", "cell": c("junction", 0, -4)}]},
        {"id": "tower", "event": "spot_people", "sight": 4, "loot": "food:+10",
         "units": [{"id": "bandit_archer", "cell": c("gallery", -4, 1)}, {"id": "bandit", "cell": c("gallery", 3, -1)}]},
        {"id": "cave", "event": "spot_beasts", "sight": 4, "loot": "food:+10",
         "units": [{"id": "wolf", "cell": c("cellar", -3, 1)}, {"id": "wolf", "cell": c("cellar", 3, -2)}]},
        {"id": "east_wing", "event": "spot_people", "sight": 5, "loot": "medicine:+2",
         "units": [{"id": "bandit_archer", "cell": c("wing", 1, -4)}, {"id": "bandit", "cell": c("wing", -1, 2)}]},
        {"id": "throne", "event": "spot_boss", "sight": 4, "loot": "medicine:+3;gold:+20;unlock:beat_lich",
         "boss": True, "end": True, "goals": "defeat|exit",
         "exit": [[x, y] for y in (11, 12) for x in (62, 63, 64)],
         "summon": [[62, 6], [62, 8], [61, 7], [63, 5]],
         "units": [{"id": "lich", "cell": [63, 7]}]},
    ],
    "things": [
        gate_thing,
        crypt_door_thing,
        {"id": "yard_stone", "kind": "shrine", "event": "shrine", "cell": c("court", 2, -3)},
        {"id": "lookout_boost", "kind": "boost", "event": "hp:2", "cell": c("lookout", 0, -1)},
        {"id": "hall_chest", "kind": "chest", "event": "chest", "cell": c("hall", 6, 1)},  # in the open (pm-occlusion hidden-spots check, 2026-11-01)
        {"id": "chapel_chest", "kind": "chest", "event": "chest", "cell": c("chapel", 0, 4)},
        {"id": "wing_key", "kind": "key", "event": "crypt_key", "cell": c("wing", 1, 5)},  # in the open (pm-occlusion hidden-spots check, 2026-11-01)
        {"id": "library_rare", "kind": "rare", "event": "rare:1;metal:2", "cell": c("library", -3, -2)},
        {"id": "way_out", "kind": "exit", "event": "exit", "cell": [63, 12]},
        {"id": "throne_doors", "kind": "door", "event": "locked_door", "cell": [39, 7], "floor": "s"},
        {"id": "crypt_vault", "kind": "chest", "event": "crypt_vault", "cell": c("tower", 0, 0), "once": "got_crypt_vault"},
        {"id": "crypt_chest", "kind": "chest", "event": "chest", "cell": c("vault", 0, 0)},
        {"id": "up_stair", "kind": "enter", "event": "", "cell": c("court", -6, 3), "to": "snow_pass", "at": [9, 8]},
    ],
}
for t in data["things"]:
    assert terrain[t["cell"][1]][t["cell"][0]] not in "r.w" or t["id"] == "gate", t["id"]
# Routes: the throne must be reachable by each of the three climbs alone (the other two shut).
from collections import deque


def reach(start, block):
    seen = {start}
    q = deque([start])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if (0 <= nx < W and 0 <= ny < H and (nx, ny) not in seen and (nx, ny) not in block
                    and terrain[ny][nx] not in "r.w" and abs(height[ny][nx] - height[y][x]) <= 1):
                seen.add((nx, ny))
                q.append((nx, ny))
    return seen


ROUTES = {"middle": ("hall_gallery", "gallery_junction", "junction_throne"),
          "east": ("hall_chapel", "chapel_wing", "wing_throne"),
          "west": ("gate_cellar", "cellar_library", "library_throne")}
start0 = tuple(data["start"][0])
throne_cell = tuple(c("throne", 0, 0))
for keep, links in ROUTES.items():
    block = set()
    for other, ls in ROUTES.items():
        if other != keep:
            for ln in ls[-1:]:  # shut each other route's last climb into the throne room
                block |= LINKS[ln]
    rr = reach(start0, block)
    if throne_cell not in rr:
        print(keep, "fails; library", tuple(c("library",1,0)) in rr, "cellar floor", tuple(c("cellar",0,4)) in rr, "lib exit", tuple(c("library",0,-7)) in rr)
        # the last reached cell nearest the throne
        best = min(rr, key=lambda q: abs(q[0]-throne_cell[0]) + abs(q[1]-throne_cell[1]))
        print("closest", best, height[best[1]][best[0]], terrain[best[1]][best[0]])
        for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
            n=(best[0]+dx,best[1]+dy); print("   ", n, terrain[n[1]][n[0]], height[n[1]][n[0]])
    if throne_cell not in rr and keep == "west":
        pts = [(q, terrain[q[1]][q[0]], height[q[1]][q[0]], q in rr) for q in sorted(LINKS["library_throne"], key=lambda q: (-q[1], q[0]))]
        print("LT", [p for p in pts if not p[3]][:3], [p for p in pts if p[3]][-3:])
        print("ROW40", [(x, terrain[40][x], height[40][x], (x, 40) in rr) for x in range(10, 28)])
        for ln in ("cellar_library", "library_throne"):
            cs = sorted(LINKS[ln])
            print(ln, [(q, terrain[q[1]][q[0]], height[q[1]][q[0]], q in rr) for q in cs if q[0] in (11, 12) or q[1] in (8, 27)][:40])
    assert throne_cell in rr, f"the {keep} route does not reach the throne alone"
assert throne_cell in reach(start0, set()), "the throne is unreachable"
print("routes ok: middle, east and west each reach the throne alone")

out = os.path.join(os.path.dirname(__file__), "..", "..", "game", "data", "explore", "crypt.json")
with open(out, "w") as f:
    json.dump(data, f, indent=1)
    f.write("\n")
print("wrote", os.path.normpath(out), W, "x", H)
