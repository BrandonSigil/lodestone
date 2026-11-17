# Road set pieces

A road set piece is a road fight on its own handmade map, built round one landmark that the road event talks about
([USER] 2026-11-17: "they should still be set pieces. Something should anchor each map that tie in with the story
scenario the player encounters"). The pitch and the nine approved scenes are in `docs/design/set-pieces.md`.

## How one fight is wired

1. **The road event** is a row in `game/data/travel_events.csv`. Its `road` column lists the places whose roads it
   can turn up on (`forest_roads|coastal_beach`); empty means every road. `TrailRules.pick_event` only rolls events
   whose `road` holds one end of the leg being walked.
2. **Each choice** ends in `combat:<encounter>` or in no fight. A choice that moves closer names the `_in` encounter;
   one that keeps its distance and is caught names the `_out` encounter.
3. **The encounter** is a row in `game/data/encounters.csv` with two extra columns: `map` (a file in
   `game/data/maps/`, without `.json`) and `start` (`in` or `out`). `units` is empty: the foes live on the map.
4. **The map** is an ordinary battle map (`SandboxSetup`), so F8 opens it in the map maker. On top of the usual
   fields:
   - `enemies[]` entries may carry `"hidden": true` (starts unseen, like an ambusher) and `"leader": true`.
   - `party[]` cells are where the party stands when it **walked in**.
   - `piece.out` cells are where it stands when it **kept its distance**.
   - `piece.exit` cells are the green tiles for an `exit` goal.
5. **The fight** (`combat_scene.gd`, `SetPiece`): walked in means foes marked hidden are hidden and the foes act
   first; kept out means every foe is in view and the party acts first. A party bigger than the marked cells fills
   the nearest free ground.

## Cover from things

Until now only woods gave cover. Now a solid thing also shields whoever stands behind it
(`CombatGrid.shielded(from, to)`): a prop that blocks walking and is at least 0.45 tall, a rock, a ruin wall or a
fence, in the cell next to the target on the shooter's side, counts as cover (the same -1 as woods, never stacked
with it). It does not count when the shooter is two or more levels above, or for a target on a bridge deck. So the
side of the wagon you stand on matters.

## Building one

Maps are typed as plain text in `tools/setpieces/seed_pieces.py` (levels, water, road, things, foes, both starts),
then baked into a battle map:

```
python3 tools/setpieces/seed_pieces.py <id>            # writes tools/setpieces/src/<id>.json and prints the grid
cd game && godot --headless --path . -s res://tools/setpiece_build.gd -- <id> --force   # writes data/maps/sp_<id>.json
python3 tools/map_shape.py --fight game/data/maps/sp_<id>.json                          # the "not a box" bar
```

Every set piece must pass the box bar (fill, edge, corners, bays, levels, climbs): the outline is never a plain
rectangle ([USER] 2026-11-17: "these maps should not be just big squares and rectangles"). Edges come from the
outline, creeks and ditches, not from scattered rock pillars. Once baked, a map can be hand-tuned in the map maker;
re-baking needs `--force` and overwrites those edits.

`game/tests/test_set_pieces.gd` checks every encounter with a `map`: it loads, the whole party gets a cell, every
foe and exit tile can be walked to, and foes hide only from a party that walked in.

## Built so far

| Id | Road | Landmark | Event | Encounters | Notes |
|---|---|---|---|---|---|
| W1 `sp_wagon` | west | cart and spilled load across the road, creek with one bridge | `tr_wagon` | `wagon_in`, `wagon_out` | three hidden ambushers on the cover side, an archer up the bank |
| E2 `sp_bulls` | east | corral with a broken fence, barn, well | `tr_bulls` | `bulls_in` | three bulls and a rusher charge down open lanes; win by beating them or reaching the far gate |

The tipped wagon uses the upright cart art until Brandon draws a tipped one. Event lines are Claude's drafts,
flagged in `game/text/claude_written.txt`.
