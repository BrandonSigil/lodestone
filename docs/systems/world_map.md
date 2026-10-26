# World map (riso)

Code: `game/scripts/world/`, scene `game/scenes/world_map.tscn`, shaders `game/shaders/world_ground.gdshader` and `world_fog.gdshader`. Data in `game/data/world/`. Drawing helpers and palettes come from the riso kit (`game/scripts/riso/`).

- The map is a 1920x1080 sheet with a folk stamp border. Wheel zooms, drag pans.
- **Regions** (`regions.csv`): each row is a seed point with a kind (fields, forest, hills, snow, mountains, water, mesa, floating, stalks, deep), a strangeness `s` and a `weight` (bigger = larger region). Borders are a warped Voronoi drawn per pixel by the ground shader; `WorldMap.region_hit()` runs the same math on the CPU so stamps land in the right region. Region colors are the riso palette at the region's `s`.
- **The Wall** (`lines.csv`, line `wall`): x as a function of y. Regions with `s >= 0.5` only exist east of it, so it is always a hard border.
- **Route** (`lines.csv`, line `route`): waypoints with a league `d`. The trail's `run.distance` maps onto it with `WorldMap.route_point(d)`. Waypoint 150 sits on the Wall gate, 300 at the end mark.
- **Landmarks** (`landmarks.csv`): village, farm, tower, pass, gate, ruin, spire, end. `name_key` is optional; empty means no label.
- **Stamps**: scattered on a jittered grid, density by kind, clumped by a slow sine. Trees and peaks turn strange on their own roll as `s` grows: pine, lollipop, glowing stalk; gumdrop, mesa, floating rock.
- **The Lodestone record**: the route is dark where anyone has walked (`meta.best_distance`), pale beyond. Diamonds are marks from every run (`meta.marks`), a flag marks the best distance, the red piece is the party when a run is out.
- **Discovery** (`discovery.gd`): `meta.revealed` is a list of circles `[x, y, r]`. A new save knows the village plus 170 units around it. A recall or finished run reveals the walked route (95 units either side, a circle every 10 leagues, 128 circles max). The map shows everything for now; the FOG PEEK button previews the fog of war shader on those circles.
- **Screens**: the village's MAP button opens it with no run (BACK returns to the village). The trail's MAP button opens it mid-run (BACK returns to the trail).
- Everything is a pure function of `MAP_SEED` (1 for now), so screenshots are reproducible.

## Changing the map (no code)
1. Move or add region seeds in `regions.csv` (max 24). Keep `s >= 0.5` rows east of the Wall.
2. Bend the route or the Wall in `lines.csv`. Keep route `d` running 0 to 300 with 150 at the gate.
3. Add label keys to `game/text/placeholder.csv`.
4. Run `tools/check.sh`. `test_world.gd` checks the route, the Wall split, strangeness along the route and the text keys.

Not yet: fog of war on by default, side trips off the route, region names from Brandon, a per-save map seed.
