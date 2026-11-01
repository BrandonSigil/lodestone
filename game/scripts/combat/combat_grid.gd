class_name CombatGrid
extends RefCounted
## The battle map: a height and a terrain type per cell.

## STONE is paved ruin floor. STAIRS let pieces climb STAIRS_CLIMB more levels than their Jump.
## RUIN is a broken wall or pillar: impassable, and it stands RUIN_RISE levels above its cell for line of sight.
## VOID is no ground at all: the island's outline. Nothing stands on it, nothing is drawn, sight passes over it.
enum T { GRASS, FOREST, WATER, ROCK, ROAD, STONE, STAIRS, RUIN, VOID }

const BLOCKED := 999
const STEP_COST := {T.GRASS: 1, T.FOREST: 2, T.WATER: 3, T.ROCK: BLOCKED, T.ROAD: 1, T.STONE: 1, T.STAIRS: 1, T.RUIN: BLOCKED, T.VOID: BLOCKED}
const COVER := {T.GRASS: 0, T.FOREST: 2, T.WATER: -2, T.ROCK: 0, T.ROAD: 0, T.STONE: 0, T.STAIRS: 0, T.RUIN: 0, T.VOID: 0}
## How far above the ground each terrain blocks sight (trees and boulders block a little, ruins a lot).
const SIGHT_BLOCK := {T.GRASS: 0.0, T.FOREST: 0.8, T.WATER: 0.0, T.ROCK: 1.0, T.ROAD: 0.0, T.STONE: 0.0, T.STAIRS: 0.0, T.RUIN: 2.0, T.VOID: 0.0}
const RUIN_RISE := 2
const STAIRS_CLIMB := 2
const MAX_HEIGHT := 24  ## editor and saved maps (was 8: [USER] 2026-10-30, maps with high vertical inclines)
## A saved height is one character a cell: 0-9, then a-z for 10 to 35 (old maps' 0-9 read and write the same).
const HEIGHT_DIGITS := "0123456789abcdefghijklmnopqrstuvwxyz"
const GEN_MAX_HEIGHT := 4  ## the random generator stays gentle; stairs keep it crossable
const PLATEAU_LEVEL := 4  ## the high floor of a plateau map (see _plateau)
const DEPLOY_COLS := 2  ## columns kept clear at each side for deployment
const DEPLOY_MIN := 6  ## starting cells each side needs; fewer on the main ground and the side borrows more
const NONE_CELL := Vector2i(-999, -999)
## Two-level cells ([USER] 2026-10-30, card builder-city-overpass): a deck is a second floor over a cell, a bridge
## you walk on with a lane you walk under. A place is a Vector2i: a cell is its own ground, and the same cell
## with DECK added to y is its deck (deck_of). Everything that takes a cell takes a place; ground() strips it.
const DECK := 4096
const DECK_CLEAR := 2  ## a deck stands at least this many levels over its ground for the lane under it to stay open
## For sight, a deck is a slab DECK_THICK levels thick under its floor: a line through the cell between
## h - DECK_THICK and h is blocked; above it (on the deck) or below it (in the lane) it passes.
const DECK_THICK := 1
const NO_PLACE := Vector2i(-1, -1)  ## step_place found nowhere to stand

var w := 0
var h := 0
var heights := PackedInt32Array()
var terrain := PackedInt32Array()
var zones := PackedStringArray()  ## per-cell tile set (BattleArt set name); "" = the map's own set
## Placed props (wells, carts, beds, whole buildings): anchor cell (back corner of the footprint) ->
## {"sprite": file stem, "foot": Vector2i cells, "tall": draw height in tile widths (0 = fit the footprint),
## "sight": levels it blocks sight above the ground, "walk": can pieces stand on it (rugs)}, plus the
## optional PROP_EXTRA keys the map maker sets (facing, mirror, an id, a placeholder blob's name, a note, an arch,
## and "open": footprint offsets "x,y|x,y" the prop leaves free, like the yard in a ^-shaped building).
var props := {}
## How the map is staged (see MapLook and docs/design/map-look.md): {"id": a row of data/looks.csv, and
## optional "staging", "floor", "skirt" overrides}. Empty = the look named like the tile set.
var look := {}
var version := 0  ## goes up on every height or terrain edit, so drawing caches know to rebuild
var decks := {}  ## ground cell -> {"h": deck floor height, "t": T} (see DECK)
## Cells a very short, thin wall stands on ([USER] 2026-10-30, card dev-crypt-half-walls: the walls between two
## floors "very short and not thick"): the cell shows as floor with the wall along its middle, nobody walks
## on it, and sight passes FENCE_HIGH over it. Walls maps set them (ExploreRules.shape_walls); not saved.
var fences := {}
const FENCE_HIGH := 0.5
var _prop_at := {}  ## every footprint cell -> its anchor (deck props: deck places -> deck anchor)
var _sight := {}  ## line of sight cache, cleared on any edit
## What abilities left on the ground this fight (not saved with the map): place -> [{"kind", "team", "turns",
## "src", "ability"}]. kind: trap, caltrops, fire, smoke (CombatRules.FIELD_*); turns: its maker's phases left.
var fields := {}


