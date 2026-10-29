extends RefCounted

var finished := false


func play(tree: SceneTree, args: PackedStringArray) -> void:
	var game: Node = tree.root.get_node("Game")
	var map_name := args[0] if args.size() > 0 else "snow_pass"
	var group_id := args[1] if args.size() > 1 else "pass_wolves"
	var tries := int(args[2]) if args.size() > 2 else 10
	Engine.time_scale = 8.0
	game.save_enabled = false
	Battle.auto_fight = true
	var wins := 0
	for i in tries:
		seed(1000 + i)
		game.new_game()
		game.set_flag("weapon_sword")
		game.set_flag("met_dog")
		game.set_flag("has_lodestone")
		game.run = null
		game.ensure_run()
		game.explore_map = map_name
		game.explore_entry = Vector2i(-1, -1)
		game.go(game.EXPLORE)
		var s: Node = null
		while s == null or not String(s.scene_file_path).ends_with("explore.tscn") or s.get("battle") == null and s.get("mode") != 0:
			await tree.process_frame
			s = tree.current_scene
		for _f in 3:
			await tree.process_frame
		if s.get("_dialog") != null:
			s.call("_close_dialog")
			s.set("mode", 0)
		var g := {}
		for x: Dictionary in s.get("groups"):
			if x.def.id == group_id:
				g = x
		var lead: CombatUnit = s.call("leader")
		var target: Vector2i = g.units[0].cell
		var path: Array[Vector2i] = ExploreRules.path_to_use(s.get("grid"), lead.cell, target, lead.jump, s.call("_blocked"))
		s.call("walk", path)
		var waited := 0
		while s.get("mode") == 0 and waited < 2000:
			await tree.process_frame
			waited += 1
		var how := "?"
		if s.get("mode") == 2:  # the box: we saw them first; FIGHT
			how = "party"
			s.call("start_fight", g, "party")
		elif s.get("mode") == 3:
			how = String(s.get("_pending").how)
		var at: Vector2i = lead.cell
		while s.get("battle") == null or s.get("battle").state != Battle.S.OVER:
			await tree.process_frame
		var units: Array = s.get("battle").units
		var won := not CombatRules.team_alive(units, 1)
		wins += 1 if won else 0
		var desc := []
		for u: CombatUnit in units:
			desc.append("%s@%s h%d hp%d/%d" % [Txt.t(u.name_key), u.cell, s.get("grid").height_at(u.cell), u.hp, u.max_hp])
		print("try %d: %s from %s (h%d) -> %s   %s" % [i, how, at, s.get("grid").height_at(at), "WIN" if won else "LOSS", ", ".join(desc)])
		s.set("mode", 5)
	print("%s / %s: won %d of %d" % [map_name, group_id, wins, tries])
	finished = true
