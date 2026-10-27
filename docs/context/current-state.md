# Current state (2026-10-27, refreshed 11:30 UTC)

## Where things live
- Repo: github.com/BrandonSigil/lodestone, branch `main`. Godot project in `game/`. The repo is the single source of truth: pull before work, push after.
- Brandon's machines: Windows PC "Gamer" (Godot 4.7.2, repo at `C:\Users\Brand\Claude\lodestone`) and a MacBook Pro M4 Max (repo at `~/lodestone`, Godot in Applications, Krita AI Diffusion). Claude reaches both through Remote Control sessions. He may also use a second Claude account.
- Run `git lfs install` before cloning. `.gitattributes` sends PNG, PSD, KRA, WAV and OGG to Git LFS except the plain-git paths listed there (art templates, docs art, battle and character game art, paintings, character working files). Cloud Claude sessions can't upload LFS objects (403), so new binary folders need the same exemption.
- Art working files: `art/` (prompts in `art/prompts/`, Picsart runs in `art/picsart/`, palettes in `art/palettes/`, templates in `art/templates/`, characters in `art/characters/<id>/`, paintings in `art/paintings/`, screenshots in `art/screens/`). Game-ready art: `game/art/source/`.
- Secrets: the Picsart API key lives only at `~/.lodestone/picsart-api-key` (or env `PICSART_API_KEY`) on each machine, and is gitignored. Never paste it in chat, print it, log it or commit it. A key was once pasted in chat, so Brandon should rotate it. On the Mac, art scripts run in a venv at `~/.lodestone/venv` (`requests pillow numpy psd-tools`).

## How to run it
1. Install Godot 4.4 or newer (4.7.2 works; don't commit Godot 4.7's rewrites of existing project files).
2. Open `game/project.godot`. F5 starts the village.
3. Anywhere in the game: **F9** combat sandbox, **F10** walkable exploration map. In the editor, F6 runs the open scene.
4. Checks: `GODOT=/path/to/godot tools/check.sh` (headless import, about 100 unit tests, smoke runs of village, trail, combat, world_map, combat_sandbox and explore). Run it after every change.
5. Screenshots headless: `tools/screenshot.sh`, `game/tools/explore_shot.gd`, `game/tools/sandbox_shot.gd` (in the cloud: `xvfb-run` and `--rendering-driver opengl3`).

