extends SceneTree
## Frames of the fight's hand of cards in use ([USER] 2026-10-30), for a clip: the hand is dealt, ATTACK is pointed
## at, ABILITIES opens the spells, FIRE ZAP is rested on until its details fill the corner panel, then BACK.
## godot --path game -s res://tools/hand_clip.gd -- <out prefix> [tip mode delay|corner]. Needs a window
## (tools/godot.sh). Writes <out prefix>_000.png and on. Never writes the save.

var _f := 0
var _saved := 0
var _out := ""
var _mode := "delay"
var _steps: Object


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_mode = args[1] if args.size() > 1 else "delay"
	root.get_node("Game").set("save_enabled", false)
	root.get_node("Game").set("explore_map", "crypt")
	change_scene_to_file("res://scenes/explore.tscn")


func _process(_delta: float) -> bool:
	_f += 1
	var s: Node = current_scene
	if s == null:
		return false
	if _steps == null:
		_steps = load("res://tools/explore_shot_steps.gd").new()
	if _f <= 30:  # the explore shot's set-up: the hero with the book, the dog, the fight begun, the hand dealt
		_steps.call("run", s, _f, "cards:main:-1:" + _mode)
		return false
	var hud = s.battle._hud
	match _f:
		50:
			hud._slots[1].grab_focus()  # ATTACK
		80:
			hud._slots[2].grab_focus()  # ABILITIES
		100:
			hud._open("skills")
		115:
			hud._slots[0].grab_focus()  # FIRE ZAP
			if _mode == "corner":
				hud._slots[0].info_asked.emit()
		190:
			hud._open("main")
	if _f >= 34 and _f % 3 == 0:
		root.get_viewport().get_texture().get_image().save_png("%s_%03d.png" % [_out, _saved])
		_saved += 1
	return _f >= 220
