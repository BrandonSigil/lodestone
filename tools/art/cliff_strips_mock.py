#!/usr/bin/env python3
"""Cliff strips mock (art runner, 2026-10-30): a village v2 terrace whose faces are cut into windows 1 to 3
cells wide at hashed spots; each window is one tall strip cut from Brandon's snowy cliff painting, started at
its own random depth and run down the whole face, mirrored where it runs out, so no join ever sits on a level
line (card cliff-no-breaks). Windows blend a little at their sides. Staging only; it places pixels, it
never edits art.

    ~/.lodestone/venv/bin/python tools/art/cliff_strips_mock.py OUT.png "#8c827d" 1 0 pieces
"""
import sys
import numpy as np
from PIL import Image, ImageDraw

Z = 0.75
TW, TH, HS = 64 * Z, 32 * Z, 16 * Z
INK = (55, 51, 53)
GRASS = np.array([150, 158, 92], float)

# The terrace: stepped shelves on the left (24, 18, 12, 6, 0 like the map), one 24-level drop on the right.
N = 12
H = np.zeros((N, N), int)
for x in range(N):
    for y in range(N):
        if x < 7:
            H[y, x] = [24, 24, 24, 12, 12, 12, 6, 6, 6, 0, 0, 0][y]
        else:
            H[y, x] = 24 if y <= 6 else 0


def iso(x, y, h):
    return ((x - y) * TW * 0.5, (x + y) * TH * 0.5 - h * HS)


