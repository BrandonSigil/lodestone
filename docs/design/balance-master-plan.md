# Balance master plan: making every run hard fought

Balance officer, 2026-11-16. Brandon's ask: "run some hard math and logistics on how we can make every run feel hard fought ... Rations/food should feel tight, having to fish or hunt for food should feel hard fought, you could walk away empty handed. I dont want the game to feel impossible ... small improvements over the course of the game which ultimately get you past the wall."

This is a plan with measurements. Nothing in `game/data/` changed. Every number proposed here is `[AI]` until Brandon picks it. The measuring tool is new: `game/tools/economy_sim.gd` (usage at the end).

## One-page summary

**What is true today (measured):**

1. **Food is never short.** A trip to the Lich eats 4 to 6 portions (2 or 3 nights on the road, 2 eaters). The party leaves with 12, finds 6 to 17 more hunting at camp, 4 on the road, and the eight fights drop 51. It reaches the throne with 53 portions. In 1,000 simulated trips there was not one hungry night.
2. **The food clock stops where the trip happens.** Days only pass on the world map. The pass, the wolf den and the crypt cost no food, and every camp comes before the first fight, so REST and MEND have nothing to fix.
3. **Meat is a free full heal.** One portion heals 2 HP, with no limit, between fights. A player who eats the fights' own meat reaches the Lich at 100% HP and wins the first try 39 to 94% of the time (target 5 to 10%). A player who never eats arrives at 58% and wins 10 to 13%. So "fights must cost" holds only for players who don't open the pack.
4. **Levels run away.** The seven fights before the throne pay 445 XP, and a level is a flat 100. One failed trip is +4.5 levels. The second try is at level 10 and wins 85 to 94% (target 25 to 50%). Nothing else is needed, so upgrades, the kitchen and side trips have no job.
5. **A third party member is worth more than everything else together.** At level 5 and 60% HP the duo beats the Lich 14% of the time; one weapon upgrade makes that 39%; a third member makes it 93 to 100%.
6. **Hunting is already a coin flip** (45% empty-handed for hero and Doggo), which is about right. It just doesn't matter, because food isn't scarce.
7. **Town upgrades arrive after the wall has fallen, or never.** Metal is plentiful. Herbs have one source in the whole region (2, once ever), so the book ladder and the second kitchen step can't be finished.

**The plan in five moves (all `[AI]` proposals):**

1. **Run the food clock on the maps too:** a cold meal every 150 tiles walked (no camp, so "camp only on the world map" stands). A push to the Lich becomes about 5 days of food, not 2.
2. **Make meat the healing budget:** cut the fights' food to about 30%. The party then has to choose between a full pot, healing, and spending evenings hunting.
3. **Slow the levels and firm the wall:** 200 XP a level and the Lich at 52 HP (was 42). Measured with a player who eats sensibly: first try 5%, second 31%, third 48%, fourth 91%.
4. **Make each evening action worth about the same,** so the right pick depends on the night: a riskier, bigger hunt; a safer forage that brings herbs; a smaller REST; a bigger MEND and TALK.
5. **Give the other run types their own pay:** a failed push costs morale that a safe trip earns back; side trips are the only source of herbs, ingredients and recruits; each town step is worth a named slice of the wall.

**The seven calls only Brandon can make are at the end.**

## 1. What is true now

All numbers are from the shipped data. Sim runs are hero plus Doggo with the fight AI on both sides, 50 to 80 trips a weapon unless noted. Tables are in the appendix.

### Food
| | portions |
| --- | --- |
| Carried at the gate, first trip (free kit) | 12 |
| In the town chest on a new game | 10 (2 rations) |
| Eaten on the way to the Lich, FILLING | 4 to 6 (2 or 3 nights x 2) |
| Eaten on MEAGER | 2 to 3 |
| Found at camp if two of three evening actions go to food | 12 to 17 |
| Found in road events | 4.5 |
| Dropped by the eight fights | 51 |
| In chests on the way (each trip / once ever) | 12 / 8 |
| Left at the throne door, eating nothing but the pot | 53 |

