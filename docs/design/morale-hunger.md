# Morale is hunger

Game designer, 2026-11-02, for Brandon's [USER] line "Morale is hunger" and the polish-day bumpers line in `docs/decisions.md`. Everything here is [AI] until he picks. It replaces only "no food = journey over" (2026-11-01). It keeps per-character morale, the bands, fight costs, Doggo's Good Boy, the bed, the benched days, and "the tavern restores morale through meals only".

## 1. The road loop
Morale is one meter that food feeds. Every night at camp, each member eats the portions they need (the picker stays).

- **Fed day:** no change. Morale holds.
- **Unfed day:** -15. A short meal loses its share: 15 times the missing portions over the needed ones, rounded up. Members who eat nothing (Bushberry, the Prince, the Archer) never lose morale to hunger. Good Boy still softens it by 20 percent.
- **Fights:** as today. Down -5, left down -10 more, won +2 per piece that stayed up, elite or boss win +5.
- **Lifts:** camp REST +10 once a leg, cooked meals +10, +15, +25. These are how a hungry party digs out.
- **No more "journey over".** An empty pack no longer ends the trip. The camp warns "N go hungry" and you choose who eats. From 70 morale, a member who never eats lasts 5 nights before hitting 0. That runway is the new bumper in itself.

**At 0, a member is Spent.** A Spent member cannot fight: they sit out every fight and earn no XP. They still walk and still eat. They are not dead weight forever: REST or a meal lifts them to 10, and at 10 they fight again, Broken. A fight already under way never removes someone mid-battle.

**The loss.** When every member in the party is Spent, at a camp or after a fight, the party is carried home as in a fall: loot kept, not a death, no extra morale loss (they are already at 0). The old -10 `no_food` goes away. The page that shows on arrival is the same homecoming page. A loss starts the next trip from 0, so home recovery has to matter.

## 2. Home recovery: three options
XCOM's ward heals soldiers who sit out missions. The same idea fits: the road drains morale, home refills it, and the refill has a price.

**A. Rotation.** Home recovery is only what exists now, turned up. The bed gives +20 once a trip. Benched companions gain 5 a day gone (was 3). You decide who rests and who goes. Rations matter because a smaller party eats less, so a rested pair can stretch the same pack. Weakness: after a loss, a party at 0 gets only the +20 bed and heads out Broken. It is free, so it has no pressure.

**B. The home pantry.** Home nights are fed days. Leftover food from the pack goes into a home larder. You can SLEEP any number of nights in the bed. Each night passes a day and costs the larder one portion per member, and a fed member gains +15. Benched days still count. You decide how many nights to spend before going out. Rations matter twice: food you didn't eat on the road is your recovery at home, and a hungry trip leaves an empty larder. Weakness: it adds a new larder to build and balance, and "sleep until full" can be a chore.

**C. The tavern ward.** A is the base. On top of it, once the tavern is open, SIT DOWN at the counter: each member you pay a dish for gains twice that dish's morale (stew +20 for its 10 gold). You decide who is worth gold now and who can sleep it off. Rations matter because gold buys them too (a ration is 2 gold, a stew 10), so every coin is either rest now or food on the road. It uses the existing tavern menu and Brandon's "meals only" call, and it gives a loss a cost: four Spent members need about 40 gold to be fit to go.

**I recommend C.** It is the smallest build, it follows what Brandon already picked for the tavern, and it makes gold the dial between "rest more" and "carry more". The free parts (bed, benched days) mean a broke player is never stuck.

## 3. New-player bumpers
The "found a friend, picked a class, died on the road" case happens at the first night camp. Each bumper below blocks it.

1. **Starter pack.** On the first trip only, the gate tops the pack up to 12 portions with free rations. With the hero and Doggo eating 2 a day, that is 6 days. It covers the player who skipped the barrel.
2. **Gate warning.** If the pack holds under 3 days of food for the party, leaving asks "N days of food. GO ANYWAY / BACK". The number comes from the party you picked, so adding a companion updates it.
3. **First night is free.** On each of your first 3 trips, the first night's hunger costs nothing. Nobody is ever punished at the first camp.
4. **A new mouth brings lunch.** When a companion joins for the first time, the pack gains 4 portions. Their hunger no longer eats the player's plan.

## 4. Numbers

| Name | Value | File | New or changed |
| --- | --- | --- | --- |
| `unfed` (morale per unfed day) | -15 | `game/data/morale.csv` | new (replaces `no_food` -10, removed) |
| `fed` | 0 | `game/data/morale.csv` | new |
| `fight_min` (below this a member cannot fight) | 1 | `game/data/morale.csv` | new |
| `home_day` (benched, per day) | 5 | `game/data/morale.csv` | changed (was 3) |
| `bed` | 20 | `game/data/morale.csv` | unchanged |
| `sitdown_mult` (home dish morale, option C) | 2 | `game/data/morale.csv` | new |
| `grace_trips` / `grace_nights` | 3 / 1 | `game/data/morale.csv` | new |
| `first_trip_food` (portions) | 12 | `game/data/levels.csv` | new |
| `gate_warn_days` | 3 | `game/data/levels.csv` | new |
| `join_food` (portions) | 4 | `game/data/levels.csv` | new |
| Dish prices (ration 2, jerky 7, stew 10) | as is | `game/data/tavern_menu.csv` | unchanged |

Needs the developer: the camp picker lets someone go hungry, the Spent check in the fight setup, the loss check, and the gate prompt. All words are placeholders and plain rules text, no story.