## What's built (all on main)
- Week 1 graybox: iso grid combat with height and d20 checks, trail loop (days, food, morale, 12 slots, CSV events), village roster with unlocks, Lodestone recall save.
- Village hub (riso style, bottom frame A): team select, shop, 4x3 Tetris pack, mayor side jobs. Riso kit in `game/scripts/riso/`. (The empty-village premise will replace the mayor and gate the shop; not in code yet.)
- Riso world map: route with the Wall at league 150, fog-ready discovery (FOG PEEK toggle).
- Combat sandbox (F9): map painter, difficulty dials, FE/XCOM action menus with hit forecasts, counters, ledge pushes, AI-vs-AI balance sim; heights 0 to 8, stairs, ruins, line of sight, camera rotate (Q); character traits and caster spell picks.
- Battle tile sets: 8 flat zone sets in `game/art/source/battle/<zone>/` (forest, snow, ruins, dungeon, farmland, marsh, canyon, crystal; PRs #37, #38), picked from the sandbox "tile set" dropdown (under SUPPLIES AND RULES) and saved with the map. Cut from Picsart GPT-image tile kits by `tools/art/kit_cut.py`. The older painted base set and graybox fallback still exist on main.
- Hero sprites (PR #39): character id `lead`, idle / walk / attack / cast / hurt in SE and NE (SW and NW are mirrors), faces its move or attack target, hit lands on the strike frame, survives camera turns. Loader `game/scripts/combat/character_art.gd`. Other characters are still pawns. Placeholder art until Brandon approves.
- Walkable exploration (PRs #42, #43): F10 opens the 34x30 `crypt` test map. Only the leader walks (click or WASD, grid hidden outside fights), fog of war on line of sight, enemy groups that spot you or get spotted, fights start in place with a deploy ring around the leader (ring = move - 3, min 1; +1 on a sneak attack; 1 when ambushed), "!" interactables with party-gated options and dice checks. See `docs/systems/explore.md`.
- Art pipeline docs and tools: battle map rules B1 to B32 (`docs/art/battle-maps.md`), character rules C1 to C29 (`docs/art/characters.md`), Krita templates, `tools/art/battle_art.py`, `char_art.py`, `break_out.py`, `picsart_sheet.py`, `anim_sheet_cut.py`, zone palette cards, and house-style prompts in `art/prompts/` (see `art/prompts/README.md` and `flat-style-portable.txt`).

## The art recipe that works now
- Model: GPT image (`gpt-image-2.5-sunburst`) through the Picsart API on the MacBook, about 10¢ per sheet at 2K. Flux is cheaper but copies references too literally.
- Look: Brandon loves the SIMPLE flat style: near-solid grass with a few dots, two-tone blob trees, three flat values, plain one-colour cliffs. "Too detailed" is his recurring complaint.
- Reference images: his approved flat forest panel (`docs/art/references/style-flat-forest.png`) plus its tile-row crop for tile kits. Attach only those. Never feed a result back in as a reference; detail compounds.
- Picsart's credits endpoint reads 0 even when the dollar wallet has money; `picsart_sheet.py` no longer stops on it.

## Superseded notes (older lines that are out of date)
- 2026-10-27 [USER] New premise: the hero and their corgi in an empty, decayed village; predetermined survivors are met in the world. This supersedes the scout / King / lord framing and the run-count roster unlocks (kept on file in `docs/decisions.md`). Brandon's answers: settlers are NPCs between runs, the corgi fights and sniffs, gold and shop unlock with a blacksmith or merchant who settles, the Lodestone is unearthed early and its power revealed on the first death, the Wall stays (elves or an elvish prophecy). Systems doc: `docs/design/empty-village.md`.
- "Brandon draws every final mark / no AI image gen" (2026-10-25): replaced 2026-10-26 [USER]. AI-generated art directed by Brandon is allowed. The CLAUDE.md art rule still says otherwise until Brandon edits it.
- Krita AI Diffusion as the main painter and the "paint a concept map, then break it out" flow (early 2026-10-27): Krita at full-map scale looked flat; Picsart GPT tile kits replaced it. Krita is for touch-ups. The break-out tool still works.
- Style LoRA plan and the busy hand-painted Picsart kit (pines, grass, cliff): on hold; the flat zone sets replace it.
- Paths under `lodestone-art\...`: moved into the repo's `art/` and `~/.lodestone/`.

## In flight (2026-10-27)
- Combat polish from Brandon's playtest notes (thread "Build character templates and flat terrain sets"): see-through props or outlines for hidden units, grid toggle, combat stance with weapon drawn, floating-island map shapes with rough stepped undersides and drips, remove the old base tile set (forest default), blended-zone maps. The grid toggle and base set removal were done on the MacBook but NOT pushed; check `~/lodestone` there first and use `CombatBoard.show_grid` from PR #43.
- Empty village design (thread "Rework systems for the empty village premise"): draft 3 (PR #44) adds the nobody start (the village as the first explore map, a smithy weapon rack, a hidden item) and a three-tier Fire Emblem style job tree with levels, XP and growths. Docs only so far.

## Open items waiting on Brandon
- Empty village: is a survivor settler-or-party-member by who they are (Claude's assumption)? Who survives, and which kind? Draft 3 job system: are levels kept through recall, one smithy weapon or more, the three-tier tree and branch names.
- Pick the bottom frame: A embroidered band (current), B quilt row, C foreground ridge, or a mix.
- Retag `[AI]` lines he agrees with in `docs/decisions.md` as `[USER]`; mark rules B1 to B32 and C1 to C29 his or change them.
- Fill in `docs/style-bible.md`; edit the art rule in CLAUDE.md.
- Approve or replace the generated `lead` sprite; roaming views (S, E, N) and the rest of the roster come after.
- Tune the explore deploy ring (move - 3) and WASD speed after playing.
- Rotate the Picsart key.

## Gotchas for Claude sessions
- Godot in the cloud rewrites every art `.import` file; `git checkout -- game/art` before committing. Godot 4.7 on Brandon's machines edits project files too; don't commit those edits.
- Picsart (picsart.io) is blocked from the cloud container, so API runs happen on the MacBook through Remote Control.
- `save_psd` in `tools/art/battle_art.py` must build an RGBA PSD, or psd-tools hides strokes behind a layer mask.
- GDScript errors on type inference from Variant; use explicit types or `int()`.
- Autoloads don't `_ready` before a `-s` test script; tests call `Db.reload()`. A `-s` script that names game classes fails to compile; load a helper at runtime (see `game/tools/sandbox_shot.gd`).
- Full `balance_report` at 100 fights takes about 8 minutes.
- Several threads push to main at once. Pull often, keep PRs small, and don't edit shared render code (`CombatBoard`) without checking what other open work touches it.
