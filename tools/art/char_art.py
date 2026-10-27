#!/usr/bin/env python3
"""Character sprite kit: frame spec, Krita templates, image-gen control images and the exporter.

Same camera as the battle maps (tools/art/battle_art.py, docs/art/battle-maps.md): 2:1 dimetric,
art at 2x the engine (tile 128 x 64, 32 px per level). A piece's feet sit on the centre of its
footprint, so every frame drops onto the board with one fixed offset.

    python3 tools/art/char_art.py                         # templates, diagrams, palette, layout.json
    python3 tools/art/char_art.py export FILE --id ID     # painted sheet / model / parts file -> game sprites
    python3 tools/art/char_art.py pack DIR --id ID        # Krita animation render (ID_anim_dir_0000.png) -> strips
    python3 tools/art/char_art.py lock IN.png [OUT.png]   # snap colours to the character palette
    python3 tools/art/char_art.py import PIC.png --id ID  # Picsart picture (3:2 sheet or 1:1 view) -> model.ora + frames
    python3 tools/art/char_art.py guide                   # rebuild docs/context/artifacts/character-guide.html

Needs Pillow, numpy and psd-tools (pip install pillow numpy psd-tools).
See docs/art/characters.md for the rules these files encode.
"""
from __future__ import annotations

import argparse
import io
import json
import math
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from battle_art import HS, INK, PAPER, TW, font, paper, save_psd  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / "docs/art/characters"
TEMPLATES = ROOT / "art/templates/characters"
GAME = ROOT / "game/art/source/characters"

# --- camera (same as the board) -------------------------------------------------------------
# World: x and y are grid axes (1 = one cell), z is up. Screen: +x runs down-right, +y down-left.
SQ2 = math.sqrt(2.0)
K = TW / SQ2  # art px per world unit across the ground (90.5)
R = np.array([1.0, -1.0, 0.0]) / SQ2  # screen right
U = np.array([-0.5 / SQ2, -0.5 / SQ2, math.sqrt(3) / 2])  # screen up
F = np.array([math.sqrt(3) / 2 / SQ2, math.sqrt(3) / 2 / SQ2, 0.5])  # toward the camera
LEVEL_UNITS = HS / (K * U[2])  # one height level (32 px) in world units

# Eight facings, named by where the piece looks on screen. Grid moves are the diagonals.
DIRS = {"s": (1, 1), "se": (1, 0), "e": (1, -1), "ne": (0, -1),
        "n": (-1, -1), "nw": (-1, 0), "w": (-1, 1), "sw": (0, 1)}
DRAWN = ["s", "se", "e", "ne", "n"]
MIRROR = {"sw": "se", "w": "e", "nw": "ne"}  # drawn later only for lopsided pieces
FRONT_DIRS = {"s", "se", "e", "sw", "w"}  # which part stack order a facing uses

PINK = (200, 60, 120)
BLUE = (60, 110, 170)
CELL = 192  # frame side per footprint cell
SLOT = 768  # model sheet slot (image-gen size)

# --- palette: Brandon's sheet swatches as key ramps (light, mid, dark) ----------------------
# The engine recolours a piece by swapping these exact keys, so paint (or lock) to them.
RAMPS = {
    "cloth_a": ("#9cbe9b", "#6c8f74", "#4f6b5a"),  # cloak
    "cloth_b": ("#5da9cb", "#448caa", "#356b86"),  # tunic
    "cloth_c": ("#e2ead9", "#bfd3d6", "#97aab0"),  # shirt
    "trousers": ("#7a8783", "#556260", "#3f4749"),
    "leather": ("#b89f83", "#827262", "#5f5349"),
    "hair": ("#a88b72", "#876d59", "#64503f"),
    "skin": ("#f6e2cc", "#eed0b4", "#d3a98c"),
    "metal": ("#dfe5e1", "#b4c3c4", "#88979b"),
    "accent_r": ("#df9178", "#cc6d55", "#a14f3f"),
    "accent_y": ("#e8d49c", "#d7bd78", "#ad9458"),
}
FIXED = {"ink": "#373335", "glint": "#f2f1e2"}


