# Combat (graybox)

Code: `game/scripts/combat/`. Rules math is in `combat_rules.gd`; numbers live in `docs/decisions.md`.

- Map: 10 x 8 cells from a seed (`CombatGrid.generate`). Heights 0 to 3. Terrain grass, forest, shallow water, rock, road. Regenerates until both deploy zones connect for a jump-1 unit. Colors drift toward the alien palette as strangeness rises.
- Turns: Fire Emblem phases. Click a piece, click a blue tile to move (it hops), click a red-marked enemy to attack, or WAIT. Right-click undoes a move before acting. END TURN skips the rest.
- Attack: d20 + attack (+2 per level above the target, up to 2 levels, +2 flank, -3 spooked) vs defense + cover. Damage = class damage + height levels. Natural 20 doubles damage.
- Movement: Dijkstra over step cost, climb limited by Jump, pass through allies, never through enemies.
- Enemy AI (`enemy_ai.gd`): best expected damage it can reach, preferring kills and high ground; otherwise walk toward the nearest foe.
- Stardrop's skittish check runs at the start of each player phase.
- Win: loot from `data/encounters.csv`, downed members stand back up with 1 HP. Lose: the Lodestone recalls the party.
- Try it alone: open `scenes/combat.tscn` and press F6 for a debug fight.

Not yet: facing, abilities beyond one attack, counterattacks, per-character spells, minigame hooks.
