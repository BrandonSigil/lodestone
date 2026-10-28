#!/usr/bin/env python3
"""Procreate kit for the iPad: layered sketch templates (PSD), the full palette (.ase), and a cutter.

    python3 tools/art/procreate_art.py                     # writes art/templates/procreate/ and art/palettes/procreate/
    python3 tools/art/procreate_art.py cut FILE --template NAME [--out DIR]
                                                           # slices a drawing from a template into PNGs

Same camera and sizes as the battle maps and the character kit (tools/art/battle_art.py,
tools/art/char_art.py, docs/art/battle-maps.md, docs/art/characters.md): art at 2x the engine,
a cell is 128 x 64, one height level is 32 px. Procreate's Gallery Import keeps the PSD layers
(an insert into an open canvas flattens them), and the Color panel imports .ase palettes.

Layer names matter. Anything named PAINT is cut; GUIDE, SKETCH, SILHOUETTE and REFERENCE layers are
never cut. Hide or delete nothing in the manifest's cells, and keep the canvas size as built.

Needs Pillow, numpy and psd-tools (pip install pillow numpy psd-tools).
"""
from __future__ import annotations

import argparse
import json
import re
import struct
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from battle_art import paper  # noqa: E402
from char_art import (CLASSES, FIXED, K, RAMPS, anchor_of, compose, dashed, footprint,  # noqa: E402
                      frame_of, read_layers, render_mannequin)

ROOT = Path(__file__).resolve().parents[2]
TEMPLATES = ROOT / "art/templates/procreate"
PALETTES = ROOT / "art/palettes/procreate"
CUT_OUT = ROOT / "art/procreate-out"
ZONES_GPL = ROOT / "art/palettes/lodestone-zones.gpl"
STYLE_BIBLE = ROOT / "docs/style-bible.md"
TEMPLATE_NAMES = ["character-hero", "terrain-tiles", "props-iso"]

INK = (55, 51, 53)
BLUE = (60, 110, 170)
PINK = (200, 60, 120)
CARD = (243, 234, 210)  # the cream piece colour from style bible section 5
PAPER_RGB = (234, 232, 214)
SILHOUETTE = (42, 36, 51)  # 'base' in style bible section 5


