extends SceneTree
## Bakes road set pieces (docs/systems/set-pieces.md) from their sketches into battle maps the map maker opens.
## A sketch is tools/setpieces/src/<id>.json, written by tools/setpieces/seed_pieces.py. Run headless from game/:
##   godot --headless --path . -s res://tools/setpiece_build.gd -- [id ...] [--force]
## Without ids it bakes every sketch. A map that already exists is left alone unless --force is given, so a set piece
## Brandon has reworked in the map maker is never overwritten by accident.

const SRC := "res://../tools/setpieces/src/"


func _initialize() -> void:
	var steps: Object = load("res://tools/setpiece_build_steps.gd").new()
	var args := Array(OS.get_cmdline_user_args())
	var force := args.has("--force")
	args.erase("--force")
	var dir := ProjectSettings.globalize_path(SRC)
	if args.is_empty():
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".json"):
				args.append(f.get_basename())
		args.sort()
	for id: String in args:
		print(steps.call("bake", dir + id + ".json", force))
	quit()
