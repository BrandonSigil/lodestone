extends RefCounted
## Steps for tools/maker_shot.gd (loaded at runtime so the -s script compiles before the autoloads).


func run(m: Node, script: String) -> void:
	for step in script.split(",", false):
		var a := step.split(":")
		match a[0]:
			"tool":
				m.call("_set_tool", a[1])
			"saveas":  # open the save as card, optionally with a name typed
				m.call("open_save_as")
				if a.size() > 1:
					(m.get("_save_name") as LineEdit).text = a[1]
					m.call("_on_save_name", a[1])
			"item":
				m.call("pick_item", MakerCatalog.by_id(a[1]))
			"page":
				m.call("_show_page", a[1])
			"fight":
				var fd: Object = m.get("_fight_drawer")
				if not fd.get("open"):
					fd.call("_flip")
			"turn":
				m.call("_turn_item")
			"stamp":
				m.call("_push_undo")
				m.set("_stroke", {"button": MOUSE_BUTTON_LEFT, "done": {}})
				m.call("_stamp", Vector2i(int(a[1]), int(a[2])))
				m.set("_stroke", {})
			"select":
				m.call("_select", m.call("_pick", Vector2i(int(a[1]), int(a[2]))), true)
			"hover":
				var b: CombatBoard = m.get("board")
				var p := b.get_global_transform_with_canvas() * b.cell_top(Vector2i(int(a[1]), int(a[2])))
				m.get_viewport().warp_mouse(p)
			"search":
				m.get("_search").text = a[1]
				m.call("_build_catalog")
			"name":
				var sel: Dictionary = m.get("selection")
				m.call("_change_prop", func(q: Dictionary) -> void:
					q["name"] = a[1]
					q["sprite"] = "ph_" + MakerCatalog.slug(a[1]))
			"zoom":
				m.set("zoom", float(a[1]))
				m.call("_look_at", Vector2i(int(a[2]), int(a[3])))
			"blank":  # blank:<w>:<h>, a new blank map that size
				m.get("_w_spin").value = int(a[1])
				m.get("_h_spin").value = int(a[2])
				m.call("new_blank")
			"flat":  # flat:on|off, the flat sketch mode
				m.call("set_flat", a[1] == "on")
			"fdrawer":  # fdrawer:open, the flat brush drawer on the right panel
				var fdr: Object = m.get("_flat_drawer")
				if not fdr.get("open"):
					fdr.call("_flip")
			"fpaint":  # fpaint:<x1>:<y1>:<x2>:<y2>:<ground>:<height>: paint a line in the flat view
				var fv: FlatView = m.get("flat")
				fv.set_ground(int(a[5]))
				fv.set_height(int(a[6]))
				m.call("_push_undo")
				fv.paint_line(Vector2i(int(a[1]), int(a[2])), Vector2i(int(a[3]), int(a[4])))
			"view":  # flip a top-bar view toggle: soft, grid, heights, labels
				m.call("_toggle_view", a[1])
