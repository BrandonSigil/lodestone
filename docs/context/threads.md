# Thread history

One entry per thread in Brandon's Claude project, oldest first. Each says what was asked, what came out, and what's still open. Dates are 2026.

## Plan a cheap, beautiful Godot game pipeline (Oct 25, done)
- Ask: Brandon pasted a "best AAA setup with Claude" summary and a Reddit devlog (manager session plus per-system sessions, decisions.md with [USER]/[AI] tags) and wanted a plan.
- Output: the Studio Playbook page (`artifacts/studio-playbook.html`).
- Calls: Godot 4, 2D, GDScript (skip Unreal, Blender, image generators); manager plus system sessions; `decisions.md` with owner tags; style bible before the first sprite; one "Strangeness" number per region drives palette, shapes, creatures and sound; near-free tooling; six-week order of work starting with a graybox.
- Later changed: the "no AI-generated art" call (see `current-state.md`).

## Build the Lodestone graybox prototype (Oct 25, done)
- Ask: build week 1 of the playbook.
- Output: Godot project pushed straight to `main` (empty repo). Iso grid combat with height, forest, water and rock; d20 attacks with high-ground bonuses; trail days with walk, rest, hunt, forage, food, getting lost, 12 slots with the Wizard's books taking 3; CSV events showing success chance per choice; roster unlocks; Lodestone recall. 29 tests and 3 scene smoke runs.
- Created `CLAUDE.md`, `docs/decisions.md`, `docs/style-bible.md` template, `game/text/placeholder.csv`.

## Start Remote Control session (Oct 25 to 26, idle)
- Brandon tried `/claude rc`. A Remote Control session later connected on the PC "Gamer" in `C:\Users\Brand\Claude`. No task was given. Nothing to carry over.

## Run the Lodestone demo on my PC (Oct 26, done)
- Cloned the repo to `C:\Users\Brand\Claude\lodestone`, found Godot 4.7.2 (project targeted 4.4, works fine), all tests passed, launched the demo.
- Open: godot-mcp setup was offered (needs Node.js via winget). No answer yet.

