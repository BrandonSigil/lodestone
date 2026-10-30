class_name MapLook
extends RefCounted
## How a map is staged around its playable ground: the sky and mountains behind it, the forest it sits in,
## how deep its outer cliffs drop and the trees that frame it. One row of data/looks.csv per look.
## A map picks one with grid.look.id; otherwise the row named like its tile set, else DEFAULT.
## Strangeness drifts the colours toward the ALIEN row (Earth to Alien). Design: docs/design/map-look.md.

const PATH := "res://data/looks.csv"
const DEFAULT := "forest"
const ALIEN := "crystal"

var id := ""
## valley: the map stands in a forest valley under a sky (skirt of trees, tall outer cliffs, backdrop);
## island: it floats on a paper card with rock hanging under the rim; plain: nothing around it (interiors).
var staging := "valley"
var floor_h := -4.0  ## valley: the level where the outer cliffs end in the forest floor
var skirt := 3  ## valley: rings of forest cells drawn around the playable outline
var ridge := "peaks"  ## mountain shape behind the map: peaks, hills, mesas, spires or none
var trees: Array[String] = []  ## prop stems for the forest around the map ("set/stem" borrows another set's art)
var tree_scale := 1.8  ## forest tree height in tile widths
var colors := {}  ## sky_top, sky_low, cloud, far, near, snow, haze, wood_far, wood, floor_col, tree
## Ambience ([USER] 2026-10-30): how hard the breeze bends the trees (0 still air, 1 a light breeze), and the
## weather falling over the map ("snow", "leaves" or ""). A map's own look can set either (grid.look).
var wind := 0.0
var weather := ""
## Stairs (docs/design/stairs.md): treads a level, every step the same size. [USER] 2026-10-30 block steps (1);
## a map can still ask for fine treads (3) with "stairs" in its look.
var stair_treads := 1
## The ground a stair's treads are made of, as a map letter: "d" road (dressed steps), "g" the map's own ground
## (snow on the snowy looks: the steps read as cut into the terrace, their risers rock).
var stair_top := "d"

static var _rows := {}


static func ids() -> Array[String]:
	_load()
	var out: Array[String] = []
	for k in _rows:
		out.append(String(k))
	return out


static func _load() -> void:
	if not _rows.is_empty():
		return
	for row in CsvTable.load_rows(PATH):
		_rows[row.id] = row


## The look for a map: its own pick, else the one named like its tile set, else DEFAULT; then the map's
## overrides (staging, floor, skirt) and the drift toward the alien colours.
static func resolve(map_look: Dictionary, art_set: String, strangeness := 0.0) -> MapLook:
	_load()
	var want := String(map_look.get("id", ""))
	if not _rows.has(want):
		want = art_set if _rows.has(art_set) else DEFAULT
	var row: Dictionary = _rows.get(want, {})
	var m := MapLook.new()
	m.id = want
	m.staging = String(map_look.get("staging", row.get("staging", "valley")))
	m.floor_h = float(map_look.get("floor", row.get("floor", "-4")))
	m.skirt = int(map_look.get("skirt", row.get("skirt", "3")))
	m.ridge = String(row.get("ridge", "peaks"))
	m.tree_scale = float(row.get("tree_scale", "1.8"))
	m.wind = float(map_look.get("wind", row.get("wind", "0")))
	m.weather = String(map_look.get("weather", row.get("weather", "")))
	m.stair_treads = clampi(int(map_look.get("stairs", row.get("stairs", "1"))), 1, 6)
	m.stair_top = String(map_look.get("stair_top", row.get("stair_top", "d")))
	for stem in String(row.get("trees", "prop_pine_1")).split("|", false):
		m.trees.append(stem)
	var alien: Dictionary = _rows.get(ALIEN, row)
	for k in ["sky_top", "sky_low", "cloud", "far", "near", "snow", "haze", "wood_far", "wood", "floor_col", "tree"]:
		var a := Color(String(row.get(k, "#808080")))
		m.colors[k] = a.lerp(Color(String(alien.get(k, "#808080"))), clampf(strangeness, 0.0, 1.0)) if want != ALIEN else a
	return m


func color(k: String) -> Color:
	return colors.get(k, Color(0.5, 0.5, 0.5))


## A stable key for caching what this look draws.
func key() -> String:
	return "%s|%s|%s|%s|%s|%s" % [id, staging, floor_h, skirt, stair_treads, stair_top]
