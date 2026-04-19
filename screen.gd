extends RefCounted
class_name GodoteerScreen

const GodoteerLocator = preload("locator.gd")

var tree: SceneTree
var app_root: Node
var failure_sink: Object
var artifacts_dir := "user://artifacts"
var last_mouse_position := Vector2.ZERO


func _init(scene_tree: SceneTree, root_node: Node, sink: Object, artifacts_path: String = "user://artifacts") -> void:
	tree = scene_tree
	app_root = root_node
	failure_sink = sink
	artifacts_dir = artifacts_path.trim_suffix("/")


func wait_frames(count: int = 1) -> void:
	for _i in range(max(count, 1)):
		await tree.process_frame


func wait_seconds(seconds: float) -> void:
	await tree.create_timer(max(seconds, 0.0)).timeout


func wait_until(predicate: Callable, timeout_sec: float = 2.0, step_frames: int = 1, message: String = "Condition timed out") -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() <= deadline:
		if predicate.call():
			return true
		await wait_frames(step_frames)

	_record_failure(message)
	return false


func node(path_or_node: Variant) -> Node:
	if typeof(path_or_node) == TYPE_OBJECT and not is_instance_valid(path_or_node):
		return null

	if path_or_node is Node:
		return path_or_node if is_instance_valid(path_or_node) else null

	if path_or_node is GodoteerLocator:
		return path_or_node.node()

	var path := str(path_or_node)
	if path == "":
		return null

	if path.begins_with("/root"):
		return tree.root.get_node_or_null(path)

	if app_root == null:
		return null

	return app_root.get_node_or_null(path)


func node_exists(path_or_node: Variant) -> bool:
	return node(path_or_node) != null


func property(path_or_node: Variant, property_name: String):
	var target := node(path_or_node)
	if target == null:
		_record_failure("Node missing for property read: %s" % str(path_or_node))
		return null

	return target.get(property_name)


func node_text(path_or_node: Variant) -> String:
	return _visible_text(node(path_or_node))


func node_value(path_or_node: Variant):
	var target := node(path_or_node)
	if target == null:
		return null

	if target is LineEdit or target is TextEdit:
		return target.text
	if target is CheckBox or target is CheckButton:
		return target.button_pressed
	if target is OptionButton:
		if target.selected >= 0:
			return target.get_item_text(target.selected)
		return null
	if _has_property(target, "value"):
		return target.get("value")
	if _has_property(target, "text"):
		return target.get("text")
	return null


func is_visible(path_or_node: Variant) -> bool:
	var target := node(path_or_node)
	if target == null:
		return false
	if target is CanvasItem:
		return target.is_visible_in_tree()
	return true


func is_enabled(path_or_node: Variant) -> bool:
	var target := node(path_or_node)
	if target == null:
		return false
	if target is Control:
		return not target.disabled
	return true


func click(target: Variant, button: int = MOUSE_BUTTON_LEFT) -> void:
	var target_node := node(target)
	if target_node is BaseButton:
		target_node.grab_focus()
		target_node.pressed.emit()
		await wait_frames(1)
		return

	var position := _resolve_position(target)
	if position == null:
		_record_failure("Could not resolve click target: %s" % str(target))
		return

	mouse_move(position)
	await wait_frames(1)
	mouse_button(position, button, true)
	await wait_frames(1)
	mouse_button(position, button, false)
	await wait_frames(1)


func hover(target: Variant) -> void:
	var target_node := node(target)
	var position := _resolve_position(target)
	if position == null:
		_record_failure("Could not resolve hover target: %s" % str(target))
		return

	mouse_move(position)
	if target_node is Control:
		target_node.mouse_entered.emit()
	await wait_frames(1)


func focus(target: Variant) -> void:
	var target_node := node(target)
	if target_node is Control:
		target_node.grab_focus()
		await wait_frames(1)
		return

	_record_failure("focus() supports Control only: %s" % str(target))


