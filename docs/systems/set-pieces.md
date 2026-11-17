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

## Rivers and stepping stones

- **Swept away** (built for W2, `CombatRules.sweep`): a piece pushed into river water is carried downstream instead of
  bumping: toward where the river leaves the map at its lowest edge, up to 3 cells, then it washes up on the nearest
  free bank, taking 2 damage (`SWEPT_DAMAGE`). Water that never leaves the map (a pond, a lake) still bumps. Ice
  pillars aren't swept.
- **Stepping stones**: a stone tile with river water on two or more sides is drawn as a round stone standing
  in the water (`CombatBoard._ford_stone`), so a ford reads as separate steps, not a paved causeway. This also changes
  the fords the random plots lay.
- **Lone stairs beside water** (`MapPlot._lay_stairs`): a single stair mark climbs between the two dry cells either side
  of it, never from the river at its foot (a trail up the side of a gorge).

## Building one

Maps are typed as plain text in `tools/setpieces/seed_pieces.py` (levels, water, road, things, foes, both starts),
then baked into a battle map:

```
python3 tools/setpieces/seed_pieces.py <id>            # writes tools/setpieces/src/<id>.json and prints the grid
cd game && godot --headless --path . -s res://tools/setpiece_build.gd -- <id> --force   # writes data/maps/sp_<id>.json
python3 tools/map_shape.py --piece game/data/maps/sp_<id>.json                          # the "not a box" bar (outline)
```

## A lived-in place first

Brandon on the first W1 and E2 (2026-11-16, backlog X23): "It just doesnt make any reasonable sense as an actual lived
place. I'd rather have believable ... feel lived in, and believable AND create fun combat/tactic choices for players.
This just seems barfed at random." Every set piece is drawn to these rules before any number is checked:

1. **Say what the place is in one sentence** (who uses it, why the road goes there) and put it in the map's `note`.
   Every terrace, path and thing must answer to that sentence.
2. **Land first, then use.** Lay the ground the way land lies (a hillside, a valley floor, a rise a barn was built on),
   then the paths people wear into it, then what they left there. No feature only to bend a number.
3. **Water is one thing with a reason**: one stream, pond or lake, flowing somewhere or fed from somewhere. No ditch
   segments, no puddles, no river you never have to cross.
4. **Stairs are where people walk.** Every stair joins two places someone would go between, on a path, square to the
   cliff, one per need. Never two stairs side by side to the same place, never a stair into a wall or off the map.
5. **Doors, gates and paths stay clear**: two free tiles in front of every door and gate, nothing on a path but what the
   scene put there on purpose (the wagon).
6. **Sides read at a glance.** The foes' side holds their cover and their reason to be there (spilled loot, a camp, a
   corral); the party enters from the side the road comes from. In the iso view the foes' side is screen left (low x,
   high y) and the party's is screen right (high x, low y) unless the scene says otherwise.
7. **Height is earned**: a lookout, a rise a house sits on, a bank above a road. Each height has a stair or trail up and
   something worth standing there for.
8. **Two real choices at least**: a short exposed way and a longer covered or higher way.
9. **Outline from the land**: the map's edge follows the hillside, the field's hedges, the water, never a rectangle
   ([USER] 2026-11-17: "these maps should not be just big squares and rectangles"). Checked with
   `python3 tools/map_shape.py --piece game/data/maps/sp_<id>.json`, which looks at the outline alone, so filler
   ponds and rocks inside can't buy a pass.
10. **Review before Brandon sees it**: a map-engineer pass (believable?) and a play-tester pass (two or three turns from
    each start: dead zones, blocked doors, degenerate moves), fixes made, then screenshots.

Once baked, a map can be hand-tuned in the map maker; re-baking needs `--force` and overwrites those edits.

`game/tests/test_set_pieces.gd` checks every encounter with a `map`: it loads, the whole party gets a cell, every
foe and exit tile can be walked to, and foes hide only from a party that walked in.

## Built so far

| Id | Road | Landmark | Event | Encounters | Notes |
|---|---|---|---|---|---|
| W1 `sp_wagon` | west | hillside road, the wagon across it, thieves' camp below the road and lookout knob above, both on the left | `tr_wagon` | `wagon_in`, `wagon_out` | three hidden ambushers by the spilled load, an archer on the knob; the woodcutters' trail on the right lets the party climb the bank |
| W2 `sp_falls` | west | river falling off a shelf, footbridge on top, zig-zag stepping stones below, a trail up each side of the gorge | `tr_falls` | `falls_in`, `falls_out` | hidden ambusher at the stones' far end, bandit on the left bank, archers on the shelf and by the bridge; anyone kicked off a stone is swept downstream |
| W3 `sp_lake` | west | fisher's boathouse on a lake shore, reeds either side, rowboat on the sand, road through the meadow behind | `tr_lake` | `lake_in`, `lake_out` | spiders hidden in the reeds either side of the hut, slimes out of the lake; a lake has no current, so a push into it only bumps |
| N1 `sp_tower` | north | ruined watchtower on a crag above the road: the tower's broken corners on top, a built path switchbacking up the right, a goat track up the left | `tr_tower` | `tower_in`, `tower_out` | captain (leader) on the tower top, a shield warder at the top of the path, an archer on the middle ledge, an ambusher hidden by the goat track |
| N2 `sp_shrine` | north | shrine stone on a paved plinth in a dell beside the road, a ring of standing stones round it, graves; one wide stair from the shrine up a shelf and the ridge to the keeper by the old wall | `tr_shrine` | `shrine_in`, `shrine_out` | the keeper (hexer, leader) on the ridge, skeletons by the graves, two more hidden behind the west graves |
| N3 `sp_rope` | north | rope bridge over a deep gorge, a toll barricade of crates at the far end, a fallen pine across the narrows upstream | `tr_rope` | `rope_in`, `rope_out` | the toll keeper (leader) and his gate man hold their post (`post`) until someone comes within 3 or hurts them; an archer behind the barrel, an ambusher by the pine |
| E1 `sp_farm` | east | farmhouse with a fenced yard, well and hay by the road; a field of crop beds on the left with scarecrows | `tr_farm` | `farm_in`, `farm_out` | real scarecrows (`scarecrow`, a structure) stand in the beds; straw men (`foe_scarecrow`, same look, spook) stand on the paths, holding their post until someone comes close or strikes one |
| E2 `sp_bulls` | east | farm by the road: barn on a low rise with one stair, lane, broken corral and stock pond on the left, well and mown hay field on the right | `tr_bulls` | `bulls_in` | three bulls loose on the left; win by beating them or reaching the barn door |
| E3 `sp_mill` | east | windmill on a terraced hill of wheat above the road; a cart track climbs straight to the mill in two wide flights; farmers' steps up from the meadow and to the mill's back | `tr_mill` | `mill_in`, `mill_out` | captain (archer, leader, post) at the mill door, an archer on the hilltop, men on the landing and in the wheat, an ambusher low in the west wheat |

The tipped wagon uses the upright cart art until Brandon draws a tipped one. A lone stair cut into a two-step terrace edge draws its steps from the ground below up to the lip it meets
(Brandon 2026-11-17: "the tallest point of the stairs should face the cliff"). A foe marked `post` holds its cell (EnemyAI: it strikes what comes in reach) until a party piece comes within
3 or it is hurt, so a gate or lookout stays manned. Event lines are Claude's drafts,
flagged in `game/text/claude_written.txt`.
