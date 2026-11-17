"""Draws the pitch sketches: python3 tools/setpieces/sketch.py <out_dir>. Flat top-down, one cell = one tile."""
import sys, math
from PIL import Image, ImageDraw, ImageFont
from layouts import LAYOUTS

C = 34
FONT = "/home/claude/lodestone/game/fonts/YoungSerif-Regular.ttf"
OUT = "#373335"
ZONE = {
    "west": dict(ground=(126, 166, 92), road=(196, 170, 120), water=(84, 146, 178)),
    "north": dict(ground=(214, 222, 226), road=(178, 168, 150), water=(110, 160, 190)),
    "east": dict(ground=(170, 182, 92), road=(200, 166, 110), water=(92, 150, 176)),
}

def mix(a, b, k):
    return tuple(int(a[i] + (b[i] - a[i]) * k) for i in range(3))

TOP = [6]

def shade(c, h):
    """Low ground sits in shadow, high ground in light (against the map's own top), so height reads from above."""
    return mix(c, (70, 76, 84), min(0.4, max(0, TOP[0] - h) * 0.06))

def draw(key, path):
    L = LAYOUTS[key]; z = ZONE[L["zone"]]
    H, T = L["h"], L["t"]; rows, cols = len(H), len(H[0])
    TOP[0] = max(int(ch, 36) for r in H for ch in r if ch != ".")
    pad, top = 16, 46
    im = Image.new("RGB", (cols * C + pad * 2, rows * C + top + pad), (244, 236, 218))
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(FONT, 22); fs = ImageFont.truetype(FONT, 13)
    d.text((pad, 10), f"{key}  {L['name']}", font=f, fill=OUT)
    hv = lambda x, y: int(H[y][x], 36) if H[y][x] != "." else None
    def box(x, y, m=0):
        return (pad + x * C + m, top + y * C + m, pad + (x + 1) * C - m, top + (y + 1) * C - m)
    water = set("wRvob")
    for y in range(rows):
        for x in range(cols):
            h = hv(x, y); t = T[y][x]
            if h is None: continue
            g = z["ground"]
            if t in "wRvk": g = z["water"]
            elif t in "o b": g = z["water"] if t in "ob" else g
            if t == "d" or t == "X": g = z["road"]
            if t == "c": g = (214, 186, 96)
            if t == "i": g = (200, 228, 240)
            d.rectangle(box(x, y), fill=shade(g, h if t not in "wRvkob" else 0))
            cx, cy = pad + x * C + C / 2, top + y * C + C / 2
            r = C / 2
            if t == "R":
                for k in range(2):
                    yy = cy - 6 + k * 10
                    d.line((cx - 10 + k * 4, yy, cx + 4 + k * 4, yy), fill=(235, 245, 250), width=3)
            elif t == "v":
                for k in range(4):
                    d.line((cx - 12 + k * 8, cy - 14, cx - 12 + k * 8, cy + 14), fill=(235, 245, 250), width=3)
            elif t == "o":
                d.ellipse((cx - 11, cy - 10, cx + 11, cy + 10), fill=(168, 164, 156), outline=OUT, width=2)
            elif t == "b":
                d.rectangle(box(x, y, 2), fill=(160, 112, 70), outline=OUT, width=2)
                for k in range(1, 4):
                    xx = pad + x * C + k * C / 4
                    d.line((xx, top + y * C + 3, xx, top + (y + 1) * C - 3), fill=(120, 80, 50), width=1)
            elif t == "k":
                d.ellipse((cx - 13, cy - 7, cx + 13, cy + 7), fill=(150, 100, 60), outline=OUT, width=2)
            elif t == "c":
                for k in range(3):
                    yy = top + y * C + 7 + k * 10
                    d.line((pad + x * C + 2, yy, pad + (x + 1) * C - 2, yy), fill=(170, 140, 60), width=3)
            elif t == "t":
                d.ellipse((cx - 14, cy - 14, cx + 14, cy + 14), fill=(52, 96, 62) if L["zone"] != "north" else (60, 98, 80), outline=OUT, width=2)
            elif t == "r":
                d.rounded_rectangle(box(x, y, 5), radius=7, fill=(150, 146, 140), outline=OUT, width=2)
            elif t == "e":
                for k in (-8, 0, 8):
                    d.line((cx + k, cy + 10, cx + k + 3, cy - 10), fill=(76, 120, 60), width=3)
            elif t == "s":
                for k in range(4):
                    yy = top + y * C + 5 + k * 7
                    d.line((pad + x * C + 5, yy, pad + (x + 1) * C - 5, yy), fill=OUT, width=2)
            elif t == "L":
                d.line((cx - 7, cy - 15, cx - 7, cy + 15), fill=(120, 80, 50), width=3)
                d.line((cx + 7, cy - 15, cx + 7, cy + 15), fill=(120, 80, 50), width=3)
                for k in range(4):
                    yy = cy - 12 + k * 8
                    d.line((cx - 7, yy, cx + 7, yy), fill=(120, 80, 50), width=2)
            elif t == "f":
                d.line((cx - r, cy, cx + r, cy), fill=(120, 84, 50), width=4)
                d.line((cx, cy - r, cx, cy + r), fill=(120, 84, 50), width=0)
                d.rectangle((cx - 3, cy - 6, cx + 3, cy + 6), fill=(120, 84, 50))
            elif t == "h":
                d.ellipse((cx - 12, cy - 10, cx + 12, cy + 10), fill=(232, 196, 92), outline=OUT, width=2)
                d.line((cx - 10, cy, cx + 10, cy), fill=(190, 150, 60), width=2)
            elif t == "W":
                d.ellipse((cx - 13, cy - 13, cx + 13, cy + 13), fill=(150, 146, 140), outline=OUT, width=2)
                d.ellipse((cx - 7, cy - 7, cx + 7, cy + 7), fill=z["water"], outline=OUT, width=2)
            elif t == "x":
                d.rectangle((cx - 12, cy - 4, cx - 1, cy + 9), fill=(170, 124, 76), outline=OUT, width=2)
                d.ellipse((cx + 1, cy - 11, cx + 13, cy + 1), fill=(150, 100, 60), outline=OUT, width=2)
            elif t == "S":
                d.line((cx, cy - 14, cx, cy + 14), fill=(110, 76, 44), width=3)
                d.line((cx - 12, cy - 5, cx + 12, cy - 5), fill=(110, 76, 44), width=3)
                d.ellipse((cx - 5, cy - 16, cx + 5, cy - 6), fill=(214, 186, 96), outline=OUT, width=1)
            elif t == "p" and False:
                pass
            elif t in "u":
                d.rectangle(box(x, y, 3), fill=(166, 160, 150), outline=OUT, width=2)
            elif t == "i":
                pass
        # blocks drawn as one shape below
    def blocks(ch, fill):
        cells = [(x, y) for y in range(rows) for x in range(cols) if T[y][x] == ch]
        seen = set()
        for c in cells:
            if c in seen: continue
            stack = [c]; grp = []
            while stack:
                p = stack.pop()
                if p in seen or p not in cells: continue
                seen.add(p); grp.append(p)
                stack += [(p[0] + 1, p[1]), (p[0] - 1, p[1]), (p[0], p[1] + 1), (p[0], p[1] - 1)]
            x0 = min(p[0] for p in grp); x1 = max(p[0] for p in grp) + 1
            y0 = min(p[1] for p in grp); y1 = max(p[1] for p in grp) + 1
            yield (pad + x0 * C, top + y0 * C, pad + x1 * C, top + y1 * C)
    for bx in blocks("H", None):
        d.rectangle((bx[0] + 3, bx[1] + 3, bx[2] - 3, bx[3] - 3), fill=(176, 92, 70), outline=OUT, width=3)
        d.line((bx[0] + 3, (bx[1] + bx[3]) / 2, bx[2] - 3, (bx[1] + bx[3]) / 2), fill=(130, 64, 52), width=3)
    for bx in blocks("K", None):  # the tipped wagon: a box on its side, a wheel up
        d.polygon([(bx[0] + 4, bx[1] + 10), (bx[2] - 2, bx[1] + 2), (bx[2] - 6, bx[3] - 4), (bx[0] + 2, bx[3] - 8)], fill=(150, 104, 62), outline=OUT, width=3)
        for wx, wy in ((bx[0] + 14, bx[1] + 12), (bx[2] - 18, bx[3] - 14)):
            d.ellipse((wx - 9, wy - 9, wx + 9, wy + 9), fill=(110, 76, 44), outline=OUT, width=2)
    for bx in blocks("T", None):
        d.rectangle((bx[0] + 2, bx[1] + 2, bx[2] - 2, bx[3] - 2), fill=(140, 136, 130), outline=OUT, width=3)
        d.rectangle((bx[0] + 14, bx[1] + 14, bx[2] - 14, bx[3] - 14), fill=(110, 106, 100))
    for bx in blocks("A", None):
        cx, cy = (bx[0] + bx[2]) / 2, (bx[1] + bx[3]) / 2
        d.rectangle((bx[0] + 6, bx[1] + 6, bx[2] - 6, bx[3] - 6), fill=(168, 160, 190), outline=OUT, width=3)
        d.ellipse((cx - 9, cy - 9, cx + 9, cy + 9), fill=(150, 220, 230), outline=OUT, width=2)
    for bx in blocks("m", None):
        cx, cy = (bx[0] + bx[2]) / 2, (bx[1] + bx[3]) / 2
        d.ellipse((bx[0] + 8, bx[1] + 8, bx[2] - 8, bx[3] - 8), fill=(206, 190, 160), outline=OUT, width=3)
        for a in range(4):
            ang = math.radians(45 + a * 90)
            d.line((cx, cy, cx + math.cos(ang) * 52, cy + math.sin(ang) * 52), fill=(110, 76, 44), width=6)
    # cliffs: a dark edge where the next cell is lower
    for y in range(rows):
        for x in range(cols):
            h = hv(x, y)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < cols and 0 <= ny < rows): continue
                n = hv(nx, ny)
                if n is None or h is None or n >= h: continue
                if T[ny][nx] == "s" or T[y][x] == "s" or T[y][x] in "b" or T[ny][nx] == "b": w = 2
                else: w = 2 + min(h - n, 6)
                x0, y0, x1, y1 = box(x, y)
                seg = {(1, 0): (x1, y0, x1, y1), (-1, 0): (x0, y0, x0, y1), (0, 1): (x0, y1, x1, y1), (0, -1): (x0, y0, x1, y0)}[(dx, dy)]
                d.line(seg, fill=OUT, width=w)
    # starts and foes last
    for y in range(rows):
        for x in range(cols):
            t = T[y][x]; cx, cy = pad + x * C + C / 2, top + y * C + C / 2
            if t == "P":
                d.ellipse((cx - 11, cy - 11, cx + 11, cy + 11), fill=(70, 120, 200), outline=OUT, width=2)
            elif t == "p":
                d.ellipse((cx - 10, cy - 10, cx + 10, cy + 10), outline=(70, 120, 200), width=4)
            elif t in "EB":
                d.ellipse((cx - 11, cy - 11, cx + 11, cy + 11), fill=(206, 70, 60), outline=OUT, width=2)
                if t == "B":
                    d.polygon([(cx - 8, cy - 2), (cx - 8, cy - 9), (cx - 3, cy - 5), (cx, cy - 11), (cx + 3, cy - 5), (cx + 8, cy - 9), (cx + 8, cy - 2)], fill=(250, 214, 90))
            elif t == "Q":
                d.ellipse((cx - 11, cy - 11, cx + 11, cy + 11), fill=(240, 200, 190), outline=(206, 70, 60), width=3)
                d.text((cx, cy), "?", font=fs, fill=(206, 70, 60), anchor="mm")
            elif t == "X":
                d.text((cx, cy), "EXIT", font=ImageFont.truetype(FONT, 9), fill=OUT, anchor="mm")
    im.save(path)

