#!/usr/bin/env python3
"""Scripted checks for a key art sampler picture: three isometric panels side by side.

    ~/.lodestone/venv/bin/python tools/art/sampler_check.py art/picsart/out/key-art-sampler/key-art-sampler_v8.png

Measures, per panel and for the whole picture:
  iso      share of strong edges that run along the 2:1 isometric directions (26.565 degrees either way, and
           vertical). Perspective horizons and sloped floor edges pull it down.
  ink      median width in pixels of the dark outline strokes. Brandon's look is thick; thin hairlines pull it down.

Nothing here reads the figures. Scale, structure and personality are the vision grade's job (see
art/prompts/sampler-grade-rubric.md), because a figure cannot be cut out of these panels reliably yet.

The bands in BANDS come from calibration on the sampler set (v8 approved template, v9 snowman, v10 jointed):
run the script on the set, then move the bands only with a reason written next to them.

The key is never needed. Nothing is sent anywhere; this only reads the picture.
"""

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

REPO = Path(__file__).resolve().parents[2]
SAMPLER_DIR = REPO / "art" / "picsart" / "out" / "key-art-sampler"

PANELS = 3
TRIM = 0.02  # fraction trimmed from each panel edge, so rules and margins are not measured
ISO_DEG = float(np.degrees(np.arctan(0.5)))  # 26.565: a 2:1 dimetric ground edge
ISO_TOL = 4.0  # degrees either side of an isometric direction
INK_LUMA = 90  # outline ink is about 55 luma (#373335); anything darker than this is ink
INK_MAX_RUN = 20  # a dark run longer than this is a shadow or a fill, not a stroke

# Bands set from calibration (see the sampler notes). None means not banded yet.
BANDS = {
    "iso": [0.17, 1.0],  # coarse: v8 0.177 and v10 0.187 pass; v9 0.161 and v5 to v7 0.155 to 0.163 fail
    "ink": [4.0, 8.0],  # v8 5 px and v10 6 px pass; v9 and v5 to v7 at 2 to 3 px fail as hairline
}


def load_panels(path):
    img = np.asarray(Image.open(path).convert("RGB")).astype(float)
    h, w, _ = img.shape
    panels = []
    for i in range(PANELS):
        x0 = int(w * i / PANELS + w * TRIM)
        x1 = int(w * (i + 1) / PANELS - w * TRIM)
        panels.append(img[int(h * TRIM):int(h * (1 - TRIM)), x0:x1])
    return panels


def luma(rgb):
    return rgb @ np.array([0.299, 0.587, 0.114])


def sobel(g):
    p = np.pad(g, 1, mode="edge")
    gx = (p[:-2, 2:] + 2 * p[1:-1, 2:] + p[2:, 2:]) - (p[:-2, :-2] + 2 * p[1:-1, :-2] + p[2:, :-2])
    gy = (p[2:, :-2] + 2 * p[2:, 1:-1] + p[2:, 2:]) - (p[:-2, :-2] + 2 * p[:-2, 1:-1] + p[:-2, 2:])
    return gx, gy


def iso_share(panel):
    """Share of the strongest 10% of edges that lie along an isometric direction."""
    gx, gy = sobel(luma(panel))
    mag = np.hypot(gx, gy)
    strong = mag > np.percentile(mag, 90)
    # An edge runs perpendicular to its gradient. Fold angles into [0, 180).
    line = (np.degrees(np.arctan2(gy, gx)) + 90.0) % 180.0
    dist = np.full(line.shape, 180.0)
    for target in (ISO_DEG, 180.0 - ISO_DEG, 90.0):
        diff = np.abs((line - target + 90.0) % 180.0 - 90.0)
        dist = np.minimum(dist, diff)
    return float(((dist <= ISO_TOL) & strong).sum() / max(strong.sum(), 1))


def run_lengths(mask):
    m = np.pad(mask.astype(np.int8), ((0, 0), (1, 1)))
    d = np.diff(m, axis=1)
    starts = np.where(d == 1)
    ends = np.where(d == -1)
    return ends[1] - starts[1]


def ink_width(panel):
    """Median width of dark strokes, measured across rows and columns."""
    dark = luma(panel) < INK_LUMA
    lengths = np.concatenate([run_lengths(dark), run_lengths(dark.T)])
    strokes = lengths[(lengths >= 1) & (lengths <= INK_MAX_RUN)]
    return float(np.median(strokes)) if strokes.size else 0.0


def check(path):
    panels = load_panels(path)
    per_panel = [{"panel": i + 1, "iso": round(iso_share(p), 3), "ink": round(ink_width(p), 2)}
                 for i, p in enumerate(panels)]
    overall = {
        "iso": round(float(np.mean([r["iso"] for r in per_panel])), 3),
        "ink": round(float(np.median([r["ink"] for r in per_panel])), 2),
    }
    verdict = {}
    for key in ("iso", "ink"):
        band = BANDS[key]
        verdict[key] = None if band is None else bool(band[0] <= overall[key] <= band[1])
    return {"image": path.name, "panels": per_panel, "overall": overall, "bands": BANDS, "pass": verdict}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("images", nargs="+", type=Path)
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()
    results = [check(p) for p in args.images]
    if args.json:
        print(json.dumps(results, indent=2))
        return
    for r in results:
        print("%s  iso %.3f  ink %.2f px" % (r["image"], r["overall"]["iso"], r["overall"]["ink"]))
        for p in r["panels"]:
            print("   panel %d  iso %.3f  ink %.2f" % (p["panel"], p["iso"], p["ink"]))


if __name__ == "__main__":
    main()
