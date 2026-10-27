# Current state (2026-10-27)

## Where things live
- Repo: github.com/BrandonSigil/lodestone, branch `main`. Godot project in `game/`.
- Brandon's machines: Windows PC "Gamer" (Godot 4.7.2, repo at `C:\Users\Brand\Claude\lodestone`) and a MacBook. Possibly a second Claude account. Pull before work, push after.
- Run `git lfs install` before cloning: PNG, PSD, KRA, WAV and OGG go through Git LFS, except the paths exempted in `.gitattributes` (`art/templates/**`, `docs/art/**`, `game/art/source/battle/**`).
- Art: `art/` (Picsart renders and kit raws in `art/picsart/`, screenshots in `art/screens/`, empty `art/tests`, `art/samples`, `art/training` for Brandon's drawings, battle map templates in `art/templates/`). The old `C:\Users\Brand\Claude\lodestone-art` folder is a duplicate and can go.
- Picsart key: `~/.lodestone/picsart-api-key` or env `PICSART_API_KEY`, never in git. A key was once pasted in chat, so it should be rotated.

## What's built (all on main)
- Week 1 graybox: iso grid combat with height and d20 checks, trail loop (days, food, morale, 12 slots, CSV events), village roster with unlocks, Lodestone recall save.
- Village hub (riso style, bottom frame A): team select, shop, 4x3 Tetris pack, mayor side jobs. Riso kit in `game/scripts/riso/`.
- Riso world map: route with the Wall at league 150, fog-ready discovery (FOG PEEK toggle).
- Combat sandbox (F9): map painter, difficulty dials, FE/XCOM action menus with hit forecasts, counters, ledge pushes, AI-vs-AI balance sim.
- Terrain pass: heights 0 to 8, stairs, ruin walls, line of sight, camera rotate (Q), temple and cliffs maps.
- Character traits and caster spell picks (2 slots).
- Painted battle terrain and props from Picsart, wired through `BattleArt` and `game/data/battle_art.csv`, graybox fallback.

## Superseded notes (memory lines that are out of date)
- "Brandon draws every final mark / no AI image gen" (tech direction, 2026-10-25): replaced 2026-10-26 [USER]. AI-generated art is allowed, directed by Brandon, made on top of templates. See `docs/art-pipeline.md`.
- Krita AI Diffusion + style LoRA plan: on hold. Brandon uses Picsart (API for scripted renders, $20 app plan with Picsart Flow for manual runs).
- Paths under `lodestone-art\...` (API key, Picsart outputs, kit raws): moved into the repo's `art/` and `~/.lodestone/` on 2026-10-27.
- CLAUDE.md still says "never generate, paint or edit art files". Brandon has been asked to edit it to point at `docs/art-pipeline.md`; Claude sessions are blocked from changing that rule themselves.

## Open items waiting on Brandon
- Pick the bottom frame: A embroidered band (current default), B quilt row, C foreground ridge, or a mix.
- Retag `[AI]` lines he agrees with in `docs/decisions.md` as `[USER]`.
- Fill in `docs/style-bible.md` where it still has blanks.
- Edit the art rule in CLAUDE.md.
- Top up Picsart credits before more API renders (balance was 0). Never batch background removal: about 1 credit per call.
- New Picsart Flow art: save as `<name>_raw.png` in `art/picsart/kit/raw/`, then run `python tools/art/picsart_kit.py --process-only`. Pines, grass and cliff are the weakest assets.
- Optional: godot-mcp setup on the PC (needs Node.js).

## Gotchas for Claude sessions
- Cloud sessions can't upload LFS objects (403) and the auto-mode classifier blocks running a downloaded Godot there, so Godot tests and screenshots usually run through a Remote Control session on the PC. Don't commit Godot 4.7's edits to existing project files.
- GDScript errors on type inference from Variant; use explicit types or `int()`.
- Autoloads don't `_ready` before a `-s` test script; tests call `Db.reload()`. A `-s` script that names game classes fails to compile; load a helper at runtime (see `tools/sandbox_shot.gd`).
- Full `balance_report` at 100 fights takes about 8 minutes.