def legend(path):
    items = [("P", "party (walked in)"), ("p", "party (saw them first)"), ("E", "foe"), ("Q", "hidden foe"),
             ("B", "foe leader"), ("t", "trees (cover)"), ("r", "rocks"), ("x", "crates, barrels"), ("h", "hay bale"),
             ("f", "fence or low wall"), ("W", "well, trough"), ("S", "scarecrow (prop)"), ("c", "crop rows"),
             ("R", "rapids"), ("o", "stepping stone"), ("b", "bridge, dock"), ("s", "stairs"), ("L", "climb (ladder, ivy)"),
             ("u", "ruin wall"), ("e", "reeds")]
    L = {"zone": "west", "name": "", "h": ["0" * len(items)], "t": ["".join(k for k, _ in items)]}
    im = Image.new("RGB", (4 * 230 + 20, 5 * 40 + 20), (244, 236, 218))
    d = ImageDraw.Draw(im); fs = ImageFont.truetype(FONT, 15)
    for i, (k, label) in enumerate(items):
        LAYOUTS["_one"] = {"zone": "east" if k in "chSfW" else "west", "name": "", "h": ["0"], "t": [k]}
        tmp = "/tmp/_cell.png"; draw("_one", tmp)
        cell = Image.open(tmp).crop((16, 46, 16 + C, 46 + C))
        col, row = i % 4, i // 4
        im.paste(cell, (10 + col * 230, 10 + row * 40))
        d.text((10 + col * 230 + C + 8, 10 + row * 40 + 8), label, font=fs, fill=OUT)
    im.save(path)

if __name__ == "__main__":
    out = sys.argv[1]
    for k in list(LAYOUTS):
        if not k.startswith("_"): draw(k, f"{out}/{k}.png")
    legend(f"{out}/legend.png")
