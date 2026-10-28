extends SceneTree
## Renders the battle view (scenes/battle_view.tscn) to a PNG, so the fight can be checked headless.
## Args after "--": <png path> <map name in data/maps, e.g. highland> [total|player] [tile set to try]
## total: the whole board. player: the board zoomed on the lead piece, HUD hidden (about the play camera).

var _frames := 0
var _out := ""
var _mode := "total"
var _set := ""
var _view: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	var map := args[1] if args.size() > 1 else "highland"
	_mode = args[2] if args.size() > 2 else "total"
	_set = args[3] if args.size() > 3 else ""
	root.get_node("Game").set("sandbox_map", "res://data/maps/%s.json" % map)
	change_scene_to_file("res://scenes/battle_view.tscn")


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3 and _set != "":  # try another tile set on the same map
		current_scene.setup.art_set = _set
		current_scene._start()
	if _frames == 12 and _mode == "player":
		_view = current_scene
		var board = _view.battle.board  # untyped: this -s script compiles before the game classes exist
		var lead = _view.battle.units[0]
		var k := 2.2
		for child in _view._hud.get_children():
			child.visible = false
		board.scale = Vector2.ONE * k
		board.position = _view.play_rect().get_center() - board.cell_top(lead.cell) * k
	if _frames == 24:
		root.get_viewport().get_texture().get_image().save_png(_out)
		quit()
	return false
