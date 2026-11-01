# Fishing: Look, Strike, Reel

Brandon's call ([USER] 2026-11-01, card design-fishing-research): one cast in three beats, with Reel as a horizontal bar. Design history in `docs/design/fishing.md`.

## How it plays
- **Look**: a flat top-down pool with drifting fish shadows. Shadow size hints at the grade. Click a shadow (or pick with left/right and press Space / A) to cast to it. LEAVE or Esc / B backs out and costs nothing.
- **Strike**: the bobber nibbles 0 to 2 times, then truly dips ("!" and rings). Strike on the dip (click, Space or A). Striking on a nibble or before the dip scares the fish off; missing the dip window loses it.
- **Reel**: the fish darts left and right along a bar. Steer the marker with the mouse (or a finger), arrows / A D, or the left stick and d-pad. On the fish the catch meter fills, off it the meter drains. Full lands the fish, empty loses it. The rod leans toward the fish and bends and twitches when you're off it, and the hooked shadow thrashes in the pool where the fish is on the bar.
- A caught fish goes in the pack (its `reward` column) and the first of each kind says NEW FISH. Raw fish are rations ([USER] 2026-11-01, dev-fish-review: "Uncooked fish should count as rations, or you need to go
  home and put them in actual recipes"): a small fish (minnow, perch), a good fish (trout, pike) and the prize fish (king)
  feed 1, 2 or 3 portions at the night camp (`fish_small`, `fish_good`, `fish_prize` in `data/items.csv`, `food` column)
  and heal nobody. They are 1, 2 and 3 cells long and share the fish icon. At home they go to the village pile with the
  materials (the `bank` column), and the kitchen cooks them: FIRE FISH (two small fish, kitchen 1) and BIG FISH PLATE
  (a good fish and the prize fish, kitchen 2), cooked meals that heal at the night camp's team meal (`data/recipes.csv`,
  [AI] numbers).
- Any explore thing whose event has the `fish` effect (the village v2 dock), with a rod in the pack. The thing's optional `pool` picks the fish (default `lake`). The spot rests for the trip once a line is cast.
- The overworld's FISH button (pool `road`). The road clock stops while it's up; leaving before the cast doesn't start the cooldown.
- Launch menu > PLAY > Fishing: practice casts back to back. Nothing goes in the pack.

## Code and data
- `game/scripts/fishing/fishing_rules.gd` (`FishingRules`): pure rules (pool, shadows, strike plan, reel step, reward). Tests: `game/tests/test_fishing.gd`.
- `game/scripts/fishing/fishing_game.gd` (`FishingGame`): the overlay. `FishingGame.open(parent, pool, mods)` and connect `finished(result)`; result `outcome` is caught, lost, early, late or left.
- `game/data/fish.csv`: one row per fish: grade, shadow size, speed, dart pauses (`dart_min`, `dart_max`), how far it darts (`reach`), meter `fill` and `drain` a second, `strike` (dip window multiplier), `weight`, `spots`, `reward`.
- `game/data/levels.csv` `fish_*` rows: shadows, wait for the bite, nibbles, dip window, marker width and speed, meter start, party skill slow.
- `Game.land_fish(row)`: reward into the pack plus the `caught_fish_<id>` flag.
- Screenshots: `game/tools/fishing_shot.gd -- <png> look|bite|reel|caught` (cloud: xvfb-run with `--rendering-driver opengl3`).

## Graybox
The pool, shadows, lily pads, reeds, bobber, rod, angler and bar are flat shapes drawn in code until Brandon's art. All words are placeholders in `game/text/placeholder.csv` (FISH_*, GRADE_*, UI_FISH_*).
