#!/usr/bin/env python3
"""Draw seamless flat top textures in code, one biome palette at a time.

Each top is a periodic field, so its left edge matches its right edge and its top matches its bottom
by construction. The field is smoothed noise filtered in the frequency domain (so it wraps), then cut at a
threshold to give a few flat blobs on a flat base colour. Deterministic: the same seed gives the same tile.

    ~/.lodestone/venv/bin/python3 tools/art/code_tops.py --biome snow --out art/picsart/out/code-tops-sample

Biome palettes live in BIOMES below; a new biome is a new entry. Needs Pillow and numpy.
"""
import argparse
from pathlib import Path

import numpy as np
from PIL import Image

SIZE = 512

# base colour, mark colour, blob share (0 to 1; lower = fewer marks), seed
BIOMES = {
    "snow": {
        "snow_top":      ((236, 242, 250), (188, 210, 240), 0.10, 1),
        "snow_speckle":  ((236, 242, 250), (184, 206, 232), 0.16, 2),
        "stone_top":     ((130, 134, 146), (104, 108, 120), 0.14, 3),
        "ice_top":       ((150, 200, 230), (120, 176, 214), 0.12, 4),
        "forest_top":    ((232, 239, 249), (190, 208, 234), 0.10, 6),   # snow under the trees
        "road_top":      ((214, 222, 234), (192, 202, 220), 0.10, 7),   # packed, trodden snow for paths
    },
}


def periodic_noise(size: int, seed: int, cutoff: float) -> np.ndarray:
    """Smooth noise that wraps at the edges: random values filtered to low frequencies in Fourier space."""
    rng = np.random.default_rng(seed)
    field = rng.standard_normal((size, size))
    f = np.fft.fft2(field)
    fy = np.fft.fftfreq(size)[:, None]
    fx = np.fft.fftfreq(size)[None, :]
    keep = np.exp(-((fx ** 2 + fy ** 2) / (2 * cutoff ** 2)))
    out = np.real(np.fft.ifft2(f * keep))
    return (out - out.mean()) / (out.std() + 1e-9)


def draw(base, mark, share, seed, cutoff=0.05) -> Image.Image:
    noise = periodic_noise(SIZE, seed, cutoff=cutoff)
    threshold = np.quantile(noise, 1.0 - share)  # top share of the field becomes marks
    mask = noise > threshold
    rgb = np.empty((SIZE, SIZE, 3), dtype=np.uint8)
    rgb[:] = base
    rgb[mask] = mark
    return Image.fromarray(rgb, "RGB")


def _roll_grad(a: np.ndarray) -> np.ndarray:
    """Gradient magnitude that wraps at the edges, so the pooling line does not break the repeat."""
    gx = (np.roll(a, -1, axis=1) - np.roll(a, 1, axis=1)) / 2
    gy = (np.roll(a, -1, axis=0) - np.roll(a, 1, axis=0)) / 2
    return np.hypot(gx, gy)


# Watercolour look, tuned against the Picsart snow top (texture 0.21, 4 colours; ours 0.18, 4). Lower = calmer.
WC = {"bloom_t": 0.6, "bloom_k": 25.0, "soft": 0.0, "blend": 0.6, "tint": 0.0, "pool": 0.0, "grain": 0.012, "cutoff": 0.007, "cover": 0.12, "lobe": 0.2, "lobe_mult": 2, "layer2": {"cutoff": 0.015, "cover": 0.02, "blend": 0.25}, "mottle": None}


def _soften(field: np.ndarray, sigma: float) -> np.ndarray:
    """Blur a periodic field with a Gaussian in Fourier space, so soft edges still wrap."""
    if sigma <= 0:
        return field
    f = np.fft.fft2(field)
    fy = np.fft.fftfreq(SIZE)[:, None]
    fx = np.fft.fftfreq(SIZE)[None, :]
    return np.real(np.fft.ifft2(f * np.exp(-(fx ** 2 + fy ** 2) / (2 * sigma ** 2))))


def watercolour(base, wash, seed) -> Image.Image:
    """Soft wash on a clean base: sparse blooms, softened edges, optional tint, pooling and grain. All wrap."""
    mid = periodic_noise(SIZE, seed + 100, cutoff=WC["cutoff"])  # where the washes bloom; lower = bigger blooms
    if WC.get("lobe"):  # a finer wobble on the edge, so the blooms read as lobed clouds
        mid = mid + WC["lobe"] * periodic_noise(SIZE, seed + 300, cutoff=WC["cutoff"] * WC.get("lobe_mult", 4))
    t = np.quantile(mid, 1.0 - WC["cover"]) if WC.get("cover") else WC["bloom_t"]  # cover = share of the tile washed
    bloom = 1.0 / (1.0 + np.exp(-WC["bloom_k"] * (mid - t)))
    bloom = np.clip(_soften(bloom, WC["soft"]), 0, 1)
    base_f = np.asarray(base, dtype=np.float32) / 255.0
    wash_f = np.asarray(wash, dtype=np.float32) / 255.0
    a_field = WC["blend"] * bloom
    if WC.get("layer2"):  # a second, finer layer of smaller blooms, at its own strength
        L = WC["layer2"]
        mid2 = periodic_noise(SIZE, seed + 400, cutoff=L["cutoff"])
        t2 = np.quantile(mid2, 1.0 - L["cover"])
        bloom2 = 1.0 / (1.0 + np.exp(-WC["bloom_k"] * (mid2 - t2)))
        a_field = np.maximum(a_field, L["blend"] * bloom2)
    if WC.get("mottle"):  # a faint wash over the whole tile, uneven in a slow way
        M = WC["mottle"]
        field = periodic_noise(SIZE, seed + 500, cutoff=M["cutoff"])
        a_field = np.maximum(a_field, M["blend"] * (0.5 + 0.5 * np.tanh(field)))
    a = a_field[..., None]
    img = base_f[None, None, :] * (1 - a) + wash_f[None, None, :] * a
    if WC["tint"]:
        low = periodic_noise(SIZE, seed, cutoff=0.012)
        img *= (1 + WC["tint"] * low)[..., None]
    if WC["pool"]:
        edge = _roll_grad(bloom)
        img *= (1 - WC["pool"] * edge / (edge.max() + 1e-9))[..., None]
    if WC["grain"]:
        fine = periodic_noise(SIZE, seed + 200, cutoff=0.22)
        img *= (1 + WC["grain"] * fine)[..., None]
    return Image.fromarray(np.clip(img * 255, 0, 255).astype(np.uint8), "RGB")


