# Map look: valley staging, grass lips and the map maker

Status: **Built (AI), 2026-10-28.** The goal is Brandon's (`docs/decisions.md`, "Map look and map maker"): every map, battle and exploration, set up like his mountain valley reference. Everything below that isn't quoted from him is a proposal until he retags it `[USER]`.

How to use the tool: `docs/systems/map-maker.md`. Code: `game/scripts/combat/` (`map_look.gd`, `map_backdrop.gd`, `map_dress.gd`, `map_ops.gd`, `map_gen.gd`, `combat_board.gd`) and `game/scripts/maker/`.

## 1. What the reference does

| In the reference | What it does for the picture | How the game does it now |
| --- | --- | --- |
| Sky, a few flat clouds, two ranges of snow peaks | Places the map in a world; gives the top of the screen something calm | Backdrop bands drawn behind the board (section 3) |
| A dark pine forest the map sits in | The map is a clearing, not a slab in a void | A skirt of tree rings around the outline, over a forest floor (section 3) |
| Big trees overlapping the bottom of the map | Frames the scene and gives depth in front | The skirt's front rings stand bigger and fade when they would hide a piece |
| Tall grey cliffs down to the forest floor | Height reads at a glance | Outer cliffs run down to the look's floor, 5 to 7 levels below height 0 |
| Terraces two or three levels apart | Every step is a cliff, not a ramp; high ground matters | Authoring rules (section 7), the generator and recipes |
| Carved stairs, a bridge, narrow ledges | Choke points between terraces | Stair cells, flights, stone bridges (section 6) |
| Waterfalls between levels | Water explains the terraces and moves | Rivers that never run uphill; every drop is a fall (section 5) |
| Grass hanging over every cliff edge, with drips | Softens every block edge; the signature of the look | Lips cut from the top texture (section 4) |
| An irregular outline | Not a 20 x 20 board | VOID cells, ROUGHEN, CUT (section 7) |

Before this, maps sat on a near-black background (or the paper card), the outer faces stopped a level or two under the ground, most steps were one level, and cliff edges were hard lines.

## 2. The pipeline

1. **Map data**: `CombatGrid` holds heights, terrain, per-cell tile set zones, placed props, and now `look` (which staging and overrides). Saved in the same JSON as before.
2. **Editing**: `MapOps` is every map operation (raise, level, paint, cut, fill, river, stairs, flight, link, road, roughen, props). The map maker's brushes, the valley generator (`MapGen`) and hand-laid recipes (`MapRecipes`) all go through it, so a generated map is an ordinary map you keep editing.
3. **Dressing**: `MapDress` turns raw cells into what gets drawn: the skirt rings, the lip drip profile, the run of each stair. Pure functions, tested headless.
4. **Look**: `MapLook` reads one row of `data/looks.csv`: staging, floor depth, skirt rings, mountain shape, skirt trees and eleven colours.
5. **Board**: `CombatBoard` draws it all. The same board runs battles, the combat sandbox, exploration and the map maker, so what you build is exactly what you fight on.

## 3. Staging and the backdrop

`data/looks.csv`, one row per look:

| Column | Meaning |
| --- | --- |
| `staging` | `valley` (sky, mountains, forest), `island` (the floating island on the paper card), `plain` (nothing around it: interiors) |
| `floor` | Valley: the level the outer cliffs drop to (-6 = six levels under height 0) |
| `skirt` | Valley: rings of forest cells around the outline (holes inside the map get them too) |
| `ridge` | Mountain shape: `peaks`, `hills`, `mesas`, `spires` or `none` |
| `trees` | Skirt tree sprites, `|` separated. `set/stem` borrows another tile set's art, `base/stem` the base art |
| `tree_scale` | Skirt tree height in tile widths |
| colours | `sky_top`, `sky_low`, `cloud`, `far`, `near`, `snow`, `haze`, `wood_far`, `wood`, `floor_col`, `tree` |

A map picks its look with `grid.look.id`; with none, it takes the row named like its tile set, else `forest`. `grid.look` may also override `staging`, `floor` and `skirt`. Strangeness drifts the colours toward the `crystal` row (Earth to Alien).

Rows today: `forest`, `alpine`, `snow`, `canyon`, `marsh`, `ruins`, `farmland`, `village`, `dungeon` (dark, no mountains), `crystal`, `village_in` (plain) and `island`.

