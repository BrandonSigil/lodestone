# Combat (graybox)

Code: `game/scripts/combat/`. Rules math is in `combat_rules.gd` (pure, no nodes). Numbers live in `docs/decisions.md` and in `game/data/`. The research behind this design is in `docs/research/tactical-combat.md`.

## Files
- `combat_rules.gd`: movement, reach, to-hit, damage, counters, pushes, statuses, the danger zone, and `resolve()`, which applies any skill or item and returns a list of events.
- `ability.gd`: one skill or item. Skills come from `data/abilities.csv`, fight items from `data/combat_items.csv`.
- `combat_unit.gd`: one piece. Stats are copied from its class and then scaled by the fight's difficulty dials.
- `enemy_ai.gd`: scores every reachable tile times every ready skill times every target, picks the best.
- `combat_sim.gd`: whole AI-vs-AI fights with no nodes, for the balance tool and tests.
- `battle.gd`: the fight controller (phases, action menu, targeting, forecast, enemy turn, animations). Both the trail fight and the sandbox use it.
- `combat_board.gd`: draws the iso board, pieces, highlights, danger zone and status tags.
- `combat_scene.gd`: a trail fight. Builds units from the run and the encounter, wraps a Battle in the frame HUD.

## How a turn works
- Fire Emblem phases: the player moves every piece, then every enemy moves.
- Click a piece to open its menu. Each piece gets **one move and one action, in either order** (so hit-and-run works). Blue tiles are where it can walk; red tiles are foes it can hit from where it stands.
- Menu: **HIT** (basic attack), the class's **skills**, **items** (spend the run's medicine or food), **GUARD** (+3 defense until your next turn), **UNDO MOVE** (before acting), **WAIT** (end this piece).
- Pick an action, then hover a lit target to see the forecast: hit chance, damage, HP before and after, every modifier ("ATK 4 HIGH +2 FLANK +2 vs DEF 11 COVER +2") and whether they will hit back. Click to commit.
- Clicking a red-lit foe straight from the menu is a shortcut for HIT (first click aims and shows the forecast, second click swings).
- Keys: Esc or right click = back / undo move, D = danger zone (every tile the enemy can hit next phase), Tab = next ready piece, E = end turn.

## Rules
- Attack: d20 + attack (+2 per level above the target up to 2 levels, +2 flank, -3 spooked, + skill bonus, + luck) vs defense (+ cover unless magic, +3 guard, +2 moon skin). Damage = unit damage + skill power + height levels, at least 1. Natural 20 doubles damage.
- Counterattack: a unit that is hit by a single-target attack and can reach the attacker with its own basic attack swings back once (no chain). Area skills never draw a counter. So melee hits melee at a price, and ranged picks at melee for free.
- Push: some skills shove the target 1 tile straight away from the attacker. Blocked by rock, a unit, the map edge or a step up of 2+: the target takes 2 bump damage instead. Pushed off a ledge: 2 damage per level dropped beyond the first.
- Statuses: GUARD and MOON SKIN last until the owner's next phase. STUCK (rooted) means 0 move and wears off at the end of the owner's next phase.
- Cooldowns: a skill with cooldown N can be used again after N of the owner's phases.
- Luck (anti-streak): each party miss in a row gives the next party roll +1, up to +3; a hit resets it. Shown in the forecast as LUCK. Enemies don't get it. The sandbox can switch it off.
- Stardrop's skittish check runs at the start of each player phase.
- Win: loot from `data/encounters.csv`, downed members stand back up with 1 HP. Lose: the Lodestone recalls the party. Items used in a fight are gone from the run.

