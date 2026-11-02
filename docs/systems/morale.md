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

## Morale is hunger ([USER] 2026-11-02, built from `docs/design/morale-hunger.md`, option C)
- **The night's meal** (`TravelRules.camp_meal` returns who was short; `Game.camp_hunger` applies it): a fed night
  holds morale (`fed` 0); a member who eats nothing loses `unfed` (-15), and a short meal its share, rounded up
  (`MoraleRules.hunger_loss`; 1 of 2 portions: -8). Doggo's Good Boy softens it. Members who eat nothing (the Lich
  Prince, Bushberry's `food_per_day` 0) never lose morale to hunger.
- **The camp screen** warns "Not enough food: N will go hungry tonight" (`TravelRules.hungry_with`) and every row has
  GO HUNGRY (`TravelRules.SKIP`), so the player chooses who eats.
- **Spent** (`spent_at` 0): a Spent member sits out every fight (explore `start_fight` and road fights deploy only
  `Game.fit_members`) and earns no XP (`Game.award_xp(xp, ids that fought)`), but still walks and eats. A camp REST or a
  full meal (a fed night, a team meal, a dish at the tavern) lifts them to `spent_lift` (10), Broken, and they fight
  again. The camp row shows a SPENT chip with the rules on hover. A fight under way never removes anyone.
- **The loss:** everyone Spent, at a camp or after a fight (`Game.all_spent`): the party is carried home as in a fall
  (`Game.party_spent`, line `UI_ALL_SPENT`): loot kept, nobody hurt, not a death, no more morale lost. `no_food` and
  `Game.larder_empty` are gone.
- **The tavern ward:** at the rebuilt tavern's counter, EAT HERE pays a dish for one character (in the party or home):
  they gain `sitdown_mult` (2) times its recipe's morale (stew +20 for 10 gold), and a Spent one is back on their feet
  (`Game.sit_down`, `sitdown_morale`). Plain food (rations, jerky) gives no morale there.
- **New-player bumpers:**
  1. Before the first trip, GO at the gate tops the pack up to `first_trip_food` (12) portions with free rations, once
     (`Game.starter_food`, flag `starter_food`), and says so.
  2. GO with under `gate_warn_days` (3) days of food for the party picked asks "Go anyway / Back" (`TravelRules.food_days`).
  3. On each of the first `grace_trips` (3) trips the first `grace_nights` (1) nights' hunger costs nothing
     (`MoraleRules.grace`, `meta.trip_nights`), and the warning says so.
  4. A companion joining for the first time brings `join_food` (4) portions as rations (`Game.join_food`, flag
     `joined_<id>`).
- **A new player who skips the food barrel:** the gate adds 3 rations (15 portions; the hero and Doggo eat 2 a day, so
  7 nights), the first night is free anyway, and an empty pack later only costs morale, so the first trip can't end
  at the first camp. From 70 morale a member who never eats lasts 5 nights before Spent.

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
- Healing model A is built ([USER] 2026-11-01, `docs/design/healing-model.md`). Each journey day on the road ends
  at a night camp (`OverworldScene._night`): every member eats their `food_per_day` portions of the food kind the
  player picks for them, the picks open as last night's (SAME AS LAST NIGHT), and food heals its portions' worth
  (`heal` / `food` in `data/items.csv`: meat 2; plain rations, sacks, jerky and raw fish 0, cooked at home instead), so meat for a hurt
  member is the healing choice. A food item with several portions keeps what's left once opened (`RunState.opened`).
  A cooked meal in the pack is a TEAM MEAL: it feeds everyone that night, heals each its recipe's `heal`, gives its
  `morale` and its buff for the next fights (`Game.team_meal`). An empty or short pack no longer ends the journey:
  see "Morale is hunger" below. MAKE CAMP (once a leg) is the free REST: half HP, all mana and charges, +10
  morale. Support heals (mend, renew, patch: a member's `heal` abilities paid with mana or charges) can be cast out of
  a fight from the PARTY window (CAST, then a party card), at their cost and with their fight amount
  (`TravelRules.road_heals`, `cast_on`); mana trickles back on the road and refills at REST. In a fight nothing
  changes: skills, passives and belt items only.
- How the tavern restores morale ([USER] Pitch G) is open.
