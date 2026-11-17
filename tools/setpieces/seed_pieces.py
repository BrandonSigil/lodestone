"""Writes the road set-piece sketches (docs/systems/set-pieces.md) to tools/setpieces/src/<id>.json.
Then bake them into battle maps:  cd game && godot --headless --path . -s res://tools/setpiece_build.gd -- [ids] [--force]

A piece is two grids of the same size. L: "." outside the map, "0"-"9" the terrace (two heights each). M: what is
there. Plot marks (MapPlot): d road, w water, b bridge, s stairs, r rock outcrop, t woods. Then, one per cell:
  P party start (walked in)   p party start (saw them first)   X exit cell   o stepping stone   k dock plank
  # filler under a big prop (ignored)
and whatever the piece's own `props` and `foes` tables name. A big prop is marked at its low-x, low-y corner.
The party side is drawn so the camera (which looks from high x + y towards low) sees the landmark behind open ground.
"""
import json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))

# sprite, foot, tall, sight (catalog.csv numbers); "blob": a named placeholder until Brandon's art lands
PROPS = {
    "h": dict(sprite="village/prop_hay", tall=0.65, sight=0.5),
    "f": dict(sprite="village/prop_fence", tall=0.6, sight=0.0),
    "x": dict(sprite="village/prop_crates", tall=0.8, sight=0.0),
    "c": dict(sprite="village/prop_barrel", tall=0.7, sight=0.0),
    "B": dict(sprite="prop_boulder", tall=0.6, sight=1.0),
    "y": dict(sprite="prop_bush", tall=0.55, sight=0.5),
    "T": dict(sprite="village/prop_tree", tall=1.6, sight=1.0),
    "e": dict(sprite="village/prop_reeds", tall=0.6, sight=0.5),
}
PLOT = set("dwbsrt ")  # "S" is a stair cell laid on its own, so a run of them side by side is one wide stair

PIECES = {}


def marks(L, spec):
    """The M grid from placements, for maps too fiddly to type as rows: "f:7-11,6 f:7,7-9 P:19,9" puts each mark on a
    cell, a row run (x0-x1,y) or a column run (x,y0-y1). Later placements win."""
    g = [[" "] * len(L[0]) for _ in L]
    for tok in spec.split():
        ch, at = tok.split(":")
        xs, ys = at.split(",")
        x0, x1 = xs.split("-") if "-" in xs else (xs, xs)
        y0, y1 = ys.split("-") if "-" in ys else (ys, ys)
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                g[y][x] = ch
    return ["".join(r) for r in g]

def levels(w, h, spec):
    """The L grid from rectangles, later ones on top: "3:4-17,1-3 .:4,1" (level or "." for outside, x run, y run)."""
    g = [["."] * w for _ in range(h)]
    for tok in spec.split():
        ch, at = tok.split(":")
        xs, ys = at.split(",")
        x0, x1 = xs.split("-") if "-" in xs else (xs, xs)
        y0, y1 = ys.split("-") if "-" in ys else (ys, ys)
        for y in range(int(y0), int(y1) + 1):
            for x in range(int(x0), int(x1) + 1):
                g[y][x] = ch
    return ["".join(r) for r in g]


def marks_at(L, spec):
    """The cells a marks() spec covers (the mark letters are ignored)."""
    g = marks(L, spec) if spec else []
    return {(x, y) for y, r in enumerate(g) for x, ch in enumerate(r) if ch != " "}


# ---- W1 Tipped wagon. The west road runs along a wooded hillside: the bank above it (back), the road, and below it
# (front left) the hollow where the thieves camp. The wagon lies across the road; what spilled out of it lies on the
# thieves' side (screen left, low x), with gaps above and below the wagon to squeeze past. Their lookout stands on
# the bank edge one level above the road, so the wagon and its load still shield against him. The party comes along
# the road from the right; the woodcutters' trail (stumps) lets it climb the bank and come along the top.
_L = levels(24, 14,
    "1:0-23,6-8 1:2-21,9 1:13-20,10 1:15-19,11 1:10-13,5 "                   # the road, its verge, the meadow on the right
    "2:2-9,1-5 2:10-13,1-4 2:14-19,2-5 2:2-3,6 2:4-8,0 .:2,1 .:19,2 "  # the bank above the road, its edge in and out
    "0:1-8,10-12 0:2-6,13 .:1,12 .:8,12")                          # the camp hollow below the road
