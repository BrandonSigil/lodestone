# The homecoming page

[USER] 2026-11-01 Pitch J (master-j-homecoming): after every return, a fall or GO HOME, one page shows what the trip
gave and closes on the next goal. Built 2026-11-01.

## How it works
- **The ledger.** `Game.meta.ledger` is a snapshot of levels, bonds, flags, morale and journey days (`HomecomingRules.snapshot`).
  The village gate (`Game.start_trip`) opens one; `ensure_run` opens one if none exists (a new game, an old save).
- **Closing it.** `Game.home_again(wake)` closes the ledger into `Game.homecoming` (`HomecomingRules.summary`):
  - a fall or GO HOME (`wake_in_town`) always shows the page, and the wake-up line becomes its headline;
  - walking home through the gate after a trip shows it only when the trip brought something;
  - walking from the cottage into the square is not a return. A fresh ledger opens after every close.
- **Showing it.** The explore scene opens `HomecomingUi` over the square in place of the old wake-up dialogue.
  OK (or Enter/Esc) closes it and the square is playable.

## What it shows
| Section | Source |
|---|---|
| Stuff brought home | the materials `home_again` banked |
| Grow strong | XP and levels from `meta.levels` against the ledger, with an XP bar to the next level |
| Friends closer | bond points from `meta.bonds`, gold when a bond level is reached |
| Heart | the journey days gone (`meta.days`), then each character's morale change from `meta.morale` and their band now (`docs/systems/morale.md`) |
| What the wall wants | after a fall in a fight that asks for a full party, with fewer than `party_max` fighting: one gold line under the wake-up line (see below) |
| Big bad known now | a boss card for every new `learned_<class>` flag: HP, armor, move and every move's plain rules text. On a fall it leads the page |
| Know now | new lasting finds (`got_`), bosses and elites down for good (`beaten_`), foes got past (`passed_`) |
| Village fixed | restore steps that just finished |
| Next goal | the first tracked step not yet paid, else the next step of the first open building, with an "N OF M" bar per material |

All words are `UI_HC_*` keys in `game/text/placeholder.csv`: game text, in plain English.

## The wall says what it wants (backlog P34, built 2026-11-16)
[USER] 2026-11-16: the world does not scale to the party, the Lich King is a fight for a full party of four, and
"have the homecoming page say what the wall wants". So a party of two or three that falls to him is told at home.
- **The data.** A foe group in a map file can carry `"wants": "full_party"` (one of `ExploreMap.STORY_KEYS`). Only the
  crypt's `throne` group, the Lich, has it. The party's limit is `party_max` in `game/data/levels.csv` (4).
- **The rule.** `HomecomingRules.fall(groups, party)` notes what the lost fight asked and how many fought;
  `HomecomingRules.wall_hint(fell, fall, cfg)` gives the line only when the return was a fall, a group in the fight
  wanted a full party, and fewer than `party_max` fought. A full party, a win, GO HOME, a fall in any other fight,
  or a fall to a trap gives nothing.
- **The path.** The explore scene builds the fall when a fight is lost and hands it to `Game.recall(fall)`, which
  passes it to `wake_in_town`; the answer is `Game.homecoming.wall` (`{"key", "party", "need"}` or `{}`).
- **The page.** One gold line under the wake-up line, every time it applies (not only the first fall).
- **The words.** `UI_HC_WANTS_FULL_PARTY` ("That fight is too big for a party of %d. Come back with %d.": who fought,
  then `party_max`). Claude's draft, flagged in `game/text/claude_written.txt` until Brandon writes or keeps it. It
  names nobody, so it gives away no recruit the player has not met.
- **Who counts.** The members who fought. Anyone Spent sits a fight out, so four on the trip with one Spent count
  as three.

## Files
- `game/scripts/core/homecoming_rules.gd`: pure rules (snapshot, summary, next goal).
- `game/scripts/ui/homecoming_ui.gd`: the page.
- `game/tests/test_homecoming.gd`: tests.
- `game/tools/homecoming_shot.gd`: screenshot over the square with a made-up trip,
  `xvfb-run tools/godot.sh --path game -s res://tools/homecoming_shot.gd -- out.png fell|home`.

## Open [AI] calls
- The wall's line counts who fought, not who came, and shows on every such fall. Its words are a draft.
- The page shows after a walk home only when something changed; a fall or GO HOME always shows it.
- "New knowledge" counts the lasting flags above until Pitch C's Lodestone knowledge list is built.