func blur(target: Variant) -> void:
	var target_node := node(target)
	if target_node is Control:
		target_node.release_focus()
		await wait_frames(1)
		return

	_record_failure("blur() supports Control only: %s" % str(target))


func fill(target: Variant, text: String) -> void:
	var target_node := node(target)
	if target_node is LineEdit:
		target_node.grab_focus()
		target_node.text = text
		target_node.text_changed.emit(text)
		await wait_frames(1)
		return

	if target_node is TextEdit:
		target_node.grab_focus()
		target_node.text = text
		await wait_frames(1)
		return

	_record_failure("fill() supports LineEdit and TextEdit only: %s" % str(target))


func clear(target: Variant) -> void:
	await fill(target, "")


func press(target: Variant, keycode: Key) -> void:
	var target_node := node(target)
	if target_node is Control:
		target_node.grab_focus()
	await key_tap(keycode)


func drag_to(source: Variant, target_or_position: Variant, duration_sec: float = 0.2, steps: int = 12) -> void:
	var source_node := node(source)
	var target_node := node(target_or_position)
	var from_position := _resolve_position(source)
	var to_position := _resolve_position(target_or_position)
	if from_position == null or to_position == null:
		_record_failure("drag_to() could not resolve source or target: %s -> %s" % [str(source), str(target_or_position)])
		return

	mouse_move(from_position)
	await wait_frames(1)
	var press_event := InputEventMouseButton.new()
	press_event.position = from_position
	press_event.global_position = from_position
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	Input.parse_input_event(press_event)
	last_mouse_position = from_position
	if source_node is Control:
		source_node.gui_input.emit(press_event)
	await wait_frames(1)
	await move_mouse_between(from_position, to_position, duration_sec, steps)
	if target_node is Control:
		target_node.mouse_entered.emit()
	var release_event := InputEventMouseButton.new()
	release_event.position = to_position
	release_event.global_position = to_position
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	Input.parse_input_event(release_event)
	last_mouse_position = to_position
	if target_node is Control:
		target_node.gui_input.emit(release_event)
	await wait_frames(1)


func check(target: Variant) -> void:
	var target_node := node(target)
	if target_node is CheckBox or target_node is CheckButton:
		if not target_node.button_pressed:
			target_node.button_pressed = true
			target_node.toggled.emit(true)
		await wait_frames(1)
		return

	_record_failure("check() supports CheckBox and CheckButton only: %s" % str(target))


func uncheck(target: Variant) -> void:
	var target_node := node(target)
	if target_node is CheckBox or target_node is CheckButton:
		if target_node.button_pressed:
			target_node.button_pressed = false
			target_node.toggled.emit(false)
		await wait_frames(1)
		return

	_record_failure("uncheck() supports CheckBox and CheckButton only: %s" % str(target))


func set_checked(target: Variant, checked: bool) -> void:
	if checked:
		await check(target)
	else:
		await uncheck(target)


func select_option(target: Variant, option_text: String) -> void:
	var target_node := node(target)
	if target_node is OptionButton:
		for index in range(target_node.item_count):
			if target_node.get_item_text(index) == option_text:
				target_node.select(index)
				target_node.item_selected.emit(index)
				await wait_frames(1)
				return
		_record_failure("Option not found for select_option(): %s on %s" % [option_text, str(target)])
		return

	_record_failure("select_option() supports OptionButton only: %s" % str(target))


