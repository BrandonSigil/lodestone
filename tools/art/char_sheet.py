#!/usr/bin/env python3
"""Generate one facing of a character as an animation or combat stance sheet, with the house defaults.

    python3 tools/art/char_sheet.py --id lead --dir s                  # animation sheet, 1K
    python3 tools/art/char_sheet.py --id lead --dir s --sheet stance   # weapon-drawn stance sheet
    python3 tools/art/char_sheet.py --id lead --dir e --cut            # generate, then cut into the game
    python3 tools/art/char_sheet.py --id lead --dir n --dry-run        # print the prompt, spend nothing

Defaults: gpt-image-2.5-sunburst at 1K, 3:2, the reference sheet as the only image, the prompt
art/prompts/sheet-character-<sheet>.txt with its facing line filled from FACINGS below. 1K costs about
5.5 cents a sheet against 9.5 at 2K and looks the same once cut to sprite size (the cutter scales every
sheet down), so pass --resolution 2K only for a sheet that will also be used as a large reference.

Writes art/picsart/out/<sheet>-<id>-<dir>_v<n>.png at the next free n. With --cut, runs
anim_sheet_cut.py on it (stance sheets get --rows ready:4,advance:6). The key is read as in
picsart_render.py.
"""

import argparse
import io
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

# The five drawn facings (C6, C9); sw, w and nw are mirrors. Plain words for the model, filled into [ZONE].
FACINGS = {
    "se": "SE: three-quarter front view, the character faces toward the LOWER RIGHT of the picture. We see the "
          "face, the front of the body and the right side; the pack and sheathed sword peek out at the upper left.",
    "ne": "NE: three-quarter back view, the character faces toward the UPPER RIGHT of the picture. We see the back "
          "of the head, the back with the pack and the sheathed sword, and a little of the right side; no face.",
    "s": "S: facing straight DOWN the screen toward the viewer. We see the full front: face centred, both shoulders "
         "level, the gold clasp in the middle of the chest, the sword hilt and pack peeking out behind one "
         "shoulder. Body symmetric left to right.",
    "e": "E: a true side profile facing the RIGHT edge of the picture. We see the character's left side only: nose "
         "and hair pointing right, the rolled pack and sheathed sword on the back at the LEFT of the figure. "
         "Attacks and steps go to the right.",
    "n": "N: seen from straight BEHIND, facing UP the screen away from the viewer. We see the back of the head (no "
         "face), the back of the green cloak, the rolled pack and the sheathed sword across the back. Body "
         "symmetric left to right.",
}
STANCE_ROWS = "ready:4,advance:6"


def next_version(out, name):
    n = 1
    while (out / ("%s_v%d.png" % (name, n))).exists():
        n += 1
    return n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--id", required=True, help="character id (game/data/characters/<id>.tres)")
    ap.add_argument("--dir", required=True, choices=sorted(FACINGS))
    ap.add_argument("--sheet", default="anim", choices=["anim", "stance"])
    ap.add_argument("--prompt-file", help="default art/prompts/sheet-character-<sheet>.txt")
    ap.add_argument("--ref", default="docs/art/characters/00-reference-sheet.png",
                    help="the character's own reference sheet; attach nothing else (models copy it)")
    ap.add_argument("--facing", help="override the facing words for --dir")
    ap.add_argument("--model", default="gpt-image-2.5-sunburst")
    ap.add_argument("--resolution", default="1K", choices=["1K", "2K", "4K"])
    ap.add_argument("--aspect", default="3:2")
    ap.add_argument("--cut", action="store_true", help="cut the result into game/art/source/characters/<id>/")
    ap.add_argument("--dry-run", action="store_true", help="print the prompt and settings, call nothing")
    args = ap.parse_args()

    prompt_file = REPO / (args.prompt_file or "art/prompts/sheet-character-%s.txt" % args.sheet)
    prompt = prompt_file.read_text(encoding="utf-8").strip().replace("[ZONE]", args.facing or FACINGS[args.dir])
    out = REPO / "art" / "picsart" / "out"
    name = "%s-%s-%s" % (args.sheet, args.id, args.dir)
    path = out / ("%s_v%d.png" % (name, next_version(out, name)))
    print("%s  %s %s %s  ref %s" % (path.relative_to(REPO), args.model, args.resolution, args.aspect, args.ref))
    if args.dry_run:
        print(prompt)
        return

    # Imported here so --dry-run works without requests or a key.
    import requests
    from PIL import Image
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from picsart_render import api_key, generate, upload

    key = api_key()
    params = {"prompt": prompt, "aspectRatio": args.aspect, "resolution": args.resolution, "count": 1,
              "imageUrls": [upload(key, Image.open(REPO / args.ref).convert("RGB"))]}
    urls, charged = generate(key, args.model, params)
    print("charged:", charged)
    out.mkdir(parents=True, exist_ok=True)
    img = Image.open(io.BytesIO(requests.get(urls[0], timeout=120).content))
    img.save(path)
    print("%s: %dx%d" % (path.relative_to(REPO), img.width, img.height))

    if args.cut:
        cmd = [sys.executable, str(REPO / "tools/art/anim_sheet_cut.py"), str(path), "--id", args.id, "--dir", args.dir]
        if args.sheet == "stance":
            cmd += ["--rows", STANCE_ROWS]
        subprocess.run(cmd, check=True)


if __name__ == "__main__":
    main()
