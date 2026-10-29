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
	parent.add_child(board)
	var vs := parent.get_viewport_rect().size
	var bs := board.board_size()
	var s := minf(vs.x / bs.x, vs.y / bs.y) * 0.92
	board.scale = Vector2.ONE * s
	board.position = (vs - bs * s) * 0.5 - board.board_origin() * s
