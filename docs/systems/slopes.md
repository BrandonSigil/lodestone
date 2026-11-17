# Slopes

A slope is a grassy bank in place of a cliff face or a stair: the cell keeps its ground (grass, road, forest, stone),
but its top tilts from the ground below up to the ground above. Asked for by Brandon on 2026-11-17 about the E3
windmill: "I feel like ultimately this windmill is ontop of a hill one that really doesnt need stairs and is more just
surrounded by a few stacking hills. So I'd like to be able to add just slopes around each of these cliff faces. We
should build this completely, so that its also in our map maker, used in other maps where it makes sense, etc."

## How a slope is shaped

- A slope is a flag on a cell (`CombatGrid.slopes`, set with `set_slope`), not a ground type, so a road can climb a
  bank and the cart track stays a road. Water, rock, ruins, stairs and holes never tilt; painting one of those
  onto a slope makes it flat.
- Which way it tilts is never stored. `CombatGrid.slope_corners` works its four corner heights out from the flat
  ground around it every time, so reshaping the land around a slope reshapes the slope:
  - a corner takes the flat ground across the two sides that meet there;
  - when those two disagree, the one on the slope's axis wins (the pair of opposite sides that differ most), so a
    slope climbs from the ground below to the lip above whether it is cut into the top row of a cliff (a trail up a
    bank) or laid along its foot (a bank round a hill);
  - a corner with slopes on both sides takes the flat ground across the corner (a hill's outer or inner corner) or,
    with slopes all round, their mean, so a bank two cells deep is one surface;
  - every corner stays within `SLOPE_RISE` (1) of the cell's own height, so one slope cell spans at most two levels
    (one terrace step). A taller cliff keeps the rest of its face above the slope; a second row of slope finishes it.
- The top is drawn as two flat triangles folded along the contour (`slope_fold`): a hill's outer corner is a
  pyramid corner, an inner corner a hollow.
- Saved maps carry a `slopes` list of row strings (`/` a slope, `.` flat), written only when a map has slopes, so
  older maps are unchanged.

## Walking and fighting

- **Stepping** (`CombatGrid.can_step`): between a slope and its neighbour, the two sides are compared where they
  meet (`edge_h`, the mean of that side's two corners), against the piece's Jump. A bank from 1 to 3 is level with
  the meadow at its foot and the terrace at its lip, so a Jump 1 piece walks straight up a slope it couldn't climb
  as a cliff, and walks along a bank's length on the level. A bank's last cell twists up into the cliff beside it,
  so the cliff next door still blocks.
- **Cost**: a slope costs what its ground costs (grass 1, forest 2), the same as a stair. What it changes is where a
  climb can happen: a stair is a choke point a cell wide, a bank is open its whole length. Use stairs and cliffs
  where a map needs a choke; banks where the land should roll.
- **Height rules**: high ground, melee reach, shove drops and line of sight use the cell's own height, which the tools
  set halfway up the bank (a 1 to 3 bank stands at 2). A shove down a bank is a one-level drop, so banks soften falls.
- **Feet**: a piece standing on a slope stands on its tilted top (`stand_h`); free walking in exploration follows the
  tilt under the feet (`ExploreRules.ground_h`, `surface_z`), so a walker goes up a bank smoothly instead of popping.

## Drawing (CombatBoard._draw_slope)

Flat style, like the rest of the ground: the top in the ground's own texture, one flat light per triangle (a step
lighter turned to the sun, a step darker turned from it or falling away from the camera, `SLOPE_SUN`, `SLOPE_SHADE`,
`SLOPE_BACK`, in `SLOPE_STEP` steps, never a blend). Its sides toward the camera drop to whatever is in front in the
cliff's rock, so where a bank ends beside lower ground a wedge of rock shows, with the ground's lip folding over its
slanted top edge. Blocks beside a slope keep square corners so the two meet edge to edge, and their faces toward a
slope run down only to the slope's edge. Roads ride over slopes (`_zp`), and so do the tile set's trees on a forest
slope. Move and attack highlights tilt with the cell.

## Making slopes

- **Map maker (F8)**: the **Slope** tool (Y, after Stairs). Drag along the foot of a cliff: those cells tilt up to
  the lip. Dragging over the lip as well makes a gentler bank two cells deep. Brush size 1 to 4 with [ and ]. Right
  drag makes cells flat again. The **Area** tool's **Slope cliffs** button banks every cliff one or two levels high in a
  selection at once (`MapOps.bank`). The flat sketch view (Tab) marks each slope with a wedge pointing downhill.
- **Set pieces** (`tools/setpieces/seed_pieces.py`): a `/` mark is one slope cell; `banks="01"` banks the foot of
  every terrace edge on those levels; `cliffs` (a marks spec) keeps chosen cells as cliff. The bake calls
  `MapOps.slope` on each (`game/tools/setpiece_build_steps.gd`).
- **Plots** (`docs/systems/plots.md`): a `/` mark (Slope in the plot maker's marks) is a slope cell in road-fight plots.
- **Code**: `MapOps.slope(grid, cell)` sets one (a stair there turns to grass first; the cell moves halfway between
  the lowest and highest flat ground beside it, diagonals too); `MapOps.bank(grid, cells)` banks every cliff foot
  in a set of cells.

## Where they are used

- **E3 windmill hill** (`sp_mill`): both rises banked all round, no stairs; the cart track runs straight up the
  banks to the mill.
- **W1 tipped wagon** (`sp_wagon`): the thieves' trail and the woodcutters' trail up the bank, and the way down to
  the thieves' camp, are worn one-cell slopes instead of single stairs.
- Rocky north maps (N1 to N3) keep their cut stairs and cliffs on purpose: built stairs and sheer rock are what those
  places are.

Tests: `game/tests/test_slopes.gd`.