A 60-second road is two days of light. Camping at every campsite is 3 nights; holding out for the good sites or never stopping is 2. A rough camp only happens if the player never stops at all.

### Hunt, forage, fish
Hero and Doggo roll at +2 (Doggo's skill). With the Hunter along it is +5 to hunt and +3 to fish.

| action | empty-handed (duo) | portions a try (duo) | with the Hunter |
| --- | --- | --- | --- |
| HUNT (DC 12, 3 + half the margin) | 45% | 2.9 | 30% empty, 4.2 |
| FORAGE (DC 11, 1 + half the margin, and a potion) | 40% | 2.1 and 0.6 potion | same |
| FISH, quick cast (DC 11, 2 + half the margin) | 50% | 2.0 | 35% empty, 3.1 |
| FISH, the minigame | by skill | 1.8 a landed fish, 0.29 ingredient | |

One evening action feeds the duo for a day or more. These dice are constants in `TravelRules.ACTS`, not data.

### Morale
On a trip it barely moves. Fed nights cost nothing, seven won fights give +14, the bed gives +20, a fall costs about 25. A failed push still ends +9. The worst morale seen in the road sim was 62, and only for a player who never camps at a site.

### HP, XP and the Lich
| fight | won | party HP lost |
| --- | --- | --- |
| pass wolves | 100% | 9% |
| pass bandits | 100% | 16% |
| den wolves | 99% | 5% |
| den lone wolf | 100% | 0% |
| crypt plaza | 99% | 16% |
| crypt cave | 100% | 0% |
| crypt tower | 100% | 0% |
| the Lich | 50% | 21% |

The road fights cost 6.5% of the party's HP each on average (the old target was 12 to 15%). Three of the seven cost nothing. They pay 445 XP together, 135 more for the Lich.

| Lich win rate | try 1 | try 2 | try 3 |
| --- | --- | --- | --- |
| Brandon's target | 5 to 10% | 25 to 50% | rising |
| Never eats between fights: sword / daggers / bow | 13 / 10 / 10% | 94 / 85 / 89% | 100% |
| Eats the fights' meat: sword / daggers / bow | 94 / 75 / 39% | 100 / 95 / 94% | 100% |

### Materials
A full trip through the pass, every time: metal 6, wood 3, gold about 48 (68 with the Lich). Once ever in the whole region: rare 4, metal 6, herb 2, ingredient 2.

- Forge, whetstone and the sword to +3 need metal 14, wood 5, rare 4. Metal and wood take two trips. Rare is the cap: one weapon to +3 plus the full kitchen needs 5 and the region holds 4.
- Herbs: 12 are asked for (kitchen step 2, the book ladder) and 2 exist.
- Ingredients come only from fish (0.29 a landed fish) after the first 2. A stew needs 3.
- A restore step is done on the return from the next trip, so forge, whetstone and sword +1 land after trips 2, 3 and 4. The Lich falls on trip 2.

## 2. The model: what turns into what

| resource | comes from | turns into | rate today |
| --- | --- | --- | --- |
| Food (portions) | gate, loot, hunt, forage, fish, gold | a fed night; HP | 1 portion each a night; meat 2 HP a portion |
| HP | food, potions, MEND, REST, support spells | winning the next fight | 20 points of arrival HP is worth 35 points of Lich win chance |
| Morale | fed nights, wins, REST, hot pot, bed, tavern | damage (under 60: -1) and checks | never under 60 today |
| Evening actions (3 a night) | campsites | food, HP, morale, bonds | see below |
| Daylight | walking | which campsite you reach | 30 s a day; a rough camp is -1 action, -5 morale |
| Pack room (12 cells) | fixed | what comes home | meat 10 a cell, so food never crowds the pack |
| Gold | loot, chests | food, tavern meals | 2 gold buys 5 portions; a trip's gold buys 120 |
| Materials | chests, one-time finds, fish | town steps | metal 6 a trip; herbs none |
| XP | won fights | levels | 100 a level; 445 a trip |
| Bonds | fights (up to 3 each), TALK (2) | team-up damage | 24 a trip from fights alone |

**What one evening action is worth today:**

| action | gives | note |
| --- | --- | --- |
| REST | half of everyone's HP, all mana and charges, +10 morale each | worth about 20 portions of meat when the party is hurt, nothing when it is fresh |
| HUNT | 2.9 portions | |
| FORAGE | 2.1 portions, 0.6 potion | |
| MEND | 6 HP to one | the same as 3 portions of meat |
| FISH | about 1.1 portions at a 60% catch rate | the only ingredient source |
| COOK (hot pot) | +5 morale each | cancels one MEAGER night, which saves 1 portion for a duo |
| TALK | 2 bond points | a twelfth of what the trip's fights give |

**Where a choice is free or dominated today:**
- **FILLING is always right.** Food never runs out, so MEAGER and BARE are never used.
- **Eating meat between fights is always right** and costs nothing.
- **REST beats MEND** whenever anyone is hurt, and on the way to the pass nobody is.
- **Pushing to the Lich beats grinding.** A push fights the same early fights and then more, and falling is free.
- **TALK is never worth a slot.**
- **Cooked meals never reach the Lich.** A meal's buff lasts 2 fights and can only be eaten at a road camp; the throne is fight 8.
- **Buying rations beats hunting** once the counter is open.

**Where there is a real trade today:**
- Which campsite to stop at (river, hilltop, ruins) against the light. This works.
- Which weapon: the bow is clearly the weakest against the Lich (arrows -2 on undead, a `[USER]` call).
- Whether to fetch a third party member before the Lich. It decides the fight.

## 3. The plan

### 3.1 Food: how tight

**Target.** Count what a trip wants (the pot at FILLING plus the meat it would take to heal every fight) and what it can count on (gate, loot, road finds). Aim for:

| the player... | has this share of what the trip wants |
| --- | --- |
| spends no evening on food | 90%: one MEAGER night, or arrives hurt |
| spends one action a night on food | 100 to 110%: about level |
| spends every evening on food | 125%: comfortable, but no rest, mend or talk |

**How to get there:**
1. **A cold meal on the maps.** Every `day_steps` (150) tiles on an explore map away from the village, the party eats the pot at the set ration. No camp screen, no evening actions. Hunger costs morale as on the road. A push to the Lich is then about 2 road nights plus 3 map days: 10 portions for the duo, 15 for three, 20 for four. The 3 map days are my estimate from the walking distances; the robot should measure them.
2. **Fight loot food to about 30%** (51 to about 15 portions a trip). Wolves drop 2, bandits 1 or 2.
3. **The first trip's 12 portions stay.** With a 10-portion trip the free kit is one spare day, which is what a bumper should be. The gate warning moves from 3 days to 4.
4. **Rations cost 10 gold, not 2.** A trip's gold then buys about 24 portions (one push's pot for a full party), or a tavern meal and less food. Today it buys 120.

