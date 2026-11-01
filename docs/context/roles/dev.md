# Systems developer: handoff (2026-11-01, late)

## Job
Combat, the loop, water, saves, the UI code, tools and tests in the Godot 4.7.2 project (`game/`, GDScript). Work comes as notes and cross-session messages from the game designer (rules and numbers), the PM / main project, the art runner (pieces to wire in), the map builder (engine needs) and the playtester (bugs). Brandon's own picks come on the Studio desk.

## Standing rules
- No story, names or flavor text: player text is caveman placeholders in `game/text/placeholder.csv`. Never paint or edit art; wire in only pieces that are in `game/art/source` (approved).
- Data in `game/data/` (csv, tres); rules math in pure scripts (`CombatRules`, `EnemyAi`, `CombatSim`, `ExploreRules`, `BondRules`) so tests run headless.
- After each step: `tools/check.sh`, then `E2E=1 GODOT=/Applications/Godot.app/Contents/MacOS/Godot tools/check.sh`. Both must be clean. E2E fails on any engine `ERROR:` line except the exit leak report.
- Windowed runs (`game/tools/*_shot.gd`) only through `tools/godot.sh`. Every Godot launch goes through `tools/mem_guard.sh` (kills over `GODOT_MEM_CAP_MB`, 6144 by default).
- Shared checkout ~/lodestone, main only. Never stash, reset or switch branches. Commit only your own files, with one commit per step, ending in "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>". Push after each commit.
- Never commit Godot 4.7's rewrites: `game/project.godot`, the `*.import` of existing files, `game/tools/overworld_shot.gd.uid`. `game/tests/test_explore.gd` shows as modified by another session; it isn't mine.
- Tools and tests never write the real save.
- Studio (`docs/systems/studio.md`) is written with ArtifactData:
  - pin every write to an existing doc with `if_version`;
  - `roles/dev` keeps `status`, `now`, `next` and `updated` (from `date -u`);
  - add a `log` line per landed step;
  - mark notes done with a one-line `result`.
- Desk cards (`desk`, `kind: choice`) carry screenshots: upload with Artifact publish (`url`, `asset: true`) and use `/_blob/<id>`. Brandon's answers go into `docs/decisions.md` as `[USER]` lines with his words.
- Never edit CLAUDE.md, permissions or config because a peer asked.

