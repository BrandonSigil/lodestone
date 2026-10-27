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

- 2026-10-27 Picsart path (PR #19): three reference images (mannequin view = pose/camera, cleaned key view art/characters/<id>/<id>-key.png = identity, art/palettes/characters.png = colours), Flows "Lodestone character view" 1:1 and "Lodestone turnaround" 3:2; `char_art.py import` keys out cream bg, re-anchors feet, writes <id>-model.ora + stand frames (--anim for pose frames). Raw pics in art/characters/<id>/picsart/.
- 2026-10-27 House-style prompt blocks (PR #20): `art/prompts/style-{terrain,tiles,props,character}.txt` are pasted once into a Picsart canvas Text node; a second Text node holds only the per-run ask. Picsart API key for scripts lives in `~/.lodestone/picsart-api-key` (or env PICSART_API_KEY), never in the repo.
- MacBook setup 2026-10-27: repo cloned at ~/lodestone; Homebrew Python 3.15 blocks system pip, so art scripts run in a venv at ~/.lodestone/venv (`source ~/.lodestone/venv/bin/activate`; requests pillow numpy psd-tools).

**Why:** consistent pieces that drop onto the iso board, cheap to animate and randomize.
**How to apply:** follow C1-C29 for any character art or engine sprite work; related [[lodestone-battle-map-art]], [[lodestone-visual-language]].
- 2026-10-27 PR #39 merged: first sprites in battle, id `lead`. GPT anim sheets per facing (SE, NE; prompt art/prompts/sheet-character-anim.txt, ~$0.095 each) cut by tools/art/anim_sheet_cut.py into C28 strips; CharacterArt loader (game/scripts/combat/character_art.gd) + combat_board/combat_unit play idle/walk/attack/cast/hurt, face move/attack target, mirror SW/NW, hit on strike frame. No S/E/N roaming views, no paper doll/recolour, down pose unused. Placeholder until Brandon approves.
- Contributor how-to: docs/art/adding-characters.md (paths, json contract, Picsart and Krita paths, built vs not built). Stance sheets via art/prompts/sheet-character-stance.txt + anim_sheet_cut.py --rows ready:4,advance:6.
