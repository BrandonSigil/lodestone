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
| Big bad known now | a boss card for every new `learned_<class>` flag: HP, armor, move and every move's plain rules text. On a fall it leads the page |
| Know now | new lasting finds (`got_`), bosses and elites down for good (`beaten_`), foes got past (`passed_`) |
| Village fixed | restore steps that just finished |
| Next goal | the first tracked step not yet paid, else the next step of the first open building, with an "N OF M" bar per material |

All words are `UI_HC_*` keys in `game/text/placeholder.csv` (caveman placeholders for Brandon).

## Files
- `game/scripts/core/homecoming_rules.gd`: pure rules (snapshot, summary, next goal).
- `game/scripts/ui/homecoming_ui.gd`: the page.
- `game/tests/test_homecoming.gd`: tests.
- `game/tools/homecoming_shot.gd`: screenshot over the square with a made-up trip,
  `xvfb-run tools/godot.sh --path game -s res://tools/homecoming_shot.gd -- out.png fell|home`.

## Open [AI] calls
- The page shows after a walk home only when something changed; a fall or GO HOME always shows it.
- "New knowledge" counts the lasting flags above until Pitch C's Lodestone knowledge list is built.
