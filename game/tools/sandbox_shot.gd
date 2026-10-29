extends SceneTree
## Drives the combat sandbox into a state and saves a PNG, so visual work can be checked headless.
## Args after "--": <png path> <step> [map name in data/maps] [tile set, a subfolder of art/source/battle]
## Steps: edit, menu (select first party piece), aim (aim its first skill at the nearest foe),
## danger (danger zone on), guard (the first piece guards), downed (the first piece bleeding out, AID next to it), teamup (two pieces on one foe, HIT aimed), goals (boss or way out), moved (walk the first piece forward, then open its menu)

var _frames := 0
var _out := ""
var _step := ""


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_step = args[1] if args.size() > 1 else "edit"
	if _step == "maker":  # as the map maker's Play test starts it: the fight alone
		root.get_node("Game").set("sandbox_play", true)
	change_scene_to_file("res://scenes/combat_sandbox.tscn")


var _steps: Object


func _process(_delta: float) -> bool:
	_frames += 1
	# Game classes are loaded at runtime: a -s script compiles before the autoloads exist.
	if _steps == null:
		_steps = load("res://tools/sandbox_shot_steps.gd").new()
	var args := OS.get_cmdline_user_args()
	if _frames == 3 and args.size() > 2:
		var s: Node = current_scene
		s.set("setup", load("res://scripts/sandbox/sandbox_setup.gd").load_file("res://data/maps/%s.json" % args[2]))
		if args.size() > 3:
			s.get("setup").art_set = args[3]
		s.call("_sync_controls")
		s.call("_enter_edit")
	_steps.call("run", current_scene, _frames, _step)
	if _frames == (90 if _step == "restart_mid" else 24):
		root.get_viewport().get_texture().get_image().save_png(_out)
		quit()
	return false
