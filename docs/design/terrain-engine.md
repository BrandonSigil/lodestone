# Terrain engine: hand-shaped maps from the grid

Status: **Proposed (AI), 2026-10-28.** First pass built: the soft terrain pass (`CombatBoard.soft`, on for every
outdoor look; interiors keep the blocks). Everything below is a proposal until Brandon retags it `[USER]` in
`docs/decisions.md`.

The ask (Brandon, 2026-10-28): maps, hand-built or generated, that look bespoke and painted like the target
(`docs/art/references/terrain-target-snow.png`), not like Minecraft. He named six things: cliffs whose pattern you
don't notice, a slightly darker snow cap that overhangs each lip, water strokes that run down the whole river
instead of sitting in one square, stairs set into the map, softer edges, and no grid lines.

Screens: `art/screens/soft-terrain/` (`highland-*-before.png` is the block look, `-after.png` the soft pass as it
is now, `highland-closeup-first-pass.png` the first, rounder pass Brandon reviewed; same camera).

## 1. Why our maps read as Minecraft

Not the art. The same snow art draws both pictures in the screens folder. It was how the board draws cells:

| What you see | Cause in the code (before the soft pass) |
| --- | --- |
| A white snow band halfway down tall cliffs; the rock pattern lines up with the cells | Sides repeat every 2 cells across and 4 levels down, pinned to absolute height (`_face`: `v = -h / SIDE_LEVELS`), so the cap painted into the side art lands wherever the height is a multiple of 4, not under the lip |
| A thin light line every two cells on every cliff | The Picsart side textures were cut from a sheet and keep a strip of paper and ink at their left and right edges; every repeat shows it |
| Every block outlined | A pale rim line on every ledge, ink at every block corner, a dark line at every face's foot, a contact shadow band on every cell edge, grid polylines |
| Hard square corners | Nothing rounds or fills a corner |
| A diamond lattice on water | A float rounding bug: water next to water at some heights cast a contact shadow on itself (fixed for both looks) |
| Waterfalls in boxes | Each fall is a per-cell sprite with rock pillars painted on both sides |
| Stairs on top of the map | Stairs are stacked grey slabs in the masonry texture, not the path and the rock they're cut from |
| Zigzag edges | The layout: one-cell zigzags (diagonal channels, stepped terrace edges) can't look hand-made however they're drawn. The target has long straight runs and few corners |

## 2. The idea: keep the grid for the rules, stop drawing cells

The grid stays the truth for play: heights, terrain, moving, sight, AI. The picture is drawn as continuous
surfaces worked out from it. Short version: **parameterise, don't tile.** Nothing a painter would make continuous
(a cliff, a lip, a river, a path) may restart at a cell edge.

Four layers, each a pure rule set so it works on any map, hand-built or generated:

1. **Shape** (`TerrainShape`, pure, tested): which corners of each cell round off (both sides drop away), which
   get a fillet (a low cell's corner tucked between higher ground of one height, which curves round into it),
   and what ground shows in the bit a corner gives up. A block standing alone rounds into a column (the target's
   rock pillars come for free from single raised cells). Drawing stays per cell, so the board's slabs, draw
   order and local redraws are unchanged.
2. **Surface**: every surface gets coordinates that run on across cells. Cliff faces: across the screen
   (`_screen_u`, shifted by the cliff's top so stacked walls don't echo each other) and down from **that cliff's
   own top**, so the texture's top band always sits under the lip and its strokes run the full height. Tops:
   world position. Lips: their edge is a function of screen position, so it continues across cells and round
   every corner. Water: a flow field over each body of water (downhill, then toward where it pours off the map)
   and strokes traced along it (`TerrainShape.flow`, `strokes`), cut at cell edges so each cell draws its own
   piece at its own depth.
3. **Dress** (next): props, pillars and small decals by rules (section 6).
4. **Line and light, flat like the key art**: two flat values per material, lit and shade, with a clean step
   between them; the cap a flat band; no shading gradients, highlights or occlusion fades. Outlines are a loose,
   see-through marker only where a block stands out against what's behind it (the back of a raised top, down the
   sides where its faces turn away), and they break off now and then. Never the front edges or the foot.

## 3. What the soft pass does now (built 2026-10-28)

