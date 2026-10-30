class_name BattleArt
extends RefCounted
## Painted battle map art: terrain textures and prop sprites from art/source/battle/, wired by
## data/battle_art.csv. Any missing file falls back to the graybox drawing in CombatBoard.
## Tile sets: a subfolder of DIR (snow/, dungeon/...) holds a region's versions of the same file names.
## A file missing from the set falls back to the base one, so a set can be filled in one texture at a time.
## A set may also bring its own data/battle_art_<set>.csv (same columns) to change which files a terrain
## uses there, e.g. the village interior's rock is a plaster wall with no boulders on it. The base art (the forest
## set) reads data/battle_art_forest.csv.
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
	var table := "forest" if set_name == "" else set_name  # the base art is the forest set, with its own table
	if not _set_rows.has(table):
		var rows := {}
		var path := "res://data/battle_art_%s.csv" % table
		if FileAccess.file_exists(path):
			for row in CsvTable.load_rows(path):
				if NAMES.has(row.terrain):
					rows[NAMES[row.terrain]] = row
		_set_rows[table] = rows
	return _set_rows.get(table, {}).get(t, _rows.get(t, {}))


static func top(t: int, from_set := "") -> Texture2D:
	var row := _row(t, from_set)
	var tex := texture(String(row.get("top", "")), true, from_set)
	var tone := String(row.get("tone", ""))
	return toned(tex, Color.html(tone)) if tex != null and tone != "" else tex


const TONE_KEEP := 0.6  ## how much of a toned texture's own light and dark marks survive (0 = flat colour)
static var _toned := {}  # texture id + colour -> retinted texture


## A texture recoloured so its average is `col`, keeping its marks a little softer: the `tone` column (a hex
## colour) in a set's table, e.g. the snow set's road borrows the base sand but in the key art's paler beige.
static func toned(tex: Texture2D, col: Color) -> Texture2D:
	var key := "%d|%s" % [tex.get_instance_id(), col.to_html()]
	if _toned.has(key):
		return _toned[key]
	var img := tex.get_image()
	img.decompress()
	img.clear_mipmaps()
	img.convert(Image.FORMAT_RGBA8)
	var mean := average(tex)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color((col + (c - mean) * TONE_KEEP).clamp(), c.a))
	img.generate_mipmaps()
	var out := ImageTexture.create_from_image(img)
	_toned[key] = out
	return out


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


## How much of a side texture's top is a painted cap (snow, moss) rather than the rock under it, as a share of
## its height (0 = none). The soft terrain pass hangs its own lip instead and repeats only the rock below.
static func cap(t: int, from_set := "") -> float:
	return float(_row(t, from_set).get("cap", "0"))


## How high this ground piles up against the foot of a wall rising from it, in levels (0 = it doesn't): snow
## banks in the soft terrain pass.
static func drift(t: int, from_set := "") -> float:
	return float(_row(t, from_set).get("drift", "0"))


const BODY_TRIM := 0.05  ## share of a capped side texture's width cut off each edge (the sheet's paper and ink)
static var _bodies := {}  # set/stem -> {"tex", "u", "v"}


## The rock of a side texture for the soft terrain pass: {"tex", "u": cells across one repeat, "v": levels down
## one repeat}. A side with a painted cap (cap > 0, cut from a sheet) loses the cap and the sheet's edges, and
## its far edges are faded over its near ones, so it tiles with no seam (made at load; the art file is
## untouched). Others come as they are.
static func side_body(t: int, from_set := "") -> Dictionary:
	var stem := String(_row(t, from_set).get("side", ""))
	var c := cap(t, from_set)
	var src := texture(stem, false, from_set)
	if src == null:
		return {}
	if c <= 0.0:
		return {"tex": texture(stem, true, from_set), "u": SIDE_TILES, "v": SIDE_LEVELS}
	var key := "%s/%s/%s" % [from_set if from_set != "" else art_set, stem, c]
	if _bodies.has(key):
		return _bodies[key]
	var img := src.get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var x0 := roundi(w * BODY_TRIM)
	var y0 := roundi(h * c)
	var body := _tileable(img.get_region(Rect2i(x0, y0, w - 2 * x0, h - y0)))
	var bw := body.get_width()
	var bh := body.get_height()
	body.resize(TEX_SIZE, roundi(TEX_SIZE * float(bh) / bw), Image.INTERPOLATE_LANCZOS)
	body.generate_mipmaps()
	var res := {"tex": ImageTexture.create_from_image(body), "u": SIDE_TILES * float(bw) / w, "v": SIDE_LEVELS * float(bh) / h}
	_bodies[key] = res
	return res


const STRIP_CELLS := 3.0  ## a painted cliff strip spans 3 cells across a face
static var _strips := {}  # set + stems -> {"texs", "hs", "w"}


## The painted cliff strips for a terrain's faces (the `strips` column: stems split by "|"): {"texs": textures,
## "hs": each one's height in levels, "w": cells across}, or {} when the set has none or their art isn't in yet
## (the faces then keep the side texture). A strip is drawn at the side texture's density, 2 levels a cell.
static func side_strips(t: int, from_set := "") -> Dictionary:
	var stems := String(_row(t, from_set).get("strips", ""))
	if stems == "":
		return {}
	var key := "%s|%s" % [from_set if from_set != "" else art_set, stems]
	if _strips.has(key):
		return _strips[key]
	var texs: Array[Texture2D] = []
	var hs: Array[float] = []
	for stem in stems.split("|", false):
		var src := texture(stem, false, from_set)
		if src == null:
			continue
		var img := src.get_image()
		img.decompress()
		img.generate_mipmaps()
		texs.append(ImageTexture.create_from_image(img))
		hs.append(STRIP_CELLS * SIDE_LEVELS / SIDE_TILES * float(img.get_height()) / img.get_width())
	var res := {} if texs.is_empty() else {"texs": texs, "hs": hs, "w": STRIP_CELLS}
	_strips[key] = res
	return res


## An image made to tile: a quarter of its width (then height) is cut off its far edge and faded in over its
## near edge, so the end runs straight on into the start.
static func _tileable(img: Image) -> Image:
	for axis in 2:
		var w := img.get_width()
		var h := img.get_height()
		var b := (w if axis == 0 else h) / 4
		var out := img.get_region(Rect2i(0, 0, w - b, h) if axis == 0 else Rect2i(0, 0, w, h - b))
		var tail := img.get_region(Rect2i(w - b, 0, b, h) if axis == 0 else Rect2i(0, h - b, w, b))
		for y in tail.get_height():
			for x in tail.get_width():
				var col := tail.get_pixel(x, y)
				col.a *= 1.0 - ((x if axis == 0 else y) + 0.5) / b
				tail.set_pixel(x, y, col)
		out.blend_rect(tail, Rect2i(Vector2i.ZERO, tail.get_size()), Vector2i.ZERO)
		img = out
	return img


## Drop cached textures (after new art is imported).
static func reset() -> void:
	_rows.clear()
	_set_rows.clear()
	_tex.clear()
	_bodies.clear()
	_toned.clear()
	_loaded = false
