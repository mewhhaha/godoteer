extends Node
class_name GodoteerAgent

@export var host: String = "127.0.0.1"
@export var port: int = 6010

var _server: TCPServer = TCPServer.new()
var _client: StreamPeerTCP = null
var _buffer := ""

func _ready() -> void:
	var env_host := OS.get_environment("GODOTEER_HOST")
	if env_host != "":
		host = env_host

	var env_port := OS.get_environment("GODOTEER_PORT")
	if env_port.is_valid_int():
		port = env_port.to_int()

	var listen_error := _server.listen(port, host)
	if listen_error != OK:
		push_error("GodoteerAgent failed to listen on %s:%d (%s)" % [host, port, error_string(listen_error)])
		return

	print("GodoteerAgent listening on %s:%d" % [host, port])


func _process(_delta: float) -> void:
	if _client == null and _server.is_connection_available():
		_client = _server.take_connection()
		_client.set_no_delay(true)
		print("GodoteerAgent client connected")

	if _client == null:
		return

	if _client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_client = null
		_buffer = ""
		return

	var available := _client.get_available_bytes()
	if available <= 0:
		return

	_buffer += _client.get_utf8_string(available)

	while true:
		var newline_index := _buffer.find("\n")
		if newline_index == -1:
			break

		var line := _buffer.substr(0, newline_index).strip_edges()
		_buffer = _buffer.substr(newline_index + 1)

		if line == "":
			continue

		_handle_message(line)


func _handle_message(line: String) -> void:
	var payload = JSON.parse_string(line)
	if typeof(payload) != TYPE_DICTIONARY:
		_send({
			"id": null,
			"ok": false,
			"error": "Invalid JSON payload"
		})
		return

	var id = payload.get("id", null)
	var method := String(payload.get("method", ""))
	var params: Dictionary = payload.get("params", {})

	if method == "":
		_send({
			"id": id,
			"ok": false,
			"error": "Missing method"
		})
		return

	var result = _dispatch(method, params)
	if typeof(result) == TYPE_DICTIONARY and result.has("__error"):
		_send({
			"id": id,
			"ok": false,
			"error": result["__error"]
		})
		return

	_send({
		"id": id,
		"ok": true,
		"result": result
	})


func _dispatch(method: String, params: Dictionary):
	match method:
		"ping":
			return {"pong": true}
		"screenshot":
			return _save_screenshot(params)
		"mouse_move":
			return _mouse_move(params)
		"mouse_button":
			return _mouse_button(params)
		"key_tap":
			return _key_tap(params)
		"node_exists":
			return _node_exists(params)
		"get_property":
			return _get_property(params)
		"call_method":
			return _call_method(params)
		"tree_snapshot":
			return _tree_snapshot(params)
		"quit":
			get_tree().quit()
			return {"quitting": true}
		_:
			return _error("Unknown method: %s" % method)


func _save_screenshot(params: Dictionary):
	var path := String(params.get("path", "user://godoteer.png"))
	var image := get_viewport().get_texture().get_image()
	var save_error := image.save_png(path)
	if save_error != OK:
		return _error("Failed to save screenshot to %s (%s)" % [path, error_string(save_error)])
	return {"path": path}


func _mouse_move(params: Dictionary):
	var x := float(params.get("x", 0.0))
	var y := float(params.get("y", 0.0))
	var event := InputEventMouseMotion.new()
	var position := Vector2(x, y)
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	return {"x": x, "y": y}


func _mouse_button(params: Dictionary):
	var button_name := String(params.get("button", "left"))
	var button_index := _button_index(button_name)
	if button_index == -1:
		return _error("Unknown mouse button: %s" % button_name)

	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.pressed = bool(params.get("pressed", true))

	if params.has("x") and params.has("y"):
		var position := Vector2(float(params["x"]), float(params["y"]))
		event.position = position
		event.global_position = position

	Input.parse_input_event(event)
	return {"button": button_name, "pressed": event.pressed}


func _key_tap(params: Dictionary):
	var key_name := String(params.get("key", ""))
	if key_name == "":
		return _error("Missing key name")

	var keycode := OS.find_keycode_from_string(key_name)
	var unicode := 0
	if keycode == KEY_NONE and key_name.length() == 1:
		unicode = key_name.unicode_at(0)
		keycode = unicode

	if keycode == KEY_NONE and unicode == 0:
		return _error("Unknown key: %s" % key_name)

	var press := InputEventKey.new()
	press.pressed = true
	press.keycode = keycode
	press.unicode = unicode
	Input.parse_input_event(press)

	var release := InputEventKey.new()
	release.pressed = false
	release.keycode = keycode
	release.unicode = unicode
	Input.parse_input_event(release)

	return {"key": key_name}


func _node_exists(params: Dictionary):
	var node_path := String(params.get("nodePath", ""))
	return {"exists": get_node_or_null(node_path) != null}


func _get_property(params: Dictionary):
	var node_path := String(params.get("nodePath", ""))
	var property_name := String(params.get("property", ""))

	if property_name == "":
		return _error("Missing property name")

	var node = get_node_or_null(node_path)
	if node == null:
		return _error("Node not found: %s" % node_path)

	return {"value": node.get(property_name)}


func _call_method(params: Dictionary):
	var node_path := String(params.get("nodePath", ""))
	var method_name := String(params.get("method", ""))
	var node = get_node_or_null(node_path)

	if node == null:
		return _error("Node not found: %s" % node_path)

	if method_name == "":
		return _error("Missing method name")

	if not node.has_method(method_name):
		return _error("Method not found: %s on %s" % [method_name, node_path])

	var args: Array = params.get("args", [])
	return {"value": node.callv(method_name, args)}


func _tree_snapshot(params: Dictionary):
	var node_path := String(params.get("nodePath", "/root"))
	var node = get_node_or_null(node_path)
	if node == null:
		return _error("Node not found: %s" % node_path)

	var nodes: Array[String] = []
	_collect_tree(node, nodes)
	return {"nodes": nodes}


func _collect_tree(node: Node, nodes: Array[String]) -> void:
	nodes.append(str(node.get_path()))
	for child in node.get_children():
		_collect_tree(child, nodes)


func _button_index(button_name: String) -> int:
	match button_name.to_lower():
		"left":
			return MOUSE_BUTTON_LEFT
		"right":
			return MOUSE_BUTTON_RIGHT
		"middle":
			return MOUSE_BUTTON_MIDDLE
		"wheel_up":
			return MOUSE_BUTTON_WHEEL_UP
		"wheel_down":
			return MOUSE_BUTTON_WHEEL_DOWN
		_:
			return -1


func _send(payload: Dictionary) -> void:
	if _client == null:
		return

	var message := JSON.stringify(payload) + "\n"
	_client.put_data(message.to_utf8_buffer())


func _error(message: String) -> Dictionary:
	return {"__error": message}
