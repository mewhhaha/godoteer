extends RefCounted
class_name GodoteerTestCase

const GodoteerDriver = preload("res://addons/godoteer_gd/driver.gd")

var failures: Array[String] = []
var quiet_failures := false


func before_each(_driver: GodoteerDriver, _test_name: String) -> void:
	pass


func after_each(driver: GodoteerDriver, _test_name: String) -> void:
	await driver.reset()


func list_tests() -> PackedStringArray:
	var names: PackedStringArray = []
	for method_info in get_method_list():
		var method_name := str(method_info.get("name", ""))
		if method_name.begins_with("test_"):
			names.append(method_name)

	names.sort()
	return names


func record_failure(message: String) -> void:
	failures.append(message)
	if not quiet_failures:
		printerr("FAIL: %s" % message)


func has_failures() -> bool:
	return failures.size() > 0


func failure_count() -> int:
	return failures.size()


func summary() -> String:
	return "\n".join(failures)


func drain_failures() -> Array[String]:
	var drained := failures.duplicate()
	failures.clear()
	return drained


func set_failures_quiet(enabled: bool) -> void:
	quiet_failures = enabled


func fail(message: String) -> void:
	record_failure(message)


func expect_true(condition: bool, message: String = "Expected value to be true") -> void:
	if not condition:
		record_failure(message)


func expect_false(condition: bool, message: String = "Expected value to be false") -> void:
	if condition:
		record_failure(message)


func expect_equal(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		if message == "":
			message = "Expected %s, got %s" % [var_to_str(expected), var_to_str(actual)]
		record_failure(message)


func expect_not_null(value: Variant, message: String = "Expected non-null value") -> void:
	if value == null:
		record_failure(message)


func expect_node(path_or_node: Variant, message: String = "") -> void:
	var screen = _current_screen()
	if screen != null:
		screen.expect_node(path_or_node, message)


func expect_property(path_or_node: Variant, property_name: String, expected: Variant, message: String = "") -> void:
	var screen = _current_screen()
	if screen != null:
		screen.expect_property(path_or_node, property_name, expected, message)


func _current_screen():
	if not has_meta("godoteer_driver"):
		return null

	var driver = get_meta("godoteer_driver")
	if driver == null:
		return null

	return driver.current_screen
