# Stairs: a kit (proposal)

Brandon on village v2 pass 4 (2026-10-30): "The stairs still look janky... they connect oddly to each other, these flat
spots in the middle of them are weird. They should be constant repeatable stairs. Can you research how other games do
this? They should work at different angles."

## What's wrong today
- **Steps change size from cell to cell.** `CombatBoard._stair_steps_soft` fits 2 to 8 treads between the heights of a
  cell's neighbours (`MapDress.stair_run`: half a level each way, at most 2 levels). Neighbouring cells get different
  tread heights. Where two stair cells meet, the top tread of one and the bottom tread of the next sit at the same
  height, so the seam reads as a double-length flat tread.
- **Flights don't meet the ground flush.** A flight cut as `hi - 1 .. lo + 1` (pass 4's roads) ends half a level
  short of the ground at both ends.
- **Landings mid-flight.** The grand staircases had a flat landing every three steps, which is what Brandon called
  "flat spots in the middle".
- **Stubs and sideways two-step flights.** Short cliffs got single stair cells, or two cells climbing across the
  view (playtest recheck, pass 4).

## How other games do it
- **Final Fantasy Tactics, Triangle Strategy:** stairs are terrain. Each tile has a height, and a stair tile is a
  tile whose surface is drawn as steps between its height and its lower neighbour's. A flight is a run of tiles,
  each one step higher, with every step the same size because the tile height unit is fixed.
- **Tactics Ogre** (Brandon's picture 4): chunky stone block steps, one block per height unit. A flight is a stack of
  identical blocks, with walls running alongside and no landings inside a flight.
- **Brandon's picture 3:** a wide flight of identical block steps. The flight is as wide as the space, and the sides
  are the cliff's own masonry.
- **Brandon's pictures 5 and 6 (cozy plaza steps):** low, wide, shallow treads, several per height unit. They follow
  the edge of a plaza and wrap round its outside corners, so the step lines turn the corner as L shapes.
- **Tile kits** ([Kenney's isometric prototype tiles](https://opengameart.org/content/isometric-prototype-tiles),
  [Kenney's isometric dungeon tiles](https://kenney-assets.itch.io/isometric-dungeon-tiles)): one stair tile per
  facing, each a fixed rise, so stairs at any angle are the same piece turned. Corners are their own tiles.

The common rules: **one constant step rise everywhere; a stair cell is one piece of a repeating flight; flights are
straight runs with no landings inside; turns happen on the level ground at either end, or as a corner piece; each
facing is the same piece turned.**

## The kit
1. **Constant rise.** A stair cell climbs from the cell below it to its own height, in treads of one constant rise
   (`STAIR_TREADS` a level). Its top tread is flush with the next cell up, so a flight runs on unbroken and every step
   on the map is the same size.
2. **Flights.** A flight from ground `lo` to ground `hi` is `hi - lo` stair cells at heights `lo + 1 .. hi`, a
   straight run with no landings. It can be any width; the cells across a flight share heights, so the treads line up.
3. **Facings.** The same piece serves all four ways. A cell climbs toward a stair one level higher; failing that, a
   flight's top cell climbs toward the level ground it meets, opposite lower ground. Both camera turns show the
   flight right (risers toward the camera, treads stepping up away from it).
4. **Outside corners.** A cell with lower ground on one x side and one y side, and its own height on the other two,
   is an outside corner. Its treads are L-shaped, so plaza steps wrap round a corner (Brandon's pictures 5 and 6).
5. **Ends.** The top tread is flush with the ground above. The bottom riser stands on the ground below. The flight's
   sides are the cliff's rock.
6. **Look.** Two tread sizes are on the desk: one block step a level (`STAIR_TREADS` 1, Tactics Ogre, pictures 3 and
   4) or three fine treads a level (3, pictures 5 and 6).

## Map rules that go with it
- A road or route meets a cliff with a straight kit flight cut out from the cliff. No single stub steps; a flight is
  at least 2 cells long. It is 2 wide or wider where there's room, 3 wide or wider for grand stairs.
- Flights climb toward the camera's up-screen diagonals; sideways two-cell flights are avoided.
- Turns (switchbacks) happen on a terrace between two flights, never inside one.

## What the engine needs (systems developer)
- `CombatBoard._stair_steps_soft` (and the block-look `_stair_steps`): draw a stair cell from its lower neighbour's
  height up to its own, in treads of a constant rise (`STAIR_TREADS`), with the climb direction and corner rule
  above. A working prototype is in the shared notes folder (`stair-kit-board.patch`); it was tested on the
  `stair_test` patch, not on the live maps.
- `MapDress.stair_run` is used elsewhere (stair ledge lines, the block look); it should agree with the kit's climb
  direction.
- Existing maps: the live village and snow pass flights are built `top, top - 1, ...` down from the upper ground,
  which already fits the kit (each cell one level over the one below). Check them after the switch.
- A piece standing on a stair cell stands at its top tread (the cell's height), as now.
