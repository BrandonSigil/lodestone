#!/usr/bin/env python3
"""Does a prop's art sit on the 2:1 dimetric grid? Checks the ground-plane edges of each prop PNG.

    ~/.lodestone/venv/bin/python tools/art/prop_iso_check.py game/art/source/battle/village/prop_crops.png ...

Takes the strong edges of the picture (its silhouette against transparency and its inked lines), leaves out the
vertical ones (uprights stay vertical), and measures how far the rest lie from the two grid directions, 26.565 degrees
down-right and down-left. Reports each direction's dominant (median) angle and the worst miss. A prop passes when both are within TOL of 26.565. A bed, fence or boat drawn at
about 40 degrees (true isometric or a plan view) fails here; the sampler check only scores whole pictures. Round things (reeds, hay) have no
straight edges, so read their numbers with care. The approved fence (31.7 / -26.2) is the calibration.
Exit status 1 if any prop fails. Nothing is sent anywhere.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ISO_DEG = float(np.degrees(np.arctan(0.5)))  # 26.565
TOL = 10.0  # degrees: each direction's dominant edge angle must be within this of 26.565 (the approved fence misses by 8.5)


def edges(path):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im, dtype=float)
    alpha = a[..., 3] / 255.0
    luma = (a[..., :3] @ np.array([0.299, 0.587, 0.114])) * alpha
    out = []
    for ch in (alpha * 255.0, luma):
        p = np.pad(ch, 1, mode="edge")
        gx = (p[:-2, 2:] + 2 * p[1:-1, 2:] + p[2:, 2:]) - (p[:-2, :-2] + 2 * p[1:-1, :-2] + p[2:, :-2])
        gy = (p[2:, :-2] + 2 * p[2:, 1:-1] + p[2:, 2:]) - (p[:-2, :-2] + 2 * p[:-2, 1:-1] + p[:-2, 2:])
        mag = np.hypot(gx, gy)
        strong = mag > max(np.percentile(mag, 92), 1e-6)
        line = (np.degrees(np.arctan2(gy, gx)) + 90.0) % 180.0  # the edge runs across its gradient
        out.append(line[strong])
    return np.concatenate(out)


def check(path):
    line = edges(path)
    # angle from horizontal, down-right (+) or down-left (-): fold to -90..90, drop the near-vertical
    ang = (line + 90.0) % 180.0 - 90.0
    sloped = ang[np.abs(ang) < 70.0]
    right = sloped[(sloped > 12) & (sloped < 70)]
    left = sloped[(sloped < -12) & (sloped > -70)]
    dom = lambda v: float(np.median(v)) if v.size >= 20 else None
    dr, dl = dom(right), dom(left)
    off = [abs(abs(d) - ISO_DEG) for d in (dr, dl) if d is not None]
    worst = max(off) if off else 0.0
    return {"prop": Path(path).name, "down_right": None if dr is None else round(dr, 1),
            "down_left": None if dl is None else round(dl, 1), "worst_miss": round(worst, 1), "pass": worst <= TOL}


if __name__ == "__main__":
    bad = False
    for f in sys.argv[1:]:
        r = check(f)
        bad |= not r["pass"]
        print(("ok   " if r["pass"] else "FAIL ") + str(r))
    sys.exit(1 if bad else 0)
