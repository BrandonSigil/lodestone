# Ground transitions

Where two grounds meet on one level (a road through grass, ruins floor inside a forest), the seam should
soften: forest floor with a little rubble on it, then rubble on forest floor, then full stone. LDtk calls
this auto-rendering; Brandon asked for it on 2026-10-28.

## What the game does today (no art needed)
`CombatBoard._fringe`: where a higher-ranked ground meets a lower one at the same height, the higher
ground's own top texture reaches a ragged ~third of a cell onto the lower cell and fades out. Ranks:
grass 0 < forest floor 1 < road 2 < stone 3 (water, rock, ruin and stairs never blend). Two tile sets
meeting (a `ruins` zone inside a `forest` map) blend both ways at half depth. It is a stand-in: it can only
fade, it can't scatter rubble or tufts. Painted transitions below replace it pair by pair.

## The art: three pieces per higher ground, per tile set
Draw them flat, top-down, in the same projection and size as the top textures (`top_*.png`, one image = 2 x 2
cells, 512 px, B-rules in `docs/art/battle-maps.md`). Everything outside the higher ground is transparent.
The game turns each piece to the four directions itself, so one edge covers all four edges.

| Piece | File | What it shows |
| --- | --- | --- |
| Edge | `fringe_<ground>_edge.png` | One cell's worth: the higher ground's ragged edge along the top of the image, fading into bits (pebbles, leaf litter, a few tufts) toward the bottom. |
| Outer corner | `fringe_<ground>_outer.png` | The higher ground wrapping a convex corner (top-left of the image). |
| Inner corner | `fringe_<ground>_inner.png` | The higher ground filling a concave corner. |
| Scatter (optional) | `scatter_<ground>_1.png` .. `_3.png` | Loose bits of the higher ground (a rubble stone, a leaf clump) the game sprinkles one cell further out. |

They go in the tile set's folder (`game/art/source/battle/<set>/`), like every other tile. The renderer
doesn't read them yet: the loader gets written with the first painted set, and then a set without the
pieces falls back to the base set's, then to the code fade.

## Which pairs the current maps need
Counted from every map in `game/data/` on 2026-10-28 (same-height neighbours). Painting the higher ground's
three pieces covers every pair below it in that set.

| Tile set | Higher ground pieces needed | Pairs it covers (cells of seam) |
| --- | --- | --- |
| village | forest, road, stone | forest/grass 182, grass/road 142, grass/stone 56, forest/road 16, road/stone 16 |
| forest (base) | forest, road, stone | forest/grass 122, grass/road 43, forest/road 5, forest/stone 2, road/stone 2 |
| alpine (borrows forest) | (base pieces) | forest/grass 100, grass/road 57, forest/road 9 |
| farmland | forest, road, stone | grass/stone 20, forest/grass 14, grass/road 10, road/stone 4 |
| crystal | forest, road | forest/grass 18, grass/road 4 |
| snow | forest, road | forest/grass 17, grass/road 10, forest/road 2 |
| marsh | forest, road | forest/grass 14, grass/road 4, forest/road 3 |
| dungeon | forest | forest/grass 12 |
| ruins | forest | forest/grass 5 |

Tile sets meeting each other (zones): marsh/snow (grass and forest edges, 16), dungeon/ruins stone (7),
dungeon road into forest grass (3). For these the higher set's pieces are used on the lower set's cell, so
no extra files: the zone with the higher ground rank (or, for equal ground, the zone painted on the map)
draws its fringe.

Most value first: village (forest, road, stone), then the base forest set, then farmland stone.

## Through the Picsart pipeline
Same flow as the tile kits (`art/prompts/`, `tools/art/`): one sheet per set with the three pieces per
ground side by side on transparency, prompt built from the approved flat forest panel, cut by a script
into the files above. Brandon approves the sheet before it goes in.
