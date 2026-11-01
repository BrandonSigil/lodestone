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
			"pline":  # pline:<x1>:<y1>:<x2>:<y2>: apply the current tool along a line (a drag), as a stroke
				m.call("_push_undo")
				m.set("_stroke", {"button": MOUSE_BUTTON_LEFT, "done": {}})
				for c in MapOps.line(Vector2i(int(a[1]), int(a[2])), Vector2i(int(a[3]), int(a[4]))):
					m.call("_apply", c, false)
				m.set("_stroke", {})
			"keys":  # keys: open the ? key map
				m.call("_toggle_keys")
			"width":  # width:<n>, the size of the brush or line: 1 to 4
				m.call("_set_width", int(a[1]))
			"mat":  # mat:<ground material label with _ for spaces>: pick a ground material for the Ground tool
				for mat in m.get("MATERIALS"):
					if String(mat[0]) == String(a[1]).replace("_", " "):
						m.set("paint_t", int(mat[1]))
						m.set("paint_set", String(mat[2]))
						m.set("paint_mat", String(mat[0]))
			"region":  # region:<x1>:<y1>:<x2>:<y2>: select a box with the Area tool
				m.call("_set_tool", "region")
				m.set("_box", {"start": Vector2i(int(a[1]), int(a[2])), "last": Vector2i(int(a[3]), int(a[4]))})
				m.call("_preview_box")
				m.set("_box", {})
			"shift":  # shift:<dz>: raise or lower the selected area
				m.call("region_shift", int(a[1]))
			"bridge":  # bridge:<x1>:<y1>:<x2>:<y2>: the Bridge tool's drag from one landing to another
				m.call("_push_undo")
				var res: Dictionary = MapOps.bridge_span(m.get("doc").grid, Vector2i(int(a[1]), int(a[2])), Vector2i(int(a[3]), int(a[4])), int(m.get("width")))
				print("BRIDGE ", res.error, " ", (res.cells as Array).size())
			"phase":  # phase:<shape|decor|play>
				m.call("_set_phase", a[1])
			"level":  # level:<n>: the level height (and the Level tool)
				m.call("set_level_height", int(a[1]))
			"ground":  # ground:<terrain int>: the Ground tool's ground
				m.set("paint_t", int(a[1]))
			"view":  # flip a top-bar view toggle: soft, grid, heights, labels
				m.call("_toggle_view", a[1])
			"qa":  # qa: press the QA button (run every check, open the QA tab, paint the problems)
				m.call("run_qa", true)
			"qafly":  # qafly:<check index>:<problem index>: click a QA problem row (fly to it)
				var res: Array = m.get("qa")
				var pr: Array = res[int(a[1])].problems
				m.call("qa_fly", pr[int(a[2])].cell)
