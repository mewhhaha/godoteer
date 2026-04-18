extends RefCounted
class_name GodoteerDriver

const GodoteerLocator = preload("res://addons/godoteer_gd/locator.gd")

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
	if path_or_node is Node:
		return path_or_node

	if path_or_node is GodoteerLocator:
		return path_or_node.node()

	var path := String(path_or_node)
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
		_record_failure("Node missing for property read: %s" % String(path_or_node))
		return null

	return target.get(property_name)


func node_text(path_or_node: Variant) -> String:
	var target := node(path_or_node)
	if target == null:
		return ""

	for property_name in ["text", "title", "placeholder_text"]:
		var value = target.get(property_name)
		if value is String and value != "":
			return value

	return ""


func click(target: Variant, button: int = MOUSE_BUTTON_LEFT) -> void:
	var target_node := node(target)
	if target_node is BaseButton:
		target_node.grab_focus()
		target_node.pressed.emit()
		await wait_frames(1)
		return

	var position := _resolve_position(target)
	if position == null:
		_record_failure("Could not resolve click target: %s" % String(target))
		return

	mouse_move(position)
	await wait_frames(1)
	mouse_button(position, button, true)
	await wait_frames(1)
	mouse_button(position, button, false)
	await wait_frames(1)


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
	var absolute_dir := ProjectSettings.globalize_path(artifacts_dir)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK:
		_record_failure("Could not create screenshot dir: %s" % absolute_dir)
		return ""

	var image := tree.root.get_viewport().get_texture().get_image()
	var save_error := image.save_png(save_path)
	if save_error != OK:
		_record_failure("Could not save screenshot: %s" % save_path)
		return ""

	return ProjectSettings.globalize_path(save_path)


func can_screenshot() -> bool:
	if DisplayServer.get_name() == "headless":
		return false

	return tree.root.get_viewport().get_texture() != null


func locator(target: Variant) -> GodoteerLocator:
	return GodoteerLocator.new(self, {"kind": "target", "value": target}, "locator(%s)" % String(target))


func get_by_name(name: String, root_target: Variant = null) -> GodoteerLocator:
	return GodoteerLocator.new(
		self,
		{"kind": "name", "name": name, "root": root_target},
		"get_by_name(%s)" % name
	)


func get_by_text(text: String, root_target: Variant = null) -> GodoteerLocator:
	return GodoteerLocator.new(
		self,
		{"kind": "text", "text": text, "root": root_target},
		"get_by_text(%s)" % text
	)


func get_by_role(role: String, name: String = "", root_target: Variant = null) -> GodoteerLocator:
	return GodoteerLocator.new(
		self,
		{"kind": "role", "role": role.to_lower(), "name": name, "root": root_target},
		"get_by_role(%s, %s)" % [role, name]
	)


func resolve_query(query: Dictionary) -> Node:
	var kind := String(query.get("kind", "target"))
	match kind:
		"target":
			return node(query.get("value", null))
		"name":
			return _find_first_match(
				_query_root(query.get("root", null)),
				func(candidate: Node) -> bool:
					return candidate.name == String(query.get("name", "")) or node_text(candidate) == String(query.get("name", ""))
			)
		"text":
			return _find_first_match(
				_query_root(query.get("root", null)),
				func(candidate: Node) -> bool:
					return node_text(candidate) == String(query.get("text", ""))
			)
		"role":
			var wanted_role := String(query.get("role", "")).to_lower()
			var wanted_name := String(query.get("name", ""))
			return _find_first_match(
				_query_root(query.get("root", null)),
				func(candidate: Node) -> bool:
					if _node_role(candidate) != wanted_role:
						return false
					if wanted_name == "":
						return true
					return candidate.name == wanted_name or node_text(candidate) == wanted_name
			)
		_:
			return null


func expect_node(path_or_node: Variant, message: String = "") -> void:
	if node(path_or_node) == null:
		if message == "":
			message = "Expected node to exist: %s" % String(path_or_node)
		_record_failure(message)


func expect_property(path_or_node: Variant, property_name: String, expected: Variant, message: String = "") -> void:
	var actual = property(path_or_node, property_name)
	if actual != expected:
		if message == "":
			message = "Property mismatch for %s.%s expected=%s actual=%s" % [
				String(path_or_node),
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


func _query_root(root_target: Variant) -> Node:
	if root_target == null:
		return app_root if app_root != null else tree.root

	return node(root_target)


func _find_first_match(start: Node, predicate: Callable) -> Node:
	if start == null:
		return null

	if predicate.call(start):
		return start

	for child in start.get_children():
		var match := _find_first_match(child, predicate)
		if match != null:
			return match

	return null


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
