# Foe roles and boss phases: build notes

Game designer, 2026-10-30, for the systems developer. Brandon picked these on card `design-foes-boss2` (see `docs/decisions.md`). Numbers are `[AI]` starting points; put them in `game/data/` (`classes/*.tres`, `abilities.csv`, `tags.csv`), not in scripts. All player-facing names are caveman placeholders in `game/text/placeholder.csv` (e.g. `FOE_MENDER`: "HEALER FOE. lorem ipsum"). No names, no story.

## Rules every foe here must keep
- Danger zone only: the new foes show where they could hit, nothing about who they will pick (c2).
- Sure hits, damage wobble, crits, armor, guard zones, bleed-out (c3, c8, c13).
- Foes are set by depth and never change.
- Each foe is a few HP and dies to a focused turn. Rolled as ordinary foes, not elites.

## Caster/support foes (all three, build in this order)
| id | HP | armor | move | ability | AI |
| --- | --- | --- | --- | --- | --- |
| `foe_mender` | 8 | 0 | 3 | `foe_mend`: heals a foe 3, range 2 | Stays 2+ tiles from heroes, moves to the most wounded foe in reach, heals at most once a phase. Never attacks unless cornered (basic hit 1). |
| `foe_hexer` | 8 | 0 | 3 | `foe_hex`: range 3, -1 damage (spooked) or -2 move (slow) for one phase | Targets the hero with the highest damage output. A new hex on a hexed hero does nothing, so it spreads them. |
| `foe_warder` | 9 | 1 | 3 | `foe_ward`: a foe within 3 gains +2 armor until the warder's next phase | Wards the foe closest to a hero. Does not stack on one foe. |

Reuse existing effects: heal is the player's `mend` shape, spook and slow are the existing statuses (`SPOOKED` is -1 damage per decisions, `slow` is -2 move), ward is `ward` pointed at a foe. Only the AI choices are new.

Risks to measure: a mender out of reach can stall a fight (use 120 fights a row; no stalls allowed), and warder armor walls (the Divinity lesson), so a ward must lapse and never stack.

## Chargers (both)
| id | HP | armor | move | rule |
| --- | --- | --- | --- | --- |
| `foe_rusher` | 10 | 0 | 5 | If it moved 3 or more tiles in a straight line this phase, its hit does +2. Goes for the nearest hero. |
| `foe_bull` | 14 | 1 | 5 | A rusher that also shoves its target 1 tile (the shove rules we have: a ledge is a fall, a wall blocks it). |

The straight-line rule needs a small "moved in a line" check in `CombatRules`. A guard zone or a snare answers a rusher, so check both in the sim.

## Boss phases by health (the second boss)
- Phase changes at 2/3 and 1/3 of max HP. The change takes effect at the start of the boss's next phase, so a burst turn does not skip one.
- Brandon did not pick what changes per phase (a new big move, an arena change). **Open, do not build the content yet.** Build the trigger as data: `phases` on the boss class, a list of HP fractions mapping to an ability set.
- Balance for a party of 3 to 4 at level 8 to 10, not the level 5 pair. Measure with the usual rules: each build wins about 15% or more, no stalls.

## Left open (not picked)
Guard foes, boss parts and objective, per-phase changes. Do not re-ask now.
