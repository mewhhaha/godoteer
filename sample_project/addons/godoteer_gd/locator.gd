extends RefCounted
class_name GodoteerLocator

var screen: Object
var query: Dictionary
var description := "locator"


func _init(screen_instance: Object, locator_query: Dictionary, label: String = "locator") -> void:
	screen = screen_instance
	query = locator_query
	description = label


func node() -> Node:
	return screen.resolve_query(query)


func exists() -> bool:
	return node() != null


func click() -> void:
	var target := node()
	if target == null:
		screen.record_failure("Locator not found for click: %s" % description)
		return

	await screen.click(target)


func property(property_name: String):
	return screen.property(self, property_name)


func text() -> String:
	return screen.node_text(self)


func expect_exists(message: String = "") -> void:
	screen.expect_node(self, message if message != "" else "Expected locator to exist: %s" % description)


func expect_text(expected: String, message: String = "") -> void:
	screen.expect_text(self, expected, message)


func within() -> GodoteerLocator:
	return screen.within(self)


func get_by_role(role: String, options: Dictionary = {}) -> GodoteerLocator:
	return screen.get_by_role(role, options, self)


func query_by_role(role: String, options: Dictionary = {}) -> GodoteerLocator:
	return screen.query_by_role(role, options, self)


func find_by_role(role: String, options: Dictionary = {}) -> GodoteerLocator:
	return await screen.find_by_role(role, options, self)


func get_all_by_role(role: String, options: Dictionary = {}) -> Array:
	return screen.get_all_by_role(role, options, self)


func query_all_by_role(role: String, options: Dictionary = {}) -> Array:
	return screen.query_all_by_role(role, options, self)


func find_all_by_role(role: String, options: Dictionary = {}) -> Array:
	return await screen.find_all_by_role(role, options, self)


func get_by_text(text: String, options: Dictionary = {}) -> GodoteerLocator:
	return screen.get_by_text(text, options, self)


func query_by_text(text: String, options: Dictionary = {}) -> GodoteerLocator:
	return screen.query_by_text(text, options, self)


func find_by_text(text: String, options: Dictionary = {}) -> GodoteerLocator:
	return await screen.find_by_text(text, options, self)


func get_by_label_text(text: String, options: Dictionary = {}) -> GodoteerLocator:
	return screen.get_by_label_text(text, options, self)


func query_by_label_text(text: String, options: Dictionary = {}) -> GodoteerLocator:
	return screen.query_by_label_text(text, options, self)


func find_by_label_text(text: String, options: Dictionary = {}) -> GodoteerLocator:
	return await screen.find_by_label_text(text, options, self)


func get_by_placeholder_text(text: String, options: Dictionary = {}) -> GodoteerLocator:
	return screen.get_by_placeholder_text(text, options, self)


func query_by_placeholder_text(text: String, options: Dictionary = {}) -> GodoteerLocator:
	return screen.query_by_placeholder_text(text, options, self)


func find_by_placeholder_text(text: String, options: Dictionary = {}) -> GodoteerLocator:
	return await screen.find_by_placeholder_text(text, options, self)


func get_by_node_name(name: String) -> GodoteerLocator:
	return screen.get_by_node_name(name, self)


func query_by_node_name(name: String) -> GodoteerLocator:
	return screen.query_by_node_name(name, self)


func wait_for(timeout_sec: float = 2.0, step_frames: int = 1, message: String = "") -> bool:
	return await screen.wait_until(
		func() -> bool:
			return exists(),
		timeout_sec,
		step_frames,
		message if message != "" else "Timed out waiting for %s" % description
	)


func wait_for_text(expected: String, timeout_sec: float = 2.0, step_frames: int = 1, message: String = "") -> bool:
	return await screen.wait_until(
		func() -> bool:
			return text() == expected,
		timeout_sec,
		step_frames,
		message if message != "" else "Timed out waiting for text %s on %s" % [expected, description]
	)
