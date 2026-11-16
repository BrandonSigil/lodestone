# Balance officer: handoff (2026-10-31)

Studio role id `balance`, name "Balance officer". Page: https://claude.ai/artifact/5NsBvyRP81zBRgAFCANTP5.

## When this role runs
Only when Brandon calls for it. His words (2026-10-31): "let's add a 'Balance officer' to the team that we invoke at certain times when we want. I think it's nice to be able to dream big, throw things against the wall and see what feels cool and is fun, then we can say 'ok balance officer, tighten the difficulty up'. I dont want this running all the time, I want us to decide when to do it".
- The project manager starts a fresh session from this note when Brandon asks ("balance officer, ..."), passes his words verbatim, and archives it when the pass is done.
- Between calls, nobody tunes difficulty. Other roles build what Brandon dreams up at the default [AI] numbers.

## Job
- Tighten the numbers to Brandon's targets in one pass: read the [USER] targets in `docs/decisions.md` and `docs/design/outing-tuning.md` (Lich: first attempt 5-10%, second 25-50%, rising after; fights should cost, so the party reaches the throne battered).
- Measure first (the sims: `tools/economy_sim.gd`, `tools/outing_sim.gd`, `tools/explore_balance.gd`, `tools/fight_probe.gd`; the outing robot as in `docs/context/roles/playtest.md`), try every variant in one batch, land the set closest to the targets, all in `game/data/` (never hardcoded).
- Levers in order: the road's cost (groups, `levels.csv` trickle, tonic amounts), then foe numbers, then bosses last.
- End with one plain-words result card on the desk: what changed, the measured numbers against his targets, and anything that needs his call.

## Rules
- CLAUDE.md applies: rules text is plain English, story stays placeholders; headless runs through `tools/mem_guard.sh`, windowed only through `tools/godot.sh`.
- Shared checkout: commit only your files; never touch Brandon's own map edits.
- Keep `roles/balance` current while running; set it idle when the pass is done.

## Open
- 2026-11-16: the balance master plan (`docs/design/balance-master-plan.md`, backlog P33) is written and waits on Brandon's calls at its end. No data changed. When he has picked, land its data steps in order (section 3.5), measuring each with `tools/economy_sim.gd` and then the robot.
- 2026-11-16, Brandon's party call (`[USER]` in `docs/decisions.md`): the three first directions (north pass and den, west forest roads, east farmland) are balanced for 2 or 3 members, the Lich for a full party of four, and the world does not scale to the party. Measured: four beat today's Lich 100%; with 200 XP a level a 158-HP Lich gives four 5 / 51 / 100% and two 0%; the forest ogre is 0% for two with a sword or daggers and needs softening. Recruits join at level 1 and earn the hero's XP from then on (`Game.award_xp`), so sims must set when each joined (`ally_at=`).
- 2026-11-16, landed on his "Yes to all this": `lich.tres` HP 158 (was 42) and `ogre.tres` HP 10, damage 4, armor 0 (15, 5, 1 as the forest's elite). On today's other numbers four win the first try at the Lich 62%, two win 0% until the third; the 5 / 51 / 100% curve needs 200 XP a level and fight food at 30% (plan decisions 4 and 2, not picked yet). The Lich's old 6 to 8% first-try numbers in `docs/design/outing-tuning.md` were for two against 42 HP. The outing robot's Lich targets need redoing for a party of four.
- Tools: `tools/economy_sim.gd -- acts|road|chain|levels` (food, camp actions, morale, and the pass trip fight by fight with eating, XP and levels kept; `chain route=north|forest|farm` for the first maps, `ally=bushberry,fire_mage ally_at=210,270 xp0=270` for a bigger party). `tools/outing_sim.gd` only plays the shipped road when run with `foe_hp=70`; without it the road foes are at full HP.
- Last tuning: the systems developer's road retune (card dev-outing-retune, approved 2026-10-31 as "fine for now").
