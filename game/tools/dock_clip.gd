extends SceneTree
## Frames of the fight's dock in use ([USER] 2026-10-30), for a clip: the hero's dock comes up, HIT pops GUARD,
## TRICKS pops the spells, up to FIRE ZAP and rest until its details fill the corner panel, then WAIT, and the dog's
## dock comes up by itself.
## godot --path game -s res://tools/dock_clip.gd -- <out prefix>. Needs a window (tools/godot.sh). Writes
## <out prefix>_000.png and on. Never writes the save.

var _f := 0
var _saved := 0
var _out := ""
var _steps: Object


func _initialize() -> void:
	_out = OS.get_cmdline_user_args()[0]
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
	if _f <= 30:  # the explore shot's set-up: the hero with the book, the dog, the fight begun, the hero's dock up
		_steps.call("run", s, _f, "dock:main:-1")
		return false
	var hud = s.battle._hud
	match _f:
		45:
			hud._bar_slots[1].grab_focus()  # HIT: GUARD pops up over it
		70:
			hud._bar_slots[2].grab_focus()  # TRICKS: the spells pop up
		80:
			hud._pop_slots[0].grab_focus()  # up to FIRE ZAP: rest on it
		160:
			hud._hide_tip()
			s.battle._on_wait()  # WAIT: the dog comes up by itself
	if _f >= 34 and _f % 3 == 0:
		root.get_viewport().get_texture().get_image().save_png("%s_%03d.png" % [_out, _saved])
		_saved += 1
	return _f >= 220
