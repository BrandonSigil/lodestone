#!/usr/bin/env python3
"""Unfolds village_v2 into a winding town ([USER] 2026-10-30, card design-village-shape-choice: "Redesign").

The built town is cut along a few lines through open ground, the pieces are moved apart, and the new gaps are bridged
where roads (or open ground) ran across them, so the districts become terraced islands joined by long bridges: the
outline winds, and the map's bounding box is mostly air. Every coordinate moves with its piece (props, things, foes,
the start, decks, companions' spots). Then each home gets a 2 x 2 landing outside its door ([USER]: "make sure each home
has a landing outside it so that NPCs can be outside it").

    python3 tools/explore/unfold_village_v2.py [in.json [out.json]]
Run by build_village_v2.py at its end; the cuts are chosen from the content (roads, stairs, houses, water avoided).
"""
import json
import os
import sys

HD = "0123456789abcdefghijklmnopqrstuvwxyz"
DECOR = ("tree", "pine", "bush", "boulder", "hay", "reeds", "fence", "crops", "bench", "planter", "barrel", "crates", "lamp",
         "rack", "grindstone", "headstone", "grave", "stall", "well")
WALK = "gdts"  # the game's walkable cells (forest and water are WALK_OUT); props block them


def load(path):
    return json.load(open(path))


def solid_cells(d):
    g = d["grid"]
    out = set()
    for p in g["props"]:
        if any(k in p["sprite"] for k in DECOR):
            continue
        for dx in range(p["foot"][0]):
            for dy in range(p["foot"][1]):
                out.add((p["cell"][0] + dx, p["cell"][1] + dy))
    for t in d["things"]:
        out.add((int(t["cell"][0]), int(t["cell"][1])))
    for k in g.get("decks", []):
        out.add((k["x"], k["y"]))
    return out


def cut_cost(d, axis, pos, solid):
    g = d["grid"]
    W, H = g["w"], g["h"]
    ter = g["terrain"]
    cost = 0
    rng = range(H) if axis == "x" else range(W)
    for i in rng:
        a = (pos - 1, i) if axis == "x" else (i, pos - 1)
        b = (pos, i) if axis == "x" else (i, pos)
        ta, tb = ter[a[1]][a[0]], ter[b[1]][b[0]]
        if ta == "." or tb == ".":
            continue
        if ta in "tsw" or tb in "tsw" or a in solid or b in solid:
            cost += 50
        elif ta == "d" or tb == "d":
            cost += 1
    return cost


def choose_cuts(d, nx, ny, spacing=12, margin=7):
    g = d["grid"]
    solid = solid_cells(d)
    out = []
    for axis, n, size in (("x", nx, g["w"]), ("y", ny, g["h"])):
        scored = sorted((cut_cost(d, axis, p, solid), p) for p in range(margin, size - margin))
        picked = []
        for c, p in scored:
            if all(abs(p - q) >= spacing for q in picked):
                picked.append(p)
            if len(picked) == n:
                break
        out.append(sorted(picked))
    return out


