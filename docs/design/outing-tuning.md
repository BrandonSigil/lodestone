# Making the road cost: a tuning plan

Game designer, 2026-10-30, from Brandon's answer on `playtest-scale-c-difficulty` (the `[USER]` line is in `docs/decisions.md`). Plain version: he wants the party to arrive at the Lich King worn down, half health, only one or two abilities left, and to lose most first tries. Everything below is `[AI]` and tunable in data.

## What carries between fights today
Read from `game/scripts/combat/combat_scene.gd` (`_on_finished`), `explore_scene.gd` (`_end_fight`) and `game.gd`.

| Thing | Today after a fight | Should it carry? |
| --- | --- | --- |
| HP | **Carries.** A piece keeps the HP it ended with. A downed piece gets back up at 1 HP after a win. | Yes, as it is. This is already the main cost. |
| Mana | **Resets to full** (`reset_resource`). | **Carry it.** This is the missing cost. |
| Charges (dog, rogue, archer) | **Reset to full.** | **Carry them.** |
| Rage | Resets to 0. | No. Rage is a heat-of-the-fight bar, not a spend. |
| Statuses (slow, spook, root) | Cleared. | Yes, cleared. |
| Belt and pack items | **Carry, and are used up.** | Yes. Potions and food are the way back. |
| Camp meal buff | Lasts a few fights. | Yes. |
| Downed state | Back up at 1 HP after a win. | Yes. |
| A wipe or Lodestone recall | Everyone wakes in the village at full HP, nothing lost (`[USER]` 2026-10-28). | Yes. Falling stays free; the cost is the walk back. |

So today the only cost on the road is HP and items. A mender or a few potions undo it, and mana and charges are full for every fight, which is why the Lich arrives against a fresh party.

