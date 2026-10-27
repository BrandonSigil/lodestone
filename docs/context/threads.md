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

## Build battle map art into the game (Oct 26, done)
- Ask: use Brandon's isometric reference image to set the battle map look, write exact rules for an "art team", give prompt-ready ratios and grid references, and a template to draw maps on a tablet.
- Output: the Battle Map Guide page (`artifacts/battle-map-guide.html`) and `docs/art/battle-maps.md`, rules B1 to B32 (2:1 dimetric, art at 2x engine with 128x64 tiles and 32 px per level, sun fixed upper left, top/lit/shade values 100/75/55, outline #373335). Templates in `art/templates/battle-maps/` (PSD and ORA, blank 16x16, one per sandbox map, tile kit sheet, control PNGs) built by `tools/art/battle_art.py`. PR #8.
- Picsart: Brandon chose the Picsart API (PR #9 test renders; temple held the grid). Then 9 textures and 7 props generated (`tools/art/picsart_kit.py` and `.json`, finals in `game/art/source/battle/`) and wired into the combat board with graybox fallback (PR #10). Background removal drained the credits to 0. Sharper prompts for pines, grass and cliff (PR #11). The guide gained a Picsart Flow recipe for the $20 app plan, since Flow can't import workflow files.
- Open: top up credits; regenerate the weak assets; engine work for full painted tiles listed in `docs/art/battle-maps.md` is not all built.

## Move all Lodestone files into the repo (Oct 27, done)
- Ask: keep everything in the repo so the MacBook and another account have it.
- Output: commit 72c977f on main. Picsart work in `art/picsart/`, screenshots in `art/screens/`, empty Krita folders, scripts and `docs/art-pipeline.md` updated. API key moved to `~/.lodestone/picsart-api-key`.

## Build the character sprite template and Krita guide (Oct 27)
- Ask: use Brandon's chibi character sheet as the template for all characters, add front / back / left / right views for free roaming, and write a detailed Krita guide for characters, monsters and bosses that fits the iso maps.
- Output: `docs/art/characters.md` (rules C1 to C29, sizes, export names, engine plan), diagrams in `docs/art/characters/`, templates in `art/templates/characters/` (model sheet with 3D mannequins and control PNGs per view, paper-doll parts front/back, anim canvas, sprite sheet, palette, layout.json) built by `tools/art/char_art.py`, which also exports painted files to `game/art/source/characters/<id>/`. Character Guide page (`artifacts/character-guide.html`). Fixed `save_psd` writing layer alpha as masks and regenerated the battle-map PSDs.
- Follow-up: Picsart section in the guide (three reference images: mannequin view, key view, palette card `art/palettes/characters.png`; Flows "Lodestone character view" 1:1 and "Lodestone turnaround" 3:2) and `char_art.py import`, which keys out the background, re-anchors the feet and writes the model sheet.
- Open: Brandon's sign-off on C1 to C29; engine work (sprite node, facing, anim states, paper doll, recolour, multi-cell units, free roaming).

## Export project context into the repo (Oct 27)
- This export: `docs/context/`.
