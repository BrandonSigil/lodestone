class_name ShadowKit
extends RefCounted
## Cast shadows for the board's props, as pure shape math (no drawing, so tests can run it headless).
##
## One sun for the whole game, set in `res://data/shadows.csv`. A prop's shadow is its own sprite silhouette
## (from the alpha channel, traced once per texture and cached) sheared along the sun's ground direction, or
## for boxy things (buildings, planters, crates) the footprint swept along it. The board hands each ground cell
## the shadows that reach it, merged into one shape per cell (so overlaps never darken twice) and clipped to
## that cell's own top (so a shadow stops at a cliff edge and never paints over a wall). Because every cell draws
## its share of one continuous shape, nothing shows the tile grid. See `docs/systems/shadows.md`.

const PATH := "res://data/shadows.csv"
const TRACE_SIZE := 96  ## the longest side a sprite is traced at (px)
const ALPHA_CUT := 0.4  ## alpha that counts as part of the silhouette
const SIMPLIFY := 1.1  ## outline simplification in trace px

static var _cfg := {}
static var _rules := {}
static var _cache := {}  ## texture key -> silhouette Dictionary


static func reset() -> void:
	_cfg.clear()
	_rules.clear()
	_cache.clear()


static func _load() -> void:
	if not _cfg.is_empty():
		return
	for row in CsvTable.load_rows(PATH):
		var key := String(row.key)
		if key.begins_with("sprite:"):
			_rules[key.substr(7)] = row
		else:
			_cfg[key] = row
	if _cfg.is_empty():
		_cfg["sun"] = {"a": "0.6", "b": "0.2"}


static func _num(key: String, field: String, fallback: float) -> float:
	_load()
	var row: Dictionary = _cfg.get(key, {})
	var s := String(row.get(field, ""))
	return float(s) if s != "" else fallback


## Ground shift on screen (px) for each px of height: x to the right, y toward the viewer. The sun is upper left.
static func sun() -> Vector2:
	return Vector2(_num("sun", "a", 0.6), _num("sun", "b", 0.2))


## Colour (alpha = the one opacity every shadow shares).
static func color() -> Color:
	return Color(_num("color", "a", 0.12), _num("color", "b", 0.15), _num("color", "c", 0.3), _num("alpha", "a", 0.3))


## Height (px) above which a shadow stops lengthening much, and how much of the rest still counts.
static func height_cap() -> Vector2:
	return Vector2(_num("height_cap", "a", 100.0), _num("height_cap", "b", 0.3))


## The soft edge: its width (px) and the share of the opacity it carries. 0 width = a hard edge.
static func edge() -> Vector2:
	return Vector2(_num("edge", "a", 2.0), _num("edge", "b", 0.5))


## The rule for a sprite stem: {len, shape ("" = by size, "box" or "sil"), box_h, contact}.
static func rule(stem: String) -> Dictionary:
	_load()
	var r: Dictionary = _rules.get(stem, {})
	if r.is_empty():  # prop_bush_3 follows prop_bush
		var k := stem.rfind("_")
		if k > 0 and stem.substr(k + 1).is_valid_int():
			r = _rules.get(stem.substr(0, k), {})
	return {
		"len": float(String(r.get("a", "1")) if String(r.get("a", "")) != "" else "1"),
		"shape": String(r.get("shape", "")),
		"box_h": float(String(r.get("b", "")) if String(r.get("b", "")) != "" else str(_num("box", "a", 0.6))),
		"contact": float(String(r.get("c", "")) if String(r.get("c", "")) != "" else "1"),
	}


## Height after the cap: a tall building's shadow lengthens slowly instead of crossing the village.
static func squash(v: float) -> float:
	var cap := height_cap()
	if v <= cap.x:
		return v
	return cap.x + (v - cap.x) * cap.y


static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		a += p[i].x * q.y - q.x * p[i].y
	return absf(a) * 0.5


## A sprite's silhouette, traced from its alpha, as {polys, bottom, gap, height}: outlines in unit space (x -0.5 to
## 0.5 across the sprite, y up from the silhouette's lowest point in sprite heights), `gap` the transparent strip
## below it in sprite heights. Holes are dropped (the shadow is a solid shape). Cached per texture.
static func silhouette(tex: Texture2D) -> Dictionary:
	if tex == null:
		return {}
	var key: String = tex.resource_path if tex.resource_path != "" else str(tex.get_instance_id())
	if _cache.has(key):
		return _cache[key]
	var out := {"polys": [] as Array, "gap": 0.0, "height": 1.0}
	var img := tex.get_image()
	if img != null and not img.is_empty():
		if img.is_compressed():
			img.decompress()
		var s := float(TRACE_SIZE) / float(maxi(img.get_width(), img.get_height()))
		if s < 1.0:
			img.resize(maxi(1, int(img.get_width() * s)), maxi(1, int(img.get_height() * s)), Image.INTERPOLATE_BILINEAR)
		out = from_image(img)
	_cache[key] = out
	return out


