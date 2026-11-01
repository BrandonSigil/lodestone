# The healing model: Fire Emblem in a fight, Oregon Trail on the road

Game designer, 2026-11-01, for Brandon's reversal on `dev-food-review` (the `[USER]` line is in `docs/decisions.md`): food is both a health thing and a road resource, the party eats every day at camp, no food ends the journey. Card `design-healing`; all of this is `[AI]` until he picks.

## Numbers today (origin/main)
- Food items in `items.csv` have a `food` column (portions) and a new `heal` column: meat 1 portion and heals 2, ration 5, sack 12, jerky 30 (no heal yet).
- Potions (`medicine`): the belt `salve` heals 5 at range 1, the `snack` heals 2.
- Camp REST (`data/levels.csv`): free, `camp_hp_pct` 50% of max HP, plus all mana and charges, plus +10 morale; walking trickles 1 mana or charge per 10 tiles. A cooked camp meal heals its `heal` column and gives its `morale`.
- Skills: mend heals 4 plus magic for 3 mana (range 2); Good Boy heals the friend next to Doggo 1 at the start of its turn; Glean (Bushberry) the same; renew heals over time.

## My pick (option A in the card)
**In a fight (Fire Emblem):** HP is a budget. Healing comes only from skills and belt items: mend, renew, Glean, Good Boy, belt potions (salve heals 5, range 1), and prevention (Branch Armor, ward). Nothing else, so the fight is about spending a few limited tools well.

**On the road (Oregon Trail):**
- **Camp REST** heals 50% of max HP free, once per camp spot. It also refills mana and charges and gives +10 morale. Camping is the end of a journey day.
- **Support skills work out of a fight** at their normal mana cost (mend 3 mana for 4 plus magic). Mana only trickles back on the road and fully refills at camp, so a mender's road healing taxes the next fight, like D&D spell slots.
- **Eating extra food heals.** Fresh meat heals 2 HP per portion when eaten on purpose. Plain rations, sacks and jerky are upkeep only: they feed but do not heal.

**Food as upkeep and as healing, without double counting:** the daily meal and healing are different decisions on the same pool.
- Every day at camp each party member eats their `food_per_day` portions, automatically, from the pack. Plain food only feeds. It does not heal.
- **A cooked meal or tavern dish replaces that day's plain meal:** one stew feeds the whole party for the day, and also heals each member its `heal` and gives its `morale`. That is how food is both: good food is better because it feeds, heals and lifts morale in one item.
- Eating meat to heal is a choice on top: it spends portions you may need tomorrow.

**No food:** if the pack cannot feed everyone at camp, the journey is over. The party is carried home as in a fall, nobody is hurt, loot stays, but everyone loses 10 morale (the old starving number) and the day does not pass. The camp screen warns before it happens.

## How it ties to morale
Falls cost morale and an unrevived fall costs more, so mend raising a downed friend saves 10 morale as well as HP. Camp +10, cooked meals +10, +15 or +25, the hero's bed +20 and journey days at home are as in `docs/systems/morale.md`. Running out of food costs 10. Good Boy softens every loss by 20%.

## The other two options
- **B, food heals most:** camp rest gives no HP; the daily meal heals each member by its `heal` and food is the main healing. Strong Oregon Trail pressure; risk of a death spiral when food runs short.
- **C, potions and support only:** food is upkeep only, with no healing; HP comes from camp REST, potions and skills. Cleanest, but food loses the "health" role you asked for.

## For the systems developer
Daily eating at camp is already being put back. The model above adds: camp and meal rules, eating meat on purpose, out-of-combat skills costing mana, the unfed-camp "journey over" result with -10 morale, and a cooked meal counting as the party's day. Heal values live in `items.csv` (`heal`) and `recipes.csv`.

## Camp meal picker (Brandon, 2026-11-01)
He picked model A and added: at camp each night the player picks what food each member eats, or uses a team Feast item for everyone if one is in the pack.
- **The picker:** a camp screen lists each member with the food kinds in the pack. Pick one per member; their daily portions come from it. Any food heals its `heal` when eaten (meat 2 a portion; ration, sack, jerky 0), so picking meat for a hurt member is the healing choice, and the same pool pays the upkeep.
- **Team meal:** a cooked meal item in the pack (stew, roast, Feast) feeds everyone at once, replaces the individual picks, heals each member its `heal`, gives its `morale` and its buff for the next fights. The Feast is the biggest.
- **Default:** a button, "same as last night", fills the picks so a quiet camp takes one click. If the pack cannot cover everyone, the camp warns and the journey ends as above.
