# Decks: two-level cells

[USER] 2026-10-30 (card `builder-city-overpass`, picked "Real two-level bridges"): a cell can hold a second walkable floor over it, a deck. A bridge you walk on, with a lane you walk under. Built by the systems developer in steps (World roadmap, "Two-level 1" to "6").

## Places
- A **place** is a `Vector2i`. A cell is its own ground. The same cell with `CombatGrid.DECK` (4096) added to y is its deck: `CombatGrid.deck_of(cell)`. `ground(place)` strips it, `on_deck(place)` tells them apart, `places_at(cell)` lists both.
- Everything that takes a cell takes a place: `height_at`, `terrain_at`, `passable`, `step_cost`, `can_step`, `prop_at`. So unit cells, highlight and path tables and saves keep their `Vector2i` keys.

## In the grid (step 1)
- `CombatGrid.decks`: ground cell -> `{"h": floor height, "t": terrain}`. `add_deck(cell, h, t)`, `remove_deck(cell)`. Floor terrain: stone (`s`), road (`d`) or stairs (`t`, so a flight can climb onto a deck).
- The lane under a deck stays walkable only when the deck is at least `DECK_CLEAR` (2) levels over its ground.
- No step goes straight between a deck and the lane under it; a deck joins the cells beside it by the usual jump and stair rule, at its own height.
- A prop whose anchor is a deck place stands on the deck (a house on the bridge): its footprint blocks the deck, not the lane.
- In the map JSON: `grid.decks` `[{"x", "y", "h", "t"}]` (t a terrain letter), and a prop entry with `"deck": true`.

## Walking (step 2)
- Every walk looks one step along a direction at `grid.places_next(place, d)`: the next cell's ground and its deck. So paths, reach, deploy rings, combat moves (`CombatRules.reachable`), the AI's walk distances and `MapOps.reach` all go over a bridge and under it, and a path can hold deck places.
- Free walking (WASD) keeps the walker's level: `ExploreRules.slide` takes the leader's place, and `grid.step_place(from, cell, jump)` picks the place at the next cell it steps onto (the walkable one nearest its own height). From the bank that is the deck; from the lane it is the lane.
- Distances (`CombatRules.dist`, `ExploreRules.dist`) and drawing positions (`unit.vis`, move and push animations, facing) use `ground()`. Seen cells (`known`) are ground cells: seeing a cell is seeing its deck until step 5.

## Sight (rule for map checks; built in step 5)
A deck is a slab `DECK_THICK` (1) level thick under its floor. A sight line through the cell between `h - 1` and `h` is blocked; above it (on the deck) or below it (in the lane) it passes.

## Still to come
3. Fights on two levels (reach, guard zones, pushes and falls off a deck, the AI). 4. Drawing the deck slab and what stands on it (with the map builder; the see-through window opens it over a piece underneath). 5. Sight and fog per layer. 6. The map maker paints decks (map builder). Until step 4, a map with decks loads and saves but doesn't draw them.
