extends RefCounted
## Board set-up for tools/map_shot.gd (game classes load at runtime there).


func build(parent: Node2D, args: PackedStringArray) -> void:
	Db.reload()
	var spec := args[1] if args.size() > 1 else "gen:1:22:20"
	var grid: CombatGrid
	var art_set := ""
	if spec.begins_with("gen:"):
		var p := spec.split(":")
		grid = MapGen.valley(int(p[1]), int(p[2]) if p.size() > 2 else 22, int(p[3]) if p.size() > 3 else 20, p[4] if p.size() > 4 else "alpine")
		art_set = p[4] if p.size() > 4 and BattleArt.sets().has(p[4]) else "alpine"  # a look with its own tile set (snow) uses it
	elif spec.begins_with("recipe:"):
		grid = MapRecipes.build(spec.substr(7))
		art_set = "alpine"
	elif spec == "demo:bridge":
		grid = _bridge_demo()
	elif spec.begins_with("explore/"):
		var m := ExploreMap.load_named(spec.substr(8))
		grid = m.grid
		art_set = m.art_set
	else:
		var s := SandboxSetup.load_file("res://data/" + spec + ".json")
		grid = s.grid
		art_set = s.art_set
	var board := CombatBoard.new()
	board.grid = grid
	board.art_set = art_set
	board.backdrop = true
	var flags := args.slice(3)
	board.show_grid = flags.has("grid")
	board.soft = not flags.has("blocks")  # "blocks": the plain block look, without the soft terrain pass
	board.rot = int(args[2]) if args.size() > 2 else 0
	board.deck_window = not flags.has("nowindow")  # the deck stays solid over a piece under it; the piece gets its ghost ring
	if spec == "demo:bridge":
		_bridge_pieces(board)
	parent.add_child(board)
	var vs := parent.get_viewport_rect().size
	var bs := board.board_size()
	var s := minf(vs.x / bs.x, vs.y / bs.y) * 0.92
	board.scale = Vector2.ONE * s
	board.position = (vs - bs * s) * 0.5 - board.board_origin() * s


## Two-level test ground (docs/systems/decks.md): a two-wide lane at 0 running toward the viewer between banks
## at 3, a two-wide bridge over it, and a bridge with a graybox house on it nearer the front.
func _bridge_demo() -> CombatGrid:
	var g := CombatGrid.flat(12, 12)
	for y in 12:
		for x in 12:
			var lane := x == 5 or x == 6
			g.set_terrain(Vector2i(x, y), CombatGrid.T.ROAD if lane else CombatGrid.T.STONE)
			g.set_height(Vector2i(x, y), 0 if lane else 3)
	for x in [5, 6]:
		for y in [3, 4]:
			g.add_deck(Vector2i(x, y), 3)
		g.add_deck(Vector2i(x, 8), 3)
	g.add_prop(CombatGrid.deck_of(Vector2i(5, 8)), "ph_house", Vector2i(2, 1))
	return g


## A piece under the wide bridge, one on top of it, one in the lane behind the house, and a move highlight on
## both levels; the cursor on the bridge.
func _bridge_pieces(board: CombatBoard) -> void:
	var hero := CombatUnit.enemy(load("res://data/classes/knight.tres"))
	hero.team = 0
	hero.place(Vector2i(5, 4), 0)
	var top := CombatUnit.enemy(load("res://data/classes/bandit.tres"))
	top.team = 1
	top.place(CombatGrid.deck_of(Vector2i(6, 3)), 3)
	var lane := CombatUnit.enemy(load("res://data/classes/bandit.tres"))
	lane.team = 1
	lane.place(Vector2i(6, 7), 0)
	board.units = [hero, top, lane]
	for c in [Vector2i(5, 5), Vector2i(5, 6), Vector2i(6, 5), Vector2i(5, 2)]:
		board.highlights[c] = Color(0.3, 0.6, 1.0, 0.35)
	board.highlights[CombatGrid.deck_of(Vector2i(5, 3))] = Color(0.3, 0.6, 1.0, 0.35)
	board.hover = CombatGrid.deck_of(Vector2i(6, 4))
	for u: CombatUnit in board.units:
		u.sync_view()
