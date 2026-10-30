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

## Fights (step 3)
- Reach, distance and helpers measure on ground cells, so melee between a deck and the lane beside it is a height gap like any cliff (`MELEE_REACH`), and a piece straight under a deck is never next to the piece on it.
- **Pushes** (`CombatRules.push_place`): a shoved piece lands on the highest floor at the next cell it isn't pushed up into. Along a bridge or from a level bank onto one, it stays on top; off the side or end of a deck it falls to the ground (fall damage as usual); in the lane it slides under the deck. Under a deck too low to walk under it bumps.
- **Blasts** (`CombatRules.area`): aimed at a deck, the blast covers the deck where the deck goes on and the ground past its edge; aimed in the lane, the deck over it shields whatever stands on it.
- **Guard zones**: the ring shows only places the guard can hit (as holding already required), so a guard on a bridge doesn't ring the lane three levels down.
- Cell-aimed abilities and the danger zone list deck places too. The AI moves through `reachable` and `walk_distance`, so it walks bridges and lanes.

## Drawing (step 4)
- `CombatBoard` has a DECK slab per depth, after that depth's pieces: the deck slab, overlays on deck places (highlights, danger, area, guard ring, goals, the cursor), props standing on decks, then the pieces on decks. So a deck covers the lane's pieces at its depth and sits under its own.
- A deck draws as a slab `DECK_THICK` deep with the ground's top and side art (graybox colours without it). Side faces and outline only where the deck ends, so a run of deck reads as one bridge.
- A piece under or behind a deck: with `deck_window` on, the deck (and a prop on it) goes see-through while the piece stands there; off, the deck stays solid and the piece gets the ghost copy and foot ring. Which one is a design call on the desk (card `dev-deck-covered-piece`); the window is on until it's answered.
- Picking returns the deck place where the deck's top is under the mouse, the lane cell elsewhere. Drawing helpers (`_diamond`, `cell_top`, `_depth_at`, `hidden`, prop rects) take places and draw at the ground cell.
- Test picture: `tools/godot.sh --path game -s res://tools/map_shot.gd -- out.png demo:bridge 0 [nowindow]`.

## Sight (rule for map checks; built in step 5)
A deck is a slab `DECK_THICK` (1) level thick under its floor. A sight line through the cell between `h - 1` and `h` is blocked; above it (on the deck) or below it (in the lane) it passes.

## Still to come
5. Sight and fog per layer. 6. The map maker paints decks (map builder), and real deck art.
