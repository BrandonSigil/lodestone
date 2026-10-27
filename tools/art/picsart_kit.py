#!/usr/bin/env python3
"""Generate the first battle-map texture and prop kit with Picsart.

Usage:
  python tools/art/picsart_kit.py                 # generate missing raws, then process all
  python tools/art/picsart_kit.py --only top_grass,prop_bush --regen
  python tools/art/picsart_kit.py --process-only  # rebuild finals from saved raws

Assets and prompts live in tools/art/picsart_kit.json. Raw model output (and
background-removed cutouts) go to art/picsart/kit/raw (git LFS, so the game
never loads them). Finals go to game/art/source/battle/:
  textures: 512 x 512 RGB, seamless, mean colour matched to the target hex
  props:    RGBA, trimmed, max 256 px tall, base contact point at bottom centre
A contact sheet goes to art/picsart/kit_contact.png and a downscaled
copy to docs/art/battle-maps/kit-contact.png.
"""

import argparse
import io
import json
import sys
from pathlib import Path

import requests
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageStat

sys.path.insert(0, str(Path(__file__).resolve().parent))
import picsart_render as pr  # noqa: E402

REPO = pr.REPO
KIT_JSON = Path(__file__).with_suffix(".json")
ART = REPO / "art" / "picsart"
RAW = ART / "kit" / "raw"
FINAL = REPO / "game" / "art" / "source" / "battle"
CONTACT = ART / "kit_contact.png"
CONTACT_DOC = REPO / "docs" / "art" / "battle-maps" / "kit-contact.png"

TEX_SIZE = 512
PROP_MAX_H = 256
CREAM = pr.PAPER


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


# ---------------------------------------------------------------- generation

def generate_raw(key, cfg, name, prompt, aspect):
    params = {"prompt": prompt, "aspectRatio": aspect,
              "resolution": cfg["resolution"], "count": 1}
    for attempt in range(3):
        try:
            urls, charged = pr.generate(key, cfg["model"], params)
            break
        except SystemExit as e:  # vendor 5xx errors are usually transient
            print("  %s: %s, retrying" % (name, str(e)[:120]))
    else:
        sys.exit("giving up on " + name)
    img = Image.open(io.BytesIO(requests.get(urls[0], timeout=120).content))
    img.save(RAW / (name + "_raw.png"))
    print("  %s: generated %dx%d, charged %s" % (name, img.width, img.height, charged))
    return charged or 0


def remove_bg(key, name):
    """Picsart removebg on the raw prop; saves <name>_cut.png. False on failure."""
    src = RAW / (name + "_raw.png")
    try:
        r = requests.post(pr.TOOLS + "/removebg", headers={"X-Picsart-API-Key": key},
                          files={"image": (src.name, src.read_bytes(), "image/png")},
                          data={"output_type": "cutout", "format": "PNG"}, timeout=180)
        r.raise_for_status()
        url = r.json()["data"]["url"]
        Image.open(io.BytesIO(requests.get(url, timeout=120).content)).save(RAW / (name + "_cut.png"))
        print("  %s: background removed" % name)
        return True
    except Exception as e:  # fall back to the cream key in process_prop
        print("  %s: removebg failed (%s), using cream key" % (name, str(e)[:120]))
        return False


# ---------------------------------------------------------------- textures

