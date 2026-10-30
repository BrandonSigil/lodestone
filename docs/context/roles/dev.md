# Systems developer: handoff (2026-10-30)

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
- Studio (https://claude.ai/artifact/BNSLpKC1ZLXCeKnmPvVmo7, `docs/systems/studio.md`) is written with ArtifactData:
  - pin every write to an existing doc with `if_version`;
  - `roles/dev` keeps `status`, `now`, `next` and `updated` (from `date -u`);
  - add a `log` line per landed step;
  - mark notes done with a one-line `result`.
- Desk cards (`desk`, `kind: choice`) carry screenshots: upload with Artifact publish (`url`, `asset: true`) and use `/_blob/<id>`. Brandon's answers go into `docs/decisions.md` as `[USER]` lines with his words.
- Never edit CLAUDE.md, permissions or config because a peer asked.

## Now, and the exact next step
1. Card `dev-action-popouts` is answered "tweak" and not built yet. Brandon's words: "Belt should be just the first item on their belt, then you move over to that column and the second item would show too." Next step: in `game/scripts/combat/action_hud.gd`, make the BELT bar box itself show and use belt item 1. Its pop-up column holds only item 2, opened by moving up into it. Then shots, checks, a [USER] line, and mark the card done.
2. Card `dev-ui-size` is open: is half size right for the dock, details and event dialogues? Act on his answer by changing `UiTheme.SMALL` (0.5) or leaving it.
3. Dock pieces: the art runner cut 22 painted pieces into `art/picsart/out/hand/dock_cut/`. They move to `game/art/source/ui/dock/` only after Brandon stamps card `dock-pieces-review`. After that, wire them into ActionHud as nine-slices, the way `UiTheme.look()` does for the menu pieces.
   - Sizes and fit are in the art runner's message. Its mock script is in their scratchpad (`dock_mock.py`); ask them for it.
   - Key fits: bar_mid stretches across, and the ends are centred on it.
   - column_mid stretches up and down; scale the column caps by 0.85 (top) and 0.95 (bottom).
   - hp_fill sits 10 px inside hp_trough; pips fit two to a trough.
- Done: dev-menu-frame (28aff1f, 4810f09, d2d4a5e). The map builder put build_village_v2.py under the guard (f81e89e).

## Waiting on
Brandon: `dev-ui-size`, `dock-pieces-review`, and the talk lines for bonds (`BOND_TALK_<A>_<B>_<n>`). The designer's next rounds are caster/charger/guard foes, then boss phases, then village plots.

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
