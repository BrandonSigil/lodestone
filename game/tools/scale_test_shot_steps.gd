extends RefCounted
## Steps for tools/scale_test_shot.gd.


func run(s: Node, frames: int, who: int) -> void:
	if frames == 15 and s.get("battle") != null:
		var b: Battle = s.battle
		if who < 0:
			b._on_auto_toggled(true)
			return
		b._select(b.units[who])
		b._show_move_tiles()
