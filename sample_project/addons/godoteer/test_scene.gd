extends "test_base.gd"
class_name GodoteerSceneTest

const GodoteerDriver = preload("driver.gd")


func before_each(_driver: GodoteerDriver, _test_name: String) -> void:
	pass


func after_each(driver: GodoteerDriver, _test_name: String) -> void:
	await driver.reset()


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
