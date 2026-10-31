class_name BridgeKit
extends RefCounted
## The bridge kit ([USER] 2026-10-30: "design bridges as assets and handle them beautifully in game ... draw between two
## pieces of landing with a river in the middle, and the bridge will dynamically get built over all of it"; "build
## these grey boxes for now in-engine, then later we can replace them with assets"). A bridge is a run of deck cells
## flagged `bridge`; each cell is one of six one-tile pieces, named like the art runner's guide (tools/art/bridge_guide.py)
## so art can replace them one by one: drop `res://art/source/battle/bridge/<piece>.png` in and the board draws it instead
## of the grey boxes.
##   deck_a / deck_b   a straight deck along x / along y (rails both sides)
##   corner            a turn (arms to the connected sides)
##   landing_a / _b    an end that meets the ground, along x / along y
##   pillar            a support from under the deck down to whatever is below
## The deck stands at the landings' height (a step if they differ by one); the ground under it is not changed.

const PIECES := ["deck_a", "deck_b", "corner", "landing_a", "landing_b", "pillar"]
const DIR := "res://art/source/battle/bridge/"
const SIDES := {"w": Vector2i(-1, 0), "e": Vector2i(1, 0), "n": Vector2i(0, -1), "s": Vector2i(0, 1)}


## Which sides of a bridge cell carry on: another bridge deck, or ground it lands on at about its height.
static func connections(grid: CombatGrid, c: Vector2i) -> Dictionary:
	var out := {}
	var h := grid.height_at(CombatGrid.deck_of(c))
	for k: String in SIDES:
		var n: Vector2i = c + SIDES[k]
		var on := false
		if grid.has_deck(n) and (grid.decks[CombatGrid.ground(n)] as Dictionary).get("bridge", false):
			on = absi(grid.height_at(CombatGrid.deck_of(n)) - h) <= 1
		elif grid.in_bounds(n) and grid.solid(n) and not grid.has_deck(n):
			on = absi(grid.height_at(n) - h) <= 1 and grid.terrain_at(n) != CombatGrid.T.WATER
		out[k] = on
	return out


## The kit piece a bridge cell is.
static func piece_at(grid: CombatGrid, c: Vector2i) -> String:
	var k := connections(grid, c)
	var along_x: bool = k.w or k.e
	var along_y: bool = k.n or k.s
	if along_x and along_y:
		return "corner"
	var ends := 0
	for s: String in ["w", "e", "n", "s"]:
		if not k[s]:
			ends += 1
	if along_x:
		return "landing_a" if _lands(grid, c, k) else "deck_a"
	if along_y:
		return "landing_b" if _lands(grid, c, k) else "deck_b"
	return "deck_a"


## Does the open side of this cell meet ground (a landing) rather than just end?
static func _lands(grid: CombatGrid, c: Vector2i, k: Dictionary) -> bool:
	for s: String in SIDES:
		if k[s]:
			var n: Vector2i = c + SIDES[s]
			if not grid.has_deck(n):
				return true
	return false


static func art(piece: String) -> Texture2D:
	var path := DIR + piece + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
