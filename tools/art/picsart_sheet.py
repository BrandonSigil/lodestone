#!/usr/bin/env python3
"""Generate a picture from a prompt file plus reference images with a Picsart model.

For the sheet prompts in art/prompts/ (zone sheets, tile kits), where there is no
template to repaint: the images are style and layout references, in order.

Usage:
  python tools/art/picsart_sheet.py --name zones --prompt-file art/prompts/sheet-zones.txt \
      --zones "forest, ruins, dungeon, ..." --ref docs/art/references/style-hike-illustration.png \
      [--ref another.png] [--aspect 3:4] [--count 1] [--model flux-3-image] [--resolution 2k]

Writes art/picsart/out/<name>_v<n>.png. The key is read as in picsart_render.py.
"""

import argparse
import io
from pathlib import Path

import requests
from PIL import Image

from picsart_render import ASPECTS, DEFAULT_OUT, api_key, balance, generate, upload


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--name", required=True)
    ap.add_argument("--prompt-file", required=True)
    ap.add_argument("--zones", help="fills [LIST 8 ZONES HERE] / [ZONE] in the prompt")
    ap.add_argument("--ref", action="append", default=[], help="reference image, in prompt order")
    ap.add_argument("--model", default="flux-3-image")
    ap.add_argument("--resolution", default="2k")
    ap.add_argument("--aspect", default="3:4", choices=sorted(ASPECTS))
    ap.add_argument("--count", type=int, default=1)
    ap.add_argument("--start", type=int, default=1)
    ap.add_argument("--out-dir", default=str(DEFAULT_OUT))
    args = ap.parse_args()

    prompt = Path(args.prompt_file).read_text(encoding="utf-8").strip()
    if args.zones:
        prompt = prompt.replace("[LIST 8 ZONES HERE]", args.zones).replace("[ZONE]", args.zones)
    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)

    key = api_key()
    before = balance(key)
    print("credits before:", before)
    if not before:
        raise SystemExit("No credits left.")

    params = {"prompt": prompt, "aspectRatio": args.aspect,
              "resolution": args.resolution, "count": args.count}
    if args.ref:
        params["imageUrls"] = [upload(key, Image.open(p).convert("RGB")) for p in args.ref]
    urls, charged = generate(key, args.model, params)
    print("charged:", charged)
    for i, url in enumerate(urls, start=args.start):
        img = Image.open(io.BytesIO(requests.get(url, timeout=120).content))
        path = out / ("%s_v%d.png" % (args.name, i))
        img.save(path)
        print("%s: %dx%d" % (path, img.width, img.height))
    print("credits after:", balance(key))


if __name__ == "__main__":
    main()
