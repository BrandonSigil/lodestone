# Level-up: a bigger event

Game designer, 2026-10-31, from Brandon's Studio chat (the `[USER]` line is in `docs/decisions.md`). Everything under "Proposed numbers" is `[AI]` and tunable in data.

## What he asked for
- Leveling up pops up on the screen after the fight or event that earned it ends.
- It shows what the character just improved, and any choices for abilities.
- On **even** levels the player picks one: learn a new ability, or upgrade a known one. An upgrade makes a number bigger ("not 5 extra damage, 7 extra", or heals a little more).
- On **odd** levels the character still gets a stat bump.
- This replaces the older level pick (more health, attack or magic every 4 or 5 levels) and the skill rank every 4 levels.

## Proposed numbers
- **Odd levels (3, 5, 7...):** the stat bump. Roll the growth table twice instead of once so total growth stays near what the one-roll-every-level system gave. Tune in `data/levels.csv` (`growth_*`).
- **Even levels (2, 4, 6...):** one pick, from two kinds of card:
  - **Learn:** an ability from the class's kit (`data/kits.csv`) that the character does not know yet.
  - **Upgrade:** a known ability gets its next step from `data/ability_upgrades.csv`.
- **Starting kit:** a class starts knowing the first two slots of its kit; slots 3 and 4 are learned by pick. So the first two even levels can fill the kit, and every even level after that is an upgrade.
- **Steps:** up to 3 per ability, each is one number getting bigger (damage, healing, reach, area, duration, crit, cost, wait). An ability's three steps are in `ability_upgrades.csv` with a plain-English line per step. With 4 abilities that is 12 steps; at level 40 there are 20 even levels, so the table will need more steps (a 4th and 5th) if players should keep upgrading, or the pick can also offer a stat. Open, not needed yet.

## The data file
`game/data/ability_upgrades.csv`: `skill, step, effect, param, text`.
- `effect` is an ability field change in the form the old rank file used (`power:+1`, `range_max:+1`, `res_cost:-1`, `cooldown:-1`, `status_turns:+1`, `push:+1`, `radius:+1`, `crit:+10`, `bleed:+2`). `LevelRules.ranked` already applies it.
- `param` is for steps that change a number that is not an ability field: a trait or a combat number (`guard_armor:+1`, `poison_damage:+1`, `ward_hits:+1`...). The engine must read these where the trait is used. A step with only `param` set does nothing until that is wired.
- `text` is the plain-English line shown on the card. The screen computes the before and after numbers from `effect` or `param`.
- It covers every ability in the ten kits (`data/kits.csv`) and the dog's, with three steps each. `data/skill_ranks.csv` stays until the developer replaces its loading with this file.

## The level-up screen (build note for the systems developer)
Pops up after the fight or event ends, before control returns. Uses the class icons and the game's frames and panels.
1. **What improved:** for each character that leveled, the stat changes ("HP 18 to 20", "Damage 4 to 5") on odd levels.
2. **Even levels:** a row of choice cards.
   - A learn card: the ability icon, its name, its plain description (`DESC_<id>`), its cost and range.
   - An upgrade card: the ability icon, its name, the step text from `ability_upgrades.csv`, and the before and after number ("Damage 3-5 to 4-6").
3. One pick per level; more than one level at once (a big XP award) queues the picks in order. A "decide later" button leaves the pick waiting in the Lodestone menu, as ranks do today.
4. **Replaces:** the rank queue (`pending`) every 4 levels, `LevelRules.rank_up`, and the old health, attack or magic pick.
5. Needs the abilities' plain descriptions, which are now in `placeholder.csv`, and the class icons in `game/art/source/icons`.