| Brandon's note | What it does | Code |
| --- | --- | --- |
| Cliff pattern not noticeable | One cliff surface along the screen, hung from each cliff's top. The painted cap and the sheet's edges are cut off the side texture at load and the rest is faded into itself so it tiles with no seam (the art file is untouched) | `CombatBoard._soft_face`, `BattleArt.side_body` |
| Snow cap overhang, a little darker | The top's own texture folds over every edge as one unbroken flat band: lit side 0.88 / 0.92 / 1.0 of its top, shade side a clear blue (0.68 / 0.76 / 0.92), values measured off the key art. Its lower edge is lumpy (30 to 100% of its depth in slow swells), with a short drip now and then. Snow (whose sides used to carry the cap) hangs 0.8 levels | `_soft_lip`, `TerrainShape.lip_depth`, `cap` column in `battle_art_snow.csv` |
| Water strokes down the whole river | Strokes follow the flow field through bends, kept evenly apart, gently wavering, fading at their ends; foam along the banks and round rounded corners; falls are one sheet across neighbouring cells with streaks placed by screen position | `TerrainShape.flow/strokes/by_cell`, `_water_marks`, `_waterfall_soft` |
| Stairs set into the map | Treads and risers in the path's ground, the flight's sides in the rock of the cliff it is cut from, that rock's texture hung from the terrace above so it carries on from the cliff beside. Every step of a flight climbs along the flight (a step used to pick its highest and lowest neighbours separately and could climb sideways, leaving a hole beside it in both looks), and a block beside a stair runs its face down to the stair's lowest step | `_stair_steps_soft`, `MapDress.stair_run`, `_seg_foot` |
| Softer edges | Corners round a little, like a brush going round them: 0.13 cells (lone blocks 0.2, masonry 0.04), each corner 35% more or less than that, fixed per corner. Inner corners fillet (0.1). The bit a corner gives up shows the right neighbour's ground, texture continuous | `TerrainShape.corner_radius`, `_gap_floor`, `_fillet` |
| No grid lines | Nothing is drawn per cell edge any more: no rims, no corner ink, no foot lines. The grid shows only when switched on (map maker) | `_draw_ground_soft` |
| Snow piled against walls (review 6) | Where a wall rises from a floor, the floor's own ground piles up its foot: a band of it whose top swells into mounds (up to `drift` levels from the set's table, never more than 60% of the wall), lit side nearly the floor's own value, shade side cool. Snow only for now: grass and forest 0.75, road 0.5, rock 0.45 | `_soft_drifts`, `_drift`, `TerrainShape.drift_height`, `drift` column |
| Edges without stair-steps | The Compatibility renderer can't antialias 2D (tested: no 2D MSAA on GLES3, FXAA only on Forward+ and Mobile), so a 1 px hairline in each surface's own colour runs along the edges you see: cap bottoms, top edges, drift tops | `_soft_lip`, `_draw_ground_soft`, `_drift` |
| Outlines (from the reviews) | A pen stroke in a cool slate blue (0.3 / 0.35 / 0.48, between the key art's line over rock and over snow), crisp edged and see-through (70%, what's under it shows a little): one strip of triangles whose width swells and thins with the hand's pressure (1.5 engine px at full, 70 to 130% of that), wavers a touch and tapers off where the pen lifts (about an eighth of its length), with a faint hairline along each edge instead of a soft halo. Where a line really stops (no other line carries on from that point, found from all the map's lines when the map changes), it narrows to a rounded point over 3 px instead of ending square; where it only hands over to the next cell's line it runs straight on. On silhouettes (the back of a raised top, down its sides), the waterline where a block's faces go into water (drawn just above it, round fillets too), and down the sides of a waterfall where its sheet stops against rock. Never the front edges or a foot on dry ground | `_marker`, `_marker_along`, `_marker_down`, `_into_water` |