**Valley staging**, back to front:
- Sky gradient, flat clouds, a far and a near mountain range, a far and a near treeline, then the forest floor. Each band slides a little with the camera (clouds most, near trees least), so panning a big map feels deep. Code-drawn flat shapes in the look's colours.
- The board's outer cliffs run all the way down to `floor`.
- The skirt: `skirt` rings of cells around the ground. Each holds a big tree (sometimes two, sometimes none) from the look's `trees`. The first ring keeps the trees' own colours, since it belongs to the map; each ring further out sinks toward the backdrop forest's colour, like the reference's dark foreground. Next to the ground the wood thins so the cliffs still show. Trees in front of the map stand bigger and go see-through when they would hide a piece, the cursor or a highlighted cell.
- In exploration the backdrop dims under fog, so what the party has seen stands out.

## 4. Grass lips

The question was how to paint the grass so it hangs over the edge. The answer here is to cut it from the top, in code:

- Along every edge where a cliff face shows (the two faces toward the camera, at any camera turn), a band is cut from the **same top texture** and hung down the face. Its texture coordinates carry on from the top across the edge, so it reads as the grass folding over, not a second material.
- The band ends in drips: `MapDress.lip_profile` gives three drips per cell edge, shallow notches between them and now and then a long one. The pattern is a function of world position, so it runs on unbroken from cell to cell, and every edge starts and ends at the same depth, so lit and shade lips meet at the corner. It is never deeper than the drop, and a drop too small for a lip gets none.
- It darkens toward the drips, casts a soft shadow onto the face, gets a thin ink line along the drips and a pale highlight just under the edge (the rounded lip catching the sun).
- Depth per terrain lives in the `lip` column of `battle_art.csv` and `battle_art_<set>.csv`, in levels: grass and forest 0.75, road 0.45, rock 0.35, stone, stairs, water and ruin 0.

Why not paint the moss into the cliff side texture (B8, B15)? A side strip with moss painted at its top needs to match the top it hangs from. It breaks when a zone or strangeness recolours the top, it repeats visibly along a long wall, it needs a corner piece for every angle, and it can't follow a drop of any height. A lip cut from the top always matches its top, on every tile set, including sets that don't exist yet.

Update 2026-10-28: the soft terrain pass (`docs/design/terrain-engine.md`) draws this lip as one unbroken band along a cell's whole outline, round its rounded corners, with the drips fixed to screen position. A set that paints its cap into the sides (`cap` column) gets a lip as thick instead.

Later, if Brandon wants a hand-drawn drip silhouette, a `lip_<terrain>.png` mask strip could replace the code profile without changing anything else (section 9).

## 5. Water and waterfalls

- `MapOps.river` digs water along a path, `depth` levels under the ground, and never lets it run uphill. Wherever the ground steps down, the water steps down too, and the drawn face becomes a waterfall with foam at its foot.
- Width 2 floods the cell beside each step, for a wider river.
- Water at the outline pours off the map into the forest (the spill).
- Falls animate in their own layer, so they don't cost a ground redraw (section 8).

## 6. Stairs, flights and bridges

- A stair cell sits between a low and a high neighbour. `MapDress.stair_run` finds which way it climbs; the steps are cut into the cliff from the low side to the high side and a piece standing on it is mid-flight.
- `MapOps.stairs` turns one cell at a cliff into stairs at the height that joins both sides. `MapOps.flight` lays a straight run from the bottom to the top of a cliff of any height, stepping evenly, so a Jump 1 piece can climb it.
- `MapOps.link` joins every walkable part of the map to the biggest one with stairs where the climb is 4 levels or less.
- Bridges are stone cells across water at the height of the banks.

## 7. Authoring rules for verticality

These are what make a map look like the reference. The generator and the `highland` recipe follow them.