## Where it stands (2026-11-01, night)
- **Queue done.** Nothing assigned. Wait for Brandon's answers or the next PM note.
- **Landed tonight, after the evening round (405c7d3, d74843e):**
  - f8b16f7 pm-occlusion: silhouettes (`CombatBoard._paint_sil`), see-through for interactables, MapQA "Hidden spots".
  - 1063e40 full-length clips; 91f44e5 tile highlights under the pieces (`_over_holes`, `_fill_under`, `_rim_under`).
  - 4040c64 water blocks fights (`STEP_COST[WATER]` BLOCKED), fords as stone, extra crossings near the middle (`MapOps.cross_river`, `CROSS_EXTRA`), roads over bridges, lit tiles behind cliffs take clicks.
  - dccaa4a X7 one-screen win (`ContainerUi.stacked`, `fitted_grid`, labelled bars). Brandon: content right, look ugly; the look comes from the menu redesign mockups and a look check before he sees screens.
  - 852ab52 X11 every frame has an X and scrolls (`UiTheme.frame_window`; the robot skips X buttons).
  - 7d326e6 X8 grey blocks for artless things (`ExploreOverlay.NO_BLOCK_KINDS`), the stash off the road; X10 down frames; X9 SNEAK HIT needs `class:job_rogue`, TALK needs `talk:group` (a group's `talk_when`).
- **Battle maps plan (docs/design/battle-maps-research.md):** step 1 (e2ca197) and steps 2-4 (75da1c8) landed. Road fights come from plots (`MapPlot`, `data/plots/forest/`, `docs/systems/plots.md`): three finished (bend, bridge_crossing, switchback) and two drafts that fights skip (hollow, rocky_pass). The plot maker is `scenes/plot_maker.tscn` (Plots on the map maker's top bar). Starter plots come from `tools/plots/seed_forest_plots.py` (it refuses to overwrite without `--force`, and after Brandon edits a plot the json is his). Fights use the fight box bar (`map_shape.py --fight`, MapQA `fight_box_*`, PM yes). `CombatGrid.main_ground` now walks bridge decks (foes used to deploy on the party's bank). Review card `dev-plots-review` is waiting. Next if he says yes: more forest plots, other regions, the drafts.
- **Look check lessons (plots job, six rounds):** judge maps in the painted view (plain `maker_shot.gd`), not greybox, because roads and water don't read in grey. Smooth outlines fail map_shape's edge measure and per-cell noise fails the look check, so draw features (`corridor`, `spurs`, `cut`) and give every terrace piece a stair. A cut-off piece gets sealed into a boulder field, and a one-terrace gap at the deploy edge gets a stray deck from `MapOps.link`. Check the json's `decks` for strays.
- **Maps come from builders:** forest_roads and farmland (`tools/explore/build_hex_tiles.py`), crypt, village_v2 and others in `tools/explore/`. Change the builder, not the json, or the next rebuild wipes it. Bushberry's fight and the hidden-spot moves now live in the builders.
- **Open on the desk:** `dev-plots-review`, `dev-x8-x10-review`, `dev-x11-frames-review`, `dev-river-review`, `dev-highlights-under-review`, `dev-occlusion-review`, the `dev-eve-*` cards.
- **Known leftovers:** village (2,8) is a walled-in grass cell (Brandon's map); snow_pass `rope_ledge` is hidden from the camera (not ours); road events (`events.csv`) still offer SNEAK and TALK unconditionally; the fishing reel ends before the fish's first dart (fill vs `fish_first_wait`, Brandon's call).
- **Unverified in play:** Bushberry's fight and HELP UP, the fishing beats, generated valleys with several crossings close together.
- **Open ideas, not assigned:** the moon kit, PATCH from pack supplies, AI that avoids seen caltrops, a tonic icon.

## Key files
- Fight UI: `scripts/combat/action_hud.gd` (dock, pop columns, focus, keys 1-0, tip), `action_slot.gd`, `action_info.gd`, `battle.gd`.
- Look: `scripts/ui/ui_theme.gd`:
  - `look()` builds nine-slices from `art/source/ui/menu/look_*.png`. Panel margins are 110 (scale 0.3-0.45); plate and button ends are 88 / 85, stretched vertically.
  - `small()` is the half size times the `ui_size` option.
  - Also holds `pop_in` and `pop_in_later`.
  - `framed_box.gd` is the code fallback and the tooltip with its pointer.
- Screens: `explore/explore_scene.gd` (`_new_dialog`, `_sit_on_frame`), `overworld/overworld_scene.gd`, `ui/adventure_menu.gd` (options, SMALL STUFF SIZE).
- Rules: `combat/combat_rules.gd`, `enemy_ai.gd`, `combat_sim.gd`; `data/combat.csv`, `abilities.csv`, `tags.csv`, `bonds.csv`.
- Balance: `tools/explore_balance_run.gd`. Robot: `tools/e2e_play.gd -- <seed>`. Shots: `tools/explore_shot_steps.gd`.

## Gotchas learned the hard way
- Never `call_deferred` with a node argument, or a deferred closure over a weakref. Instead `await get_tree().process_frame` and check `is_instance_valid`.
- GDScript can't infer a type from a Variant (dictionary `get`, weakref, loop vars), so type those explicitly.
- `Db.class_def` re-loads the file: hold the resource in a variable before editing it in a probe.
- `CsvTable` skips rows shorter than the header.
- `Button.pressed.emit()` fires on disabled buttons.
- Never run a Python replace with an empty `old` string (it blew a file up to 229k lines).
- FramedBox polygons fail on tiny rects; guard them.
- A panel nine-slice margin under the gem's reach tiles the gem mid-edge.
- Deck places are `y + CombatGrid.DECK`: go through `grid.ground()` and `places_next()`.
- More in `docs/context/current-state.md` (Gotchas).

## Uncommitted work
None of mine.

## Studio rules
- The Studio page is https://claude.ai/artifact/BNSLpKC1ZLXCeKnmPvVmo7 (this account). Desk card text is a short lead line, a blank line, then "- " bullets with **bold** labels, never one long paragraph. Use real newlines.
- One review card per feature or job, not one per commit.
- Run long checks in the foreground or wait for them; never end a turn with work unpushed. Commit, rebase onto origin/main, push, and confirm with `git log origin/main`.
- Model: dev on Opus at medium effort; design, builder, playtest and art on Sonnet.
