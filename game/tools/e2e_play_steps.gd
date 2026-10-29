extends RefCounted
## The steps of tools/e2e_play.gd: a robot player for the E2E loop ([USER] 2026-10-28). It calls the same
## functions the buttons call, so it checks the loop's wiring, data and fights, not the clicking.

const SECONDS_CAP := 400.0  ## give up on a wait after this much game time
const TRIES := 4  ## a lost fight: wake in the square, come back and fight again, up to this many times

var tree: SceneTree
var game: Node
var fails := 0
var finished := false
var falls := 0  ## fights lost along the way (each one a wake-up in the square)


func play(t: SceneTree) -> void:
	tree = t
	game = tree.root.get_node("Game")
	Engine.time_scale = 6.0
	game.save_enabled = false
	Battle.auto_fight = true
	await _frames(2)
	game.new_game()

	var s: Node = await _explore("home")
	await _use(s, "home_chest", "OPT_TAKE")
	_check(game.run.medicine == 2, "a potion from the hero's chest")
	await _through(s, "out")

	s = await _explore("village")
	_check(game.run.members.size() == 1, "alone in the village")
	_check(not _offered(s, "gate", "OPT_GO_ON"), "the gate won't let you out without the Lodestone")
	await _use(s, "weapon_rack", "OPT_TAKE_SWORD")
	_check(game.weapon_id() == "sword", "the smithy sword is the hero's")
	await _use(s, "smithy_rope", "OPT_TAKE")
	await _use(s, "food_barrel", "OPT_TAKE")
	_check(game.run.item_count("rope") == 1 and game.run.food >= 8, "rope and food in the pack")
	await _use(s, "statue", "OPT_TAKE_STONE")
	_check(game.has_flag("has_lodestone"), "the Lodestone is taken")
	_check(s.hud.tools_box.get_child_count() >= 2, "the Lodestone button is on the bar")
	await _use(s, "dog_window", "OPT_CLIMB_IN")

	s = await _explore("house_dog")
	await _use(s, "dog", "OPT_LET_OUT")
	_check(game.run.members.size() == 2, "the dog joined the party")
	_check(s.party.size() == 2, "the dog walks with the hero")
	await _through(s, "out")

	s = await _explore("village")
	await _use(s, "gate", "OPT_GO_ON")

	s = await _road_to_pass()
	await _press(s, 0)  # GO IN

	s = await _explore("snow_pass")
	s = await _fight(s, "pass_wolves")
	await _use(s, "pass_cache", "OPT_OPEN")
	_check(_offered(s, "rope_ledge", "OPT_TIE_ROPE"), "the rope opens the ledge")
	await _use(s, "rope_ledge", "OPT_TIE_ROPE")
	s = await _explore("snow_pass")
	await _use(s, "ledge_chest", "OPT_OPEN")
	await _use(s, "rope_down", "OPT_CLIMB_DOWN")
	s = await _explore("snow_pass")
	await _use(s, "snow_secret", "OPT_DIG")
	await _through(s, "den_mouth")

	s = await _explore("wolf_den")
	s = await _fight(s, "den_wolves")
	s = await _fight(s, "den_lone")
	await _use(s, "den_bones", "OPT_RUMMAGE")
	await _through(s, "den_out")

	s = await _explore("snow_pass")
	s = await _fight(s, "pass_bandits")
	_spend_picks()
	await _through(s, "crypt_stair")

	s = await _explore("crypt")
	_spend_picks()
	var lv: int = game.level_state("lead").level
	print("  hero level %d, HP %d/%d before the boss" % [lv, game.run.members[0].hp, game.run.max_hp(game.run.members[0])])
	s = await _fight(s, "throne")
	_check(game.has_flag("e2e_done"), "the Lich King is down: test done")
	print("  fights lost on the way: %d" % falls)

	# A fall costs nothing: wake in the square with everything.
	var rope: int = game.run.item_count("rope")
	var gold: int = game.run.gold
	game.run.members[0].hp = 0
	game.recall()
	s = await _explore("village")
	_check(s.leader().cell == game.SQUARE, "woke in the square")
	_check(game.run.item_count("rope") == rope and game.run.gold == gold, "kept every item")
	_check(game.run.members.all(func(m: Dictionary) -> bool: return m.hp == game.run.max_hp(m)), "everyone at full HP")
	_check(game.has_flag("lodestone_revealed"), "a fall reveals the Lodestone")

	# A beaten boss stays beaten: back in the crypt after the fall, the throne is empty.
	game.explore_map = "crypt"
	game.explore_entry = Vector2i(-1, -1)
	game.go(game.EXPLORE)
	s = await _explore("crypt")
	_check(s.get("groups").any(func(g: Dictionary) -> bool: return g.def.id == "throne" and g.state == "gone"), "the Lich King stays beaten")

	print("E2E %s: %d failed checks" % ["PASS" if fails == 0 else "FAIL", fails])
	finished = true


