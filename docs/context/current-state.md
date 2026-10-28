# Current state (2026-10-27, refreshed 16:30 UTC)

## Where things live
- Repo: github.com/BrandonSigil/lodestone, branch `main`. Godot project in `game/`. The repo is the single source of truth: pull before work, push after.
- Brandon's machines: Windows PC "Gamer" (Godot 4.7.2, repo at `C:\Users\Brand\Claude\lodestone`) and a MacBook Pro M4 Max (repo at `~/lodestone`, Godot in Applications, Krita AI Diffusion). Claude reaches both through Remote Control sessions. He may also use a second Claude account.
- Run `git lfs install` before cloning. `.gitattributes` sends PNG, PSD, KRA, WAV and OGG to Git LFS except the plain-git paths listed there (art templates, docs art, battle and character game art, paintings, character working files). Cloud Claude sessions can't upload LFS objects (403), so new binary folders need the same exemption.
- Art working files: `art/` (prompts in `art/prompts/`, Picsart runs in `art/picsart/`, palettes in `art/palettes/`, templates in `art/templates/`, characters in `art/characters/<id>/`, paintings in `art/paintings/`, screenshots in `art/screens/`). Game-ready art: `game/art/source/`.
- Secrets: the Picsart API key lives only at `~/.lodestone/picsart-api-key` (or env `PICSART_API_KEY`) on each machine, and is gitignored. Never paste it in chat, print it, log it or commit it. A key was once pasted in chat, so Brandon should rotate it. On the Mac, art scripts run in a venv at `~/.lodestone/venv` (`requests pillow numpy psd-tools`).

## How to run it
1. Install Godot 4.4 or newer (4.7.2 works; don't commit Godot 4.7's rewrites of existing project files).
2. Open `game/project.godot`. F5 opens the launch menu (`scenes/launch.tscn`): one button per built place. **Start game** is the hero's cottage; the rest fast-travel to the village hub, trail, world map, each explore map, the trail fight and the sandbox.
3. Anywhere in the game: **F8** launch menu, **F9** combat sandbox, **F10** walkable exploration map. In the editor, F6 runs the open scene.
4. Checks: `GODOT=/path/to/godot tools/check.sh` (headless import, about 100 unit tests, smoke runs of village, trail, combat, world_map, combat_sandbox and explore). Run it after every change.
5. Screenshots headless: `tools/screenshot.sh`, `game/tools/explore_shot.gd`, `game/tools/sandbox_shot.gd` (in the cloud: `xvfb-run` and `--rendering-driver opengl3`).

