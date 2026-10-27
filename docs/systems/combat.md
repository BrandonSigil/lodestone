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
- Statuses: GUARD, MOON SKIN and STAR (guided, +2 to hit) last until the owner's next phase. STUCK (rooted) means 0 move and wears off at the end of the owner's next phase. NAP (sleep) skips the owner's next phase entirely and can't hit back; any damage (a hit, a bump or a fall) wakes it.
- Hexes are spells that roll to hit like an attack but deal no damage; on a hit they only add their status (MOON NAP).
- Cooldowns: a skill with cooldown N can be used again after N of the owner's phases.
- Luck (anti-streak): each party miss in a row gives the next party roll +1, up to +3; a hit resets it. Shown in the forecast as LUCK. Enemies don't get it. The sandbox can switch it off.
- Stardrop's skittish check runs at the start of each player phase.

## Terrain and height
- Heights run 0 to 8 in the editor and saved maps (the random generator stays at 0 to 4).
- Climbing: a piece steps up or down at most its Jump per tile. **STAIRS** add +2 to that when either end is a stair, so a Jump 1 knight can take a 3 level stair but not a 3 level cliff. Stairs are the chokepoints of tall maps.
- **Line of sight**: anything with reach over 1 (bows, spells, area skills) needs a clear line from one level above the attacker to the target's body. Cliffs, trees (0.8 of a level), boulders (1 level) and **RUIN** walls (2 levels) block it. Standing high lets you shoot over things, and someone standing back from a cliff edge can't be seen from below.
- High ground still gives +2 to hit and +1 damage per level (counting 2 levels), and +1 bow and spell range per level, now capped at +3.
- Pushes off tall ledges hurt more: 2 damage per level dropped beyond the first.
- Terrain types: grass, forest (cost 2, +2 cover), shallow water (cost 3, -2 defense), road, **stone** (paved ruin floor), **stairs**, rock and **ruin** (both impassable).
- The camera turns in quarter steps (**Q**, Shift+Q back, or the TURN button), like FFT. Saved maps remember the angle they open at.
- The look (graybox, all drawn in code): stone courses on cliff faces, moss hanging over grassy ledges, waterfalls wherever water meets a drop, stair treads, ruin walls with arches, contact shadows under tall neighbours, and a faint outline of any piece hidden behind a wall.
- Win: loot from `data/encounters.csv`, downed members stand back up with 1 HP. Lose: the Lodestone recalls the party. Items used in a fight are gone from the run.

## Character traits
Every roster character has one combat trait (`traits` in their `.tres`), shown when you hover the piece. Enemy classes can have them too (`traits` on the class). Rules live in `combat_rules.gd` as `TRAIT_*` constants; names and one-line descriptions are `TRAIT_<ID>` and `TRAIT_<ID>_DESC` in `placeholder.csv`.

| Character | Trait | Effect | Why |
|---|---|---|---|
| Lead (knight) | shield_wall | allies next to the Lead get +2 defense (shown as SHIELD in the forecast) | gives the frontliner a reason to anchor a formation |
| Stardrop (moon mage) | starlit | spells get +1 hit and +1 damage when cast from height 2 or more | ties the star reader to the new tall maps |
| Hunter | steady_aim | +2 to hit when attacking without having moved this turn | rewards picking a perch and holding it |
| Wizard | scholar | spells deal +1 damage, FIX heals +1 | the books are worth carrying |
| Bushberry | deep_roots | can't be pushed; regrows 1 HP at the start of each own phase | a bush holds a chokepoint |
| Bushberry | flammable (existing perk) | takes +2 damage from fire spells | the old perk now matters in fights |
| Skeleton Archer | bones | takes 2 less damage from non-magic hits at range 2+ (arrows go through) | a tank against archers, not against swords |
| Lewith & Flark | double_strike | the basic HIT rolls twice at -1 damage each (also when hitting back) | two bodies, two swings; strong against high defense rolls, weak against armor |
| Wolf (enemy) | pack | +1 damage on a target that another enemy is next to | wolves reward being surrounded |

