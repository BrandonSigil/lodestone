# Game designer: handoff (2026-10-30)

## Job
Grill Brandon with choice cards on his Studio desk (https://claude.ai/artifact/5NsBvyRP81zBRgAFCANTP5, `docs/systems/studio.md`). Record answers. Hand approved work to the systems developer (notes, role `dev`) or the map builder (role `builder`). Keep the `combat` roadmap track current. I change no game code; tuning goes to the developer.

## Standing rules
- No story, dialogue, names, lore or flavor text. Nameable content stays blank, and player text is caveman placeholders in `game/text/placeholder.csv`.
- Brandon's answers go in `docs/decisions.md` as `[USER]` lines with his words verbatim, the date and the card id. My follow-on numbers are `[AI]` lines ending "(game designer)". A `[USER]` line beats an `[AI]` line. Read decisions.md before any design change.
- Cards (kind `choice`): 2-4 real options, each naming a game example and its trade-off. Use `multi` where picks combine ("the first you pick is built first"), and add a picture where it helps. If he picks "Neither" with a why, record his why verbatim and re-pitch.
- Pictures: Python SVG, then `magick -density 96 x.svg x.png && magick x.png -quality 88 x.webp`. Magick drops thin strokes and outline rects, so use filled cells only. Upload with Artifact publish (url + asset:true), then `/_blob/<id>`.
- Studio DB (ArtifactData): pin every write to an existing doc with `if_version`; a batch fails whole if one doc is unpinned. Notes use fields `role`, `status` (new/seen), `from`, `at`, `title`, `text`. Mark a card done with a one-line `result`.
- Role status `roles/design`: update `status`, `now`, `next` and `updated` when starting and finishing an item. Take `updated` from `date -u +%Y-%m-%dT%H:%M:%SZ`, never a guess.
- Shared checkout ~/lodestone, main only. `git fetch` + `git merge --ff-only origin/main`, never stash, reset or pull --rebase. Commit only my files: `git add <file>` then check `git show --stat HEAD`. A failed python edit must not be followed by a commit, because that once swept up another session's unstaged lines (283c84d). Commits end with "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>".
- Edit decisions.md with a Python anchor-insert after a unique existing line (assert count == 1).

## Measuring rules I set (all [AI])
- Builds may be uneven against a boss ([USER] design-boss-spread), but each build must win about 15% or more at the boss's level with the party first, and no fight may stall.
- Clutch tools must keep at least a third of a build's wins "close" (the hero went down or ended under a quarter of max HP). They are saves, not safety nets.
- Map fights: a non-boss fight losing its first try in more than half the robot runs is a wall.
- Use 120 fights per row before trusting a gap; at 40 fights, 20% vs 13% was noise.

## State now
- Nothing open: no design cards on the desk and no new notes. Role status is idle.
- Lich (crypt throne, `data/classes/lich.tres`): undead, 38 HP, big move `lich_doom` (marked a phase ahead), ice pillars `raise_ice` (1 every 2nd phase, cold 1), threat-weighted AI `threat_ai` 1. At level 5, party first: sword ~43-48%, daggers ~54-58%, bow ~39% (17% ambushed), book ~83%.
- Map levels (foes by depth): snow pass 1, wolf den 2, crypt 1; bosses skip the roll. The ambusher hides with the snow pass bandits.
- Clutch tools landed: CARRY (the dog, every party), COMMAND (sword), SHADOW SWAP (daggers, uses the move), stand and watch (bow, free shot if the archer doesn't move), WARD (book). Minion summon `raise_dead` is built but on no boss.
- Bonds are built; the talk slots `BOND_TALK_<A>_<B>_<n>` wait for Brandon's lines.

## Next step
Nothing is in flight. When the PM or Brandon says go, pitch the next round as cards, in the order Brandon set:
1. Caster/support foe, then charger, then guard ([USER] design-foe-roles).
2. Boss phases with the second boss (minions suit a bigger party), then parts, then an objective ([USER] design-boss-shape).
3. Village plots, a garden and a pen ([USER] design-village-grows).
Also still open in combat: actions per turn, counter fairness. Content for Brandon to name: settlers, buildings, blessings and setbacks.

## Pointers into docs/decisions.md (search the card id)
design-boss-spread, design-world-gate, design-boss-cadence, design-boss-shape, design-foe-scale, design-foe-roles, design-foe-weakness, design-boss-warning, design-boss-retry, design-village-grows, design-village-life, design-lich-tag, design-lich-minions (his ice pillar and clutch quote), design-clutch-tools, design-clutch-tools-2, design-clutch-jobs. The later [AI] lines of 2026-10-30 carry the measured tables.

## Key files
- `docs/design/core-loop.md`: design summary per theme; the "Bosses, foes and the village" section is current.
- `game/data/combat.csv`, `abilities.csv`, `tags.csv`, `bonds.csv`, `classes/*.tres`: the knobs.
- Balance: `godot --headless --path game -s res://tools/explore_balance.gd -- fights level weapon`; robot `-s res://tools/e2e_play.gd -- seed`. The developer and the playtester run these. Ask them for tables instead of running long sims yourself.
- Scratch Godot scripts need a SceneTree wrapper plus a RefCounted runner loaded at run time, because autoloads like Db can't be named at compile time.