static func flat(width: int, height: int) -> CombatGrid:
	var g := CombatGrid.new()
	g.w = width
	g.h = height
	g.heights.resize(width * height)
	g.terrain.resize(width * height)
	g.heights.fill(0)
	g.terrain.fill(T.GRASS)
	g.zones.resize(width * height)
	return g


## Seeded map. Retries until the two deploy zones connect for a jump-1 unit. outline = irregular floor edge (IslandShape); false gives a plain rectangle.
static func generate(seed_value: int, width := 10, height := 8, strangeness := 0.0, outline := true, relief := 1.0, plateau := false) -> CombatGrid:
	for attempt in 20:
		var s := seed_value + attempt * 7919
		var g := _plateau(s, width, height) if plateau else _try(s, width, height, strangeness)
		if outline:  # an irregular floor outline (IslandShape), so the map is not a plain rectangle
			IslandShape.carve(g, s, DEPLOY_COLS)
		if g.connected(1):
			if relief != 1.0:  # a taller copy, kept only while both deploy zones still reach each other
				var tall := from_dict(g.to_dict())
				for y in height:
					for x in width:
						var c := Vector2i(x, y)
						tall.set_height(c, clampi(roundi(g.height_at(c) * relief), 0, 8))
				if tall.connected(1):
					return tall
			return g
	return flat(width, height)


static func _try(seed_value: int, width: int, height: int, strangeness: float) -> CombatGrid:
	var g := flat(width, height)
	var hn := FastNoiseLite.new()
	hn.seed = seed_value
	hn.frequency = 0.16
	var tn := FastNoiseLite.new()
	tn.seed = seed_value + 101
	tn.frequency = 0.3
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var hv := (hn.get_noise_2d(x, y) + 1.0) * 0.5  # 0..1
			var lvl := clampi(int(hv * (GEN_MAX_HEIGHT + 1.5)) - 1, 0, GEN_MAX_HEIGHT)
			g.set_height(c, lvl)
			var tv := tn.get_noise_2d(x, y)
			var edge := x < DEPLOY_COLS or x >= width - DEPLOY_COLS
			var t := T.GRASS
			if lvl == 0 and tv > 0.05 and not edge:
				t = T.WATER
			elif lvl > 0 and tv > 0.25 - strangeness * 0.15:
				t = T.FOREST
			elif tv < -0.55 and not edge:
				t = T.RUIN if lvl >= 2 and strangeness < 0.5 else T.ROCK
			g.terrain[g.idx(c)] = t
	# Stairs where the ground jumps two levels, so ledges become chokepoints instead of walls.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if g.terrain_at(c) != T.GRASS:
				continue
			for d in CombatRules.DIRS:
				var n: Vector2i = c + d
				if g.in_bounds(n) and g.passable(n) and g.height_at(n) - g.height_at(c) == 2 and rng.randf() < 0.5:
					g.set_terrain(c, T.STAIRS)
					break
	return g