## Spells and spell slots
Casters pick their spells. A class has a `spell_pool` and `spell_slots` (both 2 for now); a character can set default picks in `spells`, otherwise the first spells in the pool are used. Picking only one spell, or leaving a slot empty, is allowed. Spells are the magic rows of `data/abilities.csv`; the `element` column (fire, moon, frost) is what traits like flammable look at.

| Class | Pool (defaults first) |
|---|---|
| Moon mage (Stardrop) | MOON BOOM, MOON SKIN, MOON NAP (hex: sleep, range 2-3, cooldown 4), MOON WAVE (range 1-3, -3 damage, pushes 2, cooldown 3), STAR POINT (ally within 3 gets +2 to hit, cooldown 2) |
| Wizard | FIRE BOOM, FIX, FIRE ZAP (single target range 2-4, +2 damage, cooldown 2), COLD STUCK (range 2-3, -2 damage, roots, cooldown 3) |

Where to pick: in the sandbox, the right panel's SPELLS section has a picker per slot for each caster placed on the map. Picks are saved with the map. Trail fights use the character's default loadout for now; a picker in the village is a follow-up.

`godot --headless --path game -s res://tools/spell_report.gd -- 100` compares every loadout on the default map with AI fights.

## Skills (graybox set, `data/abilities.csv`)
| Class | Skills |
|---|---|
| Knight (Lead) | PUSH HIT: melee, +2 hit, -2 damage, push 1, cooldown 2 |
| Moon mage (Stardrop) | spells only (see above). MOON BOOM: range 2-3, plus-shaped area, -1 damage, magic, cooldown 3 (hits friends too). MOON SKIN: ally within 3 gets +2 defense, cooldown 3 |
| Hunter | GOOD SHOT: weapon range, +3 hit, +1 damage, cooldown 2. TRAP: range 2-3, roots the target, cooldown 3 |
| Wizard | spells only (see above). FIRE BOOM: like MOON BOOM at full damage. FIX: heal an ally within 2 for 4, cooldown 2 |
| Archer (Skeleton) | GOOD SHOT |
| Duo (Lewith & Flark) | PUSH HIT |
| Wolf | JUMP BITE: +2 hit, +1 damage, cooldown 3 |
| Bandit | DIRTY KICK: +1 hit, -1 damage, push 1, cooldown 3 |

