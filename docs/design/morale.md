# Morale: per character, persistent, and no hunger

Game designer, 2026-10-31, from Brandon's answer on `design-goodboy` (the `[USER]` line is in `docs/decisions.md`). Everything below the quote is an `[AI]` proposal on his card `design-morale`; numbers are data in `game/data/`.

## What he asked for
Falls cost morale; a fall nobody picks up costs more. Low morale makes a character weaker, like the Banner Saga. Morale is persistent after a Lodestone run. There is no hunger: food is healing. Camping restores some morale, good food restores morale and health, and the village is the main way to recover it, by sleeping there or by leaving low-morale characters at home. It feeds the There and Back Again loop (you might beat the Lich with morale too low to finish).

## Today
- One group morale number (0 to 100, starts at 70) on the run. It only drops from events and choices: -5 hard pace, -2 a day for a gloomy character, -10 starving, -5 or -10 on some events.
- It changes d20 checks: -2 below 30, +1 above 75.
- Food drains every day by how many are in the party; starving costs morale and HP.

## The rules
**Scale:** each character has their own morale, 0 to 100, new characters start at 70, saved with them.

**What it does** (bands, by that character's morale):
| Morale | Band | In a fight | On a d20 check |
| --- | --- | --- | --- |
| 80 to 100 | Heartened | no change | +1 |
| 60 to 79 | Steady | no change | none |
| 40 to 59 | Shaken | -1 damage | none |
| 20 to 39 | Low | -1 damage, -1 move | -2 |
| 0 to 19 | Broken | -2 damage, -1 move, -1 armor, 1 less max mana or charges | -3 |

**What costs it:**
- A character goes down in a fight: -5.
- A downed character nobody helps up (they bleed out or are knocked out): another -10, -15 in all.
- Everyone goes down (a wipe): another -10 each.
- Event choices that already cost morale keep their numbers, now on the whole party.

**What gains it:**
- A won fight: +2 for each character who did not go down. An elite or boss win: +5.
- Camping at a camp spot: +10 for everyone, plus half HP and the resources of `outing-tuning.md`. A spot can be used once per outing. A gloomy character gains 2 less.
- Good food: a stew gives 6 HP and +10 morale, a roast 8 HP and +15, a feast 12 HP and +25 (and its fight buff). Cooked at the inn or bought.
- Sleeping in the village: a night in the bed (a day passes) gives everyone +20.
- Resting at home: a character left out of the party gains +10 each time the party goes on a run without them.
- A Lodestone return gives no morale by itself.

**Food becomes healing:** meat, ration, sack and jerky heal HP (meat 2, ration 4, sack 10, jerky 16, in data). No daily food need, no starving. Resting on the road no longer costs food.

## Good Boy and morale
Good Boy's morale half used to read "the group loses morale a little slower on the overworld". With per-character morale it becomes: while Doggo is in the party, every party member's morale losses are 20% smaller, rounded up (so -5 is -4, -10 is -8, -15 is -12). His +1 heal stays as chosen.

## Open
- Whether finishing the Lich needs enough morale, and what happens if it is too low: that is the There and Back Again loop, not designed yet.
- The Heartened bonus and the Broken penalties are my starting numbers. Tune with the playtester.