## What should change
1. **Mana and charges stop refilling after each fight.** They carry to the next fight.
2. **Slow ways back:** a trickle of one point of mana or one charge for about every 10 steps walked on the overworld or an explore map; a **camp rest** (costs a ration, takes the camp's normal event) that restores all mana and charges and half HP; potions and meals keep restoring HP, and a new small item tier (a "tonic") restores some mana or one charge.
3. **Going home refills everything,** as today. That is the escape valve and the reason a second attempt is easier.

## How much each road fight should cost
Averages over the party across many runs, for the outing before the Lich (snow pass 1 fight, wolf den 2, crypt 1, four road fights in all):
- **HP:** about 12 to 15% of the party's total HP lost per road fight.
- **Mana and charges:** about 20 to 25% of the total spent per road fight.
- **After four fights with no rest:** arrive at about 50% HP (40 to 60%) and about 25% of mana and charges, so one or two abilities left.
- **A camp rest** puts the party back to roughly 75% HP and full resources, at the cost of a ration, so the player decides whether to rest before the throne room.

## The targets
Measured over the whole outing, not a fresh party:
| Attempt at the Lich | Target win rate |
| --- | --- |
| First (fresh run, no knowledge of him) | 5 to 10% |
| Second (after a fall: the party keeps levels, learns his card, goes in with what it saved) | 25 to 50% |
| Third and later | rising, about 50% by the fourth, up to about 80% with better gear and levels |

The old rule "each build wins about 15% against him with a full-strength party first" becomes a **ceiling check**: a full-strength party should still be able to win it, so the Lich is beatable, but the number that counts is the outing. No build should be locked out; each build's outing win rate should sit within a few points of the others, with the book allowed to be lower ("pokemon red", `design-boss-spread`).

## What to tune, in order
1. **Carry-over first.** Build it, measure what the party arrives with and the Lich win rate. Do not touch the Lich's HP yet.
2. **The cost of the road** next: number of foes in the explore groups, how much a rest and a potion give, how fast the trickle comes.
3. **Item supply** (how many potions and rations you find and can carry in the 4 x 3 pack).
4. **The Lich last,** only if the first attempt is outside 5 to 10% after the road is tuned.

Keep the usual guards: 120 fights a row, no stalls, a non-boss fight losing its first try in more than half the runs is a wall.

## Hand-offs
- **Systems developer:** build the carry-over and the three ways back (note `dev-outing-carry`).
- **Playtester:** measure arrival state and the targets (note `play-outing-targets`).

## First tuning of the road (systems developer, 2026-10-31)
The playtester measured the outing at Lich wins of 3% on the first try and 21% on the second, against 5 to 10% and 25 to 50%. The road is tuned first, as planned; the Lich is untouched.

**What matters on arrival.** `tools/outing_sim.gd -- -40 5` plays the Lich from set arrival states at level 5 (win % by HP, party first, 40 fights a cell). HP is nearly everything; mana and charges move the win rate by under 5 points for any weapon, because the sword's rage starts at 0 and the dog's and rogue's charges do little against him. Sword: 3% at 50% HP, 5% at 60%, 23% at 75%, 43% at full. Daggers: 5% at 40 to 50%, 15% at 60%, 25% at 75%, 58% at full. Bow: 8% at 50%, 23% at 60%, 33% at 75%, 53% at full. The outing robot arrives at about 30 to 40% HP, which is why the first try is near 3%. The trickle (`trickle_steps`), the camp and the tonic therefore tune how the road feels, not whether the Lich is beatable; they stay as built.

**Variants** (`tools/outing_sim.gd -- 120 8 foe_hp=N`, 120 outings a weapon, a fall sends the party home with its levels): the ordinary foes of the explore maps at a percent of their HP. The sim is harder than the robot on the road (it falls before the throne), so its foes at 70% play like the robot's at 100%, and its numbers are scaled to the robot's baseline (about half the sim's Lich win rate on both tries). Average of sword, daggers and bow:

| foes' HP (shipped, % of written) | arrival HP | Lich try 1 (robot-scaled) | try 2 (robot-scaled) |
| --- | --- | --- | --- |
| 100 (before) | 34% | 3% | 21% |
| 90 | 39% | 3% | 25% |
| 80 | 43% | 3 to 4% | 30% |
| 70 | 54% | 5 to 6% | 30% |

**Landed:** `explore_foe_hp_pct` 70 in `combat.csv`: the ordinary groups on the explore maps (not elites, not bosses) come with 70% of their HP (`ExploreRules.road_mods`). Predicted: arrival at about 50% HP, the first try at about 5 to 6%, the second at about 30%. That is a prediction from a sim that does not match the robot's flow, so it needs the playtester's robot at the next milestone to confirm. If the first try is still under 5%, 60 is the next step; if it is over 10%, 80.

## Balance run, 2026-11-02 (systems developer, polish day)
`tools/outing_sim.gd -- 60 8 foe_hp=70` (the shipped road: ordinary foes at 70%), the hero and Doggo from a new run to the Lich, a fall sends them home with their levels. New sim options (data stays untouched while trying): `boss_hp=N` (% of the Lich's HP), `boss_armor=N` (armor only), `boss_dmg=N`; `SIM_WEAPON=daggers` runs one weapon, `SIM_DEBUG=1` prints each throne fight's end. In zsh, pass a variant held in a variable as `${=v}`, or it arrives as one argument and only its first key is read.

| variant (Lich) | sword try 1 / 2 | daggers try 1 / 2 | bow try 1 / 2 |
| --- | --- | --- | --- |
| as shipped (38 HP, armor 2) | 2% / 97% | 92% / 100% | 88% / 100% |
| armor +1 | 87% / 75% | 78% / 38% | 67% / 95% |
| armor +2 | 45% / 97% | 47% / 97% | 40% / 53% |
| HP 110% | 2% / 92% | 77% / 71% | 82% / 91% |
| HP 125% | 0% / 82% | 63% / 41% | 75% / 87% |
| HP 135% | 0% / 77% | 57% / 38% | 67% / 80% |
| HP 150% | 0% / 43% | 42% / 37% | 63% / 73% |
| armor +1, HP 110% | 68% / 79% | 62% / 39% | 65% / 86% |
| armor +1, HP 125% | 50% / 37% | 45% / 36% | 45% / 73% |
| damage +1 | 2% / 88% | 93% / 75% | 72% / 94% |
| road foes 80% | 3% / 91% | 88% / 100% | 70% / 100% |
| road foes 80%, HP 125% | 0% / 53% | 55% / 41% | 58% / 88% |

What it shows: daggers and bow beat the Lich on the first try about 9 times in 10 (the target is 5 to 10%); the sword about 1 in 50. Arrival is about 43 to 63% HP at level 5, close to the plan. A level 5 daggers hero and Doggo deal about 20 damage a party turn, so his 38 HP is gone in 2 or 3 turns unless he drops the dog first: the fight is all or nothing. And the results are not smooth: one more armor (armor only) takes the sword from 2% to 87%, and later tries can fall as the first rises (daggers 92% / 100% to 78% / 38%). A one-point change flipping a fight that far means the AI chooses differently on the number (its targets or its stance), so the Lich's numbers can't be tuned to a target until that is understood. Nothing in game/data changed in this run.

**Why one armor flips the sword (found 2026-11-02, `SIM_TRACE=1` prints every AI turn's choice and score).** In the throne fight the Lich opens on Doggo and downs him. Each turn the sword hero then weighs STRIKE on the Lich against AID (stand Doggo back up). AID's score stays put (about 62); STRIKE's falls with the Lich's armor (about 68 at armor 2, 56 at armor 3). At armor 2 the hero strikes every turn, Doggo stays down, and the Lich wins the damage race (2%). At armor 3 the hero revives every turn instead; the Lich spends every turn re-downing Doggo with FIREBOLT while Doggo's bites and a fresh hero wear him down (87%). So the win rate hangs on a scoring threshold between two choices, not on how strong anyone is. The fix belongs in the party AI's AID scoring (how much a revive is worth against a boss's damage race), and the balance table should be rerun once that is settled; then the Lich's numbers can be tuned.