## The same tracing from an image (tests use it with a drawn one).
static func from_image(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var bm := BitMap.new()
	bm.create_from_image_alpha(img, ALPHA_CUT)
	var raw: Array[PackedVector2Array] = bm.opaque_to_polygons(Rect2i(0, 0, w, h), SIMPLIFY)
	var keep: Array[PackedVector2Array] = []
	for i in raw.size():
		var p := raw[i]
		if p.size() < 3 or _area(p) < 6.0:
			continue
		var inside := false  # an outline inside another is a hole: left out
		for j in raw.size():
			if i != j and raw[j].size() >= 3 and _area(raw[j]) > _area(p) and Geometry2D.is_point_in_polygon(p[0], raw[j]):
				inside = true
				break
		if not inside:
			keep.append(p)
	var low := -INF
	var high := INF
	for p in keep:
		for q in p:
			low = maxf(low, q.y)
			high = minf(high, q.y)
	if keep.is_empty():
		return {"polys": [] as Array, "gap": 0.0, "height": 1.0}
	var polys := []
	for p in keep:
		var u := PackedVector2Array()
		for q in p:
			u.append(Vector2(q.x / w - 0.5, (low - q.y) / h))
		polys.append(u)
	return {"polys": polys, "gap": (h - low) / h, "height": (low - high) / h}


## A silhouette standing with its lowest point at `anchor`, drawn `w` x `h` px, sheared along the sun and merged
## into as few solid shapes as it needs. `len_mult` scales the length (0 = no shadow).
static func project(sil: Dictionary, anchor: Vector2, w: float, h: float, len_mult := 1.0, flip := false) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if sil.is_empty() or len_mult <= 0.0:
		return out
	var s := sun() * len_mult
	for u: PackedVector2Array in sil.polys:
		var p := PackedVector2Array()
		for q in u:
			var vs := squash(q.y * h)
			p.append(anchor + Vector2((-q.x if flip else q.x) * w + s.x * vs, s.y * vs))
		out = union_into(out, p)
	return out


## A footprint (screen quad) swept along the sun for a shadow of the box standing on it, `height` px tall.
static func box(foot: PackedVector2Array, height: float, len_mult := 1.0) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if len_mult <= 0.0 or foot.size() < 3:
		return out
	var sh := sun() * len_mult * squash(height)
	var pts := PackedVector2Array()
	for q in foot:
		pts.append(q)
		pts.append(q + sh)
	var hull := Geometry2D.convex_hull(pts)
	if hull.size() > 3:
		hull.remove_at(hull.size() - 1)  # the hull repeats its first point
	out.append(hull)
	return out


## A flat ellipse on the ground (the contact patch at a base).
static func patch(center: Vector2, rx: float, ry: float, n := 14) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		p.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return p


static func bounds(polys: Array) -> Rect2:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: PackedVector2Array in polys:
		for q in p:
			lo = lo.min(q)
			hi = hi.max(q)
	return Rect2(lo, hi - lo) if lo.x < INF else Rect2()


static func _solid(polys: Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for p: PackedVector2Array in polys:
		if p.size() >= 3 and not Geometry2D.is_polygon_clockwise(p) and _area(p) > 0.5:
			out.append(p)
	return out


## Only shapes the renderer can fill (a sliver can fail to triangulate).
static func _drawable(polys: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for p in polys:
		if not Geometry2D.triangulate_polygon(p).is_empty():
			out.append(p)
	return out


## Adds `p` to a set of solid shapes, merging with every shape it touches, so the set never overlaps itself.
static func union_into(set: Array[PackedVector2Array], p: PackedVector2Array) -> Array[PackedVector2Array]:
	if p.size() < 3:
		return set
	var cur := p
	var rest: Array[PackedVector2Array] = []
	for e in set:
		if not Rect2(bounds([e])).grow(0.5).intersects(Rect2(bounds([cur])).grow(0.5)):
			rest.append(e)
			continue
		var m := _solid(Geometry2D.merge_polygons(cur, e))
		if m.size() == 1:
			cur = m[0]
		else:  # they only looked close: keep both
			rest.append(e)
	rest.append(cur)
	return rest


## What one ground cell draws for these shadows: {inner, edge} lists of solid shapes clipped to its top polygon.
## `edge` is the soft band round the shadow (drawn first, at its own opacity).
static func receive(shadows: Array, top: PackedVector2Array) -> Dictionary:
	var set: Array[PackedVector2Array] = []
	for p: PackedVector2Array in shadows:
		set = union_into(set, p)
	var inner: Array[PackedVector2Array] = []
	var band: Array[PackedVector2Array] = []
	var e := edge()
	for p in set:
		inner.append_array(_drawable(_solid(Geometry2D.intersect_polygons(p, top))))
		if e.x > 0.0:
			for o in Geometry2D.offset_polygon(p, e.x, Geometry2D.JOIN_ROUND):
				if not Geometry2D.is_polygon_clockwise(o):
					band.append_array(_drawable(_solid(Geometry2D.intersect_polygons(o, top))))
	return {"inner": inner, "edge": band}
