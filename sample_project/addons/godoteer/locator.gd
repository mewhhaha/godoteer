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


func hover() -> void:
	var target := node()
	if target == null:
		screen.record_failure("Locator not found for hover: %s" % description)
		return

	await screen.hover(target)


func focus() -> void:
	var target := node()
	if target == null:
		screen.record_failure("Locator not found for focus: %s" % description)
		return

	await screen.focus(target)


func blur() -> void:
	var target := node()
	if target == null:
		screen.record_failure("Locator not found for blur: %s" % description)
		return

	await screen.blur(target)


func fill(text: String) -> void:
	var target := node()
	if target == null:
		screen.record_failure("Locator not found for fill: %s" % description)
		return

	await screen.fill(target, text)


func clear() -> void:
	await fill("")


func press(keycode: Key) -> void:
	var target := node()
	if target == null:
		screen.record_failure("Locator not found for press: %s" % description)
		return

	await screen.press(target, keycode)


func drag_to(target_or_position: Variant, duration_sec: float = 0.2, steps: int = 12) -> void:
	var target := node()
	if target == null:
		screen.record_failure("Locator not found for drag_to: %s" % description)
		return

	await screen.drag_to(target, target_or_position, duration_sec, steps)


func check() -> void:
	var target := node()
	if target == null:
		screen.record_failure("Locator not found for check: %s" % description)
		return

	await screen.check(target)


func uncheck() -> void:
	var target := node()
	if target == null:
		screen.record_failure("Locator not found for uncheck: %s" % description)
		return

	await screen.uncheck(target)


func set_checked(checked: bool) -> void:
	var target := node()
	if target == null:
		screen.record_failure("Locator not found for set_checked: %s" % description)
		return

	await screen.set_checked(target, checked)


func select_option(option_text: String) -> void:
	var target := node()
	if target == null:
		screen.record_failure("Locator not found for select_option: %s" % description)
		return

	await screen.select_option(target, option_text)


func capture(file_name: String = "locator.png") -> String:
	var target := node()
	if target == null:
		screen.record_failure("Locator not found for capture: %s" % description)
		return ""

	return screen.capture_locator(target, file_name)


func property(property_name: String):
	return screen.property(self, property_name)


func text() -> String:
	return screen.node_text(self)


func value():
	return screen.node_value(self)


func expect_exists(message: String = "") -> void:
	screen.expect_node(self, message if message != "" else "Expected locator to exist: %s" % description)


func expect_text(expected: String, message: String = "") -> void:
	screen.expect_text(self, expected, message)


func to_exist(timeout_sec: float = 2.0) -> bool:
	return await _wait_for_condition(
		func() -> bool:
			return exists(),
		timeout_sec,
		func() -> String:
			return "Timed out waiting for locator to exist: %s" % description
	)


func not_to_exist(timeout_sec: float = 2.0) -> bool:
	return await _wait_for_condition(
		func() -> bool:
			return not exists(),
		timeout_sec,
		func() -> String:
			return "Timed out waiting for locator to stop existing: %s" % description
	)


func to_have_text(expected: String, timeout_sec: float = 2.0) -> bool:
	return await _wait_for_condition(
		func() -> bool:
			return text() == expected,
		timeout_sec,
		func() -> String:
			return "Timed out waiting for text on %s expected=%s actual=%s" % [description, expected, text()]
	)


func not_to_have_text(expected: String, timeout_sec: float = 2.0) -> bool:
	return await _wait_for_condition(
		func() -> bool:
			return text() != expected,
		timeout_sec,
		func() -> String:
			return "Timed out waiting for text on %s to differ from %s actual=%s" % [description, expected, text()]
	)


func to_have_value(expected, timeout_sec: float = 2.0) -> bool:
	return await _wait_for_condition(
		func() -> bool:
			return value() == expected,
		timeout_sec,
		func() -> String:
			return "Timed out waiting for value on %s expected=%s actual=%s" % [description, var_to_str(expected), var_to_str(value())]
	)


func to_be_visible(timeout_sec: float = 2.0) -> bool:
	return await _wait_for_condition(
		func() -> bool:
			return screen.is_visible(self),
		timeout_sec,
		func() -> String:
			return "Timed out waiting for %s to become visible" % description
	)


func to_be_hidden(timeout_sec: float = 2.0) -> bool:
	return await _wait_for_condition(
		func() -> bool:
			return not screen.is_visible(self),
		timeout_sec,
		func() -> String:
			return "Timed out waiting for %s to become hidden" % description
	)


func to_be_enabled(timeout_sec: float = 2.0) -> bool:
	return await _wait_for_condition(
		func() -> bool:
			return screen.is_enabled(self),
		timeout_sec,
		func() -> String:
			return "Timed out waiting for %s to become enabled" % description
	)


func to_be_disabled(timeout_sec: float = 2.0) -> bool:
	return await _wait_for_condition(
		func() -> bool:
			return not screen.is_enabled(self),
		timeout_sec,
		func() -> String:
			return "Timed out waiting for %s to become disabled" % description
	)


func to_be_checked(timeout_sec: float = 2.0) -> bool:
	return await _wait_for_condition(
		func() -> bool:
			return value() == true,
		timeout_sec,
		func() -> String:
			return "Timed out waiting for %s to become checked actual=%s" % [description, var_to_str(value())]
	)


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


func _wait_for_condition(predicate: Callable, timeout_sec: float, message_builder: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() <= deadline:
		if predicate.call():
			return true
		await screen.wait_frames(1)

	screen.record_failure(message_builder.call())
	return false
