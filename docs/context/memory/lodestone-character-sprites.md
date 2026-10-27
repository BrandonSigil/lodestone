---
name: lodestone-character-sprites
description: Character/monster/boss sprite spec C1-C29, templates, exporter and Character Guide artifact (2026-10-27)
metadata:
  type: project
  modified: 2026-10-27T05:03:34.618Z
---

- 2026-10-27 [USER] Brandon's chibi character sheet (5 iso views on tile diamonds, idle/walk/attack/cast/hurt, sword+cloak parts, 8 swatches) is the template for ALL characters; he wants front/back/left/right too for free roaming outside combat. Krita AI Diffusion on MacBook M4 Max with SDXL ZavyChroma XL.
- [AI] spec (PR #15): `docs/art/characters.md` rules C1-C29. Frame 192n square, feet at (96n,160n) for n x n footprint; classes small 1x1, hero 1x1 (head 3 levels = 96 art px), large 2x2 (384), boss 3x3 (576). Facings named by screen dir; draw S,SE,E,NE,N, mirror SW,W,NW; combat = diagonals SE/NE. Lit from above (mirror-safe). Cut-out idle/walk from paper-doll parts; drawn attack/cast/hurt/down in SE+NE only. 10 key ramps from his swatches (`lodestone-characters.gpl`), engine recolours by ramp swap.
- Templates `art/templates/characters/<class>/`: model sheet 3x2 x 768 slots (S,SE,E/NE,N,KEY) with 3D ellipsoid mannequins + control PNGs per view, parts-front/back, anim-canvas, sprite sheet, layout.json. Built and exported by `tools/art/char_art.py` (export/pack/lock/guide) into `game/art/source/characters/<id>/` (`<id>_<anim>_<dir>.png` strips, stand frames, parts/<dir>/<part>.png, <id>.json). Working files in `art/characters/<id>/`.
- Character Guide artifact: https://claude.ai/artifact/WWYopuEueYemwfe3qZuVp5 (copy docs/context/artifacts/character-guide.html, source tools/art/character_guide.src.html).
- Engine side NOT built: sprite node, facing, anim states, paper doll + recolour shader, 2x2/3x3 units, free-roam mode.
- Gotcha fixed: psd-tools with an RGB PSD stores layer alpha as a mask over black (strokes on "empty" layers invisible in Krita). save_psd now builds RGBA; battle-map PSDs regenerated.

**Why:** consistent pieces that drop onto the iso board, cheap to animate and randomize.
**How to apply:** follow C1-C29 for any character art or engine sprite work; related [[lodestone-battle-map-art]], [[lodestone-visual-language]].
