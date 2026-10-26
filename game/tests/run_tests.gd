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
]


func _initialize() -> void:
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
