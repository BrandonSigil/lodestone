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
PLOT = set("dwbsrt ")

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

PIECES["wagon"] = dict(
    look="forest", art_set="forest",
    note="W1 Tipped wagon: the road bends round a river cove under a broken wooded bank. The thieves' side (the "
         "bank) has crates, rocks and trees to hide behind; the party's side is open grass with the water at its back.",
    L=[
        "....222......3333.....",
        "...22222....333333....",
        "..222222....3333333...",
        "..22222.....22333333..",
        "..111111....1122333...",
        ".1111111.111111222....",
        "....11111111111111....",
        "000000111111111111....",
        "00000000000000000111..",
        ".00000000000000000....",
        "..00000000000000000...",
        "..00000000000000000000",
        "...00000000000000000..",
        "....00000000000000000.",
        "......00......0000....",
        "...............000....",
        "......................",
    ],
    M=[
        "    t t      tRt      ",
        "   t   t    t   t     ",
        "  t  r      s  r  t   ",
        "  ts  x        s   t  ",
        "   A        x     r   ",
        " r   x r    A  s      ",
        "    s      x    s     ",
        "dd   s   r   w  A     ",
        " ddddddd     w    s   ",
        "  pp  ddK#x  w   r    ",
        "  pp  P ##cddbddd     ",
        "   r wwP  P  w  dddddd",
        "   wwwwwww P w  y     ",
        "    wwwwwwwwwwwwwwwww ",
        "      ww      wwww    ",
        "               www    ",
        "                      ",
    ],
    props={"K": dict(sprite="village/prop_cart", foot=[2, 2], tall=1.3, sight=1.0)},
    foes={"A": dict(id="ambusher", hidden=True), "R": dict(id="bandit_archer")},
)

_L = [
    "......1111............",
    "....11111111....333...",
    "...111111111...22332..",
    "...11111111....22222..",
    "....00000000...11222..",
    "...00000000000000000..",
    "000000000000000000000.",
    "0000000000000000000000",
    "0000000000000000000000",
    ".000000000000000000000",
    "..0000000000000000000.",
    "..000000000000000000..",
    "..000000000000000000..",
    "......0000............",
]
PIECES["bulls"] = dict(
    look="farmland", art_set="farmland",
    note="E2 Loose bulls: a broken corral in open farmland, fields split by irrigation ditches with gaps to cross at. The barn "
         "stands on a rise behind a ditch, a haystack hill beside it. Bulls charge along straight runs; fences, "
         "hay bales and gateways break a run. The barn's yard is the way out.",
    L=_L,
    M=marks(_L, "H:6,0 #:7-9,0 #:6-9,1-2 T:4,1 T:11,1 T:3,2 h:17,1 T:18,1 X:3-6,3 h:8,3 T:19,3 "
                "s:17,3 s:4,4 s:9,4 s:16,4 s:15,5 w:5-8,4 r:11,4 "
                "f:7-11,6 f:13-14,6 F:7,7 F:14,7 f:7-8,9 f:11-14,9 "
                "U:8,7 W:10,7 #:11,7 #:10-11,8 U:13,8 U:11,10 V:19,6 "
                "w:4,6-8 w:16,5-8 w:4-7,11 w:10-16,11 w:1,7 w:1-2,8 r:3,9 r:20,7 h:6,5 h:15,10 h:3,5 h:18,8 h:5,10 "
                "P:17-18,9 P:17-18,10 d:2-19,12 p:16-19,12 h:8,13 T:6,13"),
    props={"H": dict(sprite="village/b_home_b", foot=[4, 3], tall=0.0, sight=3.0),
           "W": dict(sprite="village/prop_well", foot=[2, 2], tall=1.8, sight=1.0),
           "F": dict(sprite="village/prop_fence", tall=0.6, sight=0.0, flip=True)},
    foes={"U": dict(id="foe_bull"), "V": dict(id="foe_rusher")},
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
               props=[], party=[], out=[], foes=[], exit=[], stones=[], docks=[])
    for y, row in enumerate(M):
        marks = ""
        for x, ch in enumerate(row):
            marks += ch if ch in PLOT else " "
            if ch in PLOT or ch == "#":
                continue
            assert L[y][x] != ".", (pid, "thing outside the map", ch, x, y)
            if ch == "P":
                out["party"].append([x, y])
            elif ch == "p":
                out["out"].append([x, y])
            elif ch == "X":
                out["exit"].append([x, y])
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
