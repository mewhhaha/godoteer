extends RefCounted
class_name GodoteerTestCase

const GodoteerDriver = preload("res://addons/godoteer_gd/driver.gd")

var screen: GodoteerDriver
var app_root: Node
var failures: Array[String] = []


func bind(screen_instance: GodoteerDriver, root_node: Node) -> void:
	screen = screen_instance
	app_root = root_node


func before_each(screen: GodoteerDriver) -> void:
	await screen.wait_frames(1)


func run(screen: GodoteerDriver) -> void:
	record_failure("Override `run()` in %s" % get_script().resource_path)
	await screen.wait_frames(1)


func after_each(screen: GodoteerDriver) -> void:
	await screen.wait_frames(1)


func execute() -> void:
	await before_each(screen)
	await run(screen)
	await after_each(screen)


func record_failure(message: String) -> void:
	failures.append(message)
	printerr("FAIL: %s" % message)


func has_failures() -> bool:
	return failures.size() > 0


func failure_count() -> int:
	return failures.size()


func summary() -> String:
	return "\n".join(failures)


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
	screen.expect_node(path_or_node, message)


func expect_property(path_or_node: Variant, property_name: String, expected: Variant, message: String = "") -> void:
	screen.expect_property(path_or_node, property_name, expected, message)
