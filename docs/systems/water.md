# Moving water

All water in the game is drawn this one way: every map, both looks (the soft terrain pass outdoors and the block look of interiors and the map maker's K), falls between terraces and spills off a map's edge. There is no other water code; the old textured tops, code-drawn falls, foam puffs, rim spills and graybox streaks are gone. It keeps the flat painted look: hard-edged shapes in two or three values of the tile set's own water colour, plus white.

The one thing that changes from map to map is the colour: each tile set's water is the average of its `top_water` art (pale on snow, deep blue in the forest), drifted toward the alien palette with strangeness. The `top_water` and `side_water` pictures are no longer drawn; only that average is used.

## What you see
- **Surface** (`game/shaders/water_surface.gdshader`): the set's water colour; a lighter shallow band and a thin white line along every bank that laps in and out, with a faint ripple leaving the bank now and then; a few flat darker patches and short wavy white dashes drifting down the river (slower near the banks); where a fall lands, boiling foam clouds, flecks of foam riding away and rings spreading from the foot; rings round anyone standing or walking in water.
- **Falls** (`game/shaders/water_fall.gdshader`): the sheet bends white over the lip and lighter and darker streaks pour down it.
- **Splash caps** (same shader): a band of white foam puffs over every seam where a fall meets the pool below, reaching up over the sheet's foot and out onto the water, the lower half in a soft blue shadow; the puffs slowly swell and a few flecks are thrown up. It thins out where the sheet stops against rock. It hides the hard line between the sheet and the pool.
- **Colour**: the set's water colour is drawn a little richer (more saturated), and everything that moves (dashes, ripples, rings) is a lighter tone of the water, not white, so the river stays calm. Foam and the bank line are the whitest marks.
- **Spills**: water running off the map's edge has no pool to land in: its sheet pours on down (on a floating island, past the rock rim) and thins out into mist.
- **Banks**: a bank poking into water rounds off wide and the bank fills in wide where the water turns, so a river stepped cell by cell reads as one that winds (`TerrainShape.WET_ROUND`, `WET_FILLET`, `WET_MAX`).

## How it works
- The board paints every depth in slabs, in either look. Water adds two: **WATER** (under that depth's GROUND, so the banks, their rounded-off corners and fillets draw over it) holds the surface of water cells and the water a bank's rounded corner shows; **FALLS** (over GROUND) holds the fall sheets on the river walls and, in the pool cell's own FALLS slab (so after the pool is drawn), the splash caps over the seams. Both hold still geometry; the shaders move it with `TIME`, so water costs nothing to redraw per frame. The falls' pen outlines stay in the OVER slab.
- Surface vertices carry the grid point as UV and the cell's water colour as COLOR. Fall vertices carry UV.x along the screen (streaks run on across cells), UV.y in levels down from the lip, and the drop / 10 in COLOR's alpha. Splash cap vertices carry UV.y from -1 (top) to -2 (bottom), which is how the fall shader tells them apart, and how full the cap is in COLOR's alpha.
- Spill vertices carry UV.y from 100 at the lip and their length / 20 in COLOR's alpha.
- `WaterField` (`game/scripts/combat/water_field.gd`, pure, tested in `tests/test_terrain.gd`) bakes a small RGBA picture of the map, 6 texels a cell: R the distance to the nearest bank (rounded corners and fillets included; lower ground and the map's edge are not banks, the water pours away there), G and B the flow (`TerrainShape.flow`), A the churn below falls. The board rebuilds it when a map loads (about 30 ms on the village); in the soft look an edit only redoes the cells near it and wherever the flow turned, in the block look (square banks, no shape caches) any edit redoes it all.
- Wakes: `CombatBoard._update_wakes` passes up to 8 units standing in water to the surface shader each frame.

## Tuning
- Surface shader: `speed` (cells a second), the dash lattice `CELL`, keep share (`h.x > 0.42`), length and wave in `dashes()`; patch cut 0.74; bank line `edge` 0.085 and width 0.016; foam cut 0.5 on churn; ring spacing 2.4.
- Both shaders: `richness` (1.22, how much richer the water's colour is drawn) and `glint` (about 0.4, how far moving marks go from the water's tone toward white; lower is calmer).
- Fall shader: `speed` (levels a second), streak cuts 0.62 and 0.84; the cap's puff sizes in `cap()`. The cap's size is `CombatBoard.CAP_UP` (1.4 levels up the sheet) and `CAP_OUT` (0.75 cells out onto the pool), which must match the shader's `cap_px` and `cap_seam`; `CAP_FADE` is how it thins where a sheet stops against rock.
- `WaterField.SHORE_REACH` (how far out the bank is felt), `CHURN_REACH` (how far a fall churns the water), `PER_CELL`.

## Known limits
- The water's back edge against a bank face is not antialiased (the Compatibility renderer has no 2D AA); the same as before.
- Rocks or posts standing in water get no foam ring yet (no map puts a prop on water). A prop on a water cell would be the hook: treat its footprint as a bank in `WaterField._around`.
