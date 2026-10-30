# Ambience

[USER] 2026-10-30: "Have the trees bend slightly in the breeze. Add some snow falling effects. Just a sprinkle of attention to detail and some motion to give maps life."

## Trees in the wind
- `shaders/sway.gdshader` sits on the board's props slabs. A draw whose colour alpha is a sway mark (`CombatBoard.SWAY_TREE` 254/255, `SWAY_BUSH` 253/255) leans from its base, more toward the top: about 2.6 board pixels at wind 1, in a slow wave across the map with a gentle gust, so neighbouring trees are a little out of step. Every other draw is untouched, and the slabs stay cached: only the vertices move with `TIME`.
- Marked: a wood's own trees (forest cells), the forest skirt round the map, and placed props whose catalog row has `sway` (`data/catalog.csv`: 1 a tree, 0.5 a bush). A tree that's see-through over a piece holds still while it is (its window is a mesh of its own).
- How hard it blows: `wind` per look in `data/looks.csv` (0 still air indoors, 1 a light breeze); a map's own look (`grid.look`) can set `wind`.

## Snow and leaves
- `MapWeather` (`scripts/combat/map_weather.gd`), drawn over the board and under the frame. On explore maps it lives in the world ([USER] 2026-10-30: "locked to the map not to the screen"): a child of the board, falling over the whole map's board-pixel bounds (`fit_world`, refit on a turn), with the count scaled so it's as dense on screen as before, so it scrolls and zooms with the map. The world map keeps it in screen space. `weather` per look in `data/looks.csv`: `snow` (110 small flakes with a faint cool shadow, so they read over snowy ground) or `leaves` (16 fall leaves tumbling down). Seeded by the map, slow, drifting a little to the right. A map's look can set `weather`.
- The world map: `weather` on a place in `data/overworld_nodes.csv` (the pass: snow); snow falls only within `SNOW_REACH` of those places.

## Pictures
- `tools/godot.sh --path game -s res://tools/clip_shot.gd -- <out prefix> <map> <x>,<y> [frames] [every]` saves a run of frames for a clip (`--always-on-top` so the window keeps rendering).
