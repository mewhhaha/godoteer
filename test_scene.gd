extends "test_base.gd"
class_name GodoteerSceneTest

const GodoteerDriver = preload("driver.gd")

var current_test_name := ""
var _capturing_failure_artifact := false
var _trace_bundle_written := false


func before_each(_driver: GodoteerDriver, _test_name: String) -> void:
	current_test_name = _test_name
	_trace_bundle_written = false


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
	var driver = get_meta("godoteer_driver") if has_meta("godoteer_driver") else null
	if driver != null and driver.has_method("trace_event"):
		driver.trace_event("failure", {
			"message": message,
		})
	super.record_failure(message)
	if quiet_failures or _capturing_failure_artifact:
		return

	var screen = _current_screen()
	if screen != null and screen.can_screenshot():
		_capturing_failure_artifact = true
		var safe_test_name := current_test_name.replace("/", "_").replace("\\", "_").replace(":", "_")
		var screenshot_path: String = screen.screenshot("failures/%s.png" % safe_test_name)
		_capturing_failure_artifact = false
		if screenshot_path != "":
			super.record_failure("Failure screenshot: %s" % screenshot_path)
			if driver != null and driver.has_method("trace_event"):
				driver.trace_event("artifact_linked", {
					"message": "Failure screenshot: %s" % screenshot_path,
					"file_path": screenshot_path,
				})

	if _trace_bundle_written:
		return

	_trace_bundle_written = true
	if driver == null or not driver.has_method("write_failure_trace_bundle"):
		return
	var bundle: Dictionary = driver.write_failure_trace_bundle(failures.duplicate())
	if str(bundle.get("error", "")) != "":
		super.record_failure(str(bundle.get("error", "")))
		return
	var trace_path := str(bundle.get("trace_path", ""))
	if trace_path != "":
		super.record_failure("Failure trace: %s" % trace_path)
