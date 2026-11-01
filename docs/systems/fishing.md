# Fishing: Look, Strike, Reel

Brandon's call ([USER] 2026-11-01, card design-fishing-research): one cast in three beats, with Reel as a horizontal bar. Design history in `docs/design/fishing.md`.

## How it plays
- **Look**: a flat top-down pool with the pond's drifting fish shadows (shadow size hints at the grade). You aim the cast ([USER] 2026-11-01 FI1): the mouse, the arrows or the stick moves a cross over the water, inside a faint ring that shows how close a fish must be to notice (`fish_notice`). Click, Space or A casts there; dry land takes no cast. LEAVE or Esc / B backs out and costs nothing.
- **Wait**: the bobber lands. Each shadow inside the ring gets a chance to notice it, nearest first (`FishingRules.noticed`: sure beside the bobber, `fish_notice_min` at the edge) and the chance is rolled again every half second while the bobber sits. A fish that notices turns and swims over (`fish_approach`). If none does within `fish_idle` seconds, or you click, the line comes back and you aim again: nothing is lost.
- **Strike**: the bobber nibbles 0 to 2 times, then truly dips ("!" and rings). Strike on the dip (click, Space or A). Striking on a nibble or before the dip scares the fish off; missing the dip window loses it.
- **Reel** ([USER] 2026-11-01 FI3, FI4): the fish and the marker start in the middle, the fish hovers `fish_first_wait` seconds, then eases in: for `fish_ease` seconds it is slower, darts shorter and the meter drains less (`FishingRules.ramp`). Holding left or right (arrows, A D, the left stick, or the mouse or a finger left or right of the bar's middle) pulls the marker that way up to `fish_marker_speed`; the moment you let go it springs back to the centre (`fish_spring`). On the fish the catch meter fills, off it the meter drains. Full lands the fish, empty loses it. The rod leans toward the fish and bends and twitches when you're off it, and the hooked shadow thrashes in the pool where the fish is on the bar.
- **The pond runs out** ([USER] 2026-11-01 FI2): a spot is a pond of `fish_pond_size` (3) fish, drawn by weight the first time it is fished and kept in the save (`Game.pond`, `meta.ponds`; key `<map>/<thing id>` on an explore map, `road/<place>` on the road). A catch, a fish scared off (strike too soon), a missed dip and a fish lost on the reel are each gone from the pond for good (`FishingRules.GONE`); leaving, or a bobber nothing noticed, costs nothing. An empty pond shows no shadows and says so. The dock no longer rests for the trip once cast (it did, [AI] 2026-10-30): the pond is the limit now. The road's FISH button keeps its cooldown.
- A caught fish goes in the pack (its `reward` column) and the first of each kind says NEW FISH. Raw fish are rations ([USER] 2026-11-01, dev-fish-review: "Uncooked fish should count as rations, or you need to go
  home and put them in actual recipes"): a small fish (minnow, perch), a good fish (trout, pike) and the prize fish (king)
  feed 1, 2 or 3 portions at the night camp (`fish_small`, `fish_good`, `fish_prize` in `data/items.csv`, `food` column)
  and heal nobody. They are 1, 2 and 3 cells long and share the fish icon. At home they go to the village pile with the
  materials (the `bank` column), and the kitchen cooks them: FIRE FISH (two small fish, kitchen 1) and BIG FISH PLATE
  (a good fish and the prize fish, kitchen 2), cooked meals that heal at the night camp's team meal (`data/recipes.csv`,
  [AI] numbers).
- Any explore thing whose event has the `fish` effect (the village v2 dock), with a rod in the pack. The thing's optional `pool` picks the fish (default `lake`). The spot rests for the trip once a line is cast.
- The overworld's FISH button (pool `road`). The road clock stops while it's up; leaving before the cast doesn't start the cooldown.
- Launch menu > PLAY > Fishing: practice casts back to back over a three-fish pond that fills again when it runs out. Nothing goes in the pack and nothing is saved.

## Code and data
- `game/scripts/fishing/fishing_rules.gd` (`FishingRules`): pure rules (pool, pond, shadows, notice, strike plan, reel step, reward). Tests: `game/tests/test_fishing.gd` (pond, notice, centred start and ease-in, hold and spring-back).
- `game/scripts/fishing/fishing_game.gd` (`FishingGame`): the overlay. `FishingGame.open(parent, pool, mods, seed, pond)` (`pond` is `Game.pond(key, pool)`, or null for a fresh one that isn't kept) and connect `finished(result)`; result `outcome` is caught, lost, early, late or left.
- `game/data/fish.csv`: one row per fish: grade, shadow size, speed, dart pauses (`dart_min`, `dart_max`), how far it darts (`reach`), meter `fill` and `drain` a second, `strike` (dip window multiplier), `weight`, `spots`, `reward`.
- `game/data/levels.csv` `fish_*` rows: pond size, notice reach and chance, approach and idle seconds, wait for the bite, nibbles, dip window, marker width, speed and spring, first hover, ease-in length and its start shares, meter start, party skill slow. The notice, ease and spring numbers are `[AI]` (`docs/decisions.md`).
- `Game.land_fish(row)`: reward into the pack plus the `caught_fish_<id>` flag.
- Screenshots: `game/tools/fishing_shot.gd -- <png> look|come|bite|reel|caught` (cloud: xvfb-run with `--rendering-driver opengl3`).

## Graybox
The pool, shadows, lily pads, reeds, bobber, rod, angler and bar are flat shapes drawn in code until Brandon's art. All words are placeholders in `game/text/placeholder.csv` (FISH_*, GRADE_*, UI_FISH_*).
