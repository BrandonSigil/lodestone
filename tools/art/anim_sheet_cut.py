#!/usr/bin/env python3
"""Cut a generated character animation sheet (art/prompts/sheet-character-anim.txt) into sprite strips.

    python3 tools/art/anim_sheet_cut.py art/picsart/out/anim-lead-se_v1.png --id lead --dir se
    python3 tools/art/anim_sheet_cut.py art/picsart/out/anim-lead-ne_v1.png --id lead --dir ne

The sheet is five rows of separate figures on cream: idle 4, walk 6, swing 6, cast 6, hurt 2 + down 2.
The paper is keyed off (char_art.key_background), rows are found from the empty bands between them and
figures from the gaps inside a row (a spark or sweat drop above a figure joins the figure it sits over).
Every frame is scaled by one factor per sheet (the idle figures come out HERO_H tall) and placed in a
192 x 192 frame with its feet on the anchor (96, 160), as docs/art/characters.md C2 and C18 ask.

Writes game/art/source/characters/<id>/<id>_<anim>_<dir>.png strips, <id>_stand_<dir>.png, and updates
<id>.json (anims, fps, hit frames, drawn dirs, mirror table: C16, C28). Prints a frame count per row;
a row with a different count than expected is still written, with its own count in the json.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from char_art import key_background  # noqa: E402

REPO = Path(__file__).resolve().parents[2]
OUT = REPO / "game" / "art" / "source" / "characters"
FRAME = 192
ANCHOR = (96, 160)
HERO_H = 94  # idle body height in art px (wide rows only, see body_height); hair tips reach about 108 (C3)

# Rows of the sheet: (anim, expected frames). Row 5 holds hurt and down.
ROWS = [("idle", 4), ("walk", 6), ("attack", 6), ("cast", 6), ("hurt_down", 4)]
ANIMS = {  # C16; ready and advance are idle and walk with the weapon out (combat stance)
    "idle": {"fps": 6, "loop": True},
    "ready": {"fps": 6, "loop": True},
    "advance": {"fps": 10, "loop": True},
    "walk": {"fps": 10, "loop": True},
    "attack": {"fps": 12, "loop": False, "hit": 2},
    "cast": {"fps": 10, "loop": False, "hit": 3},
    "hurt": {"fps": 8, "loop": False},
    "down": {"fps": 6, "loop": False},
}


def runs(mask, min_len, min_gap=1):
    """(start, end) of each run of True at least min_len long; gaps shorter than min_gap are bridged."""
    out = []
    start, gap = None, 0
    for i, v in enumerate(list(mask) + [False] * (min_gap + 1)):
        if v:
            if start is None:
                start = i
            gap = 0
        elif start is not None:
            gap += 1
            if gap >= min_gap:
                end = i - gap + 1
                if end - start >= min_len:
                    out.append((start, end))
                start, gap = None, 0
    return out


def figures(alpha, y0, y1, want):
    """Bounding boxes of the figures in one row band, left to right. When swords or cloaks bridge two
    figures, split at the midpoints between heads instead (found in the top part of the band)."""
    band = alpha[y0:y1] > 128
    cols = runs(band.any(axis=0), 12, min_gap=6)
    if len(cols) < want:
        for k in (0.25, 0.35, 0.45, 0.55):
            heads = runs(band[: int(band.shape[0] * k)].any(axis=0), 12, min_gap=6)
            if len(heads) == want:
                mids = [(heads[i][1] + heads[i + 1][0]) // 2 for i in range(want - 1)]
                edges = [cols[0][0]] + mids + [cols[-1][1]]
                cols = [(edges[i], edges[i + 1]) for i in range(want)]
                break
    boxes = []
    for x0, x1 in cols:
        sub = band[:, x0:x1]
        ys = np.nonzero(sub.any(axis=1))[0]
        if ys.size and sub.sum() > 400:
            boxes.append((x0, y0 + ys[0], x1, y0 + ys[-1] + 1))
    return boxes


def body_height(alpha, box):
    """Height of the rows at least a quarter as wide as the widest row: the body, not a thin blade."""
    x0, y0, x1, y1 = box
    widths = (alpha[y0:y1, x0:x1] > 128).sum(axis=1)
    rows = np.nonzero(widths >= widths.max() * 0.25)[0]
    return rows[-1] - rows[0] + 1 if rows.size else y1 - y0


def feet_x(alpha, box):
    """Centre of the opaque pixels in the bottom 10% of the figure."""
    x0, y0, x1, y1 = box
    h = max(4, (y1 - y0) // 10)
    xs = np.nonzero(alpha[y1 - h:y1, x0:x1] > 128)[1]
    return x0 + (xs.mean() if xs.size else (x1 - x0) / 2)


def body_x(alpha, box):
    """Centre of the opaque pixels from the hair line to the hips (15% to 55% down the figure). Walk and
    idle frames pin on this so the body holds still while the legs move; pinning on the feet made the
    whole figure lurch sideways every step."""
    x0, y0, x1, y1 = box
    h = y1 - y0
    xs = np.nonzero(alpha[y0 + int(h * 0.15):y0 + int(h * 0.55), x0:x1] > 128)[1]
    return x0 + (xs.mean() if xs.size else (x1 - x0) / 2)


# Rows that loop in place pin on the body; one-shot moves (swing, cast, hurt) pin on the feet so a lunge
# still travels.
PIN_BODY = {"idle", "walk", "ready", "advance"}


def place(rgba, alpha, box, scale, pin=feet_x):
    x0, y0, x1, y1 = box
    fx = pin(alpha, box)
    crop = rgba.crop(box)
    w, h = max(1, round(crop.width * scale)), max(1, round(crop.height * scale))
    crop = crop.resize((w, h), Image.LANCZOS)
    frame = Image.new("RGBA", (FRAME, FRAME))
    frame.paste(crop, (round(ANCHOR[0] - (fx - x0) * scale), ANCHOR[1] - h), crop)  # paste clips at the frame edge
    return frame


def strip(frames):
    s = Image.new("RGBA", (FRAME * len(frames), FRAME))
    for i, f in enumerate(frames):
        s.paste(f, (i * FRAME, 0))
    return s


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet")
    ap.add_argument("--id", required=True, help="character id (game/data/characters/<id>.tres)")
    ap.add_argument("--dir", required=True, choices=["s", "se", "e", "ne", "n", "sw", "w", "nw"])
    ap.add_argument("--rows", help="rows of this sheet as anim:frames,... (default: the full animation sheet);"
                    " e.g. ready:4,advance:6 for sheet-character-stance.txt")
    args = ap.parse_args()
    rows_spec = ROWS if not args.rows else [(a, int(n)) for a, n in (r.split(":") for r in args.rows.split(","))]

    rgba = key_background(Image.open(args.sheet).convert("RGB"))
    alpha = np.asarray(rgba.getchannel("A"))
    profile = (alpha > 128).sum(axis=1)
    rows = runs(profile > 8, 40, min_gap=10)
    # A sword tip or spark can bridge two rows: split the tallest band at its thinnest line (middle half).
    while 0 < len(rows) < len(rows_spec):
        k = max(range(len(rows)), key=lambda i: rows[i][1] - rows[i][0])
        y0, y1 = rows[k]
        q = (y1 - y0) // 4
        cut = y0 + q + int(np.argmin(profile[y0 + q:y1 - q]))
        rows[k:k + 1] = [(y0, cut), (cut + 1, y1)]
    if len(rows) != len(rows_spec):
        sys.exit("found %d rows, expected %d: is this the right sheet for --rows?" % (len(rows), len(rows_spec)))
    boxes = [figures(alpha, y0, y1, want) for (y0, y1), (_, want) in zip(rows, rows_spec)]
    # One scale per sheet: the first row's figures (idle or ready) come out HERO_H tall, measured on the
    # body only so a sword held over the head doesn't shrink the character.
    idle_h = float(np.median([body_height(alpha, b) for b in boxes[0]]))
    scale = HERO_H / idle_h

    out = OUT / args.id
    out.mkdir(parents=True, exist_ok=True)
    meta_path = out / (args.id + ".json")
    meta = json.loads(meta_path.read_text()) if meta_path.exists() else {
        "id": args.id, "class": "hero", "frame": FRAME, "anchor": list(ANCHOR), "scale": 0.5,
        "mirror": {"sw": "se", "w": "e", "nw": "ne"}, "dirs": [], "anims": {}}

    def write(anim, frames):
        strip(frames).save(out / ("%s_%s_%s.png" % (args.id, anim, args.dir)))
        spec = dict(ANIMS[anim], frames=len(frames))
        if "hit" in spec:
            spec["hit"] = min(spec["hit"], len(frames) - 1)
        old = meta["anims"].get(anim)
        if old and old["frames"] != spec["frames"]:
            print("  note: %s has %d frames in another facing, %d here" % (anim, old["frames"], spec["frames"]))
            spec["frames"] = min(old["frames"], spec["frames"])
        meta["anims"][anim] = spec

    for (anim, want), bx in zip(rows_spec, boxes):
        pin = body_x if anim in PIN_BODY else feet_x
        frames = [place(rgba, alpha, b, scale, pin) for b in bx]
        flag = "" if len(frames) == want else "  (expected %d)" % want
        print("  %s: %d frames%s" % (anim, len(frames), flag))
        if anim == "hurt_down":
            half = max(1, len(frames) // 2)
            write("hurt", frames[:half])
            write("down", frames[half:] or frames[-1:])
        else:
            write(anim, frames)
        if anim == "idle":
            frames[0].save(out / ("%s_stand_%s.png" % (args.id, args.dir)))
    if args.dir not in meta["dirs"]:
        meta["dirs"].append(args.dir)
    meta_path.write_text(json.dumps(meta, indent=1) + "\n")
    print("scale %.3f, wrote %s" % (scale, out))


if __name__ == "__main__":
    main()