def unfold(d, cuts_x, cuts_y, gap=11):
    g = d["grid"]
    W, H = g["w"], g["h"]
    NW, NH = W + gap * len(cuts_x), H + gap * len(cuts_y)
    mx = lambda x: x + gap * sum(1 for c in cuts_x if x >= c)
    my = lambda y: y + gap * sum(1 for c in cuts_y if y >= c)
    ter = [["."] * NW for _ in range(NH)]
    hts = [[0] * NW for _ in range(NH)]
    for y in range(H):
        for x in range(W):
            ter[my(y)][mx(x)] = g["terrain"][y][x]
            hts[my(y)][mx(x)] = HD.index(g["heights"][y][x])
    decks = {(mx(k["x"]), my(k["y"])): (k["h"], k["t"], k.get("b", False)) for k in g.get("decks", [])}
    for p in g["props"]:
        p["cell"] = [mx(p["cell"][0]), my(p["cell"][1])]
    blocked = {(p["cell"][0] + dx, p["cell"][1] + dy) for p in g["props"] if not p.get("walk")
               for dx in range(p["foot"][0]) for dy in range(p["foot"][1])}
    for t in d["things"]:
        t["cell"] = [mx(int(t["cell"][0])), my(int(t["cell"][1]))]
    for gr in d["groups"]:
        for u in gr["units"]:
            u["cell"] = [mx(int(u["cell"][0])), my(int(u["cell"][1]))]
    d["start"] = [[mx(int(s[0])), my(int(s[1]))] for s in d["start"]]
    for s in d.get("companion_spots", []):
        s["cell"] = [mx(int(s["cell"][0])), my(int(s["cell"][1]))]
    # candidate crossings: old neighbour pairs across each cut, walkable both sides, within a level
    cross = []  # (axis, a, b, gap cells)
    for cx in cuts_x:
        for y in range(H):
            if g["terrain"][y][cx - 1] in "gdts" and g["terrain"][y][cx] in "gdts" and abs(HD.index(g["heights"][y][cx - 1]) - HD.index(g["heights"][y][cx])) <= 1 \
                    and g["terrain"][y][cx - 1] != "t" and g["terrain"][y][cx] != "t":
                a, b = (mx(cx - 1), my(y)), (mx(cx), my(y))
                cross.append(("x", a, b, [(a[0] + 1 + i, a[1]) for i in range(gap)], g["terrain"][y][cx - 1] == "d" or g["terrain"][y][cx] == "d"))
    for cy in cuts_y:
        for x in range(W):
            if g["terrain"][cy - 1][x] in "gdts" and g["terrain"][cy][x] in "gdts" and abs(HD.index(g["heights"][cy - 1][x]) - HD.index(g["heights"][cy][x])) <= 1 \
                    and g["terrain"][cy - 1][x] != "t" and g["terrain"][cy][x] != "t":
                a, b = (mx(x), my(cy - 1)), (mx(x), my(cy))
                cross.append(("y", a, b, [(a[0], a[1] + 1 + i) for i in range(gap)], g["terrain"][cy - 1][x] == "d" or g["terrain"][cy][x] == "d"))
    cross = [c for c in cross if c[1] not in blocked and c[2] not in blocked]  # a landing needs open ground
    return {"w": NW, "h": NH, "ter": ter, "hts": hts, "decks": decks, "cross": cross, "gap": gap, "blocked": blocked}