def label_font(size: int):
    for p in ("/System/Library/Fonts/Supplemental/Arial.ttf",
              "/System/Library/Fonts/Helvetica.ttc",
              "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if Path(p).exists():
            return ImageFont.truetype(p, size)
    return ImageFont.load_default(size)


def empty(size):
    return Image.new("RGBA", size, (0, 0, 0, 0))


def write_psd(path: Path, size, layers):
    """layers: (name, RGBA image, visible), bottom first. Procreate keeps names and visibility."""
    from psd_tools import PSDImage
    from psd_tools.api.layers import PixelLayer
    from psd_tools.constants import Compression

    comp = empty(size)
    for _, img, visible in layers:
        if visible:
            comp.alpha_composite(img.convert("RGBA"))
    # RGBA document: alpha stays real transparency, not a layer mask (see battle_art.save_psd).
    psd = PSDImage.frompil(comp)
    for name, img, visible in layers:
        layer = PixelLayer.frompil(img.convert("RGBA"), psd, name, compression=Compression.ZIP)
        layer.visible = visible
    psd.save(str(path))
    comp.convert("RGB").save(path.with_name(path.stem + "-preview.png"), optimize=True)


def paint_layers(size):
    """The three layers Brandon draws on, bottom to top, then the free sketch layer."""
    return [
        ("PAINT 1 colour", empty(size), True),
        ("PAINT 2 ink", empty(size), True),
        ("PAINT 3 fx", empty(size), True),
        ("SKETCH (not cut)", empty(size), True),
    ]


# --- character sheet: the reference sheet's layout ---------------------------------------
# Top row: the five drawn facings (C6, C7). Bottom row: the SE poses (C9), then the sword and
# cloak parts from the reference sheet. Captions are small; the footprint is the one measure.
FR = frame_of("hero")  # 192 px cell (C2)
FOOT = anchor_of("hero")  # (96, 160), centre of the footprint diamond
HERO_BODY = CLASSES["hero"]["body"]
FACINGS = ["s", "se", "e", "ne", "n"]
POSES = ["idle", "walk", "attack", "cast", "hurt"]
PARTS = ["sword", "cloak"]
PITCH, MARGIN, TOP_Y, BOT_Y = 232, 56, 128, 400


def cell_xy(col: int, row: int):
    return MARGIN + col * PITCH, (TOP_Y if row == 0 else BOT_Y)


def silhouette(d: str) -> Image.Image:
    """Solid, fully opaque hero mannequin (graybox, C3). Hidden by default; show it to measure."""
    cov = render_mannequin(HERO_BODY, d, K, (FR, FR), FOOT, (2, 1))["blocking"].getchannel("A")
    im = Image.new("RGBA", (FR, FR), SILHOUETTE + (255,))
    im.putalpha(cov)
    return im


def character_template():
    W, H = 1812, 680
    guides, sil, labels, chips = empty((W, H)), empty((W, H)), empty((W, H)), empty((W, H))
    gd, ld, cd = ImageDraw.Draw(guides), ImageDraw.Draw(labels), ImageDraw.Draw(chips)
    small, big = label_font(17), label_font(26)
    slots = []

    def cell(name, kind, col, row):
        x, y = cell_xy(col, row)
        gd.rounded_rectangle([x, y, x + FR - 1, y + FR - 1], radius=14, outline=BLUE + (45,), width=1)
        if kind in ("facing", "pose"):
            ax, ay = x + FOOT[0], y + FOOT[1]
            footprint(gd, ax, ay, 1, 1, outline=BLUE + (150,), width=2)
            gd.ellipse([ax - 3, ay - 3, ax + 3, ay + 3], fill=PINK + (200,))
            dashed(gd, (x + 22, ay - 96), (x + FR - 22, ay - 96), BLUE + (90,), 1, 5)
        cap_y = y - 22 if row_of(name) == 0 else y + FR + 24
        ld.text((x + FR // 2, cap_y), name.upper(), fill=INK + (200,), font=small, anchor="mm")
        slots.append({"name": name, "kind": kind, "box": [x, y, FR, FR], "piece": [x, y, FR, FR],
                      "anchor": [x + FOOT[0], y + FOOT[1]] if kind != "part" else None})
        return x, y

    def row_of(name):
        return 0 if name in FACINGS else 1

    for i, d in enumerate(FACINGS):
        x, y = cell(d, "facing", i, 0)
        sil.alpha_composite(silhouette(d), (x, y))
    for i, p in enumerate(POSES):
        cell(p, "pose", i, 1)
    for i, p in enumerate(PARTS):
        cell(p, "part", len(POSES) + i, 1)

    # one swatch per key ramp (mid value), so colour choices stay on the page (C12)
    sx, sy = MARGIN + 6 * PITCH + FR + 50, TOP_Y
    for i, (name, hx) in enumerate(RAMPS.items()):
        y = sy + i * 54
        cd.rounded_rectangle([sx, y, sx + 64, y + 44], radius=8, fill=hexrgb(hx[1]) + (255,), outline=INK + (140,), width=1)

    ld.text((MARGIN, 60), "HERO", fill=INK + (220,), font=big, anchor="lm")
    layers = [
        ("paper", paper((W, H)), True),
        ("SILHOUETTE hero (hidden by default)", sil, False),
        ("GUIDE cells, footprints, head band", guides, True),
        ("GUIDE captions", labels, True),
        ("REFERENCE key ramp swatches", chips, True),
        *paint_layers((W, H)),
    ]
    write_psd(TEMPLATES / "character-hero.psd", (W, H), layers)
    return {"size": [W, H], "slots": slots}


# --- terrain: tops, overhang, cliff faces, falls -------------------------------------------
# Slot names are the engine's kit names (tools/art/kit_cut.py, art/prompts/terrain-sheets.md) plus
# the new pieces the brief asks for: grass 3, stairs, the moss overhang, and the cliff faces.
KIND_SIZE = {"top": (128, 96), "overhang_lit": (64, 56), "overhang_shade": (64, 56),
             "side_lit": (64, 96), "side_shade": (64, 96), "fall": (64, 128)}
TERRAIN = [
    [("top_grass", "top"), ("top_grass_b", "top"), ("top_grass_c", "top"),
     ("top_forest", "top"), ("top_road", "top")],
    [("top_stone", "top"), ("top_stone_b", "top"), ("top_stairs", "top"),
     ("top_rock", "top"), ("top_water", "top")],
    [("top_hazard", "top"), ("top_special", "top"), ("overhang_lit", "overhang_lit"),
     ("overhang_shade", "overhang_shade"), ("side_cliff_lit", "side_lit")],
    [("side_cliff_shade", "side_shade"), ("side_masonry_lit", "side_lit"),
     ("side_masonry_shade", "side_shade"), ("fall_lit", "fall"), ("fall_shade", "fall")],
]
SLOT = 192
TERRAIN_TOP = 40


def draw_terrain_guide(gd, kind, px, py):
    w, h = KIND_SIZE[kind]
    ink = INK + (120,)
    if kind == "top":
        pts = [(px + 64, py), (px + 128, py + 32), (px + 64, py + 64), (px, py + 32)]
        gd.line(pts + [pts[0]], fill=ink, width=2)
        gd.ellipse([px + 62, py + 30, px + 66, py + 34], fill=PINK + (170,))
    elif kind == "overhang_lit":  # top edge of the lit face, moss drape 8 to 24 px below it
        gd.line([(px, py), (px + 64, py + 32)], fill=ink, width=3)
        dashed(gd, (px, py + 24), (px + 64, py + 56), BLUE + (120,), 1, 4)
    elif kind == "overhang_shade":
        gd.line([(px, py + 32), (px + 64, py)], fill=ink, width=3)
        dashed(gd, (px, py + 56), (px + 64, py + 24), BLUE + (120,), 1, 4)
    elif kind in ("side_lit", "side_shade"):  # one stone course per level (B6)
        top = [(px, py), (px + 64, py + 32)] if kind == "side_lit" else [(px, py + 32), (px + 64, py)]
        gd.line(top, fill=ink, width=3)
        for y in (32, 64):
            dashed(gd, (px, py + y), (px + 64, py + y), BLUE + (110,), 1, 4)
    elif kind == "fall":  # seamless vertically every 64 px (B22)
        dashed(gd, (px, py + 64), (px + 64, py + 64), BLUE + (110,), 1, 4)


def terrain_template():
    W = 32 + 5 * SLOT + 32
    H = TERRAIN_TOP + 4 * SLOT + 32
    guides, labels = empty((W, H)), empty((W, H))
    gd, ld = ImageDraw.Draw(guides), ImageDraw.Draw(labels)
    f = label_font(15)
    slots = []
    for r, row in enumerate(TERRAIN):
        for c, (name, kind) in enumerate(row):
            sx, sy = 32 + c * SLOT, TERRAIN_TOP + r * SLOT
            w, h = KIND_SIZE[kind]
            px, py = sx + (SLOT - w) // 2, sy + 28 + (168 - h) // 2
            gd.rounded_rectangle([sx + 4, sy + 4, sx + SLOT - 5, sy + SLOT - 5], radius=12,
                                 fill=CARD + (255,), outline=BLUE + (60,), width=1)
            draw_terrain_guide(gd, kind, px, py)
            ld.text((sx + 12, sy + 12), name, fill=INK + (200,), font=f, anchor="lt")
            slots.append({"name": name, "kind": kind, "box": [sx, sy, SLOT, SLOT],
                          "piece": [px, py, w, h], "pivot": [px + 64, py + 32] if kind == "top" else None})
    layers = [
        ("paper", paper((W, H)), True),
        ("GUIDE slot cards, tile diamonds, courses", guides, True),
        ("GUIDE captions", labels, True),
        *paint_layers((W, H)),
    ]
    write_psd(TEMPLATES / "terrain-tiles.psd", (W, H), layers)
    return {"size": [W, H], "slots": slots}


# --- props: iso footprint and level ticks, front and side views -----------------------------
PROPS = ["pine_1", "pine_2", "bush", "boulder", "pillar", "brazier", "crate", "detail",
         "landmark", "ruin", "haybale"]
VIEWS = ["front", "side"]
PCOL, PROW = 160, 300  # slot pitch; piece 128 x 256, caption band 24 px
PIECE_W, PIECE_H = 128, 256
PROPS_LEFT, PROPS_TOP = 96, 40


def props_template():
    W = PROPS_LEFT + len(PROPS) * PCOL + 32
    H = PROPS_TOP + len(VIEWS) * PROW + 24
    guides, labels = empty((W, H)), empty((W, H))
    gd, ld = ImageDraw.Draw(guides), ImageDraw.Draw(labels)
    f, side_f = label_font(16), label_font(17)
    slots = []
    for r, view in enumerate(VIEWS):
        y = PROPS_TOP + r * PROW
        ld.text((40, y + 150), view.upper(), fill=INK + (200,), font=side_f, anchor="lm")
        for c, name in enumerate(PROPS):
            x = PROPS_LEFT + c * PCOL
            px, py = x + 16, y + 24  # piece box origin
            ax, ay = px + 64, py + 224  # pivot: centre of the footprint diamond (B23)
            gd.rounded_rectangle([x, y, x + PCOL - 18, y + PROW - 22], radius=12,
                                 fill=CARD + (255,), outline=BLUE + (60,), width=1)
            footprint(gd, ax, ay, 1, 1, outline=BLUE + (140,), width=2)
            for lv in range(0, 7):  # level ticks, 32 px each, up to 6 levels (B23)
                ty = ay - lv * 32
                gd.line([(px, ty), (px + (10 if lv % 2 == 0 else 5), ty)], fill=BLUE + (120,), width=1)
            ld.text((x + 10, y + 6), name, fill=INK + (200,), font=f, anchor="lt")
            slots.append({"name": name, "view": view, "box": [x, y, PCOL - 18, PROW - 22],
                          "piece": [px, py, PIECE_W, PIECE_H], "pivot": [ax, ay]})
    layers = [
        ("paper", paper((W, H)), True),
        ("GUIDE slot cards, footprints, levels", guides, True),
        ("GUIDE captions", labels, True),
        *paint_layers((W, H)),
    ]
    write_psd(TEMPLATES / "props-iso.psd", (W, H), layers)
    return {"size": [W, H], "slots": slots}


# --- palette: every approved or working colour, one .ase per group plus one full file --------
def hexrgb(h: str) -> tuple:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def zone_groups():
    """The five zone palettes (art/palettes/lodestone-zones.gpl), in file order."""
    groups: dict[str, list] = {}
    for line in ZONES_GPL.read_text().splitlines():
        rgb_part, _, name = line.partition("\t")
        m = re.match(r"^\s*(\d+)\s+(\d+)\s+(\d+)$", rgb_part)
        if not m or not name.strip():
            continue
        zone, role = name.split()[0], name.strip()
        groups.setdefault(zone, []).append((role, tuple(int(v) for v in m.groups())))
    return groups


def fixed_pieces():
    """'Pieces, fixed everywhere' line in the style bible, section 5."""
    line = next(l for l in STYLE_BIBLE.read_text().splitlines() if l.startswith("Pieces, fixed everywhere"))
    return [(f"piece {name}", hexrgb(hx)) for name, hx in re.findall(r"(\w+) (#[0-9a-fA-F]{6})", line)]


def region_colours():
    """The five style lab regions, nine roles each (style bible section 5)."""
    roles = ["sky top", "horizon", "far", "mid", "near", "ground", "dark", "accent", "light"]
    names = {"Home": "home", "Snow pass": "snow pass", "The Wall": "the wall",
             "Past the Wall": "past the wall", "Deep lands": "deep lands"}
    out = []
    for line in STYLE_BIBLE.read_text().splitlines():
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if len(cells) == 11 and cells[0] in names:
            for role, hx in zip(roles, cells[2:]):
                out.append((f"{names[cells[0]]} {role}", hexrgb(hx)))
    return out


def palette_groups():
    zones = zone_groups()
    ramps = [(f"{k} {lvl}", hexrgb(c)) for k, ramp in RAMPS.items()
             for lvl, c in zip(("light", "mid", "dark"), ramp)]
    return [
        ("pieces", fixed_pieces() + [("ink", hexrgb(FIXED["ink"])), ("glint", hexrgb(FIXED["glint"]))]),
        ("characters", ramps),
        ("home", zones["home"]),
        ("snow", zones["snow"]),
        ("desert", zones["desert"]),
        ("dungeon", zones["dungeon"]),
        ("forest", zones["forest"]),
        ("regions", region_colours()),
    ]


def ase_bytes(groups):
    """Adobe Swatch Exchange. groups: [(group name or None, [(colour name, (r, g, b)), ...]), ...]."""
    blocks = []

    def text(s):
        return struct.pack(">H", len(s) + 1) + (s + "\0").encode("utf-16-be")

    for gname, colours in groups:
        if gname is not None:
            body = text(gname)
            blocks.append(struct.pack(">HI", 0xC001, len(body)) + body)
        for cname, rgb in colours:
            body = text(cname) + b"RGB " + struct.pack(">3f", *(v / 255 for v in rgb)) + struct.pack(">H", 0)
            blocks.append(struct.pack(">HI", 0x0001, len(body)) + body)
        if gname is not None:
            blocks.append(struct.pack(">HI", 0xC002, 0))
    return b"ASEF" + struct.pack(">HHI", 1, 0, len(blocks)) + b"".join(blocks)


def palette_preview(groups, path: Path):
    cols, sw, gap = 16, 52, 12
    W = 40 + cols * (sw + gap)
    rows = sum(-(-len(c) // cols) for _, c in groups)
    H = 60 + rows * (sw + 30) + len(groups) * 44
    im = Image.new("RGB", (W, H), PAPER_RGB)
    d = ImageDraw.Draw(im)
    fh, fs = label_font(18), label_font(11)
    y = 24
    for gname, colours in groups:
        d.text((20, y), gname.upper(), fill=INK, font=fh, anchor="lt")
        y += 34
        for i, (cname, rgb) in enumerate(colours):
            x = 20 + (i % cols) * (sw + gap)
            ry = y + (i // cols) * (sw + 30)
            d.rectangle([x, ry, x + sw, ry + sw], fill=rgb, outline=INK, width=1)
            d.text((x, ry + sw + 3), "#%02x%02x%02x" % rgb, fill=INK, font=fs, anchor="lt")
        y += (-(-len(colours) // cols)) * (sw + 30) + 10
    im.save(path, optimize=True)


def write_palettes():
    PALETTES.mkdir(parents=True, exist_ok=True)
    groups = palette_groups()
    (PALETTES / "lodestone-full.ase").write_bytes(ase_bytes(groups))
    for i, (slug, colours) in enumerate(groups, 1):
        (PALETTES / f"lodestone-{i}-{slug}.ase").write_bytes(ase_bytes([(None, colours)]))
    palette_preview(groups, PALETTES / "lodestone-palette-preview.png")
    return {slug: len(c) for slug, c in groups}


# --- cutter: slice a finished drawing back into game-ready PNGs ------------------------------
def cut(path: Path, template: str, out: Path | None):
    """Crop every manifest slot from the PAINT layers (or a flat PNG) and write the non-empty ones."""
    manifest = json.loads((TEMPLATES / "manifest.json").read_text())[template]
    if path.suffix.lower() == ".png":
        drawing = Image.open(path).convert("RGBA")
        size = drawing.size
    else:
        size, layers = read_layers(path)
        drawing = compose(layers, lambda n: n.startswith("paint"))
    if list(size) != manifest["size"]:
        sys.exit(f"{path.name}: canvas is {size[0]} x {size[1]}, template is "
                 f"{manifest['size'][0]} x {manifest['size'][1]}. Keep the canvas size as built.")
    out = out or CUT_OUT / template
    out.mkdir(parents=True, exist_ok=True)
    written = []
    for s in manifest["slots"]:
        x, y, w, h = s["piece"]
        img = drawing.crop((x, y, x + w, y + h))
        if img.getchannel("A").getextrema()[1] <= 8:
            continue
        img.save(out / f"{s['name']}.png", optimize=True)
        written.append(s["name"])
    print(f"{path.name} -> {out}: {len(written)} piece(s): {', '.join(written) or 'none'}")
    return written


def build():
    TEMPLATES.mkdir(parents=True, exist_ok=True)
    manifest = {
        "character-hero": character_template(),
        "terrain-tiles": terrain_template(),
        "props-iso": props_template(),
    }
    (TEMPLATES / "manifest.json").write_text(json.dumps(manifest, indent=1) + "\n")
    counts = write_palettes()
    print("templates:", ", ".join(f"{k}.psd" for k in manifest))
    print("palettes:", ", ".join(f"{k} {v}" for k, v in counts.items()))


def main():
    parser = argparse.ArgumentParser(description="Procreate templates, palettes and the cutter.")
    sub = parser.add_subparsers(dest="cmd")
    c = sub.add_parser("cut", help="slice a drawing from a template into game-ready PNGs")
    c.add_argument("file", type=Path, help="the .psd / .ora from Procreate, or a flat .png")
    c.add_argument("--template", required=True, choices=TEMPLATE_NAMES)
    c.add_argument("--out", type=Path, help=f"default: {CUT_OUT.relative_to(ROOT)}/<template>")
    args = parser.parse_args()
    if args.cmd == "cut":
        cut(args.file, args.template, args.out)
    else:
        build()


if __name__ == "__main__":
    main()
