extends TestCase
## Cast shadows (ShadowKit): one sun, silhouettes traced once per texture, shapes merged so overlaps never
## double up, and clipped to a cell's own top.


func _tex(w: int, h: int, box: Rect2i) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill_rect(box, Color.WHITE)
	return ImageTexture.create_from_image(img)


func _area(polys: Array) -> float:
	var a := 0.0
	for p: PackedVector2Array in polys:
		var s := 0.0
		for i in p.size():
			var q := p[(i + 1) % p.size()]
			s += p[i].x * q.y - q.x * p[i].y
		a += absf(s) * 0.5
	return a


func test_silhouette_is_traced_and_cached_per_texture() -> void:
	var tex := _tex(32, 64, Rect2i(8, 16, 16, 40))
	var a := ShadowKit.silhouette(tex)
	ok(not (a.polys as Array).is_empty(), "an opaque block traces to an outline")
	ok(absf(float(a.gap) - 8.0 / 64.0) < 0.03, "the strip under it is the gap (%s)" % a.gap)
	ok(absf(float(a.height) - 40.0 / 64.0) < 0.03, "its height in sprite heights (%s)" % a.height)
	ok(ShadowKit.silhouette(tex) == a, "the same texture reuses its trace")
	ok(ShadowKit.silhouette(_tex(32, 64, Rect2i(8, 16, 16, 40))) is Dictionary, "another texture traces on its own")


func test_projection_follows_the_sun() -> void:
	var sil := ShadowKit.silhouette(_tex(32, 64, Rect2i(8, 16, 16, 40)))
	var anchor := Vector2(100, 200)
	var polys := ShadowKit.project(sil, anchor, 32.0, 64.0)
	ok(not polys.is_empty(), "a shadow is cast")
	var box := ShadowKit.bounds(polys)
	var sun := ShadowKit.sun()
	ok(box.position.y >= anchor.y - 1.0, "the shadow lies on the ground, not above the base")
	ok(box.end.x > anchor.x + 8.0 + sun.x * 20.0, "it leans right, along the sun")
	ok(box.end.y > anchor.y + sun.y * 20.0, "and toward the viewer")
	eq(ShadowKit.project(sil, anchor, 32.0, 64.0, 0.0).size(), 0, "a length of 0 casts nothing")
	var flipped := ShadowKit.bounds(ShadowKit.project(sil, anchor, 32.0, 64.0, 1.0, true))
	ok(absf(flipped.size.x - box.size.x) < 1.0, "a flipped sprite casts the same size")


func test_tall_shadows_stop_lengthening() -> void:
	ok(ShadowKit.squash(40.0) == 40.0, "short things keep their height")
	ok(ShadowKit.squash(400.0) < 400.0 * 0.5, "a tall building's shadow is capped")
	ok(ShadowKit.squash(400.0) > ShadowKit.squash(200.0), "but still grows")


func test_overlaps_merge_so_they_never_double() -> void:
	var a := ShadowKit.patch(Vector2(0, 0), 20.0, 10.0)
	var b := ShadowKit.patch(Vector2(10, 0), 20.0, 10.0)
	var set := ShadowKit.union_into(ShadowKit.union_into([] as Array[PackedVector2Array], a), b)
	eq(set.size(), 1, "two overlapping shadows become one shape")
	ok(_area(set) < _area([a]) + _area([b]) - 50.0, "and the overlap counts once")
	var far := ShadowKit.union_into(set, ShadowKit.patch(Vector2(300, 0), 5.0, 5.0))
	eq(far.size(), 2, "apart, they stay two")


func test_a_cell_gets_only_its_own_share() -> void:
	var top := PackedVector2Array([Vector2(0, 0), Vector2(32, 16), Vector2(0, 32), Vector2(-32, 16)])
	var wide := ShadowKit.patch(Vector2(0, 16), 120.0, 40.0)
	var got := ShadowKit.receive([wide, ShadowKit.patch(Vector2(5, 16), 100.0, 30.0)], top)
	var inner: Array = got.inner
	ok(not inner.is_empty(), "the cell receives a shape")
	ok(_area(inner) <= _area([top]) + 0.5, "clipped to the cell's top (area %s of %s)" % [_area(inner), _area([top])])
	for p: PackedVector2Array in inner:
		for q in p:
			ok(Geometry2D.is_point_in_polygon(q, top) or Rect2(ShadowKit.bounds([top])).grow(0.5).has_point(q), "no point leaves the cell")
	var none := ShadowKit.receive([ShadowKit.patch(Vector2(500, 500), 5.0, 5.0)], top)
	ok((none.inner as Array).is_empty(), "a faraway shadow leaves the cell alone")


func test_data_row_per_sprite() -> void:
	ok(ShadowKit.rule("prop_detail").len == 0.0, "flowers cast nothing")
	ok(ShadowKit.rule("prop_bush_3").len == ShadowKit.rule("prop_bush").len, "a numbered variant follows its base rule")
	ok(ShadowKit.rule("never_heard_of_it").len == 1.0, "no row = a normal shadow")
	ok(ShadowKit.color().a > 0.0 and ShadowKit.color().a < 1.0, "one see-through opacity")
