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
- 2026-10-26 [USER] Brandon has stopped using Krita for now and has a Picsart subscription. There is no Picsart connector in the registry. Driving it from Claude would need a Picsart developer API key (separate from the app subscription), added as an environment secret. He chose the API (2026-10-26). The cloud container and device VM can't reach picsart.io (proxy 403), so calls run through a Remote Control session on his PC. The key is stored only in C:\Users\Brand\Claude\lodestone-art\picsart\.api-key (outside the repo); scripts read env PICSART_API_KEY or that file. Never commit or log it. Script: tools/art/picsart_render.py on branch picsart-render.
- 2026-10-26 Picsart test run done (PR #9 merged). API: balance GET api.picsart.io/tools/1.0/balance (X-Picsart-API-Key), upload POST api.picsart.io/tools/1.0/upload -> cdn URL, generate POST api.picsart.com/workflows/v1/models/execute (Bearer), model flux-3-image (refs via imageUrls, no negative/strength). About $0.026 per 1k render, $0.055 per 2k. Temple held the grid (IoU 0.97-0.99); drift is inside the island (stair treads, courses not on 32 px levels), and clipping cuts the moss lips. Inputs must be padded to an exact aspect ratio. Outputs in C:\Users\Brand\Claude\lodestone-art\picsart\out\. Python 3.13 was installed on his PC for this.
- 2026-10-26 Battle art kit (branch battle-art-kit, merged into claude/project-thread-h2so3c): 9 textures + 7 props in game/art/source/battle/, generator tools/art/picsart_kit.py(.json). Engine: BattleArt + data/battle_art.csv. Picsart removebg costs ~1 credit per call; it drained the account to 0 (cap was $1.50). Never batch removebg; check balance after each call. Cloud cannot run downloaded Godot (auto-mode classifier blocks it), so Godot tests/screens run via Remote Control on his PC (Godot 4.7.2; don't commit its edits to existing files).
- 2026-10-26 Painted kit merged to main (PR #10, prompts PR #11). Brandon also has a $20 Picsart app plan: Picsart Flow (picsart.com/create/workflows) can't import workflow files, only share by link, so the guide artifact has a build-it-yourself Flow recipe. Handoff: he saves <name>_raw.png / <name>_cut.png into lodestone-art\picsart\kit\raw\, then run `python tools/art/picsart_kit.py --process-only` on his PC (free) to install into the game.