## A plateau map, the layout of the forest reference: one broad high floor in the middle, a terrace stepping
## down to the lowland, a river cut through the terrace with fords left open, a few paths across the top, and stairs
## wherever the ground jumps two levels.
static func _plateau(seed_value: int, width: int, height: int) -> CombatGrid:
	var g := flat(width, height)
	var hn := FastNoiseLite.new()  # how far the ground rises: a lumpy ellipse
	hn.seed = seed_value
	hn.frequency = 0.2
	var tn := FastNoiseLite.new()  # ground cover: forest patches and boulders
	tn.seed = seed_value + 101
	tn.frequency = 0.3
	var rn := FastNoiseLite.new()  # the river's line
	rn.seed = seed_value + 203
	rn.frequency = 0.18
	var pn := FastNoiseLite.new()  # the paths across the top
	pn.seed = seed_value + 307
	pn.frequency = 0.25
	var cx := (width - 1) * 0.5
	var cy := (height - 1) * 0.5
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			var edge := x < DEPLOY_COLS or x >= width - DEPLOY_COLS
			var r := Vector2((x - cx) / cx, (y - cy) / cy).length()
			var v := r + hn.get_noise_2d(x, y) * 0.25
			var lvl := 0
			if not edge and v < 0.7:
				lvl = PLATEAU_LEVEL
			elif not edge and v < 0.95:
				lvl = PLATEAU_LEVEL - 2
			g.set_height(c, lvl)
			var tv := tn.get_noise_2d(x, y)
			var t := T.GRASS
			if lvl == PLATEAU_LEVEL - 2 and absf(rn.get_noise_2d(x, y)) < 0.09 and tv < 0.2:
				t = T.WATER  # the river, with fords where the noise is high
				g.set_height(c, 0)
			elif lvl > 0 and tv > 0.35:
				t = T.FOREST
			elif lvl == PLATEAU_LEVEL and absf(pn.get_noise_2d(x, y)) < 0.07:
				t = T.ROAD
			g.terrain[g.idx(c)] = t
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for y in height:  # some two-level jumps get stairs; the rest stay cliffs, so the terraces read as drops
		for x in width:
			var c := Vector2i(x, y)
			if g.terrain_at(c) != T.GRASS and g.terrain_at(c) != T.ROAD:
				continue
			for d in CombatRules.DIRS:
				var n: Vector2i = c + d
				if g.in_bounds(n) and g.passable(n) and g.height_at(n) - g.height_at(c) == 2 and rng.randf() < 0.3:
					g.set_terrain(c, T.STAIRS)
					break
	return g


## The ground cell of a place (a deck place's cell under it).
static func ground(p: Vector2i) -> Vector2i:
	return Vector2i(p.x, p.y - DECK) if p.y >= DECK else p


static func on_deck(p: Vector2i) -> bool:
	return p.y >= DECK


## The deck place over a ground cell.
static func deck_of(c: Vector2i) -> Vector2i:
	return Vector2i(c.x, ground(c).y + DECK)


func has_deck(c: Vector2i) -> bool:
	return decks.has(ground(c))


## A deck over cell c at height dh, floored with terrain t (STONE, ROAD or STAIRS so a flight can climb on).
func add_deck(c: Vector2i, dh: int, t := T.STONE, bridge := false) -> void:
	decks[ground(c)] = {"h": dh, "t": t, "bridge": true} if bridge else {"h": dh, "t": t}
	version += 1
	_sight.clear()


func remove_deck(c: Vector2i) -> void:
	decks.erase(ground(c))
	version += 1
	_sight.clear()


