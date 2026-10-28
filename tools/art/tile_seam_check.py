#!/usr/bin/env python3
"""Score how well top tiles repeat: do the left and right edges meet, and the top and bottom?

Read-only. For each PNG it compares the wrap-around edge pairs (last column against first, last row
against first) with the typical step between neighbouring pixels inside the tile. A ratio near 1 means
the seam is no harder than the tile's own texture, so the tile repeats cleanly. Large ratios mean a
visible seam when the tile is placed next to itself.

    ~/.lodestone/venv/bin/python3 tools/art/tile_seam_check.py game/art/source/battle/snow/top_*.png
Needs Pillow and numpy.
"""
import sys

import numpy as np
from PIL import Image

LIMIT = 1.6  # above this ratio the seam is visible in play


def load(path: str) -> np.ndarray:
    im = Image.open(path).convert("RGBA")
    rgba = np.asarray(im, dtype=np.float32)
    return rgba[..., :3]


def seam_ratio(img: np.ndarray) -> tuple:
    """Return (horizontal ratio, vertical ratio). Each is seam difference / interior step."""
    # Interior steps: difference between neighbouring pixels, excluding the wrap pair.
    dx = np.abs(np.diff(img, axis=1)).mean()
    dy = np.abs(np.diff(img, axis=0)).mean()
    # Seam steps: last column against first column, last row against first row.
    sx = np.abs(img[:, -1, :] - img[:, 0, :]).mean()
    sy = np.abs(img[-1, :, :] - img[0, :, :]).mean()
    eps = 1e-6
    return sx / (dx + eps), sy / (dy + eps)


def main() -> None:
    paths = sys.argv[1:]
    if not paths:
        print(__doc__)
        return
    for path in paths:
        try:
            img = load(path)
        except Exception as e:  # a placeholder or LFS pointer is not an image
            print(f"skip  {path}: not an image ({type(e).__name__})")
            continue
        rx, ry = seam_ratio(img)
        verdict = "repeats" if max(rx, ry) <= LIMIT else "SEAM"
        print(f"{verdict:8} x={rx:4.2f} y={ry:4.2f}  {path}")


if __name__ == "__main__":
    main()