## Skills (graybox set, `data/abilities.csv`)
| Class | Skills |
|---|---|
| Knight (Lead) | PUSH HIT: melee, +2 hit, -2 damage, push 1, cooldown 2 |
| Moon mage (Stardrop) | MOON BOOM: range 2-3, plus-shaped area, -1 damage, magic, cooldown 3 (hits friends too). MOON SKIN: ally within 3 gets +2 defense, cooldown 3 |
| Hunter | GOOD SHOT: weapon range, +3 hit, +1 damage, cooldown 2. TRAP: range 2-3, roots the target, cooldown 3 |
| Wizard | FIRE BOOM: like MOON BOOM at full damage. FIX: heal an ally within 2 for 4, cooldown 2 |
| Archer (Skeleton) | GOOD SHOT |
| Duo (Lewith & Flark) | PUSH HIT |
| Wolf | JUMP BITE: +2 hit, +1 damage, cooldown 3 |
| Bandit | DIRTY KICK: +1 hit, -1 damage, push 1, cooldown 3 |

Adding a skill: add a row to `data/abilities.csv` and its name key to `text/placeholder.csv`, then list its id in the class's `abilities` array in the inspector. Columns: `kind` attack/heal/buff, `target` enemy/ally/self/cell, `range_min/max` (0/0 = the unit's weapon range), `radius` (1 = plus shape), `power`, `hit`, `cooldown`, `push`, `status`, `status_turns`, `magic`.

## Combat sandbox
`scenes/combat_sandbox.tscn`. Open it and press F6, or press **F9 from any screen** while the game runs. Code in `game/scripts/sandbox/`.

- **EDIT** (F1 toggles): paint terrain (grass, forest, water, rock, road), RAISE / LOWER height, place party members (pick from the roster) and enemies (any class, including party classes for mirror matches). Left click and drag paints, right click removes a piece. The faint red tiles are the enemy deploy zone used by "extra enemies".
- **PLAY**: the real fight controller on your map. **RESTART (R)** rebuilds the fight from the setup. "new dice on restart" off = the same rolls every time (useful to replay one exact situation), on = fresh rolls.
- **Map**: name it and SAVE (writes `game/data/maps/<name>.json`, readable and hand-editable), LOAD from the list, RESIZE (5 to 16 a side), or GENERATE a random map from a seed. `default.json` loads first.
- **Difficulty dials** for each side: HP %, to-hit, defense, damage, move, plus "extra enemies" (copies of your enemies added in the deploy zone). Presets EASY / NORMAL / HARD / BRUTAL set the enemy dials. They scale four things separately (toughness, accuracy, damage, numbers) because those feel different in play.
- **Supplies and rules**: medicine and food for items, strangeness (board colors), counterattacks on/off, party luck on/off.
- **BALANCE**: RUN AI vs AI plays the setup N times with the AI on both sides and reports party win rate, rounds, party HP left and pieces downed per fight. The party AI is greedy and much weaker than a person, so read it as a floor. A good normal fight: party wins 60 to 85% (AI) and keeps 30 to 60% HP.
- Headless: `godot --headless --path game -s res://tools/balance_report.gd -- 100` prints every saved map at every preset.

## Balance baseline (2026-10-26, 60 AI fights each, counters and luck on)
| Map | EASY | NORMAL | HARD | BRUTAL |
|---|---|---|---|---|
| default (3 vs 4) | 100% win, 66% HP | 100%, 56% | 100%, 45% | 28%, 8% |
| ridge (3 vs 4) | 100%, 78% | 100%, 54% | 53%, 15% | 0% |
| river (4 vs 5) | 100%, 63% | 100%, 56% | 92%, 33% | 0% |

What the sim taught so far: the enemy AI used to walk up to a knight and then not swing because it feared the counter (fixed: damage taken now weighs about a third of damage dealt). High ground plus range is the strongest thing on the board: a hunter on a hill can take half a bandit's HP before it can answer. 3 vs 3 trail fights are easy one at a time; they get their bite from HP carrying over between fights.

## Not yet
Facing and back attacks, overwatch, charge-time spells with a countdown, fire on forest (Bushberry's "flammable"), objectives beyond "defeat all", enemy behaviour types (charger, ambusher, guard), per-character skills on top of class skills, the party AI using items in the sim.