- **V1** Terraces are two or three levels apart, so each step is a cliff. One-level steps are walkable with Jump 1 and read as a slope; use them sparingly.
- **V2** High ground at the back, low ground at the front, so cliffs face the camera and the map reads as a whole. A low river along the front is a good base.
- **V3** Every terrace is reachable through stairs or a bridge (LINK WITH STAIRS does this). The highland test checks every dry cell is reachable from the meadow.
- **V4** Choke points: a one or two cell flight, a bridge, a ledge between a cliff and water. Two to four per battle map.
- **V5** Water runs downhill and falls at every terrace step. Two or three falls per map.
- **V6** Pines in clumps on the high ground and at the back; scattered on the front terraces, so pieces at the front stay visible. Boulders on high rims.
- **V7** The outline is ragged, never a rectangle: cut the corners, notch the edges, leave no stray scraps.
- **V8** Battle maps 20 to 30 cells across; the maker allows up to 48.
- **V9** No one-cell zigzags: edges run at least two cells straight between turns (Tidy, `MapOps.tidy`, `MapOps.steps`).
- **V10** Two to four single-cell rock pillars on high rims and in front of cliffs (Pillar, `MapOps.pillars`).
- **V11** Rivers run level and fall in a few drops of two levels or more (`MapOps.river` with `min_fall` 2).
- **V12** Roads draw as smooth ribbons through their cells (`TerrainShape.ribbons`).

V9 to V12 come from the painted look (`docs/design/terrain-engine.md` section 5); the generator and the highland
template keep them.

## 8. The renderer: slabs

The board used to redraw every tile, prop, lip and tree every frame. With the backdrop, skirt and lips that cost about 340 ms a frame on `highland` in the cloud's software renderer. It now draws through cached layers ("slabs"), child nodes of the board:

- `BACK` (backdrop), then for each depth row `GROUND` (faces, lips, tops, stairs, grid lines), `OVER` (waterfalls, highlights, hover), `PROPS` (props, fog veil, skirt trees) and `UNITS`, then `TOP` (x-ray ghosts, floating numbers).
- `GROUND` and `PROPS` are cached. A row redraws only when a cell within two rows of it changes, when fog newly reveals a cell, or when a prop or skirt tree starts or stops fading. A change to the tile set, look, camera turn, grid lines or fog switch redraws everything once.
- `OVER`, `UNITS`, `BACK` and `TOP` redraw every frame (they animate). The backdrop bands are built once into triangle lists and stamped with one call per repeat.
- Result on the same machine: `highland` 340 ms to 87 ms a frame, a 48 x 48 map 818 ms to 129 ms; of that, about 10 ms is the game's own work and the rest is the software rasteriser. On a real GPU expect a small fraction.
- For anyone adding board drawing: draw helpers paint on `_ci` (the slab being drawn), not on `self`. A `draw_*` call on the board itself, from any of these helpers, fails.

## 9. Assets: what is code now, and the slots for painted art

Everything new here is flat shapes in code or existing tile set art mixed through data. Nothing new was painted or generated.

| Piece | Now | Slot for painted art |
| --- | --- | --- |
| Sky, clouds, mountain ranges, treelines | Code bands in the look's colours | Proposal: wide strips per look in `game/art/source/looks/<look>/` (`sky`, `far`, `near`, `wood_far`, `wood`), repeating every 1600 px. Not wired yet. |
| Skirt trees | The look's `trees` column (tile set pine sprites) | Any prop sprite; a dedicated big `prop_skirt_*` pine per set would look best |
| Lip | Cut from the top texture | Proposal: `lip_<terrain>.png` drip mask per set. Not wired yet. |
| `alpine` tile set | No art of its own: forest tops, masonry cliffs and snow pines through `data/battle_art_alpine.csv` | Drop a base-named file into `game/art/source/battle/alpine/` and it replaces the borrowed one |
| Waterfalls, foam, spill, stair steps | Code | Unchanged |

## 10. How this fits the backdrop proposal

The open "Merge village-map..." PR (#55) carries Brandon's `[USER]` call that every environment gets a backdrop: the floor sits in a world that continues past its edge, for battle and explore maps alike, plus an `[AI]` proposal (`docs/art/environments.md`) of one painted plate per art set with no parallax (E4). Valley staging is that rule for outdoor maps, drawn in code from the look's colours; the `dungeon` look is the dark version for underground maps, and `village_in` stays a plain room. Painted plates can replace the code bands later through the slots above. The one real difference is parallax: this build slides the bands gently with the camera; E4 says none. That's Brandon's call (question 2 below).

## 11. Open questions for Brandon

1. Keep the code-drawn backdrop bands (they follow the look colours and strangeness for free), or have painted strips made per look?
2. Backdrop parallax: keep the gentle slide when panning, or lock it (environments E4)?
3. Battles on big maps fit the whole map on screen. Should fights zoom in closer and follow the action?
4. Which look should a map with no look of its own get? Today it takes the row named like its tile set (the forest set gets the green `forest` valley; `highland` uses `alpine`).
