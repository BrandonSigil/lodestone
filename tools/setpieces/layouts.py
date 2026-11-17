"""Set-piece road-fight layouts, pitch sketches (2026-11-17). Each layout is two equal grids:
h = height digits per cell, t = what stands there (legend in sketch.py). Lower-case p = the party's start
when it spots the foes first (walk past, sneak); upper-case P = its start when it walks into the ambush."""

LAYOUTS = {
"W1": dict(zone="west", name="Tipped wagon", h=[
"2222111111112222",
"2221111111111222",
"1111111111111122",
"1111111111111111",
"0000000000000000",
"0000000000000000",
"0000000000000000",
"0000000000000000",
"0000000000000000",
"0000000000000000",
"0000000000000000",
"0000000000000000"], t=[
"tttt tt  ttt tEt",
"tt  t      Q  tt",
"t  Q  r  xx   t ",
"  x  r   x  Q   ",
"dddddddKKKdddddd",
"pp    P K P     ",
"pp     PP       ",
"  t        t  t ",
" e  ee  e   ee  ",
"wwwwwwwwwwwwwwww",
"wwwwwwwwwwwwwwww",
"wwwwwwwwwwwwwwww"]),

"W2": None,  # built below: falls up top with the bridge over them, high ground on both banks

"W3": dict(zone="west", name="Lake dock and hut", h=[
"2222221111111111",
"2222111111111111",
"2221111111111111",
"1111111111111111",
"1111111111111111",
"1111111111110000",
"1111111111100000",
"1111111110000000",
"1111111000000000",
"1111110000000000",
"1110000000000000",
"1100000000000000"], t=[
"tttttt   tttttt ",
"tt  ddd  t   tt ",
"t  dd HHH     t ",
"  d   HHH  e    ",
" d  P HHH  ee   ",
"pp  P P   e wwww",
"pp  xx  e Qwwwww",
"  t    e  wwwwww",
" t   ee  bbbbEww",
"t  eeQ  wwwwbkww",
"t eewwwwwwwwwwww",
"ttwwwwwwwwwwwwww"]),

"N1": dict(zone="north", name="Ruined watchtower", h=[
"2222444466666666",
"2222444466666666",
"2222444466666666",
"2222444444446666",
"2222444444444444",
"0002244444444444",
"0002222222244444",
"0000222222222444",
"0000022222222224",
"0000002222222222",
"0000000222222222",
"0000000022222222"], t=[
"tt  t   L uTTu E",
"t       L  TTE  ",
" t  r   s u   u ",
"  t    E    u s ",
"t   Q  u  p     ",
"  s  s   E      ",
"  s    r    p s ",
"   s       s    ",
"PP   r  t    t  ",
"PP  t     s  tt ",
"pp   t      ttt ",
"pp       ttt  tt"]),

"N2": dict(zone="north", name="Snowbound shrine bowl", h=[
"4444444444444444",
"4433333333333344",
"3322222222222233",
"3220000000000223",
"3220000000000223",
"3220000000000223",
"3220000000000223",
"3220000000000223",
"3220000000000223",
"3322222222222233",
"4433333333333344",
"4444444444444444"], t=[
"tt  u  pp  u  tt",
"t  E   u  u   Et",
"  u ss      ss  ",
" p  u      u  p ",
"  u  Q   Q   u  ",
"  s  i AA  i s  ",
"  u  PPAAP   u  ",
" p    P   Q  p  ",
"  u  Q  i    u  ",
"   ss  u  u ss  ",
" t  E      E  t ",
"tt  t      t  tt"]),

"N3": dict(zone="north", name="Rope bridge gorge", h=[
"6666600000066666",
"6666600000066666",
"6666600000066666",
"6666600000066666",
"6666600000066666",
"6666600000066666",
"6666600000066666",
"6666600000066666",
"6666600000066666",
"6666600000066666",
"6666600000066666",
"6666600000066666"], t=[
"ttt  r ww r  ttt",
"t  t   ww    E t",
"  r  s ww    r  ",
"P     sww  Q    ",
"P      ww     E ",
"PPddbbbbbbbbddE ",
"p      ww       ",
"p    E ww  L    ",
"  r    ww E L r ",
" t     ww    t  ",
"tt   r ww    ttt",
"ttt    ww  r ttt"]),

"E1": dict(zone="east", name="Scarecrow farm", h=[
"000000000000000000",
"000000001111111110",
"000000001111111110",
"000000001111111110",
"000000001111111110",
"000000001111111110",
"000000001111111110",
"000000000000000000",
"000000000000000000",
"000000000000000000",
"000000000000000000",
"000000000000000000"], t=[
"cccccc   ffffffff ",
"cScccc   f HHHH  f",
"        f  HHHH  f",
"cccQcc  f   P  x f",
"ccScccc f  PWP   f",
"        f   P h  f",
"cccccQ  fff  ffff ",
"  h          h    ",
"cQcScc     h     t",
"         S    t   ",
"ddddddddddddddddd ",
"pp t      h    t  "]),

"E2": dict(zone="east", name="Loose bulls corral", h=[
"000000000000000000",
"111100000000000000",
"111100000000000000",
"111100000000000000",
"111100000000000000",
"000000000000000000",
"000000000000000000",
"000000000000000000",
"000000000000000000",
"000000000000000000",
"000000000000000000",
"000000000000000000"], t=[
"  t       h    t  ",
"HHHH  fffff ffff  ",
"HHHH  f   E    f h",
"HHHHX f  h     f  ",
"HHHHX     E  E f  ",
"  XX  f   h    f  ",
" h    f  E   W f  ",
"      fff ffffff  ",
"  h        h      ",
" t   h         PP ",
"ddddddddddddddddPP",
"   t     h     t  "]),

"E3": dict(zone="east", name="Windmill hill", h=[
"000002222222200000",
"000002222222200000",
"000002222222200000",
"000002222222200000",
"000000222222000000",
"000000000000000000",
"000000000000000000",
"000000000000000000",
"000000000000000000",
"000000000000000000",
"000000000000000000",
"000000000000000000"], t=[
"cccc  t     t cccc",
"cccc   mmm  E cccc",
"cccc E mmm     ccc",
"ccc    mmmE   cccc",
"ccc   s    s  ccc ",
"  fff   B   fff   ",
"ccc    h  h    ccc",
"cpcQ        Q  ccc",
"cp   fff  fff    c",
"cp  h    h    h  c",
"dddddddddddddddddd",
"    PPP      t    "]),
}


