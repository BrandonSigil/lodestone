#!/usr/bin/env python3
"""Re-pick frames in a cut animation strip: copy one whole frame over another, no new pixels.

    python3 tools/art/anim_frame_swap.py game/art/source/characters/dog/dog_idle_se.png --set 2=1 --out STAGING.png

Frame numbers start at 1. `--set 2=1` puts frame 1 where frame 2 was (the strip keeps its length, so the
json's frame counts and hit frames still hold). For a frame that came out wrong (a squint, a stray mark)
when the rest of the strip is good; anything that needs new drawing goes back to Picsart instead.
"""

import argparse

from PIL import Image

FRAME = 192  # anim_sheet_cut.FRAME


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("strip")
    ap.add_argument("--set", action="append", required=True, help="DEST=SRC, 1-based frame numbers")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    img = Image.open(args.strip).convert("RGBA")
    n = img.width // FRAME
    frames = [img.crop((i * FRAME, 0, (i + 1) * FRAME, FRAME)) for i in range(n)]
    picked = list(frames)
    for pair in args.set:
        dest, src = (int(x) for x in pair.split("="))
        if not (1 <= dest <= n and 1 <= src <= n):
            raise SystemExit("frame out of range 1..%d: %s" % (n, pair))
        picked[dest - 1] = frames[src - 1]
    out = Image.new("RGBA", img.size)
    for i, f in enumerate(picked):
        out.paste(f, (i * FRAME, 0))
    out.save(args.out)
    print("%s: %d frames, %s" % (args.out, n, ", ".join(args.set)))


if __name__ == "__main__":
    main()
