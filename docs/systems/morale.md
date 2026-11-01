# Morale, per character

[USER] 2026-10-31 (design-goodboy): morale is per character and kept after a Lodestone run; falls cost it, a fall nobody
picks up costs more, and low morale makes a character weaker (Banner Saga style). Food is healing, camping and good food
restore some, and the village is the main way back. [USER] 2026-10-31 Pitch B: morale sits stable in the middle and
80 to 100 is a passive high-morale bonus, never spent. [USER] 2026-10-31 (design-morale, "build"): "for every day gone, a
character at home gets X morale". Built 2026-11-01 from the proposal in `docs/design/morale.md`. Every number is data.

## How it works
- **Where it lives.** `Game.meta.morale`, id -> 0..100, for the hero and every companion met. New characters start at
  `start` (70). An adventure run's `run.hearts` is that same dictionary (`Game._link_hearts`), so nothing resets it: a
  fall, GO HOME and a restart all keep it. The shelved trail keeps its old group `run.morale`.
- **Bands** (`game/data/morale_bands.csv`, rules text in plain English in the menus):

| Morale | Band | In a fight | On a d20 check |
| --- | --- | --- | --- |
| 80 to 100 | Heartened | +10% crit (`attack:+2`) | +1 |
| 60 to 79 | Steady | none | none |
| 40 to 59 | Shaken | -1 damage | none |
| 20 to 39 | Low | -1 damage, -1 move | -2 |
| 0 to 19 | Broken | -2 damage, -1 move, -1 armor, 1 less max mana or charges | -3 |

  The fight mods ride on each member's `bonus` (`Game.refresh_party` merges `Game.morale_mods`), so every fight and
  the Lodestone menu's stats show them. Checks use each member's skill plus their own band (`TrailRules.party_bonus`,
  `best_member`).
- **What costs it** (`game/data/morale.csv`): going down in a fight -5; ending the fight down and never helped up (bled
  out or knocked out) another -10; everyone down in a lost fight another -10 each. Event options that say `morale:-n`
  now hit every party member.
- **What gains it:** a won fight +2 for each piece that stayed up (+5 for an elite or boss win; an escape gives
  none); the camp REST on the road +10 (a gloomy character 2 less); a camp meal +10, +15 or +25 (the `morale` column
  of `data/recipes.csv`); a night in the hero's bed at home +20 for everyone met, once a trip (the `home_bed` thing in
  `data/explore/home.json`, event `home_bed`, effect `sleep:1`; it also heals the party and refills mana and charges);
  and **journey days**.
- **Journey days.** The road counts a day every `TravelRules.DAY_SECONDS` walked (camp time included; each day ends with the camp meal);
  explore maps out of town count one every `day_steps` (150) tiles. Every day, each companion not with the party (left
  home at the gate, or the courier sent home) gains `home_day` (3). `meta.days` keeps the count.
- **Doggo's Good Boy:** while he's in the party, every member's morale losses are 20% smaller, rounded toward zero
  (-5 is -4, -15 is -12).

## Where it shows
- After a fight, the summary lists each change ("LEAD HEART -4").
- The Lodestone menu: each member's morale, band and what the band does.
- The gate's EDIT PARTY: each companion's morale and band beside COME / STAY HOME.
- The homecoming page's HEART section: the days gone, then each character's change and the band they're in now.

## Files
- `game/scripts/core/morale_rules.gd`: pure rules (bands, changes, Doggo, fights, days).
- `game/data/morale.csv`, `game/data/morale_bands.csv`, the `morale` column in `game/data/recipes.csv`.
- `Game`: `fight_morale`, `pass_days`, `walk_days`, `sleep_at_home`, `morale_of`, `morale_band`, `morale_mods`.
- `game/tests/test_morale.gd`.

## Open [AI] calls
- X, the morale per journey day at home, is 3. A trip to the pass and back is about 6 to 8 days, so about +20.
- Heartened's fight bonus (+10% crit) is new; the design draft had none. Blessing statues ([USER] Pitch B) can grant
  morale through an event's `morale:+n` once one is placed.
- Daily eating is back ([USER] 2026-11-01, replacing "no hunger"): each journey day on the road ends at camp, where
  everyone eats their `food_per_day` portions from the pack (meat first, then caught fish by the `food` column). The
  daily meal only feeds. If the pack can't feed everyone, the journey is over (`Game.larder_empty`): the party goes home
  as in a fall, nobody hurt, loot kept, not a death, and everyone loses `no_food` morale (-10). Food eaten on purpose
  still heals its `heal` column, and camp REST stays free. The rest of the healing model (`docs/design/healing-model.md`,
  the camp meal picker) waits for its build.
- How the tavern restores morale ([USER] Pitch G) is open.
