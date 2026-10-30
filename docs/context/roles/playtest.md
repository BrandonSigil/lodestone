# Playtester: handoff (2026-10-30)

Studio role id `playtest`, name "Playtester". Page: https://claude.ai/artifact/BNSLpKC1ZLXCeKnmPvVmo7. Read the desk (`playtest` cards) and `notes` (`role: "playtest"`, `status: "new"`) at the start of a turn.

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

## Baseline (clean worktree, crypt level 1, ambusher on `pass_bandits`, 9395491)
- 35 of 36 pass; no script errors, no stalls. Fails: bow seed 8 (road fight lost).
- First try lost (of 12): pass_bandits 1 / 0 / 0; plaza 1 / 6 / 1; tower 1 / 4 / 4 (sword / daggers / bow).
- Lich tries per run: sword 2.3, daggers 2.7, bow 2.3. Lich at level 5 in the sim: sword 43%, daggers 57%, bow 28%, book 85%.

## Open
- Nothing filed by me is open. Last rule from the game designer: ambusher softens if `pass_bandits` loses over half its first tries (it does not).
- Clutch tools: WARD only helps if cast after the Lich's mark (wiped at your next phase otherwise); SHADOW SWAP repositions but does not revive; forcing tools in the sim lowers Lich wins. Not played by hand (no window control); CARRY and COMMAND wording untested. Log line has a garbled figure ("14 to 8 hurt, 6 left"): correct is 14 to 6.
- Snow pass: 12 stray 1-2 cell bits (low). Cemetery stair in village_v2 was checked by data only in one round.
