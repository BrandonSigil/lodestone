extends RefCounted
## Board set-up for tools/plot_shot.gd: the plot as a road fight builds it (MapPlot.build), drawn with its region's tiles.


func build(parent: Node2D, args: PackedStringArray) -> void:
	Db.reload()
	var key := String(args[1])
	var region := key.get_slice("/", 0)
	var plot := MapPlot.load_file("res://data/plots/%s.json" % key)
	var grid := MapPlot.build(plot, int(args[2]) if args.size() > 2 else 1, region)
	var board := CombatBoard.new()
	board.grid = grid
	board.art_set = region
	board.backdrop = true
	board.soft = true
	board.rot = int(args[3]) if args.size() > 3 else 0
	parent.add_child(board)
	var vs := parent.get_viewport_rect().size
	var bs := board.board_size()
	var s := minf(vs.x / bs.x, vs.y / bs.y) * 0.92
	board.scale = Vector2.ONE * s
	board.position = (vs - bs * s) * 0.5 - board.board_origin() * s
