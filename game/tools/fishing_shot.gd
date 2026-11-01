extends SceneTree
## Drives the fishing minigame (launch menu > Fishing) into a beat and saves a PNG.
## Args after "--": <png path> <step>. Steps: look (the aim and its notice ring), come (a fish swimming to the
## bobber), bite, reel (the marker pulled left of the fish), caught.

var _frames := 0
var _out := ""
var _step := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_step = args[1] if args.size() > 1 else "look"
	root.get_node("Game").set("save_enabled", false)
	change_scene_to_file("res://scenes/fishing.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	var g: Object = current_scene.get("game") if current_scene else null
	if g == null:
		return false
	var shadows: Array = g.get("_shadows")
	if _frames == 5:
		var at: Vector2 = (shadows[0].home as Vector2) + Vector2(0.03, 0.02)  # (FishingRules isn't compiled in a -s script)
		g.set("_aim", at)
		g.set("_use_mouse", false)
		if _step != "look":
			g.call("_cast_aimed")
	if _frames == 45 and _step != "look":
		if int(g.get("state")) == 1:  # S.CAST
			g.call("_landed")
		for i in 80:  # beside the shadow a fish soon notices
			if int(g.get("state")) == 5:  # S.WAIT
				g.call("_notice")
		if _step != "come":
			g.set("_phase_t", 2.0)
	if _frames == 95 and _step == "come":
		g.set("_phase_t", 0.3)  # the fish is part-way to the bobber when the picture is taken
	if _frames == 55 and _step != "look" and _step != "come":
		var plan: Dictionary = g.get("_plan")
		g.set("_phase_t", float(plan.bite) + 0.15)
		if _step != "bite":
			g.call("_strike_now")
	if _frames >= 80 and _step == "reel":
		var r: Dictionary = g.get("_reel")
		r.t = 6.0
		r.marker = clampf(float(r.fish) - 0.13, 0.11, 0.89)
		r.catch = 0.55
	if _frames == 80 and _step == "caught":
		var r: Dictionary = g.get("_reel")
		r.catch = 0.999
		r.marker = r.fish
	if _frames == 70 and _step == "bite":
		var bp: Dictionary = g.get("_plan")
		g.set("_phase_t", float(bp.bite) + 0.15)
	if _frames >= 100:
		root.get_viewport().get_texture().get_image().save_png(_out)
		quit()
	return false