**The budget, duo, one push (proposed numbers, road sim, 1,000 trips):**

| | portions |
| --- | --- |
| Wants: the pot, 5 or 6 days | 10 to 12 |
| Wants: meat to heal the seven fights (about 47 HP) | 24 |
| Has: gate 12, loot 15, road finds 4.5 | 31.5 |
| Ends with, no evening spent on food | 0.3, and a hungry night in 84% of trips |
| Ends with, no evening on food, MEAGER all the way | 3.8, a hungry night in 5% of trips, morale about 79 |
| Ends with, two actions a night on food | 12.6 |

**Empty hands.** Proposed dice (they should move from `TravelRules.ACTS` into `camp_actions.csv`):

| action | now | proposed | empty-handed (duo / with the Hunter) | when it lands |
| --- | --- | --- | --- | --- |
| HUNT | DC 12, 3 + margin/2 | DC 13, 4 + margin/3 | 50% / 35% | 4 to 7 portions: two days for the duo |
| FORAGE | DC 11, 1 + margin/2, a potion | DC 9, 1 portion and 1 herb, no margin | 30% | small and steady; the herb source |
| FISH | minigame, river camps | unchanged | by skill | 1.8 portions, sometimes an ingredient |

Hunting is the gamble, foraging the safe small pick, fishing the skill pick. So it is not a slot machine: after two empty tries in a row on a trip, the next hunt or forage rolls at +3 (unseen). Three empty in a row drops from 1 in 8 to about 1 in 11.

