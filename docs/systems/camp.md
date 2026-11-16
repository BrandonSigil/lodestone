# The campfire

Built 2026-11-16 from option A of `docs/design/campfire-trail.md` (Brandon picked "Go with A", and "A to C is great" for later). Each journey day on the road ends at one campfire screen. It replaces the road's HUNT, FISH, FORAGE, TALK and MAKE CAMP buttons and the per-member meal picker.

## What the player sees
- **The screen.** At nightfall (`OverworldScene._night`) the campfire fills the play area above the party frame, as fishing does.
  - **Centre:** the party sits round a fire drawn in code.
  - **Top:** "NIGHT n" with tonight's slots.
  - **Left:** the pot.
  - **Right:** the evening's actions.
  - **Bottom:** SLEEP, SAME AS LAST NIGHT and "Every night the same".
- **The pot.** Days of food at the ration on the dial, the dial itself (FILLING / MEAGER / BARE), the days at the next ration, and the food kinds in the pack. A warning line appears when someone would go hungry. The dial's setting is kept (`meta.settings.camp_ration`).
- **The evening.** `slots` actions a night (3), each once (`data/camp_actions.csv`). An action that can't be taken is greyed, and its tooltip says why: no rod, nobody hurt, already done, or the evening is full.
  - **COOK:** serves a cooked meal from the pack (`Game.eat_meal`: its heal, morale and buff). With none, a hot pot gives everyone who eats `hot_pot` morale.
  - **FISH:** the fishing minigame over the camp; needs a rod. Leaving before the cast frees the slot.
  - **HUNT, FORAGE:** the party's best roll (`TravelRules.activity`).
  - **TALK:** pick a pair. They gain `talk_points` bond points and share a talk: Brandon's `BOND_TALK_<PAIR>_<level>` line once their bond has a level, else `BOND_TALK_EMPTY`.
  - **MEND:** the most hurt member heals `mend_hp`.
  - **REST:** `Game.camp_rest`: mana and charges, half HP, +10 morale, and it lifts the Spent.
- **SLEEP.** Eats the pot (`Game.camp_eat`), then the night ends as before (`OverworldScene._after_camp`, then `_end_night`). Everyone Spent is carried home.
- **SAME AS LAST NIGHT.** Repeats last night's actions and ration, then sleeps. Fishing becomes a quick cast (the fish roll), and actions that can't be taken tonight drop out (`CampRules.repeatable`).
- **"Every night the same".** Later nights run that way without the screen while the pot can feed everyone (`meta.settings.auto_camp`, `camp_plan`, `camp_pair`).

## The pot (`CampRules.eat_pot`)
- **How much it takes:** `RunState.food_need()` times the ration's `share` (`data/camp_rations.csv`), rounded up.
  - FILLING is 100%.
  - MEAGER is 50% and costs everyone who ate 5 morale (softened by Doggo).
  - BARE takes nothing: everyone goes hungry, as at an empty pack, and the food is saved.
- **Order:** the food kinds that heal most go in first (meat, then fish grades, then plain rations). The heal of what was eaten is shared evenly by everyone who ate.
- **Short pot:** the companions go hungry before the hero. Hunger is morale, as before (`Game.camp_hunger`, `MoraleRules.hunger_loss`).
- **Free nights:** the first trips' free night still applies, and a thin ration costs no morale on it.
- **The Lich Prince** (Cold Blooded, `food_per_day` 0) eats nothing and isn't counted.

## The rod
The first trip's free kit (`Game.starter_food`, at the gate) now includes a fishing rod when the pack has none. The rod was in the game before, but on the live path the only one was a pickup by the village stream.

## Code and data
- `game/scripts/overworld/camp_rules.gd`: `CampRules`, pure and tested in `game/tests/test_camp.gd`.
- `game/scripts/overworld/camp_screen.gd`: `CampScreen`, the screen. `CampScreen.act` and `repeat_plan` run an action or last night's plan without the screen.
- `Game.camp_eat`, `camp_cook`, `camp_mend`, `camp_talk`.
- `game/data/camp.csv` (slots, hot_pot, mend_hp, talk_points), `camp_actions.csv`, `camp_rations.csv`.
- Text keys `CAMP_*` in `game/text/placeholder.csv`.
- Shots: `game/tools/overworld_shot.gd` steps `night`, `night_evening`, `hungry`, `camp`.

## Campsites on the map (option C)
Built 2026-11-16 after Brandon's "A to C is great". Options has NIGHT CAMPS: AT CAMPSITES (the default) or EVERY NIGHT (option A as first built), so the two can be played side by side. The commit before campsites is tagged `before-campsites`.

- **The light.** A day is still 30 walked seconds (`TravelRules.DAY_SECONDS`), but with campsites it counts from the last camp (`Game.travel.since`), carried from leg to leg. The walking line shows "Dusk in n h" (a 12-hour day).
- **Campsites.** Each road has three, drawn as tents on it, in the site's colour. Standing at a place, the roads out show theirs, so stops can be planned; walking, passed ones fade. Hovering a tent names it. Reaching one stops the walk and asks CAMP HERE or WALK ON, with what it gives and the light left. One reached in the first 40% of a day after a camp is walked past (`CampRules.ASK_AFTER`). FAST FORWARD stops at them too.
- **What each gives** (`game/data/campsites.csv`):
  - River camp: the only camp where FISH works.
  - Hilltop camp: one more evening action (4).
  - Old ruins: a free forage before the evening.
  - Meadow camp: nothing special.
  - Rough camp: when the light runs out before the party stops. One fewer action (2) and -5 morale for everyone (free in the new-player nights, like the ration's cost).
- **The trade.** Stopping early is safe but spends a day's food on less road; pushing on to a better site risks the rough camp.
- **Data.** `overworld_paths.csv` `camps`: "0.3:meadow|0.5:river|0.8:hill", each a share of the way from the row's `from` (`CampRules.leg_sites` turns it round for the other way). The campfire screen takes the site (`CampScreen.open(..., site)`): its name in the title, its line under it, its slots, fishing and free action. `Game.camp_site_morale` applies its morale on sleeping.
- **Code.** `OverworldScene._advance_sites` (the clock), `_at_site` (the question), `_draw_sites` (the tents). Rules in `CampRules` (`style`, `leg_sites`, `next_site`, `slots_at`, `ask_at`, `daylight`). Tests in `test_camp.gd`. Screenshots: `overworld_shot.gd` steps `site_map`, `site_ask`, `site_camp`, `site_dark` (the older camp steps play EVERY NIGHT).
- **My calls ([AI]):** the hill gives an action rather than a free watch (there are no night ambushes yet); the ruins give a free forage until fireside events are written; three campsites a road, in five rotating patterns, not placed by hand.

## Not built yet
- **Fireside events:** about one night in three, a choice card.
- **Pace dial:** STEADY / HARD / GRUELING.
- **Water near camp:** with EVERY NIGHT, FISH is offered whenever there's a rod; with campsites only a river camp fishes.
- **Dishes cooked at camp:** cooking is still at home; COOK serves what you carry.
- **Old camp code:** `TravelRules.camp_meal`, `default_picks` and `hungry_with` still exist for their tests and the old trail; the road no longer calls them.
