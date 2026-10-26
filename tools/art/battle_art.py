#!/usr/bin/env python3
"""Battle map art kit: diagrams, drawing templates and image-gen control images.

Everything here uses the same iso math as game/scripts/combat/combat_board.gd, at art scale
(2x the engine's 64 px tile), so anything drawn on these templates drops onto the grid.

    python3 tools/art/battle_art.py            # writes docs/art/battle-maps/ and art/templates/battle-maps/

Needs Pillow, numpy and psd-tools (pip install pillow numpy psd-tools).
See docs/art/battle-maps.md for the rules these files encode.
"""
from __future__ import annotations

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs/art/battle-maps"
TEMPLATES = ROOT / "art/templates/battle-maps"
MAPS = ROOT / "game/data/maps"

# --- geometry (engine values x2) -----------------------------------------------------------
SCALE = 2
TW = 64 * SCALE  # tile width on screen
TH = 32 * SCALE  # tile height on screen
HS = 16 * SCALE  # pixels per height level
BASE = -2.0  # templates hang the island two levels below height 0
CANVAS = (2400, 1600)  # every map template is this size
RUIN_RISE = 2

# --- palette measured from the reference (docs/art/battle-maps.md section 5) -------------
PAPER = (234, 232, 214)
INK = (55, 51, 53)  # outline: warm plum-gray, never black
P = {
    "paper": "#eae8d6", "ink": "#373335",
    "grass_light": "#b7c37a", "grass": "#abbb71", "moss": "#909b69", "moss_dark": "#708f6a",
    "pine": "#4d7670", "path": "#d8cb97",
    "stone_top": "#d7cfb0", "stone_mid": "#c5bea2", "stone_pale": "#b3af96",
    "stone_lit": "#9e9989", "stone_shade": "#727877", "stone_deep": "#555954",
    "water": "#6cb6c1", "water_deep": "#5198b1", "foam": "#a5cdcb", "glint": "#f2f1e2",
}


def rgb(name: str) -> tuple:
    h = P[name].lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


TOP = {"g": "grass_light", "f": "moss", "w": "water", "r": "stone_pale", "d": "path",
       "s": "stone_top", "t": "stone_mid", "u": "stone_pale"}
BUILT = set("stu")


