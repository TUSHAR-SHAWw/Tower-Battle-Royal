class_name TestCase
extends Node

## Minimal test base — no third-party addon, no scene wiring.
##
## Suites extend this, add `test_*` methods, and TestRunner discovers them by name.
## Assertions *record* failures instead of aborting, because GDScript has no
## exceptions: one broken expectation must not hide the other nine (master prompt §55).
##
## Tests may be synchronous or coroutines — `await get_tree().physics_frame` inside
## a test is how movement and combat are verified against real physics ticks.

var failures: Array[String] = []
var assertion_count: int = 0

var _current_test: String = ""


## Hook: runs once before all tests in this suite (build fixtures here).
func before_suite() -> void:
	pass


## Hook: runs once after all tests.
func after_suite() -> void:
	pass


func before_each() -> void:
	pass


func after_each() -> void:
	pass


## Discovers `test_*` methods, in alphabetical order, and runs them.
func run_suite() -> void:
	await get_tree().process_frame
	before_suite()
	for test_method: StringName in test_method_names():
		_current_test = String(test_method)
		before_each()
		await call(test_method)
		after_each()
	after_suite()


func test_method_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for method: Dictionary in get_method_list():
		var method_name: String = method.get("name", "")
		if method_name.begins_with("test_") and not names.has(StringName(method_name)):
			names.append(StringName(method_name))
	names.sort()
	return names


func suite_name() -> String:
	return name


# ------------------------------------------------------------------- assertions

func fail(message: String) -> void:
	var where := "%s::%s" % [suite_name(), _current_test]
	failures.append("%s — %s" % [where, message])
	GameLog.err("Test", "%s — %s" % [where, message])


func assert_true(condition: bool, message: String = "") -> void:
	assertion_count += 1
	if not condition:
		fail(("expected true, got false" if message.is_empty() else message))


func assert_false(condition: bool, message: String = "") -> void:
	assertion_count += 1
	if condition:
		fail(("expected false, got true" if message.is_empty() else message))


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	assertion_count += 1
	if actual != expected:
		fail("expected %s, got %s%s" % [expected, actual, _suffix(message)])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	assertion_count += 1
	if actual == unexpected:
		fail("expected value to differ from %s%s" % [unexpected, _suffix(message)])


func assert_null(value: Variant, message: String = "") -> void:
	assertion_count += 1
	if value != null:
		fail("expected null, got %s%s" % [value, _suffix(message)])


func assert_not_null(value: Variant, message: String = "") -> void:
	assertion_count += 1
	if value == null:
		fail("expected a value, got null%s" % _suffix(message))


func assert_almost_eq(actual: float, expected: float, message: String = "", epsilon: float = 0.0001) -> void:
	assertion_count += 1
	if absf(actual - expected) > epsilon:
		fail("expected %f (+/-%f), got %f%s" % [expected, epsilon, actual, _suffix(message)])


func assert_vector_almost_eq(actual: Vector2, expected: Vector2, message: String = "", epsilon: float = 0.0001) -> void:
	assertion_count += 1
	if (actual - expected).length() > epsilon:
		fail("expected %s, got %s%s" % [expected, actual, _suffix(message)])


func assert_greater(actual: float, threshold: float, message: String = "") -> void:
	assertion_count += 1
	if actual <= threshold:
		fail("expected > %f, got %f%s" % [threshold, actual, _suffix(message)])


func assert_less(actual: float, threshold: float, message: String = "") -> void:
	assertion_count += 1
	if actual >= threshold:
		fail("expected < %f, got %f%s" % [threshold, actual, _suffix(message)])


func assert_in_range(actual: float, low: float, high: float, message: String = "") -> void:
	assertion_count += 1
	if actual < low or actual > high:
		fail("expected %f..%f, got %f%s" % [low, high, actual, _suffix(message)])


func assert_has(input_map_action: StringName, message: String = "") -> void:
	assertion_count += 1
	if not InputMap.has_action(input_map_action):
		fail("InputMap action '%s' is missing%s" % [input_map_action, _suffix(message)])


func _suffix(message: String) -> String:
	return "" if message.is_empty() else " [%s]" % message
