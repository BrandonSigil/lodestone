# Bushberry joins, and the tavern

Game designer, 2026-11-01, for the milestone "Bushberry joins" (`pm-next-milestone`) and Pitch G (`master-g-first-companion`). Brandon's words are in `docs/decisions.md` (the 2026-11-01 Pitch G line). Everything here is `[AI]` until he picks on the four desk cards (`design-bb-*`). No story, no dialogue, no names from me; every text slot is a caveman placeholder in `game/text/placeholder.csv`, and rules text is plain English.

## What is already decided
- Bushberry is a mender/support with **one ranged damage spell that pulls a foe one cell toward him** (`[USER]`).
- Recruiting him **opens the tavern**: characters hang out and regain morale, and gold buys food items (`[USER]`).
- The food menu **grows with the resources, characters and recipes you bring home** (`[USER]`).
- How the tavern restores morale is open (the card below).
- His older traits stay: makes a ration a day (`bushberry_ration`), flammable (fire +2 damage taken), and `deep_roots`.

## What the game has today
- **He can already join:** the playtest line-up in the village square lets anyone with art join, and Brandon had him in his party (2026-10-31). But his class `data/classes/bush.tres` has no abilities: 12 HP, move 2, damage 1, a plain 1-tile attack, and forage 3. So his kit is the most urgent part.
- He sits in the village square as a `companion` thing with event `recruit_bushberry` (invite, send home, leave), unlocked by flag `found_bushberry`. That is the playtest line-up.
- The `tavern` explore map (12 x 11) exists, with the cook (`settler_chef`) and four containers, but nothing opens it.
- Morale is per character (`docs/systems/morale.md`): a night in the hero's bed +20 once a trip, camp +10, camp meals +10, +15 or +25, and each journey day a companion left at home gains `home_day` (3).
- Food items have `price`, `food` and `medicine` in `data/items.csv`. Food as healing is being built by the systems developer; the tavern menu must use whatever item columns that build lands.

## 1. Finding and recruiting him (`[USER]` `design-bb-recruit`)
He is held captive on the snow pass by an **elite ogre** (the existing `ogre` class, at elite strength: 150% HP, +1 damage, +1 armor, `data/combat.csv`). Winning that fight frees him. He **joins the party if there is room** (four slots); if the party is full, **he runs back to the village** and waits at home to be invited. Either way, flag `rescued_bushberry` is set and the elite group stays beaten. A fall during the fight is a fight lost like any other. No cost. Story and dialogue are Brandon's; every text slot is a caveman placeholder. The map builder places the captive and the elite group on `snow_pass`; the line-up in the village square stops listing him.

## 2. His kit (`[USER]` `design-bb-kit`, numbers `[AI]`)
Resource: mana (a mender's numbers, 3 move). Abilities, each with three upgrade steps in `data/ability_upgrades.csv`:
- **tug** (new, in `abilities.csv`): ranged, 2-4 (scaled), 3 mana, 1 less than his spell damage, **pulls the foe 1 cell toward him** (`push:-1`). Steps: damage, reach, cost.
- **mend:** heals 4 plus magic, range 2, and **can raise a downed friend** at its heal amount (`mend_raise`), so no far_aid.
- **Branch Armor** (his name; replaces ward for him): 4 mana, a friend within 3. The next hit on them does 3 less damage (at least 1) and the piece that hit them takes 2 damage (`branch_soften`, `branch_thorns`). Lasts until used or his next turn; does not stack. Steps: softens 1 more, hurts 1 more, costs 1 less.
- **renew:** heals over time at range 2; kept as the fourth ability. It does not clash with Glean.
- **Passive Glean** (his name): friends standing next to him heal 1 HP at the start of each of their turns (`glean_hp`). Upgrade steps (+1 HP, a 2-tile radius, +1 HP) wait until the trait is on his class, because the data test requires a class trait to exist first.
- Older passives stay: `bushberry_ration` (a ration each journey day), `flammable` (fire +2 damage taken), `deep_roots` (cannot be pushed).
**Glean and Good Boy:** they stack. A friend next to both heals 1 from each at the start of its turn, 2 in all. Each source heals once a turn.
`far_aid` stays in the mender archetype's kit (`kits.csv`); Brandon only said Bushberry does not need it.

## 3. How the tavern restores morale (`[USER]` `design-bb-morale`)
**Meals only.** A character eats at the tavern counter; a stew gives its recipe's +10 morale. No hang-out bonus, no free evening. The hero's bed, camp and journey days work as in `docs/systems/morale.md`.

## 4. The tavern and its menu (`[USER]` `design-bb-recruit`, `design-bb-menu`)
**The tavern is rebuilt at home** as a restore step: a `tavern` row in `data/restore.csv` with `needs` of resources and food (my starting cost: wood 4, metal 2 and ingredient 3), `gives: unlock:tavern_open`, settler Bushberry. Paying and returning from a run finishes it (the same `restore` flow as the smithy). Then the counter opens.
**First menu, three dishes** (gold into the pack): ration (2 gold, heals 4), jerky (7 gold, heals 16), stew (10 gold, heals 6 and +10 morale). The menu grows by rows in `data/tavern_menu.csv` (item, price, `needs`): a dish appears when you bring home its resource (herb, ingredient, rare), when its recipe unlocks, or when a character who cooks or brings it joins. Food items follow whatever columns the developer's food-as-healing build lands on origin/main (today `items.csv` still has `food` and `medicine`); the heal numbers here are mine.

## Build order (kit first)
1. **His kit** (he has no abilities today): `bush.tres` gets mana, the four abilities and the traits (Glean as a class trait, then add its upgrade rows); `tug` and `branch_armor` are in `abilities.csv` already (the effects are unbuilt); `mend_raise` in the engine.
2. **The rescue and recruit:** the captive and the elite ogre on `snow_pass`, the join-or-run-home rule, `rescued_bushberry`; the playtest line-up stops listing him.
3. **The tavern:** the restore step, `tavern_open`, the counter, `tavern_menu.csv`, buying with gold.
