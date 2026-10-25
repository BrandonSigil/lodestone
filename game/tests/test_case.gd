class_name TestCase
extends RefCounted
## Tiny test base: subclasses define test_* methods and call ok() / eq().

var failures: Array[String] = []
var current := ""


func ok(cond: bool, msg := "") -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg])


func eq(a: Variant, b: Variant, msg := "") -> void:
	if a != b:
		failures.append("%s: expected %s, got %s %s" % [current, str(b), str(a), msg])


static func members_of(ids: Array) -> Array:
	var defs := []
	for id in ids:
		defs.append(load("res://data/characters/%s.tres" % id))
	return defs
