---
name: lodestone-battle-map-art
description: Battle map art direction (Brandon's iso reference), rules B1-B32, templates, artifact link, LFS push gotcha
metadata:
  type: project
  modified: 2026-10-26T22:30:58.172Z
---

- 2026-10-26 [USER] Battle maps take their look from an isometric reference Brandon posted (mossy stone cliff-block terraces, temple stair, waterfalls, pines, floating island on cream paper). Reference is mood only, never training data.
- [AI] proposal, merged PR #8: `docs/art/battle-maps.md` rules B1-B32. Key numbers: 2:1 dimetric, art at 2x engine (tile 128x64, 32 px per level, engine TW64/TH32/HS16), sun upper left fixed on screen, values top/lit/shade 100/75/55, outline #373335, reference structure + Style Lab surface (grain, no black, marks).
- Templates in `art/templates/battle-maps/` (PSD+ORA, 2400x1600: blank 16x16, one per saved sandbox map, tile kit sheet) with control-lineart/depth/blocking PNGs for Krita AI Diffusion; rebuilt by `tools/art/battle_art.py` (needs pillow, numpy, psd-tools). Copies in project files `battle-map-art/`.
- Published guide artifact: https://claude.ai/artifact/JjxHePXisJfFFTxoddXjYB
- Proposed loosening of art-pipeline: tiles may be generated only on top of templates (control layers, clipped, hand-fixed), never freehand.
- Engine work to use painted tiles (TileArt resource, sprite tops, UV side strips, props per depth, occluders, waterfall shader, palette-map) is listed in the doc, not built yet.
- Gotcha: .gitattributes routes *.png/*.psd to LFS, and LFS uploads are refused (403) from cloud sessions. PR #8 exempted `art/templates/**` and `docs/art/**`; new binary paths need the same exemption or must be pushed from Brandon's PC.

**Why:** Brandon wants AI-assisted art that drops onto the Godot iso grid.
**How to apply:** Check these rules before touching combat visuals; related [[lodestone-visual-language]], [[lodestone-tech-direction]].
- 2026-10-26 Picsart: API key only in C:\Users\Brand\Claude\lodestone-art\picsart\.api-key (never commit/log). picsart.io is blocked from cloud and device VM, so calls run via Remote Control on his PC. Scripts tools/art/picsart_render.py, picsart_kit.py(.json).
- Picsart API: flux-3-image via api.picsart.com/workflows/v1/models/execute, ~$0.026 per 1k render. removebg ~1 credit per call; it drained the account once, so never batch it and check balance after each call.
- Battle art kit: 9 textures + 7 props in game/art/source/battle/, wired by BattleArt + data/battle_art.csv. Godot tests/screens run via Remote Control on his PC (Godot 4.7.2; don't commit its edits to existing files).
- Picsart Flow can't import workflow files; guide has a build-it-yourself recipe. Handoff: <name>_raw.png/_cut.png into lodestone-art\picsart\kit\raw\, then picsart_kit.py --process-only on his PC.
- 2026-10-27 Brandon is back on Krita, now on a MacBook M4 Max (Krita AI Diffusion 1.53, Local Managed Server, MPS, SDXL + ZavyChroma XL). Guide artifact v3 has a full Krita step-by-step (style "Lodestone battle", Line Art 80% / Depth 55%, refine 55-65%, spot fixes 35-45%) and a snowy cliffs worked example. Every map template has control-blocking-snow.png (PR #13). 2026-10-27 [USER] CORRECTION: Brandon builds map topography in Godot (sandbox editor) and wants tile art applied there. Krita is for tile textures and props only; in-game map plates are SHELVED. But [USER] each look starts with a painted concept map (sandbox map -> template -> Krita paint with key items like campfire/fallen tree/ruins) that is then broken out into the tile set; break-out script to build when he says 'concept in' (art/paintings/<map>-concept.png). Tile sets: game/art/source/battle/<set>/ (snow, dungeon, forest) with base file names, missing files fall back to base; sandbox 'tile set' menu (branch claude/project-thread-h2so3c).