## What's built (all on main)
- Week 1 graybox: iso grid combat with height and d20 checks, trail loop (days, food, morale, 12 slots, CSV events), village roster with unlocks, Lodestone recall save.
- Village hub (riso style, bottom frame A): team select, shop, 4x3 Tetris pack, mayor side jobs. Riso kit in `game/scripts/riso/`. (The empty-village premise will replace the mayor and gate the shop; not in code yet.)
- Riso world map: route with the Wall at league 150, fog-ready discovery (FOG PEEK toggle).
- Combat sandbox (F9): map painter, difficulty dials, FE/XCOM action menus with hit forecasts, counters, ledge pushes, AI-vs-AI balance sim; heights 0 to 8, stairs, ruins, line of sight, camera rotate (Q); character traits and caster spell picks.
- Battle tile sets: 8 flat zone sets in `game/art/source/battle/<zone>/` (forest, snow, ruins, dungeon, farmland, marsh, canyon, crystal; PRs #37, #38), picked from the sandbox "tile set" dropdown (under SUPPLIES AND RULES) and saved with the map. Cut from Picsart GPT-image tile kits by `tools/art/kit_cut.py`. The old base set was removed in PR #47; forest is the default.
- Hero sprites (PR #39): character id `lead`, idle / walk / attack / cast / hurt in SE and NE (SW and NW are mirrors), faces its move or attack target, hit lands on the strike frame, survives camera turns. Loader `game/scripts/combat/character_art.gd`. Other characters are still pawns. Placeholder art until Brandon approves.
- Walkable exploration (PRs #42, #43): F10 opens the explore scene (since PR #51 it starts in the hero's cottage; the 34x30 `crypt` test map is still in `data/explore/`). Only the leader walks (click or WASD, grid hidden outside fights), fog of war on line of sight, enemy groups that spot you or get spotted, fights start in place with a deploy ring around the leader (ring = move - 3, min 1; +1 on a sneak attack; 1 when ambushed), "!" interactables with party-gated options and dice checks. See `docs/systems/explore.md`.
- Starting village prototype (thread "Prototype the starting village map"): F10 opens the hero's cottage (`home`); out the door is the `village` explore map (square, well, town hall on a terrace, tavern, smithy with the weapon rack, five homes, stream, gate to the trail), plus walk-in `house_ne` (hidden book in the inner room) and `tavern`. Placed props and whole-building sprites on the grid (`CombatGrid.props`), doors between maps, `hidden` things, once flags, per-set `battle_art_<set>.csv`. Art from Picsart: tile sets `village` and `village_in`, props and buildings (`tools/art/picsart_village.py`, `village_cut.py`). Builder `tools/explore/build_village.py`. The crypt test map is still in `data/explore/` (set `Game.explore_map`).
- Key art studio and sampler (on `lodestone-all-work`, not yet on main): `python3 tools/studio/studio.py` serves the studio at `/`. Every round goes to Picsart with the key art (`docs/art/characters/00-reference-sheet.png`) as image 1, and an edit round also gets the round it changes as image 2. Brandon rates each round 1 to 5 against the key art; a round under 4 refines by itself when sent; a job stops at 4 rounds. `/sampler` lists the pictures in `art/picsart/out/key-art-sampler/` with scripted checks (`tools/art/sampler_check.py`, bands in `BANDS`) and a blind vision grade (`art/prompts/sampler-grade-rubric.md`). As of 2026-10-27 only v10 passes both: v8 fails scale (grade 2), v9 passes the grade but its strokes are 2 px hairlines.
- Art pipeline docs and tools: battle map rules B1 to B32 (`docs/art/battle-maps.md`), character rules C1 to C29 (`docs/art/characters.md`), Krita templates, `tools/art/battle_art.py`, `char_art.py`, `break_out.py`, `picsart_sheet.py`, `anim_sheet_cut.py`, zone palette cards, and house-style prompts in `art/prompts/` (see `art/prompts/README.md` and `flat-style-portable.txt`).

## The art recipe that works now
- Model: GPT image (`gpt-image-2.5-sunburst`) through the Picsart API on the MacBook, about 10¢ per sheet at 2K. Flux is cheaper but copies references too literally.
- Character sheets default to **1K** (5.5¢) through `tools/art/char_sheet.py`: the cutter shrinks every sheet to sprite size, so 1K and 2K look the same in game (tested on the lead's S facing). A hero's five facings times two sheets is about 55¢; a combat-only enemy (SE, NE) 11 to 22¢. Tile kits, maps and village art stay at 2K.
- Look: Brandon loves the SIMPLE flat style: near-solid grass with a few dots, two-tone blob trees, three flat values, plain one-colour cliffs. "Too detailed" is his recurring complaint.
- Reference images: his approved flat forest panel (`docs/art/references/style-flat-forest.png`) plus its tile-row crop for tile kits. Attach only those. Never feed a result back in as a reference; detail compounds.
- Picsart's credits endpoint reads 0 even when the dollar wallet has money; `picsart_sheet.py` no longer stops on it.

## Superseded notes (older lines that are out of date)
- 2026-10-27 [USER] New premise: the hero and their corgi in an empty, decayed village; predetermined survivors are met in the world. This supersedes the scout / King / lord framing and the run-count roster unlocks (kept on file in `docs/decisions.md`). Brandon's answers: settlers are NPCs between runs, the corgi fights and sniffs, gold and shop unlock with a blacksmith or merchant who settles, the Lodestone is unearthed early and its power revealed on the first death, the Wall stays (elves or an elvish prophecy). Systems doc: `docs/design/empty-village.md`.
- "Brandon draws every final mark / no AI image gen" (2026-10-25): replaced 2026-10-26 [USER]. AI-generated art directed by Brandon is allowed. The CLAUDE.md art rule still says otherwise until Brandon edits it.
- Krita AI Diffusion as the main painter and the "paint a concept map, then break it out" flow (early 2026-10-27): Krita at full-map scale looked flat; Picsart GPT tile kits replaced it. Krita is for touch-ups. The break-out tool still works.
- Style LoRA plan and the busy hand-painted Picsart kit (pines, grass, cliff): on hold; the flat zone sets replace it.
- Paths under `lodestone-art\...`: moved into the repo's `art/` and `~/.lodestone/`.

## Recently landed (2026-10-27 afternoon)
- Combat polish (PR #47): all six playtest notes done. Prop fade and x-ray for hidden units, grid checkbox (`CombatBoard.show_grid`), lead combat stance, floating-island maps (HOLE tool, rock rims, spill-off water, backdrop), per-cell zone tile sets (ZONE brush), 4 blended `blend_` maps, forest default. Rough edges: code-drawn underside rock, hard zone seams.
- Exploration crypt uses the new tile sets (PR #48).
- Job system decisions (PRs #46, #49): levels persist through recall; one smithy weapon, final: sword, daggers or bow to knight, rogue or archer; a hidden book in a home unlocks mage at level 5 (wizard / healer). Tier 2 names still open.
- Starting village prototype (PR #51, merged): F10 now starts in the hero's cottage `home`, then `village` (square, town hall, tavern, smithy, homes, gate) and interiors `house_ne` and `tavern`. Smithy rack sets `weapon_sword` / `weapon_daggers` / `weapon_bow`; the hidden book sets `found_book`. Placed props and whole-building sprites, doors between maps. Picsart art (about $1.57), placeholder until Brandon approves.
- Character sprite contributor how-to (PR #50) for adding new characters.

## Machines and worktrees
- The MacBook now has Godot 4.5.1. Keep the project 4.4-compatible: don't commit `project.godot` version bumps or 4.5's `.import` rewrites.
- Brandon plays clean main from the worktree `~/lodestone-main`. Claude threads on the Mac work in `~/lodestone` or their own worktrees and must commit and push; nothing should stay Mac-only.

## Open items waiting on Brandon
- Empty village: is a survivor settler-or-party-member by who they are (Claude's assumption)? Who survives, and which kind? Job system: tier 2 branch roles and names. Approve or replace the village prototype art.
- Pick the bottom frame: A embroidered band (current), B quilt row, C foreground ridge, or a mix.
- Retag `[AI]` lines he agrees with in `docs/decisions.md` as `[USER]`; mark rules B1 to B32 and C1 to C29 his or change them.
- Fill in `docs/style-bible.md`; edit the art rule in CLAUDE.md.
- Approve or replace the generated `lead` sprite (now all five drawn views S, SE, E, NE, N with every anim; sheets in `art/picsart/out/anim-lead-<dir>_v1.png` and `stance-lead-<dir>_v1.png` on the MacBook); the rest of the roster comes after.
- Tune the explore deploy ring (move - 3) and WASD speed after playing.
- Rotate the Picsart key.

## Gotchas for Claude sessions
- Godot in the cloud rewrites every art `.import` file; `git checkout -- game/art` before committing. Godot 4.7 on Brandon's machines edits project files too; don't commit those edits.
- The MacBook has no git-lfs (PNGs go in as plain blobs) and a big art push dies with "unexpected disconnect"; push with `git -c http.postBuffer=524288000 push`. Godot there is `/Applications/Godot.app/Contents/MacOS/Godot` (4.7.2).
- Picsart (picsart.io) is blocked from the cloud container, so API runs happen on the MacBook through Remote Control.
- `save_psd` in `tools/art/battle_art.py` must build an RGBA PSD, or psd-tools hides strokes behind a layer mask.
- GDScript errors on type inference from Variant; use explicit types or `int()`.
- Autoloads don't `_ready` before a `-s` test script; tests call `Db.reload()`. A `-s` script that names game classes fails to compile; load a helper at runtime (see `game/tools/sandbox_shot.gd`).
- Full `balance_report` at 100 fights takes about 8 minutes.
- Several threads push to main at once. Pull often, keep PRs small, and don't edit shared render code (`CombatBoard`) without checking what other open work touches it.