def hexrgb(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def palette_colors() -> list[tuple[str, tuple]]:
    out = [(f"{k} {lvl}", hexrgb(c)) for k, ramp in RAMPS.items() for lvl, c in zip(("light", "mid", "dark"), ramp)]
    return out + [(k, hexrgb(c)) for k, c in FIXED.items()]


# --- size classes, animations and sheet rows ------------------------------------------------
ANIMS = {  # frames, fps, loop, hit frame (-1 none)
    "hero": {"idle": (4, 6, True, -1), "walk": (6, 10, True, -1), "attack": (6, 12, False, 3),
             "cast": (6, 10, False, 4), "hurt": (2, 8, False, -1), "down": (2, 6, False, -1)},
    "small": {"idle": (4, 6, True, -1), "walk": (6, 12, True, -1), "attack": (6, 12, False, 3),
              "hurt": (2, 8, False, -1), "down": (2, 6, False, -1)},
    "large": {"idle": (4, 5, True, -1), "walk": (6, 8, True, -1), "attack": (6, 10, False, 3),
              "hurt": (2, 8, False, -1), "down": (2, 6, False, -1)},
    "boss": {"idle": (4, 5, True, -1), "move": (4, 6, True, -1), "attack": (6, 10, False, 3),
             "special": (6, 8, False, 4), "hurt": (2, 8, False, -1), "down": (4, 6, False, -1)},
}
CLASSES = {
    # cells: footprint side. band: target height in levels to the top of the head.
    # model: model-sheet pixels per sprite pixel (sized so the footprint fills about 2/3 of a slot).
    "hero": {"cells": 1, "cols": 8, "band": 3, "body": "biped", "model": 4, "roam": True},
    "small": {"cells": 1, "cols": 8, "band": 1.5, "body": "critter", "model": 5, "roam": True},
    "large": {"cells": 2, "cols": 6, "band": 4, "body": "beast", "model": 2, "roam": True},
    "boss": {"cells": 3, "cols": 6, "band": 7, "body": "giant", "model": 4 / 3, "roam": False},
}


def frame_of(cls: str) -> int:
    return CELL * CLASSES[cls]["cells"]


def anchor_of(cls: str) -> tuple[int, int]:
    n = CLASSES[cls]["cells"]
    return 96 * n, 160 * n


def sheet_rows(cls: str) -> list[list[tuple[str, str, int]]]:
    """Each row is a list of (anim, dir, frames) segments laid left to right."""
    c = CLASSES[cls]
    anims = ANIMS[cls]
    turn = list(DIRS) if c["cols"] >= 8 else DRAWN
    rows = [[("stand", d, 1) for d in turn]]
    for d in ("se", "ne"):
        for a, (n, *_rest) in anims.items():
            if a in ("hurt", "down"):
                continue
            rows.append([(a, d, n)])
        rows.append([("hurt", d, anims["hurt"][0]), ("down", d, anims["down"][0])])
    if c["roam"]:
        for d in ("s", "e", "n"):
            rows.append([("walk", d, anims["walk"][0])])
    return rows


# --- mannequins: ellipsoids in a piece's own frame (forward, left, up), world units ----------
def _pair(part, f, s, u, rf, rs, ru, col):
    return [(part, (f, s, u), (rf, rs, ru), col), (part, (f, -s, u), (rf, rs, ru), col)]


C_SKIN, C_HAIR, C_CLOTH, C_SHIRT = "#eed0b4", "#876d59", "#448caa", "#bfd3d6"
C_LEG, C_LEATHER, C_LEATHER_L, C_EYE = "#556260", "#827262", "#b89f83", "#373335"
C_HIDE, C_HIDE_L, C_HORN = "#9e9989", "#c5bea2", "#d8cb97"

BODIES = {
    "biped": (
        _pair("feet", 0.06, 0.11, 0.05, 0.12, 0.07, 0.06, C_LEATHER)
        + _pair("legs", 0.0, 0.10, 0.20, 0.075, 0.075, 0.16, C_LEG)
        + [("torso", (0, 0, 0.47), (0.17, 0.21, 0.20), C_CLOTH),
           ("belt", (0, 0, 0.37), (0.175, 0.215, 0.04), C_LEATHER_L),
           ("pack", (-0.19, 0, 0.55), (0.09, 0.15, 0.13), C_LEATHER)]
        + _pair("arms", 0.0, 0.25, 0.47, 0.07, 0.07, 0.17, C_SHIRT)
        + _pair("hands", 0.02, 0.26, 0.29, 0.055, 0.055, 0.055, C_SKIN)
        + [("head", (0, 0, 0.92), (0.27, 0.27, 0.27), C_SKIN),
           ("hair", (-0.09, 0, 0.99), (0.28, 0.295, 0.26), C_HAIR),
           ("hair", (0.12, 0, 1.08), (0.17, 0.25, 0.11), C_HAIR)]
        + _pair("eyes", 0.24, 0.09, 0.89, 0.03, 0.025, 0.045, C_EYE)
    ),
    "critter": (
        [("body", (-0.02, 0, 0.20), (0.26, 0.17, 0.15), C_HIDE),
         ("head", (0.24, 0, 0.30), (0.13, 0.13, 0.12), C_HIDE_L),
         ("tail", (-0.30, 0, 0.24), (0.10, 0.04, 0.04), C_HIDE)]
        + _pair("ears", 0.20, 0.08, 0.42, 0.04, 0.04, 0.07, C_HIDE)
        + _pair("eyes", 0.355, 0.05, 0.32, 0.02, 0.02, 0.03, C_EYE)
        + _pair("legs", 0.14, 0.10, 0.06, 0.05, 0.05, 0.07, C_HIDE)
        + _pair("legs", -0.14, 0.10, 0.06, 0.05, 0.05, 0.07, C_HIDE)
    ),
    "beast": (
        [("body", (-0.10, 0, 0.95), (0.75, 0.45, 0.42), C_HIDE),
         ("head", (0.72, 0, 1.20), (0.32, 0.30, 0.30), C_HIDE_L),
         ("snout", (1.00, 0, 1.08), (0.16, 0.15, 0.12), C_HIDE_L),
         ("tail", (-0.85, 0, 1.05), (0.15, 0.07, 0.07), C_HIDE)]
        + _pair("horns", 0.62, 0.24, 1.48, 0.06, 0.06, 0.16, C_HORN)
        + _pair("eyes", 1.00, 0.12, 1.28, 0.035, 0.03, 0.05, C_EYE)
        + _pair("legs", 0.50, 0.30, 0.32, 0.14, 0.14, 0.32, C_HIDE)
        + _pair("legs", -0.50, 0.30, 0.32, 0.14, 0.14, 0.32, C_HIDE)
    ),
    "giant": (
        _pair("feet", 0.15, 0.35, 0.12, 0.30, 0.18, 0.13, C_LEATHER)
        + _pair("legs", 0.0, 0.32, 0.60, 0.22, 0.22, 0.48, C_LEG)
        + [("torso", (0, 0, 1.45), (0.48, 0.62, 0.55), C_HIDE),
           ("belt", (0, 0, 1.0), (0.46, 0.6, 0.08), C_LEATHER_L),
           ("head", (0.10, 0, 2.20), (0.36, 0.36, 0.38), C_HIDE_L)]
        + _pair("shoulders", -0.02, 0.60, 1.92, 0.28, 0.28, 0.20, C_LEATHER)
        + _pair("arms", 0.05, 0.78, 1.35, 0.20, 0.20, 0.55, C_HIDE)
        + _pair("hands", 0.10, 0.80, 0.78, 0.20, 0.20, 0.20, C_HIDE_L)
        + _pair("horns", 0.0, 0.30, 2.55, 0.07, 0.07, 0.22, C_HORN)
        + _pair("eyes", 0.45, 0.13, 2.24, 0.035, 0.035, 0.05, C_EYE)
    ),
}
JOINTS = {  # pivots for cut-out animation, in the same frame as BODIES
    "biped": {"head": (0, 0, 0.92), "neck": (0, 0, 0.66), "shoulder_l": (0, 0.25, 0.62),
              "shoulder_r": (0, -0.25, 0.62), "hip_l": (0, 0.10, 0.34), "hip_r": (0, -0.10, 0.34),
              "hand_l": (0.02, 0.26, 0.29), "hand_r": (0.02, -0.26, 0.29)},
    "critter": {"head": (0.24, 0, 0.30), "neck": (0.16, 0, 0.28), "tail": (-0.24, 0, 0.24),
                "hip_f": (0.14, 0, 0.12), "hip_b": (-0.14, 0, 0.12)},
    "beast": {"head": (0.72, 0, 1.20), "neck": (0.52, 0, 1.15), "tail": (-0.78, 0, 1.05),
              "hip_f": (0.50, 0, 0.62), "hip_b": (-0.50, 0, 0.62)},
    "giant": {"head": (0.10, 0, 2.20), "neck": (0.05, 0, 1.92), "shoulder_l": (0, 0.70, 1.80),
              "shoulder_r": (0, -0.70, 1.80), "hip_l": (0, 0.32, 1.05), "hip_r": (0, -0.32, 1.05),
              "hand_l": (0.10, 0.80, 0.78), "hand_r": (0.10, -0.80, 0.78)},
}
PARTS = {  # paper-doll layers, bottom to top, for facings that show the front and the back
    "biped": {
        "front": ["back gear", "cloak back", "arm far", "leg far", "leg near", "torso", "head",
                  "hair or hat", "cloak front", "arm near", "weapon", "offhand"],
        "back": ["weapon", "offhand", "cloak front", "arm far", "leg far", "leg near", "torso", "head",
                 "hair or hat", "arm near", "cloak back", "back gear"],
    },
    "quad": {
        "front": ["tail", "legs far", "body", "legs near", "head", "ears or horns"],
        "back": ["head", "ears or horns", "legs far", "body", "legs near", "tail"],
    },
}
PART_SET = {"biped": "biped", "giant": "biped", "critter": "quad", "beast": "quad"}


def basis(d: str):
    v = np.array([*DIRS[d], 0.0])
    fwd = v / np.linalg.norm(v)
    left = np.array([-fwd[1], fwd[0], 0.0])
    return np.stack([fwd, left, np.array([0.0, 0.0, 1.0])])  # rows: local axes in world


def project(p_world, k, anchor):
    p = np.asarray(p_world, dtype=float)
    return anchor[0] + k * float(p @ R), anchor[1] - k * float(p @ U)


def joints_2d(body: str, d: str, k: float, anchor) -> dict:
    ax = basis(d)
    return {n: project(np.array(loc) @ ax, k, anchor) for n, loc in JOINTS[body].items()}


def raycast(body: str, d: str, k: float, size, anchor, ss=2):
    """Orthographic ray cast of the mannequin. Returns id (-1 empty), depth and normal at ss x size."""
    prims = BODIES[body]
    w, h = size
    xs = (np.arange(w * ss) + 0.5) / ss - anchor[0]
    ys = (np.arange(h * ss) + 0.5) / ss - anchor[1]
    X, Y = np.meshgrid(xs, ys)
    O = (X / k)[..., None] * R + (-Y / k)[..., None] * U
    ax = basis(d)
    best = np.full(X.shape, -np.inf)
    ids = np.full(X.shape, -1, dtype=np.int32)
    nrm = np.zeros(X.shape + (3,))
    for i, (_part, c, r, _col) in enumerate(prims):
        r = np.asarray(r, dtype=float)
        C = np.asarray(c, dtype=float) @ ax
        q0 = ((O - C) @ ax.T) / r
        dd = (ax @ F) / r
        a = dd @ dd
        b = 2 * (q0 @ dd)
        cc = (q0 * q0).sum(-1) - 1
        disc = b * b - 4 * a * cc
        hit = disc >= 0
        t = (-b + np.sqrt(np.where(hit, disc, 0))) / (2 * a)
        upd = hit & (t > best)
        if not upd.any():
            continue
        best[upd] = t[upd]
        ids[upd] = i
        q = q0[upd] + t[upd][:, None] * dd
        n = (q / r) @ ax
        nrm[upd] = n / np.linalg.norm(n, axis=1, keepdims=True)
    return ids, best, nrm


LIGHT = (0.0 * R + 0.8 * U + 0.6 * F)
LIGHT = LIGHT / np.linalg.norm(LIGHT)  # pieces are lit from above and in front so mirrors stay true


def _down(a: np.ndarray, ss: int, how="mean"):
    h, w = a.shape[0] // ss, a.shape[1] // ss
    b = a[:h * ss, :w * ss].reshape(h, ss, w, ss, *a.shape[2:])
    return b.mean(axis=(1, 3)) if how == "mean" else b.max(axis=(1, 3))


def body_bbox(body: str, d: str, k: float, anchor, pad=8):
    ax = basis(d)
    xs, ys = [], []
    for _part, c, r, _col in BODIES[body]:
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (-1, 1):
                    p = (np.asarray(c) + np.asarray(r) * (sx, sy, sz)) @ ax
                    x, y = project(p, k, anchor)
                    xs.append(x)
                    ys.append(y)
    return int(min(xs)) - pad, int(min(ys)) - pad, int(max(xs)) + pad + 1, int(max(ys)) + pad + 1


def render_mannequin(body: str, d: str, k: float, size, anchor, line_w=(3, 2), ss=2):
    """Returns dict of PIL images: blocking (flat colours), shaded (preview), lines (ink on clear),
    lineart (black on white, for control), depth (L, white near). Only the body's box is cast."""
    x0, y0, x1, y1 = body_bbox(body, d, k, anchor, pad=max(line_w) + 4)
    part = _render_box(body, d, k, (x1 - x0, y1 - y0), (anchor[0] - x0, anchor[1] - y0), line_w, ss)
    out = {}
    for key, im in part.items():
        bg = {"lineart": (255, 255, 255), "depth": 0}.get(key, (0, 0, 0, 0))
        full = Image.new(im.mode, size, bg)
        full.paste(im, (x0, y0))
        out[key] = full
    return out


def _render_box(body, d, k, size, anchor, line_w, ss):
    prims = BODIES[body]
    ids, depth, nrm = raycast(body, d, k, size, anchor, ss)
    cov = ids >= 0
    cols = np.array([hexrgb(p[3]) for p in prims] + [(0, 0, 0)], dtype=float)
    base = cols[ids]  # -1 indexes the trailing black
    lam = np.clip(nrm @ LIGHT, 0, 1)
    shade = np.where(cov, 0.68 + 0.32 * lam, 0)[..., None]
    alpha = _down(cov.astype(float), ss)
    def rgba(rgb_ss):
        pm = _down(rgb_ss * cov[..., None], ss)
        rgb = np.where(alpha[..., None] > 0, pm / np.maximum(alpha[..., None], 1e-6), 0)
        return Image.fromarray(np.dstack([rgb, alpha * 255]).clip(0, 255).astype(np.uint8), "RGBA")
    blocking = rgba(base)
    shaded = rgba(base * shade)
    # lines: where the part id changes; silhouette heavier than inner edges
    e_in = np.zeros(ids.shape, bool)
    e_out = np.zeros(ids.shape, bool)
    for sl_a, sl_b in [((slice(None), slice(1, None)), (slice(None), slice(None, -1))),
                       ((slice(1, None), slice(None)), (slice(None, -1), slice(None)))]:
        a, b = ids[sl_a], ids[sl_b]
        diff = a != b
        outer = diff & ((a < 0) | (b < 0))
        e_out[sl_a] |= outer
        e_out[sl_b] |= outer
        e_in[sl_a] |= diff & ~outer
    def thick(m, wpx):
        im = Image.fromarray((_down(m.astype(float), ss, "max") * 255).astype(np.uint8), "L")
        if wpx > 1:
            im = im.filter(ImageFilter.MaxFilter(int(wpx) | 1))
        return im
    lo = thick(e_out, line_w[0])
    li = thick(e_in, line_w[1])
    line_a = Image.fromarray(np.maximum(np.asarray(lo), np.asarray(li)), "L")
    lines = Image.new("RGBA", size, INK + (0,))
    lines.putalpha(line_a)
    lineart = Image.fromarray(255 - np.asarray(line_a), "L").convert("RGB")
    dmax = _down(np.where(cov, depth, -np.inf), ss, "max")
    valid = np.isfinite(dmax)
    dep = np.zeros(dmax.shape, np.uint8)
    if valid.any():
        lo_d, hi_d = dmax[valid].min(), dmax[valid].max()
        dep[valid] = (60 + 195 * (dmax[valid] - lo_d) / max(hi_d - lo_d, 1e-6)).astype(np.uint8)
    return {"blocking": blocking, "shaded": shaded, "lines": lines, "lineart": lineart,
            "depth": Image.fromarray(dep, "L")}


def mannequin_rgba(body, d, k, size, anchor, line_w=(3, 2)):
    m = render_mannequin(body, d, k, size, anchor, line_w)
    im = m["shaded"].copy()
    im.alpha_composite(m["lines"])
    return im


# --- guide drawing --------------------------------------------------------------------------
def empty(size):
    return Image.new("RGBA", size, (0, 0, 0, 0))


def footprint(dr, ax, ay, n, sc, fill=None, outline=INK + (150,), width=2, cells=True):
    hw, hh = 64 * n * sc, 32 * n * sc
    pts = [(ax, ay - hh), (ax + hw, ay), (ax, ay + hh), (ax - hw, ay)]
    if fill:
        dr.polygon(pts, fill=fill)
    if cells and n > 1:
        for i in range(1, n):
            f = i / n
            for a, b, c in [(0, 3, 1), (0, 1, 3)]:
                p0 = (pts[a][0] + (pts[b][0] - pts[a][0]) * f, pts[a][1] + (pts[b][1] - pts[a][1]) * f)
                p1 = (p0[0] + pts[c][0] - pts[a][0], p0[1] + pts[c][1] - pts[a][1])
                dr.line([p0, p1], fill=outline[:3] + (70,), width=1)
    dr.line(pts + [pts[0]], fill=outline, width=width)


def dashed(dr, a, b, col, width=1, dash=6):
    L = math.dist(a, b)
    if L == 0:
        return
    n = int(L // dash)
    for i in range(0, n, 2):
        f0, f1 = i / n, min((i + 1) / n, 1)
        dr.line([(a[0] + (b[0] - a[0]) * f0, a[1] + (b[1] - a[1]) * f0),
                 (a[0] + (b[0] - a[0]) * f1, a[1] + (b[1] - a[1]) * f1)], fill=col, width=width)


def frame_guides(dr, x0, y0, side, cls, sc=1.0, label="", f=None, levels=True):
    """Box, footprint diamond, foot anchor, plumb line, level ticks and the target head band."""
    n = CLASSES[cls]["cells"]
    ax, ay = anchor_of(cls)
    ax, ay = x0 + ax * sc, y0 + ay * sc
    dr.rectangle([x0, y0, x0 + side - 1, y0 + side - 1], outline=BLUE + (110,), width=1)
    footprint(dr, ax, ay, n, sc)
    dashed(dr, (ax, ay), (ax, y0 + 4), PINK + (90,), 1, 5)
    lv_px = HS * sc
    if levels:
        top = int((ay - y0) // lv_px)
        for lv in range(0, top + 1):
            y = ay - lv * lv_px
            ln = 10 if lv % 2 == 0 else 5
            dr.line([(x0, y), (x0 + ln * max(sc, 1) ** 0.5, y)], fill=BLUE + (170,), width=1)
            if lv % 2 == 0 and lv and f is not None:
                dr.text((x0 + 13 * max(sc, 1) ** 0.5, y), str(lv), fill=BLUE + (190,), font=f, anchor="lm")
        band = CLASSES[cls]["band"]
        y = ay - band * lv_px
        dashed(dr, (ax - 40 * n * sc, y), (ax + 40 * n * sc, y), PINK + (150,), 1, 4)
    r = max(2, 3 * sc ** 0.5)
    dr.ellipse([ax - r, ay - r, ax + r, ay + r], fill=PINK + (230,))
    if label and f is not None:
        dr.text((x0 + side - 5, y0 + 4), label, fill=BLUE + (220,), font=f, anchor="ra")


def marker(name):
    return (f"TEMPLATE {name}", empty((8, 8)), False)


# --- templates ------------------------------------------------------------------------------
def sprite_sheet(cls: str) -> dict:
    side = frame_of(cls)
    cols = CLASSES[cls]["cols"]
    rows = sheet_rows(cls)
    body = CLASSES[cls]["body"]
    size = (cols * side, len(rows) * side)
    guides, labels, ghost = empty(size), empty(size), empty(size)
    gd, ld = ImageDraw.Draw(guides), ImageDraw.Draw(labels)
    f = font(13 if side <= 192 else 18)
    k = K
    cache = {}
    layout_rows = []
    for r, segs in enumerate(rows):
        col = 0
        row_out = []
        for anim, d, nframes in segs:
            row_out.append({"anim": anim, "dir": d, "frames": nframes, "col": col})
            for i in range(nframes):
                x0, y0 = (col + i) * side, r * side
                tag = f"{d.upper()} {anim}" + (f" {i + 1}" if nframes > 1 else "")
                if d in MIRROR:
                    tag += " (opt)"
                frame_guides(gd, x0, y0, side, cls, 1.0, "", f)
                ld.text((x0 + side - 5, y0 + 4), tag, fill=BLUE + (220,), font=f, anchor="ra")
                if d not in cache:
                    cache[d] = mannequin_rgba(body, d, k, (side, side), anchor_of(cls), (2, 1))
                g = cache[d].copy()
                g.putalpha(g.getchannel("A").point(lambda v: v * 90 // 255))
                ghost.alpha_composite(g, (x0, y0))
            col += nframes
        layout_rows.append(row_out)
    layers = [
        ("paper", paper(size), True),
        ("GUIDE frames, footprints, anchors, levels", guides, True),
        ("GUIDE labels", labels, True),
        ("GUIDE mannequins", ghost, False),
        ("paint 1 body", empty(size), True),
        ("paint 2 cleanup and lines", empty(size), True),
        ("paint fx (exported on its own)", empty(size), True),
        marker(f"{cls} sheet"),
    ]
    out = TEMPLATES / cls
    out.mkdir(parents=True, exist_ok=True)
    save_psd(out / f"{cls}-sheet.psd", size, layers)
    prev = paper(size)
    for _, im, vis in layers[1:4]:
        prev.alpha_composite(im)
    prev.convert("RGB").save(out / "preview-sheet.png", optimize=True)
    return {"size": list(size), "rows": layout_rows}


MODEL_SLOTS = ["s", "se", "e", "ne", "n", "KEY"]


def model_anchor(cls: str):
    n, m = CLASSES[cls]["cells"], CLASSES[cls]["model"]
    return SLOT / 2, SLOT - 32 * n * m - 24


def model_sheet(cls: str) -> dict:
    """3 x 2 slots of 768 px for image generation: five views plus a KEY slot for the approved view."""
    body = CLASSES[cls]["body"]
    m = CLASSES[cls]["model"]
    k = K * m
    n = CLASSES[cls]["cells"]
    size = (SLOT * 3, SLOT * 2)
    anc = model_anchor(cls)
    blocking, lines_l, guides = empty(size), empty(size), empty(size)
    lineart = Image.new("RGB", size, (255, 255, 255))
    depth = Image.new("L", size, 0)
    gd = ImageDraw.Draw(guides)
    f = font(22)
    views = TEMPLATES / cls / "views"
    views.mkdir(parents=True, exist_ok=True)
    joints = {}
    lw = (max(3, round(1.2 * m)), max(2, round(0.7 * m)))
    for i, d in enumerate(MODEL_SLOTS):
        x0, y0 = (i % 3) * SLOT, (i // 3) * SLOT
        gd.rectangle([x0, y0, x0 + SLOT - 1, y0 + SLOT - 1], outline=BLUE + (120,), width=2)
        footprint(gd, x0 + anc[0], y0 + anc[1], n, m, width=3)
        lv = HS * m
        for j in range(0, int(anc[1] // lv) + 1):
            y = y0 + anc[1] - j * lv
            gd.line([(x0, y), (x0 + (18 if j % 2 == 0 else 9), y)], fill=BLUE + (170,), width=2)
            if j % 2 == 0 and j:
                gd.text((x0 + 24, y), str(j), fill=BLUE + (190,), font=f, anchor="lm")
        yb = y0 + anc[1] - CLASSES[cls]["band"] * lv
        dashed(gd, (x0 + anc[0] - 130, yb), (x0 + anc[0] + 130, yb), PINK + (160,), 2, 8)
        gd.ellipse([x0 + anc[0] - 6, y0 + anc[1] - 6, x0 + anc[0] + 6, y0 + anc[1] + 6], fill=PINK + (230,))
        gd.text((x0 + SLOT - 12, y0 + 10), d.upper() if d != "KEY" else "KEY: paste the approved view here",
                fill=BLUE + (230,), font=f, anchor="ra")
        if d == "KEY":
            continue
        mq = render_mannequin(body, d, k, (SLOT, SLOT), anc, lw)
        blocking.alpha_composite(mq["blocking"], (x0, y0))
        lines_l.alpha_composite(mq["lines"], (x0, y0))
        lineart.paste(mq["lineart"], (x0, y0))
        depth.paste(mq["depth"], (x0, y0))
        for key in ("lineart", "depth"):
            mq[key].save(views / f"{d}-{key}.png", optimize=True)
        flat = paper((SLOT, SLOT))
        flat.alpha_composite(mq["blocking"])
        flat.convert("RGB").save(views / f"{d}-blocking.png", optimize=True)
        joints[d] = {jn: [round(v, 1) for v in p] for jn, p in joints_2d(body, d, k, anc).items()}
        for jn, (px, py) in joints[d].items():
            gd.ellipse([x0 + px - 5, y0 + py - 5, x0 + px + 5, y0 + py + 5], outline=PINK + (200,), width=2)
    layers = [
        ("paper", paper(size), True),
        ("CONTROL depth (white = near)", depth.convert("RGBA"), False),
        ("CONTROL line art", lines_l, False),
        ("CONTROL blocking mannequins", blocking, True),
        ("GUIDE slots, footprints, levels, pivots", guides, True),
        ("paint 1 generated", empty(size), True),
        ("paint 2 cleanup and lines", empty(size), True),
        ("paint fx (exported on its own)", empty(size), True),
        marker(f"{cls} model"),
    ]
    out = TEMPLATES / cls
    save_psd(out / f"{cls}-model-sheet.psd", size, layers)
    lineart.save(out / "control-lineart.png", optimize=True)
    depth.save(out / "control-depth.png", optimize=True)
    flat = paper(size)
    flat.alpha_composite(blocking)
    flat.convert("RGB").save(out / "control-blocking.png", optimize=True)
    flat.alpha_composite(lines_l)
    flat.alpha_composite(guides)
    flat.convert("RGB").save(out / "preview-model-sheet.png", optimize=True)
    return {"size": list(size), "slot": SLOT, "slots": MODEL_SLOTS, "scale": m,
            "anchor": [round(v, 1) for v in anc], "joints": joints}


def parts_sheet(cls: str, side_name: str) -> list[str]:
    """Paper-doll file at model scale: one slot per facing, one layer per part in draw order."""
    body = CLASSES[cls]["body"]
    m = CLASSES[cls]["model"]
    k = K * m
    n = CLASSES[cls]["cells"]
    dirs = [d for d in DRAWN if (d in FRONT_DIRS) == (side_name == "front")]
    size = (SLOT * len(dirs), SLOT)
    anc = model_anchor(cls)
    ghost, guides = empty(size), empty(size)
    gd = ImageDraw.Draw(guides)
    f = font(22)
    lw = (max(3, round(1.2 * m)), max(2, round(0.7 * m)))
    for i, d in enumerate(dirs):
        x0 = i * SLOT
        gd.rectangle([x0, 0, x0 + SLOT - 1, SLOT - 1], outline=BLUE + (120,), width=2)
        footprint(gd, x0 + anc[0], anc[1], n, m, width=3)
        gd.ellipse([x0 + anc[0] - 6, anc[1] - 6, x0 + anc[0] + 6, anc[1] + 6], fill=PINK + (230,))
        gd.text((x0 + SLOT - 12, 10), d.upper(), fill=BLUE + (230,), font=f, anchor="ra")
        for jn, (px, py) in joints_2d(body, d, k, anc).items():
            gd.ellipse([x0 + px - 6, py - 6, x0 + px + 6, py + 6], outline=PINK + (220,), width=2)
            gd.text((x0 + px + 9, py), jn, fill=PINK + (220,), font=font(15), anchor="lm")
        g = mannequin_rgba(body, d, k, (SLOT, SLOT), anc, lw)
        g.putalpha(g.getchannel("A").point(lambda v: v * 110 // 255))
        ghost.alpha_composite(g, (x0, 0))
    names = PARTS[PART_SET[body]][side_name]
    layers = [("paper", paper(size), True), ("GUIDE mannequins", ghost, True),
              ("GUIDE slots, footprints, pivots", guides, True)]
    layers += [(f"part {i + 1:02d} {p}", empty(size), True) for i, p in enumerate(names)]
    layers.append(marker(f"{cls} parts-{side_name}"))
    save_psd(TEMPLATES / cls / f"{cls}-parts-{side_name}.psd", size, layers)
    return dirs


def anim_canvas(cls: str):
    """One model-scale slot for Krita's animation timeline: same anchor as the model sheet."""
    body = CLASSES[cls]["body"]
    m = CLASSES[cls]["model"]
    n = CLASSES[cls]["cells"]
    size = (SLOT, SLOT)
    anc = model_anchor(cls)
    guides = empty(size)
    gd = ImageDraw.Draw(guides)
    footprint(gd, anc[0], anc[1], n, m, width=3)
    lv = HS * m
    for j in range(0, int(anc[1] // lv) + 1):
        y = anc[1] - j * lv
        gd.line([(0, y), (18 if j % 2 == 0 else 9, y)], fill=BLUE + (170,), width=2)
    gd.ellipse([anc[0] - 6, anc[1] - 6, anc[0] + 6, anc[1] + 6], fill=PINK + (230,))
    dashed(gd, (anc[0], anc[1]), (anc[0], 4), PINK + (90,), 2, 8)
    lw = (max(3, round(1.2 * m)), max(2, round(0.7 * m)))
    ghosts = []
    for d in ("se", "ne"):
        g = mannequin_rgba(body, d, K * m, size, anc, lw)
        g.putalpha(g.getchannel("A").point(lambda v: v * 110 // 255))
        ghosts.append((f"GUIDE mannequin {d.upper()}", g, d == "se"))
    layers = [("paper", paper(size), True), *ghosts, ("GUIDE footprint and levels", guides, True),
              ("paint 1 pose", empty(size), True), marker(f"{cls} anim")]
    save_psd(TEMPLATES / cls / f"{cls}-anim-canvas.psd", size, layers)


def write_palette():
    lines = ["GIMP Palette", "Name: Lodestone characters", "Columns: 3", "#"]
    for name, (r, g, b) in palette_colors():
        lines.append(f"{r:3d} {g:3d} {b:3d}\t{name}")
    (TEMPLATES / "lodestone-characters.gpl").write_text("\n".join(lines) + "\n")


def build_templates():
    TEMPLATES.mkdir(parents=True, exist_ok=True)
    layout = {"camera": {"tile": [128, 64], "level_px": HS, "px_per_unit": round(K, 3),
                         "level_units": round(LEVEL_UNITS, 4)},
              "dirs": {d: list(v) for d, v in DIRS.items()}, "drawn": DRAWN, "mirror": MIRROR,
              "front_dirs": sorted(FRONT_DIRS), "parts": PARTS,
              "palette": {k: list(v) for k, v in RAMPS.items()} | {k: v for k, v in FIXED.items()},
              "classes": {}}
    for cls, c in CLASSES.items():
        sheet = sprite_sheet(cls)
        model = model_sheet(cls)
        sides = {s: parts_sheet(cls, s) for s in ("front", "back")}
        anim_canvas(cls)
        body = c["body"]
        layout["classes"][cls] = {
            "cells": c["cells"], "frame": frame_of(cls), "anchor": list(anchor_of(cls)),
            "band_levels": c["band"], "body": body, "part_set": PART_SET[body],
            "anims": {a: {"frames": v[0], "fps": v[1], "loop": v[2], "hit": v[3]} for a, v in ANIMS[cls].items()},
            "sheet": sheet, "model_sheet": model, "parts_files": sides,
            "joints": {d: {jn: [round(v, 1) for v in p] for jn, p in joints_2d(body, d, K, anchor_of(cls)).items()}
                       for d in DRAWN},
        }
    (TEMPLATES / "layout.json").write_text(json.dumps(layout, indent=1) + "\n")
    write_palette()


# --- diagrams -------------------------------------------------------------------------------
def diagram_sizes():
    order = ["small", "hero", "large", "boss"]
    z = 2
    W, H = 2400, 1240
    im = paper((W, H))
    dr = ImageDraw.Draw(im)
    f, fb = font(24), font(32, serif=True)
    ground = 930
    xs = [330, 680, 1180, 1880]
    for cls, x in zip(order, xs):
        n = CLASSES[cls]["cells"]
        footprint(dr, x, ground, n, z, fill=(215, 207, 176, 255), width=3)
        side = 1000
        g = mannequin_rgba(CLASSES[cls]["body"], "se", K * z, (side, side), (side / 2, side - 60), (4, 2))
        im.alpha_composite(g, (int(x - side / 2), int(ground - side + 60)))
        top = CLASSES[cls]["band"]
        y = ground - top * HS * z
        dashed(dr, (x - 80 * n, y), (x + 80 * n, y), PINK + (220,), 2, 8)
        fr = frame_of(cls)
        y_lab = ground + 32 * n * z + 20
        dr.text((x, y_lab), cls, fill=INK, font=fb, anchor="mt")
        dr.text((x, y_lab + 42), f"{n}x{n} cells, frame {fr}", fill=INK, font=f, anchor="mt")
        dr.text((x, y_lab + 74), f"head at ~{top:g} levels", fill=INK, font=f, anchor="mt")
    x = 70
    dr.line([(x, ground), (x, ground - 8 * HS * z)], fill=BLUE + (255,), width=3)
    for lv in range(0, 9):
        y = ground - lv * HS * z
        dr.line([(x - 10, y), (x + 10, y)], fill=BLUE + (255,), width=3)
        dr.text((x + 16, y), str(lv), fill=BLUE + (255,), font=f, anchor="lm")
    dr.text((x - 30, ground - 8 * HS * z - 36), "levels (32 px)", fill=BLUE + (255,), font=f, anchor="lm")
    dr.text((W / 2, 30), "Piece sizes on the board, shown at 2x the art size. Pink dash = target head height.",
            fill=INK, font=f, anchor="mt")
    im.convert("RGB").save(DOCS / "01-sizes.png", optimize=True)


def diagram_directions():
    cw, ch = 440, 400
    W, H = cw * 3, ch * 3 + 60
    im = paper((W, H))
    dr = ImageDraw.Draw(im)
    f, fb = font(22), font(28, serif=True)
    spots = {"nw": (0, 0), "n": (1, 0), "ne": (2, 0), "w": (0, 1), "e": (2, 1),
             "sw": (0, 2), "s": (1, 2), "se": (2, 2)}
    cx, cy = W / 2, 60 + ch * 1.5
    footprint(dr, cx, cy, 1, 1.4, fill=(215, 207, 176, 255), width=3)
    side = 300
    for d, (gx, gy) in spots.items():
        v = DIRS[d]
        sx, sy = (v[0] - v[1]) * 64, (v[0] + v[1]) * 32
        L = math.hypot(sx, sy)
        dr.line([(cx, cy), (cx + sx / L * 130, cy + sy / L * 130)], fill=BLUE + (200,), width=3)
        dr.text((cx + sx / L * 158, cy + sy / L * 158), d.upper(), fill=BLUE + (255,), font=f, anchor="mm")
        x0, y0 = gx * cw, 60 + gy * ch
        g = mannequin_rgba("biped", d, K * 1.6, (side, side), (side / 2, side - 50), (3, 2))
        im.alpha_composite(g, (int(x0 + cw / 2 - side / 2), int(y0 + 10)))
        if d in MIRROR:
            tag, col = f"mirror of {MIRROR[d].upper()}", (150, 140, 130)
        else:
            tag, col = "draw", INK
        tag += "  ·  combat" if d in ("se", "sw", "ne", "nw") else "  ·  roaming"
        dr.text((x0 + cw / 2, y0 + side + 12), f"{d.upper()}   {tag}", fill=col, font=f, anchor="mt")
    dr.text((W / 2, 24), "Eight facings, named by where the piece looks on screen. Grid moves are the diagonals (combat).",
            fill=INK, font=f, anchor="mt")
    im.convert("RGB").save(DOCS / "02-directions.png", optimize=True)


def diagram_frame():
    cls = "hero"
    z = 4
    side = frame_of(cls) * z
    W, H = side + 760, side + 80
    im = paper((W, H))
    x0, y0 = 40, 40
    g = mannequin_rgba("biped", "se", K * z, (side, side), (anchor_of(cls)[0] * z, anchor_of(cls)[1] * z), (6, 3))
    im.alpha_composite(g, (x0, y0))
    dr = ImageDraw.Draw(im)
    f = font(24)
    frame_guides(dr, x0, y0, side, cls, z, "", font(20))
    ax, ay = x0 + anchor_of(cls)[0] * z, y0 + anchor_of(cls)[1] * z
    for jn, (px, py) in joints_2d("biped", "se", K * z, (anchor_of(cls)[0] * z, anchor_of(cls)[1] * z)).items():
        px, py = px + x0, py + y0
        dr.ellipse([px - 7, py - 7, px + 7, py + 7], outline=PINK + (255,), width=3)
    notes = [
        ("Frame 192 x 192 (one cell). Large 384, boss 576.", BLUE),
        ("Foot anchor (96, 160): centre of the footprint.", PINK),
        ("The engine puts this pixel on the cell's top centre.", INK),
        ("Footprint diamond 128 x 64 fills the bottom.", INK),
        ("Ticks: one level = 32 px. Dashed: head at 3 levels.", BLUE),
        ("Circles: joint pivots for cut-out animation.", PINK),
        ("Headroom: 5 levels for hats, swings and spells.", INK),
        ("No ground, base or shadow: the engine adds them.", INK),
    ]
    tx = x0 + side + 40
    for i, (t, c) in enumerate(notes):
        dr.text((tx, y0 + 30 + i * 70), t, fill=c + (255,), font=f)
    im.convert("RGB").save(DOCS / "03-frame-anatomy.png", optimize=True)


def diagram_parts():
    W, H = 1700, 900
    im = paper((W, H))
    dr = ImageDraw.Draw(im)
    f, fb = font(21), font(28, serif=True)
    side = 600
    for i, (d, sname) in enumerate([("se", "front"), ("ne", "back")]):
        x = 40 + i * 840
        g = mannequin_rgba("biped", d, K * 2.6, (side, side), (side / 2, side - 70), (4, 2))
        im.alpha_composite(g, (x, 150))
        for jn, (px, py) in joints_2d("biped", d, K * 2.6, (side / 2, side - 70)).items():
            dr.ellipse([x + px - 7, 150 + py - 7, x + px + 7, 150 + py + 7], outline=PINK + (255,), width=3)
        dr.text((x + side / 2, 110), f"{d.upper()}: {sname} stack", fill=INK, font=fb, anchor="mm")
        names = PARTS["biped"][sname]
        for j, p in enumerate(reversed(names)):
            dr.text((x + side - 40, 170 + j * 50), f"{len(names) - j:2d}  {p}", fill=INK, font=f)
    dr.text((W / 2, 30), "Paper-doll parts, top of list draws on top. S, SE, E (and mirrors) use the front stack; NE, N use the back.",
            fill=INK, font=f, anchor="mt")
    im.convert("RGB").save(DOCS / "05-parts.png", optimize=True)


def diagram_palette():
    cols = list(RAMPS.items())
    W, H = 1500, 330
    im = paper((W, H))
    dr = ImageDraw.Draw(im)
    f = font(19)
    for i, (name, ramp) in enumerate(cols):
        x = 30 + i * 145
        for j, c in enumerate(ramp):
            dr.rectangle([x, 30 + j * 70, x + 120, 90 + j * 70], fill=hexrgb(c), outline=INK, width=2)
            dr.text((x + 60, 60 + j * 70), c, fill=INK if j < 2 else (240, 238, 228), font=font(16), anchor="mm")
        dr.text((x + 60, 255), name, fill=INK, font=f, anchor="mt")
    dr.text((30, 295), "Key ramps (light / mid / dark) from Brandon's sheet. Outline ink #373335. The engine swaps whole ramps to recolour a piece.",
            fill=INK, font=f)
    im.convert("RGB").save(DOCS / "04-palette.png", optimize=True)


def build_diagrams():
    DOCS.mkdir(parents=True, exist_ok=True)
    diagram_sizes()
    diagram_directions()
    diagram_frame()
    diagram_palette()
    diagram_parts()


# --- reading painted files ------------------------------------------------------------------
def read_layers(path: Path):
    """(size, [(name, visible, RGBA full-canvas image)]) bottom first, groups flattened."""
    if path.suffix.lower() == ".ora":
        with zipfile.ZipFile(path) as z:
            root = ET.fromstring(z.read("stack.xml"))
            size = (int(root.get("w")), int(root.get("h")))
            out = []

            def walk(stack, vis=True, ox=0, oy=0):
                for el in reversed(list(stack)):  # stack.xml lists top first
                    v = vis and el.get("visibility", "visible") != "hidden"
                    x, y = ox + int(float(el.get("x", 0))), oy + int(float(el.get("y", 0)))
                    if el.tag == "stack":
                        walk(el, v, x, y)
                    elif el.tag == "layer" and el.get("src", "").endswith(".png"):
                        img = Image.open(io.BytesIO(z.read(el.get("src")))).convert("RGBA")
                        op = float(el.get("opacity", 1))
                        if op < 1:
                            img.putalpha(img.getchannel("A").point(lambda a: int(a * op)))
                        full = empty(size)
                        full.alpha_composite(img, (max(x, 0), max(y, 0)), (max(-x, 0), max(-y, 0)))
                        out.append((el.get("name", ""), v, full))
            walk(root.find("stack"))
            return size, out
    from psd_tools import PSDImage
    psd = PSDImage.open(path)
    size = (psd.width, psd.height)
    out = []
    for layer in psd.descendants():
        if layer.is_group():
            continue
        img = layer.topil()
        full = empty(size)
        if img is not None:
            img = img.convert("RGBA")
            if layer.opacity < 255:
                img.putalpha(img.getchannel("A").point(lambda a: a * layer.opacity // 255))
            l, t = layer.offset
            full.alpha_composite(img, (max(l, 0), max(t, 0)), (max(-l, 0), max(-t, 0)))
        out.append((layer.name, layer.is_visible(), full))
    return size, out


def compose(layers, pick):
    size = layers[0][2].size
    im = empty(size)
    for name, vis, img in layers:
        if vis and pick(name.lower()):
            im.alpha_composite(img)
    return im


def is_body_paint(n):
    return n.startswith("paint") and "fx" not in n


def is_fx(n):
    return n.startswith("paint") and "fx" in n


def has_ink(img: Image.Image) -> bool:
    return img.getchannel("A").getextrema()[1] > 8


def lock_colors(img: Image.Image, colors=None) -> Image.Image:
    """Snap every visible pixel to the nearest palette colour; alpha is kept."""
    pal = np.array([c for _, c in (colors or palette_colors())], dtype=float)
    a = np.asarray(img.convert("RGBA")).astype(float)
    rgb = a[..., :3].reshape(-1, 3)
    w = np.array([0.30, 0.59, 0.11])
    best = np.zeros(len(rgb), dtype=np.int32)
    bd = np.full(len(rgb), np.inf)
    for i, c in enumerate(pal):
        dist = (((rgb - c) ** 2) * w).sum(1)
        m = dist < bd
        bd[m], best[m] = dist[m], i
    out = a.copy()
    out[..., :3] = pal[best].reshape(a.shape[:2] + (3,))
    out[..., 3] = np.where(a[..., 3] < 16, 0, a[..., 3])
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def read_gpl(path: Path):
    cols = []
    for line in path.read_text().splitlines():
        m = re.match(r"\s*(\d+)\s+(\d+)\s+(\d+)\s*(.*)", line)
        if m:
            cols.append((m.group(4), tuple(int(m.group(i)) for i in (1, 2, 3))))
    return cols


def save_sprite(img, path: Path, lock, colors):
    path.parent.mkdir(parents=True, exist_ok=True)
    (lock_colors(img, colors) if lock else img).save(path, optimize=True)
    print("  ", path.relative_to(ROOT) if path.is_relative_to(ROOT) else path)


def update_meta(out: Path, sid: str, cls: str, anims=None, stand=None, parts=None):
    meta_path = out / f"{sid}.json"
    meta = json.loads(meta_path.read_text()) if meta_path.exists() else {}
    c = CLASSES[cls]
    meta.update({"id": sid, "class": cls, "frame": frame_of(cls), "anchor": list(anchor_of(cls)),
                 "scale": 0.5, "mirror": MIRROR})
    if anims:
        meta.setdefault("anims", {}).update(anims)
    if stand:
        meta["stand"] = sorted(set(meta.get("stand", [])) | set(stand))
    if parts:
        meta.setdefault("parts", {}).update(parts)
        meta["part_order"] = PARTS[PART_SET[c["body"]]]
    meta_path.write_text(json.dumps(meta, indent=1, sort_keys=True) + "\n")
    print("  ", meta_path.relative_to(ROOT) if meta_path.is_relative_to(ROOT) else meta_path)


def slot_to_frame(img: Image.Image, cls: str) -> Image.Image:
    """Cut one model-scale slot down to a game frame, keeping the foot anchor."""
    m = CLASSES[cls]["model"]
    fr = frame_of(cls)
    ax, ay = model_anchor(cls)
    fax, fay = anchor_of(cls)
    box = (round(ax - fax * m), round(ay - fay * m), round(ax + (fr - fax) * m), round(ay + (fr - fay) * m))
    crop = empty((box[2] - box[0], box[3] - box[1]))
    crop.alpha_composite(img, (max(-box[0], 0), max(-box[1], 0)),
                         (max(box[0], 0), max(box[1], 0), min(box[2], img.width), min(box[3], img.height)))
    # premultiply so transparent pixels don't bleed dark fringes
    a = np.asarray(crop).astype(float)
    a[..., :3] *= a[..., 3:4] / 255
    small = Image.fromarray(a.astype(np.uint8), "RGBA").resize((fr, fr), Image.LANCZOS)
    b = np.asarray(small).astype(float)
    al = np.maximum(b[..., 3:4], 1)
    b[..., :3] = np.where(b[..., 3:4] > 0, b[..., :3] * 255 / al, 0)
    return Image.fromarray(b.clip(0, 255).astype(np.uint8), "RGBA")


def export(path: Path, sid: str, out: Path | None, lock: bool, palette: Path | None):
    size, layers = read_layers(path)
    tag = next((n for n, _, _ in layers if n.startswith("TEMPLATE ")), None)
    if not tag:
        sys.exit(f"{path}: no 'TEMPLATE <class> <kind>' layer; start from a file in art/templates/characters/")
    _, cls, kind = tag.split()
    out = out or GAME / sid
    colors = read_gpl(palette) if palette else None
    print(f"{path.name}: {cls} {kind} -> {out}")
    if kind == "sheet":
        side = frame_of(cls)
        bodies, fxs = compose(layers, is_body_paint), compose(layers, is_fx)
        anims, stand = {}, []
        for r, segs in enumerate(sheet_rows(cls)):
            col = 0
            for anim, d, n in segs:
                for src, suffix in ((bodies, ""), (fxs, "_fx")):
                    frames = [src.crop(((col + i) * side, r * side, (col + i + 1) * side, (r + 1) * side))
                              for i in range(n)]
                    used = [i for i, fr in enumerate(frames) if has_ink(fr)]
                    if not used:
                        continue
                    count = used[-1] + 1
                    strip = empty((side * count, side))
                    for i in range(count):
                        strip.alpha_composite(frames[i], (i * side, 0))
                    save_sprite(strip, out / f"{sid}_{anim}_{d}{suffix}.png", lock and not suffix, colors)
                    if suffix:
                        continue
                    if anim == "stand":
                        stand.append(d)
                    else:
                        fr_, fps, loop, hit = ANIMS[cls][anim]
                        anims[f"{anim}_{d}"] = {"frames": count, "fps": fps, "loop": loop, "hit": hit}
                col += n
        update_meta(out, sid, cls, anims=anims, stand=stand)
    elif kind == "model":
        body = compose(layers, is_body_paint)
        stand = []
        for i, d in enumerate(MODEL_SLOTS):
            if d == "KEY":
                continue
            x0, y0 = (i % 3) * SLOT, (i // 3) * SLOT
            fr = slot_to_frame(body.crop((x0, y0, x0 + SLOT, y0 + SLOT)), cls)
            if has_ink(fr):
                save_sprite(fr, out / f"{sid}_stand_{d}.png", lock, colors)
                stand.append(d)
        update_meta(out, sid, cls, stand=stand)
    elif kind.startswith("parts-"):
        side_name = kind.split("-", 1)[1]
        dirs = [d for d in DRAWN if (d in FRONT_DIRS) == (side_name == "front")]
        parts = {}
        for name, vis, img in layers:
            m = re.match(r"part \d+ (.+)", name)
            if not (m and vis):
                continue
            pname = re.sub(r"\W+", "_", m.group(1).strip().lower()).strip("_")
            for i, d in enumerate(dirs):
                fr = slot_to_frame(img.crop((i * SLOT, 0, (i + 1) * SLOT, SLOT)), cls)
                if has_ink(fr):
                    save_sprite(fr, out / "parts" / d / f"{pname}.png", lock, colors)
                    parts.setdefault(d, []).append(pname)
        update_meta(out, sid, cls, parts=parts)
    else:
        sys.exit(f"unknown template kind {kind}")


def pack(folder: Path, sid: str, cls: str, out: Path | None, lock: bool):
    """Krita's Render Animation writes <base>0000.png ...; name the base <id>_<anim>_<dir>_."""
    out = out or GAME / sid
    groups: dict[str, list[Path]] = {}
    for p in sorted(folder.glob(f"{sid}_*.png")):
        m = re.match(rf"({re.escape(sid)}_[a-z]+_[a-z]+(?:_fx)?)_?(\d+)\.png$", p.name)
        if m:
            groups.setdefault(m.group(1), []).append(p)
    anims = {}
    side = frame_of(cls)
    for base, files in groups.items():
        frames = [Image.open(f).convert("RGBA") for f in files]
        if frames[0].size == (SLOT, SLOT):  # drawn on the model-scale anim canvas
            frames = [slot_to_frame(fr, cls) for fr in frames]
        elif frames[0].size != (side, side):
            sys.exit(f"{files[0].name}: frames must be {side} or {SLOT} square for class {cls}")
        strip = empty((side * len(frames), side))
        for i, fr in enumerate(frames):
            strip.alpha_composite(fr, (i * side, 0))
        save_sprite(strip, out / f"{base}.png", lock and not base.endswith("_fx"), None)
        if base.endswith("_fx"):
            continue
        anim, d = base[len(sid) + 1:].split("_")
        if anim in ANIMS[cls]:
            fr_, fps, loop, hit = ANIMS[cls][anim]
            anims[f"{anim}_{d}"] = {"frames": len(frames), "fps": fps, "loop": loop, "hit": hit}
    update_meta(out, sid, cls, anims=anims)


def palette_card(labeled: bool) -> Image.Image:
    """3:2 card of the key ramps on paper: a shaded ball and three swatches per ramp, ink and glint last.
    The unlabeled one is a reference image for Picsart / GPT; the labeled one is for people."""
    W, H = 1536, 1024
    im = Image.new("RGBA", (W, H), PAPER + (255,))
    dr = ImageDraw.Draw(im)
    ramps = list(RAMPS.items())
    cw = W // (len(ramps) + 1)
    for i, (name, ramp) in enumerate(ramps):
        x = i * cw + cw // 2
        light, mid, dark = (hexrgb(c) for c in ramp)
        # a ball lit from above: dark base, mid body, light cap, inked
        r = cw * 0.36
        cy = 250
        dr.ellipse([x - r, cy - r, x + r, cy + r], fill=dark)
        dr.ellipse([x - r * 0.92, cy - r, x + r * 0.92, cy + r * 0.62], fill=mid)
        dr.ellipse([x - r * 0.6, cy - r * 0.86, x + r * 0.6, cy - r * 0.05], fill=light)
        dr.ellipse([x - r, cy - r, x + r, cy + r], outline=INK, width=4)
        for j, c in enumerate((light, mid, dark)):
            y = 440 + j * 150
            dr.rectangle([x - cw * 0.38, y, x + cw * 0.38, y + 130], fill=c, outline=INK, width=3)
        if labeled:
            dr.text((x, 920), name, fill=INK, font=font(17), anchor="mt")
            for j, c in enumerate(ramp):
                dr.text((x, 440 + j * 150 + 65), c, fill=INK if j < 2 else (240, 238, 228), font=font(14), anchor="mm")
    x = len(ramps) * cw + cw // 2
    for j, key in enumerate(("ink", "glint")):
        y = 440 + j * 150
        dr.rectangle([x - cw * 0.38, y, x + cw * 0.38, y + 130], fill=hexrgb(FIXED[key]), outline=INK, width=3)
        if labeled:
            dr.text((x, y + 65), FIXED[key], fill=(240, 238, 228) if key == "ink" else INK, font=font(14), anchor="mm")
    return im.convert("RGB")


def write_palette_cards():
    out = ROOT / "art/palettes"
    out.mkdir(parents=True, exist_ok=True)
    palette_card(False).save(out / "characters.png", optimize=True)
    palette_card(True).save(out / "characters-labeled.png", optimize=True)


# --- importing pictures from an image model (Picsart, GPT) ------------------------------------
def key_background(img: Image.Image, tol=38) -> Image.Image:
    """Make the plain background transparent: flood from the picture's edges through pixels close to
    the edge colour. The ink outline stops the flood, so cream inside the figure stays."""
    a = np.asarray(img.convert("RGBA")).astype(np.int16)
    if a[..., 3].min() < 250:  # already cut out (e.g. Picsart Remove background)
        return img.convert("RGBA")
    rgb = a[..., :3]
    edge = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
    bg = np.median(edge, axis=0)
    near = (np.abs(rgb - bg).sum(-1) <= tol * 3) & (np.abs(rgb - bg).max(-1) <= tol)
    fill = np.zeros(near.shape, bool)
    fill[0], fill[-1], fill[:, 0], fill[:, -1] = near[0], near[-1], near[:, 0], near[:, -1]
    while True:  # grow the flood one pixel at a time inside the near-background mask
        grown = fill.copy()
        grown[1:] |= fill[:-1]
        grown[:-1] |= fill[1:]
        grown[:, 1:] |= fill[:, :-1]
        grown[:, :-1] |= fill[:, 1:]
        grown &= near
        if (grown == fill).all():
            break
        fill = grown
    out = a.copy()
    out[..., 3] = np.where(fill, 0, 255)
    im = Image.fromarray(out.astype(np.uint8), "RGBA")
    # soften the cut edge by one pixel so the figure doesn't look stamped out
    alpha = im.getchannel("A").filter(ImageFilter.MinFilter(3)).filter(ImageFilter.BoxBlur(0.6))
    im.putalpha(alpha)
    return im


def _ink_box(img: Image.Image):
    a = np.asarray(img.getchannel("A")) > 40
    # ignore specks: keep rows / columns with a few solid pixels
    rows = np.nonzero(a.sum(1) >= 3)[0]
    cols = np.nonzero(a.sum(0) >= 3)[0]
    if not len(rows):
        return None
    return cols[0], rows[0], cols[-1], rows[-1]


def reanchor(view: Image.Image, cls: str, d: str, fit=False):
    """Move (and optionally scale) a 768 view so its feet sit where the mannequin's feet are.
    Returns the new view and the figure's height as a share of the mannequin's."""
    body = CLASSES[cls]["body"]
    m = CLASSES[cls]["model"]
    anc = model_anchor(cls)
    man = render_mannequin(body, d, K * m, (SLOT, SLOT), anc, (2, 1))["blocking"]
    mb, vb = _ink_box(man), _ink_box(view)
    if vb is None:
        return view, 0.0
    m_h, v_h = mb[3] - mb[1], vb[3] - vb[1]
    ratio = v_h / max(m_h, 1)
    if fit and abs(ratio - 1) > 0.04:
        s = 1 / ratio
        view = view.resize((round(view.width * s), round(view.height * s)), Image.LANCZOS)
        vb = _ink_box(view)
    # feet: centre of the lowest band of the figure
    a = np.asarray(view.getchannel("A")) > 40
    band = a[max(vb[3] - 12, 0):vb[3] + 1]
    xs = np.nonzero(band.any(0))[0]
    fx = (xs[0] + xs[-1]) / 2 if len(xs) else (vb[0] + vb[2]) / 2
    am = np.asarray(man.getchannel("A")) > 40
    mband = am[mb[3] - 12:mb[3] + 1]
    mxs = np.nonzero(mband.any(0))[0]
    mfx = (mxs[0] + mxs[-1]) / 2
    dx, dy = round(mfx - fx), round(mb[3] - vb[3])
    out = empty((SLOT, SLOT))
    out.alpha_composite(view, (max(dx, 0), max(dy, 0)), (max(-dx, 0), max(-dy, 0)))
    return out, ratio


def import_picture(path: Path, sid: str, cls: str, d: str | None, anim: str | None, frame: int,
                   fit: bool, anchor: bool, lock: bool, out: Path | None):
    """Bring a picture from Picsart (or any image model) into the pipeline.
    3:2 picture = a whole model sheet (S, SE, E / NE, N, KEY). Square picture = one view (--dir)."""
    src = Image.open(path)
    work = ROOT / "art/characters" / sid
    out = out or GAME / sid
    ratio_wh = src.width / src.height
    if abs(ratio_wh - 1.5) < 0.05:
        sheet = key_background(src.convert("RGB").resize((SLOT * 3, SLOT * 2), Image.LANCZOS))
        slots = [(d_, (i % 3) * SLOT, (i // 3) * SLOT) for i, d_ in enumerate(MODEL_SLOTS) if d_ != "KEY"]
        views = {d_: sheet.crop((x, y, x + SLOT, y + SLOT)) for d_, x, y in slots}
    elif abs(ratio_wh - 1) < 0.05:
        if not d:
            sys.exit("a square picture is one view: say which with --dir s|se|e|ne|n (or sw|w|nw)")
        views = {d: key_background(src.convert("RGB").resize((SLOT, SLOT), Image.LANCZOS))}
    else:
        sys.exit(f"{path.name} is {src.width} x {src.height}: use 3:2 for a turnaround sheet or 1:1 for one view")
    print(f"{path.name}: {cls}, {len(views)} view(s) -> {work}")
    placed = {}
    for d_, v in views.items():
        if not has_ink(v):
            print(f"   {d_.upper()}: empty, skipped")
            continue
        if anchor:
            v, r = reanchor(v, cls, MIRROR.get(d_, d_), fit)
            note = "ok" if 0.88 <= r <= 1.15 else ("too small, try --fit" if r < 0.88 else "too tall (hat? else --fit)")
            print(f"   {d_.upper()}: height {r:.0%} of the mannequin, {note}")
        placed[d_] = v
    if anim:
        for d_, v in placed.items():
            dst = work / "renders" / f"{sid}_{anim}_{d_}_{frame:04d}.png"
            dst.parent.mkdir(parents=True, exist_ok=True)
            v.save(dst, optimize=True)
            print("  ", dst.relative_to(ROOT))
        print(f"   then: python3 tools/art/char_art.py pack {(work / 'renders').relative_to(ROOT)} --id {sid} --class {cls}")
        return
    # keep a layered model sheet to fix in Krita, then export stand frames from it
    model = work / f"{sid}-model.ora"
    if model.exists():
        size, layers = read_layers(model)
        layers = [(n, im, v) for n, v, im in layers]
    else:
        size, layers = read_layers(TEMPLATES / cls / f"{cls}-model-sheet.ora")
        layers = [(n, im, v) for n, v, im in layers]
    idx = next(i for i, (n, _, _) in enumerate(layers) if n.lower().startswith("paint 1"))
    name, paint, vis = layers[idx]
    for d_, v in placed.items():
        if d_ not in MODEL_SLOTS:
            continue  # optional mirrors have no model-sheet slot; they still export below
        i = MODEL_SLOTS.index(d_)
        x0, y0 = (i % 3) * SLOT, (i // 3) * SLOT
        paint.paste(empty((SLOT, SLOT)), (x0, y0))
        paint.alpha_composite(v, (x0, y0))
    layers[idx] = (name, paint, vis)
    from battle_art import save_ora
    comp = paper(size)
    for _, im, v in layers:
        if v:
            comp.alpha_composite(im)
    work.mkdir(parents=True, exist_ok=True)
    save_ora(model, size, layers, comp)
    print("  ", model.relative_to(ROOT), "(layered: fix it in Krita, then run export on it)")
    stand = []
    for d_, v in placed.items():
        save_sprite(slot_to_frame(v, cls), out / f"{sid}_stand_{d_}.png", lock, None)
        stand.append(d_)
    update_meta(out, sid, cls, stand=stand)


def build_guide():
    """Inline the diagrams into tools/art/character_guide.src.html -> docs/context/artifacts/character-guide.html."""
    import base64
    src = (ROOT / "tools/art/character_guide.src.html").read_text()

    def inline(m):
        img = Image.open(ROOT / m.group(1)).convert("RGB")
        w = int(m.group(2))
        if img.width > w:
            img = img.resize((w, round(img.height * w / img.width)), Image.LANCZOS)
        b = io.BytesIO()
        img.save(b, "PNG", optimize=True)
        return "data:image/png;base64," + base64.b64encode(b.getvalue()).decode()
    out = re.sub(r"\{\{IMG:([^:}]+):(\d+)\}\}", inline, src)
    dst = ROOT / "docs/context/artifacts/character-guide.html"
    dst.write_text(out)
    print("wrote", dst.relative_to(ROOT), f"{len(out) // 1024} KB")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd")
    e = sub.add_parser("export", help="slice a painted .psd/.ora made from a template")
    e.add_argument("file", type=Path)
    e.add_argument("--id", required=True, help="sprite id, lower_snake (e.g. hero, wolf_small)")
    e.add_argument("--out", type=Path, help="default game/art/source/characters/<id>/")
    e.add_argument("--lock", action="store_true", help="snap colours to the palette")
    e.add_argument("--palette", type=Path, help=".gpl to lock to (default: character palette)")
    p = sub.add_parser("pack", help="join a Krita animation render into strips")
    p.add_argument("folder", type=Path)
    p.add_argument("--id", required=True)
    p.add_argument("--class", dest="cls", default="hero", choices=list(CLASSES))
    p.add_argument("--out", type=Path)
    p.add_argument("--lock", action="store_true")
    lk = sub.add_parser("lock", help="snap a PNG's colours to the palette")
    lk.add_argument("src", type=Path)
    lk.add_argument("dst", type=Path, nargs="?")
    lk.add_argument("--palette", type=Path)
    sub.add_parser("guide", help="rebuild the character guide page with inlined diagrams")
    im = sub.add_parser("import", help="bring a Picsart / image-model picture in: key out the background, put the feet on the anchor")
    im.add_argument("picture", type=Path, help="3:2 turnaround sheet or 1:1 single view")
    im.add_argument("--id", required=True)
    im.add_argument("--class", dest="cls", default="hero", choices=list(CLASSES))
    im.add_argument("--dir", choices=list(DIRS), help="which view a square picture is")
    im.add_argument("--anim", help="a key pose: writes art/characters/<id>/renders/<id>_<anim>_<dir>_<frame>.png for pack")
    im.add_argument("--frame", type=int, default=0, help="frame number for --anim (0 = first)")
    im.add_argument("--fit", action="store_true", help="also scale the figure to the mannequin's height")
    im.add_argument("--no-anchor", action="store_true", help="leave the figure where the model put it")
    im.add_argument("--lock", action="store_true")
    im.add_argument("--out", type=Path)
    a = ap.parse_args()
    if a.cmd == "export":
        export(a.file, a.id, a.out, a.lock, a.palette)
    elif a.cmd == "pack":
        pack(a.folder, a.id, a.cls, a.out, a.lock)
    elif a.cmd == "import":
        import_picture(a.picture, a.id, a.cls, a.dir, a.anim, a.frame, a.fit, not a.no_anchor, a.lock, a.out)
    elif a.cmd == "guide":
        build_guide()
    elif a.cmd == "lock":
        colors = read_gpl(a.palette) if a.palette else None
        lock_colors(Image.open(a.src), colors).save(a.dst or a.src)
    else:
        build_templates()
        build_diagrams()
        write_palette_cards()
        print("wrote", TEMPLATES.relative_to(ROOT), "and", DOCS.relative_to(ROOT))


if __name__ == "__main__":
    main()
