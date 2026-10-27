#!/usr/bin/env python3
"""Break a painted concept map into a battle tile set.

You paint a map on its template (art/templates/battle-maps/maps/<map>/), export the painting at the
template's exact size, and this cuts it back into the pieces the game draws:

  * one top texture per terrain, unwarped from a 2 x 2 patch of same-terrain, same-height cells
  * side strips (cliff, masonry, water), unwarped from the tallest lit or shaded face run, 2 cells wide
    and 4 levels tall, lined up so the stone rows sit on height levels in the game
  * props, one per blob on an exported "paint 3 props" layer, with the feet at the bottom centre

    python3 tools/art/break_out.py art/paintings/sampler-forest.png --map sampler --set forest
    python3 tools/art/break_out.py painting.png --map sampler --set forest --props sampler-forest-props.png

It first checks how well the painting kept the grid (share of the template blocking's edges with a painted
edge nearby) and marks drifted cells. --check does only that. A 3:2 image of another size (1536 x 1024 from an
image model) is scaled to the template size first.

Writes game/art/source/battle/<set>/ (top_*.png, side_*.png, prop_<n>.png) and a contact sheet
art/paintings/<painting>-breakout.png showing every piece and where it was cut. Existing files in the
set are only replaced with --force, so hand-cleaned tiles are safe.

Needs Pillow and numpy. Uses the same iso math as battle_art.py (and the game).
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import battle_art as ba  # noqa: E402

ROOT = ba.ROOT
SETS = ROOT / "game/art/source/battle"
OUT_SIZE = 512  # textures come out at this size; the game shrinks them to 256
TOP_TILES = 2  # matches BattleArt.TOP_TILES / SIDE_TILES / SIDE_LEVELS
SIDE_TILES = 2
SIDE_LEVELS = 4
EDGE = 0.04  # sample this far (in cells / levels) inside each patch, so neighbour colours and outlines don't bleed in
TOP_SKIP = 0.2  # side strips start this many levels below the face's top edge
SHADE_LIFT = 75 / 55  # shade faces are painted at value 55, the strip is stored at lit value 75 (B11)

TOPS = {"g": "top_grass", "f": "top_forest", "w": "top_water", "r": "top_rock", "d": "top_road", "s": "top_stone"}
SIDE_OF = {"g": "side_cliff", "f": "side_cliff", "r": "side_cliff", "d": "side_cliff",
           "s": "side_masonry", "t": "side_masonry", "u": "side_masonry", "w": "side_water"}


def load_map(name: str):
    data = json.loads((ba.MAPS / f"{name}.json").read_text())
    m = data["map"]
    w, h = m["w"], m["h"]
    heights = [[int(ch) for ch in row] for row in m["heights"]]
    rot = int(data.get("view", 0))
    iso = ba.Iso(w, h, ba.fit_origin(heights, w, h, rot), rot)
    return heights, m["terrain"], iso


def unwarp(src: Image.Image, p0, pu, pv, size: int) -> Image.Image:
    """Square texture whose (0,0), (1,0), (0,1) corners land on screen points p0, pu, pv."""
    a, b = (pu[0] - p0[0]) / size, (pv[0] - p0[0]) / size
    d, e = (pu[1] - p0[1]) / size, (pv[1] - p0[1]) / size
    return src.transform((size, size), Image.AFFINE, (a, b, p0[0], d, e, p0[1]), resample=Image.BICUBIC)


# --- tops ---------------------------------------------------------------------------------------

def top_patches(heights, terrain, iso: ba.Iso):
    """terrain letter -> the nearest 2 x 2 patch (x, y) of that terrain at one height."""
    best = {}
    for y in range(iso.h - 1):
        for x in range(iso.w - 1):
            cells = [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)]
            ts = {terrain[cy][cx] for cx, cy in cells}
            hs = {heights[cy][cx] for cx, cy in cells}
            if len(ts) != 1 or len(hs) != 1:
                continue
            t = ts.pop()
            if t not in TOPS:
                continue
            score = iso.depth(x + 0.5, y + 0.5)  # nearest patch: least likely to sit behind anything
            if t not in best or score > best[t][0]:
                best[t] = (score, x, y, hs.pop())
    return {t: v[1:] for t, v in best.items()}


def cut_top(src, iso: ba.Iso, x, y, lv):
    lo, hi = EDGE, TOP_TILES - EDGE
    p0 = iso.pt(x + lo, y + lo, lv)
    pu = iso.pt(x + hi, y + lo, lv)  # texture u runs along world x, v along world y (as in the game)
    pv = iso.pt(x + lo, y + hi, lv)
    outline = [iso.pt(x, y, lv), iso.pt(x + 2, y, lv), iso.pt(x + 2, y + 2, lv), iso.pt(x, y + 2, lv)]
    return unwarp(src, p0, pu, pv, OUT_SIZE), outline


# --- sides --------------------------------------------------------------------------------------

def side_runs(heights, terrain, iso: ba.Iso):
    """Visible faces grouped into runs of 2 neighbouring cells facing the same way.
    Returns material -> best (levels, lit, a0 world point, edge dir, top level)."""
    hgt = lambda c: heights[c[1]][c[0]] if 0 <= c[0] < iso.w and 0 <= c[1] < iso.h else ba.BASE
    faces = {}  # (cell, shade) -> (material, top, bottom, a, b)
    for y in range(iso.h):
        for x in range(iso.w):
            t = terrain[y][x]
            lv = heights[y][x]
            for shade in (False, True):
                d = iso.front_dir(shade)
                lo = max(ba.BASE, min(hgt((x + d[0], y + d[1])), lv))
                if lo < lv:
                    a, b = ba.side((x, y), d)
                    faces[((x, y), shade)] = (SIDE_OF.get(t, "side_cliff"), lv, lo, a, b)

    def clear(c, step, shade):  # nothing tall (trees, rocks, ruins) in front of the run or beside it
        d = iso.front_dir(shade)
        for k in (-1, 0, 1, 2):
            f = (c[0] + d[0] + step[0] * k, c[1] + d[1] + step[1] * k)
            if 0 <= f[0] < iso.w and 0 <= f[1] < iso.h and terrain[f[1]][f[0]] in "fru":
                return False
        return True

    best = {}
    for ((c, shade), (mat, top, lo, a, b)) in faces.items():
        step = (b[0] - a[0], b[1] - a[1])
        nxt = faces.get(((c[0] + step[0], c[1] + step[1]), shade))
        if nxt is None or nxt[0] != mat:
            continue
        hi = min(top, nxt[1])
        levels = hi - max(lo, nxt[2])
        if levels <= 0:
            continue
        # Prefer lit faces (their values are the strip's own); a shaded run only wins when no lit run is 2+ tall.
        score = (not shade and levels >= 2, min(levels, SIDE_LEVELS), clear(c, step, shade), levels)
        if mat not in best or score > best[mat][0]:
            best[mat] = (score, levels, not shade, a, step, hi)
    return {m: v[1:] for m, v in best.items()}


def cut_side(src, iso: ba.Iso, levels, lit, a0, step, top):
    """A 2-cell x 4-level strip, rolled so texture (0,0) sits where the game's UVs put it."""
    at = lambda s_, lv: iso.pt(a0[0] + step[0] * s_, a0[1] + step[1] * s_, lv)
    start = top - TOP_SKIP  # below the top edge's outline and the overhanging lip
    avail = levels - TOP_SKIP
    p0 = at(EDGE, start)
    pu = at(SIDE_TILES - EDGE, start)
    pv = at(EDGE, start - SIDE_LEVELS)
    strip = unwarp(src, p0, pu, pv, OUT_SIZE)
    arr = np.asarray(strip).copy()
    if avail < SIDE_LEVELS:  # not tall enough: repeat whole painted levels downward
        rows = int(OUT_SIZE * max(1, int(avail)) / SIDE_LEVELS)
        for j in range(rows, OUT_SIZE):
            arr[j] = arr[j % rows]
    if not lit:
        rgb = arr[..., :3].astype(np.float32) * SHADE_LIFT
        arr[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    # Game UVs: u = world coordinate along the edge / 2, v = -height / 4 (both wrap).
    along = a0[0] if step[0] else a0[1]
    du = int(round(((along / SIDE_TILES) % 1.0) * OUT_SIZE))
    dv = int(round(((-start / SIDE_LEVELS) % 1.0) * OUT_SIZE))
    arr = np.roll(np.roll(arr, du, axis=1), dv, axis=0)
    pw = at(SIDE_TILES - EDGE, start - SIDE_LEVELS)
    return Image.fromarray(arr), [p0, pu, pw, pv]


# --- props --------------------------------------------------------------------------------------

def blobs(alpha: np.ndarray, gap=12, min_px=400):
    """Connected shapes in an alpha mask (strokes closer than `gap` px join). Bounding boxes, left to right."""
    k = gap
    small = alpha[::k, ::k] > 16
    # grow by one cell so strokes a little apart join into one prop
    grown = small.copy()
    grown[1:, :] |= small[:-1, :]
    grown[:-1, :] |= small[1:, :]
    grown[:, 1:] |= small[:, :-1]
    grown[:, :-1] |= small[:, 1:]
    seen = np.zeros_like(grown)
    boxes = []
    hh, ww = grown.shape
    for sy in range(hh):
        for sx in range(ww):
            if not grown[sy, sx] or seen[sy, sx]:
                continue
            q = deque([(sy, sx)])
            seen[sy, sx] = True
            y0 = y1 = sy
            x0 = x1 = sx
            while q:
                cy, cx = q.popleft()
                y0, y1, x0, x1 = min(y0, cy), max(y1, cy), min(x0, cx), max(x1, cx)
                for ny, nx in ((cy + 1, cx), (cy - 1, cx), (cy, cx + 1), (cy, cx - 1)):
                    if 0 <= ny < hh and 0 <= nx < ww and grown[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        q.append((ny, nx))
            box = (max(0, (x0 - 1) * k), max(0, (y0 - 1) * k), min(alpha.shape[1], (x1 + 2) * k), min(alpha.shape[0], (y1 + 2) * k))
            if (alpha[box[1]:box[3], box[0]:box[2]] > 16).sum() >= min_px:
                boxes.append(box)
    return sorted(boxes)


def cut_prop(layer: Image.Image, box) -> Image.Image:
    """Crop to the shape, then pad so the feet (bottom rows' centre) sit at the bottom centre."""
    crop = layer.crop(box)
    a = np.asarray(crop)[..., 3]
    ys, xs = np.nonzero(a > 16)
    crop = crop.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    a = np.asarray(crop)[..., 3]
    foot_rows = a[-max(3, a.shape[0] // 12):]
    fx = np.nonzero(foot_rows.max(axis=0) > 16)[0]
    foot = (fx.min() + fx.max()) / 2
    half = int(max(foot, crop.width - foot)) + 4
    out = Image.new("RGBA", (half * 2, crop.height + 4), (0, 0, 0, 0))
    out.paste(crop, (int(round(half - foot)), 2))
    return out


# --- grid check ---------------------------------------------------------------------------------

def edge_map(src: Image.Image, reach=6) -> np.ndarray:
    """Where the painting has a visible edge, grown by `reach` px so small wobble still counts."""
    g = np.asarray(src.convert("L"), dtype=np.int16)
    mag = np.zeros_like(g)
    mag[:, 1:] = np.abs(np.diff(g, axis=1))
    mag[1:, :] = np.maximum(mag[1:, :], np.abs(np.diff(g, axis=0)))
    edge = mag > 14
    grown = edge.copy()
    for _ in range(reach):
        e = grown.copy()
        e[1:, :] |= grown[:-1, :]
        e[:-1, :] |= grown[1:, :]
        e[:, 1:] |= grown[:, :-1]
        e[:, :-1] |= grown[:, 1:]
        grown = e
    return grown


def grid_check(src, heights, terrain, iso: ba.Iso, block=80):
    """How well the painting kept the map: the share of the template blocking's own edges (block outlines,
    colour changes, height steps) that have a painted edge nearby. Returns (overall 0..1, weak boxes)."""
    want = edge_map(Image.alpha_composite(ba.paper(ba.CANVAS), ba.render_blocking(ba.map_faces(heights, terrain, iso), ba.CANVAS, iso)), reach=0)
    got = edge_map(src)
    hit = want & got
    weak = []
    for y0 in range(0, want.shape[0], block):
        for x0 in range(0, want.shape[1], block):
            n = want[y0:y0 + block, x0:x0 + block].sum()
            if n >= block // 2 and hit[y0:y0 + block, x0:x0 + block].sum() / n < 0.6:
                weak.append([(x0, y0), (x0 + block, y0), (x0 + block, y0 + block), (x0, y0 + block)])
    return (hit.sum() / max(1, want.sum())), weak


# --- main ---------------------------------------------------------------------------------------

def save(img: Image.Image, path: Path, force: bool, written: list, skipped: list):
    if path.exists() and not force:
        skipped.append(path.name)
        return
    img.save(path)
    written.append(path.name)


def contact_sheet(src, cuts, pieces, out_path: Path, weak=()):
    marked = src.convert("RGB").copy()
    dr = ImageDraw.Draw(marked)
    for poly in weak:  # cells whose outline the painting lost
        dr.polygon(poly, outline=(230, 120, 20), width=6)
    for name, poly in cuts:
        dr.polygon(poly, outline=(200, 40, 120), width=4)
        dr.text((poly[0][0] + 6, poly[0][1] + 4), name, fill=(200, 40, 120))
    thumb = 200
    cols = 6
    rows = (len(pieces) + cols - 1) // cols
    sheet = Image.new("RGB", (max(marked.width // 2, cols * (thumb + 20)), marked.height // 2 + rows * (thumb + 40) + 20), ba.PAPER)
    sheet.paste(marked.resize((marked.width // 2, marked.height // 2)), (0, 0))
    d2 = ImageDraw.Draw(sheet)
    for i, (name, img) in enumerate(pieces):
        x = 10 + (i % cols) * (thumb + 20)
        y = marked.height // 2 + 10 + (i // cols) * (thumb + 40)
        t = img.copy()
        t.thumbnail((thumb, thumb))
        bg = Image.new("RGBA", t.size, ba.PAPER + (255,))
        bg.alpha_composite(t.convert("RGBA"))
        sheet.paste(bg.convert("RGB"), (x, y))
        d2.text((x, y + thumb + 4), name, fill=ba.INK)
    sheet.save(out_path)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("painting", type=Path, help="the exported painting, exactly the template's size")
    ap.add_argument("--map", required=True, help="the map it was painted on (game/data/maps/<map>.json)")
    ap.add_argument("--set", required=True, help="tile set folder to write (game/art/source/battle/<set>/)")
    ap.add_argument("--props", type=Path, help="the exported 'paint 3 props' layer (transparent PNG)")
    ap.add_argument("--force", action="store_true", help="overwrite files already in the set")
    ap.add_argument("--check", action="store_true", help="only check how well the painting kept the grid; write nothing")
    args = ap.parse_args(argv)

    src = Image.open(args.painting).convert("RGBA")
    if src.size != ba.CANVAS and abs(src.width / src.height - ba.CANVAS[0] / ba.CANVAS[1]) < 0.01:
        print(f"scaling {src.width} x {src.height} up to {ba.CANVAS[0]} x {ba.CANVAS[1]} (same 3:2 shape)")
        src = src.resize(ba.CANVAS, Image.LANCZOS)
    if src.size != ba.CANVAS:
        sys.exit(f"{args.painting} is {src.size[0]} x {src.size[1]}; it must be {ba.CANVAS[0]} x {ba.CANVAS[1]} "
                 "(export the whole canvas, don't crop or resize)")
    heights, terrain, iso = load_map(args.map)
    fit, weak = grid_check(src, heights, terrain, iso)
    print(f"grid fit {fit:.0%} (share of the map's edges the painting kept; 85%+ is good)")
    if weak:
        print(f"{len(weak)} spot(s) drifted, marked orange on the sheet")
    if args.check:
        sheet = args.painting.with_name(args.painting.stem + "-gridcheck.png")
        contact_sheet(src, [], [], sheet, weak)
        print("grid check sheet:", sheet)
        return
    out = SETS / args.set
    out.mkdir(parents=True, exist_ok=True)
    written, skipped, cuts, pieces, notes = [], [], [], [], []

    patches = top_patches(heights, terrain, iso)
    for t, stem in TOPS.items():
        if t not in patches:
            notes.append(f"{stem}: no 2 x 2 patch of '{t}' at one height on this map")
            continue
        x, y, lv = patches[t]
        img, poly = cut_top(src, iso, x, y, lv)
        save(img.convert("RGB"), out / f"{stem}.png", args.force, written, skipped)
        cuts.append((stem, poly))
        pieces.append((stem, img))

    runs = side_runs(heights, terrain, iso)
    for stem in ("side_cliff", "side_masonry", "side_water"):
        if stem not in runs:
            notes.append(f"{stem}: no visible face run 2 cells wide on this map")
            continue
        levels, lit, a0, step, top = runs[stem]
        img, poly = cut_side(src, iso, levels, lit, a0, step, top)
        if levels - TOP_SKIP < SIDE_LEVELS:
            notes.append(f"{stem}: tallest clear face is {levels:g} level(s), whole levels repeated to make 4")
        save(img.convert("RGB"), out / f"{stem}.png", args.force, written, skipped)
        cuts.append((stem, poly))
        pieces.append((stem, img))

    if args.props:
        layer = Image.open(args.props).convert("RGBA")
        if layer.size != ba.CANVAS:
            sys.exit(f"{args.props} must be {ba.CANVAS[0]} x {ba.CANVAS[1]} like the painting")
        for i, box in enumerate(blobs(np.asarray(layer)[..., 3]), 1):
            img = cut_prop(layer, box)
            stem = f"prop_{i}"
            save(img, out / f"{stem}.png", args.force, written, skipped)
            cuts.append((stem, [(box[0], box[1]), (box[2], box[1]), (box[2], box[3]), (box[0], box[3])]))
            pieces.append((stem, img))

    sheet = args.painting.with_name(args.painting.stem + "-breakout.png")
    contact_sheet(src, cuts, pieces, sheet, weak)
    print(f"set {args.set}: wrote {len(written)} file(s) to {out.relative_to(ROOT)}")
    for n in written:
        print("  +", n)
    if skipped:
        print("kept (already there, use --force to replace):", ", ".join(skipped))
    for n in notes:
        print("note:", n)
    print("contact sheet:", sheet)


if __name__ == "__main__":
    main()
