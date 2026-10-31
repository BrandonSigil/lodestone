# Playtester: handoff (2026-10-30)

Studio role id `playtest`, name "Playtester". Page: https://claude.ai/artifact/5NsBvyRP81zBRgAFCANTP5. Read the desk (`playtest` cards) and `notes` (`role: "playtest"`, `status: "new"`) at the start of a turn.

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

## Baseline (clean worktree, scale C on, 48909e0, 2026-10-30)
- 36 of 36 pass; no script errors, no stalls; no pop_in errors. Fights now: pass_wolves, pass_bandits, den_wolves, den_lone, plaza, cave, tower, throne.
- Runs with a first-try loss (of 12), sword / daggers / bow: pass_wolves 1/0/0; pass_bandits 0/1/0; den_wolves 0/2/0; den_lone 0/2/4; plaza 0/0/1; tower 2/3/1; throne 11/12/10.
- Lich tries per run: sword 2.1, daggers 2.7, bow 3.1 (was 2.3 / 2.7 / 2.3). Sim at level 5 (60 fights): sword 42%, daggers 57%, bow 37% (ambushed 27 / 48 / 15). Every other group is 100% in the sim.
- Ordinary fights are all but unloseable; only the Lich bites. Bow is the hardest weapon on him.

## Outing measurement (dd916d0, check.sh 332 tests 0 failures; 2026-10-30)
- 108 runs, all pass, no script errors. Robot variants: "noheal" (never uses pack potions/food, 24 seeds per weapon) and "heal" (the stock robot, heals before each fight, 12 seeds). Instrument by printing HP and `Game.member_res` before and after each `_fight` in a scratch copy of `e2e_play_steps.gd`.
- Lich win rate, attempt 1: about 3% (noheal 2/72, heal 1/36), target 5-10%. Attempt 2 (after one fall): about 21% (noheal 15/70, heal 7/35), target 25-50%. Slightly too hard, both.
- Arrival at the throne (noheal, first try), HP / resources: sword 41% / 15%, daggers 29% / 55%, bow 31% / 6%. Target about 50% / 25%. Daggers keep their charges; sword and bow are spent.
- Ceiling (fresh level 5, sim 60 fights): throne win sword 38%, daggers 55%, bow 52%. Beatable.
- Per-road-fight cost is noisy across seeds (HP 0-40%, resources 2-46%); no reliable average. Mana/charges are what the road spends.

## Open
- Nothing filed by me is open. Last rule from the game designer: ambusher softens if `pass_bandits` loses over half its first tries (it does not).
- Clutch tools: WARD only helps if cast after the Lich's mark (wiped at your next phase otherwise); SHADOW SWAP repositions but does not revive; forcing tools in the sim lowers Lich wins. Not played by hand (no window control); CARRY and COMMAND wording untested. Log line has a garbled figure ("14 to 8 hurt, 6 left"): correct is 14 to 6.
- Snow pass: 12 stray 1-2 cell bits (low). Cemetery stair in village_v2 was checked by data only in one round.
