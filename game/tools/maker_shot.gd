extends SceneTree
## Screenshots the map maker itself (panels and all), so its UI can be checked headless.
## Args after "--": <png path> <map key, e.g. explore/home> [script of steps]
## Steps (comma separated): tool:<id>, item:<catalog id>, page:<assets|inspect|map>, hover:<x>:<y> (put the
## ghost on a cell), stamp:<x>:<y>, select:<x>:<y>, close:<drawer>, search:<text>, view:<soft|grid|heights|labels>
## (flip a top-bar view toggle; view:soft shows the plain blocks).
## In the cloud: xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x1000 --path . -s res://tools/maker_shot.gd -- out.png explore/home

var _frames := 0
var _maker: Node


func _process(_delta: float) -> bool:
	_frames += 1
	var args := OS.get_cmdline_user_args()
	if _frames == 2:
		root.get_node("Game").set("maker_map", args[1] if args.size() > 1 else "")
		_maker = load("res://scenes/map_maker.tscn").instantiate()
		root.add_child(_maker)
	if _frames == 6 and args.size() > 2:
		load("res://tools/maker_shot_steps.gd").new().call("run", _maker, String(args[2]))
	if _frames == 16:
		root.get_viewport().get_texture().get_image().save_png(args[0])
		quit()
	return false