def make_seamless(img, feather):
    """Offset by half and cross-fade: the edges come from the rolled copy (which
    wraps cleanly) and the middle from the original (which has no seam there)."""
    if isinstance(feather, (int, float)):
        feather = (feather, feather)
    fx, fy = feather  # 0 = that axis already wraps, leave it alone
    w, h = img.size
    rolled = ImageChops.offset(img, w // 2 if fx else 0, h // 2 if fy else 0)
    mask = Image.new("L", (w, h))
    px = mask.load()
    for y in range(h):
        wy = min(1.0, min(y, h - 1 - y) / fy) if fy else 1.0
        for x in range(w):
            wx = min(1.0, min(x, w - 1 - x) / fx) if fx else 1.0
            px[x, y] = int(255 * wx * wy)
    return Image.composite(img, rolled, mask)


def color_match(img, target, max_std):
    """Shift each channel so its mean equals the target, keeping the variation
    but scaling it down if the luminance spread exceeds max_std (B20)."""
    stat = ImageStat.Stat(img)
    lum_std = ImageStat.Stat(img.convert("L")).stddev[0]
    k = min(1.0, max_std / lum_std) if lum_std else 1.0
    bands = []
    for band, mean, t in zip(img.split(), stat.mean, target):
        bands.append(band.point(lambda v, m=mean, t=t: max(0, min(255, round(t + (v - m) * k)))))
    return Image.merge("RGB", bands), k


def joint_peaks(img, axis):
    """Positions of dark joint lines along axis ('x' = vertical joints), found
    as peaks in the row/column mean darkness."""
    g = img.convert("L")
    n = g.width if axis == "x" else g.height
    prof = g.resize((n, 1) if axis == "x" else (1, n), Image.BOX)
    dark = [255 - v for v in prof.get_flattened_data()]
    mean = sum(dark) / n
    std = (sum((d - mean) ** 2 for d in dark) / n) ** 0.5
    thr = mean + 1.2 * std
    peaks, run = [], []
    for i, d in enumerate(dark + [0]):
        if d > thr:
            run.append(i)
        elif run:
            peaks.append(sum(run) / len(run))
            run = []
    return [round(p) for p in peaks], n


def joint_span(img, axis, count):
    """(a, b) spanning exactly `count` joint periods, cut through the middle of a
    joint at both ends so tiling closes the joint. None if not enough joints."""
    peaks, n = joint_peaks(img, axis)
    best = None
    for i in range(len(peaks) - count):
        a, b = peaks[i], peaks[i + count]
        off = abs((a + b) / 2 - n / 2)
        if best is None or off < best[0]:
            best = (off, a, b)
    return best[1:] if best else None


def wrap_span(img, axis, a, length):
    """(a, b) with b near a + length chosen so the line at b best matches the
    line at a, for patterns without regular joints along this axis."""
    n = img.width if axis == "x" else img.height
    line = lambda p: img.crop((p, 0, p + 1, img.height) if axis == "x" else (0, p, img.width, p + 1))
    ref = line(a)
    best = None
    for b in range(a + int(length * 0.85), min(n, a + int(length * 1.15))):
        d = sum(ImageStat.Stat(ImageChops.difference(ref, line(b))).mean)
        if best is None or d < best[0]:
            best = (d, b)
    return a, best[1]


def joint_crop(raw, t):
    """Crop structured textures (slabs, block rows, brick courses) on their
    joints so the tile wraps on a joint and needs little or no blending."""
    rows, cols = t.get("joint_rows"), t.get("joint_cols")
    ys = joint_span(raw, "y", rows) if rows else None
    if not ys:
        return None
    xs = joint_span(raw, "x", cols) if cols else None
    if not xs:
        length = ys[1] - ys[0]
        start = max(0, (raw.width - length) // 2 - length // 10)
        xs = wrap_span(raw, "x", start, length)
    print("  %s: joint crop x %s y %s" % (t["name"], xs, ys))
    return raw.crop((xs[0], ys[0], xs[1], ys[1]))


def process_texture(t):
    raw = Image.open(RAW / (t["name"] + "_raw.png")).convert("RGB")
    cut = joint_crop(raw, t) if ("joint_rows" in t) else None
    if cut is None:
        s = min(raw.size)
        # Center square, then trim 6% off each side to drop any edge vignette.
        m = round(s * 0.06)
        left, top = (raw.width - s) // 2 + m, (raw.height - s) // 2 + m
        cut = raw.crop((left, top, left + s - 2 * m, top + s - 2 * m))
    sq = cut.resize((TEX_SIZE, TEX_SIZE), Image.LANCZOS)
    feather = t.get("feather", 96)
    tile = make_seamless(sq, feather) if feather and feather != [0, 0] else sq
    tile, k = color_match(tile, hex_rgb(t["target"]), t["contrast"])
    tile.save(FINAL / (t["name"] + ".png"))
    seam = seam_error(tile)
    mean = tuple(round(v) for v in ImageStat.Stat(tile).mean)
    print("  %s: mean %s (target %s), contrast x%.2f, seam err %.1f (interior %.1f)"
          % (t["name"], "#%02x%02x%02x" % mean, t["target"], k, seam[0], seam[1]))
    return tile


def seam_error(img):
    """Mean abs difference across the wrap seam vs across an interior column."""
    w, h = img.size
    a, b = img.crop((w - 1, 0, w, h)), img.crop((0, 0, 1, h))
    c, d = img.crop((w // 2 - 1, 0, w // 2, h)), img.crop((w // 2, 0, w // 2 + 1, h))
    diff = lambda p, q: sum(ImageStat.Stat(ImageChops.difference(p, q)).mean) / 3
    return diff(a, b), diff(c, d)


# ---------------------------------------------------------------- props

def cream_key(img, tol=28):
    diff = ImageChops.difference(img.convert("RGB"), Image.new("RGB", img.size, CREAM)).convert("L")
    return diff.point(lambda v: 0 if v < tol else (255 if v > tol * 2 else int(255 * (v - tol) / tol)))


def decontaminate(rgba):
    """Undo cream blending in soft edge pixels, drop near-clear ones, then
    shave one pixel off the alpha so no cream halo survives."""
    r, g, b, a = rgba.split()
    a = a.point(lambda v: 0 if v < 40 else v)
    px, ap = rgba.load(), a.load()
    w, h = rgba.size
    out = Image.new("RGBA", rgba.size)
    op = out.load()
    for y in range(h):
        for x in range(w):
            al = ap[x, y]
            if al == 0:
                continue
            c = px[x, y]
            if al < 250:
                f = al / 255.0
                c = tuple(max(0, min(255, round((c[i] - (1 - f) * CREAM[i]) / f))) for i in range(3))
            op[x, y] = (c[0], c[1], c[2], al)
    # Erode alpha by one pixel: removes the last ring of cream-tinted edge.
    eroded = out.getchannel("A").filter(ImageFilter.MinFilter(3))
    out.putalpha(eroded)
    return out


def keep_largest(rgba):
    """Drop specks: keep alpha only inside the bounding box of the main blob
    (cheap: threshold, close, take the biggest connected run via flood fill)."""
    a = rgba.getchannel("A").point(lambda v: 255 if v > 0 else 0)
    w, h = a.size
    seen = bytearray(w * h)
    ap = a.load()
    best = []
    for sy in range(0, h, 2):
        for sx in range(0, w, 2):
            if ap[sx, sy] and not seen[sy * w + sx]:
                stack, comp = [(sx, sy)], []
                seen[sy * w + sx] = 1
                while stack:
                    x, y = stack.pop()
                    comp.append((x, y))
                    for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                        if 0 <= nx < w and 0 <= ny < h and ap[nx, ny] and not seen[ny * w + nx]:
                            seen[ny * w + nx] = 1
                            stack.append((nx, ny))
                if len(comp) > len(best):
                    best = comp
    mask = Image.new("L", (w, h))
    mp = mask.load()
    for x, y in best:
        mp[x, y] = 255
    out = rgba.copy()
    out.putalpha(ImageChops.multiply(rgba.getchannel("A"), mask))
    return out


def fill_holes(alpha):
    """Make clear areas that do not reach the image border opaque: pale
    highlights and flame cores look like cream to the key but are inside."""
    w, h = alpha.size
    m = Image.new("L", (w + 2, h + 2), 0)
    m.paste(alpha.point(lambda v: 255 if v >= 128 else 0), (1, 1))
    ImageDraw.floodfill(m, (0, 0), 128)
    holes = m.crop((1, 1, w + 1, h + 1)).point(lambda v: 255 if v == 0 else 0)
    return ImageChops.lighter(alpha, holes)


def process_prop(p):
    raw = Image.open(RAW / (p["name"] + "_raw.png")).convert("RGB")
    cut_path = RAW / (p["name"] + "_cut.png")
    if cut_path.exists():
        cut = Image.open(cut_path).convert("RGBA").resize(raw.size)
        # Combine with a cream key so Picsart's soft fringe on cream goes too.
        alpha = ImageChops.darker(cut.getchannel("A"), cream_key(raw, 14))
    else:
        alpha = cream_key(raw)
    rgba = raw.convert("RGBA")
    rgba.putalpha(fill_holes(alpha))
    rgba = keep_largest(decontaminate(rgba))
    rgba = rgba.crop(rgba.getchannel("A").getbbox())
    if rgba.height > PROP_MAX_H:
        rgba = rgba.resize((round(rgba.width * PROP_MAX_H / rgba.height), PROP_MAX_H), Image.LANCZOS)
    # Base contact: centre of the opaque pixels in the bottom 4% of rows.
    a = rgba.getchannel("A")
    band = max(2, rgba.height // 25)
    xs = [x for y in range(rgba.height - band, rgba.height)
          for x in range(rgba.width) if a.getpixel((x, y)) > 128]
    cx = round(sum(xs) / len(xs)) if xs else rgba.width // 2
    half = max(cx, rgba.width - cx)
    out = Image.new("RGBA", (2 * half, rgba.height))
    out.paste(rgba, (half - cx, 0))
    out.save(FINAL / (p["name"] + ".png"))
    print("  %s: %dx%d, contact x %d -> centre" % (p["name"], out.width, out.height, cx))
    return out


# ---------------------------------------------------------------- contact sheet

def contact_sheet(textures, props):
    cell = 384
    cols = 3
    rows_t = (len(textures) + cols - 1) // cols
    prop_h = PROP_MAX_H + 40
    width = cols * (cell + 24) + 24
    # Lay props out in rows that fit the sheet width.
    prop_rows, x = [[]], 24
    for name, prop in props:
        if x + prop.width + 24 > width and prop_rows[-1]:
            prop_rows.append([])
            x = 24
        prop_rows[-1].append((name, prop))
        x += prop.width + 24
    sheet = Image.new("RGB", (width, rows_t * (cell + 24) + 24 + len(prop_rows) * prop_h), CREAM)
    for i, (name, tile) in enumerate(textures):
        tiled = Image.new("RGB", (TEX_SIZE * 2, TEX_SIZE * 2))
        for dx in (0, 1):
            for dy in (0, 1):
                tiled.paste(tile, (dx * TEX_SIZE, dy * TEX_SIZE))
        x, y = 24 + (i % cols) * (cell + 24), 24 + (i // cols) * (cell + 24)
        sheet.paste(tiled.resize((cell, cell), Image.LANCZOS), (x, y))
    for r, row in enumerate(prop_rows):
        y0 = 24 + rows_t * (cell + 24) + r * prop_h
        x = 24
        for name, prop in row:
            sheet.paste(prop, (x, y0 + PROP_MAX_H - prop.height), prop)
            x += prop.width + 24
    CONTACT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(CONTACT)
    small = sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS)
    small.save(CONTACT_DOC, optimize=True)
    print("contact sheet:", CONTACT, "and", CONTACT_DOC.relative_to(REPO))


# ---------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", help="comma-separated asset names to (re)generate")
    ap.add_argument("--regen", action="store_true", help="regenerate even if a raw exists")
    ap.add_argument("--process-only", action="store_true", help="no API calls")
    ap.add_argument("--budget", type=float, default=1.50, help="stop generating past this spend")
    args = ap.parse_args()

    cfg = json.loads(KIT_JSON.read_text(encoding="utf-8"))
    only = set(args.only.split(",")) if args.only else None
    RAW.mkdir(parents=True, exist_ok=True)
    FINAL.mkdir(parents=True, exist_ok=True)

    if not args.process_only:
        key = pr.api_key()
        before = pr.balance(key)
        print("credits before:", before)
        spent = 0.0
        jobs = [(t, "texture") for t in cfg["textures"]] + [(p, "prop") for p in cfg["props"]]
        for a, kind in jobs:
            if only and a["name"] not in only:
                continue
            if (RAW / (a["name"] + "_raw.png")).exists() and not args.regen:
                continue
            if spent >= args.budget:
                print("budget reached, skipping", a["name"])
                continue
            if kind == "texture":
                prompt = "%s %s Avoid: %s" % (cfg["texture_style"], a["prompt"], cfg["texture_avoid"])
                spent += generate_raw(key, cfg, a["name"], prompt, "1:1")
            else:
                prompt = "%s %s Avoid: %s" % (cfg["prop_style"], a["prompt"], cfg["prop_avoid"])
                spent += generate_raw(key, cfg, a["name"], prompt, a.get("aspect", "1:1"))
                (RAW / (a["name"] + "_cut.png")).unlink(missing_ok=True)
                remove_bg(key, a["name"])
        after = pr.balance(key)
        print("credits after:", after, "(used %.4f)" % (float(before) - float(after)))

    textures = [(t["name"], process_texture(t)) for t in cfg["textures"]
                if (RAW / (t["name"] + "_raw.png")).exists()]
    props = [(p["name"], process_prop(p)) for p in cfg["props"]
             if (RAW / (p["name"] + "_raw.png")).exists()]
    contact_sheet(textures, props)


if __name__ == "__main__":
    main()