## Shape the Lodestone visual language (Oct 26, waiting on Brandon)
- Ask: where to ideate on visuals with AI; reference images; the riso-windowseat repo as inspiration; UI tucked into a bottom decorative frame.
- Output: the Style Lab page (`artifacts/style-lab.html`, source also in `docs/style-lab/`). Draft 1: colors measured from 7 references, rules R1 to R10, five region palettes blended by strangeness, three bottom frames (A embroidered band, B quilt row, C foreground ridge). Merged as PR #1. Draft 2: six gaps F1 to F6 (perfect edges, no single light, uniform grain, one-horizon layout, plain pawns, loud UI) with a before/after village, PR #3.
- Brandon rejected code-only art and asked how AI-built games get good art. Proposed pipeline: style LoRA trained on his own drawings, Krita AI Diffusion (free, local, his GPU has 8 GB+), paint-over, code for palette lock, grain and animation. He said "let's do it"; recorded [USER] and written up in `docs/art-pipeline.md` (PR #4). Setup reached the point of installing the local generator in Krita.
- Since then: Brandon paused Krita and moved to Picsart, so the LoRA plan is on hold.
- Open: bottom frame pick (A, B, C or a mix). CLAUDE.md art rule edit by Brandon.

## Build the starting village hub (Oct 26, done)
- Ask: the starting village in the Style Lab look, with team select, supply shop, Tetris-style inventory and a mayor for lore and side quests.
- Output: riso drawing kit (`game/scripts/riso/`: palettes, shape helpers, grain shader, theme, font), village scene in frame A, team select, shop (`data/items.csv`), 4x3 pack with rotation and selling, the Wizard's books as an unsellable 3-cell L, mayor panel with side jobs (`data/quests.csv`). Merged to main inside PR #2.
- [AI] calls to review: frame A used while the pick is open; the lord's bonus became 30G gold instead of free food.
- Open: side jobs can be taken but not completed yet.

## Create the riso world map (Oct 26, done)
- Ask: a general world map in the riso look that the player slowly uncovers; the team sees all of it for now, fog of war later.
- Output: `scenes/world_map.tscn`, `scripts/world/`, `data/world/`, world shaders. Home bottom-left, route climbing to the Wall down the middle, stranger regions east. 300-league route with the Wall gate at league 150, walked ground printed dark, run marks and best distance. Discovery as revealed circles; FOG PEEK previews the player view. Merged as PR #2 (with the village work).
- Open: whether fog is on by default is Brandon's call; layout lines are [AI] in `docs/decisions.md`.

## Build a full tactical combat sandbox (Oct 26, done)
- Ask: a test environment to edit maps, reload fights, balance teams and scale difficulty; FE/XCOM-style action menus (move, attack, spell, item); research what makes tactics fun.
- Output: PR #5 combat sandbox (F9 anywhere): map painter, difficulty dials and EASY to BRUTAL presets, restart, AI-vs-AI sim (`CombatSim`, `tools/balance_report.gd`), action menus with hit forecasts, counterattacks, ledge pushes, danger zone view. Skills in `data/abilities.csv`, fight items in `data/combat_items.csv`, maps as JSON in `data/maps`. Research in `docs/research/tactical-combat.md`.
- PR #6 terrain and height: heights 0 to 8, stairs (+2 climb), stone floors, ruin walls, line of sight (cliffs, ruins, boulders, trees block), camera rotate with Q, temple and cliffs maps rebalanced so NORMAL is winnable.
- PR #7 traits and spell picks: one combat trait per roster character (in `data/characters/*.tres`, rules in `CombatRules`), casters pick 2 spells from a class pool (`spell_pool`, `spell_slots`), SPELLS picker in the sandbox, `tools/spell_report.gd`. 85 tests.
- Watch: the moon mage's area blast makes bunched enemies on the default map too easy.

## Build battle map art into the game (Oct 26 to 27, done)
- Ask: use Brandon's isometric reference image to set the battle map look, write exact rules for an "art team", give prompt-ready ratios and grid references, and a template to draw maps on a tablet.
- Output: the Battle Map Guide page (`artifacts/battle-map-guide.html`) and `docs/art/battle-maps.md`, rules B1 to B32 (2:1 dimetric, art at 2x engine with 128x64 tiles and 32 px per level, sun fixed upper left, top/lit/shade values 100/75/55, outline #373335). Templates in `art/templates/battle-maps/` (PSD and ORA, blank 16x16, one per sandbox map, tile kit sheet, control PNGs) built by `tools/art/battle_art.py`. PR #8.
- Picsart: Brandon chose the Picsart API (PR #9 test renders; temple held the grid). Then 9 textures and 7 props generated (`tools/art/picsart_kit.py` and `.json`, finals in `game/art/source/battle/`) and wired into the combat board with graybox fallback (PR #10). Background removal drained the credits to 0. Sharper prompts for pines, grass and cliff (PR #11). The guide gained a Picsart Flow recipe for the $20 app plan, since Flow can't import workflow files.
- Oct 27, Krita on the MacBook: Krita AI Diffusion walkthrough and snowy-cliffs blocking (PR #13). Brandon corrected the plan: maps are built in Godot, and each zone look starts as a painted concept map broken out into a tile set. Built tile sets per zone with a sandbox "tile set" menu (PR #14), a sampler map, zone starting pictures and the break-out tool (PR #16), a grid-fit check and 3:2 inputs for image models (PR #17), and zone palette cards to use as a reference image in Picsart (PR #18).
- Krita at full-map scale came out flat and sloppy, so concept maps moved to image models (Picsart / GPT). Krita is now for touch-ups.
- Superseded by the flat zone tile sets made in the next thread.

## Move all Lodestone files into the repo (Oct 27, done)
- Ask: keep everything in the repo so the MacBook and another account have it.
- Output: commit 72c977f on main. Picsart work in `art/picsart/`, screenshots in `art/screens/`, empty Krita folders, scripts and `docs/art-pipeline.md` updated. API key moved to `~/.lodestone/picsart-api-key`.

## Build character templates and flat terrain sets (Oct 27, open)
Started as "Build the character sprite template and Krita guide" and grew into the main art thread of the night.
- Character template: Brandon's chibi sheet became the template for every character, monster and boss. `docs/art/characters.md` (rules C1 to C29), Krita templates in `art/templates/characters/` built by `tools/art/char_art.py`, and the Character Guide page (`artifacts/character-guide.html`). PR #15. A 3D (Blender) route was discussed; Claude suggested testing it on one hero, nothing decided.
- Picsart for characters: three reference images (mannequin view, cleaned key view, palette card), Flows "Lodestone character view" and "Lodestone turnaround", and `char_art.py import`. PR #19.
- House-style prompt blocks for Picsart canvases (`art/prompts/style-*.txt`, PR #20). Brandon saved his Picsart key at `~/.lodestone/picsart-api-key` on the Mac; a venv at `~/.lodestone/venv` runs the art scripts.
- Terrain sheets: Sunburst prompts for a zone sheet and a game-ready tile kit (PR #21), rougher then simpler finishes (PRs #22, #29), Flux vs GPT image tests through the Picsart API on the Mac (PRs #23 to #30). GPT image with a single style reference won. Brandon loved the flat forest panel, so it became the only style reference (PRs #31 to #35, including `art/prompts/flat-style-portable.txt` for other agents). Flat forest and snow kits (PR #36), cut into game tile sets by `tools/art/kit_cut.py` (PR #37), then six more zones: 8 sets in all (PR #38).
- Hero sprites: GPT animation sheets for SE and NE cut into game strips by `tools/art/anim_sheet_cut.py`; the `lead` hero idles, walks, swings, casts and flinches in battle (PR #39). Previews in project files `character-art/lead/`.
- Brandon's playtest notes (after PR #39): show units behind trees and pillars, grid toggle, combat stance with weapon drawn, floating-island map shapes with rough stepped undersides and drips (the "Lich King tomb" sheet is the reference), drop the old base tile set, blended-zone maps. Two were done on the MacBook but not pushed when the session stalled.
- Open: the rest of those notes; roaming views (S, E, N); other characters; Brandon's sign-off on C1 to C29.

## Export project context into the repo (Oct 27, done)
- First export of `docs/context/` (PR #12).

## Build walkable exploration maps (Oct 27, done)
- Ask: big isometric maps the party roams with fog of war, where spotting enemies starts combat right there and doors or chests pop an "interact" box with options based on the party. Brandon's reference images set layout only, not style. Then [USER]: only the main character walks; when combat starts you place the party around the leader, quick characters further out.
- Output: PR #42. `scenes/explore.tscn` (F10), `game/scripts/explore/`, `data/explore/crypt.json` (from `tools/explore/build_crypt.py`), `data/explore_events.csv`, `docs/systems/explore.md`. Fog on line of sight, spotting and ambush, in-place fights with a deploy ring (move - 3), skill-gated options with dice checks. 101 tests.
- PR #43: WASD walking (screen-relative, slides along walls) and no grid lines outside fights (`CombatBoard.show_grid`).
- Open: Brandon to try it and tune ring size and WASD speed; roaming sprite views; hooking explore maps into the trail.

## Rework systems for the empty village premise (Oct 27, open)
- Ask: Brandon set a new premise (everyone gone, empty decayed village, hero and corgi, survivors become settlers or party members). Record it and work out the systems side; keep the old plans on file.
- Output: `docs/design/empty-village.md` (corgi, survivors, village rebuilding with salvage and settler buildings, GO HOME recall, roster unlocks as `met_<id>`, build order, open questions). Premise in `docs/decisions.md`. PR #40. No game code changed.
- Brandon answered: settlers are NPCs between runs (no swapping), the corgi fights and sniffs ("ears perk up... or a squirrel"), gold and the shop come with a blacksmith or merchant, the Lodestone is unearthed early and revealed on the first death, the Wall stays. Draft 2 follows these (PR #41).
- Brandon added: the hero is a nobody who leaves their house, picks from a couple of weapons at the blacksmith, may find a hidden item, and grows a class Fire Emblem style. Draft 3 adds the village opening (section 7) and the job tree with levels and XP (section 8), PR #44.
- Open: survivor kind fixed per character or chosen; who survives. Then build steps 1 to 3.

## Refresh project context in the repo (Oct 27, done)
- Brandon asked whether everything from the night was in the repo so a friend on another account could help. Refreshed `docs/context/` (memory copy, this file, `current-state.md`, latest Character Guide and Battle Map Guide HTML) and the newcomer pointer in `CLAUDE.md`.
