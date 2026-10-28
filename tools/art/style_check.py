#!/usr/bin/env python3
"""Measure how busy a picture is, against the approved references. Read-only.

Two numbers per picture:
  texture  share of pixels that sit in small-scale texture: the local grey spread over a 5 x 5
           window is above 6 levels. Marks, speckles, cracks and grain all count. Flat fills don't.
  colours  how many distinct colours hold at least 0.5% of the picture (colours binned to 16 steps).

Reference bars, measured 2026-10-28:
  flat-forest references (Brandon's approved style)  texture 0.31 to 0.37
  snow island plate (the cliffs Brandon likes)        texture 0.41
  first snow kit sheets (too busy, per Brandon)       texture 0.45 to 0.46
Pictures above TEXTURE_BAR (0.42) are flagged as busier than the references.

    ~/.lodestone/venv/bin/python3 tools/art/style_check.py docs/art/references/style-flat-forest.png art/picsart/out/snow-batch-v1/snow-kit-v2a_v1.png
Needs Pillow and numpy.
"""
import sys

import numpy as np
from PIL import Image

TEXTURE_BAR = 0.42  # set by Brandon 2026-10-28: above the island plate (0.41) he likes, below the busy sheets (0.45)


def box(a: np.ndarray, k: int = 5) -> np.ndarray:
    p = k // 2
    ap = np.pad(a, p, mode="edge")
    c = np.pad(ap.cumsum(0).cumsum(1), ((1, 0), (1, 0)))
    return (c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]) / (k * k)


def measure(path: str) -> tuple:
    im = Image.open(path).convert("RGB")
    if max(im.size) > 1024:  # one scale for every picture, so the numbers compare
        im.thumbnail((1024, 1024))
    grey = np.asarray(im.convert("L"), dtype=np.float32)
    m = box(grey)
    sd = np.sqrt(np.maximum(box(grey * grey) - m * m, 0))
    texture = float((sd > 6).mean())
    rgb = np.asarray(im, dtype=np.int32) // 16
    codes = rgb[..., 0] * 256 + rgb[..., 1] * 16 + rgb[..., 2]
    _, counts = np.unique(codes, return_counts=True)
    colours = int((counts / codes.size >= 0.005).sum())
    return texture, colours


def main() -> None:
    paths = sys.argv[1:]
    if not paths:
        print(__doc__)
        return
    print(f"{'texture':>8} {'colours':>8}  verdict   picture")
    for p in paths:
        try:
            t, c = measure(p)
        except Exception as e:
            print(f"    skip {p}: not an image ({type(e).__name__})")
            continue
        verdict = "busier" if t > TEXTURE_BAR else "ok"
        print(f"{t:8.2f} {c:8d}  {verdict:8}  {p}")


if __name__ == "__main__":
    main()
