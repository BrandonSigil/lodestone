extends SceneTree
## Drives a hunting prototype (Dev Tools > Hunting) into a typical moment and saves a PNG.
## Args after "--": <png path> <menu|bow|stalk|snare|drive|card> [hunter] [doggo]

var _frames := 0
var _out := ""
var _mode := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_mode = args[1] if args.size() > 1 else "menu"
	root.get_node("Game").set("save_enabled", false)
	change_scene_to_file("res://scenes/hunting.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var sc: Node = current_scene
	if sc == null:
		return false
	var args := OS.get_cmdline_user_args()
	if _frames == 3 and _mode != "menu":
		sc.set("hunter", args.has("hunter"))
		sc.set("doggo", args.has("doggo"))
		sc.call("play", "bow" if _mode == "card" else _mode, 4242)
	var g: Object = sc.get("game")
	match _mode:
		"bow":
			if _frames == 6:
				g.set("next_in", 0.0)
			if _frames == 30:
				var r: Dictionary = g.get("runner")
				if not r.is_empty():
					r.state = "pause"
					r.pause_t = 9.0
					g.set("aim_override", (r.p as Vector2) + Vector2(14, -6))
				g.set("drawing", true)
				g.set("draw_t", 0.95)
		"stalk":
			if _frames == 6:
				var deer: Vector2 = g.get("deer")
				g.set("hero", deer + Vector2(-120, 70))
				var grass: Array = g.get("grass")
				grass.append(Rect2(deer + Vector2(-190, 30), Vector2(160, 90)))
				g.set("phase", "up")
				g.set("phase_t", 9.0)
				g.set("facing", Vector2(-1, 0.35).normalized())
				g.set("aim_override", deer + Vector2(4, -4))
				g.set("drawing", true)
				g.set("draw_t", 0.95)
		"snare":
			if _frames == 6:
				var runs: Array = g.get("runs")
				var sn: Array[Vector2i] = []
				for r: Dictionary in runs:
					if r.fresh and r.seen and sn.size() < 3:
						sn.append(r.cells[int(r.cells.size() / 2)])
				g.set("snares", sn)
				g.set("bait", sn[0] + Vector2i(1, 1) if not sn.is_empty() else Vector2i(-1, -1))
			if _frames == 8 and args.has("night"):
				g.call("_sleep")
		"drive":
			if _frames == 6:
				var birds: Array = g.get("birds")
				var c := Vector2.ZERO
				for b: Dictionary in birds:
					c += b.p
				c /= birds.size()
				g.set("dog", c + Vector2(-150, 20))
				g.set("dog_face", Vector2.RIGHT)
			if _frames == 40:
				g.call("_bark")
		"card":
			if _frames == 10:
				var caught: Array = g.get("caught")
				var db: Object = root.get_node("Db")
				caught.append(db.get("hunt_animals").rabbit)
				caught.append(db.get("hunt_animals").deer)
				g.call("_end")
	if _frames >= (150 if _mode == "snare" and args.has("night") else 60):
		root.get_viewport().get_texture().get_image().save_png(_out)
		quit()
	return false
