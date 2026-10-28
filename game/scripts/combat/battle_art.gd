class_name BattleArt
extends RefCounted
## Painted battle map art: terrain textures and prop sprites from art/source/battle/, wired by
## data/battle_art.csv. Any missing file falls back to the graybox drawing in CombatBoard.
## Tile sets: a subfolder of DIR (snow/, dungeon/...) holds a region's versions of the same file names.
## A file missing from the set falls back to the base one, so a set can be filled in one texture at a time.
## A set may also bring its own data/battle_art_<set>.csv (same columns) to change which files a terrain
## uses there, e.g. the village interior's rock is a plaster wall with no boulders on it.
## Rules for the art itself: docs/art/battle-maps.md.

const DIR := "res://art/source/battle/"
const TOP_TILES := 2.0  ## a top texture spans 2 x 2 cells
const SIDE_TILES := 2.0  ## a side texture spans 2 cells across...
const SIDE_LEVELS := 4.0  ## ...and 4 height levels down (4 stone rows)
const TEX_SIZE := 256  ## textures are downsized to this and mipmapped so they don't shimmer
const NAMES := {
	"grass": CombatGrid.T.GRASS, "forest": CombatGrid.T.FOREST, "water": CombatGrid.T.WATER,
	"rock": CombatGrid.T.ROCK, "road": CombatGrid.T.ROAD, "stone": CombatGrid.T.STONE,
	"stairs": CombatGrid.T.STAIRS, "ruin": CombatGrid.T.RUIN,
}

static var _rows := {}  # terrain -> row
static var _set_rows := {}  # set name -> {terrain -> row}, from data/battle_art_<set>.csv when there is one
static var _tex := {}  # file name -> Texture2D or null
static var _loaded := false
static var art_set := ""  ## the active tile set: a subfolder of DIR, or "" for the base art


## Switch tile sets (cached textures are dropped when it changes).
static func use_set(name: String) -> void:
	if name != art_set:
		art_set = name
		_tex.clear()


## The tile sets on disk: every subfolder of DIR.
static func sets() -> PackedStringArray:
	var d := DirAccess.open(DIR)
	return d.get_directories() if d != null else PackedStringArray()


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for row in CsvTable.load_rows("res://data/battle_art.csv"):
		if NAMES.has(row.terrain):
			_rows[NAMES[row.terrain]] = row


## A texture by file stem from a tile set ("" = the active set), or null when the art isn't there yet.
## A stem may name another set: "snow/prop_pine_1" borrows the snow set's pine (mix-and-match sets).
static func texture(stem: String, tile := false, from_set := "") -> Texture2D:
	if stem == "":
		return null
	var set_name := from_set if from_set != "" else art_set
	var slash := stem.find("/")
	if slash > 0:  # "set/stem" borrows another set's art; "base/stem" the base art
		set_name = stem.substr(0, slash)
		stem = stem.substr(slash + 1)
		if set_name == "base":
			set_name = ""
	var key := set_name + "/" + stem
	if _tex.has(key):
		return _tex[key]
	var path := DIR + set_name + "/" + stem + ".png"
	if set_name == "" or not ResourceLoader.exists(path):
		path = DIR + stem + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path)
		if tex != null and tile:
			var img := tex.get_image()
			if img != null:
				img.decompress()
				img.resize(TEX_SIZE, TEX_SIZE, Image.INTERPOLATE_LANCZOS)
				img.generate_mipmaps()
				tex = ImageTexture.create_from_image(img)
	_tex[key] = tex
	return tex


static var _avg := {}  # texture -> mean colour


## Mean colour of a texture (cached): the island underside borrows its cliff art's colour.
static func average(tex: Texture2D) -> Color:
	if _avg.has(tex):
		return _avg[tex]
	var img := tex.get_image()
	var sum := Color(0, 0, 0, 0)
	var n := 0
	if img != null:
		img.decompress()
		var step := maxi(1, img.get_width() / 16)
		for y in range(0, img.get_height(), step):
			for x in range(0, img.get_width(), step):
				sum += img.get_pixel(x, y)
				n += 1
	var c := Color(sum.r / n, sum.g / n, sum.b / n, 1.0) if n > 0 else Color(0.5, 0.45, 0.4)
	_avg[tex] = c
	return c


## The CSV row for a terrain in a set: the set's own table when it has one, else the shared one.
static func _row(t: int, from_set: String) -> Dictionary:
	_load()
	var set_name := from_set if from_set != "" else art_set
	if set_name != "" and not _set_rows.has(set_name):
		var rows := {}
		var path := "res://data/battle_art_%s.csv" % set_name
		if FileAccess.file_exists(path):
			for row in CsvTable.load_rows(path):
				if NAMES.has(row.terrain):
					rows[NAMES[row.terrain]] = row
		_set_rows[set_name] = rows
	return _set_rows.get(set_name, {}).get(t, _rows.get(t, {}))


static func top(t: int, from_set := "") -> Texture2D:
	return texture(String(_row(t, from_set).get("top", "")), true, from_set)


static func side(t: int, from_set := "") -> Texture2D:
	return texture(String(_row(t, from_set).get("side", "")), true, from_set)


## The prop sprites that stand on this terrain, how tall they draw (in tile widths) and how many per cell.
static func props(t: int, from_set := "") -> Dictionary:
	var row := _row(t, from_set)
	var list: Array[Texture2D] = []
	for stem in String(row.get("props", "")).split("|", false):
		var tex := texture(stem, false, from_set)
		if tex != null:
			list.append(tex)
	return {"list": list, "height": float(row.get("prop_height", "0")), "count": int(row.get("prop_count", "0"))}


## How far the top's grass (snow, sand...) hangs over a cliff edge, in height levels; 0 = a clean edge.
## The set's own table may leave the column out, then the shared table's value holds.
static func lip(t: int, from_set := "") -> float:
	var row := _row(t, from_set)
	if row.has("lip"):
		return float(row.lip)
	_load()
	return float(_rows.get(t, {}).get("lip", "0"))


## Drop cached textures (after new art is imported).
static func reset() -> void:
	_rows.clear()
	_set_rows.clear()
	_tex.clear()
	_loaded = false
