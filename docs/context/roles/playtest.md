# Playtester: handoff (2026-11-01)

Studio role id `playtest`, name "Playtester". Read the desk (`playtest` cards) and `notes` (`role: "playtest"`, `status: "new"`) at the start of a turn.

## Job and rules
- **Milestones only (Brandon, 2026-10-30):** "limit the playtester to some milestones. I dont mind quick screengrabs for things, but let's do less full-sweeps and difficulty checks for now". Full 36-run sweeps and balance/difficulty checks only at a milestone the PM or Brandon names. Between milestones: quick screenshots or a single seed when asked, nothing more.
- Play the loop with the headless test robot, file bugs as `notes` for the owner (`dev` or `builder`) with a repro, put feel or balance matters on the desk, add `log` lines, keep `roles/playtest` current (`updated` from `date -u +%Y-%m-%dT%H:%M:%SZ`).
- Headless runs only; any windowed run goes through `tools/godot.sh`, never the bare binary. Never edit game files. No story or copy. Never touch the Picsart key.
- Every Godot run goes through `tools/mem_guard.sh` (kills it over 6 GB; `GODOT_MEM_CAP_MB`). `tools/godot.sh` and `tools/check.sh` already do. Bare headless runs in my batches skipped it: wrap them.

## Run the robot (36 runs = sword, daggers, bow x seeds 1-12)
- One run: `cd game && /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s res://tools/e2e_play.gd -- <seed>` (sword; prints `E2E PASS` or `FAIL`).
- Other weapons: copy `game/tools/e2e_play_steps.gd` to `_pt_steps_<w>.gd`, `sed` `OPT_TAKE_SWORD` to `OPT_TAKE_DAGGERS` or `OPT_TAKE_BOW` and the `weapon_id() == "sword"` check to match; copy `e2e_play.gd` to `_pt_run_<w>.gd` pointing at it. Delete them (and their `.uid`) afterwards.
- Run the 12 seeds of a weapon in parallel (`timeout 420`, log each to its own file, append `exit $?`); the whole 36 takes about 10 minutes.
- Per-encounter losses: `grep "lost the fight with"` per log; first try = the first `with <group>` line (L or W). Lich tries per run = (throne losses + 12) / 12.
- Group balance without the robot: `godot --headless --path game -s res://tools/explore_balance.gd -- <fights> <level> <weapon>`; one group on the real walk: `tools/fight_probe.gd -- <map> <group> [tries]`.
- Map access (flood fill): my scratch drivers are gone. Rebuild with `CombatGrid.from_dict`, `ExploreRules.reach(grid, seeds, jump)`, hero Jump 1, doors, rubble and hidden things as open; `can_step` adds `STAIRS_CLIMB` 2. Screenshots: `tools/godot.sh --path game -s res://tools/explore_shot.gd -- out.png <step> [map]` (`start`, `overview`, `near:x,y`, `use:<id>`).

## Gotchas from today
- Run from a clean worktree (`git worktree add --detach <dir> HEAD`, then `godot --headless --path <dir>/game --import`), not ~/lodestone. Other sessions have uncommitted edits there; one run parsed a half-edited `action_slot.gd` and gave 240k script errors and a false fail. Remove the worktree afterwards.
- A "Decisions:" commit is not the change. Check the data file (e.g. `game/data/explore/crypt.json` `"level"`) is changed in HEAD before running.
- `sed -i` on macOS needs `-i ''`; use python or write to a new file.
- The robot fights road fights once; one lost road fight beyond the crypt fails a run (bow seed 8). Not a bug.
- `Cannot convert argument 1 from Object to Object` (`pop_in`) appears in most logs; no effect on results, unknown if new.
- Studio writes to an existing doc need `if_version`.

## Re-measure after the retune (d658ae5, check.sh 395 tests 0 failures; 2026-11-01)
- explore_foe_hp_pct 70, hex world map, daily camp meals. 108 runs (24 seeds noheal, 12 heal per weapon), all pass, no script errors.
- Lich attempt 1: noheal 3/72 (4%), heal 1/36 (3%); attempt 2: noheal 15/69 (22%), heal 8/35 (23%). Targets 5-10% and 25-50%.
- Arrival HP at the throne (noheal): sword 60%, daggers 53%, bow 59%; resources 12% / 58% / 55%. The stock robot heals up before the fight (arrives 97-100%).
- Food is never short (34 left at the throne in noheal); the empty-larder ending, Bushberry's rescue and the tavern are not exercised by the robot. Only 2 non-Lich falls in 108 runs.
- Recommendation sent: explore_foe_hp_pct 60 (first try under 5%). Sample is small, so 1-2 more wins would move it.

## Where it stands (2026-11-01)
- The Lich re-measure at d658ae5 is done (card `playtest-outing-retune-result`, 108 runs): Lich attempt 1 about 4%, attempt 2 about 22%. It recommends `explore_foe_hp_pct` 60 (Brandon's call; the sample is small).
- Earlier baseline (70%, dd916d0, 2026-10-30): attempt 1 about 3%, attempt 2 about 21%. Ceiling (fresh level 5, sim 60 fights): sword 38%, daggers 55%, bow 52%.
- Nothing filed by me is open. Milestones only, so nothing is queued. The likely next trigger is the progress change (every fight returns each run, the Lich Prince after win 3): re-measure the Lich loop only when the PM or Brandon names it.
- Unverified: the empty-larder ending, Bushberry's rescue, the tavern, Amber's recruit and the camp meal picker are not exercised by the robot. Clutch tools (WARD after the Lich's mark, SHADOW SWAP, CARRY and COMMAND wording) were never played by hand.
- Low: snow pass has 12 stray 1-2 cell bits; the village_v2 cemetery stair was checked by data only.

## Studio rules
- The Studio page is https://claude.ai/artifact/BNSLpKC1ZLXCeKnmPvVmo7 (this account). Desk card text is a short lead line, a blank line, then "- " bullets with **bold** labels, never one long paragraph. Use real newlines.
- One review card per feature or job, not one per commit.
- Run long checks in the foreground or wait for them; never end a turn with work unpushed. Commit, rebase onto origin/main, push, and confirm with `git log origin/main`.
- Model: dev on Opus at medium effort; design, builder, playtest and art on Sonnet.