## The places at a cell: its ground, and its deck if it has one.
func places_at(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = [ground(c)]
	if has_deck(c):
		out.append(deck_of(c))
	return out


## The places one step along d from place p: the ground of that cell and its deck if it has one.
func places_next(p: Vector2i, d: Vector2i) -> Array[Vector2i]:
	return places_at(ground(p) + d)


## Of the places at cell c, the one a piece with this Jump standing on `from` steps onto: the walkable one
## nearest its own height that it may climb to, or NO_PLACE. Free walking uses it to keep a walker on its deck.
func step_place(from: Vector2i, c: Vector2i, jump: int, blocked := {}) -> Vector2i:
	if ground(c) == ground(from):
		return from
	var best := NO_PLACE
	for p in places_at(c):
		if not walkable(p) or blocked.has(p) or not can_step(from, p, jump):
			continue
		if best == NO_PLACE or absi(height_at(p) - height_at(from)) < absi(height_at(best) - height_at(from)):
			best = p
	return best


func idx(c: Vector2i) -> int:
	return c.y * w + c.x


func in_bounds(c: Vector2i) -> bool:
	var g := ground(c)
	return g.x >= 0 and g.y >= 0 and g.x < w and g.y < h


func height_at(c: Vector2i) -> int:
	if c.y >= DECK:
		return int(decks.get(ground(c), {"h": heights[idx(ground(c))]}).h)
	return heights[idx(c)]


func set_height(c: Vector2i, v: int) -> void:
	heights[idx(c)] = v
	version += 1
	_sight.clear()


func terrain_at(c: Vector2i) -> int:
	if c.y >= DECK:
		return int(decks.get(ground(c), {"t": T.VOID}).t)
	return terrain[idx(c)]


func set_terrain(c: Vector2i, t: int) -> void:
	terrain[idx(c)] = t
	version += 1
	_sight.clear()


## Is there ground here? False off the map and on VOID cells.
func solid(c: Vector2i) -> bool:
	return in_bounds(c) and terrain_at(c) != T.VOID


func zone_at(c: Vector2i) -> String:
	return zones[idx(ground(c))]


func set_zone(c: Vector2i, z: String) -> void:
	zones[idx(c)] = z
	version += 1


## Optional prop keys, saved only when set: "face" (0-3, which drawn angle: `<sprite>_r1`.. `_r3`), "flip"
## (mirrored), "id" (a name to script it by), "blob" (a named placeholder block: true, with "name"), "note"
## (a designer note for Claude: what it should do or look like), "arch" (true: a gateway; only the two end
## cells of its long side are pillars, pieces walk and see through the cells between them).
const PROP_EXTRA := ["face", "flip", "id", "blob", "name", "note", "arch", "open"]


## Stand a prop on the map. Its footprint runs from the anchor toward +x and +y. An anchor on a deck place
## stands it on the deck (a house on the bridge): its footprint blocks the deck, not the lane under it.
func add_prop(anchor: Vector2i, sprite: String, foot := Vector2i.ONE, tall := 0.0, sight := 1.0, walk := false, extra := {}) -> void:
	props[anchor] = {"sprite": sprite, "foot": foot, "tall": tall, "sight": sight, "walk": walk}
	for k in PROP_EXTRA:
		if extra.has(k):
			props[anchor][k] = extra[k]
	version += 1
	for c in prop_cells(anchor):
		_prop_at[c] = anchor
	_sight.clear()


## Take a placed prop off the map (by its anchor).
func remove_prop(anchor: Vector2i) -> void:
	if not props.has(anchor):
		return
	for c in prop_cells(anchor):
		_prop_at.erase(c)
	props.erase(anchor)
	version += 1
	_sight.clear()


## The prop standing on this cell (any footprint cell), or {}.
func prop_at(c: Vector2i) -> Dictionary:
	return props.get(_prop_at.get(c, NONE_CELL), {})


func prop_anchor(c: Vector2i) -> Vector2i:
	return _prop_at.get(c, NONE_CELL)


## The cells a placed prop stands on: its footprint less any it leaves open.
func prop_cells(anchor: Vector2i) -> Array[Vector2i]:
	var p: Dictionary = props[anchor]
	var free := open_offsets(p)
	var out: Array[Vector2i] = []
	for dy in p.foot.y:
		for dx in p.foot.x:
			if not free.has(Vector2i(dx, dy)):
				out.append(anchor + Vector2i(dx, dy))
	return out


## A prop's "open" offsets ("x,y|x,y") as cells.
static func open_offsets(p: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for part in String(p.get("open", "")).split("|", false):
		var xy := part.split(",")
		if xy.size() == 2:
			out.append(Vector2i(int(xy[0]), int(xy[1])))
	return out


## The "open" offsets of a prop mirrored (its footprint's x and y swap).
static func mirror_open(open: String) -> String:
	var parts: Array[String] = []
	for part in open.split("|", false):
		var xy := part.split(",")
		if xy.size() == 2:
			parts.append("%s,%s" % [xy[1], xy[0]])
	return "|".join(parts)


## A copy at a new size. Cells that still fit keep their height and terrain; new cells are flat grass.
func resized(width: int, height: int) -> CombatGrid:
	var g := flat(width, height)
	for y in mini(h, height):
		for x in mini(w, width):
			var c := Vector2i(x, y)
			g.set_height(c, height_at(c))
			g.set_terrain(c, terrain_at(c))
			g.set_zone(c, zone_at(c))
	for a: Vector2i in props:
		var p: Dictionary = props[a]
		var ga := ground(a)
		if ga.x + p.foot.x <= width and ga.y + p.foot.y <= height:
			g.add_prop(a, p.sprite, p.foot, p.tall, p.sight, p.walk, p)
	for c: Vector2i in decks:
		if c.x < width and c.y < height:
			g.add_deck(c, int(decks[c].h), int(decks[c].t), bool(decks[c].get("bridge", false)))
	g.look = look.duplicate()
	return g


## Saved maps store terrain as letters, one string per row: g grass, f forest, w water, r rock, d road,
## s stone, t stairs, u ruin, . void (no ground).
## Heights are digits 0-8, one string per row. Easy to read and hand-edit in the JSON.
const LETTERS := {T.GRASS: "g", T.FOREST: "f", T.WATER: "w", T.ROCK: "r", T.ROAD: "d", T.STONE: "s", T.STAIRS: "t", T.RUIN: "u", T.VOID: "."}


func to_dict() -> Dictionary:
	var t_rows: Array[String] = []
	var h_rows: Array[String] = []
	for y in h:
		var tr := ""
		var hr := ""
		for x in w:
			tr += LETTERS[terrain_at(Vector2i(x, y))]
			hr += HEIGHT_DIGITS[height_at(Vector2i(x, y))]
		t_rows.append(tr)
		h_rows.append(hr)
	var d := {"w": w, "h": h, "terrain": t_rows, "heights": h_rows}
	# Zones (only when a map mixes tile sets): one letter per cell, a-z mapped to set names, "-" = the map's set.
	var names: Array[String] = []
	for z in zones:
		if z != "" and not names.has(z):
			names.append(z)
	if not names.is_empty():
		var z_rows: Array[String] = []
		for y in h:
			var zr := ""
			for x in w:
				var z := zone_at(Vector2i(x, y))
				zr += "-" if z == "" else String.chr(97 + names.find(z))
			z_rows.append(zr)
		var key := {}
		for i in names.size():
			key[String.chr(97 + i)] = names[i]
		d["zones"] = z_rows
		d["zone_key"] = key
	if not props.is_empty():
		var list: Array = []
		for a: Vector2i in props:
			var p: Dictionary = props[a]
			var ga := ground(a)
			var e := {"sprite": p.sprite, "cell": [ga.x, ga.y], "foot": [p.foot.x, p.foot.y], "tall": p.tall, "sight": p.sight, "walk": p.walk}
			if on_deck(a):
				e["deck"] = true
			for k in PROP_EXTRA:
				if p.has(k):
					e[k] = p[k]
			list.append(e)
		d["props"] = list
	if not decks.is_empty():
		var list: Array = []
		for c: Vector2i in decks:
			var e := {"x": c.x, "y": c.y, "h": int(decks[c].h), "t": LETTERS[int(decks[c].t)]}
			if decks[c].get("bridge", false):
				e["b"] = true  # a bridge piece (BridgeKit)
			list.append(e)
		d["decks"] = list
	if not look.is_empty():
		d["look"] = look.duplicate()
	return d


static func from_dict(d: Dictionary) -> CombatGrid:
	var g := flat(int(d.get("w", 10)), int(d.get("h", 8)))
	var from_letter := {}
	for k in LETTERS:
		from_letter[LETTERS[k]] = k
	var t_rows: Array = d.get("terrain", [])
	var h_rows: Array = d.get("heights", [])
	for y in g.h:
		for x in g.w:
			var c := Vector2i(x, y)
			if y < t_rows.size() and x < String(t_rows[y]).length():
				g.set_terrain(c, from_letter.get(String(t_rows[y])[x], T.GRASS))
			if y < h_rows.size() and x < String(h_rows[y]).length():
				g.set_height(c, clampi(maxi(0, HEIGHT_DIGITS.find(String(h_rows[y])[x].to_lower())), 0, MAX_HEIGHT))
	var z_rows: Array = d.get("zones", [])
	var key: Dictionary = d.get("zone_key", {})
	for y in mini(g.h, z_rows.size()):
		for x in mini(g.w, String(z_rows[y]).length()):
			g.set_zone(Vector2i(x, y), String(key.get(String(z_rows[y])[x], "")))
	for dk: Dictionary in d.get("decks", []):
		g.add_deck(Vector2i(int(dk.x), int(dk.y)), clampi(int(dk.h), 0, MAX_HEIGHT), from_letter.get(String(dk.get("t", "s")), T.STONE), bool(dk.get("b", false)))
	for p: Dictionary in d.get("props", []):
		var cell: Array = p.get("cell", [0, 0])
		var foot: Array = p.get("foot", [1, 1])
		var anchor := Vector2i(int(cell[0]), int(cell[1]))
		if bool(p.get("deck", false)):
			anchor = deck_of(anchor)
		g.add_prop(anchor, String(p.get("sprite", "")), Vector2i(int(foot[0]), int(foot[1])),
			float(p.get("tall", 0.0)), float(p.get("sight", 1.0)), bool(p.get("walk", false)), _extra(p))
	g.look = (d.get("look", {}) as Dictionary).duplicate()
	return g


static func _extra(p: Dictionary) -> Dictionary:
	var e := {}
	for k in PROP_EXTRA:
		if p.has(k):
			e[k] = int(p[k]) if k == "face" else (bool(p[k]) if k in ["flip", "blob", "arch"] else String(p[k]))
	return e


func step_cost(c: Vector2i) -> int:
	return STEP_COST[terrain_at(c)]


func cover(c: Vector2i) -> int:
	return COVER[terrain_at(c)]


func passable(c: Vector2i) -> bool:
	if not in_bounds(c) or step_cost(c) >= BLOCKED or fences.has(c):
		return false
	if not on_deck(c) and has_deck(c) and int(decks[c].h) - height_at(c) < DECK_CLEAR:
		return false  # a deck too low over the ground leaves no room underneath
	var p := prop_at(c)
	return p.is_empty() or p.walk or under_arch(c)


## Ground the party never walks onto outside fights ([USER] 2026-10-30: no jumping into the water; trees are
## obstructed terrain, so dense forest blocks the way). Fights keep `passable`, so a piece can still wade or
## stand in the trees for cover in a fight.
const WALK_OUT := [T.WATER, T.FOREST]


## Can the party walk here on a map (explore walking: clicks, keys, paths)? A deck over water is dry.
func walkable(c: Vector2i) -> bool:
	return passable(c) and not terrain_at(c) in WALK_OUT


## Is this cell the open middle of an arch (between its two pillars)?
func under_arch(c: Vector2i) -> bool:
	var a := prop_anchor(c)
	var p: Dictionary = props.get(a, {})
	if not p.get("arch", false):
		return false
	var d := c - a
	if p.foot.y > p.foot.x:
		return d.y > 0 and d.y < p.foot.y - 1
	return d.x > 0 and d.x < p.foot.x - 1


## Can a piece with this Jump step between two neighbouring cells? Stairs on either end help it climb.
func can_step(a: Vector2i, b: Vector2i, jump: int) -> bool:
	if ground(a) == ground(b):
		return false  # no straight way between a deck and the lane under it
	var limit := jump
	if terrain_at(a) == T.STAIRS or terrain_at(b) == T.STAIRS:
		limit += STAIRS_CLIMB
	return absi(height_at(b) - height_at(a)) <= limit


## Highest point of the cell for line of sight: ground plus whatever stands on it.
func sight_top(c: Vector2i) -> float:
	var p := prop_at(c)
	var block: float = FENCE_HIGH if fences.has(c) else float(SIGHT_BLOCK[terrain_at(c)])
	return height_at(c) + maxf(block, 0.0 if p.is_empty() or under_arch(c) else float(p.sight))


func top_height() -> int:
	var m := 0
	for v in heights:
		m = maxi(m, v)
	for c: Vector2i in decks:
		m = maxi(m, int(decks[c].h))
	return m


## Clear line from an eye one level above `from` to the body of whoever stands on `to`?
## Walks the straight line between cell centres; any cell in between whose top rises above the line blocks it.
func line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	var key := (_sight_idx(from) << 24) | _sight_idx(to)
	if _sight.has(key):
		return _sight[key]
	var clear := _trace_sight(from, to)
	_sight[key] = clear
	return clear


## A place as one number for the sight cache: its cell, and whether it is the deck.
func _sight_idx(p: Vector2i) -> int:
	return idx(ground(p)) * 2 + (1 if on_deck(p) else 0)


func _trace_sight(from: Vector2i, to: Vector2i) -> bool:
	var ga := ground(from)
	var gb := ground(to)
	var a := Vector2(ga) + Vector2(0.5, 0.5)
	var b := Vector2(gb) + Vector2(0.5, 0.5)
	var ha := height_at(from) + 1.0
	var hb := height_at(to) + 0.6
	var steps := int(ceil(a.distance_to(b) * 4.0))
	for i in range(1, steps):
		var t := float(i) / steps
		var p := a.lerp(b, t)
		var c := Vector2i(int(floor(p.x)), int(floor(p.y)))
		if c == ga or c == gb or not in_bounds(c):
			continue
		var z := lerpf(ha, hb, t)
		if sight_top(c) > z + 0.05 or _deck_blocks(c, z):
			return false
	return true


## Does the deck over cell c stop a sight line passing through it at height z? Its slab (DECK_THICK under the
## floor) does, and so does whatever stands on it, up to that prop's sight height. Above or below, it passes.
func _deck_blocks(c: Vector2i, z: float) -> bool:
	if not has_deck(c):
		return false
	var p := deck_of(c)
	var dh := float(height_at(p))
	var top := dh
	var pr := prop_at(p)
	if not pr.is_empty() and not under_arch(p):
		top += float(pr.sight)
	return z > dh - DECK_THICK - 0.05 and z < top + 0.05

## Can a unit with this jump walk from the left deploy zone to the right one?
func connected(jump: int) -> bool:
	var start := Vector2i(-1, -1)
	for y in h:
		if passable(Vector2i(0, y)):
			start = Vector2i(0, y)
			break
	if start.x < 0:
		return false
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c.x == w - 1:
			return true
		for d in CombatRules.DIRS:
			var n: Vector2i = c + d
			if passable(n) and not seen.has(n) and can_step(c, n, jump):
				seen[n] = true
				queue.append(n)
	return false


## Passable cells in the deploy zone for team 0 (left) or 1 (right), center rows first.
## A lone column's top: ground standing at least two levels over every neighbour (a rock pillar, MapOps.pillar).
## Only a piece with Jump 2 or more gets up there, so nobody is set down on one.
func perch(c: Vector2i) -> bool:
	if not solid(c):
		return false
	var hc := height_at(c)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		if solid(n) and height_at(n) > hc - 2:
			return false
	return true


func deploy_cells(team: int) -> Array[Vector2i]:
	var cols := range(DEPLOY_COLS) if team == 0 else range(w - DEPLOY_COLS, w)
	if team == 0:
		cols.reverse()  # front column first
	var out: Array[Vector2i] = []
	var rows := range(h)
	rows.sort_custom(func(a: int, b: int) -> bool: return absf(a - (h - 1) * 0.5) < absf(b - (h - 1) * 0.5))
	var ground := main_ground()
	for x in cols:
		for y in rows:
			var c := Vector2i(x, y)
			if passable(c) and not perch(c) and ground.has(c):
				out.append(c)
	if out.size() < DEPLOY_MIN:
		# The deploy columns are cut off from the main ground: take its cells nearest this side instead.
		var more: Array = ground.keys().filter(func(c: Vector2i) -> bool: return not out.has(c) and not perch(c))
		more.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x if team == 0 else a.x > b.x)
		for c: Vector2i in more.slice(0, DEPLOY_MIN - out.size()):
			out.append(c)
	return out


## The biggest stretch of ground a Jump 1 piece can walk all over (stairs count). Fights deploy only on it,
## so nobody starts on a ledge or wall top they can't get down from, out of reach of the other side.
func main_ground(jump := 1) -> Dictionary:
	var best := {}
	var done := {}
	for y in h:
		for x in w:
			var start := Vector2i(x, y)
			if done.has(start) or not passable(start):
				continue
			var region := {start: true}
			done[start] = true
			var queue: Array[Vector2i] = [start]
			while not queue.is_empty():
				var c: Vector2i = queue.pop_back()
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n: Vector2i = c + d
					if not done.has(n) and passable(n) and can_step(c, n, jump):
						done[n] = true
						region[n] = true
						queue.append(n)
			if region.size() > best.size():
				best = region
	return best
