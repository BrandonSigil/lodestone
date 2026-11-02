# Plots (road-fight skeletons)

A plot is the hand-drawn skeleton of a road fight: which cells are map, which terrace each stands on, where the road,
river, bridge, stairs, rocks and woods go. A fight's map is a plot plus a seed. [USER] 2026-11-01 battle-maps plan:
"clean up the UI to make Plots and pre-seed it with 5-6 that seem good to you and that I can tinker with later."
Why plots: `docs/design/battle-maps-research.md`.

Code: `game/scripts/combat/map_plot.gd` (`MapPlot`: load, build, problems), `game/scripts/maker/plot_maker.gd` (the
screen), `scenes/plot_maker.tscn`. Files: `game/data/plots/<region>/<id>.json`. Starter set:
`tools/plots/seed_plots.py` (it will not overwrite a plot without `--force`, so Brandon's edits are safe).

## The file
- `levels`: one string per row. `.` outside the map, `0` to `3` the terrace (low to high; 2 heights apart, so every
  terrace edge is a cliff a stair climbs).
- `marks`: one string per row, same size. ` ` plain ground, `d` road, `w` river water, `b` bridge (a straight run with
  dry banks at both ends), `s` stairs, `r` rock outcrop (one height up: cover), `t` woods.
- `river`: `flank` (along one side, no bridge), `crossing` (between the starts, with its one bridge) or `""`.
- `draft` (optional): `true` keeps it out of road fights while it is being drawn.
- `flip` (optional): `false` or `true` pins the top-to-bottom flip.
- `note`: the designer's note. The party starts on the low-x columns, the foes on the high-x columns.

## A seed
`MapPlot.build(plot, seed)` keeps everything the plot drew and varies only: a top-to-bottom flip (a plot's `"flip"` key pins it, so a bowl or river bank faces the camera), a one-height lift,
patches of one-height ledges inside quiet terrace cells, noise clumps of trees (ledge and tree amounts vary by seed) (never in the start columns). Then dead
stairs flatten, `MapOps.link` joins any cut-off ground (no bridges over water) and `seal_unreachable` voids the rest.

## In the game
`MapGen.road_fight(seed, region)` picks a region's finished (non-draft) plot by seed and builds it (up to 8 tries, each must deploy both
sides and have a land route); a region with no plots falls back to `MapGen.valley`. The combat scene calls it with the
road's `art_set` region (`town` to `forest_roads` is `forest`). Test: `test_forest_plots_make_fights`.

## The plot maker
Open it from the map maker's top bar (**Plots**); the X, Esc or **Map maker** go back. Top bar: the region (Forest or Snow), the plot picker, New,
Save, Undo, the river's job, Draft. Left: brushes (the four terraces, Outside, and each mark, each with its swatch), the start
legend (party blue on the left two columns, foes red on the right two). Middle: the sketch, centred; left click paints,
right click clears a mark (or makes a plain cell Outside). Roads draw joined to their neighbours, stairs as treads,
rocks and woods as round marks, and a dark line marks every drop to a lower terrace. Right: the note, a flat mini-map
of one seed in the same colours, **Another seed**, **Open in 3D** (the seed as a battle map in the map maker,
`user://maps/plot_preview.json`), and the checks as ticks and crosses (the plot's own problems, then reach, deploy
room, crossings and route for that seed). Screenshot:
`tools/godot.sh --path game -s res://tools/plot_maker_shot.gd -- out.png [region/]id`.

## Box bar
Seeds are judged with `python3 tools/map_shape.py --fight` ([AI] 2026-11-01, see `FIGHT` there: fill <= 0.62,
edge >= 1.3, corners >= 14, bays >= 0.3, levels >= 7, climbs >= 4). A 21 x 18 fight with two flat deploy bands can't
wind like an explore map, so the standard bar (fill 0.45, edge 1.8) fails every fight map ever made. MapQA's box check uses the same bar for battle maps up to 26 x 26 (`fight_box_*` in `game/data/map_qa.csv`, `MapQA.FIGHT_MAX`); bigger maps and explore maps keep the standard `box_*` bar. On 2026-11-01 every seed of the three finished plots passes it. Every older saved battle map in `data/maps` still fails it (arena_c, god_road, highland, the blend and test maps: fill 0.66 to 0.93).

## The plots (2026-11-01)
Road fights use each region's finished plots; drafts (`"draft": true`, "(draft)" in the plot maker) are starts for
Brandon to tinker with, and every one of them failed the look check.
- **forest, finished (5):** bend (the road bends under a high shoulder; the flank river follows the bend), bridge_crossing
  (a river between the starts, one bridge on the road), switchback (the road zigzags up three terraces), lakeshore (the
  road curves round a lake under a bluff), falls (a river steps down the slope in falls between the starts, one bridge;
  ice_bridge's plan mirrored).
- **forest, drafts:** hollow, rocky_pass, fork (a road looping round a knoll), gorge (a deep river gorge).
- **snow, finished (2):** ice_bridge (frozen falls between the starts, one bridge), frozen_lake (lakeshore's plan
  mirrored, on a frozen lake).
- **snow, drafts:** cliff_road (a road on a cliff ledge above a snowfield), zigzag (long zigzags up a slope),
  snow_switchback (switchback's plan mirrored).
- What passed every time: water with one clear job (falls, a lake, one bridge) and an open winding road. What failed:
  terraces that read as stacked slabs, low knolls, thin hidden rivers. A plot whose feature hides behind high ground
  when mirrored top to bottom pins `"flip": false`.
- Seeding: `tools/plots/seed_plots.py --only=<ids>` (never rewrite plots Brandon has touched; `--force` only with
  `--only`). `Plot.mirrored` copies a proven plan into another region as its own file.
- A straight run of two or more `s` cells is one flight (`MapOps.flight`) from the cell before it to the cell after it,
  so a climb over two terraces is drawn as two stairs. `MapPlot.build(..., join = false)` skips link and seal, to find
  pieces a plot leaves cut off (link joins them with stair decks that read as stray bridges; sealed ones turn to rock
  pillars).

## Deploy across bridges (2026-11-01)
`CombatGrid.main_ground` now walks over bridge decks (`places_next`), listing only ground cells. Before, a bridge joining the two starts was not walked, so the far bank fell out of the main ground and the foes deployed next to the party (seen on bridge_crossing). Test: `test_forest_plots_make_fights` checks the foes start on their own edge.
