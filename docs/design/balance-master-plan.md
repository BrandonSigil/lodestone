# Balance master plan: making every run hard fought

Balance officer, 2026-11-16. Brandon's ask: "run some hard math and logistics on how we can make every run feel hard fought ... Rations/food should feel tight, having to fish or hunt for food should feel hard fought, you could walk away empty handed. I dont want the game to feel impossible ... small improvements over the course of the game which ultimately get you past the wall."

This is a plan with measurements. Nothing in `game/data/` changed. Every number proposed here is `[AI]` until Brandon picks it. The measuring tool is new: `game/tools/economy_sim.gd` (usage at the end).

**Updated the same day with Brandon's call on party size** (`[USER]` 2026-11-16 in `docs/decisions.md`): "balance the three starting directions N,W,E to the idea that the party will probably be 2-3 party members. Then the Lich King fight is expected to be a first skill check where you really need to come with a full party". The world does not scale to the party. Section 3.3, steps 2 and 11, and decisions 3, 6 and 7 now follow it; the earlier Lich for two (52 HP) is kept in appendix B as superseded.

**Landed the same day, after his "Yes to all this" on the three calls in decision 3:** the Lich is 158 HP (`data/classes/lich.tres`, was 42) and the ogre is HP 10, damage 4, armor 0 (`data/classes/ogre.tres`, was 24, 5, 1; as the forest's elite that is 15 HP, 5 damage, 1 armor). Nothing else in `game/data/` changed. Measured on the written data, 30 runs a weapon, eating meat:

| on today's other numbers (100 XP a level, full fight food) | try 1 | try 2 | try 3 | try 4 |
| --- | --- | --- | --- | --- |
| the ogre, hero and Doggo: sword / daggers / bow | 60 / 53 / 100% | 100% | | |
| the ogre, with Amber | 100%, losing 30% of the party's HP | | | |
| the Lich, all four: sword / daggers / bow | 80 / 67 / 40% | 100% | | |
| the Lich, hero, Doggo and Bushberry | 0% | 87 / 87 / 33% | 100% | |
| the Lich, hero, Doggo and Amber | 0% | 97 / 77 / 53% | 100% | |
| the Lich, hero and Doggo | 0% | 0% | 53 / 3 / 0% | 100% |

So the wall already wanted a party, but four still won the first try 62% of the time, because levels came at 100 XP and meat was a free heal.

**Then decisions 2 and 4, also the same day ("Yes, land both"):** a level is 200 XP (`levels.csv` `xp_per_level`, was 100), and the fights drop about 30% of the food they did: the pass, den and crypt groups 14 portions a trip (was 45), the farmland's fight 1 (was 3), the road's fights 1 each (was 3 or 4). `forest_roads.json` is Brandon's own map file and was not touched, so the west's two fights still drop 3 and 4. Measured on the written data, eating meat:

| the game as it now stands | try 1 | try 2 | try 3 | try 4 | try 5 |
| --- | --- | --- | --- | --- | --- |
| Brandon's target for the Lich | 5 to 10% | 25 to 50% | rising | | |
| **the Lich, all four, average (60 runs a weapon)** | **11%** | **53%** | **100%** | | |
| sword / daggers / bow | 7 / 27 / 0% | 71 / 61 / 27% | 100% | | |
| the Lich, hero, Doggo and Amber, average | 0% | 4% | 24% | 78% | 100% |
| the Lich, hero, Doggo and Bushberry, average | 0% | 0% | 0% | 66% | 98% |
| the Lich, hero and Doggo | 0% | 0% | 0% | 0% | 0% |
| the west's ogre, hero and Doggo: sword / daggers / bow | 60 / 53 / 100% | 42 / 57% | 71 / 67% | | |

With two members the north's four fights cost 14, 26, 13 and 10% of the party's HP and are won every time, the east's one fight costs 22%, and the west's cost 10, 29 and 40%. Four members reach the Lich at full HP with 13.6 portions of fight meat left: the fights before him are sized for two, so for four they cost almost nothing (0 to 5% each). The daggers' first try (27% over 60 runs, 13% over the earlier 30) is the one number above the band.

## One-page summary

**What is true today (measured):**

1. **Food is never short.** A trip to the Lich eats 4 to 6 portions (2 or 3 nights on the road, 2 eaters). The party leaves with 12, finds 6 to 17 more hunting at camp, 4 on the road, and the eight fights drop 51. It reaches the throne with 53 portions. In 1,000 simulated trips there was not one hungry night.
2. **The food clock stops where the trip happens.** Days only pass on the world map. The pass, the wolf den and the crypt cost no food, and every camp comes before the first fight, so REST and MEND have nothing to fix.
3. **Meat is a free full heal.** One portion heals 2 HP, with no limit, between fights. A player who eats the fights' own meat reaches the Lich at 100% HP and wins the first try 39 to 94% of the time (target 5 to 10%). A player who never eats arrives at 58% and wins 10 to 13%. So "fights must cost" holds only for players who don't open the pack.
4. **Levels run away.** The seven fights before the throne pay 445 XP, and a level is a flat 100. One failed trip is +4.5 levels. The second try is at level 10 and wins 85 to 94% (target 25 to 50%). Nothing else is needed, so upgrades, the kitchen and side trips have no job.
5. **A third party member is worth more than everything else together.** At level 5 and 60% HP the duo beats the Lich 14% of the time; one weapon upgrade makes that 39%; a third member makes it 93 to 100%.
6. **Hunting is already a coin flip** (45% empty-handed for hero and Doggo), which is about right. It just doesn't matter, because food isn't scarce.
7. **Town upgrades arrive after the wall has fallen, or never.** Metal is plentiful. Herbs have one source in the whole region (2, once ever), so the book ladder and the second kitchen step can't be finished.
8. **The first maps and the wall are the wrong way round for Brandon's party call.** All four members beat today's Lich every time. The west's ogre, who guards the first recruit, can't be beaten by two with a sword or daggers (0% on the first try; 93% with the bow, which kites him).

**The plan in five moves (all `[AI]` proposals):**

1. **Run the food clock on the maps too:** a cold meal every 150 tiles walked (no camp, so "camp only on the world map" stands). A push to the Lich becomes about 5 days of food, not 2.
2. **Make meat the healing budget:** cut the fights' food to about 30%. The party then has to choose between a full pot, healing, and spending evenings hunting.
3. **Slow the levels and build the wall for a full party:** 200 XP a level and the Lich at about 158 HP (was 42), with the west's ogre softened so two can win the first recruit. Measured with all four and a player who eats sensibly: first try 5%, second 51%, third 100%. The hero and Doggo alone don't beat him in five tries.
4. **Make each evening action worth about the same,** so the right pick depends on the night: a riskier, bigger hunt; a safer forage that brings herbs; a smaller REST; a bigger MEND and TALK.
5. **Give the other run types their own pay:** a failed push costs morale that a safe trip earns back; side trips are the only source of herbs, ingredients and recruits; each town step is worth a named slice of the wall.

**The calls only Brandon can make are at the end.** Decisions 2, 3 and 4 are answered and landed; 1, 5, 6 and 7 are open.

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
| **Gather or recruit** (forest roads to the west, farmland to the east) | 1 to 3 | 2 or 3 days | a recruit the first time (Bushberry west, Amber east); 210 XP west, 60 XP east; herbs, ingredients, wood from camp actions and finds | the ogre on the forest road |
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

So one weapon upgrade is worth about three levels, or 20 points of arrival HP. A third member is worth the wall. **Rule for the plan: no single permanent gain should be worth more than about 25 points,** with one exception Brandon has made on purpose: party members. The first three directions are built for 2 or 3 members and the Lich for all four, so recruiting is the key to the wall, and levels, upgrades, meals and food decide how many tries it takes.

**The three first directions, for 2 or 3 members.** Today's data, a player who eats meat between fights, 30 runs a weapon. "Hardest fight" is the first try at the map's last fight, sword / daggers / bow:

| direction | party | hardest fight, first try | party HP lost in each fight |
| --- | --- | --- | --- |
| North: the pass and the den (4 fights, 240 XP) | hero, Doggo | 100 / 100 / 100% | 14, 26, 16, 3% |
| | with Bushberry | 100 / 100 / 100% | 3, 4, 2, 0% |
| | with Amber | 100 / 100 / 100% | 4, 12, 2, 0% |
| West: forest roads (3 fights, 210 XP, Bushberry) | hero, Doggo | 0 / 0 / 93% (the ogre) | 9, 27, 23% |
| | with Amber | 100 / 90 / 100% | 4, 21, 51% |
| East: farmland (1 fight, 60 XP, Amber) | hero, Doggo | 100 / 100 / 100% | 22% |
| | with Bushberry | 100 / 100 / 100% | 6% |

**Proposed band for these maps:** with two, an ordinary fight costs 15 to 25% of the party's HP and the map's hardest fight is won about half the time on the first try; with three, 5 to 15% and about 9 times in 10. North and east are inside the band today. The west is not. The ogre is an elite (150% HP, +1 damage, +1 armor) with Bushberry fighting beside him, and that stops two melee members cold, while a bow kites him for free. Measured on the ogre alone, two members, first try:

| the ogre as an elite | sword | daggers | bow | with Amber |
| --- | --- | --- | --- | --- |
| today: 36 HP, 6 damage, 2 armor | 0% | 0% | 93% | 97%, losing half the party's HP |
| 18 HP, 5 damage, 1 armor | 40% | 40% | 100% | 100% (measured at 24 and at 14 HP) |
| 14 HP, 5 damage, 1 armor | 60% | 57% | 100% | 100%, losing 29% |

So the proposal is about 15 HP, 5 damage and 1 armor in that fight (step 11). At 200 XP a level a duo that falls there comes back at 33 to 71%, so it stays a fight; at today's 100 XP a level the second try is 100%.

**The target curve: the Lich against a full party.** Measured with 200 XP a level, fight food at 30%, and a player who eats meat down to a 4-portion reserve. The hero has 270 XP from the west and the east; Bushberry joined at 210 XP and Amber at 270, each at level 1, earning the same XP from then on. 30 runs a weapon:

| | try 1 | try 2 | try 3 | try 4 | try 5 |
| --- | --- | --- | --- | --- | --- |
| Brandon's target | 5 to 10% | 25 to 50% | rising | | |
| **All four, the Lich at 158 HP, average** | **5%** | **51%** | **100%** | | |
| sword | 3% | 72% | 100% | | |
| daggers | 13% | 62% | 100% | | |
| bow | 0% | 20% | 100% | | |
| All four, the Lich at 147 HP, average | 17% | 70% | 100% | | |
| All four, the Lich at 168 HP, average | 1% | 36% | 98% | 100% | |
| All four, 126 HP and +1 armor, average | 3% | 67% | 100% | | |
| Hero and Doggo only, 158 HP | 0% | 0% | 0% | 0% | 0% |
| Hero, Doggo and Bushberry, 158 HP, average | 0% | 0% | 0% | 66% | 98% |
| Hero, Doggo and Amber, 158 HP, average | 0% | 4% | 24% | 78% | 100% |
| All four against today's Lich (42 HP), today's numbers | 100% | | | | |

The wall does what Brandon asked: two can't pass it, three need four tries, four need two or three. It rises fast because every fall pays all four members 445 XP, 2.2 levels each. More Lich HP doesn't stretch that (168 HP gives 1 / 36 / 98%); slower levels would. At today's 100 XP a level there is no curve at all: four members go from 0% to 100% in one try (measured at 210 and 252 HP).

The full-party push is also the hungriest trip. With the proposed hunt and forage dice and a 12-portion pack, four eaters go through 23 portions. Hunting every evening leaves 4.7, with the pack empty at some point in 31% of trips; spending no evening on food means 2.5 hungry nights and morale down to 34. (The sim's four include the Hunter, who hunts at +5; with Bushberry and Amber it will be tighter.) So the push with four wants two sacks, which at the proposed prices is a whole trip's gold.

Read as trips for a player who mixes sensibly:

| trip | what they do | chance the Lich falls this trip |
| --- | --- | --- |
| 1 | west with two: the forest roads and Bushberry (about even odds at the softer ogre; a fall keeps the XP) | no try |
| 2 | east: the farmland, Amber and her bonfire | no try |
| 3 | north with all four: the pass, the den, the crypt, the throne; learn his card | about 5% |
| 4 | push again, two levels up | about 50% |
| 5 | push again, or a breather first for morale, a stew or weapon +1 | near certain |

A player who walks north first with two meets a wall they can't climb, keeps 445 XP a try, and should be told at home what the wall wants (the homecoming page; the words are Brandon's). Most players should be past the wall in 4 to 6 trips, which at 30 to 45 minutes a trip is 3 to 5 hours. Weapon upgrades and meals were not measured with four; they were worth 25 points each to two.

### 3.4 Guard rails

**Against a death spiral** (hunger, then weak fights, then more hunger):
1. **Hunger never kills.** It costs morale only, and everyone Spent is carried home with the loot. This is built and stays.
2. **A floor at home.** After a night in the bed nobody starts a trip under 40 morale. The worst a trip can start at is Shaken (-1 damage), never Low or Broken.
3. **The first-trip kit and the free first nights stay** (12 portions, the first night of the first three trips free).
4. **The empty-hands breaker** in 3.1.
5. **The pot's order stays:** companions go hungry before the hero, so the hero can always fight.

**Against impossible:**
1. **A ceiling check on every wall:** the party the wall is built for (for the Lich, all four), at the level a first push reaches, must win the second try at least 1 time in 4 with every weapon but the book. With the proposed Lich the bow is under that (0% on try 1, 20% on try 2). See the decisions.
2. **Every fall pays:** XP kept, his card learned, and the homecoming page says what got closer.
3. **No road fight should be lost more than 1 time in 10.** Today none is over 3%.
4. **The first directions never need a third member.** On the north, west and east maps two members must win every ordinary fight 9 times in 10 and the map's hardest fight about half the time. Today the west's ogre fails this.
5. **The wall says what it wants.** A party of two or three that falls to the Lich is told at home that he is a fight for a full party.

### 3.5 The data changes, in the order to try them

Each step should be measured before the next (`economy_sim.gd`, then the robot). "Measured" means this pass's sim; "modelled" means arithmetic from measured rates.

| # | file, key | from | to | effect |
| --- | --- | --- | --- | --- |
| 1 | `levels.csv` `xp_per_level` (**landed 2026-11-16**) | 100 | 200 | levels a trip 4.5 to 2.2. At 100 no Lich HP gives a curve: four members go from 0% to 100% in one try (measured) |
| 2 | `data/classes/lich.tres` HP (**landed 2026-11-16**) | 42 | 158 | with step 1 and all four members, tries 1 / 2 / 3 are 5 / 51 / 100%; the hero and Doggo alone, 0% in five tries (measured) |
| 3 | `loot` food on the groups in `snow_pass.json`, `wolf_den.json`, `crypt.json`, `farmland.json`; the road's fights in `encounters.csv` (**landed 2026-11-16**; `forest_roads.json` is Brandon's file and still drops 7) | 45 a pass trip | 14 | food at the throne 53 to about 5; healing becomes a budget (measured) |
| 4 | new rule: a cold meal every `morale.csv` `day_steps` tiles on explore maps | none | 150 tiles | a push eats 10 portions, not 4 (modelled; needs code) |
| 5 | hunt and forage dice into `camp_actions.csv` (new columns `dc`, `food`, `margin_div`, `gives`) | hunt 12 / 3 / 2; forage 11 / 1 / 2 / potion | hunt 13 / 4 / 3; forage 9 / 1 / none / herb | hunt 50% empty, 5.2 when it lands; forage 30% empty; herbs get a source (measured for hunt; needs code) |
| 6 | `camp.csv` `mend_hp`, `talk_points`; `levels.csv` `camp_hp_pct`; `morale.csv` `camp`; `bonds.csv` `fight_max` | 6, 2, 50, 10, 3 | 8, 4, 25, 5, 2 | no evening action worth more than about 4 portions (modelled) |
| 7 | `levels.csv` `meal_fights` | 2 | 8 | a meal reaches the throne; the kitchen is worth about one weapon upgrade for that fight (modelled) |
| 8 | `morale.csv` `win`, `bed`; new `home_floor` | 2, 20, none | 1, 10, 40 | a failed push nets about -8, a safe trip +14; no trip starts under 40 (modelled; the floor needs code) |
| 9 | `items.csv` and `tavern_menu.csv` price: ration, sack, jerky | 2, 4, 7 | 10, 24, 60 | a trip's gold buys 24 portions, not 120 (modelled) |
| 10 | `levels.csv` `gate_warn_days` | 3 | 4 | the gate warns before a push that can't be fed |
| 11 | `data/classes/ogre.tres` HP, damage, armor (**landed 2026-11-16**; the ogre's only other uses are two test groups on the launch menu) | 24, 5, 1 | 10, 4, 0 | as an elite he is 15 HP, 5 damage, 1 armor: two members win the first recruit 53 to 60% of the time on the first try with a sword or daggers, not 0%; with Amber 100% (measured on the written data) |
| 12 | repeatable finds on the side maps, and ingredients from a hunt that lands well | none | wood and herbs on forest roads, ingredients on farmland | gather runs pay something no push can (needs the map builder; `forest_roads.json` is Brandon's file) |

Steps 1, 2, 3 and 11 are landed. Steps 4, 5 and 8 need small rules code. Step 12 needs maps. The rest are data and wait on decisions 1, 5, 6 and 7.

## 4. Decisions for Brandon

1. **Should days pass on the explore maps?** Recommended: yes, as a cold meal every 150 tiles with no camp, so "camp only on the world map" stands. Without it the food clock runs for 2 nights out of a 40-minute trip and food can't be tight. The other way is longer roads with more nights before each place.
2. **Is eating meat between fights meant to be free?** Answered 2026-11-16 ("Yes, land both"): eating stays as it is and the fights drop about 30% of what they did. Landed.
3. **Who is the Lich built for?** Answered 2026-11-16: the first three directions for 2 or 3 members, the Lich for a full party, and the world does not scale. The plan follows that (3.3). The three smaller calls it left are answered too ("Yes to all this", each as recommended):
   - **How the Lich gets bigger:** HP alone, to 158. Landed.
   - **The west's ogre:** softened to 15 HP, 5 damage and 1 armor as an elite. Landed.
   - **Fewer than four:** left as it is, and the homecoming page says what the wall wants. Built 2026-11-16 (backlog P34, `docs/systems/homecoming.md`); the line is Claude's flagged draft.
4. **Slower levels?** Answered 2026-11-16 ("Yes, land both"): 200 XP a level. Landed.
5. **What should a failed push cost, with falling free?** Recommended: morale (bed +10, wins +1, a floor of 40 at home), so two reckless pushes in a row cost a point of damage until the party rests or eats at the tavern. Leaving it free keeps pushing the best choice every time.
6. **The bow against the Lich.** Arrows do -2 to undead by your call, and under this plan a full party led by the bow wins 0% and 20% on its first two tries, then 100%. Recommended: accept it as the "pokemon red" matchup, as with the book, and say so on the weapon rack. The other way is to drop the arrow penalty to -1.
7. **Should levels alone be enough to pass the first wall?** Your party call changes the question: two members never pass on levels (0% in five tries), and four pass on levels by the third try. Recommended: keep that for the Lich, and from the next wall on tune it so a full party's levels top out near 50% and upgrades or meals are needed. If the third try at the Lich should not be certain, the lever is slower levels, not more HP (168 HP gives 1 / 36 / 98%); that needs its own measuring.

## Appendix A: how this was measured

`game/tools/economy_sim.gd` (new, headless, never writes data):

```
godot --headless --audio-driver Dummy --path game -s res://tools/economy_sim.gd -- acts
godot --headless --audio-driver Dummy --path game -s res://tools/economy_sim.gd -- road trips=1000 party=duo camp=first evening=mixed
godot --headless --audio-driver Dummy --path game -s res://tools/economy_sim.gd -- chain runs=80 heal=meat
godot --headless --audio-driver Dummy --path game -s res://tools/economy_sim.gd -- levels fights=40 lvls=3,5,8,10
godot --headless --audio-driver Dummy --path game -s res://tools/economy_sim.gd -- chain route=forest runs=30 attempts=3 heal=meat
godot --headless --audio-driver Dummy --path game -s res://tools/economy_sim.gd -- chain route=pass ally=bushberry,fire_mage ally_at=210,270 xp0=270 boss_hp=375 xp_per_level=200 loot_pct=30 heal=meat
```

- `acts`: exact odds of hunt, forage and the fish roll by skill bonus.
- `road`: the campsites, nights, pot, evening actions, road events and morale from the real tables, with a seeded policy for the player.
- `chain`: the pass trip fight by fight through the real fight engine (built on `outing_sim_run.gd`), with food, loot, eating between fights, XP and levels kept across falls. `route=north|forest|farm` runs the first maps instead; `ally=` adds party members, who start at level 1 at the hero XP in `ally_at=` and earn the same XP after; `xp0=` is the XP the hero sets out with. Elite groups get the elite numbers and the ogre fights with Bushberry beside him, as in the game.
- `levels`: the Lich from a set arrival HP at each level, with weapon upgrades and extra party members.
- The party update rebuilt how `chain` sets up a fight (elites now get the elite numbers, where the first pass gave every group the road's 70% HP). Today's baseline was rerun that way and matches section 1 within noise: never eating 15 / 9 / 5% then 96 / 85 / 87%; eating 94 / 74 / 43%; the lone wolf costs 2% HP, not 0, and pays 52 XP, so the seven fights pay 462.
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

**Superseded: the Lich for two (52 HP), measured before Brandon's party call** (200 XP a level, fight food 30%, five days of food, eats meat to a 4-portion reserve):

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

**The first maps on today's data (eats meat, 30 runs a weapon, three tries; sword / daggers / bow on the map's last fight):**

| map and party | try 1 | try 2 | try 3 | HP lost a fight, in order |
| --- | --- | --- | --- | --- |
| forest roads, hero and Doggo | 0 / 0 / 93% | 57 / 13 / 100% | 85 / 23% | 9, 27, 23% |
| forest roads, with Amber (joined at 60 XP) | 100 / 90 / 100% | - / 100% | | 4, 21, 51% |
| farmland, hero and Doggo | 100 / 100 / 100% | | | 22% |
| farmland, with Bushberry (joined at 210 XP) | 100 / 100 / 100% | | | 6% |
| pass and den, hero and Doggo | 100 / 100 / 100% | | | 14, 26, 16, 3% |
| pass and den, with Bushberry | 100 / 100 / 100% | | | 3, 4, 2, 0% |
| pass and den, with Amber | 100 / 100 / 100% | | | 4, 12, 2, 0% |

**The forest ogre by his elite numbers (hero and Doggo; sword / daggers, tries 1 to 3; the bow wins 93 to 100% on try 1 in every row):**

| elite HP, damage, armor | 100 XP a level | 200 XP a level |
| --- | --- | --- |
| 150%, +1, +1 (today: 36 HP, 6, 2) | 0 / 57 / 85% and 0 / 13 / 23% | not run |
| 125%, +1, +1 | 0 / 80 / 83% and 0 / 40 / 61% | 0 / 0 / 0% and 0 / 0 / 0% |
| 100%, +1, +1 | 0 / 93 / 100% and 0 / 73 / 63% | 0 / 0 / 0% and 0 / 0 / 0% |
| 125%, +0, +0 | 10 / 100% and 13 / 100% | 10 / 15 / 26% and 13 / 8 / 13% |
| 100%, +0, +0 (24 HP, 5, 1) | 17 / 100% and 23 / 100% | 17 / 24 / 32% and 23 / 22 / 28% |
| 75%, +0, +0 (18 HP, 5, 1) | 40 / 100% and 40 / 100% | 40 / 33 / 58% and 40 / 39 / 45% |
| 60%, +0, +0 (14 HP, 5, 1) | 60 / 100% and 57 / 100% | 60 / 42 / 71% and 57 / 62 / 60% |

With Amber every row run (all but the 75% one) is 97 to 100% on the first try. His extra damage and armor matter more than his HP.

**The Lich against all four (hero at 270 XP, Bushberry joined at 210, Amber at 270; eats meat; 30 runs a weapon; tries 1, 2, 3...):**

| XP a level, fight food | Lich HP | sword | daggers | bow |
| --- | --- | --- | --- | --- |
| 100, 100% (today) | 42 | 100% | 100% | 100% |
| 100, 100% | 84 | 100% | 100% | 100% |
| 100, 100% | 126 | 97 / 100% | 100% | 87 / 100% |
| 100, 100% | 168 | 63 / 100% | 47 / 100% | 20 / 100% |
| 100, 100% | 210 | 0 / 100% | 0 / 100% | 0 / 97 / 100% |
| 100, 100% | 252 | 0 / 100% | 0 / 97 / 100% | 0 / 90 / 100% |
| 200, 30% | 52 | 100% | 100% | 100% |
| 200, 30% | 84 | 100% | 100% | 93 / 100% |
| 200, 30% | 126 | 80 / 100% | 77 / 100% | 0 / 77 / 100% |
| 200, 30% | 147 | 17 / 84 / 100% | 33 / 85 / 100% | 0 / 40 / 100% |
| **200, 30%** | **158** | **3 / 72 / 100%** | **13 / 62 / 100%** | **0 / 20 / 100%** |
| 200, 30% | 168 | 0 / 50 / 100% | 3 / 48 / 100% | 0 / 10 / 93 / 100% |
| 200, 30% | 126, +1 armor | 0 / 87 / 100% | 10 / 81 / 100% | 0 / 33 / 100% |
| 200, 30% | 126, +1 damage | 77 / 100% | 73 / 100% | 0 / 67 / 100% |
| 200, 30% | 105, +2 damage | 93 / 100% | 93 / 100% | 7 / 96 / 100% |

His damage hardly matters to four; his HP and armor do. The rows up to 168 HP on today's numbers and up to 126 HP on the plan's were run with the hero at 240 XP and the allies joining at 180 and 240, 30 XP earlier than the rest.

**Smaller parties against the 158-HP Lich (200 XP a level, fight food 30%, tries 1 to 5):**

| party | sword | daggers | bow |
| --- | --- | --- | --- |
| hero and Doggo (from 0 XP) | 0 / 0 / 0 / 0 / 0% | 0 / 0 / 0 / 0 / 0% | 0 / 0 / 0 / 0 / 0% |
| with Bushberry (hero from 210 XP) | 0 / 0 / 0 / 83 / 100% | 0 / 0 / 0 / 87 / 100% | 0 / 0 / 0 / 27 / 95% |
| with Amber (hero from 60 XP) | 0 / 3 / 28 / 90 / 100% | 0 / 10 / 30 / 79 / 100% | 0 / 0 / 13 / 65 / 100% |

**Food on the push with the proposed dice (12 portions, 3 road nights and 3 map days, 1,000 trips):**

| eaters, evenings | eaten | found at camp | left | trips with an empty pack | hungry nights | worst morale |
| --- | --- | --- | --- | --- | --- | --- |
| two, hunting and foraging | 11.9 | 16.6 | 12.0 | 3% | 0.02 | 71 |
| two, no food actions | 10.4 | 2.0 | 0.3 | 86% | 0.90 | 58 |
| four, hunting and foraging | 23.0 | 20.0 | 4.7 | 31% | 0.33 | 67 |
| four, no food actions | 14.8 | 2.0 | 0.0 | 100% | 2.48 | 34 |

**Limits of the party measurements.** The AI plays both sides. Allies are built from their growth rolls with no ability picks. The trios set out with different XP because each recruit comes from a different map. The four in the food table are the sim's stand-ins (hero, Doggo, Hunter, wizard), not Bushberry and Amber. How long a fight with a 158-HP Lich lasts was not measured.
