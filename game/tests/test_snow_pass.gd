extends TestCase
## The snowy mountain pass and the wolf den (end-to-end loop): every place the party must reach is
## reachable with Jump 1, and the rope ledge is not, except by the rope.


func _thing(m: ExploreMap, id: String) -> Dictionary:
	for t in m.things:
		if t.id == id:
			return t
	return {}


## Every cell of the map, so pathing isn't limited by fog.
func _all(m: ExploreMap) -> Dictionary:
	var all := {}
	for y in m.grid.h:
		for x in m.grid.w:
			all[Vector2i(x, y)] = true
	return all


## Things stand in the way, like in the explore scene.
func _blocked(m: ExploreMap) -> Dictionary:
	var out := {}
	for t in m.things:
		out[t.cell] = true
	return out


func _can_use(m: ExploreMap, from: Vector2i, id: String) -> bool:
	var t := _thing(m, id)
	return not t.is_empty() and not ExploreRules.path_to_use(m.grid, from, t.cell, 1, _blocked(m), _all(m)).is_empty()


func test_pass_loads() -> void:
	if Db.abilities.is_empty():
		Db.reload()
	var m := ExploreMap.load_named("snow_pass")
	ok(m != null, "snow_pass.json loads")
	eq(m.art_set, "snow", "snow tile set")
	ok(m.grid.passable(m.start[0]), "start is walkable")
	ok(m.grid.top_height() >= 7, "the pass climbs to level 7 or more")
	for id in ["pass_exit", "den_mouth", "pass_cache", "rope_ledge", "ledge_chest", "rope_down", "snow_secret", "crypt_stair"]:
		ok(not _thing(m, id).is_empty(), "thing %s" % id)
	for g in m.groups:
		for u: Dictionary in g.units:
			ok(m.grid.passable(u.cell), "%s stands on walkable ground" % g.id)
			ok(Db.class_def(u.id) != null, "%s is a class" % u.id)
	eq(String(_thing(m, "crypt_stair").to), "crypt", "the top leads into the crypt")
	eq(String(_thing(m, "den_mouth").to), "wolf_den", "the cave leads into the den")


func test_pass_climb_reaches_everything() -> void:
	var m := ExploreMap.load_named("snow_pass")
	var s := m.start[0]
	for id in ["pass_exit", "den_mouth", "pass_cache", "snow_secret", "crypt_stair", "rope_ledge"]:
		ok(_can_use(m, s, id), "start reaches %s" % id)
	var top := _thing(m, "crypt_stair")
	ok(m.grid.height_at(top.cell) > m.grid.height_at(s) + 5, "the crypt stair is far above the start")
	for g in m.groups:
		for u: Dictionary in g.units:
			ok(ExploreRules.find_path(m.grid, s, u.cell, 1, _blocked(m), _all(m)).size() > 1, "%s can be walked to" % g.id)


func test_ledge_only_by_rope() -> void:
	var m := ExploreMap.load_named("snow_pass")
	ok(not _can_use(m, m.start[0], "ledge_chest"), "the ledge chest can't be reached on foot")
	var rope := _thing(m, "rope_ledge")
	eq(String(rope.to), "snow_pass", "the rope stays on the pass")
	ok(m.grid.passable(rope.at), "the rope lands on ground")
	ok(_can_use(m, rope.at, "ledge_chest"), "from the rope's landing the chest is in reach")
	ok(_can_use(m, rope.at, "rope_down"), "and so is the rope back down")
	var down := _thing(m, "rope_down")
	ok(_can_use(m, m.start[0], "rope_ledge") and ExploreRules.find_path(m.grid, m.start[0], down.at, 1, _blocked(m), _all(m)).size() > 1,
		"the rope down lands back on the walk")


func test_wolf_den() -> void:
	var den := ExploreMap.load_named("wolf_den")
	ok(den != null, "wolf_den.json loads")
	var s := den.start[0]
	ok(den.grid.passable(s), "den start is walkable")
	ok(_can_use(den, s, "den_bones"), "the den start reaches the bones at the back")
	ok(_can_use(den, s, "den_out"), "and the way out")
	eq(den.groups.size(), 2, "a pair and a lone wolf")
	var wolves := 0
	for g in den.groups:
		wolves += g.units.size()
	eq(wolves, 3, "three wolves in all")
	var a: Vector2i = den.groups[0].units[0].cell
	var b: Vector2i = den.groups[1].units[0].cell
	ok(ExploreRules.dist(a, b) > ExploreRules.JOIN_RANGE, "far enough apart to fight separately")
	var p := ExploreMap.load_named("snow_pass")
	var mouth := _thing(p, "den_mouth")
	eq(Vector2i(mouth.at), s, "the cave mouth arrives on the den's start")
	var out := _thing(den, "den_out")
	ok(p.grid.passable(out.at), "the den's way out lands on walkable ground on the pass")
	ok(ExploreRules.can_use_from(p.grid, out.at, mouth.cell), "right in front of the cave mouth")
