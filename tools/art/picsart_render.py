#!/usr/bin/env python3
"""Run a battle-map template through a Picsart image-edit model and clip the result.

Usage:
  python tools/art/picsart_render.py INPUT.png --name temple --prompt-file p.txt \
      [--negative-file n.txt] [--count 2] [--model flux-3-image] [--resolution 1k] \
      [--out-dir C:/Users/Brand/Claude/lodestone-art/picsart/out]
  python tools/art/picsart_render.py --balance

The key comes from env PICSART_API_KEY, else from lodestone-art/picsart/.api-key
next to the repo. It is never printed or written anywhere.

Per result it writes <name>_v<n>_raw.png (model output as returned),
<name>_v<n>_clipped.png (resized to the input and clipped to the input's
non-paper silhouette, transparent elsewhere) and <name>_v<n>_compare.png
(template | raw | clipped). It also prints a silhouette IoU: how well the raw
image's non-background area lines up with the template's (1.0 = exact).
"""

import argparse
import io
import os
import sys
import time
from pathlib import Path

import requests
from PIL import Image, ImageChops, ImageFilter

REPO = Path(__file__).resolve().parents[2]
KEY_FILE = REPO.parent / "lodestone-art" / "picsart" / ".api-key"
DEFAULT_OUT = REPO.parent / "lodestone-art" / "picsart" / "out"

GENAI = "https://api.picsart.com"
TOOLS = "https://api.picsart.io/tools/1.0"
PAPER = (0xEA, 0xE8, 0xD6)

ASPECTS = {"21:9": 21 / 9, "2:1": 2.0, "16:9": 16 / 9, "3:2": 1.5, "7:5": 1.4, "4:3": 4 / 3,
           "5:4": 1.25, "1:1": 1.0, "4:5": 0.8, "3:4": 0.75, "2:3": 2 / 3, "9:16": 9 / 16}

# Added to every prompt: the model only gets the template as an edit input, so
# the instruction to keep its geometry has to be spelled out.
KEEP_GEOMETRY = ("Repaint the input image in place. Keep its exact layout, silhouette, block "
                 "positions, block heights and the 2:1 dimetric tile grid unchanged; only replace "
                 "the flat placeholder colours with finished surfaces. Keep the plain background.")


def api_key():
    key = os.environ.get("PICSART_API_KEY", "").strip()
    if not key and KEY_FILE.exists():
        key = KEY_FILE.read_text(encoding="utf-8").strip()
    if not key:
        sys.exit("No Picsart key: set PICSART_API_KEY or create " + str(KEY_FILE))
    return key


def balance(key):
    r = requests.get(TOOLS + "/balance", headers={"X-Picsart-API-Key": key}, timeout=30)
    r.raise_for_status()
    return r.json().get("credits")


def upload(key, img):
    buf = io.BytesIO()
    img.save(buf, "PNG")
    r = requests.post(TOOLS + "/upload", headers={"X-Picsart-API-Key": key},
                      files={"image": ("input.png", buf.getvalue(), "image/png")}, timeout=120)
    r.raise_for_status()
    return r.json()["data"]["url"]


def nearest_aspect(w, h):
    return min(ASPECTS, key=lambda a: abs(ASPECTS[a] - w / h))


def pad_to_aspect(img, ratio):
    """Centre img on paper so its ratio matches what the model returns exactly.
    Returns (padded image, box of the original inside it)."""
    w, h = img.size
    pw, ph = (round(h * ratio), h) if w / h < ratio else (w, round(w / ratio))
    x, y = (pw - w) // 2, (ph - h) // 2
    padded = Image.new("RGB", (pw, ph), PAPER)
    padded.paste(img, (x, y))
    return padded, (x, y, x + w, y + h)


def generate(key, model, params, timeout=600):
    """Run a model and return (list of image URLs, credits charged)."""
    headers = {"Authorization": "Bearer " + key, "Content-Type": "application/json"}
    r = requests.post(GENAI + "/workflows/v1/models/execute", headers=headers,
                      json={"params": {"model": model, "params": params}}, timeout=timeout)
    if r.status_code >= 400:
        sys.exit("Generate failed %d: %s" % (r.status_code, r.text[:500]))
    resp = r.json().get("response", {})
    deadline = time.time() + timeout
    while resp.get("status") not in ("COMPLETED", "FAILED"):
        if time.time() > deadline:
            sys.exit("Timed out waiting for job " + str(resp.get("id")))
        time.sleep(3)
        p = requests.get(GENAI + "/workflows/v1/models/%s/result" % resp["id"],
                         headers=headers, timeout=60)
        p.raise_for_status()
        resp = p.json().get("response", {})
    if resp["status"] == "FAILED":
        sys.exit("Job failed: " + str(resp)[:500])
    result = resp.get("result", {})
    urls = [it["url"] for it in result.get("items", []) if it.get("url")] or [result["url"]]
    return urls, resp.get("usage", {}).get("credits")


