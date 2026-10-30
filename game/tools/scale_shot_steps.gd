extends RefCounted
## Study scales for tools/scale_shot.gd: area, most pieces, fast and long-range pieces.

const SEED := 14
const SCALES := {"today": [1.0, 1.0, 1.0], "a": [1.25, 1.25, 1.25], "b": [1.5, 1.5, 1.5], "c": [1.5, 1.25, 1.5]}  # area, most, fast



func run(s: Node, frames: int, which: String) -> void:
	var study: RefCounted = load("res://tools/scale_study_run.gd").new()
	var k: Array = SCALES[which]
	if frames == 3:
		var setup := SandboxSetup.default_setup()
		var w := int(round(14 * float(k[0])))
		var h := int(round(12 * float(k[0])))
		setup.grid = MapGen.valley(SEED, w, h, "snow")
		setup.art_set = "snow"
		setup.party = []
		setup.enemies = []
		var spots := setup.grid.deploy_cells(0)
		for id in ["lead", "stardrop", "hunter"]:
			setup.party.append({"id": id, "cell": spots.pop_front()})
		var es := setup.grid.deploy_cells(1)
		for id in ["bandit", "bandit", "bandit_archer", "wolf"]:
			setup.enemies.append({"id": id, "cell": es.pop_front()})
		s.set("setup", setup)
		study.set("_k", k[1])
		study.set("_fast", k[2])
		study.call("_scale_abilities", k[1], k[2])
		s.call("_sync_controls")
		s.call("_enter_edit")
	if frames == 5:
		s.call("_enter_play")
	if frames == 10:
		var b: Battle = s.battle
		study.set("_k", k[1])
		study.set("_fast", k[2])
		for u: CombatUnit in b.units:
			study.call("_stretch", u)
		var hunter: CombatUnit = b.units[2]
		b._select(hunter)
		b._show_move_tiles()
		for child in b.get_children():
			if child != b.board:
				child.visible = false
		for child in s.get_children():
			if child != b and child is CanvasItem:
				(child as CanvasItem).visible = false
		var move_cells: Dictionary = CombatRules.reachable(b.grid, hunter, b.units).cost
		var threat := {}
		for from: Vector2i in move_cells:  # every cell within the piece's reach of somewhere it could stand
			for y in b.grid.h:
				for x in b.grid.w:
					var c := Vector2i(x, y)
					var d := CombatRules.dist(from, c)
					if b.grid.passable(c) and d >= hunter.range_min and d <= hunter.range_max:
						threat[c] = true
		for c in threat:
			if not move_cells.has(c):
				b.board.highlights[c] = Color(0.9, 0.3, 0.25, 0.45)
