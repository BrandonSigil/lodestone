# Game designer: handoff (2026-11-01)

## Job
Grill Brandon with choice cards on his Studio desk (`docs/systems/studio.md`). Record answers. Hand approved work to the systems developer (notes, role `dev`) or the map builder (role `builder`). Keep the `combat` roadmap track current. I change no game code; tuning goes to the developer.

## Standing rules
- No story, dialogue, names, lore or flavor text. Nameable content stays blank, and player text is caveman placeholders in `game/text/placeholder.csv`.
- Brandon's answers go in `docs/decisions.md` as `[USER]` lines with his words verbatim, the date and the card id. My follow-on numbers are `[AI]` lines ending "(game designer)". A `[USER]` line beats an `[AI]` line. Read decisions.md before any design change.
- Cards (kind `choice`): 2-4 real options, each naming a game example and its trade-off. Use `multi` where picks combine ("the first you pick is built first"), and add a picture where it helps. If he picks "Neither" with a why, record his why verbatim and re-pitch.
- Pictures: Python SVG, then `magick -density 96 x.svg x.png && magick x.png -quality 88 x.webp`. Magick drops thin strokes and outline rects, so use filled cells only. Upload with Artifact publish (url + asset:true), then `/_blob/<id>`.
- Studio DB (ArtifactData): pin every write to an existing doc with `if_version`; a batch fails whole if one doc is unpinned. Notes use fields `role`, `status` (new/seen), `from`, `at`, `title`, `text`. Mark a card done with a one-line `result`.
- Role status `roles/design`: update `status`, `now`, `next` and `updated` when starting and finishing an item. Take `updated` from `date -u +%Y-%m-%dT%H:%M:%SZ`, never a guess.
- Shared checkout ~/lodestone, main only. `git pull --rebase --autostash` (other sessions leave uncommitted edits), never reset or switch branches. Commit only my files: `git add <file>` then check `git show --stat HEAD`. A failed python edit must not be followed by a commit, because that once swept up another session's unstaged lines (283c84d). Commits end with "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>".
- Edit decisions.md with a Python anchor-insert after a unique existing line (assert count == 1).

## Measuring rules I set (all [AI])
- Builds may be uneven against a boss ([USER] design-boss-spread), but each build must win about 15% or more at the boss's level with the party first, and no fight may stall.
- Clutch tools must keep at least a third of a build's wins "close" (the hero went down or ended under a quarter of max HP). They are saves, not safety nets.
- Map fights: a non-boss fight losing its first try in more than half the robot runs is a wall.
- Use 120 fights per row before trusting a gap; at 40 fights, 20% vs 13% was noise.

## Where it stands (2026-11-01)
- **Done today:** `docs/design/healing-model.md` (Pick A, camp meal picker), `docs/design/bushberry-tavern.md` (recruit flow, kit, tavern menu) and `docs/design/lich-prince.md` (`lich_wins` meta, the yield at win 3, PASS or FIGHT afterwards). Brandon's answers are `[USER]` lines at the tail of `docs/decisions.md`.
- **In flight:** nothing. Role status is idle. The developer's next job is `dev-lich-prince` (the progress change and the Prince recruit).
- **Standing design change:** every fight returns each run unless a story beat says otherwise (the Lich is the first beat). Check new designs against it.
- **When Brandon says go**, pitch the next round as cards in his order: caster/support foe, charger, guard ([USER] design-foe-roles); boss phases ([USER] design-boss-shape); village plots ([USER] design-village-grows). Also open: actions per turn, counter fairness, content for Brandon to name (settlers, buildings, blessings, setbacks).
- Bonds are built; `BOND_TALK_<A>_<B>_<n>` slots wait for Brandon's lines.
- Lich numbers (38 HP, `lich_doom`, `raise_ice`, `threat_ai`) and the clutch tools are as of 2026-10-30; the playtester's 2026-11-01 re-measure (card `playtest-outing-retune-result`) is the current table.

## Pointers into docs/decisions.md (search the card id)
design-boss-spread, design-world-gate, design-boss-shape, design-foe-roles, design-village-grows, design-lich-minions, design-clutch-tools, design-healing, design-bb-recruit, design-bb-kit, design-lich-prince. The 2026-10-30 [AI] lines carry the measured tables.

## Key files
- `docs/design/core-loop.md`: design summary per theme; the "Bosses, foes and the village" section is current.
- `game/data/combat.csv`, `abilities.csv`, `tags.csv`, `bonds.csv`, `classes/*.tres`: the knobs.
- Balance: `godot --headless --path game -s res://tools/explore_balance.gd -- fights level weapon`; robot `-s res://tools/e2e_play.gd -- seed`. The developer and the playtester run these. Ask them for tables instead of running long sims yourself.
- Scratch Godot scripts need a SceneTree wrapper plus a RefCounted runner loaded at run time, because autoloads like Db can't be named at compile time.

## Studio rules
- The Studio page is https://claude.ai/artifact/BNSLpKC1ZLXCeKnmPvVmo7 (this account). Desk card text is a short lead line, a blank line, then "- " bullets with **bold** labels, never one long paragraph. Use real newlines.
- One review card per feature or job, not one per commit.
- Run long checks in the foreground or wait for them; never end a turn with work unpushed. Commit, rebase onto origin/main, push, and confirm with `git log origin/main`.
- Model: dev on Opus at medium effort; design, builder, playtest and art on Sonnet.