def silhouette(img, bg, tol):
    """L mask, 255 where img differs from colour bg by more than tol."""
    diff = ImageChops.difference(img.convert("RGB"), Image.new("RGB", img.size, bg))
    return diff.convert("L").point(lambda v: 255 if v > tol else 0)


def iou(a, b):
    inter = ImageChops.multiply(a, b).histogram()[255]
    union = ImageChops.lighter(a, b).histogram()[255]
    return inter / union if union else 0.0


def post_process(template, raw, tol, padded_size, box):
    """Return (resized raw, clipped RGBA, IoU of raw vs template silhouette)."""
    raw = raw.convert("RGB").resize(padded_size, Image.LANCZOS).crop(box)
    mask = silhouette(template, PAPER, tol)
    clipped = raw.convert("RGBA")
    clipped.putalpha(mask)
    # The model may tint the background, so sample its own corner as background.
    raw_bg = raw.getpixel((4, 4))
    raw_mask = silhouette(raw, raw_bg, 24).filter(ImageFilter.MedianFilter(5))
    return raw, clipped, iou(mask, raw_mask)


def compare(template, raw, clipped, width=900):
    h = round(template.height * width / template.width)
    sheet = Image.new("RGB", (width * 3 + 40, h + 20), PAPER)
    on_paper = Image.new("RGB", clipped.size, PAPER)
    on_paper.paste(clipped, mask=clipped.getchannel("A"))
    for i, im in enumerate((template.convert("RGB"), raw, on_paper)):
        sheet.paste(im.resize((width, h), Image.LANCZOS), (10 + i * (width + 10), 10))
    return sheet


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input", nargs="?")
    ap.add_argument("--name")
    ap.add_argument("--prompt")
    ap.add_argument("--prompt-file")
    ap.add_argument("--negative", default="")
    ap.add_argument("--negative-file")
    ap.add_argument("--model", default="flux-3-image")
    ap.add_argument("--resolution", default="1k")
    ap.add_argument("--aspect", help="default: nearest supported ratio to the input")
    ap.add_argument("--count", type=int, default=1)
    ap.add_argument("--start", type=int, default=1, help="first variation number in file names")
    ap.add_argument("--tolerance", type=int, default=10, help="paper match tolerance (0-255)")
    ap.add_argument("--out-dir", default=str(DEFAULT_OUT))
    ap.add_argument("--balance", action="store_true", help="print credits and exit")
    args = ap.parse_args()

    key = api_key()
    if args.balance:
        print("credits:", balance(key))
        return
    if not args.input:
        ap.error("input image required")
    prompt = Path(args.prompt_file).read_text(encoding="utf-8").strip() if args.prompt_file else args.prompt
    negative = Path(args.negative_file).read_text(encoding="utf-8").strip() if args.negative_file else args.negative
    if not prompt:
        ap.error("--prompt or --prompt-file required")
    name = args.name or Path(args.input).parent.name
    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)

    before = balance(key)
    print("credits before:", before)
    if not before:
        sys.exit("No credits left.")

    template = Image.open(args.input).convert("RGB")
    # Flux takes no negative prompt field, so the negatives ride in the prompt.
    full = KEEP_GEOMETRY + " " + prompt + ((" Avoid: " + negative) if negative else "")
    aspect = args.aspect or nearest_aspect(*template.size)
    padded, box = pad_to_aspect(template, ASPECTS[aspect])
    params = {"prompt": full, "imageUrls": [upload(key, padded)],
              "aspectRatio": aspect,
              "resolution": args.resolution, "count": args.count}
    urls, charged = generate(key, args.model, params)
    print("charged:", charged)

    for i, url in enumerate(urls, start=args.start):
        raw = Image.open(io.BytesIO(requests.get(url, timeout=120).content))
        stem = out / ("%s_v%d" % (name, i))
        raw.save(str(stem) + "_raw.png")
        resized, clipped, score = post_process(template, raw, args.tolerance, padded.size, box)
        clipped.save(str(stem) + "_clipped.png")
        compare(template, resized, clipped).save(str(stem) + "_compare.png")
        print("%s_v%d: raw %dx%d, silhouette IoU %.3f" % (name, i, raw.width, raw.height, score))

    print("credits after:", balance(key))


if __name__ == "__main__":
    main()