def streak_noise(size: int, seed: int, cutoff_x: float, cutoff_y: float) -> np.ndarray:
    """Periodic noise with its own frequency per axis: a low cutoff_y makes long vertical streaks."""
    rng = np.random.default_rng(seed)
    field = rng.standard_normal((size, size))
    f = np.fft.fft2(field)
    fy = np.fft.fftfreq(size)[:, None]
    fx = np.fft.fftfreq(size)[None, :]
    keep = np.exp(-(fx ** 2 / (2 * cutoff_x ** 2) + fy ** 2 / (2 * cutoff_y ** 2)))
    out = np.real(np.fft.ifft2(f * keep))
    return (out - out.mean()) / (out.std() + 1e-9)


def face(base, wash, seed, strength=0.5) -> Image.Image:
    """A cliff face in watercolour: vertical streaks of wash on a clean base, a little pooling and grain. All wrap."""
    streaks = streak_noise(SIZE, seed, cutoff_x=0.05, cutoff_y=0.006)  # long, soft vertical streaks
    strata = streak_noise(SIZE, seed + 50, cutoff_x=0.02, cutoff_y=0.002)  # slow banding across the face
    grain = periodic_noise(SIZE, seed + 200, cutoff=0.22)
    t = np.quantile(streaks, 1.0 - WC["cover"] * 2.5)
    bloom = 1.0 / (1.0 + np.exp(-WC["bloom_k"] * (streaks - t)))
    bloom = bloom * (0.5 + 0.5 * np.tanh(strata))
    base_f = np.asarray(base, dtype=np.float32) / 255.0
    wash_f = np.asarray(wash, dtype=np.float32) / 255.0
    a = (strength * bloom)[..., None]
    img = base_f[None, None, :] * (1 - a) + wash_f[None, None, :] * a
    img *= (1 + 0.012 * grain)[..., None]
    return Image.fromarray(np.clip(img * 255, 0, 255).astype(np.uint8), "RGB")


FACES = {
    "side_cliff": ((120, 124, 134), (96, 100, 112), 3),       # grey stone
    "side_cliff_b": ((138, 192, 226), (108, 166, 208), 4),    # blue ice
    "side_masonry": ((74, 78, 90), (58, 62, 74), 5),          # dark rock
}


def lip_snow(base, wash, seed) -> Image.Image:
    """A soft snow lip: a watercolour snow band with a rounded drape along its bottom edge, transparent below.
    The drape is smooth noise, not teeth. It wraps left to right, so the strip repeats along a cliff top."""
    drape = periodic_noise(SIZE, seed + 600, cutoff=0.012)[0]          # one row of noise: the drape line per column
    edge = (SIZE * (0.30 + 0.035 * np.tanh(drape))).astype(np.float32)  # shallow, gentle drape: a cap, not drips
    mid = periodic_noise(SIZE, seed + 100, cutoff=0.02)
    bloom = 1.0 / (1.0 + np.exp(-WC["bloom_k"] * (mid - 0.6)))
    base_f = np.asarray(base, dtype=np.float32) / 255.0
    wash_f = np.asarray(wash, dtype=np.float32) / 255.0
    a_col = (0.22 * bloom)[..., None]
    rgb = base_f[None, None, :] * (1 - a_col) + wash_f[None, None, :] * a_col
    rows = np.arange(SIZE, dtype=np.float32)[:, None]
    alpha = np.clip((edge[None, :] - rows) / 2.0, 0, 1)                 # 2 px soft edge on the drape
    rgba = np.dstack([rgb, alpha])
    return Image.fromarray(np.clip(rgba * np.array([255, 255, 255, 255], dtype=np.float32), 0, 255).astype(np.uint8), "RGBA")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--biome", required=True, choices=sorted(BIOMES))
    ap.add_argument("--out", required=True)
    ap.add_argument("--cutoff", type=float, default=0.05, help="lower = larger, softer marks")
    ap.add_argument("--style", default="flat", choices=["flat", "watercolour", "faces", "lip"])
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    if args.style == "lip":
        lip_snow((236, 242, 250), (188, 210, 240), 1).save(out / "lip_snow.png")
        print("wrote", out / "lip_snow.png")
        return
    if args.style == "faces":
        for name, (base, wash, seed) in FACES.items():
            face(base, wash, seed).save(out / f"{name}.png")
            print("wrote", out / f"{name}.png")
        return
    for name, (base, mark, share, seed) in BIOMES[args.biome].items():
        img = watercolour(base, mark, seed) if args.style == "watercolour" else draw(base, mark, share, seed, args.cutoff)
        img.save(out / f"{name}.png")
        print("wrote", out / f"{name}.png")


if __name__ == "__main__":
    main()
