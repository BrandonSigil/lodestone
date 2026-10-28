# Map maker

Build battle and exploration maps in the game (the starting village, dungeons, explore maps), seen the whole
time in their finished look. Design of the look: `docs/design/map-look.md`. Why the editor works the way it
does: `docs/research/map-editors.md`.

Code: `game/scripts/maker/` (`map_maker.gd` the scene, `maker_catalog.gd` the asset catalog, `maker_ui.gd`
theme and widgets, `maker_icons.gd` the icons drawn in code, `maker_overlay.gd` ghost, badges and marks,
`map_doc.gd` files, `map_recipes.gd` hand-laid maps). Map operations: `game/scripts/combat/map_ops.gd`.
Catalog: `game/data/catalog.csv`. Scene: `scenes/map_maker.tscn`.

## Open it
- **F8 from any screen**, the launch menu's MAKE buttons (F7; "Edit the village" opens that map straight away), or F6 on `scenes/map_maker.tscn` in the editor. It reopens the last map.

## Screen
- **Top bar** (icons, tooltips name them): new, open, save, undo, redo; the map's name (`*` unsaved); grid
  lines, height numbers, names over things; turn the view (editing only), fit, hide panels; **Play test**.
- **Tool rail** (left): Select V, Place B, Erase X | Raise 1, Lower 2, Level 3, Smooth 4 | Ground P, Path L,
  River W, Stairs T | Cut C, Fill F, Zone Z. Hover a tool for what it does.
- **Options bar** (top): what the picked tool needs: brush size and shape, the level height, ground
  swatches (the tile set's own textures), path ground and "follow ground", the zone's tile set, the stamp
  and its angle, or the selection's turn / mirror / copy / delete.
- **Dock** (right): **Assets**, **Inspector**, **Map** tabs.
- **Status bar**: the cell under the cursor, and the tool's help.

## Assets
Search box, a RECENT row, then drawers (Nature, Village, Building interior, Ruins and dungeon,
Interactables, Placeholders, Markers, Unsorted), each with groups (Building interior > Furniture,
Hearth and light, Storage). Drawers fold; the maker remembers which (`user://map_maker.cfg`).

- Click a tile, then click the map (drag for a row of small props), or drag the tile straight onto the map.
- A ghost shows where it lands: green fits, red doesn't (off the ground, or an explore-only piece on a
  battle map).
- **R** turns it to its next painted angle; a sprite painted from one angle mirrors instead. **M** mirrors.
  An odd turn swaps the footprint (a 2x1 table becomes 1x2).
- Props from another tile set are borrowed (`village_in/prop_hearth` in a dungeon); `base/` entries take the
  map's own set's version (a crate in a dungeon is the dungeon crate).
- New art: any `prop_*`, `b_*` or `ph_*` PNG in `game/art/source/battle/` (or a set folder) shows up under
  Unsorted at once. Give it a row in `data/catalog.csv` (drawer, group, footprint, height, sight) to sort it.
- More angles: put `<sprite>_r1.png`, `_r2`, `_r3` next to the sprite (a quarter turn each).

## Select and the Inspector
Select (V) picks a thing, the party start or a battle piece first, then a prop. Drag moves it; R, M,
Del, ctrl D (copy it to the stamp); alt click with any tool picks up what's under the cursor. The Inspector
shows its fields, and **On this map** lists every interactable, blob and named prop (click to fly to it).

- **Props**: angle, an optional id, height, how much sight it blocks, can be stood on, a note.
- **Blobs** (Placeholders): name, width, depth, height, a note. Its sprite is `ph_<name>`; when
  `game/art/source/battle/ph_<name>.png` exists it draws instead of the block, nothing else to change.
- **Interactables** (explore maps): id (unique on the map, `door_01`), kind, event (`data/explore_events.csv`),
  where an `enter` door leads and where you arrive, "gone if" flags, a note.

### Asking Claude for behaviour or art
Name the map and the id or blob, and write what you want in its note:
- "door_01 on goblin_cave_01: barred from the other side, a strong character can smash it" -> Claude adds an
  event row (options, checks, results) and points the door at it.
- "the Lich king throne blob on goblin_cave_01: make concept art with Picsart, show me, then put it in" ->
  once approved the art is saved as `ph_lich_king_throne.png` and the blob turns into it.
`python3 tools/map_notes.py [map]` lists every blob (and whether its art exists), interactable and note.

## Ground
- **Raise / Lower / Level / Smooth**: brush tools; each cell changes once per stroke. Right click on Level
  takes a cell's height.
- **Ground**: pick a swatch (grass, forest floor, road, stone, rock, ruin, water) and paint.
- **Path**: drag a course; it's painted `brush` cells wide in road, stone or grass, and stairs are cut where
  it climbs more than a level. "Follow ground" finds the easiest walk between press and release instead.
- **River**, **Stairs**, **Cut**, **Fill**, **Zone**: as before (river never runs uphill and falls at every
  drop; stairs join a cliff or run a flight; cut and fill shape the outline; zone paints another tile set).
- Where different grounds meet on one level they blend (see `docs/art/transitions.md`).

## Map tab
- **Map**: name, kind (battle map in `data/maps`, explore map in `data/explore`), size and resize.
- **Look**: tile set, look, "Use this view as the map's angle" (players only ever see that angle; turning
  while editing doesn't change it), cliff depth, forest rings, strangeness.
- **Generate**: seed, new valley, next seed, roughen outline, link with stairs, templates.
- **Keys**: every shortcut.

## Keys
Drag paints, right drag does the opposite. Shift drag, middle drag or two fingers pan; arrows pan; wheel or
pinch zooms; space fits. Tools: V B X 1 2 3 4 P L W T C F Z. R turn, M mirror, Del delete, Esc deselect,
ctrl D copy to the stamp, alt click pick up, [ ] brush, Q turn the view (editing only), G grid, H hide
panels, ctrl Z undo, ctrl shift Z redo (80 steps), ctrl S save.

## Saving
- Battle maps save to `game/data/maps/<name>.json`, explore maps to `game/data/explore/<name>.json`
  (`user://` when the project folder is read-only). Things, start, groups and the rest of the file are kept.
- Props save their extras only when set: `face`, `flip`, `id`, `blob`, `name`, `note`
  (`CombatGrid.PROP_EXTRA`). Things save `note` alongside the fields the explore scene reads.

## Play test
Play test saves, then a battle map opens in the combat sandbox with the fight started, an explore map in the
explore scene at its start. F8 comes back.

## Command line
From `game/`:
- Screenshot the maker: `godot --path . -s res://tools/maker_shot.gd -- out.png explore/home "item:blob_2x2,stamp:5:4"`
  (steps in `tools/maker_shot.gd`). In the cloud: `xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x1000 ...`.
- Screenshot a map with its look: `godot --path . -s res://tools/map_shot.gd -- out.png <map> [turn] [grid]`.
- Save a recipe as a battle map: `godot --headless --path . -s res://tools/map_build.gd -- highland alpine`.

## Tests
`game/tests/test_maps.gd`: the look, map ops (smooth, path), recipes, prop extras round trip, the catalog,
the maker scene (sculpt, undo, stamping props, blobs and doors, unique ids, notes, moving, deleting, the
start, battle maps refusing things), ground blend ranks.