### Brandon's review of the first pass (2026-10-28)
"The softness really makes an improvement", but it read almost 3D, the corners were nearly circular ("border
radius too high"), and he likes the key art's outlines: imperfect, semi-translucent, marker-like, only on outer
edges, sporadic. What made it 3D, and what changed:

| First pass | Now |
| --- | --- |
| Light blended round each corner, so corners turned into lit cylinders | Two flat values, lit or shade, by which way each bit of face points |
| Tall faces darkened toward their foot | No occlusion fade; faces are flat (the valley's mist at the map's outer foot stays) |
| Cap: gradient to its edge, a highlight line, a cast shadow, an ink line, an overhang | One flat band per side, no line; the overhang pinched into spikes at inner corners, so it's gone |
| Corner radius 0.32 (lone blocks 0.46) | 0.13 (lone blocks 0.2), varying per corner |
| Thin, even, crisp ink lines | A bold cel outline (second review: "show up", almost cel-shaded), then a crisp pen stroke instead of a soft halo (third review: "blurry, less like a pen/marker stroke"), then thinner and a lighter slate (fourth review: "less thick, not as contrasty"), then thinner again and see-through (fifth: "a little thinner and a little more transparent"), then tapered ends instead of square ones (sixth) |
| Waterfalls lighter at the top | One flat sheet; streaks and the white lip stay |
| Contact shade 0.9 | 0.3 |

Still short of the key art, waiting on art or the next phases:
- Snow tops are whiter than the key art's (about 226 of 255, a little blue) and repeat every 2 x 2 cells.
- The key art has more outline because it has more rock pillars and tall rock masses to outline; highland has
  none. Single raised cells already draw as the key art's pillars (`art/screens/soft-terrain/highland-pillars-test.png`,
  five cells raised in memory, map file untouched); V10 would place them.
