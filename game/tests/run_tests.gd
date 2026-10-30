extends SceneTree
## Headless test runner: godot --headless --path game -s res://tests/run_tests.gd

const SUITES := [
	"res://tests/test_dice.gd",
	"res://tests/test_combat.gd",
	"res://tests/test_trail.gd",
	"res://tests/test_data.gd",
	"res://tests/test_world.gd",
	"res://tests/test_village.gd",
	"res://tests/test_sandbox.gd",
	"res://tests/test_traits.gd",
	"res://tests/test_explore.gd",
	"res://tests/test_maps.gd",
	"res://tests/test_terrain.gd",
	"res://tests/test_shape.gd",
	"res://tests/test_maker_pieces.gd",
	"res://tests/test_snow_pass.gd",
	"res://tests/test_loop.gd",
	"res://tests/test_pack.gd",
	"res://tests/test_decks.gd",
	"res://tests/test_sheets.gd",
]


var _done := false


## Runs on the first frame rather than in _initialize, so the root is in the tree and suites can stand
## scenes up (their _ready runs when they are added).
func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	Engine.set_meta("no_scale_standard", true)  # the suites assume the old move and reach (ScaleTest.PAUSE_META)
	var total := 0
	var failed: Array[String] = []
	for path in SUITES:
		var suite: TestCase = load(path).new()
		for m in suite.get_method_list():
			var n: String = m.name
			if not n.begins_with("test_"):
				continue
			total += 1
			suite.current = path.get_file() + ":" + n
			suite.call(n)
		failed.append_array(suite.failures)
	for f in failed:
		printerr("FAIL ", f)
	print("%d tests, %d failures" % [total, failed.size()])
	quit(1 if failed.size() > 0 else 0)
	return false