### 3.2 The evening: no pick always right

| action | proposed | best when |
| --- | --- | --- |
| HUNT | 50% for 4 to 7 portions | food is short and there is a night to spare |
| FORAGE | 70% for 1 portion and 1 herb | a town step needs herbs, or one portion closes the gap |
| FISH | unchanged | at a river, for ingredients |
| COOK | unchanged (+5 morale each) | with MEAGER: turns one action into half a pot saved, more for a big party |
| MEND | 8 HP to one (was 6) | one member is hurt |
| REST | a quarter of everyone's HP (was half), all mana and charges, +5 morale (was 10) | after a road fight, or between two places |
| TALK | 4 bond points (was 2), and fights give at most 2 (was 3) | nothing is urgent: a talk is then a quarter of a trip's bond gain |

Every action lands at about 2.5 to 4 portions' worth in its best case. REST stops being worth seven of anything else.

**Cooked meals should last the trip.** `meal_fights` 2 to 8, so a stew eaten at the last camp is still on at the throne. That gives the kitchen a job against the wall.

### 3.3 The four kinds of run

Proposed pay per trip, duo:

| run | fights | food | pays | cost and risk |
| --- | --- | --- | --- | --- |
| **Push to the wall** (pass, den, crypt, throne) | 8 | 5 days | a try at the Lich; 445 XP (2.2 levels at 200 a level); metal 6, wood 3, gold 48; his card on a fall | the whole healing budget; a fall costs each member 25 morale |
| **Grind** (pass and den, home before the crypt) | 4 | 3 days | 240 XP (1.2 levels); +4 morale and the bed | none to speak of; about half the play time |
| **Gather or recruit** (forest roads, farmland) | 1 to 3 | 2 or 3 days | a recruit the first time (Bushberry, Amber); herbs, ingredients, wood from camp actions and finds | an elite on the forest road |
| **Town** (no trip of its own) | 0 | 0 | a step paid at home, done after the next trip | the materials |

Falling is free (`[USER]` 2026-10-28), so a push can't cost items or levels. It should cost **morale**: with the bed at +10 (was 20) and a won fight at +1 (was 2), a failed push ends about 8 down and a safe trip about 14 up. Two failed pushes in a row from 70 put the party under 60, Shaken, which is -1 damage: one weapon upgrade lost. That is the reason to take a breather run. A tavern meal buys it back with gold.

