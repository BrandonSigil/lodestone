class_name SetPiece
extends RefCounted
## A road set piece ([USER] 2026-11-17: "they should still be set pieces. Something should anchor each map that tie in
## with the story scenario the player encounters"): a road fight on its own handmade map, built round one landmark.
## The map is an ordinary battle map in data/maps (so the map maker opens it): its `enemies` are the foes where they
## stand (an entry may be `hidden` or the `leader`), its `party` entries are the cells the party starts on when it
## walked into the trap, and `piece.out` the cells it starts on when it saw the foes first. An encounter names its
## set piece in data/encounters.csv: `map` (the file's name) and `start` ("in" or "out"). docs/systems/set-pieces.md.

const DIR := "res://data/maps/"


## The set piece's map, or null when the encounter names none (or the file is gone: the fight falls back to a plot).
static func load_map(id: String) -> SandboxSetup:
	if id == "":
		return null
	var path := DIR + id + ".json"
	if not FileAccess.file_exists(path):
		push_warning("set piece map '%s' not found" % id)
		return null
	return SandboxSetup.load_file(path)


## The cells the party starts on, best first: its marked cells for this start, then the free ground nearest them
## (a walk from the first cell), so a party bigger than the marks still stands together.
static func party_cells(setup: SandboxSetup, walked_in: bool, need: int) -> Array[Vector2i]:
	var grid := setup.grid
	var out: Array[Vector2i] = []
	var foes := {}
	for e in setup.enemies:
		foes[e.cell] = true
	if walked_in:
		for p in setup.party:
			if grid.passable(p.cell) and not out.has(p.cell):
				out.append(p.cell)
	else:
		for c in setup.piece.get("out", []):
			var cell := Vector2i(int(c[0]), int(c[1]))
			if grid.passable(cell) and not out.has(cell):
				out.append(cell)
	if out.is_empty():
		return grid.deploy_cells(0)
	var queue: Array[Vector2i] = out.duplicate()
	var seen := {}
	for c in queue:
		seen[c] = true
	while out.size() < need and not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			for n: Vector2i in grid.places_next(c, d):
				if seen.has(n) or not grid.passable(n) or not grid.can_step(c, n, 1):
					continue
				seen[n] = true
				queue.append(n)
				if not foes.has(CombatGrid.ground(n)) and not CombatGrid.on_deck(n) and not out.has(n):
					out.append(n)
	return out


## The fight's pieces: the real party on its start cells, the map's foes where they stand. Foes hide only from a
## party that walked in; a party that saw them first sees them all.
static func units(setup: SandboxSetup, members: Array, walked_in: bool) -> Array:
	var grid := setup.grid
	var out: Array = []
	var cells := party_cells(setup, walked_in, members.size())
	for m in members:
		if cells.is_empty():
			break
		var u := CombatUnit.from_member(m)
		var c: Vector2i = cells.pop_front()
		u.place(c, grid.height_at(c))
		out.append(u)
	var taken := {}
	for u: CombatUnit in out:
		taken[u.cell] = true
	for e in setup.enemies:
		var cd: ClassDef = Db.class_def(e.id)
		if cd == null or not grid.passable(e.cell) or taken.has(e.cell):
			continue
		var f := CombatUnit.enemy(cd, setup.enemy_mods)
		f.place(e.cell, grid.height_at(e.cell))
		f.hiding = walked_in and bool(e.get("hidden", false))
		f.leader = bool(e.get("leader", false))
		f.posted = bool(e.get("post", false))
		taken[e.cell] = true
		out.append(f)
	return out
