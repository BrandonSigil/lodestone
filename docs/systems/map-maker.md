# Map maker

Build battle and exploration maps in the game, seen the whole time in their finished look (sky and mountains, the forest around the map, grass lips, tall cliffs, carved stairs, waterfalls). Design and the reasons behind the look: `docs/design/map-look.md`.

Code: `game/scripts/maker/` (`map_maker.gd` the scene, `map_doc.gd` files, `map_recipes.gd` hand-laid maps, `maker_overlay.gd` brush marks). Map operations: `game/scripts/combat/map_ops.gd`; generator: `map_gen.gd`. Scene: `scenes/map_maker.tscn`.

## Open it
- **F8 from any screen**, or F6 on `scenes/map_maker.tscn` in the editor.
- The first time it opens `maps/highland` (the reference layout); after that, the last map you had open.

## Screen
- **Top bar**: map name, `*` when unsaved, the look in use, size. NEW (blank map of the W x H on the right), OPEN MAP..., SAVE, UNDO, REDO, TURN (Q), PLAY TEST.
- **Left**: tools, the brush size, and a help line for the tool picked.
- **Right**: the map's settings, the generator and view options.
- **Bottom**: the cell under the cursor (grid cell, terrain, height, zone, prop).

## Tools
Left drag paints; right drag does the opposite. Each cell changes once per stroke, so dragging RAISE over a cell lifts it one level, not ten.

| Group | Tool | Left | Right |
| --- | --- | --- | --- |
| SCULPT | RAISE / LOWER | Up / down one level | The opposite |
| | LEVEL | Flatten into a terrace at the level height | Take a cell's height as the level height |
| PAINT | GRASS, FOREST, ROAD, STONE, ROCK, RUIN, WATER | Paint that ground (a hole is filled first) | Grass |
| BUILD | RIVER | Drag the river's course from high ground down: it digs a channel that never runs uphill; every drop becomes a waterfall. Brush size 1+ makes it wider | |
| | STAIRS | Click a cell at a cliff: stairs joining both sides. Drag from the bottom to the top of a cliff: a straight flight | Clear stairs along the drag |
| | PROP | Stand the picked prop on a cell | Take it away |
| SHAPE | CUT | Cut cells out of the map: the outline, chasms, pits | Fill them back |
| | FILL | Give holes ground again at the height around them | Cut |
| | ZONE | Paint another tile set onto cells (forest blending into ruins) | Back to the map's own set |

Brush size 0 to 4 (`[` and `]`), diamond or square.

## Keys
- Shift drag, middle drag or two fingers: pan. Arrows pan too. Wheel or pinch: zoom. Space: fit the map.
- Q turns the view. G toggles grid lines. H hides the panels (for a clean look at the map).
- Ctrl Z undo, Ctrl Shift Z or Ctrl Y redo (60 steps), Ctrl S save.

## Right panel
- **MAP**: name, kind (battle map or explore map), width and height (6 to 48) with RESIZE.
- **LOOK**: `tiles` is the tile set (`forest`, `alpine`, `snow`, `ruins`...). `look` is the staging from `data/looks.csv` ("as the tiles" uses the row named like the tile set). `cliff depth` is how far the outer cliffs drop (the look's floor), `forest rings` how many rings of trees surround the map, `strangeness` drifts the colours toward the alien look. Depth and rings you change are saved with the map as overrides of the look's own values.
- **GENERATE**: `seed`, NEW VALLEY (a terraced valley at W x H: terraces 0, 3, 6, 8 high, a river falling down them, stairs where a climb is needed, roads, pines, boulders, a ragged outline; the same seed gives the same map), NEXT SEED, ROUGHEN OUTLINE, LINK WITH STAIRS (joins every walkable part with stairs), and TEMPLATE (rebuild a hand-laid recipe, `highland` for now). Each is one undo step.
- **VIEW**: grid lines, height numbers, fit.

Blue marks show the party start, red the enemies or enemy groups, gold the things (doors, chests) from the map's file. The maker edits the ground and the look only; it writes the rest of the file back untouched.

## Saving
- Battle maps save to `game/data/maps/<name>.json` (the combat sandbox's format; the sandbox's LOAD list sees them). A new battle map gets a test party at the screen-left end and a band of foes at the screen-right end. Pieces left on cells that can't be stood on any more are dropped.
- Explore maps save to `game/data/explore/<name>.json`. Start, groups and things are kept; if the start is no longer walkable it moves to the left end.
- When the project folder is read-only (an exported build), saves go to `user://maps/` or `user://explore/` instead.
- The map's look is saved in its grid as `"look": {"id": ..., "floor": ..., "skirt": ...}`.

## Play test
PLAY TEST saves, then a battle map opens in the combat sandbox with the fight already started; an explore map opens in the explore scene at its start. F8 brings you back to the map you were making.

## Hand-laid maps in code (recipes)
`MapRecipes` writes a layout as a few lines of the same operations the brushes use, placed in screen terms (`u` from screen left -1 to right 1, `v` from the back 0 to the front 1), so a layout can be rebuilt, tweaked and tested. `highland` is the reference layout: a 26 x 26 map with a meadow and crossroads in the middle, high plateaus behind and to the right, a lower terrace on the left across a gorge (stone bridge), two terraces in front, a low river along the front and three waterfalls. Add a recipe: write the function, add it to `names()` and `build()`.

## Command line
From `game/`:
- Save a recipe as a battle map: `godot --headless --path . -s res://tools/map_build.gd -- highland alpine`.
- Screenshot a map with its look: `godot --path . -s res://tools/map_shot.gd -- out.png <map> [turn 0-3] [grid]`, where `<map>` is `maps/<name>`, `explore/<name>`, `gen:<seed>:<w>:<h>[:<look>]` or `recipe:<name>`. In the cloud: `xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x1000 ...`.

## Tests
`game/tests/test_maps.gd`: skirt rings, lip profile, stair runs, rivers never run uphill, flights, roughen keeps one piece, link, roads, the valley generator, the highland recipe (every dry cell reachable, every terrain used, at least three falls), looks, grid look round trip, art borrowing, map files, and the maker scene itself (edit, undo, redo, look fields, templates).
