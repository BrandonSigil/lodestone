extends SceneTree
## Plays a few seconds of a feel feature for a short clip ([USER] 2026-11-01: "record little videos for features like this
## so I can actually see what it feels like without opening up the game"). Run it under Godot's movie writer:
##   tools/godot.sh --path game --write-movie <out.avi> --fixed-fps 30 -s res://tools/feel_clip.gd -- <clip>
## then tools/clip_gif.sh turns the .avi into a small GIF. Clips: fishing (the aimed cast, the bite and the reel),
## highlight (walking past the tavern's things: the one F would use lights up), takeall (a barrel's coins go over
## with TAKE ALL). The Lich Prince's hand is the sandbox shot's `nepo` step (SHOT_FRAME sets its length).
## Never writes the real save.

var _f := 0
var _clip := ""
var _done_at := -1


func _initialize() -> void:
	_clip = OS.get_cmdline_user_args()[0]
	root.get_node("Game").set("save_enabled", false)
	match _clip:
		"fishing":
			change_scene_to_file("res://scenes/fishing.tscn")
		"highlight", "takeall":
			root.get_node("Game").set("explore_map", "tavern")
			change_scene_to_file("res://scenes/explore.tscn")


func _process(_delta: float) -> bool:
	_f += 1
	if current_scene == null:
		return false
	match _clip:
		"fishing":
			_fishing()
		"highlight":
			_highlight()
		"takeall":
			_takeall()
	if _f >= 1500 or (_done_at > 0 and _f >= _done_at):
		quit()
	return false


## A whole cast at a player's pace ([USER] 2026-11-01 "Can these clips be longer? this only hows the aim part"): the aim
## glides over the pool to a fish's shadow, the cast, the bobber waits until a fish notices on its own (a recast if none
## does), the nibbles and the real bite, the strike, HOOKED!, then the reel steered a little late (as a player chasing the
## fish would), and the catch card held a few seconds.
func _fishing() -> void:
	var g: Object = current_scene.get("game")
	if g == null:
		return
	var state := int(g.get("state"))  # FishingGame.S: LOOK 0, CAST 1, STRIKE 2, REEL 3, RESULT 4, WAIT 5, COME 6, HOOKED 7, SWIM_OFF 8
	var shadows: Array = g.get("_shadows")
	if state == 0 and not shadows.is_empty():
		if _aim_from < 0:
			_aim_from = _f
		var k := float(_f - _aim_from)
		var big: Dictionary = shadows[0]  # the biggest fish in the pond: a longer fight on the reel
		for sh: Dictionary in shadows:
			if float(sh.fish.get("size", 1.0)) > float(big.fish.get("size", 1.0)):
				big = sh
		var to: Vector2 = (big.home as Vector2) + Vector2(0.03, 0.02)
		g.set("_use_mouse", false)
		var wander := Vector2(0.25 + 0.5 * sin(k / 40.0), 0.6 + 0.15 * cos(k / 33.0))  # looks over the pool first
		g.set("_aim", wander.lerp(to, smoothstep(90.0, 150.0, k)))
		if k >= 165.0:
			g.call("_cast_aimed")
			_aim_from = -1
	if state == 2:
		var plan: Dictionary = g.get("_plan")
		if float(g.get("_phase_t")) >= float(plan.bite) + 0.15:
			g.call("_strike_now")
	if state == 3:  # chase the fish, a beat late and only once it has drifted off the marker
		var r: Dictionary = g.get("_reel")
		var off := float(r.fish) - float(r.marker)
		if _f % 20 == 0:  # a slow, sloppy player reacts in fits: the fish pulls away from the marker now and then
			_steer = 0 if absf(off) < 0.18 else (1 if off > 0.0 else -1)
		Input.action_release("ui_left")
		Input.action_release("ui_right")
		if _steer != 0:
			Input.action_press("ui_right" if _steer > 0 else "ui_left")
	elif _steer != 0:
		Input.action_release("ui_left")
		Input.action_release("ui_right")
		_steer = 0
	if state == 4 and _done_at < 0:
		_done_at = _f + 105


var _aim_from := -1
var _steer := 0


## Walks the hero (held WASD, as a player would) along the tavern's back wall and back: the "!" bubbles over things,
## and the one F would use grows, rings in light and gets a pool of light under it as the hero passes each one.
func _highlight() -> void:
	var s: Node = current_scene
	if _f == 5:
		_put(s, Vector2i(2, 4))
	for k in [[25, 120, KEY_D], [135, 230, KEY_A]]:
		if _f == k[0] or _f == k[1]:
			var ev := InputEventKey.new()
			ev.keycode = k[2]
			ev.physical_keycode = k[2]
			ev.pressed = _f == k[0]
			Input.parse_input_event(ev)
	if _f == 250:
		_done_at = _f


## The barrel opens beside the pack (its 8 coins under its grid, the party's 0 under the pack), then TAKE ALL moves the
## meat, the potion and the coins over.
func _takeall() -> void:
	var s: Node = current_scene
	if _f == 5:
		for t: Dictionary in s.get("things"):
			if t.id == "barrel1":
				_put(s, t.cell + Vector2i(1, 0))
				s.call("_open_thing", t)
	if _f == 55:
		for b in _buttons(root):
			if b.text.length() > 1 and b.get_parent().get_class() != "VBoxContainer":  # TAKE ALL on the view, not an X
				b.pressed.emit()
				break
	if _f == 120:
		_done_at = _f


func _buttons(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is Button and (c as Button).is_visible_in_tree():
			out.append(c)
		out.append_array(_buttons(c))
	return out


func _put(s: Node, c: Vector2i) -> void:
	var lead: Object = s.call("leader")
	lead.call("place", c, s.get("grid").height_at(c))
	s.call("_refresh_sight")
	s.call("_refresh_units")
	s.set("focus", Vector2(c) + Vector2(0.5, 0.5))