func mouse_move(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	last_mouse_position = position


func mouse_button(position: Vector2, button: int = MOUSE_BUTTON_LEFT, pressed: bool = true) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	last_mouse_position = position


func move_mouse_between(
	from_position: Vector2,
	to_position: Vector2,
	duration_sec: float = 0.2,
	steps: int = 12
) -> void:
	mouse_move(from_position)

	var distance := from_position.distance_to(to_position)
	if distance <= 0.0:
		await wait_frames(1)
		return

	var safe_steps: int = max(1, steps)
	var safe_duration_sec: float = max(duration_sec, 0.0)
	var delay_sec: float = safe_duration_sec / float(safe_steps)

	for index in range(1, safe_steps + 1):
		var weight := float(index) / float(safe_steps)
		mouse_move(from_position.lerp(to_position, weight))
		if delay_sec > 0.0:
			await tree.create_timer(delay_sec).timeout


func move_mouse_to(
	to_position: Vector2,
	duration_sec: float = 0.2,
	steps: int = 12
) -> void:
	await move_mouse_between(last_mouse_position, to_position, duration_sec, steps)


func key_tap(keycode: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)

	var release := InputEventKey.new()
	release.keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)

	await wait_frames(1)


func screenshot(file_name: String = "screenshot.png") -> String:
	if not can_screenshot():
		_record_failure("Screenshots unavailable with current renderer/window mode")
		return ""

	var save_path := artifacts_dir.path_join(file_name)
	var absolute_path := ProjectSettings.globalize_path(save_path)
	var absolute_dir := absolute_path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK:
		_record_failure("Could not create screenshot dir: %s" % absolute_dir)
		return ""

	var image := tree.root.get_viewport().get_texture().get_image()
	var save_error := image.save_png(absolute_path)
	if save_error != OK:
		_record_failure("Could not save screenshot: %s" % save_path)
		return ""

	return absolute_path


func capture_locator(target: Variant, file_name: String = "locator.png") -> String:
	return screenshot(file_name)


func can_screenshot() -> bool:
	if DisplayServer.get_name() == "headless":
		return false

	return tree.root.get_viewport().get_texture() != null


func screen_reader_supported() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_ACCESSIBILITY_SCREEN_READER)


func screen_reader_active() -> int:
	return int(DisplayServer.accessibility_screen_reader_active())


func accessible_name(target: Variant) -> String:
	return _accessible_name(node(target))


func accessible_description(target: Variant) -> String:
	return _accessible_description(node(target))


func expect_accessible_name(target: Variant, expected: String, message: String = "") -> void:
	var actual := accessible_name(target)
	if actual != expected:
		if message == "":
			message = "Accessible name mismatch expected=%s actual=%s" % [expected, actual]
		_record_failure(message)


func expect_accessible_description(target: Variant, expected: String, message: String = "") -> void:
	var actual := accessible_description(target)
	if actual != expected:
		if message == "":
			message = "Accessible description mismatch expected=%s actual=%s" % [expected, actual]
		_record_failure(message)


func locator(target: Variant) -> GodoteerLocator:
	return GodoteerLocator.new(self, {"kind": "target", "value": target}, "locator(%s)" % str(target))


func within(target: Variant) -> GodoteerLocator:
	return GodoteerLocator.new(self, {"kind": "target", "value": target}, "within(%s)" % str(target))