# --- helpers ----------------------------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func _check(cond: bool, what: String) -> void:
	print(("ok    " if cond else "FAIL  ") + what)
	if not cond:
		fails += 1


func _scene(name: String) -> Node:
	var waited := 0.0
	while tree.current_scene == null or not String(tree.current_scene.scene_file_path).ends_with(name + ".tscn"):
		await tree.process_frame
		waited += tree.root.get_process_delta_time()
		if waited > SECONDS_CAP:
			_check(false, "reached scene " + name)
			finished = true
			await tree.create_timer(9999).timeout
	await _frames(3)
	return tree.current_scene


func _explore(map_name: String) -> Node:
	var s: Node = await _scene("explore")
	var waited := 0.0
	while String(s.get("map").map_name) != map_name:
		await tree.process_frame
		waited += tree.root.get_process_delta_time()
		if waited > SECONDS_CAP:
			_check(false, "reached map " + map_name)
			finished = true
			await tree.create_timer(9999).timeout
		s = await _scene("explore")
	# Close the wake-up line if there is one (or back off from a group that saw the party arrive).
	if s.get("_dialog") != null:
		await _dismiss(s)
	print("-- %s" % map_name)
	return s


func _thing(s: Node, id: String) -> Dictionary:
	for t: Dictionary in s.get("things"):
		if t.id == id:
			return t
	_check(false, "thing %s on %s" % [id, s.get("map").map_name])
	return {}


func _offered(s: Node, id: String, key: String) -> bool:
	var t := _thing(s, id)
	var ev: Dictionary = Db.explore_events.get(String(t.get("event", "")), {})
	if ev.is_empty():
		return false
	var opts := ExploreRules.options_for(ev, s.call("_defs"), {"items": game.run.items, "flags": game.meta.flags})
	return opts.any(func(o: Dictionary) -> bool: return o.key == key)


## Use a thing and pick the option with this text key, then press on through the result box.
func _use(s: Node, id: String, key: String) -> void:
	var t := _thing(s, id)
	var ev: Dictionary = Db.explore_events.get(String(t.event), {})
	var opts := ExploreRules.options_for(ev, s.call("_defs"), {"items": game.run.items, "flags": game.meta.flags})
	var picked: Array = opts.filter(func(o: Dictionary) -> bool: return o.key == key)
	_check(not picked.is_empty(), "%s offers %s" % [id, key])
	if picked.is_empty():
		return
	s.set("mode", 2)  # DIALOG, as if the box were open
	s.call("choose", picked[0], {"thing": t})
	await _frames(2)
	# The result box, and maybe a group that came into sight meanwhile asking what to do. Back off from
	# those: the robot fights with _fight, on purpose. (Pressing FIGHT there left a fight running behind
	# the next door: the playtester's bug 01.)
	for i in 2:
		if not is_instance_valid(s) or s.get("_dialog") == null or tree.current_scene != s:
			break
		if i == 0:
			await _dismiss(s)
		else:
			await _press_text(s, Txt.t("OPT_BACK_OFF"))