PIECES["wagon"] = dict(
    look="forest", art_set="forest",
    note="W1 Tipped wagon: a hillside road. The wagon lies across it with a gap above and below to get past. "
         "The thieves' side is the left: the spilled load, their camp in the hollow below the road, their lookout on "
         "the bank edge. The party comes from the right; the woodcutters' trail climbs the bank to come at the lookout.",
    L=_L,
    road="d:0-23,7-8",
    M=marks(_L, "d:0-23,7-8 "
                "K:10,7 #:11,7 #:10-11,8 c:8,7 x:7,8 x:9,9 B:7,6 "               # the wagon and its spilled load
                "s:5,5 s:16,5 s:6,10 "                                          # thieves' trail, woodcutters' trail, way down to camp
                "t:3-4,2-3 t:8-9,1-2 t:11-12,2 t:5,1 T:13,3 T:4,4 "             # woods on the thieves' bank
                "u:15,4 u:18,3 u:17,5 T:19,4 T:15,2 "                           # cut stumps on the woodcutters' side
                "u:3,10 u:5,12 u:4,10 x:2,11 x:3,12 c:2,12 y:7,11 "              # camp: seats round the fire pit, the loot they hauled off
                "B:17,10 B:16,11 y:14,9 "                                       # a rockfall below the road on the party's side
                "A:9,8 A:8,9 A:6,11 R:10,4 "
                "P:12,6 P:12,9 P:13,7 P:13,8 p:21,7 p:21,8 p:22,7 p:22,8"),
    props={"K": dict(sprite="village/prop_cart", foot=[2, 2], tall=1.3, sight=1.0),
           "u": dict(sprite="village/prop_stump", tall=0.5, sight=0.0)},
    foes={"A": dict(id="ambusher", hidden=True), "R": dict(id="bandit_archer")},
)

# ---- E2 Loose bulls. A small farm beside the east road, all on the flat. The barn at the back with clear ground in
# front of its door, the lane from the door down to the road. Left of the lane: the corral, its gate open on the lane
# and its road-side fence broken out, a water barrel inside. Right of the lane: the well in the yard, then a mown hay
# field with bales left in rows. The bulls are loose on the left; the party comes along the road from the right.
_L = levels(24, 15,
    "0:7-15,0-4 .:7,0 .:15,0 "                             # the barn yard
    "0:3-20,5-8 0:1-21,9-11 0:0-23,12-13 "                # yard, corral, field, road
    "0:4-19,14 .:3,5 .:20,5 .:1,9 .:1,11")                 # verge
PIECES["bulls"] = dict(
    look="farmland", art_set="farmland",
    note="E2 Loose bulls: a farm by the road, on the flat. Barn at the back with its door clear, the lane down to "
         "the road. Corral with its gate open and its road-side fence broken on the left, where the bulls are; well "
         "and a mown hay field in rows on the right, where the party comes from. Fences, bales and the well break a "
         "charge; the barn door is the way out.",
    L=_L,
    road="d:10-11,5-11 d:0-23,12-13",
    M=marks(_L, "H:9,1 #:10-12,1 #:9-12,2-3 X:9-12,4 "
                "h:8,2 h:8,3 K:13,2 #:14,2 #:13-14,3 T:8,0 T:14,0 "             # hay stacked by the barn wall, the farm cart
                "f:4-8,6 f:4,10 f:7-8,10 F:4,7-9 F:8,7 F:8,9 c:5,8 h:3,7 "      # corral: gate (8,8) open, (5-6,10) broken
                "W:13,6 #:14,6 #:13-14,7 "                                      # well
                "h:14,9 h:17,9 h:20,9 h:13,11 h:16,11 h:19,11 "                 # bales in rows in the mown field
                "T:20,6 T:3,9 T:21,10 "
                "U:5,11 U:6,9 U:2,12 "
                "P:15,8 P:16,10 P:18,10 P:17,8 p:20,10 p:21,11 p:21,12 p:22,12"),
    props={"H": dict(sprite="village/b_home_b", foot=[4, 3], tall=0.0, sight=3.0),
           "W": dict(sprite="village/prop_well", foot=[2, 2], tall=1.8, sight=1.0),
           "K": dict(sprite="village/prop_cart", foot=[2, 2], tall=1.3, sight=1.0),
           "F": dict(sprite="village/prop_fence", tall=0.6, sight=0.0, flip=True)},
    foes={"U": dict(id="foe_bull")},
)