def bridge(state, c):
    """Lay the bridge for one crossing: gap cells at the near landing's height, the far half at the far one's."""
    axis, a, b, cells, _ = c
    ha, hb = state["hts"][a[1]][a[0]], state["hts"][b[1]][b[0]]
    n = len(cells)
    for i, (x, y) in enumerate(cells):
        state["decks"][(x, y)] = (ha if i < n // 2 else hb, "s", True)


def components(state, start):
    """Reachable places from start, walking as the game does: a cell's ground and its deck are separate places; a ground
    under a deck too low over it is not walkable; a stair adds two to the step. Returns the ground cells reached
    (decks are reached too, kept in state['deck_seen'])."""
    W, H, ter, hts, decks = state["w"], state["h"], state["ter"], state["hts"], state["decks"]
    def places(c):
        x, y = c
        out = []
        if not (0 <= x < W and 0 <= y < H):
            return out
        if ter[y][x] in WALK and c not in state["blocked"] and (c not in decks or decks[c][0] - hts[y][x] >= 2):
            out.append((c, 0))
        if c in decks:
            out.append((c, 1))
        return out
    def lvl(q):
        return decks[q[0]][0] if q[1] else hts[q[0][1]][q[0][0]]
    def stair(q):
        return not q[1] and ter[q[0][1]][q[0][0]] == "t"
    seen = set()
    todo = []
    for q in places(start):
        seen.add(q)
        todo.append(q)
    while todo:
        q = todo.pop()
        x, y = q[0]
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            for r in places(n):
                if r in seen:
                    continue
                if abs(lvl(q) - lvl(r)) <= 1 + (2 if stair(q) or stair(r) else 0):
                    seen.add(r)
                    todo.append(r)
    state["deck_seen"] = {q[0] for q in seen if q[1]}
    return {q[0] for q in seen if not q[1]} | state["deck_seen"]


def runs_of(cross):
    """Group crossings into runs: consecutive cells along one cut."""
    out = []
    for axis in ("x", "y"):
        by_cut = {}
        for c in cross:
            if c[0] != axis:
                continue
            key = c[1][0] if axis == "x" else c[1][1]
            by_cut.setdefault(key, []).append(c)
        for key, cs in by_cut.items():
            cs.sort(key=lambda c: c[1][1] if axis == "x" else c[1][0])
            run = [cs[0]]
            for c in cs[1:]:
                prev = run[-1]
                step = (c[1][1] - prev[1][1]) if axis == "x" else (c[1][0] - prev[1][0])
                if step == 1:
                    run.append(c)
                else:
                    out.append(run)
                    run = [c]
            out.append(run)
    return out


def pick(run, width=3):
    """The cells of a run a bridge uses: up to `width`, centred, preferring road cells."""
    if len(run) <= width:
        return run
    roads = [i for i, c in enumerate(run) if c[4]]
    mid = roads[len(roads) // 2] if roads else len(run) // 2
    lo = max(0, min(len(run) - width, mid - width // 2))
    return run[lo:lo + width]


def reached(state, got, t):
    """A thing is reached when its cell is, or (a fishing spot on the water) a ground cell beside it is."""
    c = tuple(t["cell"])
    if t["kind"] == "fish" or c in state["blocked"]:  # used from beside it
        return any((c[0] + dx, c[1] + dy) in got for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
    return c in got


def lay_bridges(state, start, things, limit=60):
    runs = runs_of(state["cross"])
    chosen = []
    # roads first: every run with a road crossing gets a bridge, then whatever is needed to reach every thing
    for r in sorted(runs, key=lambda r: -sum(1 for c in r if c[4])):
        if any(c[4] for c in r):
            chosen.append(r)
    for r in chosen:
        for c in pick(r):
            bridge(state, c)
    for _ in range(limit):
        got = components(state, start)
        if all(reached(state, got, t) for t in things):
            break
        best = None
        for r in runs:
            if r in chosen:
                continue
            for c in pick(r):
                if (c[1] in got) != (c[2] in got):
                    best = r
                    break
            if best:
                break
        if best is None:
            break
        chosen.append(best)
        for c in pick(best):
            bridge(state, c)
    return chosen


def landings(state, d):
    """A 2 x 2 landing of open ground outside every home's door, flat, clear and reachable ([USER]: NPCs stand there)."""
    ter, hts, W, H = state["ter"], state["hts"], state["w"], state["h"]
    blocked = set()
    for p in d["grid"]["props"]:
        if any(k in p["sprite"] for k in DECOR):
            continue
        for dx in range(p["foot"][0]):
            for dy in range(p["foot"][1]):
                blocked.add((p["cell"][0] + dx, p["cell"][1] + dy))
    decor = {}
    for p in d["grid"]["props"]:
        if any(k in p["sprite"] for k in DECOR):
            decor[tuple(p["cell"])] = p
    n = 0
    for t in d["things"]:
        if not (t["kind"] == "enter" and t["id"].startswith("door_")):
            continue
        door = tuple(t["cell"])
        h = hts[door[1]][door[0]]
        done = False
        for ox, oy in ((0, 0), (-1, 0), (0, -1), (-1, -1)):
            cells = [(door[0] + ox + i, door[1] + oy + j) for i in range(2) for j in range(2)]
            if door not in cells:
                continue
            if all(0 <= c[0] < W and 0 <= c[1] < H and c not in blocked and ter[c[1]][c[0]] in "gdfs" and hts[c[1]][c[0]] == h for c in cells):
                for c in cells:
                    if ter[c[1]][c[0]] in "gf":
                        ter[c[1]][c[0]] = "d" if c != door else ter[c[1]][c[0]]
                    (decor.pop(c, None), state.setdefault("cleared", set()).add(c))
                done = True
                break
        if not done:  # cut one: level the cells beside the door to its height, clear the little props off them
            for ox, oy in ((0, 0), (-1, 0), (0, -1), (-1, -1)):
                cells = [(door[0] + ox + i, door[1] + oy + j) for i in range(2) for j in range(2)]
                if door in cells and all(0 <= c[0] < W and 0 <= c[1] < H and c not in blocked and ter[c[1]][c[0]] in "gdfs" and abs(hts[c[1]][c[0]] - h) <= 2 for c in cells):
                    for c in cells:
                        hts[c[1]][c[0]] = h
                        if ter[c[1]][c[0]] in "gf":
                            ter[c[1]][c[0]] = "d"
                        (decor.pop(c, None), state.setdefault("cleared", set()).add(c))
                    done = True
                    break
        if not done:  # a door set inside its building's yard: the nearest open 2 x 2 within three cells, level with it
            best = None
            for ox in range(-4, 4):
                for oy in range(-4, 4):
                    cells = [(door[0] + ox + i, door[1] + oy + j) for i in range(2) for j in range(2)]
                    if all(0 <= c[0] < W and 0 <= c[1] < H and c not in blocked and ter[c[1]][c[0]] in "gdfs" and abs(hts[c[1]][c[0]] - h) <= 1 for c in cells):
                        dist = min(abs(c[0] - door[0]) + abs(c[1] - door[1]) for c in cells)
                        if best is None or dist < best[0]:
                            best = (dist, cells)
            if best is not None:
                for c in best[1]:
                    if ter[c[1]][c[0]] in "gf":
                        ter[c[1]][c[0]] = "d"
                    (decor.pop(c, None), state.setdefault("cleared", set()).add(c))
                done = True
        if not done:  # last resort: build a small platform beside the door, at its height, over water or empty ground
            best = None
            for ox in range(-3, 3):
                for oy in range(-3, 3):
                    cells = [(door[0] + ox + i, door[1] + oy + j) for i in range(2) for j in range(2)]
                    if all(0 <= c[0] < W and 0 <= c[1] < H and c not in blocked for c in cells):
                        dist = min(abs(c[0] - door[0]) + abs(c[1] - door[1]) for c in cells)
                        poor = sum(1 for c in cells if ter[c[1]][c[0]] in "w.")
                        if best is None or (dist, poor) < best[0]:
                            best = ((dist, poor), cells)
            if best is not None:
                for c in best[1]:
                    ter[c[1]][c[0]] = "d"
                    hts[c[1]][c[0]] = h
                    (decor.pop(c, None), state.setdefault("cleared", set()).add(c))
                done = True
        assert done, "no room for a landing outside %s at %s" % (t["id"], door)
        n += 1
    d["grid"]["props"] = [p for p in d["grid"]["props"] if not (any(k in p["sprite"] for k in DECOR) and p["foot"] == [1, 1] and tuple(p["cell"]) in state.get("cleared", set()))]
    return n


def _on_landing(p, state, d):
    return tuple(p["cell"]) in state.get("cleared", set())


def inlets(state, d, start, count=170, seed=3):
    """Bites out of the rims of the islands (2 x 3 or 3 x 2 of open grass or woods) so the outline winds in as well as out.
    Never near a thing, foe, road, stair, stone, deck or building, and never cutting the walk."""
    import random
    ter, hts, W, H = state["ter"], state["hts"], state["w"], state["h"]
    keep = set()
    for t in d["things"]:
        keep.add((t["cell"][0], t["cell"][1]))
    for gr in d["groups"]:
        for u in gr["units"]:
            keep.add((u["cell"][0], u["cell"][1]))
    solid = set()
    for p in d["grid"]["props"]:
        if any(k in p["sprite"] for k in DECOR):
            continue
        for dx in range(p["foot"][0]):
            for dy in range(p["foot"][1]):
                solid.add((p["cell"][0] + dx, p["cell"][1] + dy))
    rng = random.Random(seed)
    rim = [(x, y) for y in range(H) for x in range(W) if ter[y][x] in "gf"
           and any(0 <= x + dx < W and 0 <= y + dy < H and ter[y + dy][x + dx] == "." for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
           and all(abs(x - k[0]) + abs(y - k[1]) > 3 for k in keep)]
    rng.shuffle(rim)
    done = 0
    for c in rim:
        if done >= count:
            break
        for sx, sy in ((1, 1), (1, -1), (-1, 1), (-1, -1)):
            kind = rng.random()
            if kind < 0.5:  # a nibble: one or two cells, to rough the edge
                cells = [c] + ([(c[0] + sx, c[1])] if rng.random() < 0.5 else [(c[0], c[1] + sy)])
            else:
                wide = kind < 0.75
                cells = [(c[0] + i * sx, c[1] + j * sy) for i in range(3 if wide else 2) for j in range(2 if wide else 3)]
            if not all(0 <= q[0] < W and 0 <= q[1] < H and ter[q[1]][q[0]] in "gf" and q not in solid and q not in state["decks"] for q in cells):
                continue
            ring = [(q[0] + dx, q[1] + dy) for q in cells for dx in (-1, 0, 1) for dy in (-1, 0, 1)]
            if any(0 <= r[0] < W and 0 <= r[1] < H and (ter[r[1]][r[0]] in "ts" or r in solid or r in state["decks"] or r in keep) for r in ring):
                continue
            before = len(components(state, start))
            saved = [(q, ter[q[1]][q[0]], hts[q[1]][q[0]]) for q in cells]
            for q in cells:
                ter[q[1]][q[0]] = "."
                hts[q[1]][q[0]] = 0
            if len(components(state, start)) < before - len(cells):
                for q, t0, h0 in saved:
                    ter[q[1]][q[0]] = t0
                    hts[q[1]][q[0]] = h0
                continue
            done += 1
            break
    return done


def export(state, d):
    g = d["grid"]
    g["w"], g["h"] = state["w"], state["h"]
    g["terrain"] = ["".join(r) for r in state["ter"]]
    g["heights"] = ["".join(HD[v] for v in r) for r in state["hts"]]
    g["decks"] = [{"x": x, "y": y, "h": h, "t": t, **({"b": True} if b else {})} for (x, y), (h, t, b) in sorted(state["decks"].items())]
    return d


def clear_lost(path, name="village_v2", rounds=6):
    """Void every cell the game's own walking can't reach (godot tools/lost_cells.gd): strays the unfolding left."""
    import shutil
    import subprocess
    godot = os.environ.get("GODOT") or shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot"
    root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
    guard = os.path.join(root, "tools", "mem_guard.sh")
    for _ in range(rounds):
        out = subprocess.run([guard, godot, "--headless", "--path", os.path.join(root, "game"), "-s", "res://tools/lost_cells.gd", "--", name],
                             capture_output=True, text=True).stdout
        lost = [tuple(int(v) for v in line.split()[1:]) for line in out.splitlines() if line.startswith("LOST ")]
        if not lost:
            return True
        d = load(path)
        g = d["grid"]
        ter = [list(r) for r in g["terrain"]]
        hts = [list(r) for r in g["heights"]]
        for x, y, deck in lost:
            if deck:
                g["decks"] = [k for k in g["decks"] if not (k["x"] == x and k["y"] == y)]
            else:
                ter[y][x] = "."
                hts[y][x] = "0"
        g["terrain"] = ["".join(r) for r in ter]
        g["heights"] = ["".join(r) for r in hts]
        with open(path, "w") as f:
            json.dump(d, f, indent=1)
            f.write("\n")
        print("cleared", len(lost), "stray cells")
    return False


def main(src, dst):
    d = load(src)
    for nx, ny in ((3, 3), (3, 2), (2, 3), (2, 2)):
        cx, cy = choose_cuts(d, nx, ny)
        dd = json.loads(json.dumps(d))
        st = unfold(dd, cx, cy)
        start = tuple(dd["start"][0])
        things = dd["things"]
        lay_bridges(st, start, things)
        got = components(st, start)
        miss = [t["id"] for t in things if not reached(st, got, t)]
        print("cuts", cx, cy, "box", st["w"], "x", st["h"], "unreached things:", len(miss))
        if miss:
            continue
        keep_cells = {tuple(t["cell"]) for t in dd["things"]}
        # walkable ground the bridges did not reach goes to void (nobody could stand there), but never what lies under a
        # prop or a thing
        for y in range(st["h"]):
            for x in range(st["w"]):
                if st["ter"][y][x] in WALK and (x, y) not in got and (x, y) not in st["blocked"] and (x, y) not in keep_cells:  # nobody could stand there
                    st["ter"][y][x] = "."
                    st["hts"][y][x] = 0
        dd["grid"]["props"] = [p for p in dd["grid"]["props"] if st["ter"][p["cell"][1]][p["cell"][0]] != "."]
        n_in = inlets(st, dd, start) + inlets(st, dd, start, seed=4)
        print("inlets:", n_in)
        dd["grid"]["props"] = [p for p in dd["grid"]["props"] if st["ter"][p["cell"][1]][p["cell"][0]] != "."]
        landings(st, dd)
        export(st, dd)
        with open(dst, "w") as f:
            json.dump(dd, f, indent=1)
            f.write("\n")
        print("wrote", dst)
        return clear_lost(dst) if os.path.basename(dst) == "village_v2.json" else True
    return False


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else "game/data/explore/village_v2.json"
    sys.exit(0 if main(src, sys.argv[2] if len(sys.argv) > 2 else src) else 1)