func _through(s: Node, id: String) -> void:
	_check(s.get("battle") == null, "no fight running when leaving through " + id)
	s.call("_travel", _thing(s, id))
	await _frames(2)


## Press button n of the scene's open box.
func _press(s: Node, n: int) -> void:
	var d: Node = s.get("_dialog")
	if d == null:
		return
	var buttons := d.find_children("*", "Button", true, false)
	if n < buttons.size():
		(buttons[n] as Button).pressed.emit()
	await _frames(2)


## Close the open box: BACK OFF when a group is asking what to do (the robot starts its fights with
## _fight), otherwise its first button.
func _dismiss(s: Node) -> void:
	if not await _press_text(s, Txt.t("OPT_BACK_OFF")):
		await _press(s, 0)


## Press the open box's button with this text. False when it has none.
func _press_text(s: Node, text: String) -> bool:
	var d: Node = s.get("_dialog")
	if d == null:
		return false
	for b in d.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			(b as Button).pressed.emit()
			await _frames(2)
			return true
	return false


## A fight on the explore map against one group, played on auto, then OK through the result.
## Lost: the party wakes in the square; the robot checks that, comes back to this map and fights again.
## Returns the explore scene it ends on.
func _fight(s: Node, group_id: String) -> Node:
	var map_name := String(s.get("map").map_name)
	for attempt in TRIES:
		var g := {}
		for x: Dictionary in s.get("groups"):
			if x.def.id == group_id:
				g = x
		_check(not g.is_empty(), "group " + group_id)
		if g.is_empty():
			return s
		var xp: int = game.level_state("lead").xp + game.level_state("lead").level * 1000
		_heal_up()
		_approach(s, g)
		_check(s.get("battle") == null, "no fight already running before the %s fight" % group_id)
		s.call("start_fight", g, "party")
		var waited := 0.0
		while s.get("battle") == null or s.get("battle").state != Battle.S.OVER:
			await tree.process_frame
			waited += tree.root.get_process_delta_time()
			if waited > SECONDS_CAP:
				_check(false, "fight %s ended" % group_id)
				return s
		await _frames(3)
		var units: Array = s.get("battle").units
		if CombatRules.team_alive(units, 0) and CombatRules.team_alive(units, 1):
			_check(false, "the fight with %s ended in a stalemate (the AI couldn't reach)" % group_id)
			return s
		if not CombatRules.team_alive(units, 1):
			_check(true, "won the fight with %s" % group_id)
			var after: int = game.level_state("lead").xp + game.level_state("lead").level * 1000
			_check(after > xp, "XP for the %s fight" % group_id)
			if not game.has_flag("e2e_done"):
				await _press(s, 0)
			return s
		s = await _fell("the fight with " + group_id)
		game.explore_map = map_name
		game.explore_entry = Vector2i(-1, -1)
		game.go(game.EXPLORE)
		s = await _explore(map_name)
	_check(false, "won the fight with %s in %d tries" % [group_id, TRIES])
	return s


## The party fell: OK through the defeat box and check the wake-up in the square with everything kept.
func _fell(what: String) -> Node:
	falls += 1
	var items: Dictionary = game.run.items.duplicate()
	print("  lost %s: the Lodestone brings the party home" % what)
	var cur := tree.current_scene
	if String(cur.scene_file_path).ends_with("explore.tscn"):
		await _press(cur, 0)
	var v: Node = await _explore("village")
	_check(v.leader().cell == game.SQUARE, "woke in the square")
	_check(game.run.items == items, "kept every item")
	_check(game.run.members.all(func(m: Dictionary) -> bool: return m.hp == game.run.max_hp(m)), "everyone at full HP")
	return v


