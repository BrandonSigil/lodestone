extends Control
## The fishing minigame on its own (launch menu > Fishing): practice casts over a flat backdrop, one after
## another. Nothing goes in the pack and no save changes. ESC at Look (or LEAVE) goes back to the launcher.

var game: FishingGame
var casts := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = RisoTheme.make()
	resized.connect(queue_redraw)
	_again()


func _again() -> void:
	casts += 1
	game = FishingGame.open(self, "lake", FishingRules.mods_for(Game.run))
	game.finished.connect(func(res: Dictionary) -> void:
		if String(res.outcome) == "left":
			Game.go(Game.LAUNCH)
		else:
			_again.call_deferred())


func _draw() -> void:
	var p := Riso.palette_at(0.0)
	Riso.draw_sky(self, Rect2(Vector2.ZERO, size), p.sky_top, p.horizon)
	draw_rect(Rect2(0, size.y * 0.72, size.x, size.y * 0.28), p.ground)