- The path is grey snow and blends with an airbrushed fade; the key art's is a sandy band (V12 ribbons, kit path).
- The cliff rock is the old Picsart side, cropped and faded (a little soft); stairs are the set's grey road.
- Layouts still have one-cell zigzags (highland's diagonal channel). Prop ground shadows are now a faint cool shade.

Switch: `CombatBoard.soft` (default true). Maps with a `plain` look (interiors) always draw blocks. In the map maker,
K (or the top bar's snow-capped block) flips it; `tools/map_shot.gd ... blocks` renders the plain look. How to
build for it: `docs/systems/map-maker.md`, "Building for the painted look". The shape caches rebuild only near
an edit (about 1 ms per edit on a 48 x 48 map; a full rebuild there is about 90 ms).

## 4. The biome kit: art that makes it painterly

What a biome needs so the engine can paint any map in it. About 20 files, all **seamless, borderless, flat-lit
(the engine adds light)**, in the biome's palette. A new biome is a new kit and a palette row, no code.

| Piece | File (in `game/art/source/battle/<set>/`) | Size | Rules |
| --- | --- | --- | --- |
| Ground tops, 2 or 3 | `top_<ground>.png` | 1024 px, covers 4 x 4 cells | Calm: one value, a few soft marks (R4). Tiles both ways. Twice the area of today's, so repeats are rare |
| Path top | `top_road.png` | 1024 px, 4 x 4 cells | The target's sandy track. Also the stair treads |
| Cliff rock, 1 or 2 | `cliff_<rock>.png` | 1024 x 1024, 4 cells x 6 levels | Vertical strokes and column facets, no cap, no paper edge, no outline, tiles both ways. Replaces `side_*` with baked caps |
| Lip strip | `lip_<ground>.png` | 1024 x 128 | The overhang's front: top edge straight, bottom edge the drip silhouette in alpha, tiles across. The engine bends it round every corner (replaces the code scallops) |
| Water surface | `top_water.png` | 1024 px | Flat colour and a little mottle; the strokes come from the engine |
| Flow stroke brushes, 3 to 5 | `stroke_water_<n>.png` | 256 x 32 | One painted stroke each, light and dark. The engine draws them along the flow lines instead of plain lines |
| Fall sheet | `fall.png` | 256 x 1024 | Tiles top to bottom, no rocks at its sides. Scrolls |
| Decals, 8 to 12 | `decal_<name>_<n>.png` | 128 to 256 px | Drifts, cracks, pebbles, tufts, ice floes, footprints. Small, transparent, scattered by rules |
| Props (have most) | `prop_*.png` | as now | Pines 5, bushes 3, boulders 2, one or two rock outcrops |

How to make them: Brandon's Procreate templates (`art/templates/procreate/`) gain a "seamless swatch" canvas per
size, or a Picsart batch from the approved flat style (`docs/art/references/style-flat-forest.png`), each batch
only on Brandon's yes, drafts until he approves. `tools/art/tile_seam_check.py` already checks repeats.

The engine side, one file at a time: each loader falls back to today's art when a kit file is missing, so a set
improves piece by piece (the `side_body` crop and fade is that fallback for cliffs).

## 5. Maps a painter would draw: generator and authoring rules

Drawing can only soften a layout. These join V1 to V8 (`docs/design/map-look.md` section 7). Brandon had them
built into the generator, the highland template and the map maker on 2026-10-28:

- **V9 No one-cell zigzags.** An outline runs straight for at least two cells between turns; a slanted edge is
  built from two- or three-cell steps. `MapOps.tidy` re-steps edges two cells at a time (in each 2 x 2 block, at
  the offset that changes least, the odd one out of three takes their height; a hole counts as a level, so the
  outline steps too) and drops a cell sticking out or fills a notch; water, stairs and cells beside stairs stay.
  `MapOps.steps` lays slanted courses (rivers, the recipe's paths) in runs of two cells or more, and the
  generator's river goes straight on for at least two cells before it turns. Map maker: Tidy brush (5), Map tab
  > Generate > Tidy edges.
- **V10 Pillars on the rims.** Two to four single-cell rock columns on high rims and in front of cliffs; they round
  into the target's snow-capped pillars. `MapOps.pillar` raises a cell two levels over its highest neighbour
  in the top's own ground; `MapOps.pillars` places a few at least four cells apart, off roads, water and stairs,
  never cutting the walkable map. A pillar top (`CombatGrid.perch`) only takes a Jump 2 piece, so deploy cells
  and the maker's test party skip it. Map maker: Pillar tool (6), Generate > Add pillars.
- **V11 Rivers fall in few, big drops.** Level runs with square bends, and falls of two levels or more, not a
  one-level step every cell: `MapOps.river(..., min_fall)` digs deeper and falls `min_fall` instead of stepping
  less. The generator and the recipe use 2. The generator's river now only leaves the map from its front half,
  so it runs the map's length.
- **V12 Paths are ribbons.** Road cells on each level join into lines through their centres, smoothed with
  rounded turns and drawn as one band with a wavering edge over the ground (`TerrainShape.ribbons`, cut per cell
  like the flow strokes); the cells underneath stay road for movement and draw their ground (grass, snow).
  Built as a drawing rule, so every map's roads become ribbons without changing the map files. The ribbon is
  the set's road texture. The snow set borrows the base set's sand (`base/top_road`) recoloured to the key art's
  pale beige by the `tone` column (`#c7b9ab`, which lands on the key art's 220 / 204 / 187 on screen after the
  height lift); stair treads use the same road. Brandon: the plain sand was "a little too bright and yellow".

## 6. Build plan

| Phase | What | Needs Brandon |
| --- | --- | --- |
| 0, done | Soft pass: shape, continuous cliffs and lips, flow strokes, sheet falls, carved stairs, silhouette ink | Look at the screens |
| 1 | Tune with him: radii, cap thickness, drip count, stroke weight; lock as `[USER]` lines | His eye |
| 2 | Snow kit: cliff rock, lip strip, fall sheet, path, 1024 tops, stroke brushes, decals; loaders for each | Yes to a Picsart batch, or Procreate |
| 3, done | Maps: V9 to V12 in `MapGen`, the highland recipe and the map maker (Tidy, Pillar, ribbons) | Done 2026-10-28 |
| 4 | Life: flow strokes slide downstream, ice floes, macro variation on tops (two swatches blended by a slow noise) | No |
| 5 | Other biomes: forest, ruins, canyon kits | A kit per biome |

## 7. Considered, not chosen

- **Hand-painted autotiles** (dual grid or marching-squares pieces): the pieces multiply with every height
  difference, still repeat, and need a full set per biome. The rules above get the same corners from a handful
  of swatches.
- **A 3D board** (meshes, orthographic camera, toon shading): the right tool for real lighting, but a rewrite of
  the board, picking, fog and units. Players never turn the camera (`[USER]` 2026-10-28), which keeps 2D simple.
- **A painted plate per map** (AI paint-over): shelved by Brandon on 2026-10-27, and it can't follow a generated
  map or an edit.

## 8. Open questions for Brandon

1. Keep the soft pass on for every outdoor map now, or only snow until the kits land?
2. Corners (0.13, varying) and cap thickness (0.8 levels): right now, or more or less?
3. Done: snow paths are the key art's beige (`tone` column).
4. Make the snow kit through Picsart (a batch of sheets at about 10 cents each) or paint it in Procreate?
5. Done: V9 to V12 are built (section 5).
