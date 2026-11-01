extends SceneTree
## Drives the fishing minigame (launch menu > Fishing) into a beat and saves a PNG.
## Args after "--": <png path> <step>. Steps: look, bite, reel, caught.

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
	if _frames == 5:
		g.set("_sel", 1)
		if _step != "look":
			g.call("_cast", 1)
	if _frames > 40 and _step == "bite":
		var bp: Dictionary = g.get("_plan")
		g.set("_phase_t", float(bp.bite) + 0.15)  # hold the real dip
	if _frames == 40 and _step != "look":
		var plan: Dictionary = g.get("_plan")
		g.set("_phase_t", float(plan.bite) + 0.15)
		if _step != "bite":
			g.call("_strike_now")
	if _frames >= 60 and _step == "reel":
		g.set("_use_mouse", false)  # xvfb's pointer sits mid-screen: keep it off the marker
		var r: Dictionary = g.get("_reel")
		r.marker = clampf(float(r.fish) - 0.13, 0.11, 0.89)
		r.catch = 0.55
	if _frames == 60 and _step == "caught":
		var r: Dictionary = g.get("_reel")
		r.catch = 0.999
		r.marker = r.fish
	if _frames >= 90:
		root.get_viewport().get_texture().get_image().save_png(_out)
		quit()
	return false