def _w2():
    """W2: the river falls from an upper pool (the bridge crosses above the falls), then runs as rapids past a line
    of stepping stones. Both banks rise: a rocky outcrop on the left (stairs, a scramble), a knoll on the right."""
    h = [
        "..555555555555..",
        "..555555555555..",
        ".444451111555555",
        "4444221111555555",
        "4444221111555555",
        "2444221111335555",
        "2222221111333355",
        "2222221111333333",
        "2222221111335553",
        ".222221111335553",
        "..22221111335553",
        "..2222111133333.",
        "...22.1111.333..",
    ]
    t = [[" "] * 16 for _ in h]
    def put(ch, *cells):
        for x, y in cells:
            t[y][x] = ch
    for y in range(13):
        for x in range(6, 10):
            t[y][x] = "w" if y < 2 or y > 10 else ("v" if y == 2 else "R")
    put("o", *[(x, 7) for x in range(6, 10)])
    put("b", *[(x, 1) for x in range(5, 11)])
    put("d", (2, 1), (3, 1), (4, 1), (11, 1), (4, 4), (4, 5), (0, 7), (1, 7), (2, 7), (3, 7), (4, 7), (5, 7),
        (10, 7), (11, 7), (12, 7), (13, 7), (14, 7), (15, 7))
    put("s", (4, 2), (4, 3), (3, 6), (12, 6), (12, 11))
    put("L", (0, 5), (11, 9))
    put("t", (2, 0), (3, 0), (4, 0), (12, 0), (13, 0), (1, 8), (2, 9), (3, 11), (14, 11), (15, 3), (15, 4))
    put("r", (11, 3), (14, 6), (5, 9), (1, 2))
    put("P", (3, 8), (4, 8), (4, 9), (5, 8))
    put("p", (1, 3), (2, 3), (1, 4), (2, 4))
    put("E", (12, 1), (13, 8), (14, 10))
    put("Q", (11, 8))
    return dict(zone="west", name="Stepping-stone falls", h=h, t=["".join(r) for r in t])


LAYOUTS["W2"] = _w2()

# The outline: cells cut out of each map so no map is a plain box (map-look rule V9: cuts run two cells or more
# along an edge where they can). Rectangles x0, y0, x1, y1, inclusive.
CUTS = {
    "W1": [(0, 0, 1, 1), (6, 0, 8, 0), (15, 0, 15, 1), (0, 10, 2, 11), (12, 11, 15, 11), (15, 8, 15, 10)],
    "W3": [(0, 0, 2, 0), (13, 0, 15, 1), (15, 2, 15, 3), (0, 11, 1, 11), (14, 11, 15, 11), (0, 7, 0, 8)],
    "N1": [(0, 0, 1, 0), (14, 10, 15, 11), (12, 11, 13, 11), (0, 5, 0, 6), (15, 4, 15, 5)],
    "N2": [(0, 0, 2, 1), (12, 0, 15, 0), (15, 1, 15, 2), (0, 10, 2, 11), (13, 10, 15, 11), (0, 5, 0, 6)],
    "N3": [(0, 0, 1, 1), (14, 0, 15, 0), (0, 11, 2, 11), (13, 11, 15, 11), (15, 4, 15, 6)],
    "E1": [(0, 7, 1, 7), (17, 7, 17, 9), (13, 11, 17, 11), (17, 10, 17, 10), (0, 0, 1, 0)],
    "E2": [(0, 0, 3, 0), (16, 0, 17, 1), (0, 11, 2, 11), (17, 2, 17, 4), (0, 7, 0, 9)],
    "E3": [(0, 0, 1, 1), (16, 0, 17, 0), (0, 11, 3, 11), (14, 11, 17, 11), (17, 5, 17, 7)],
}
for _k, _rects in CUTS.items():
    _h = [list(r) for r in LAYOUTS[_k]["h"]]
    for x0, y0, x1, y1 in _rects:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                assert LAYOUTS[_k]["t"][y][x] not in "PpEQB", (_k, x, y)
                _h[y][x] = "."
    LAYOUTS[_k]["h"] = ["".join(r) for r in _h]