func get_by_role(role: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return _get_single_locator(_build_role_query("get_by_role", role, options, root_target))


func query_by_role(role: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return _query_single_locator(_build_role_query("query_by_role", role, options, root_target))


func find_by_role(role: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return await _find_single_locator(_build_role_query("find_by_role", role, options, root_target))


func get_all_by_role(role: String, options: Dictionary = {}, root_target: Variant = null) -> Array:
	return _get_all_locators(_build_role_query("get_all_by_role", role, options, root_target))


func query_all_by_role(role: String, options: Dictionary = {}, root_target: Variant = null) -> Array:
	return _query_all_locators(_build_role_query("query_all_by_role", role, options, root_target))


func find_all_by_role(role: String, options: Dictionary = {}, root_target: Variant = null) -> Array:
	return await _find_all_locators(_build_role_query("find_all_by_role", role, options, root_target))


func get_by_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return _get_single_locator(_build_text_query("get_by_text", "text", text, options, root_target))


func query_by_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return _query_single_locator(_build_text_query("query_by_text", "text", text, options, root_target))


func find_by_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return await _find_single_locator(_build_text_query("find_by_text", "text", text, options, root_target))


func get_by_label_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return _get_single_locator(_build_text_query("get_by_label_text", "label_text", text, options, root_target))


func query_by_label_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return _query_single_locator(_build_text_query("query_by_label_text", "label_text", text, options, root_target))


func find_by_label_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return await _find_single_locator(_build_text_query("find_by_label_text", "label_text", text, options, root_target))


func get_by_placeholder_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return _get_single_locator(_build_text_query("get_by_placeholder_text", "placeholder_text", text, options, root_target))


func query_by_placeholder_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return _query_single_locator(_build_text_query("query_by_placeholder_text", "placeholder_text", text, options, root_target))


func find_by_placeholder_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return await _find_single_locator(_build_text_query("find_by_placeholder_text", "placeholder_text", text, options, root_target))


func get_by_node_name(name: String, root_target: Variant = null) -> GodoteerLocator:
	return _get_single_locator(_build_node_name_query("get_by_node_name", name, root_target))


func query_by_node_name(name: String, root_target: Variant = null) -> GodoteerLocator:
	return _query_single_locator(_build_node_name_query("query_by_node_name", name, root_target))


func resolve_query(query: Dictionary) -> Node:
	if str(query.get("kind", "")) != "target":
		return null

	return node(query.get("value", null))


func expect_node(path_or_node: Variant, message: String = "") -> void:
	if node(path_or_node) == null:
		if message == "":
			message = "Expected node to exist: %s" % str(path_or_node)
		_record_failure(message)


func expect_property(path_or_node: Variant, property_name: String, expected: Variant, message: String = "") -> void:
	var actual = property(path_or_node, property_name)
	if actual != expected:
		if message == "":
			message = "Property mismatch for %s.%s expected=%s actual=%s" % [
				str(path_or_node),
				property_name,
				var_to_str(expected),
				var_to_str(actual),
			]
		_record_failure(message)


func expect_text(path_or_node: Variant, expected: String, message: String = "") -> void:
	var actual := node_text(path_or_node)
	if actual != expected:
		if message == "":
			message = "Text mismatch expected=%s actual=%s" % [expected, actual]
		_record_failure(message)


func record_failure(message: String) -> void:
	_record_failure(message)


func _has_property(target: Object, property_name: String) -> bool:
	for property_info in target.get_property_list():
		if str(property_info.get("name", "")) == property_name:
			return true
	return false


func _resolve_position(target: Variant) -> Variant:
	if target is Vector2:
		return target

	var target_node := node(target)
	if target_node == null:
		return null

	if target_node is Control:
		return target_node.get_global_rect().get_center()

	if target_node is Node2D:
		return target_node.global_position

	return null


func _build_role_query(method_name: String, role: String, options: Dictionary, root_target: Variant) -> Dictionary:
	var normalized := _normalize_query_options(options)
	return {
		"kind": "role",
		"role": role.to_lower(),
		"options": normalized,
		"root": root_target,
		"label": "%s(%s, %s)" % [method_name, role, var_to_str(normalized)],
	}


func _build_text_query(method_name: String, kind: String, text: String, options: Dictionary, root_target: Variant) -> Dictionary:
	var normalized := _normalize_query_options(options)
	return {
		"kind": kind,
		"text": text,
		"options": normalized,
		"root": root_target,
		"label": "%s(%s, %s)" % [method_name, text, var_to_str(normalized)],
	}


func _build_node_name_query(method_name: String, name: String, root_target: Variant) -> Dictionary:
	return {
		"kind": "node_name",
		"text": name,
		"options": _normalize_query_options({}),
		"root": root_target,
		"label": "%s(%s)" % [method_name, name],
	}


func _normalize_query_options(options: Dictionary) -> Dictionary:
	return {
		"name": str(options.get("name", "")),
		"exact": bool(options.get("exact", true)),
		"include_hidden": bool(options.get("include_hidden", false)),
	}


func _get_single_locator(query: Dictionary) -> GodoteerLocator:
	var matches := _resolve_matches(query)
	if matches.is_empty():
		_record_failure("Expected exactly one match for %s, found none" % query["label"])
		return null
	if matches.size() > 1:
		_record_failure("Expected exactly one match for %s, found %d" % [query["label"], matches.size()])
		return null
	return _target_locator(matches[0], str(query["label"]))


func _query_single_locator(query: Dictionary) -> GodoteerLocator:
	var matches := _resolve_matches(query)
	if matches.is_empty():
		return null
	if matches.size() > 1:
		_record_failure("Expected at most one match for %s, found %d" % [query["label"], matches.size()])
		return null
	return _target_locator(matches[0], str(query["label"]))


func _find_single_locator(query: Dictionary, timeout_sec: float = 2.0, step_frames: int = 1) -> GodoteerLocator:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() <= deadline:
		var matches := _resolve_matches(query)
		if matches.size() == 1:
			return _target_locator(matches[0], str(query["label"]))
		await wait_frames(step_frames)

	var final_matches := _resolve_matches(query)
	if final_matches.is_empty():
		_record_failure("Timed out waiting for exactly one match for %s" % query["label"])
	else:
		_record_failure("Expected exactly one match for %s, found %d" % [query["label"], final_matches.size()])
	return null


func _get_all_locators(query: Dictionary) -> Array:
	var matches := _resolve_matches(query)
	if matches.is_empty():
		_record_failure("Expected at least one match for %s, found none" % query["label"])
		return []
	return _nodes_to_locators(matches, str(query["label"]))


func _query_all_locators(query: Dictionary) -> Array:
	return _nodes_to_locators(_resolve_matches(query), str(query["label"]))


func _find_all_locators(query: Dictionary, timeout_sec: float = 2.0, step_frames: int = 1) -> Array:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() <= deadline:
		var matches := _resolve_matches(query)
		if not matches.is_empty():
			return _nodes_to_locators(matches, str(query["label"]))
		await wait_frames(step_frames)

	_record_failure("Timed out waiting for at least one match for %s" % query["label"])
	return []


func _nodes_to_locators(nodes: Array, description: String) -> Array:
	var locators: Array = []
	for candidate in nodes:
		locators.append(_target_locator(candidate, description))
	return locators


func _target_locator(target: Variant, description: String) -> GodoteerLocator:
	return GodoteerLocator.new(self, {"kind": "target", "value": target}, description)


func _resolve_matches(query: Dictionary) -> Array:
	var start := _query_root(query.get("root", null))
	var matches: Array = []
	_collect_matches(start, query, matches)
	return matches


func _query_root(root_target: Variant) -> Node:
	if root_target == null:
		return app_root if app_root != null else tree.root

	return node(root_target)


func _collect_matches(start: Node, query: Dictionary, matches: Array) -> void:
	if start == null:
		return

	if _candidate_matches(start, query):
		matches.append(start)

	for child in start.get_children():
		_collect_matches(child, query, matches)


func _candidate_matches(candidate: Node, query: Dictionary) -> bool:
	var kind := str(query.get("kind", ""))
	if kind != "node_name" and not bool(query.get("options", {}).get("include_hidden", false)) and _is_hidden(candidate):
		return false

	match kind:
		"role":
			return _role_matches(candidate, query)
		"text":
			return _string_matches(_visible_text(candidate), str(query.get("text", "")), bool(query["options"]["exact"]))
		"label_text":
			return _string_matches(_label_text(candidate), str(query.get("text", "")), bool(query["options"]["exact"]))
		"placeholder_text":
			return _string_matches(_placeholder_text(candidate), str(query.get("text", "")), bool(query["options"]["exact"]))
		"node_name":
			return candidate.name == str(query.get("text", ""))
		_:
			return false


func _role_matches(candidate: Node, query: Dictionary) -> bool:
	if _node_role(candidate) != str(query.get("role", "")):
		return false

	var wanted_name := str(query["options"]["name"])
	if wanted_name == "":
		return true

	return _string_matches(_accessible_name(candidate), wanted_name, bool(query["options"]["exact"]))


func _string_matches(actual: String, expected: String, exact: bool) -> bool:
	if exact:
		return actual == expected

	return actual.to_lower().contains(expected.to_lower())


func _visible_text(candidate: Node) -> String:
	if candidate == null:
		return ""

	if candidate is RichTextLabel:
		return candidate.get_parsed_text()

	for property_name in ["text", "title"]:
		var value := _get_string_property(candidate, property_name)
		if value != "":
			return value

	return ""


func _accessible_name(candidate: Node) -> String:
	if candidate == null or not candidate is Control:
		return ""

	var explicit := _get_string_property(candidate, "accessibility_name")
	if explicit != "":
		return explicit

	if _supports_text_accessible_name(candidate):
		return _visible_text(candidate)

	return ""


func _accessible_description(candidate: Node) -> String:
	if candidate == null or not candidate is Control:
		return ""

	return _get_string_property(candidate, "accessibility_description")


func _label_text(candidate: Node) -> String:
	if candidate == null or not candidate is Control:
		return ""

	var direct_label := _get_string_property(candidate, "accessibility_name")
	if direct_label != "":
		return direct_label

	var visible_label := _visible_text(candidate)
	if visible_label != "" and _is_labelable_control(candidate):
		return visible_label

	return _associated_label_text(candidate)


func _placeholder_text(candidate: Node) -> String:
	if candidate == null or not _is_textbox(candidate):
		return ""

	return _get_string_property(candidate, "placeholder_text")


func _associated_label_text(candidate: Node) -> String:
	var parent := candidate.get_parent()
	if parent == null:
		return ""

	var siblings := parent.get_children()
	var index := siblings.find(candidate)
	if index <= 0:
		return ""

	for sibling_index in range(index - 1, -1, -1):
		var sibling = siblings[sibling_index]
		if sibling is Label:
			var text := _visible_text(sibling)
			if text != "":
				return text
		if sibling is Control and _is_labelable_control(sibling):
			break

	return ""


func _supports_text_accessible_name(candidate: Node) -> bool:
	return candidate is BaseButton or candidate is Label or candidate is RichTextLabel or candidate is CheckBox or candidate is CheckButton or candidate is OptionButton


func _is_labelable_control(candidate: Node) -> bool:
	return candidate is LineEdit or candidate is TextEdit or candidate is BaseButton or candidate is CheckBox or candidate is CheckButton or candidate is OptionButton


func _is_textbox(candidate: Node) -> bool:
	return candidate is LineEdit or candidate is TextEdit


func _is_hidden(candidate: Node) -> bool:
	return candidate is CanvasItem and not candidate.is_visible_in_tree()


func _get_string_property(target: Object, property_name: String) -> String:
	if target == null:
		return ""

	for property_info in target.get_property_list():
		if str(property_info.get("name", "")) != property_name:
			continue

		var value = target.get(property_name)
		return str(value).strip_edges() if value is String else ""

	return ""


func _node_role(candidate: Node) -> String:
	if candidate is CheckBox or candidate is CheckButton:
		return "checkbox"
	if candidate is OptionButton:
		return "combobox"
	if candidate is LineEdit or candidate is TextEdit:
		return "textbox"
	if candidate is BaseButton:
		return "button"
	if candidate is Label or candidate is RichTextLabel:
		return "text"
	return ""


func _record_failure(message: String) -> void:
	if failure_sink != null and failure_sink.has_method("record_failure"):
		failure_sink.record_failure(message)
	else:
		printerr(message)
