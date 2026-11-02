# Content lane: handoff (2026-11-02)

## Job and standing rules
- Plots (`game/data/plots/<region>/`), explore maps (never Brandon's uncommitted `snow_pass.json`, `tavern.json`, `village.json`), the event tables (`travel_events.csv`, `explore_events.csv`), game text in `placeholder.csv` (menus, tips, rules in clear English; never story, dialogue or names). Studio role id `builder` (cards) until a `content` chair exists. Three lanes: `docs/systems/studio.md`.
- Don't edit UI scripts or rules scripts; ask through the PM. Edit `placeholder.csv` only with `~/.lodestone/venv/bin/python tools/word_swap.py apply <swaps.json>` (a JSON list of `{key, new}`).
- Work in a temp worktree cut from `origin/main`; bring changes to main when `tools/check.sh` is green. Commit with `git commit -- <paths>`, pull with rebase first.
- Never show Brandon a box (see `builder.md`). Look check: a fresh Sonnet reviewer gets a 2-seed sheet, `docs/style-bible.md`, an approved plot as the reference. At most 5 rounds, then post with honest notes.
- Studio page for this account: https://claude.ai/artifact/BNSLpKC1ZLXCeKnmPvVmo7 (CLAUDE.md's 5Nsy... URL is the other account's and 404s here).

## Done 2026-11-02
- Plots finished: forest `rocky_pass` (sunken dogleg pass, two high wooded shoulders), forest `fork` (stepped knoll, stairs, small peak), snow `zigzag` (road along a frozen lake, then bends up to the shelf). Forest road fights now draw from 7 plots, snow from 4. Farmland roads use the forest set (`overworld_paths.csv` art_set column), so farmland already has plots; no plumbing needed.
- Still drafts: forest `hollow` (the clearing doesn't read, 25 sealed rock cells), forest `gorge` (thin hidden river), snow `snow_switchback` (stacked boxes, no feature; needs a pond or stream).
- Game text written: UI_TAKES_PACK, UI_HC_CARD, UI_HC_KNOW and its three sub-lines, UI_STRANGE (now DANGER; the shelved trail's HUD, distance over goal).
- **Unused keys** (no code or data reads them): UI_TURN_VIEW (the sandbox hardcodes "TURN (Q)") and UI_LS_RANK. Left as they are; the PM may drop them from the CSV and Word Swap.
- Tools added: `game/tools/plot_qa.gd` (every seed through MapQA plus rock cells per seed) and `game/tools/plot_shot.gd` (a plot as a battle map). See `docs/systems/plots.md` "Plot QA tools".

## Lessons
- MapQA passes every draft; the look decides. The best signal for a bad plot is `rock cells per seed` above the plot's own rocks: the extras are cut-off ground sealed into orange pillar heaps. Diagonal spurs were the cause on rocky_pass and zigzag; use orthogonal spurs or stair-linked ones.
- A footprint wider than about 4 cells either side of the road fills the box (rocky_pass v2 failed that way). Keep corridors narrow, with the bulk in a few lobes.
- Fewer `woods` entries: the renderer adds noise trees on top, and heavy trees hide the road.
- Regenerate with `python3 tools/plots/seed_plots.py --force --only=<ids>` (the files match the script byte for byte; Brandon hasn't edited them yet).

## Open
- Desk cards `content-plots-forest-review` and `content-plots-snow-review` (role builder, choice yes / tweak). Act on his answer.
- Queue item 2 (new Word Swap `asks`) waits for the PM to pass one.
- Possible next: a pond for snow_switchback, a different idea for hollow and gorge, events and foes for forest_roads and farmland if asked.