## Out the gate and along the road to the pass; encounters on the way. Returns the overworld at the pass.
func _road_to_pass() -> Node:
	var s: Node = await _scene("overworld")
	for attempt in TRIES:
		s.call("_start_leg", "pass")
		_check(s.call("walking"), "on the road to the pass")
		var eaten := 0  ## food the meals on the walk took (finds and foraging add some back)
		var foraged := false
		var fell := false
		_heal_up()
		while game.travel.has("to"):
			if not foraged:
				s.call("act", "forage")
				foraged = true
			await _frames(1)
			if tree.current_scene != s:
				if not await _fight_on_generated_map():
					fell = true
					break
				s = await _scene("overworld")
				continue
			if s.get("_busy"):
				await _press(s, 0)
			else:
				var food: int = game.run.food
				s.call("fast_forward")
				eaten += maxi(0, food - game.run.food)
		if not fell:
			_check(game.travel.get("at", "") == "pass", "arrived at the pass")
			_check(eaten > 0, "food drained on the walk")
			return s
		var v := await _fell("a road fight")
		await _use(v, "gate", "OPT_GO_ON")
		s = await _scene("overworld")
	_check(false, "reached the pass in %d tries" % TRIES)
	return s


## A fight from an overworld encounter (combat.tscn), on auto. OK goes back to the overworld.
func _fight_on_generated_map() -> bool:
	var c: Node = await _scene("combat")
	print("-- road fight")
	var waited := 0.0
	while c.get("battle").state != Battle.S.OVER:
		await tree.process_frame
		waited += tree.root.get_process_delta_time()
		if waited > SECONDS_CAP:
			_check(false, "road fight ended")
			return false
	await _frames(3)
	var units: Array = c.get("battle").units
	var won: bool = not CombatRules.team_alive(units, 1)
	if won:
		_check(true, "won the road fight")
	elif CombatRules.team_alive(units, 0):
		# Auto's stalemate guard ends the fight as a win, so OK goes back to the road, not to the square.
		_check(false, "the road fight ended in a stalemate (the AI couldn't reach)")
		won = true
	for b in c.get("hud").root.find_children("*", "Button", true, false):
		if (b as Button).text == Txt.t("UI_CONTINUE"):
			(b as Button).pressed.emit()
	await _frames(2)
	return won


## Walk up the way a player would: the fight starts 3 to 5 cells from the group, on a cell with a
## walkable way to it (the leader is moved there at once; the walk and the crypt's doors aren't the test).
func _approach(s: Node, g: Dictionary) -> void:
	var grid: CombatGrid = s.get("grid")
	var lead: CombatUnit = s.call("leader")
	var all := {}
	for y in grid.h:
		for x in grid.w:
			all[Vector2i(x, y)] = true
	var blocked: Dictionary = s.call("_blocked")
	var foes: Array = g.units.filter(func(u: CombatUnit) -> bool: return u.alive()).map(func(u: CombatUnit) -> Vector2i: return u.cell)
	var best := lead.cell
	var best_d := INF
	for c: Vector2i in all:
		if not grid.passable(c) or blocked.has(c):
			continue
		var d: float = foes.map(func(f: Vector2i) -> float: return ExploreRules.dist(c, f)).min()
		if d < 3.0 or d > 5.0 or absf(d - 4.0) >= best_d:
			continue
		if not foes.any(func(f: Vector2i) -> bool: return not ExploreRules.path_to_use(grid, c, f, lead.jump, {}, all).is_empty()):
			continue
		best = c
		best_d = absf(d - 4.0)
	lead.place(best, grid.height_at(best))
	s.call("_refresh_sight")


## Like a player before a fight: drink potions, then eat, while someone is hurt.
func _heal_up() -> void:
	while TravelRules.most_hurt(game.run) != {} and game.run.medicine > 0:
		TrailRules.heal(game.run)
	while TravelRules.most_hurt(game.run) != {} and game.run.food > 4:
		TravelRules.eat_one(game.run)
	game.refresh_party()


func _spend_picks() -> void:
	for id in ["lead", "dog"]:
		while game.level_state(id).pending > 0:
			_check(game.pick_boost(id, "hp" if id == "dog" else "attack"), "Lodestone pick for " + id)
