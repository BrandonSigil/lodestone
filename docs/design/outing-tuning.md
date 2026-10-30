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
