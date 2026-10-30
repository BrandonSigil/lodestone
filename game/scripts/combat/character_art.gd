class_name CharacterArt
extends RefCounted
## Character sprites from art/source/characters/<id>/ (docs/art/characters.md C28): <id>.json plus one
## horizontal strip per anim and drawn facing, <id>_<anim>_<dir>.png. Undrawn facings use the json's
## mirror table, then the nearest drawn facing. A character with no json draws as the graybox Pawn.

const DIR := "res://art/source/characters/"
const FALLBACK := &"dummy"  ## the general dummy: any unit with no art of its own draws with it
const SCREEN_DIRS := ["e", "se", "s", "sw", "w", "nw", "n", "ne"]  ## clockwise from screen right

static var _meta := {}  # id -> parsed json, or null when the character has no art
static var _tex := {}  # "id/anim/dir" -> Texture2D or null


static func meta(id: StringName) -> Variant:
	if id == &"":
		return null
	if not _meta.has(id):
		var path := DIR + String(id) + "/" + String(id) + ".json"
		var data: Variant = null
		if FileAccess.file_exists(path):
			data = JSON.parse_string(FileAccess.get_file_as_string(path))
		_meta[id] = data if data is Dictionary else null
	return _meta[id]


static func has_art(id: StringName) -> bool:
	return meta(id) != null


## Sprite a unit draws with: its own art when it has some, else the general dummy (tinted by team).
static func sprite_for(id: StringName) -> StringName:
	return id if has_art(id) else FALLBACK


static func has_anim(id: StringName, anim: String) -> bool:
	var m: Variant = meta(id)
	return m != null and m.anims.has(anim)


## Seconds an anim takes to play once. A character with no art uses the placeholder's timing.
static func length(id: StringName, anim: String) -> float:
	if meta(id) == null:
		return PlaceholderFigure.length(anim)
	var a: Dictionary = meta(id).anims.get(anim, {})
	return float(a.get("frames", 1)) / float(a.get("fps", 10))


## Seconds from an anim's start to its hit or release frame (C17); 0 when it has none.
static func hit_time(id: StringName, anim: String) -> float:
	if meta(id) == null:
		return PlaceholderFigure.hit_time(anim)
	var a: Dictionary = meta(id).anims.get(anim, {})
	return float(a.get("hit", 0)) / float(a.get("fps", 10))


## Screen facing name for a screen-space direction (y down).
static func screen_dir(v: Vector2) -> String:
	var i := posmod(roundi(v.angle() / (PI / 4.0)), 8)
	return SCREEN_DIRS[i]


## {tex, region, flip, scale, anchor} for this anim at time t, or {} when nothing is drawn for it.
static func frame(id: StringName, anim: String, dir: String, t: float) -> Dictionary:
	var m: Dictionary = meta(id)
	if not m.anims.has(anim):
		anim = "idle"
	var a: Dictionary = m.anims[anim]
	var flip := false
	var dirs: Array = m.dirs
	if not dirs.has(dir):
		var mirror: Dictionary = m.get("mirror", {})
		if dirs.has(mirror.get(dir, "")):
			dir = mirror[dir]
			flip = true
		else:  # nearest drawn facing: south-ish faces use the front view, north-ish the back view
			var west := dir.contains("w")
			var front := "se" if dirs.has("se") else String(dirs[0])
			var back := "ne" if dirs.has("ne") else front
			dir = back if dir.begins_with("n") else front
			flip = west
	var tex := _strip(id, anim, dir)
	if tex == null:
		return {}
	var n := int(a.frames)
	var i := int(t * float(a.fps))
	i = posmod(i, n) if a.get("loop", false) else mini(i, n - 1)
	var size := float(m.frame)
	return {"tex": tex, "region": Rect2(i * size, 0, size, size), "flip": flip,
		"scale": float(m.scale), "anchor": Vector2(m.anchor[0], m.anchor[1]),
		"bar": float(m.get("bar", float(m.anchor[1]) * 0.72))}  # art px over the feet the HP pips sit at (a small dog's are lower)


static func _strip(id: StringName, anim: String, dir: String) -> Texture2D:
	var key := "%s/%s/%s" % [id, anim, dir]
	if not _tex.has(key):
		var path := DIR + "%s/%s_%s_%s.png" % [id, id, anim, dir]
		var tex: Texture2D = null
		if ResourceLoader.exists(path):
			tex = load(path)
			# Mipmaps so the half-size sprite doesn't shimmer (like BattleArt's tiles).
			var img := tex.get_image()
			if img != null:
				img.decompress()
				img.generate_mipmaps()
				tex = ImageTexture.create_from_image(img)
		_tex[key] = tex
	return _tex[key]
