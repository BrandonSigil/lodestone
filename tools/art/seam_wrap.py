#!/usr/bin/env python3
"""Make a texture repeat: the scripted version of Krita's "offset by half, blend the seam".

The picture is rolled by half along an axis, so its own middle becomes the new edges (which meet by
construction) and the old seam lands in the middle. That middle band is then cross-faded back to the
unrolled picture, whose middle has no seam. Sides need --axis x; waterfalls need --axis xy.

    ~/.lodestone/venv/bin/python tools/art/seam_wrap.py IN.png [IN2.png ...] --axis x --band 0.25 --suffix _seam

Writes <name><suffix>.png next to each input. Check with tools/art/tile_seam_check.py.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image


def wrap(img: np.ndarray, axis: int, band: float) -> np.ndarray:
    n = img.shape[axis]
    rolled = np.roll(img, n // 2, axis=axis)
    # Weight of the unrolled picture: 1 at the middle, 0 outside the band, smooth in between.
    d = np.abs(np.arange(n) - n / 2) / (n * band / 2)
    w = np.clip(1 - d, 0, 1)
    w = w * w * (3 - 2 * w)
    shape = [1, 1, 1]
    shape[axis] = n
    w = w.reshape(shape)
    return rolled * (1 - w) + img * w


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("inputs", nargs="+")
    ap.add_argument("--axis", choices=["x", "y", "xy"], default="x")
    ap.add_argument("--band", type=float, default=0.25, help="width of the blend as a share of the picture")
    ap.add_argument("--suffix", default="_seam")
    args = ap.parse_args()
    for path in args.inputs:
        src = Image.open(path).convert("RGBA")
        img = np.asarray(src, dtype=np.float32)
        if "x" in args.axis:
            img = wrap(img, 1, args.band)
        if "y" in args.axis:
            img = wrap(img, 0, args.band)
        p = Path(path)
        out = p.with_name(p.stem + args.suffix + p.suffix)
        Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA").save(out)
        print(out)


if __name__ == "__main__":
    main()