**What each permanent gain is worth against the Lich** (measured: level 5, arriving at 60% HP, today's Lich, average of sword, daggers and bow, 40 fights a cell):

| gain | Lich win chance |
| --- | --- |
| Nothing | 14% |
| Arriving at 80% HP, not 60% | 49% |
| +3 levels (level 8) | 34% |
| +5 levels (level 10) | 70% |
| Weapon +1 / +2 / +3 | 39% / 62% / 73% |
| A third member at the same level (Bushberry / Hunter / a mage) | 93% / 99% / 100% |

So one weapon upgrade is worth about three levels, or 20 points of arrival HP. A third member is worth the wall. **Rule for the plan: no single permanent gain should be worth more than about 25 points.** For the third member that means the Lich grows with the party (below).

**The target curve.** Measured with 200 XP a level, the Lich at 52 HP, fight food at 30%, five days of food, and a player who eats meat down to a 4-portion reserve:

| | try 1 | try 2 | try 3 | try 4 | try 5 |
| --- | --- | --- | --- | --- | --- |
| Brandon's target | 5 to 10% | 25 to 50% | rising | | |
| Levels alone, average | 5% | 31% | 48% | 91% | 100% |
| sword | 4% | 56% | 67% | 100% | |
| daggers | 12% | 32% | 70% | 100% | |
| bow | 0% | 4% | 8% | 73% | 100% |
| The same, never eating between fights | 0% | 3% | 21% | 75% | 97% |
| With weapon +1 from the start | 24% | 61% | 69% | | |
| With Bushberry, two levels behind | 66% | 88% | | | |
| With Bushberry, and the Lich at 80 HP | 5% | 26% | 62% | 99% | |

Read as trips for a player who mixes sensibly:

| trip | what they do | chance the Lich falls this trip |
| --- | --- | --- |
| 1 | push; learn his card | 5 to 10% |
| 2 | push again at level 5 | 25 to 35% |
| 3 | forest roads: Bushberry, herbs, wood; the forge is done, pay the whetstone | no try |
| 4 | push with three and a stew | 45 to 60% |
| 5 | grind or gather; pay weapon +1 | no try |
| 6 | push with weapon +1 | 70 to 85% |

A pure pusher gets there in 4 or 5 tries on levels alone. A mixer gets there in about the same number of trips with fewer falls. Most players should be past the wall in 4 to 7 trips, which at 30 to 45 minutes a trip is 3 to 5 hours.

### 3.4 Guard rails

**Against a death spiral** (hunger, then weak fights, then more hunger):
1. **Hunger never kills.** It costs morale only, and everyone Spent is carried home with the loot. This is built and stays.
2. **A floor at home.** After a night in the bed nobody starts a trip under 40 morale. The worst a trip can start at is Shaken (-1 damage), never Low or Broken.
3. **The first-trip kit and the free first nights stay** (12 portions, the first night of the first three trips free).
4. **The empty-hands breaker** in 3.1.
5. **The pot's order stays:** companions go hungry before the hero, so the hero can always fight.

**Against impossible:**
1. **A ceiling check on every wall:** a fresh, full-HP party at the level a first push reaches must win at least 1 time in 10 with every weapon but the book. With the proposed Lich the bow is under that (0% on try 1, 4% on try 2). See the decisions.
2. **Every fall pays:** XP kept, his card learned, and the homecoming page says what got closer.
3. **No road fight should be lost more than 1 time in 10.** Today none is over 3%.

### 3.5 The data changes, in the order to try them

Each step should be measured before the next (`economy_sim.gd`, then the robot). "Measured" means this pass's sim; "modelled" means arithmetic from measured rates.

| # | file, key | from | to | effect |
| --- | --- | --- | --- | --- |
| 1 | `levels.csv` `xp_per_level` | 100 | 200 | levels a trip 4.5 to 2.2. With steps 2 and 3, try 2 falls from about 90% to 31% (measured) |
| 2 | `data/classes/lich.tres` HP | 42 | 52 | with step 1, try 1 for a player who eats falls from about 40% to 5% (measured) |
| 3 | `loot` food on the groups in `snow_pass.json`, `wolf_den.json`, `crypt.json`; road fights in `encounters.csv` | 51 a trip | about 15 | food at the throne 53 to about 5; healing becomes a budget (measured) |
| 4 | new rule: a cold meal every `morale.csv` `day_steps` tiles on explore maps | none | 150 tiles | a push eats 10 portions, not 4 (modelled; needs code) |
| 5 | hunt and forage dice into `camp_actions.csv` (new columns `dc`, `food`, `margin_div`, `gives`) | hunt 12 / 3 / 2; forage 11 / 1 / 2 / potion | hunt 13 / 4 / 3; forage 9 / 1 / none / herb | hunt 50% empty, 5.2 when it lands; forage 30% empty; herbs get a source (measured for hunt; needs code) |
| 6 | `camp.csv` `mend_hp`, `talk_points`; `levels.csv` `camp_hp_pct`; `morale.csv` `camp`; `bonds.csv` `fight_max` | 6, 2, 50, 10, 3 | 8, 4, 25, 5, 2 | no evening action worth more than about 4 portions (modelled) |
| 7 | `levels.csv` `meal_fights` | 2 | 8 | a meal reaches the throne; the kitchen is worth about one weapon upgrade for that fight (modelled) |
| 8 | `morale.csv` `win`, `bed`; new `home_floor` | 2, 20, none | 1, 10, 40 | a failed push nets about -8, a safe trip +14; no trip starts under 40 (modelled; the floor needs code) |
| 9 | `items.csv` and `tavern_menu.csv` price: ration, sack, jerky | 2, 4, 7 | 10, 24, 60 | a trip's gold buys 24 portions, not 120 (modelled) |
| 10 | `levels.csv` `gate_warn_days` | 3 | 4 | the gate warns before a push that can't be fed |
| 11 | new `combat.csv` key: a boss's HP per party member past two | none | +50% | with Bushberry the curve is 5 / 26 / 62 / 99%, not 66 / 88% (measured at 80 HP; needs code) |
| 12 | repeatable finds on the side maps, and ingredients from a hunt that lands well | none | wood and herbs on forest roads, ingredients on farmland | gather runs pay something no push can (needs the map builder; `forest_roads.json` is Brandon's file) |

Steps 1 to 3 are data only and can be tried in an afternoon. Steps 4, 5, 8 and 11 need small rules code. Step 12 needs maps.

## 4. Decisions for Brandon

1. **Should days pass on the explore maps?** Recommended: yes, as a cold meal every 150 tiles with no camp, so "camp only on the world map" stands. Without it the food clock runs for 2 nights out of a 40-minute trip and food can't be tight. The other way is longer roads with more nights before each place.
2. **Is eating meat between fights meant to be free?** Recommended: keep eating as it is and cut what the fights drop to about 30%, so meat is a budget to spend. The other way is a cap, such as each member eating to heal once between fights.
3. **Who is the Lich built for: the hero and Doggo, or a party of three?** Recommended: the hero and Doggo, with his HP growing by half for each member past two. Today one recruit ends the fight (93 to 100% at level 5), and with this plan's other numbers a recruit still takes the first try from 5% to 66 to 90%.
4. **Slower levels?** Recommended: 200 XP a level. At 100 the second try is always near 90%, whatever else changes.
5. **What should a failed push cost, with falling free?** Recommended: morale (bed +10, wins +1, a floor of 40 at home), so two reckless pushes in a row cost a point of damage until the party rests or eats at the tavern. Leaving it free keeps pushing the best choice every time.
6. **The bow against the Lich.** Arrows do -2 to undead by your call, and under this plan the bow wins 0, 4 and 8% on its first three tries. Recommended: accept it as the "pokemon red" matchup, as with the book, and say so on the weapon rack. The other way is to drop the arrow penalty to -1.
7. **Should levels alone be enough to pass the first wall?** Recommended: yes for the Lich (a stubborn player gets through in 4 or 5 tries, a player who mixes in 4 to 7 trips with fewer falls), and from the next wall on, no: tune it so levels top out near 50% and upgrades or recruits are needed. If you want that at the Lich too, the measured setting is 200 XP a level and the Lich at 63 HP: on levels alone the sword and daggers win 0 / 6 / 36 / 86% on tries 1 to 4, and the bow 0 / 0 / 0 / 50%.

## Appendix A: how this was measured

`game/tools/economy_sim.gd` (new, headless, never writes data):

```
godot --headless --audio-driver Dummy --path game -s res://tools/economy_sim.gd -- acts
godot --headless --audio-driver Dummy --path game -s res://tools/economy_sim.gd -- road trips=1000 party=duo camp=first evening=mixed
godot --headless --audio-driver Dummy --path game -s res://tools/economy_sim.gd -- chain runs=80 heal=meat
godot --headless --audio-driver Dummy --path game -s res://tools/economy_sim.gd -- levels fights=40 lvls=3,5,8,10
```

- `acts`: exact odds of hunt, forage and the fish roll by skill bonus.
- `road`: the campsites, nights, pot, evening actions, road events and morale from the real tables, with a seeded policy for the player.
- `chain`: the pass trip fight by fight through the real fight engine (built on `outing_sim_run.gd`), with food, loot, eating between fights, XP and levels kept across falls.
- `levels`: the Lich from a set arrival HP at each level, with weapon upgrades and extra party members.
- `key=value` overrides try a number for one run: `xp_per_level=200 boss_hp=125 loot_pct=30 hunt_dc=13`.

**What the sim does not know.** It plays the hero and Doggo with the AI on both sides; a person plays better. Samples are 40 to 80 a cell, so single numbers are good to about 7 points either way. Morale in the chain is rough (a fall is a flat -25). Road events always take the first option. The fishing minigame is taken at a 60% catch rate. The three map days are an estimate. Recruits were tried at the hero's level and two behind, not at level 1. The e2e robot was not run in this pass; it should confirm steps 1 to 3 before they ship.

## Appendix B: raw tables

**Hunt, forage and the fish roll by the party's best bonus (today's dice):**

| bonus | hunt win | hunt portions a try | forage win | forage portions a try | fish roll win | fish portions a try |
| --- | --- | --- | --- | --- | --- | --- |
| -2 | 35% | 1.50 | 40% | 1.00 | 40% | 1.40 |
| +0 | 45% | 2.15 | 50% | 1.50 | 50% | 2.00 |
| +2 | 55% | 2.90 | 60% | 2.10 | 60% | 2.70 |
| +3 | 60% | 3.30 | 65% | 2.45 | 65% | 3.10 |
| +5 | 70% | 4.20 | 75% | 3.20 | 75% | 3.95 |

**The road to the pass today (duo, 12 portions, FILLING, hunt and forage each night, 300 trips):**

| camp policy | nights | rough camps | eaten | found at camp | found on the road | empty tries | food on arrival | worst morale |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| every campsite | 2.99 | 0.01 | 6.0 | 16.6 | 4.5 | 43% | 27.1 | 72 |
| only river, hilltop, ruins | 2.00 | 0.02 | 4.0 | 11.8 | 4.5 | 43% | 24.2 | 72 |
| never stop | 2.00 | 2.00 | 4.0 | 6.1 | 4.3 | 42% | 18.5 | 62 |

**The Lich by level and arrival HP (today's Lich, resources full, 40 fights a cell):**

| | HP 40% | 60% | 80% | 100% |
| --- | --- | --- | --- | --- |
| sword, level 3 | 0% | 30% | 48% | 90% |
| sword, level 5 | 0% | 30% | 75% | 95% |
| sword, level 8 | 23% | 55% | 95% | 100% |
| sword, level 10 | 73% | 90% | 100% | 100% |
| daggers, level 3 | 3% | 0% | 35% | 75% |
| daggers, level 5 | 0% | 8% | 63% | 85% |
| daggers, level 8 | 3% | 38% | 75% | 98% |
| daggers, level 10 | 25% | 73% | 95% | 100% |
| bow, level 3 | 0% | 0% | 5% | 10% |
| bow, level 5 | 0% | 3% | 10% | 38% |
| bow, level 8 | 0% | 8% | 28% | 60% |
| bow, level 10 | 8% | 48% | 80% | 100% |

Even levels roll no stats (`rolls_even` 0), so levels 3 and 4, and 5 and 6, fight the same.

**Level 5, weapon upgrades and a third member (sword / daggers / bow):**

| | HP 40% | 60% | 80% | 100% |
| --- | --- | --- | --- | --- |
| weapon +1 | 8 / 20 / 0% | 50 / 38 / 28% | 90 / 90 / 50% | 100 / 95 / 68% |
| weapon +2 | 23 / 40 / 5% | 78 / 73 / 35% | 95 / 100 / 65% | 100 / 100 / 85% |
| weapon +3 | 48 / 55 / 23% | 88 / 78 / 53% | 100 / 100 / 78% | 100 / 100 / 98% |
| with the Hunter | 55 / 45 / 43% | 100 / 100 / 98% | 100% | 100% |
| with Bushberry | 63 / 58 / 10% | 100 / 100 / 78% | 100 / 100 / 95% | 100% |
| with the fire mage | 100 / 100 / 98% | 100% | 100% | 100% |

**Eating between fights, today's data (first try, sword / daggers / bow, 60 trips each):**

| fight food | meat heals | first try | HP on arrival | food left |
| --- | --- | --- | --- | --- |
| 100% | 2 | 92 / 78 / 42% | 100% | 35 |
| 50% | 2 | 92 / 78 / 42% | 100% | 14 |
| 30% | 2 | 88 / 78 / 42% | 97% | 7 |
| 20% | 2 | 73 / 68 / 42% | 90% | 5 |
| 30% | 1 | 63 / 60 / 40% | 83% | 4.5 |
| 20% | 1 | 50 / 50 / 35% | 75% | 4 |

Cutting food alone does not reach the target: at level 5 and near-full HP today's Lich is a 40 to 90% fight. That is why the plan moves levels and the Lich as well.

**XP a level against the Lich's HP (eats meat, fight food 30%, five days of food, 50 trips a weapon; sword then daggers, tries 1 to 5; the bow runs behind both in every row):**

| XP a level | Lich HP | sword | daggers |
| --- | --- | --- | --- |
| 150 | 42 | 44 / 86 / 100% | 50 / 68 / 100% |
| 150 | 52 | 4 / 58 / 100% | 10 / 31 / 100% |
| 150 | 63 | 0 / 18 / 95 / 100% | 4 / 6 / 96 / 100% |
| 200 | 42 | 36 / 84 / 100% | 40 / 73 / 88 / 100% |
| **200** | **52** | **4 / 56 / 67 / 100%** | **12 / 32 / 70 / 100%** |
| 200 | 63 | 0 / 10 / 44 / 96 / 100% | 0 / 2 / 29 / 77 / 100% |
| 300 | 42 | 4 / 40 / 86 / 100% | 4 / 60 / 63 / 43 / 100% |
| 300 | 52 | 0 / 2 / 55 / 36 / 86% | 0 / 22 / 33 / 35 / 82% |
| 300 | 63 | 0 / 0 / 20 / 10 / 39% | 0 / 0 / 10 / 7 / 29% |

At 300 XP a level the later tries wobble (a try can be worse than the one before) because fewer parties are left and the level steps are coarse; 200 is smoother.

**The proposed road (duo, 12 portions, 3 road nights and 3 map days, fight food 15, healing wants 24, proposed dice, 1,000 trips):**

| evenings | ration | eaten | found at camp | empty tries | food left | trips with a hungry night | worst morale |
| --- | --- | --- | --- | --- | --- | --- | --- |
| hunt, rest, forage | FILLING | 11.9 | 17.0 | 35% | 12.6 | 2% | 99 |
| rest, cook, talk | FILLING | 10.5 | 2.2 | 26% | 0.3 | 84% | 87 |
| rest, cook, talk | MEAGER | 5.9 | 2.2 | 26% | 3.8 | 5% | 79 |

(The 2.2 found with no food actions is the old ruins' free forage. The forage here still used the margin; with no margin it lands 70% for 1 portion.)
