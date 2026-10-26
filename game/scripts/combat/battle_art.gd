class_name BattleArt
extends RefCounted
## Painted battle map art: terrain textures and prop sprites from art/source/battle/, wired by
## data/battle_art.csv. Any missing file falls back to the graybox drawing in CombatBoard.
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
static var _tex := {}  # file name -> Texture2D or null
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for row in CsvTable.load_rows("res://data/battle_art.csv"):
		if NAMES.has(row.terrain):
			_rows[NAMES[row.terrain]] = row


## A texture by file stem, or null when the art isn't there yet.
static func texture(stem: String, tile := false) -> Texture2D:
	if stem == "":
		return null
	if _tex.has(stem):
		return _tex[stem]
	var path := DIR + stem + ".png"
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
	_tex[stem] = tex
	return tex


static func top(t: int) -> Texture2D:
	_load()
	return texture(String(_rows.get(t, {}).get("top", "")), true)


static func side(t: int) -> Texture2D:
	_load()
	return texture(String(_rows.get(t, {}).get("side", "")), true)


## The prop sprites that stand on this terrain, how tall they draw (in tile widths) and how many per cell.
static func props(t: int) -> Dictionary:
	_load()
	var row: Dictionary = _rows.get(t, {})
	var list: Array[Texture2D] = []
	for stem in String(row.get("props", "")).split("|", false):
		var tex := texture(stem)
		if tex != null:
			list.append(tex)
	return {"list": list, "height": float(row.get("prop_height", "0")), "count": int(row.get("prop_count", "0"))}


## Drop cached textures (after new art is imported).
static func reset() -> void:
	_rows.clear()
	_tex.clear()
	_loaded = false
