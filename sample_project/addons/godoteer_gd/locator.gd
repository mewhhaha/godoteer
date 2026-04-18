extends RefCounted
class_name GodoteerLocator

var driver: Object
var query: Dictionary
var description := "locator"


func _init(driver_instance: Object, locator_query: Dictionary, label: String = "locator") -> void:
	driver = driver_instance
	query = locator_query
	description = label


func node() -> Node:
	return driver.resolve_query(query)


func exists() -> bool:
	return node() != null


func click() -> void:
	var target := node()
	if target == null:
		driver.record_failure("Locator not found for click: %s" % description)
		return

	await driver.click(target)


func property(property_name: String):
	return driver.property(self, property_name)


func text() -> String:
	return driver.node_text(self)


func expect_exists(message: String = "") -> void:
	driver.expect_node(self, message if message != "" else "Expected locator to exist: %s" % description)


func expect_text(expected: String, message: String = "") -> void:
	driver.expect_text(self, expected, message)


func wait_for(timeout_sec: float = 2.0, step_frames: int = 1, message: String = "") -> bool:
	return await driver.wait_until(
		func() -> bool:
			return exists(),
		timeout_sec,
		step_frames,
		message if message != "" else "Timed out waiting for %s" % description
	)


func wait_for_text(expected: String, timeout_sec: float = 2.0, step_frames: int = 1, message: String = "") -> bool:
	return await driver.wait_until(
		func() -> bool:
			return text() == expected,
		timeout_sec,
		step_frames,
		message if message != "" else "Timed out waiting for text %s on %s" % [expected, description]
	)
