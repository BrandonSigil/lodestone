extends RefCounted
## Steps for tools/scale_test_shot.gd.


func run(s: Node, frames: int, who: int) -> void:
	if frames == 15 and s.get("battle") != null:
		var b: Battle = s.battle
		b._select(b.units[who])
		b._show_move_tiles()
