# Systems developer: handoff (2026-11-01)

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

## Where it stands (2026-11-01, evening)
- **Queue done.** Nothing assigned. Wait for Brandon's answers or the next PM note.
- **Landed today (late):**
  - Playtest X1-X4 (89e2681): Doggo's sprite in his house, no raw effect text (`TrailRules.gains_text`), pickups open the loot window (`box` column in `explore_events.csv`), the gate opens the playtest party picker.
  - The painted world map (8132155): outlines in `data/world_tiles.csv`, parchment fog (`seen_tile_<id>` flags), highlights.
  - Brandon's map tweaks (9951f30): links are data per edge (`TravelRules.linked`; the pass has no side links), subtler lines and current tile.
  - Every fight comes back each run, and the Lich Prince (6f94172):
    - progress: run-scoped trip flags (`Game.set_trip_flag`, `flags_now`); story keys on groups (`relents`, `wins`, `yield_at`, `yields`, `relent_event`);
    - the Lich: yields on the third win (`CombatUnit.yields`), then PASS / FIGHT;
    - the Prince: joins from the square; ICE ARMOR, COLD SNAP, Hoarfrost and Cold Blooded wired.
  - A seed for the flaky kit batch 2 burn test (086cb2a).
  - Fishing FI1-FI4 was built by the junior developer (5c0f592), not here.
- **Earlier today:** daily eating 0b2acb3; hex world map cca863e; healing model A bb87663; Bushberry 2f2acdc, 0ecc810, 23ba459; renew dropped 67a9ace; raw fish as rations e67db09; restore box crash fix bf616c1.
- **Open on the desk:**
  - review cards `dev-x1-x4-review`, `dev-painted-map-tweak-review`, `dev-lich-prince-review`;
  - the playtester's `explore_foe_hp_pct` 60 (now 70): Brandon's call, don't change it unasked.
- **Unverified:**
  - Amber's hidden-bonfire recruit hasn't been played end to end.
  - The robot doesn't exercise the empty-larder ending, the rescue, the tavern, or the Prince in a fight.
  - The crypt `relent` screenshot step frames the hero off the map; the box is right.
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