def font(size: int, serif=False):
    names = (["game/fonts/YoungSerif-Regular.ttf"] if serif else []) + [
        "/usr/share/fonts/truetype/crosextra/Carlito-Regular.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]
    for n in names:
        p = Path(n) if n.startswith("/") else ROOT / n
        if p.exists():
            return ImageFont.truetype(str(p), size)
    return ImageFont.load_default()


class Iso:
    """Grid to screen, with the engine's camera rotation."""

    def __init__(self, w: int, h: int, origin=(0.0, 0.0), rot=0):
        self.w, self.h, self.ox, self.oy, self.rot = w, h, origin[0], origin[1], rot

    def _rot(self, x, y):
        if self.rot == 1:
            return self.h - y, x
        if self.rot == 2:
            return self.w - x, self.h - y
        if self.rot == 3:
            return y, self.w - x
        return x, y

    def pt(self, x, y, lv):
        px, py = self._rot(x, y)
        return (self.ox + (px - py) * TW / 2, self.oy + (px + py) * TH / 2 - lv * HS)

    def depth(self, x, y):
        px, py = self._rot(x + 0.5, y + 0.5)
        return px + py

    def front_dir(self, shade: bool):
        want = (1, 0) if shade else (0, 1)
        for d in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
            a = self._rot(1 + d[0], 1 + d[1])
            b = self._rot(1, 1)
            if (round(a[0] - b[0]), round(a[1] - b[1])) == want:
                return d
        return (0, 1)


def side(c, d):
    x, y = c
    if d[0] > 0:
        return (x + 1, y), (x + 1, y + 1)
    if d[0] < 0:
        return (x, y), (x, y + 1)
    if d[1] > 0:
        return (x, y + 1), (x + 1, y + 1)
    return (x, y), (x + 1, y)


# --- map rendering: blocking, line art, depth ------------------------------------------------

def nearness(x, y, lv):
    """Distance toward the camera (30 deg elevation, ortho). Bigger = nearer."""
    return 0.612 * (x + y) + 0.204 * lv


def map_faces(heights, terrain, iso: Iso, base=BASE):
    """Every visible polygon, back to front: (kind, terrain letter, screen pts, world pts)."""
    hgt = lambda c: heights[c[1]][c[0]]
    inb = lambda c: 0 <= c[0] < iso.w and 0 <= c[1] < iso.h
    cells = sorted(((x, y) for y in range(iso.h) for x in range(iso.w)), key=lambda c: iso.depth(*c))
    out = []
    for c in cells:
        t = terrain[c[1]][c[0]]
        lv = hgt(c)
        for shade in (False, True):
            d = iso.front_dir(shade)
            n = (c[0] + d[0], c[1] + d[1])
            nb = hgt(n) if inb(n) else base
            lo = max(base, min(nb, lv))
            if lo >= lv:
                continue
            a, b = side(c, d)
            world = [(a[0], a[1], lv), (b[0], b[1], lv), (b[0], b[1], lo), (a[0], a[1], lo)]
            out.append(("shade" if shade else "lit", t, [iso.pt(*w) for w in world], world))
        world = [(c[0], c[1], lv), (c[0] + 1, c[1], lv), (c[0] + 1, c[1] + 1, lv), (c[0], c[1] + 1, lv)]
        out.append(("top", t, [iso.pt(*w) for w in world], world))
        if t == "u":  # ruin: a pillar block RUIN_RISE levels tall on the middle of the cell
            lo_, hi_ = 0.25, 0.75
            for shade in (False, True):
                d = iso.front_dir(shade)
                a, b = side((0, 0), d)
                a = (c[0] + lo_ + (hi_ - lo_) * a[0], c[1] + lo_ + (hi_ - lo_) * a[1])
                b = (c[0] + lo_ + (hi_ - lo_) * b[0], c[1] + lo_ + (hi_ - lo_) * b[1])
                world = [(a[0], a[1], lv + RUIN_RISE), (b[0], b[1], lv + RUIN_RISE), (b[0], b[1], lv), (a[0], a[1], lv)]
                out.append(("shade" if shade else "lit", "u", [iso.pt(*w) for w in world], world))
            world = [(c[0] + lo_, c[1] + lo_, lv + RUIN_RISE), (c[0] + hi_, c[1] + lo_, lv + RUIN_RISE),
                     (c[0] + hi_, c[1] + hi_, lv + RUIN_RISE), (c[0] + lo_, c[1] + hi_, lv + RUIN_RISE)]
            out.append(("top", "u", [iso.pt(*w) for w in world], world))
    return out


def face_color(kind, t):
    if kind == "top":
        return rgb(TOP[t])
    if t == "w":
        return rgb("water_deep") if kind == "shade" else rgb("water")
    return rgb("stone_shade") if kind == "shade" else rgb("stone_lit")


def render_blocking(faces, size, iso: Iso):
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    for kind, t, pts, world in faces:
        dr.polygon(pts, fill=face_color(kind, t) + (255,))
        if kind != "top":
            # course lines every level, like the engine's laid stone
            lv_hi, lv_lo = world[0][2], world[3][2]
            a, b = world[0][:2], world[1][:2]
            line = tuple(int(v * 0.8) for v in face_color(kind, t)) + (255,)
            lv = math.floor(lv_hi) - 1
            while lv > lv_lo + 0.05:
                dr.line([iso.pt(a[0], a[1], lv), iso.pt(b[0], b[1], lv)], fill=line, width=2)
                lv -= 1
        elif t == "t":  # stairs: three treads across the cell
            for f in (0.25, 0.5, 0.75):
                l0 = lerp(pts[0], pts[3], f)
                l1 = lerp(pts[1], pts[2], f)
                dr.line([l0, l1], fill=rgb("stone_lit") + (255,), width=3)
        elif t == "f":  # forest marker: a pine silhouette
            cx = sum(p[0] for p in pts) / 4
            cy = sum(p[1] for p in pts) / 4
            dr.polygon([(cx - 22, cy + 6), (cx, cy - 70), (cx + 22, cy + 6)], fill=rgb("pine") + (255,))
        elif t == "r":
            cx = sum(p[0] for p in pts) / 4
            cy = sum(p[1] for p in pts) / 4
            dr.polygon([(cx - 30, cy + 8), (cx - 16, cy - 26), (cx + 12, cy - 34), (cx + 30, cy + 4)],
                       fill=rgb("stone_lit") + (255,))
    return im


def lerp(p, q, f):
    return (p[0] + (q[0] - p[0]) * f, p[1] + (q[1] - p[1]) * f)


def render_lines(faces, size, color=(0, 0, 0), bg=(255, 255, 255), width=3):
    """Hidden-line drawing: fill each face with the background, stroke its edges, back to front."""
    im = Image.new("RGB", size, bg)
    dr = ImageDraw.Draw(im)
    for kind, t, pts, world in faces:
        dr.polygon(pts, fill=bg)
        dr.line(pts + [pts[0]], fill=color, width=width, joint="curve")
    return im


def render_depth(faces, size):
    """Grayscale depth for a Depth control layer: white is nearest the camera."""
    w, h = size
    buf = np.full((h, w), -1e9, dtype=np.float64)
    for kind, t, pts, world in faces:
        mask = Image.new("L", size, 0)
        ImageDraw.Draw(mask).polygon(pts, fill=255)
        m = np.asarray(mask) > 0
        if not m.any():
            continue
        # Solve the face's plane: nearness is linear in screen x, y on a flat face.
        s = np.array([[p[0], p[1], 1.0] for p in pts[:3]])
        v = np.array([nearness(*wp) for wp in world[:3]])
        coef = np.linalg.solve(s, v) if abs(np.linalg.det(s)) > 1e-6 else np.array([0, 0, v.mean()])
        ys, xs = np.nonzero(m)
        buf[ys, xs] = coef[0] * xs + coef[1] * ys + coef[2]
    valid = buf > -1e8
    lo, hi = buf[valid].min(), buf[valid].max()
    out = np.zeros((h, w), dtype=np.uint8)
    out[valid] = (40 + 215 * (buf[valid] - lo) / max(hi - lo, 1e-6)).astype(np.uint8)
    return Image.fromarray(out, "L")


def grid_layer(iso: Iso, size, lv=0.0, color=INK, alpha=110, width=2, every=0):
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    for x in range(iso.w + 1):
        wdt = width + (1 if every and x % every == 0 else 0)
        dr.line([iso.pt(x, 0, lv), iso.pt(x, iso.h, lv)], fill=color + (alpha,), width=wdt)
    for y in range(iso.h + 1):
        wdt = width + (1 if every and y % every == 0 else 0)
        dr.line([iso.pt(0, y, lv), iso.pt(iso.w, y, lv)], fill=color + (alpha,), width=wdt)
    return im


def fit_origin(heights, w, h, rot=0):
    """Center a map on the fixed canvas (bounding box of every corner from BASE to top + ruin)."""
    iso = Iso(w, h, (0, 0), rot)
    top = max(max(r) for r in heights) + RUIN_RISE
    xs, ys = [], []
    for x in (0, w):
        for y in (0, h):
            for lv in (BASE, top):
                px, py = iso.pt(x, y, lv)
                xs.append(px)
                ys.append(py)
    cx = (min(xs) + max(xs)) / 2
    cy = (min(ys) + max(ys)) / 2
    return (CANVAS[0] / 2 - cx, CANVAS[1] / 2 - cy)


def paper(size):
    return Image.new("RGBA", size, PAPER + (255,))


def label_layer(iso: Iso, size, heights=None):
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    f = font(18)
    for y in range(iso.h):
        for x in range(iso.w):
            lv = heights[y][x] if heights else 0
            px, py = iso.pt(x + 0.5, y + 0.5, lv)
            txt = f"{x},{y}" + (f" h{lv}" if heights else "")
            dr.text((px, py), txt, fill=INK + (200,), font=f, anchor="mm")
    return im


def column_guides(iso: Iso, size):
    """Vertical lines through every grid corner column: cut big drawings along these into per-cell slices."""
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    xs = sorted({round(iso.pt(x, y, 0)[0]) for x in range(iso.w + 1) for y in range(iso.h + 1)})
    for i, x in enumerate(xs):
        if i % 2 == 0:
            dr.line([(x, 0), (x, size[1])], fill=(200, 60, 120, 70), width=1)
    return im


def height_ruler(iso: Iso, size, top=8):
    """Level ticks up the left, front and right corners so heights can be eyeballed."""
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    f = font(16)
    for corner in [(0, iso.h), (iso.w, iso.h), (iso.w, 0)]:
        x0, y0 = iso.pt(corner[0], corner[1], BASE)
        x1, y1 = iso.pt(corner[0], corner[1], top)
        dr.line([(x0, y0), (x1, y1)], fill=(60, 110, 170, 160), width=2)
        for lv in range(int(BASE), top + 1):
            x, y = iso.pt(corner[0], corner[1], lv)
            dr.line([(x - 10, y), (x + 10, y)], fill=(60, 110, 170, 200), width=2)
            dr.text((x + 14, y), str(lv), fill=(60, 110, 170, 230), font=f, anchor="lm")
    return im


def save_psd(path: Path, size, layers):
    """layers: list of (name, RGBA image, visible). Bottom first."""
    from psd_tools import PSDImage
    from psd_tools.api.layers import PixelLayer
    from psd_tools.constants import Compression

    # The composite preview is stored compressed; PSDImage.new would store it raw (15 MB per file).
    comp = Image.new("RGBA", size, (0, 0, 0, 0))
    for _, img, visible in layers:
        if visible:
            comp.alpha_composite(img.convert("RGBA"))
    psd = PSDImage.frompil(comp.convert("RGB"))
    for name, img, visible in layers:
        layer = PixelLayer.frompil(img.convert("RGBA"), psd, name, compression=Compression.ZIP)
        layer.visible = visible
        psd.append(layer)
    psd.save(str(path))
    save_ora(path.with_suffix(".ora"), size, layers, comp)


def save_ora(path: Path, size, layers, comp):
    """OpenRaster: Krita's own layered exchange format, as a fallback if a PSD reader balks."""
    import io
    import zipfile
    from xml.sax.saxutils import quoteattr

    def png(img):
        b = io.BytesIO()
        img.save(b, "PNG", optimize=True)
        return b.getvalue()

    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr(zipfile.ZipInfo("mimetype"), "image/openraster", compress_type=zipfile.ZIP_STORED)
        stack = [f'<image w="{size[0]}" h="{size[1]}" version="0.0.3"><stack>']
        for i, (name, img, visible) in reversed(list(enumerate(layers))):
            src = f"data/layer{i:02d}.png"
            z.writestr(src, png(img.convert("RGBA")))
            vis = "visible" if visible else "hidden"
            stack.append(f'<layer name={quoteattr(name)} src="{src}" x="0" y="0" opacity="1.0" visibility="{vis}"/>')
        stack.append("</stack></image>")
        z.writestr("stack.xml", "".join(stack))
        z.writestr("mergedimage.png", png(comp.convert("RGB")))
        thumb = comp.convert("RGB")
        thumb.thumbnail((256, 256))
        z.writestr("Thumbnails/thumbnail.png", png(thumb))


def empty(size):
    return Image.new("RGBA", size, (0, 0, 0, 0))


# --- blank drawing template ------------------------------------------------------------------

def blank_template():
    n = 16
    flat = [[0] * n for _ in range(n)]
    iso = Iso(n, n, fit_origin([[6] * n], n, n))
    size = CANVAS
    layers = [
        ("paper", paper(size), True),
        ("GUIDE level 6 grid", grid_layer(iso, size, 6, color=(170, 90, 60), alpha=70), False),
        ("GUIDE level 4 grid", grid_layer(iso, size, 4, color=(170, 90, 60), alpha=70), False),
        ("GUIDE level 2 grid", grid_layer(iso, size, 2, color=(170, 90, 60), alpha=70), False),
        ("GUIDE ground grid h0", grid_layer(iso, size, 0, every=4), True),
        ("GUIDE height rulers", height_ruler(iso, size), True),
        ("GUIDE slice columns", column_guides(iso, size), False),
        ("GUIDE cell labels", label_layer(iso, size), False),
        ("paint 1 cliffs and sides", empty(size), True),
        ("paint 2 tops", empty(size), True),
        ("paint 3 props", empty(size), True),
        ("paint 4 water and fx", empty(size), True),
        ("paint 5 foreground occluders", empty(size), True),
    ]
    save_psd(TEMPLATES / "blank-16x16.psd", size, layers)
    flat_png = paper(size)
    for name, img, vis in layers[4:6]:
        flat_png.alpha_composite(img)
    flat_png.convert("RGB").save(TEMPLATES / "blank-16x16.png")


# --- per-map templates -----------------------------------------------------------------------

def map_template(path: Path):
    data = json.loads(path.read_text())
    m = data["map"]
    w, h = m["w"], m["h"]
    heights = [[int(ch) for ch in row] for row in m["heights"]]
    terrain = m["terrain"]
    rot = int(data.get("view", 0))
    iso = Iso(w, h, fit_origin(heights, w, h, rot), rot)
    faces = map_faces(heights, terrain, iso)
    size = CANVAS
    blocking = render_blocking(faces, size, iso)
    lines = render_lines(faces, size)
    depth = render_depth(faces, size)
    line_rgba = lines.convert("L").point(lambda v: 255 - v)
    line_layer = Image.new("RGBA", size, INK + (0,))
    line_layer.putalpha(line_rgba)
    name = path.stem
    out = TEMPLATES / "maps" / name
    out.mkdir(parents=True, exist_ok=True)
    layers = [
        ("paper", paper(size), True),
        ("CONTROL depth (white = near)", depth.convert("RGBA"), False),
        ("CONTROL blocking (flat colors)", blocking, True),
        ("CONTROL line art", line_layer, True),
        ("GUIDE ground grid on tops", top_grid(heights, iso, size), True),
        ("GUIDE slice columns", column_guides(iso, size), False),
        ("GUIDE cell labels with height", label_layer(iso, size, heights), False),
        ("paint 1 cliffs and sides", empty(size), True),
        ("paint 2 tops", empty(size), True),
        ("paint 3 props", empty(size), True),
        ("paint 4 water and fx", empty(size), True),
        ("paint 5 foreground occluders", empty(size), True),
    ]
    save_psd(out / f"{name}.psd", size, layers)
    # Separate PNGs for Krita AI Diffusion control layers.
    lines.save(out / "control-lineart.png")
    depth.save(out / "control-depth.png")
    flat = paper(size)
    flat.alpha_composite(blocking)
    flat.convert("RGB").save(out / "control-blocking.png")
    flat.alpha_composite(line_layer)
    flat.convert("RGB").save(out / "preview.png")
    return out / "preview.png"


def top_grid(heights, iso: Iso, size):
    """Each cell's own diamond at its own height, so the grid sits on the terrain like in the game."""
    im = Image.new("RGBA", size, (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    for y in range(iso.h):
        for x in range(iso.w):
            lv = heights[y][x]
            pts = [iso.pt(x, y, lv), iso.pt(x + 1, y, lv), iso.pt(x + 1, y + 1, lv), iso.pt(x, y + 1, lv)]
            dr.line(pts + [pts[0]], fill=INK + (60,), width=1)
    return im


# --- tile kit sheet --------------------------------------------------------------------------

KIT_CELL = (256, 320)  # one slot: a single cell block, 2 levels of side, room above for a prop
KIT_COLS = 8
KIT_FOOT = (128, 224)  # the cell's top-centre (pivot) inside a slot, at height 2
KIT_ROWS = [
    ("tops", ["g", "g", "f", "d", "s", "t", "r", "w"]),
    ("tops variants", ["g", "g", "g", "d", "s", "s", "f", "w"]),
    ("props (stand on the pivot)", ["u", "u", "f", "f", "r", "r", "s", "s"]),
]


def kit_sheet():
    cols, rows = KIT_COLS, len(KIT_ROWS)
    size = (KIT_CELL[0] * cols, KIT_CELL[1] * rows)
    blocking = Image.new("RGBA", size, (0, 0, 0, 0))
    lines = Image.new("RGB", size, (255, 255, 255))
    mask = Image.new("RGBA", size, (0, 0, 0, 0))
    guides = Image.new("RGBA", size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(guides)
    f = font(16)
    depth = Image.new("L", size, 0)
    for r, (row_name, ts) in enumerate(KIT_ROWS):
        for i, t in enumerate(ts):
            ox = i * KIT_CELL[0] + KIT_FOOT[0]
            oy = r * KIT_CELL[1] + KIT_FOOT[1]
            iso = Iso(1, 1, (0, 0))
            # pivot = top-centre of a height-2 cell
            cx, cy = iso.pt(0.5, 0.5, 2)
            iso = Iso(1, 1, (ox - cx, oy - cy))
            terrain = [t if r != 2 else ("u" if t == "u" else "g")]
            faces = map_faces([[2]], [terrain[0]], iso, base=0)
            b = render_blocking(faces, size, iso)
            blocking.alpha_composite(b)
            mask.alpha_composite(Image.merge("RGBA", (*Image.new("RGB", size, (255, 255, 255)).split(), b.split()[3])))
            ln = render_lines(faces, size)
            lines = Image.fromarray(np.minimum(np.asarray(lines), np.asarray(ln)))
            d = render_depth(faces, size)
            depth = Image.fromarray(np.maximum(np.asarray(depth), np.asarray(d)))
            x0, y0 = i * KIT_CELL[0], r * KIT_CELL[1]
            gd.rectangle([x0, y0, x0 + KIT_CELL[0] - 1, y0 + KIT_CELL[1] - 1], outline=(60, 110, 170, 120), width=1)
            gd.ellipse([ox - 4, oy - 4, ox + 4, oy + 4], fill=(200, 60, 120, 230))
            gd.text((x0 + 6, y0 + 4), f"r{r} c{i}  {t}" + (f"  {row_name}" if i == 0 else ""), fill=(60, 110, 170, 220), font=f)
            if r == 2:  # prop room: everything above the pivot inside the slot
                gd.rectangle([ox - 64, y0 + 8, ox + 64, oy], outline=(200, 60, 120, 120), width=1)
    line_layer = Image.new("RGBA", size, INK + (0,))
    line_layer.putalpha(lines.convert("L").point(lambda v: 255 - v))
    layers = [
        ("paper", paper(size), True),
        ("CONTROL depth (white = near)", depth.convert("RGBA"), False),
        ("MASK shapes (clip paint to this)", mask, False),
        ("CONTROL blocking (flat colors)", blocking, True),
        ("CONTROL line art", line_layer, True),
        ("GUIDE slots and pivots", guides, True),
        ("paint 1 sides", empty(size), True),
        ("paint 2 tops", empty(size), True),
        ("paint 3 props", empty(size), True),
    ]
    out = TEMPLATES / "kit"
    out.mkdir(parents=True, exist_ok=True)
    save_psd(out / "tile-kit-sheet.psd", size, layers)
    lines.save(out / "control-lineart.png")
    depth.save(out / "control-depth.png")
    flat = paper(size)
    flat.alpha_composite(blocking)
    flat.convert("RGB").save(out / "control-blocking.png")
    flat.alpha_composite(line_layer)
    flat.alpha_composite(guides)
    flat.convert("RGB").save(out / "preview.png")


# --- diagrams --------------------------------------------------------------------------------

def arrow(dr, a, b, col, w=3):
    dr.line([a, b], fill=col, width=w)
    ang = math.atan2(b[1] - a[1], b[0] - a[0])
    for s in (-0.45, 0.45):
        dr.line([b, (b[0] - 14 * math.cos(ang + s), b[1] - 14 * math.sin(ang + s))], fill=col, width=w)


def dim(dr, a, b, text, f, col=(60, 110, 170), off=(0, 0)):
    dr.line([a, b], fill=col, width=2)
    for p in (a, b):
        dr.ellipse([p[0] - 4, p[1] - 4, p[0] + 4, p[1] + 4], fill=col)
    mx, my = (a[0] + b[0]) / 2 + off[0], (a[1] + b[1]) / 2 + off[1]
    dr.text((mx, my), text, fill=col, font=f, anchor="mm")


def diagram_projection():
    size = (1600, 1000)
    im = paper(size)
    dr = ImageDraw.Draw(im)
    big, mid, small = font(44, True), font(26), font(21)
    dr.text((60, 40), "Projection: 2:1 dimetric (pixel-art isometric)", fill=INK, font=big)
    # left: world square grid seen from above
    ox, oy, s = 120, 200, 70
    dr.text((ox, oy - 50), "World: square 1:1 grid", fill=INK, font=mid)
    for i in range(5):
        dr.line([(ox, oy + i * s), (ox + 4 * s, oy + i * s)], fill=INK, width=2)
        dr.line([(ox + i * s, oy), (ox + i * s, oy + 4 * s)], fill=INK, width=2)
    dr.text((ox, oy + 4 * s + 20), "turn it 45 degrees,", fill=INK, font=small)
    dr.text((ox, oy + 4 * s + 48), "look down from 30 degrees,", fill=INK, font=small)
    dr.text((ox, oy + 4 * s + 76), "(orthographic, 2:1 on screen)", fill=INK, font=small)
    arrow(dr, (450, 340), (560, 340), INK, 4)
    # middle: screen diamond grid
    iso = Iso(4, 4, (820, 210))
    dr.text((640, 160), "Screen: every tile is a 2:1 diamond", fill=INK, font=mid)
    for x in range(5):
        dr.line([iso.pt(x, 0, 0), iso.pt(x, 4, 0)], fill=INK, width=2)
    for y in range(5):
        dr.line([iso.pt(0, y, 0), iso.pt(4, y, 0)], fill=INK, width=2)
    t = [iso.pt(1, 1, 0), iso.pt(2, 1, 0), iso.pt(2, 2, 0), iso.pt(1, 2, 0)]
    dr.polygon(t, fill=rgb("grass_light"), outline=INK)
    left, right = iso.pt(1, 2, 0), iso.pt(2, 1, 0)
    top_, bot = iso.pt(1, 1, 0), iso.pt(2, 2, 0)
    dr.line([(t[3][0], t[1][1] - 52), (t[1][0], t[1][1] - 52)], fill=(60, 110, 170), width=2)
    dr.text(((t[3][0] + t[1][0]) / 2, t[1][1] - 72), "128 px wide", fill=(60, 110, 170), font=small, anchor="mm")
    dr.line([(t[1][0] + 20, t[0][1]), (t[1][0] + 20, t[2][1])], fill=(60, 110, 170), width=2)
    dr.text((t[1][0] + 28, t[1][1]), "64 px tall", fill=(60, 110, 170), font=small, anchor="lm")
    # right: the 26.565 degree line and the 2-across-1-down pixel step
    bx, by = 1180, 260
    dr.text((bx, 160), "Grid lines: 26.565 degrees", fill=INK, font=mid)
    dr.line([(bx, by + 200), (bx + 360, by + 20)], fill=INK, width=3)
    dr.line([(bx, by + 200), (bx + 360, by + 200)], fill=(150, 150, 150), width=2)
    dr.arc([bx - 120, by + 80, bx + 120, by + 320], 333, 360, fill=(60, 110, 170), width=3)
    dr.text((bx + 130, by + 175), "26.565", fill=(60, 110, 170), font=small, anchor="lm")
    # pixel stair
    px, py, c = bx + 20, by + 300, 18
    dr.text((bx, py - 20), "pixel step: 2 across, 1 down", fill=INK, font=small)
    for k in range(8):
        dr.rectangle([px + k * 2 * c, py + 40 + (7 - k) * c, px + k * 2 * c + 2 * c - 1, py + 40 + (7 - k) * c + c - 1],
                     fill=INK)
    # bottom notes
    notes = [
        "NOT true isometric: true iso lines are 30 degrees and the diamond is 1.73:1. Use 2:1.",
        "Orthographic: no perspective, no vanishing point. Parallel lines stay parallel everywhere on the map.",
        "Height: 1 level = 32 px straight up (half a tile height). A full cube block = 2 levels = 64 px.",
    ]
    for i, n in enumerate(notes):
        dr.text((60, 820 + i * 44), n, fill=INK, font=mid)
    im.convert("RGB").save(DOCS / "01-projection.png")


def shade_cube(dr, iso: Iso, lv_lo, lv_hi, top_col, lit_col, shade_col, outline=True):
    f_lit = [iso.pt(0, 1, lv_hi), iso.pt(1, 1, lv_hi), iso.pt(1, 1, lv_lo), iso.pt(0, 1, lv_lo)]
    f_sh = [iso.pt(1, 0, lv_hi), iso.pt(1, 1, lv_hi), iso.pt(1, 1, lv_lo), iso.pt(1, 0, lv_lo)]
    f_top = [iso.pt(0, 0, lv_hi), iso.pt(1, 0, lv_hi), iso.pt(1, 1, lv_hi), iso.pt(0, 1, lv_hi)]
    for poly, col in ((f_lit, lit_col), (f_sh, shade_col), (f_top, top_col)):
        dr.polygon(poly, fill=col, outline=INK if outline else None, width=3 if outline else 0)
    return f_top, f_lit, f_sh


def diagram_anatomy():
    size = (1600, 1100)
    im = paper(size)
    dr = ImageDraw.Draw(im)
    big, mid, small = font(44, True), font(26), font(21)
    dr.text((60, 40), "Tile anatomy at art size (2x engine)", fill=INK, font=big)
    dr.text((60, 100), "Diagram drawn at 2x so labels fit; numbers are real art pixels.", fill=INK, font=small)
    S = 2  # draw the diagram itself at 2x art size so labels fit
    iso = Iso(1, 1, (520, 330))
    # scale the iso up for legibility
    big_iso = Iso(1, 1, (520, 330))
    big_iso.pt = lambda x, y, lv: (520 + (x - y) * TW / 2 * S, 330 + (x + y) * TH / 2 * S - lv * HS * S)
    f_top, f_lit, f_sh = shade_cube(dr, big_iso, -2, 0, rgb("grass_light"), rgb("stone_lit"), rgb("stone_shade"))
    # course line at -1
    dr.line([big_iso.pt(0, 1, -1), big_iso.pt(1, 1, -1)], fill=INK, width=2)
    dr.line([big_iso.pt(1, 0, -1), big_iso.pt(1, 1, -1)], fill=INK, width=2)
    # moss lip drape
    lip = [big_iso.pt(0, 1, 0), big_iso.pt(1, 1, 0), big_iso.pt(1, 0, 0)]
    for k in range(len(lip) - 1):
        a, b = lip[k], lip[k + 1]
        n = 7
        pts = [a]
        for j in range(1, n + 1):
            p = lerp(a, b, j / (n + 1))
            pts.append((p[0], p[1] + (22 if j % 2 else 10)))
        pts.append(b)
        dr.polygon(pts + [b, a], fill=rgb("moss"), outline=INK, width=2)
    piv = big_iso.pt(0.5, 0.5, 0)
    dr.ellipse([piv[0] - 8, piv[1] - 8, piv[0] + 8, piv[1] + 8], fill=(200, 60, 120))
    blue = (60, 110, 170)
    # labels
    l, r = big_iso.pt(0, 1, 0), big_iso.pt(1, 0, 0)
    t_, b_ = big_iso.pt(0, 0, 0), big_iso.pt(1, 1, 0)
    dr.line([(l[0], t_[1] - 40), (r[0], t_[1] - 40)], fill=blue, width=2)
    dr.text(((l[0] + r[0]) / 2, t_[1] - 62), "top: 128 x 64 diamond", fill=blue, font=mid, anchor="mm")
    dr.line([(r[0] + 40, t_[1]), (r[0] + 40, b_[1])], fill=blue, width=2)
    dr.text((r[0] + 52, (t_[1] + b_[1]) / 2), "64", fill=blue, font=mid, anchor="lm")
    lo = big_iso.pt(1, 0, -2)
    dr.line([(r[0] + 40, r[1]), (r[0] + 40, lo[1])], fill=blue, width=2)
    ll = big_iso.pt(0, 1, 0)
    dr.line([(ll[0] - 30, ll[1]), (ll[0] - 30, big_iso.pt(0, 1, -2)[1])], fill=blue, width=2)
    dr.text((ll[0] - 40, ll[1] + 64), "2 levels =\n64 px of side\n(32 px a level)", fill=blue, font=small, anchor="ra")
    dr.text((140, 650), "Pink dot = pivot: the top centre of the cell. Every sprite is placed by it.", fill=(200, 60, 120), font=small)
    a = big_iso.pt(0.25, 1, -1.2)
    dr.text((a[0] + 40, a[1] + 10), "LIT", fill=INK, font=mid, anchor="mm")
    a = big_iso.pt(1, 0.6, -1.2)
    dr.text((a[0] - 10, a[1] + 10), "SHADE", fill=(240, 240, 230), font=mid, anchor="mm")
    dr.text((140, 700), "LIT face looks to the lower-left, SHADE face to the lower-right,\nwhatever way the camera is turned.", fill=INK, font=small)
    dr.text((r[0] + 70, lo[1] + 10), "moss lip: drapes 8-24 px\nover the edge, painted\nwith the TOP sprite", fill=INK, font=small, anchor="la")
    # sprite list on the right
    x0 = 960
    rows = [
        ("top sprite", "128 x 96 PNG, diamond in the top 64 px,"),
        ("", "lip may hang into the lower 32 px"),
        ("lit side strip", "64 x 96 PNG, tiles vertically every 64 px"),
        ("shade side strip", "64 x 96 PNG, same, mirrored geometry"),
        ("prop", "128 x 256 PNG, feet on the pivot at (64, 224)"),
        ("waterfall strip", "64 x 128 PNG, seamless top to bottom"),
    ]
    dr.text((x0, 150), "Sprites the engine needs", fill=INK, font=mid)
    for i, (k, v) in enumerate(rows):
        dr.text((x0, 200 + i * 38), k, fill=(200, 60, 120), font=small)
        dr.text((x0 + 170, 200 + i * 38), v, fill=INK, font=small)
    notes = [
        "Faces you never draw: the back two sides and the bottom. The camera never shows them.",
        "The side strip is cropped from the TOP down to the neighbour's height, so keep the moss and the best detail at the top.",
        "Outline: 3 px on the outer silhouette, 2 px on inner edges, colour #373335 (never black).",
    ]
    for i, n in enumerate(notes):
        dr.text((60, 930 + i * 44), n, fill=INK, font=mid)
    im.convert("RGB").save(DOCS / "02-tile-anatomy.png")


def diagram_light():
    size = (1600, 1000)
    im = paper(size)
    dr = ImageDraw.Draw(im)
    big, mid, small = font(44, True), font(26), font(21)
    dr.text((60, 40), "Light, value and palette", fill=INK, font=big)
    big_iso = Iso(1, 1)
    big_iso.pt = lambda x, y, lv: (330 + (x - y) * 140, 300 + (x + y) * 70 - lv * 70)
    shade_cube(dr, big_iso, -2, 0, rgb("stone_top"), rgb("stone_lit"), rgb("stone_shade"))
    arrow(dr, (90, 150), (230, 260), (220, 150, 40), 5)
    dr.text((80, 120), "sun: upper left, fixed", fill=(180, 120, 30), font=small)
    t = big_iso.pt(0.5, 0.5, 0)
    dr.text(t, "TOP 100%", fill=INK, font=mid, anchor="mm")
    t = big_iso.pt(0.15, 1, -1)
    dr.text((t[0] + 40, t[1] + 30), "LIT 75%", fill=INK, font=mid, anchor="mm")
    t = big_iso.pt(1, 0.55, -1)
    dr.text((t[0] - 15, t[1] + 30), "SHADE 55%", fill=(240, 240, 230), font=mid, anchor="mm")
    dr.text((140, 640), "Values relative to the top face.\nSame for every material, every region.", fill=INK, font=small)
    groups = [
        ("ground", ["paper", "grass_light", "grass", "moss", "moss_dark", "pine", "path"]),
        ("stone", ["stone_top", "stone_mid", "stone_pale", "stone_lit", "stone_shade", "stone_deep", "ink"]),
        ("water", ["glint", "foam", "water", "water_deep"]),
    ]
    x0, y0 = 720, 140
    for g, names in groups:
        dr.text((x0, y0), g, fill=INK, font=mid)
        y0 += 40
        for i, n in enumerate(names):
            x = x0 + i * 120
            dr.rectangle([x, y0, x + 104, y0 + 80], fill=rgb(n), outline=INK, width=2)
            dr.text((x, y0 + 88), n.replace("_", " "), fill=INK, font=font(17))
            dr.text((x, y0 + 110), P[n], fill=INK, font=font(17))
        y0 += 160
    notes = [
        "Blue and red stay out of terrain (only water may be blue): they belong to team rings and move / attack highlights.",
        "Tops are the brightest thing on the map so highlights read on them; props and pieces must not out-shout them.",
        "Shadows are cool (push toward #727877), lights are warm (push toward #d8cb97). Never pure gray, never black.",
    ]
    for i, n in enumerate(notes):
        dr.text((60, 820 + i * 44), n, fill=INK, font=mid)
    im.convert("RGB").save(DOCS / "03-light-and-palette.png")


def diagram_sort():
    size = (1600, 1000)
    im = paper(size)
    dr = ImageDraw.Draw(im)
    big, mid, small = font(44, True), font(26), font(21)
    dr.text((60, 40), "Draw order and big structures", fill=INK, font=big)
    iso = Iso(5, 5, (420, 200))
    f = font(24)
    for y in range(5):
        for x in range(5):
            pts = [iso.pt(x, y, 0), iso.pt(x + 1, y, 0), iso.pt(x + 1, y + 1, 0), iso.pt(x, y + 1, 0)]
            v = 255 - (x + y) * 18
            dr.polygon(pts, fill=(v, v, int(v * 0.95)), outline=INK, width=2)
            c = iso.pt(x + 0.5, y + 0.5, 0)
            dr.text(c, str(x + y), fill=INK, font=f, anchor="mm")
    dr.text((90, 560), "Depth = x + y. Lower numbers draw first.\nEverything on a cell (block, prop, piece)\ndraws with that cell's depth.", fill=INK, font=mid)
    # big structure sliced into columns
    iso2 = Iso(3, 2, (1180, 330))
    dr.text((900, 130), "A 3x2 temple: draw it whole, then cut it", fill=INK, font=mid)
    shade = iso2
    # simple block
    lo, hi = 0, 4
    f_lit = [iso2.pt(0, 2, hi), iso2.pt(3, 2, hi), iso2.pt(3, 2, lo), iso2.pt(0, 2, lo)]
    f_sh = [iso2.pt(3, 0, hi), iso2.pt(3, 2, hi), iso2.pt(3, 2, lo), iso2.pt(3, 0, lo)]
    f_top = [iso2.pt(0, 0, hi), iso2.pt(3, 0, hi), iso2.pt(3, 2, hi), iso2.pt(0, 2, hi)]
    dr.polygon(f_lit, fill=rgb("stone_lit"), outline=INK, width=3)
    dr.polygon(f_sh, fill=rgb("stone_shade"), outline=INK, width=3)
    dr.polygon(f_top, fill=rgb("stone_top"), outline=INK, width=3)
    xs = sorted({round(iso2.pt(x, y, 0)[0]) for x in range(4) for y in range(3)})
    for x in xs:
        dr.line([(x, 180), (x, 620)], fill=(200, 60, 120), width=2)
    dr.text((900, 680), "Cut along the pink columns (every 64 px, through grid\ncorners). Each slice belongs to the cell whose front\ncorner it contains and sorts with that cell, so pieces\nwalk in front of and behind it correctly.", fill=INK, font=small)
    notes = [
        "Turn (Q) rotates the camera in 90 degree steps. Tops must read the same in all 4 turns: no arrows, no one-way slopes.",
        "Props get a FRONT view and a SIDE view; the engine mirrors them for the other two turns. Stairs need both views too.",
        "Anything that hangs in front of a piece (arches, branches) goes on the foreground occluder layer and fades when a piece is behind it.",
    ]
    for i, n in enumerate(notes):
        dr.text((60, 840 + i * 44), n, fill=INK, font=mid)
    im.convert("RGB").save(DOCS / "04-draw-order.png")


def main():
    DOCS.mkdir(parents=True, exist_ok=True)
    TEMPLATES.mkdir(parents=True, exist_ok=True)
    diagram_projection()
    diagram_anatomy()
    diagram_light()
    diagram_sort()
    blank_template()
    kit_sheet()
    for p in sorted(MAPS.glob("*.json")):
        map_template(p)
    print("wrote", DOCS.relative_to(ROOT), "and", TEMPLATES.relative_to(ROOT))


if __name__ == "__main__":
    main()
