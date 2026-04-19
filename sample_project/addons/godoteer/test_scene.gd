extends "test_base.gd"
class_name GodoteerSceneTest

const GodoteerDriver = preload("driver.gd")

var current_test_name := ""
var _capturing_failure_artifact := false


func before_each(_driver: GodoteerDriver, _test_name: String) -> void:
	current_test_name = _test_name


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


func record_failure(message: String) -> void:
	super.record_failure(message)
	if quiet_failures or _capturing_failure_artifact:
		return

	var screen = _current_screen()
	if screen == null or not screen.can_screenshot():
		return

	_capturing_failure_artifact = true
	var safe_test_name := current_test_name.replace("/", "_").replace("\\", "_").replace(":", "_")
	var screenshot_path: String = screen.screenshot("failures/%s.png" % safe_test_name)
	_capturing_failure_artifact = false
	if screenshot_path != "":
		super.record_failure("Failure screenshot: %s" % screenshot_path)