def hsh(*k):
    v = 2166136261
    for i in k:
        v = ((v ^ (int(i) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
    return v


def vnoise(a, b):
    """Smooth value noise in 0..1 over the face's world coordinates."""
    ia, ib = np.floor(a).astype(int), np.floor(b).astype(int)
    fa, fb = a - ia, b - ib
    fa, fb = fa * fa * (3 - 2 * fa), fb * fb * (3 - 2 * fb)
    r = np.vectorize(lambda p, q: (hsh(p, q, 7) % 1000) / 1000.0)
    c00, c10, c01, c11 = r(ia, ib), r(ia + 1, ib), r(ia, ib + 1), r(ia + 1, ib + 1)
    return (c00 * (1 - fa) + c10 * fa) * (1 - fb) + (c01 * (1 - fa) + c11 * fa) * fb


def sample(texs, along, h, axis, scale, variety):
    size = texs[0].shape[0]
    u = along / (2.0 * scale)
    v = -h / (4.0 * scale)
    col = np.floor(u).astype(int)
    full = variety == 1
    if full:
        v = v + np.vectorize(lambda c: (hsh(c, axis, 1) % 1000) / 1000.0)(col)
    row = np.floor(v).astype(int)
    fu, fv = u - col, v - row
    out = np.zeros(u.shape + (3,))
    if full:
        pick = np.vectorize(lambda c, r: hsh(c, r, axis, 2) % len(texs))(col, row)
        flip = np.vectorize(lambda c, r: hsh(c, r, axis, 3) & 1)(col, row).astype(bool)
        fu = np.where(flip, 1 - fu - 1e-6, fu)
    else:
        pick = np.zeros_like(col)
    tx = np.clip((fu * size).astype(int), 0, size - 1)
    ty = np.clip((fv * size).astype(int), 0, size - 1)
    for i, t in enumerate(texs):
        m = pick == i
        out[m] = t[ty[m], tx[m]]
    if variety:
        out *= (0.9 + 0.2 * vnoise(along / 5.0, h / 9.0))[..., None]
    return out


INKC = np.array([55, 51, 53], float)


LINE = np.array([52, 46, 48], float)


def rnd(*k):
    return (hsh(*k) % 100000) / 100000.0


def line_at(c, axis):
    """The one possible line in cell column c: about one column in four has one. Returns its offset across
    the column, or None."""
    return 0.15 + 0.7 * rnd(c, axis, 2) if rnd(c, axis, 1) < 0.27 else None


def marks(along, h, axis, top, bottom, col):
    """The cliff marks after Brandon's example: one thick dark line here and there, running from under the
    lip most of the way down, with a soft shade strip beside it; the lines split the face into broad planes of
    slightly different tone; under it all a faint fine mottle and the odd speckle, spread evenly over the
    whole height. Seeded on the world cell, sizes in screen pixels at zoom 1.5."""
    X, Y = along * TW * 0.5, h * HS
    c0 = int(np.floor(along.min()))
    span = top - bottom
    # Planes: each line starts a plane that runs right until the next line, a few percent lighter or darker.
    plane = np.ones_like(along)
    for c in range(c0 - 5, c0 + 1):
        off = line_at(c, axis)
        if off is not None:
            start = c + off
            plane = np.where(along >= start, 1 + (rnd(c, axis, 3) - 0.5) * 0.2, plane)
    col *= plane[..., None]
    # Soft vertical streaks: a wide faint darker band now and then, down most of the face, like the example's
    # shaded flutes between lines.
    for c in range(c0 - 1, c0 + 2):
        if rnd(c, axis, 20) < 0.35:
            cx = (c + rnd(c, axis, 21)) * TW * 0.5
            hw = 8 + rnd(c, axis, 22) * 14
            reach = span * (0.5 + 0.5 * rnd(c, axis, 23))
            v = np.clip((Y - (top - reach) * HS) / (reach * HS * 0.4 + 1), 0, 1)
            a = np.clip(1 - np.abs(X - cx) / hw, 0, 1) ** 1.5 * 0.14 * v
            col *= (1 - a)[..., None]
    # Faint grain: a soft mottle stretched tall, so the paint reads as dabs running down the rock.
    g = 0.6 * vnoise(along / 0.35 + 31, h / 1.4 + 17) + 0.4 * vnoise(along / 0.14 + 5, h / 0.55 + 2) - 0.5
    g = g + 0.12 * (vnoise(along / 0.04 + 3, h / 0.12 + 9) - 0.5)  # chippy, broken dab edges
    flat = np.where(g > 0.14, 0.038, np.where(g < -0.14, -0.042, 0.0))  # three flat tones, crisp edges, like dabs
    col *= (1 + flat)[..., None]
    for c in range(c0 - 1, c0 + 2):
        for lv in range(int(np.floor(bottom)) - 1, int(np.ceil(top)) + 1):
            if rnd(c, lv, axis, 14) < 0.06:  # the odd speckle, faint
                px, py = (c + rnd(c, lv, axis, 15)) * TW * 0.5, (lv + rnd(c, lv, axis, 16)) * HS
                a = np.clip(1.2 - np.hypot(X - px, Y - py) / 1.4, 0, 1) * 0.3
                col *= (1 - a)[..., None]
    # Lines: thick, nearly straight, from just under the lip down 55 to 100% of the face, thinning at the foot.
    for c in range(c0 - 1, c0 + 2):
        off = line_at(c, axis)
        if off is None or span < 1.5:
            continue
        reach = span * (0.7 + 0.3 * rnd(c, axis, 4))
        y_top, y_end = (top - 0.38) * HS, (top - reach) * HS
        inside = (Y <= y_top) & (Y >= y_end)
        t = np.clip((y_top - Y) / max(y_top - y_end, 1), 0, 1)
        lean = (rnd(c, axis, 5) - 0.5) * 0.05
        hook = (1 if rnd(c, axis, 8) < 0.5 else -1) * 8 * np.exp(-(y_top - Y) / 7) if rnd(c, axis, 9) < 0.6 else 0
        x = (c + off) * TW * 0.5 + lean * (y_top - Y) + 1.0 * np.sin((y_top - Y) / 90 + c) + hook
        w = (4.0 + rnd(c, axis, 6) * 1.2) * (1 - 0.35 * t ** 4)
        d = X - x
        side = 1 if rnd(c, axis, 7) < 0.5 else -1
        band = 12 + rnd(c, axis, 24) * 12 + 2.0 * np.sin(Y / 9 + c)  # a crisp darker band beside the line
        sh = inside * (((d * side) > 0) & ((d * side) < band)) * 0.23 * (1 - 0.3 * t)
        col *= (1 - sh)[..., None]
        a = inside * np.clip(w + 0.6 - np.abs(d), 0, 1) * 0.9
        col[:] = col * (1 - a[..., None]) + LINE * a[..., None]
    return col


EX = np.asarray(Image.open(__import__("pathlib").Path(__file__).resolve().parents[2] / "docs/art/references/village-v2-cliff-example-snow.png").convert("RGB"), float)
CHUNKS = [(390, 285, 560, 425), (605, 215, 690, 305), (700, 255, 790, 350), (440, 255, 560, 425),
          (390, 290, 470, 425), (480, 290, 560, 425)]  # the warm-grey rock only, no snow
BLOCK = 3  # levels in one block: village v2's drops come in threes
MAX_BLOCKS = 5  # a painted piece is 1 to 5 blocks tall; taller faces stack two with a ledge


def is_start(k, axis):
    """A piece starts at cell k on a hash, and at least every third cell, so pieces are 1 to 3 cells wide."""
    return rnd(k, axis, 40) < 0.45 or k % 3 == 0


def span_of(c, axis):
    k = c
    while not is_start(k, axis):
        k -= 1
    return k


FEATHER_V = 3.0  # px of cross-fade where two pieces stack, at a height of its own in every window
FEATHER_H = 0.18  # cells of cross-fade where two windows meet


def window_color(st, axis, top, xpx, dpx):
    """Paint for window `st` at xpx px across it and dpx px below the lip: one piece of Brandon's painting at
    its own scale, started at a random depth inside it, and when the face is taller than the piece it runs on
    into the piece mirrored top to bottom, so the paint continues with no join at all. Each window starts at
    its own depth, so the mirror points never line up across a cliff."""
    ci = int(rnd(st, axis, int(top), 41) * len(CHUNKS))
    x0, y0, x1, y1 = CHUNKS[ci]
    ch = y1 - y0 - 1
    xo = x0 + rnd(st, axis, int(top), 42) * max(0, (x1 - x0) - 3 * TW * 0.5 - 1)
    v = rnd(st, axis, int(top), 43) * ch * 0.5 + dpx
    v = np.abs(((v / ch) % 2.0) - 1.0)  # a triangle wave: down the piece, then back up it mirrored
    v = 1.0 - v
    xs = np.clip((xo + xpx).astype(int), x0, x1 - 1)
    ys = np.clip((y0 + v * ch).astype(int), y0, y1 - 1)
    return EX[ys, xs].astype(float)


def pieces(along, h, axis, top, bottom):
    cell = np.floor(along).astype(int)
    start = np.vectorize(lambda c: span_of(c, axis))(cell)
    dpx = (top - h) * HS
    out = np.zeros(along.shape + (3,))
    for st in np.unique(start):
        m = start == st
        xpx = (along[m] - st) * TW * 0.5
        col = window_color(st, axis, top, xpx, dpx[m])
        # Feather into the window before: near this window's left edge, blend in the previous window's paint
        # carried on past its end.
        prev = span_of(st - 1, axis)
        f = np.clip((along[m] - st) / FEATHER_H, 0, 1)
        near = f < 1
        if near.any():
            pc = window_color(prev, axis, top, (along[m][near] - prev) * TW * 0.5, dpx[m][near])
            col[near] = col[near] * f[near][:, None] + pc * (1 - f[near][:, None])
        out[m] = col
    return out


def wash(along, h, base):
    """A stand-in for the painted wash: one rock colour with soft mottle (the real base comes from Picsart)."""
    m = vnoise(along / 2.5, h / 6.0)
    return base[None, :] * (0.97 + 0.06 * m)[..., None]


def render(texs, scale=1, variety=False):
    xs = [iso(x, y, h)[0] for x in (0, N) for y in (0, N) for h in (0, 24)]
    ys = [iso(x, y, h)[1] for x in (0, N) for y in (0, N) for h in (0, 24)]
    ox, oy = -min(xs) + 10, -min(ys) + 10
    W, Hh = int(max(xs) - min(xs) + 20), int(max(ys) - min(ys) + 20)
    img = np.full((Hh, W, 3), 234.0)
    img[:] = (234, 232, 214)
    yy, xx = np.mgrid[0:Hh, 0:W].astype(float)
    sx, sy = xx - ox, yy - oy
    lines = []

    def poly_mask(pts):
        m = Image.new("L", (W, Hh), 0)
        ImageDraw.Draw(m).polygon([(px + ox, py + oy) for px, py in pts], fill=255)
        return np.asarray(m) > 0

    def face(a, b, h, hb, axis, shade):
        if h <= hb:
            return
        pts = [iso(*a, h), iso(*b, h), iso(*b, hb), iso(*a, hb)]
        m = poly_mask(pts)
        if not m.any():
            return
        if axis == 0:  # along x at y = a[1]: sx = (x - y) * TW/2
            along = sx[m] / (TW * 0.5) + a[1]
            hh = ((along + a[1]) * TH * 0.5 - sy[m]) / HS
        else:  # along y at x = a[0]
            along = a[0] - sx[m] / (TW * 0.5)
            hh = ((a[0] + along) * TH * 0.5 - sy[m]) / HS
        if PIECES:
            col = pieces(along, hh, axis, h, hb)
        elif isinstance(texs, np.ndarray) and texs.ndim == 1:
            col = wash(along, hh, texs)
        else:
            col = sample(texs, along, hh, axis, scale, variety)
        if LINES and not PIECES:
            col = marks(along, hh, axis, h, hb, col)
        col *= 0.72 if shade else 1.0
        lip = hh > h - 0.35
        col[lip] = GRASS * (0.8 if shade else 0.9)
        img[m] = col
        lines.append([pts[2], pts[3]])

    for s in range(2 * N):
        for y in range(N):
            x = s - y
            if not (0 <= x < N):
                continue
            h = H[y, x]
            top = [iso(x, y, h), iso(x + 1, y, h), iso(x + 1, y + 1, h), iso(x, y + 1, h)]
            img[poly_mask(top)] = GRASS
            hf = H[y + 1, x] if y + 1 < N else 0
            face((x, y + 1), (x + 1, y + 1), h, hf, 0, False)
            hr = H[y, x + 1] if x + 1 < N else 0
            face((x + 1, y), (x + 1, y + 1), h, hr, 1, True)
    out = Image.fromarray(img.clip(0, 255).astype(np.uint8))
    return out


def load(p):
    return np.asarray(Image.open(p).convert("RGB"), float)


LINES = False
PIECES = False

if __name__ == "__main__":
    out = sys.argv[1]
    LINES = len(sys.argv) > 5 and sys.argv[5] == "lines"
    PIECES = len(sys.argv) > 5 and sys.argv[5] == "pieces"
    texs = np.array([int(sys.argv[2][i:i + 2], 16) for i in (1, 3, 5)], float) if sys.argv[2].startswith("#") else [load(p) for p in sys.argv[2].split(",")]
    scale = float(sys.argv[3])
    variety = int(sys.argv[4])
    render(texs, scale, variety).save(out)
    print(out)