# ---- W2 Stepping-stone falls. A forest river drops off a rock shelf at the back of the map. An old footbridge
# crosses it on top, right at the lip of the falls; below, where the river spreads out shallow, travellers ford it
# on four stepping stones. The road comes from the right, fords, and goes on left. A trail climbs each bank in two
# steps (valley, shelf, top) to the bridge: the long, dry way round. The bandits hold the far (left) bank: one at
# the stones' end, archers on the left shelf over the ford and on the top by the bridge. Anyone pushed into the river
# is swept downstream and washes up on a bank (CombatRules.sweep).
_L = levels(24, 18,
    "2:4-18,0-4 .:4,0 .:18,0 .:18,4 2:5-7,5 1:8-9,5 "                     # the top, the river's shelf
    "1:3-9,6-9 .:3,6 1:2,7 1:12-18,5-8 .:18,8 "                   # left bank shelf, right bank knoll, both to the gorge
    "0:1-9,10-17 .:1,10 .:1-3,15-17 .:4-7,17 "                    # left valley floor
    "0:12-22,9-15 .:22,9-10 .:19-22,14-15 .:21-22,13 0:12-14,16-17 .:14,17 "  # right valley floor
    "2:10-11,0-4 0:10-11,5-17 "                                   # the river: on top, the falls, below
    ".:16-18,0 .:15-18,1 .:17-18,2-3 .:16-18,4 .:1-2,13-14 .:17-18,14 .:15,16 .:13-15,0 .:1,11-12 .:19-20,13 .:19-21,9 .:20-21,10 .:2,10 .:2-3,7 .:18,5-7 .:16-18,13 .:4,15-16")  # the forest closing in
PIECES["falls"] = dict(
    look="forest", art_set="forest",
    note="W2 Stepping-stone falls: a river falls off a rock shelf. An old track crosses it on a footbridge at the top "
         "of the falls; below, the road fords it on a zig-zag of stepping stones. A trail climbs each side of the gorge, "
         "valley to shelf to top: the dry way round, close to the edge. Bandits hold the left bank: one by the stones, "
         "an archer on the shelf over the ford and one by the bridge.",
    L=_L,
    road="d:13-23,12 d:1-8,12 d:4-9,2 d:12-18,2",
    M=marks(_L, "w:10-11,0-1 w:10-11,3-17 w:9,11-13 w:12,10-12 b:10-11,2 "                  # river, ford pool, bridge
                "o:9,12 o:10,12 o:10,11 o:11,11 o:12,11 "                                  # the stones
                "s:13,9 s:13,5 s:8,10 s:8,5 d:13,6-8 d:13,3-4 d:8,6-9 d:8,3-4 d:9,4 d:12,4 "    # the two gorge trails
                "t:4-5,1-2 t:12,0 t:7,0 T:16,3 T:4,7 T:17,6 T:4,14 T:21,12 "
                "B:6,7 B:15,10 B:7,13 B:16,6 y:14,13 y:3,10 e:8,11 e:9,14 e:12,14 "
                "R:7,8 R:8,3 N:3,11 A:7,14 "
                "P:13,10 P:13,11 P:13,12 P:14,11 p:20,11 p:21,12 p:20,12 p:21,11"),
    foes={"R": dict(id="bandit_archer"), "N": dict(id="bandit"), "A": dict(id="ambusher", hidden=True)},
)