Adding a skill: add a row to `data/abilities.csv` and its name key to `text/placeholder.csv`, then list its id in the class's `abilities` array in the inspector. A new spell instead goes into a caster class's `spell_pool`. Columns: `kind` attack/hex/heal/buff, `target` enemy/ally/self/cell, `range_min/max` (0/0 = the unit's weapon range), `radius` (1 = plus shape), `power`, `hit`, `cooldown`, `push`, `status`, `status_turns`, `magic`, `element`.

## Combat sandbox
`scenes/combat_sandbox.tscn`. Open it and press F6, or press **F9 from any screen** while the game runs. Code in `game/scripts/sandbox/`.

- **EDIT** (F1 toggles): paint terrain (grass, forest, water, rock, road, stone, stairs, ruin), RAISE / LOWER height (0 to 8), place party members (pick from the roster) and enemies (any class, including party classes for mirror matches). Left click and drag paints, right click removes a piece. The faint red tiles are the enemy deploy zone used by "extra enemies".
- **PLAY**: the real fight controller on your map. **RESTART (R)** rebuilds the fight from the setup. "new dice on restart" off = the same rolls every time (useful to replay one exact situation), on = fresh rolls.
- **Map**: name it and SAVE (writes `game/data/maps/<name>.json`, readable and hand-editable), LOAD from the list, RESIZE (5 to 16 a side), or GENERATE a random map from a seed. `default.json` loads first.
- **Difficulty dials** for each side: HP %, to-hit, defense, damage, move, plus "extra enemies" (copies of your enemies added in the deploy zone). Presets EASY / NORMAL / HARD / BRUTAL set the enemy dials. They scale four things separately (toughness, accuracy, damage, numbers) because those feel different in play.
- **Supplies and rules**: medicine and food for items, strangeness (board colors), counterattacks on/off, party luck on/off.
- **BALANCE**: RUN AI vs AI plays the setup N times with the AI on both sides and reports party win rate, rounds, party HP left and pieces downed per fight. The party AI is greedy and much weaker than a person, so read it as a floor. A good normal fight: party wins 60 to 85% (AI) and keeps 30 to 60% HP.
- Headless: `godot --headless --path game -s res://tools/balance_report.gd -- 100` prints every saved map at every preset.

## Balance baseline (2026-10-26, AI fights, counters and luck on)
| Map | EASY | NORMAL | HARD | BRUTAL |
|---|---|---|---|---|
| default (3 vs 4) | 100% win, 66% HP | 100%, 56% | 100%, 45% | 27%, 7% |
| ridge (3 vs 4) | 100%, 63% | 90%, 29% | 15%, 3% | 0% |
| river (4 vs 5) | 100%, 63% | 100%, 56% | 92%, 34% | 0% |
| temple (4 vs 5, tall) | 98%, 50% | 98%, 44% | 55%, 15% | not run |
| cliffs (3 vs 4, tall) | 95%, 42% | 85%, 32% | 40%, 8% | not run |

After traits and spell picks (same date, default loadouts, 100 fights):

| Map | EASY | NORMAL | HARD | BRUTAL |
|---|---|---|---|---|
| default | 100%, 80% | 100%, 64% | 100%, 55% | 27%, 8% |
| ridge | 100%, 62% | 92%, 42% | 29%, 6% | 0% |
| river | 100%, 65% | 99%, 56% | 93%, 36% | 3%, 1% |
| temple | 96%, 49% | 92%, 36% | 59%, 16% | 4%, 1% |
| cliffs | 98%, 34% | 81%, 21% | 37%, 4% | 1%, 0% |

Traits moved things a little both ways: the Lead's shield and the Hunter's steady aim help on open maps (ridge HP left 29% to 42%), wolf packs hurt on the tall maps. Spell report on the default map: any loadout with MOON BOOM ends fights in 2.7 rounds, because the enemies start bunched up; without it fights run about 4.3 rounds and every loadout wins 94 to 99%. FIRE BOOM + FIX is the strongest Wizard pair (85% HP left). Area spells are the thing to watch if fights feel too easy.

What the sim taught so far: with line of sight on, high ground decides fights. The first versions of temple and cliffs (all enemies on top of a 5 to 6 level fortress) were 0 to 2% wins at NORMAL, so both maps now give each side some high ground. Fights on tall maps run about 6 rounds instead of 3. Also: the enemy AI used to walk up to a knight and then not swing because it feared the counter (fixed: damage taken now weighs about a third of damage dealt). High ground plus range is the strongest thing on the board: a hunter on a hill can take half a bandit's HP before it can answer. 3 vs 3 trail fights are easy one at a time; they get their bite from HP carrying over between fights.

## Not yet
Seeing why a target can't be hit (a "no sight" hint on hover), deep water and swimming, climbing as an action, destructible ruins.
Facing and back attacks, overwatch, charge-time spells with a countdown, fire on forest, objectives beyond "defeat all", enemy behaviour types (charger, ambusher, guard), the party AI using items in the sim, a spell picker in the village, learning new spells during a run, traits for the deficiencies (gloomy, fear of rodents) in fights.

## Painted art
- `BattleArt` (`scripts/combat/battle_art.gd`) loads terrain textures and prop sprites from `art/source/battle/`, wired per terrain by `data/battle_art.csv` (top texture, side texture, props, prop height in tile widths, props per cell).
- Tops: a texture spans 2 x 2 cells, UV-mapped on the iso diamond so it reads the same in every camera turn. Sides: a texture spans 2 cells across and 4 height levels down (one stone row per level); shade faces draw at 72% of lit (the guide's 55 / 75).
- Props stand on the cell's top centre, back to front, with a soft contact shadow. A ruin's pillar sprite replaces the graybox wall.
- Strangeness multiplies the art toward the alien colours. Any missing file falls back to the graybox drawing, so art can arrive one terrain at a time.
- Tile sets: a subfolder of `art/source/battle/` (`snow/`, `dungeon/`...) holds a region's versions under the same file names. `BattleArt.use_set()` switches; each file missing from the set falls back to the base one. The board's `art_set` picks it; the sandbox has a "tile set" menu and saves it with the map. The trail doesn't pick a set yet.
- Art rules: `docs/art/battle-maps.md`.
