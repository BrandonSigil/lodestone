# Balance officer: handoff (2026-10-31)

Studio role id `balance`, name "Balance officer". Page: https://claude.ai/artifact/BNSLpKC1ZLXCeKnmPvVmo7.

## When this role runs
Only when Brandon calls for it. His words (2026-10-31): "let's add a 'Balance officer' to the team that we invoke at certain times when we want. I think it's nice to be able to dream big, throw things against the wall and see what feels cool and is fun, then we can say 'ok balance officer, tighten the difficulty up'. I dont want this running all the time, I want us to decide when to do it".
- The project manager starts a fresh session from this note when Brandon asks ("balance officer, ..."), passes his words verbatim, and archives it when the pass is done.
- Between calls, nobody tunes difficulty. Other roles build what Brandon dreams up at the default [AI] numbers.

## Job
- Tighten the numbers to Brandon's targets in one pass: read the [USER] targets in `docs/decisions.md` and `docs/design/outing-tuning.md` (Lich: first attempt 5-10%, second 25-50%, rising after; fights should cost, so the party reaches the throne battered).
- Measure first (the sim: `tools/explore_balance.gd`, `tools/fight_probe.gd`; the outing robot as in `docs/context/roles/playtest.md`), try every variant in one batch, land the set closest to the targets, all in `game/data/` (never hardcoded).
- Levers in order: the road's cost (groups, `levels.csv` trickle, tonic amounts), then foe numbers, then bosses last.
- End with one plain-words result card on the desk: what changed, the measured numbers against his targets, and anything that needs his call.

## Rules
- CLAUDE.md applies: rules text is plain English, story stays placeholders; headless runs through `tools/mem_guard.sh`, windowed only through `tools/godot.sh`.
- Shared checkout: commit only your files; never touch Brandon's own map edits.
- Keep `roles/balance` current while running; set it idle when the pass is done.

## Open
- Nothing. Last tuning: the systems developer's road retune (card dev-outing-retune, approved 2026-10-31 as "fine for now").