def sketch(pid):
    p = PIECES[pid]
    L, M = p["L"], p["M"]
    w = len(L[0])
    assert len(L) == len(M), pid
    for r in L + M:
        assert len(r) == w, (pid, r, len(r), w)
    props_def = dict(PROPS)
    props_def.update(p.get("props", {}))
    foes_def = p.get("foes", {})
    out = dict(id=pid, look=p["look"], art_set=p["art_set"], note=p["note"], levels=L, marks=[],
               props=[], party=[], out=[], foes=[], exit=[], stones=[], docks=[], stairs=[])
    road = marks_at(L, p.get("road", ""))  # road that runs on under things and pieces standing on it
    for y, row in enumerate(M):
        marks = ""
        for x, ch in enumerate(row):
            marks += "d" if (x, y) in road and ch not in "wbsrtSoke" else (ch if ch in PLOT else " ")
            if ch in PLOT or ch == "#":
                continue
            assert L[y][x] != ".", (pid, "thing outside the map", ch, x, y)
            if ch == "P":
                out["party"].append([x, y])
            elif ch == "p":
                out["out"].append([x, y])
            elif ch == "X":
                out["exit"].append([x, y])
            elif ch == "S":
                out["stairs"].append([x, y])
            elif ch == "o":
                out["stones"].append([x, y])
            elif ch == "k":
                out["docks"].append([x, y])
            elif ch in foes_def:
                out["foes"].append(dict(foes_def[ch], cell=[x, y]))
            elif ch in props_def:
                out["props"].append(dict(props_def[ch], cell=[x, y]))
            else:
                raise SystemExit("%s: unknown mark %r at %d,%d" % (pid, ch, x, y))
        out["marks"].append(marks)
    return out


def shape(pid):
    """The box bar of tools/map_shape.py --fight, on the sketch (the baked map is checked again)."""
    p = PIECES[pid]
    L, M = p["L"], p["M"]
    H, W = len(L), len(L[0])
    walk = [[L[y][x] != "." and M[y][x] not in "wr" for x in range(W)] for y in range(H)]
    cells = [(x, y) for y in range(H) for x in range(W) if walk[y][x]]
    xs = [c[0] for c in cells]; ys = [c[1] for c in cells]
    bw, bh, x0, y0 = max(xs) - min(xs) + 1, max(ys) - min(ys) + 1, min(xs), min(ys)
    ok = lambda x, y: 0 <= x < W and 0 <= y < H and walk[y][x]
    edge = sum(1 for x, y in cells if not all(ok(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))))
    corners = sum(1 for y in range(-1, H) for x in range(-1, W)
                  if sum(ok(x + dx, y + dy) for dx in (0, 1) for dy in (0, 1)) in (1, 3))
    qw, qh = max(1, bw // 4), max(1, bh // 4)
    bays = sum(1.0 - sum(ok(x, y) for y in range(cy, cy + qh) for x in range(cx, cx + qw)) / (qw * qh)
               for cx, cy in ((x0, y0), (x0 + bw - qw, y0), (x0, y0 + bh - qh), (x0 + bw - qw, y0 + bh - qh))) / 4
    fill, er, c100 = len(cells) / (bw * bh), edge / (2.0 * (bw + bh)), 100.0 * corners / len(cells)
    bad = [n for n, v in (("fill", fill <= 0.62), ("edge", er >= 1.3), ("corners", c100 >= 14), ("bays", bays >= 0.3)) if not v]
    return "%-8s %dx%d cells %d  fill %.2f  edge %.2f  corners %.1f  bays %.2f  %s" % (
        pid, W, H, len(cells), fill, er, c100, bays, "BOX: " + ", ".join(bad) if bad else "ok")


if __name__ == "__main__":
    os.makedirs(os.path.join(HERE, "src"), exist_ok=True)
    for pid in (sys.argv[1:] or sorted(PIECES)):
        with open(os.path.join(HERE, "src", pid + ".json"), "w") as f:
            json.dump(sketch(pid), f, indent=1)
            f.write("\n")
        print("wrote", shape(pid))
