extends RefCounted
class_name GodoteerScreen

const GodoteerLocator = preload("locator.gd")
const GodoteerLocatorList = preload("locator_list.gd")


class SignalProbe:
	extends RefCounted

	var fired := false
	var args: Array = []
	var arg_count := 0
	var count := 0
	var history: Array = []

	func mark(
		_arg1 = null,
		_arg2 = null,
		_arg3 = null,
		_arg4 = null,
		_arg5 = null,
		_arg6 = null,
		_arg7 = null,
		_arg8 = null
	) -> void:
		fired = true
		count += 1
		var values := [_arg1, _arg2, _arg3, _arg4, _arg5, _arg6, _arg7, _arg8]
		args = values.slice(0, min(arg_count, values.size()))
		history.append(args.duplicate())

var tree: SceneTree
var app_root: Node
var failure_sink: Object
var artifacts_dir := "user://artifacts"
var active_suite_path := ""
var active_test_name := ""
var update_snapshots := false
var trace_recorder: Object
var last_mouse_position := Vector2.ZERO
var pressed_actions: Dictionary = {}
var pressed_keys: Dictionary = {}
var pressed_joy_buttons: Dictionary = {}
var joy_axis_values: Dictionary = {}
var active_touches: Dictionary = {}


func _init(
	scene_tree: SceneTree,
	root_node: Node,
	sink: Object,
	artifacts_path: String = "user://artifacts",
	suite_path: String = "",
	test_name: String = "",
	should_update_snapshots: bool = false,
	recorder: Object = null
) -> void:
	tree = scene_tree
	app_root = root_node
	failure_sink = sink
	artifacts_dir = artifacts_path.trim_suffix("/")
	active_suite_path = suite_path
	active_test_name = test_name
	update_snapshots = should_update_snapshots
	trace_recorder = recorder


func wait_frames(count: int = 1) -> void:
	for _i in range(max(count, 1)):
		await tree.process_frame


func wait_seconds(seconds: float) -> void:
	await tree.create_timer(max(seconds, 0.0)).timeout


func wait_physics_frames(count: int = 1) -> void:
	for _i in range(max(count, 1)):
		await tree.physics_frame


func wait_until(predicate: Callable, timeout_sec: float = 2.0, step_frames: int = 1, message: String = "Condition timed out") -> bool:
	_trace_event("wait_started", {
		"message": message,
		"timeout_sec": timeout_sec,
		"step_frames": step_frames,
		"wait_kind": "wait_until",
	})
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() <= deadline:
		if predicate.call():
			_trace_event("wait_finished", {
				"message": message,
				"timeout_sec": timeout_sec,
				"wait_kind": "wait_until",
			})
			return true
		await wait_frames(step_frames)

	_trace_event("wait_timed_out", {
		"message": message,
		"timeout_sec": timeout_sec,
		"wait_kind": "wait_until",
	})
	_record_failure(message)
	return false


func wait_until_frames(predicate: Callable, max_frames := 120, message: String = "Condition timed out") -> bool:
	_trace_event("wait_started", {
		"message": message,
		"max_frames": max_frames,
		"wait_kind": "wait_until_frames",
	})
	if predicate.call():
		_trace_event("wait_finished", {
			"message": message,
			"max_frames": max_frames,
			"wait_kind": "wait_until_frames",
		})
		return true

	for _i in range(max(int(max_frames), 0)):
		await wait_frames(1)
		if predicate.call():
			_trace_event("wait_finished", {
				"message": message,
				"max_frames": max_frames,
				"wait_kind": "wait_until_frames",
			})
			return true

	_trace_event("wait_timed_out", {
		"message": message,
		"max_frames": max_frames,
		"wait_kind": "wait_until_frames",
	})
	_record_failure(message)
	return false


func wait_until_physics(predicate: Callable, max_frames := 120, message: String = "Condition timed out") -> bool:
	_trace_event("wait_started", {
		"message": message,
		"max_frames": max_frames,
		"wait_kind": "wait_until_physics",
	})
	if predicate.call():
		_trace_event("wait_finished", {
			"message": message,
			"max_frames": max_frames,
			"wait_kind": "wait_until_physics",
		})
		return true

	for _i in range(max(int(max_frames), 0)):
		await wait_physics_frames(1)
		if predicate.call():
			_trace_event("wait_finished", {
				"message": message,
				"max_frames": max_frames,
				"wait_kind": "wait_until_physics",
			})
			return true

	_trace_event("wait_timed_out", {
		"message": message,
		"max_frames": max_frames,
		"wait_kind": "wait_until_physics",
	})
	_record_failure(message)
	return false


func wait_for_signal(target: Variant, signal_name: String, timeout_sec: float = 2.0, message: String = "") -> bool:
	_trace_event("wait_started", {
		"message": message,
		"signal_name": signal_name,
		"target": str(target),
		"timeout_sec": timeout_sec,
		"wait_kind": "wait_for_signal",
	})
	var target_node := node(target)
	if target_node == null:
		_record_failure("wait_for_signal() could not resolve target: %s" % str(target))
		return false
	if not target_node.has_signal(signal_name):
		_record_failure("wait_for_signal() target has no signal %s: %s" % [signal_name, str(target)])
		return false

	var probe := _connect_signal_probe(target_node, signal_name)
	if probe == null:
		_record_failure("wait_for_signal() could not watch signal %s: %s" % [signal_name, str(target)])
		return false

	var timeout_message := message
	if timeout_message == "":
		timeout_message = "Timed out waiting for signal %s on %s" % [signal_name, str(target)]

	var received := await wait_until(
		func() -> bool:
			return probe.fired,
		timeout_sec,
		1,
		timeout_message
	)
	_disconnect_signal_probe(target_node, signal_name, probe)
	_trace_event("wait_finished" if received else "wait_timed_out", {
		"message": timeout_message,
		"signal_name": signal_name,
		"target": str(target),
		"timeout_sec": timeout_sec,
		"wait_kind": "wait_for_signal",
	})
	return received


func next_signal(
	target: Variant,
	signal_name: String,
	max_frames := 120,
	physics := false,
	message: String = ""
) -> Dictionary:
	_trace_event("wait_started", {
		"message": message,
		"signal_name": signal_name,
		"target": str(target),
		"max_frames": max_frames,
		"wait_kind": "next_signal",
		"physics": physics,
	})
	var target_node := node(target)
	if target_node == null:
		_record_failure("next_signal() could not resolve target: %s" % str(target))
		return {"fired": false, "args": []}
	if not target_node.has_signal(signal_name):
		_record_failure("next_signal() target has no signal %s: %s" % [signal_name, str(target)])
		return {"fired": false, "args": []}

	var probe := _connect_signal_probe(target_node, signal_name)
	if probe == null:
		_record_failure("next_signal() could not watch signal %s: %s" % [signal_name, str(target)])
		return {"fired": false, "args": []}

	var wait_message := message
	if wait_message == "":
		wait_message = "Timed out waiting for signal %s on %s" % [signal_name, str(target)]

	var received := false
	if physics:
		received = await wait_until_physics(
			func() -> bool:
				return probe.fired,
			max_frames,
			wait_message
		)
	else:
		received = await wait_until_frames(
			func() -> bool:
				return probe.fired,
			max_frames,
			wait_message
		)

	_disconnect_signal_probe(target_node, signal_name, probe)
	_trace_event("wait_finished" if received else "wait_timed_out", {
		"message": wait_message,
		"signal_name": signal_name,
		"target": str(target),
		"max_frames": max_frames,
		"wait_kind": "next_signal",
		"physics": physics,
		"args": probe.args.duplicate(),
	})
	return {
		"fired": received,
		"args": probe.args.duplicate(),
	}


func hold_action_until(
	action_name: String,
	predicate: Callable,
	max_frames := 120,
	strength := 1.0,
	message: String = ""
) -> bool:
	_trace_action_started("hold_action_until", {
		"input_action": action_name,
		"max_frames": int(max_frames),
		"strength": strength,
	})
	if not _ensure_action_exists("hold_action_until", action_name):
		return false

	var wait_message := message
	if wait_message == "":
		wait_message = "Condition timed out while holding action %s" % action_name

	action_press(action_name, strength)
	_trace_event("wait_started", {
		"message": wait_message,
		"input_action": action_name,
		"max_frames": int(max_frames),
		"wait_kind": "hold_action_until",
	})

	if predicate.call():
		action_release(action_name)
		await wait_frames(1)
		_trace_event("wait_finished", {
			"message": wait_message,
			"input_action": action_name,
			"max_frames": int(max_frames),
			"wait_kind": "hold_action_until",
		})
		_trace_action_finished("hold_action_until", {
			"input_action": action_name,
			"max_frames": int(max_frames),
		})
		return true

	for _frame in range(max(int(max_frames), 0)):
		await wait_frames(1)
		if predicate.call():
			action_release(action_name)
			await wait_frames(1)
			_trace_event("wait_finished", {
				"message": wait_message,
				"input_action": action_name,
				"max_frames": int(max_frames),
				"wait_kind": "hold_action_until",
			})
			_trace_action_finished("hold_action_until", {
				"input_action": action_name,
				"max_frames": int(max_frames),
			})
			return true

	action_release(action_name)
	await wait_frames(1)
	_trace_event("wait_timed_out", {
		"message": wait_message,
		"input_action": action_name,
		"max_frames": int(max_frames),
		"wait_kind": "hold_action_until",
	})
	_record_failure(wait_message)
	_trace_action_finished("hold_action_until", {
		"input_action": action_name,
		"max_frames": int(max_frames),
	})
	return false


func hold_key_until(keycode: Key, predicate: Callable, max_frames := 120, message: String = "") -> bool:
	_trace_action_started("hold_key_until", {
		"keycode": keycode,
		"max_frames": int(max_frames),
	})
	var wait_message := message
	if wait_message == "":
		wait_message = "Condition timed out while holding key %s" % keycode

	key_press(keycode)
	_trace_event("wait_started", {
		"message": wait_message,
		"keycode": keycode,
		"max_frames": int(max_frames),
		"wait_kind": "hold_key_until",
	})

	if predicate.call():
		key_release(keycode)
		await wait_frames(1)
		_trace_event("wait_finished", {
			"message": wait_message,
			"keycode": keycode,
			"max_frames": int(max_frames),
			"wait_kind": "hold_key_until",
		})
		_trace_action_finished("hold_key_until", {
			"keycode": keycode,
			"max_frames": int(max_frames),
		})
		return true

	for _frame in range(max(int(max_frames), 0)):
		await wait_frames(1)
		if predicate.call():
			key_release(keycode)
			await wait_frames(1)
			_trace_event("wait_finished", {
				"message": wait_message,
				"keycode": keycode,
				"max_frames": int(max_frames),
				"wait_kind": "hold_key_until",
			})
			_trace_action_finished("hold_key_until", {
				"keycode": keycode,
				"max_frames": int(max_frames),
			})
			return true

	key_release(keycode)
	await wait_frames(1)
	_trace_event("wait_timed_out", {
		"message": wait_message,
		"keycode": keycode,
		"max_frames": int(max_frames),
		"wait_kind": "hold_key_until",
	})
	_record_failure(wait_message)
	_trace_action_finished("hold_key_until", {
		"keycode": keycode,
		"max_frames": int(max_frames),
	})
	return false


func key_chord(keycodes: Array, hold_frames := 1) -> void:
	_trace_action_started("key_chord", {
		"keycodes": keycodes.duplicate(),
		"hold_frames": int(hold_frames),
	})
	for keycode in keycodes:
		key_press(int(keycode))
	await wait_frames(max(int(hold_frames), 1))
	for index in range(keycodes.size() - 1, -1, -1):
		key_release(int(keycodes[index]))
	await wait_frames(1)
	_trace_action_finished("key_chord", {
		"keycodes": keycodes.duplicate(),
		"hold_frames": int(hold_frames),
	})


func expect_signal(
	target: Variant,
	signal_name: String,
	max_frames := 120,
	physics := false,
	message: String = ""
) -> Dictionary:
	return await _wait_for_signal_match(
		"expect_signal",
		target,
		signal_name,
		max_frames,
		physics,
		func(_args: Array) -> bool:
			return true,
		message
	)


func expect_no_signal(
	target: Variant,
	signal_name: String,
	max_frames := 120,
	physics := false,
	message: String = ""
) -> bool:
	_trace_event("wait_started", {
		"message": message,
		"signal_name": signal_name,
		"target": str(target),
		"max_frames": int(max_frames),
		"wait_kind": "expect_no_signal",
		"physics": physics,
	})
	var target_node := node(target)
	if target_node == null:
		_record_failure("expect_no_signal() could not resolve target: %s" % str(target))
		return false
	if not target_node.has_signal(signal_name):
		_record_failure("expect_no_signal() target has no signal %s: %s" % [signal_name, str(target)])
		return false

	var probe := _connect_signal_probe(target_node, signal_name)
	if probe == null:
		_record_failure("expect_no_signal() could not watch signal %s: %s" % [signal_name, str(target)])
		return false

	var wait_message := message
	if wait_message == "":
		wait_message = "Expected no signal %s on %s for %d frames" % [signal_name, str(target), int(max_frames)]

	for _frame in range(max(int(max_frames), 0)):
		await _wait_signal_frame(physics)
		if probe.fired:
			_disconnect_signal_probe(target_node, signal_name, probe)
			_trace_event("wait_finished", {
				"message": wait_message,
				"signal_name": signal_name,
				"target": str(target),
				"max_frames": int(max_frames),
				"wait_kind": "expect_no_signal",
				"physics": physics,
				"count": probe.count,
				"history": _duplicate_signal_history(probe.history),
			})
			_record_failure("%s actual_count=%d args=%s" % [wait_message, probe.count, var_to_str(_duplicate_signal_history(probe.history))])
			return false

	_disconnect_signal_probe(target_node, signal_name, probe)
	_trace_event("wait_finished", {
		"message": wait_message,
		"signal_name": signal_name,
		"target": str(target),
		"max_frames": int(max_frames),
		"wait_kind": "expect_no_signal",
		"physics": physics,
		"count": 0,
	})
	return true


func expect_signal_count(
	target: Variant,
	signal_name: String,
	expected_count: int,
	max_frames := 120,
	physics := false,
	message: String = ""
) -> Array:
	_trace_event("wait_started", {
		"message": message,
		"signal_name": signal_name,
		"target": str(target),
		"expected_count": int(expected_count),
		"max_frames": int(max_frames),
		"wait_kind": "expect_signal_count",
		"physics": physics,
	})
	var target_node := node(target)
	if target_node == null:
		_record_failure("expect_signal_count() could not resolve target: %s" % str(target))
		return []
	if not target_node.has_signal(signal_name):
		_record_failure("expect_signal_count() target has no signal %s: %s" % [signal_name, str(target)])
		return []

	var probe := _connect_signal_probe(target_node, signal_name)
	if probe == null:
		_record_failure("expect_signal_count() could not watch signal %s: %s" % [signal_name, str(target)])
		return []

	for _frame in range(max(int(max_frames), 0)):
		await _wait_signal_frame(physics)

	_disconnect_signal_probe(target_node, signal_name, probe)
	var history := _duplicate_signal_history(probe.history)
	var wait_message := message
	if wait_message == "":
		wait_message = "Expected signal %s on %s to fire %d time(s) in %d frames" % [
			signal_name,
			str(target),
			int(expected_count),
			int(max_frames),
		]

	_trace_event("wait_finished", {
		"message": wait_message,
		"signal_name": signal_name,
		"target": str(target),
		"expected_count": int(expected_count),
		"actual_count": probe.count,
		"max_frames": int(max_frames),
		"wait_kind": "expect_signal_count",
		"physics": physics,
		"history": history,
	})
	if probe.count != int(expected_count):
		_record_failure("%s actual=%d history=%s" % [wait_message, probe.count, var_to_str(history)])
	return history


func wait_for_animation_finished(
	player_target: Variant,
	animation_name: String = "",
	max_frames := 120,
	message: String = ""
) -> Dictionary:
	var player_node := node(player_target)
	if not player_node is AnimationPlayer:
		_record_failure("wait_for_animation_finished() supports AnimationPlayer only: %s" % str(player_target))
		return {"fired": false, "args": [], "count": 0, "history": []}
	var wait_message := message
	if wait_message == "":
		wait_message = "Timed out waiting for animation_finished on %s" % str(player_target)
	if animation_name != "":
		wait_message = "Timed out waiting for animation %s to finish on %s" % [animation_name, str(player_target)]
	return await _wait_for_signal_match(
		"wait_for_animation_finished",
		player_target,
		"animation_finished",
		max_frames,
		false,
		func(args: Array) -> bool:
			return animation_name == "" or (args.size() > 0 and str(args[0]) == animation_name),
		wait_message
	)


func wait_for_audio_finished(player_target: Variant, max_frames := 120, message: String = "") -> bool:
	var player_node := node(player_target)
	if not (player_node is AudioStreamPlayer or player_node is AudioStreamPlayer2D or player_node is AudioStreamPlayer3D):
		_record_failure("wait_for_audio_finished() supports AudioStreamPlayer, AudioStreamPlayer2D, and AudioStreamPlayer3D only: %s" % str(player_target))
		return false
	var wait_message := message
	if wait_message == "":
		wait_message = "Timed out waiting for audio finished on %s" % str(player_target)
	_trace_event("wait_started", {
		"message": wait_message,
		"target": str(player_target),
		"max_frames": int(max_frames),
		"wait_kind": "wait_for_audio_finished",
	})
	var probe := _connect_signal_probe(player_node, "finished")
	if probe == null:
		_record_failure("wait_for_audio_finished() could not watch signal finished: %s" % str(player_target))
		return false

	var saw_playing := bool(player_node.playing)
	for _frame in range(max(int(max_frames), 0)):
		if player_node.playing:
			saw_playing = true
		if probe.fired or (saw_playing and not player_node.playing):
			_disconnect_signal_probe(player_node, "finished", probe)
			_trace_event("wait_finished", {
				"message": wait_message,
				"target": str(player_target),
				"max_frames": int(max_frames),
				"wait_kind": "wait_for_audio_finished",
				"count": probe.count,
				"used_playback_fallback": not probe.fired,
			})
			return true
		await wait_frames(1)

	_disconnect_signal_probe(player_node, "finished", probe)
	_trace_event("wait_timed_out", {
		"message": wait_message,
		"target": str(player_target),
		"max_frames": int(max_frames),
		"wait_kind": "wait_for_audio_finished",
		"count": probe.count,
	})
	_record_failure(wait_message)
	return false


func wait_for_body_entered(area_target: Variant, max_frames := 120, message: String = "") -> Dictionary:
	var area_node := node(area_target)
	if not area_node is Area2D:
		_record_failure("wait_for_body_entered() supports Area2D only: %s" % str(area_target))
		return {"fired": false, "args": [], "count": 0, "history": []}
	var wait_message := message
	if wait_message == "":
		wait_message = "Timed out waiting for body_entered on %s" % str(area_target)
	return await _wait_for_signal_match(
		"wait_for_body_entered",
		area_target,
		"body_entered",
		max_frames,
		true,
		func(_args: Array) -> bool:
			return true,
		wait_message
	)


func wait_for_area_entered(area_target: Variant, max_frames := 120, message: String = "") -> Dictionary:
	var area_node := node(area_target)
	if not area_node is Area2D:
		_record_failure("wait_for_area_entered() supports Area2D only: %s" % str(area_target))
		return {"fired": false, "args": [], "count": 0, "history": []}
	var wait_message := message
	if wait_message == "":
		wait_message = "Timed out waiting for area_entered on %s" % str(area_target)
	return await _wait_for_signal_match(
		"wait_for_area_entered",
		area_target,
		"area_entered",
		max_frames,
		true,
		func(_args: Array) -> bool:
			return true,
		wait_message
	)


func pause_scene() -> void:
	tree.paused = true


func resume_scene() -> void:
	tree.paused = false


func set_time_scale(scale: float) -> void:
	_trace_action_started("set_time_scale", {"scale": scale})
	if scale <= 0.0:
		_record_failure("set_time_scale() requires scale > 0.0: %s" % scale)
		return
	Engine.time_scale = scale
	_trace_action_finished("set_time_scale", {"scale": scale})


func action_press(action_name: String, strength: float = 1.0) -> void:
	_trace_action_started("action_press", {"input_action": action_name, "strength": strength})
	if not _ensure_action_exists("action_press", action_name):
		return

	Input.action_press(action_name, strength)
	pressed_actions[action_name] = true
	_trace_action_finished("action_press", {"input_action": action_name, "strength": strength})


func action_release(action_name: String) -> void:
	_trace_action_started("action_release", {"input_action": action_name})
	if not _ensure_action_exists("action_release", action_name):
		return

	Input.action_release(action_name)
	pressed_actions.erase(action_name)
	_trace_action_finished("action_release", {"input_action": action_name})


func action_tap(action_name: String, hold_frames: int = 1, strength: float = 1.0) -> void:
	_trace_action_started("action_tap", {
		"input_action": action_name,
		"hold_frames": hold_frames,
		"strength": strength,
	})
	if not _ensure_action_exists("action_tap", action_name):
		return

	action_press(action_name, strength)
	await wait_physics_frames(max(hold_frames, 1))
	action_release(action_name)
	_trace_action_finished("action_tap", {
		"input_action": action_name,
		"hold_frames": hold_frames,
		"strength": strength,
	})


func key_press(keycode: Key) -> void:
	_trace_action_started("key_press", {"keycode": keycode})
	var press := InputEventKey.new()
	press.keycode = keycode
	press.physical_keycode = keycode
	press.pressed = true
	Input.parse_input_event(press)
	pressed_keys[keycode] = true
	_trace_action_finished("key_press", {"keycode": keycode})


func key_release(keycode: Key) -> void:
	_trace_action_started("key_release", {"keycode": keycode})
	var release := InputEventKey.new()
	release.keycode = keycode
	release.physical_keycode = keycode
	release.pressed = false
	Input.parse_input_event(release)
	pressed_keys.erase(keycode)
	_trace_action_finished("key_release", {"keycode": keycode})


func joy_button_press(button, device := 0) -> void:
	_trace_action_started("joy_button_press", {"button": int(button), "device": int(device)})
	var event := InputEventJoypadButton.new()
	event.device = int(device)
	event.button_index = int(button)
	event.pressed = true
	event.pressure = 1.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	pressed_joy_buttons[_joy_input_key(int(device), int(button))] = true
	_trace_action_finished("joy_button_press", {"button": int(button), "device": int(device)})


func joy_button_release(button, device := 0) -> void:
	_trace_action_started("joy_button_release", {"button": int(button), "device": int(device)})
	var event := InputEventJoypadButton.new()
	event.device = int(device)
	event.button_index = int(button)
	event.pressed = false
	event.pressure = 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	pressed_joy_buttons.erase(_joy_input_key(int(device), int(button)))
	_trace_action_finished("joy_button_release", {"button": int(button), "device": int(device)})


func joy_button_tap(button, hold_frames := 1, device := 0) -> void:
	_trace_action_started("joy_button_tap", {"button": int(button), "device": int(device), "hold_frames": int(hold_frames)})
	joy_button_press(button, device)
	await wait_physics_frames(max(int(hold_frames), 1))
	joy_button_release(button, device)
	await wait_frames(1)
	_trace_action_finished("joy_button_tap", {"button": int(button), "device": int(device), "hold_frames": int(hold_frames)})


func joy_axis_set(axis, value: float, device := 0) -> void:
	_trace_action_started("joy_axis_set", {"axis": int(axis), "value": value, "device": int(device)})
	var clamped_value := clampf(value, -1.0, 1.0)
	var event := InputEventJoypadMotion.new()
	event.device = int(device)
	event.axis = int(axis)
	event.axis_value = clamped_value
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	joy_axis_values[_joy_input_key(int(device), int(axis))] = clamped_value
	_trace_action_finished("joy_axis_set", {"axis": int(axis), "value": clamped_value, "device": int(device)})


func joy_axis_reset(axis, device := 0) -> void:
	_trace_action_started("joy_axis_reset", {"axis": int(axis), "device": int(device)})
	joy_axis_set(axis, 0.0, device)
	joy_axis_values.erase(_joy_input_key(int(device), int(axis)))
	_trace_action_finished("joy_axis_reset", {"axis": int(axis), "device": int(device)})


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
	if target is Control and _has_property(target, "disabled"):
		return not bool(target.get("disabled"))
	return true


func click(target: Variant, button: int = MOUSE_BUTTON_LEFT) -> void:
	_trace_action_started("click", {"target": str(target), "button": button})
	var target_node := node(target)
	if not _ensure_control_enabled("click", target_node, target):
		return

	var pressed_probe := _connect_signal_probe(target_node, "pressed") if button == MOUSE_BUTTON_LEFT else null
	var toggled_probe := _connect_signal_probe(target_node, "toggled") if button == MOUSE_BUTTON_LEFT else null
	var position := _resolve_position(target)
	if position == null:
		_disconnect_signal_probe(target_node, "pressed", pressed_probe)
		_disconnect_signal_probe(target_node, "toggled", toggled_probe)
		_record_failure("Could not resolve click target: %s" % str(target))
		return

	mouse_move(position)
	await wait_frames(1)
	mouse_button(position, button, true)
	await wait_frames(1)
	mouse_button(position, button, false)
	await wait_frames(1)

	var pressed_fired := _disconnect_signal_probe(target_node, "pressed", pressed_probe)
	var toggled_fired := _disconnect_signal_probe(target_node, "toggled", toggled_probe)
	if button == MOUSE_BUTTON_LEFT and (target_node is CheckBox or target_node is CheckButton):
		if not pressed_fired and not toggled_fired:
			target_node.grab_click_focus()
			target_node.set_pressed(not target_node.button_pressed)
			await wait_frames(1)
		_trace_action_finished("click", {"target": str(target), "button": button})
		return

	if button == MOUSE_BUTTON_LEFT and target_node is BaseButton and not pressed_fired:
		target_node.grab_click_focus()
		target_node.pressed.emit()
		await wait_frames(1)
	_trace_action_finished("click", {"target": str(target), "button": button})


func dblclick(target: Variant, button: int = MOUSE_BUTTON_LEFT) -> void:
	_trace_action_started("dblclick", {"target": str(target), "button": button})
	var target_node := node(target)
	if not _ensure_control_enabled("dblclick", target_node, target):
		return

	var position := _resolve_position(target)
	if position == null:
		_record_failure("Could not resolve dblclick target: %s" % str(target))
		return

	mouse_move(position)
	await wait_frames(1)
	await _mouse_click_cycle(position, button, false, target_node)
	await wait_frames(1)
	await _mouse_click_cycle(position, button, true, target_node)
	await wait_frames(1)
	_trace_action_finished("dblclick", {"target": str(target), "button": button})


func right_click(target: Variant) -> void:
	_trace_action_started("right_click", {"target": str(target)})
	var target_node := node(target)
	if not _ensure_control_enabled("right_click", target_node, target):
		return
	var position := _resolve_position(target)
	if position == null:
		_record_failure("Could not resolve right_click target: %s" % str(target))
		return

	mouse_move(position)
	await wait_frames(1)
	await _mouse_click_cycle(position, MOUSE_BUTTON_RIGHT, false, target_node)
	await wait_frames(1)
	_trace_action_finished("right_click", {"target": str(target)})


func long_press(target: Variant, hold_frames := 12, button := MOUSE_BUTTON_LEFT) -> void:
	_trace_action_started("long_press", {
		"target": str(target),
		"hold_frames": int(hold_frames),
		"button": int(button),
	})
	var target_node := node(target)
	if not _ensure_control_enabled("long_press", target_node, target):
		return

	var position := _resolve_position(target)
	if position == null:
		_record_failure("Could not resolve long_press target: %s" % str(target))
		return

	mouse_move(position)
	await wait_frames(1)
	_dispatch_pointer_button(target_node, position, button, true)
	await wait_frames(max(int(hold_frames), 1))
	_dispatch_pointer_button(target_node, position, button, false)
	await wait_frames(1)
	_trace_action_finished("long_press", {
		"target": str(target),
		"hold_frames": int(hold_frames),
		"button": int(button),
	})


func hover(target: Variant) -> void:
	_trace_action_started("hover", {"target": str(target)})
	var target_node := node(target)
	var hover_probe := _connect_signal_probe(target_node, "mouse_entered")
	var position := _resolve_position(target)
	if position == null:
		_disconnect_signal_probe(target_node, "mouse_entered", hover_probe)
		_record_failure("Could not resolve hover target: %s" % str(target))
		return

	mouse_move(position)
	await wait_frames(1)
	if target_node is Control and not _disconnect_signal_probe(target_node, "mouse_entered", hover_probe):
		target_node.mouse_entered.emit()
		await wait_frames(1)
	_trace_action_finished("hover", {"target": str(target)})


func focus(target: Variant) -> void:
	_trace_action_started("focus", {"target": str(target)})
	var target_node := node(target)
	if target_node is Control:
		if not _ensure_control_enabled("focus", target_node, target):
			return
		target_node.grab_focus()
		await wait_frames(1)
		_trace_action_finished("focus", {"target": str(target)})
		return

	_record_failure("focus() supports Control only: %s" % str(target))


func blur(target: Variant) -> void:
	_trace_action_started("blur", {"target": str(target)})
	var target_node := node(target)
	if target_node is Control:
		target_node.release_focus()
		await wait_frames(1)
		_trace_action_finished("blur", {"target": str(target)})
		return

	_record_failure("blur() supports Control only: %s" % str(target))


func fill(target: Variant, text: String) -> void:
	_trace_action_started("fill", {"target": str(target), "text": text})
	var target_node := node(target)
	if target_node is LineEdit:
		if not _ensure_control_enabled("fill", target_node, target):
			return
		if not _ensure_text_input_editable("fill", target_node, target):
			return
		target_node.grab_focus()
		target_node.text = text
		target_node.text_changed.emit(text)
		await wait_frames(1)
		_trace_action_finished("fill", {"target": str(target), "text": text})
		return

	if target_node is TextEdit:
		if not _ensure_control_enabled("fill", target_node, target):
			return
		if not _ensure_text_input_editable("fill", target_node, target):
			return
		target_node.grab_focus()
		target_node.text = text
		target_node.text_changed.emit()
		await wait_frames(1)
		_trace_action_finished("fill", {"target": str(target), "text": text})
		return

	_record_failure("fill() supports LineEdit and TextEdit only: %s" % str(target))


func clear(target: Variant) -> void:
	_trace_action_started("clear", {"target": str(target)})
	await fill(target, "")
	_trace_action_finished("clear", {"target": str(target)})


func press(target: Variant, keycode: Key) -> void:
	_trace_action_started("press", {"target": str(target), "keycode": keycode})
	var target_node := node(target)
	var submitted_probe := _connect_signal_probe(target_node, "text_submitted")
	if target_node is Control:
		if not _ensure_control_enabled("press", target_node, target):
			_disconnect_signal_probe(target_node, "text_submitted", submitted_probe)
			return
		if not _ensure_text_input_editable("press", target_node, target):
			_disconnect_signal_probe(target_node, "text_submitted", submitted_probe)
			return
		target_node.grab_focus()
	await key_tap(keycode)
	var submitted := _disconnect_signal_probe(target_node, "text_submitted", submitted_probe)
	if target_node is LineEdit and not submitted and (keycode == KEY_ENTER or keycode == KEY_KP_ENTER):
		target_node.text_submitted.emit(target_node.text)
		await wait_frames(1)
	_trace_action_finished("press", {"target": str(target), "keycode": keycode})


func drag_to(source: Variant, target_or_position: Variant, duration_sec: float = 0.2, steps: int = 12) -> void:
	_trace_action_started("drag_to", {
		"source": str(source),
		"target": str(target_or_position),
		"duration_sec": duration_sec,
		"steps": steps,
	})
	var source_node := node(source)
	var target_node := node(target_or_position)
	var from_position := _resolve_position(source)
	var to_position := _resolve_position(target_or_position)
	if from_position == null or to_position == null:
		_record_failure("drag_to() could not resolve source or target: %s -> %s" % [str(source), str(target_or_position)])
		return
	if not _ensure_control_enabled("drag_to", source_node, source, "source"):
		return
	if not _ensure_control_enabled("drag_to", target_node, target_or_position, "target"):
		return

	var source_probe := _connect_signal_probe(source_node, "gui_input")
	var target_hover_probe := _connect_signal_probe(target_node, "mouse_entered")
	var target_probe := _connect_signal_probe(target_node, "gui_input")
	mouse_move(from_position)
	await wait_frames(1)
	var press_event := InputEventMouseButton.new()
	press_event.position = from_position
	press_event.global_position = from_position
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	Input.parse_input_event(press_event)
	last_mouse_position = from_position
	await wait_frames(1)
	if source_node is Control and not _disconnect_signal_probe(source_node, "gui_input", source_probe):
		source_node.gui_input.emit(press_event)
		await wait_frames(1)
	await move_mouse_between(from_position, to_position, duration_sec, steps)
	if target_node is Control and not _disconnect_signal_probe(target_node, "mouse_entered", target_hover_probe):
		target_node.mouse_entered.emit()
		await wait_frames(1)
	var release_event := InputEventMouseButton.new()
	release_event.position = to_position
	release_event.global_position = to_position
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	Input.parse_input_event(release_event)
	last_mouse_position = to_position
	await wait_frames(1)
	if target_node is Control and not _disconnect_signal_probe(target_node, "gui_input", target_probe):
		target_node.gui_input.emit(release_event)
		await wait_frames(1)
	_trace_action_finished("drag_to", {
		"source": str(source),
		"target": str(target_or_position),
	})


func check(target: Variant) -> void:
	_trace_action_started("check", {"target": str(target)})
	var target_node := node(target)
	if target_node is CheckBox or target_node is CheckButton:
		if not _ensure_control_enabled("check", target_node, target):
			return
		if not target_node.button_pressed:
			await click(target)
		_trace_action_finished("check", {"target": str(target)})
		return

	_record_failure("check() supports CheckBox and CheckButton only: %s" % str(target))


func uncheck(target: Variant) -> void:
	_trace_action_started("uncheck", {"target": str(target)})
	var target_node := node(target)
	if target_node is CheckBox or target_node is CheckButton:
		if not _ensure_control_enabled("uncheck", target_node, target):
			return
		if target_node.button_pressed:
			await click(target)
		_trace_action_finished("uncheck", {"target": str(target)})
		return

	_record_failure("uncheck() supports CheckBox and CheckButton only: %s" % str(target))


func set_checked(target: Variant, checked: bool) -> void:
	_trace_action_started("set_checked", {"target": str(target), "checked": checked})
	if checked:
		await check(target)
	else:
		await uncheck(target)
	_trace_action_finished("set_checked", {"target": str(target), "checked": checked})


func select_option(target: Variant, option_text: String) -> void:
	_trace_action_started("select_option", {"target": str(target), "option_text": option_text})
	var target_node := node(target)
	if target_node is OptionButton:
		if not _ensure_control_enabled("select_option", target_node, target):
			return
		var option_button: OptionButton = target_node
		var option_index := _option_button_item_index(option_button, option_text)
		if option_index < 0:
			_record_failure("Option not found for select_option(): %s on %s" % [option_text, str(target)])
			return

		var popup := _option_button_popup(option_button)
		if popup == null:
			_record_failure("select_option() could not resolve popup for %s" % str(target))
			return

		await click(target)
		if not await _wait_for_popup_visible(popup):
			option_button.show_popup()
			if not await _wait_for_popup_visible(popup):
				_record_failure("select_option() could not open popup for %s" % str(target))
				return

		var previous_index := option_button.selected
		popup.set_focused_item(option_index)
		var activate_event := InputEventMouseButton.new()
		activate_event.button_index = MOUSE_BUTTON_LEFT
		activate_event.pressed = false
		var activated := popup.activate_item_by_event(activate_event)
		await wait_frames(1)
		if option_button.selected == option_index:
			_trace_action_finished("select_option", {"target": str(target), "option_text": option_text})
			return

		if not activated:
			popup.index_pressed.emit(option_index)
			await wait_frames(1)
		if option_button.selected == option_index:
			_trace_action_finished("select_option", {"target": str(target), "option_text": option_text})
			return

		_record_failure("select_option() could not activate option %s on %s previous=%s actual=%s" % [
			option_text,
			str(target),
			previous_index,
			option_button.selected,
		])
		return

	_record_failure("select_option() supports OptionButton only: %s" % str(target))


func mouse_move_relative(delta: Vector2) -> void:
	_trace_action_started("mouse_move_relative", {"delta": delta})
	var next_position := last_mouse_position + delta
	var event := InputEventMouseMotion.new()
	event.position = next_position
	event.global_position = next_position
	event.relative = delta
	event.screen_relative = delta
	Input.parse_input_event(event)
	last_mouse_position = next_position
	_trace_action_finished("mouse_move_relative", {"delta": delta})


func mouse_move(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)
	last_mouse_position = position


func mouse_button(position: Vector2, button: int = MOUSE_BUTTON_LEFT, pressed: bool = true, double_click := false) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.pressed = pressed
	event.double_click = bool(double_click)
	Input.parse_input_event(event)
	last_mouse_position = position


func mouse_wheel(vertical_steps: int, horizontal_steps := 0, target: Variant = null) -> void:
	_trace_action_started("mouse_wheel", {
		"vertical_steps": vertical_steps,
		"horizontal_steps": horizontal_steps,
		"target": str(target),
	})
	var position := _resolve_optional_position(target)
	for _step in range(abs(vertical_steps)):
		var button := MOUSE_BUTTON_WHEEL_UP if vertical_steps > 0 else MOUSE_BUTTON_WHEEL_DOWN
		mouse_button(position, button, true)
		await wait_frames(1)
	for _step in range(abs(horizontal_steps)):
		var button := MOUSE_BUTTON_WHEEL_RIGHT if horizontal_steps > 0 else MOUSE_BUTTON_WHEEL_LEFT
		mouse_button(position, button, true)
		await wait_frames(1)
	_trace_action_finished("mouse_wheel", {
		"vertical_steps": vertical_steps,
		"horizontal_steps": horizontal_steps,
		"target": str(target),
	})


func move_mouse_between(
	from_position: Vector2,
	to_position: Vector2,
	duration_sec: float = 0.2,
	steps: int = 12
) -> void:
	_trace_action_started("move_mouse_between", {
		"from": from_position,
		"to": to_position,
		"duration_sec": duration_sec,
		"steps": steps,
	})
	mouse_move(from_position)

	var distance := from_position.distance_to(to_position)
	if distance <= 0.0:
		await wait_frames(1)
		_trace_action_finished("move_mouse_between", {
			"from": from_position,
			"to": to_position,
		})
		return

	var safe_steps: int = max(1, steps)
	var safe_duration_sec: float = max(duration_sec, 0.0)
	var delay_sec: float = safe_duration_sec / float(safe_steps)

	for index in range(1, safe_steps + 1):
		var weight := float(index) / float(safe_steps)
		mouse_move(from_position.lerp(to_position, weight))
		if delay_sec > 0.0:
			await tree.create_timer(delay_sec).timeout
	_trace_action_finished("move_mouse_between", {
		"from": from_position,
		"to": to_position,
	})


func move_mouse_to(
	to_position: Vector2,
	duration_sec: float = 0.2,
	steps: int = 12
) -> void:
	await move_mouse_between(last_mouse_position, to_position, duration_sec, steps)


func key_tap(keycode: Key, hold_frames := 1) -> void:
	_trace_action_started("key_tap", {"keycode": keycode, "hold_frames": int(hold_frames)})
	key_press(keycode)
	await wait_frames(max(int(hold_frames), 1))
	key_release(keycode)
	await wait_frames(1)
	_trace_action_finished("key_tap", {"keycode": keycode, "hold_frames": int(hold_frames)})


func touch_press(position: Vector2, index := 0) -> void:
	_trace_action_started("touch_press", {"position": position, "index": int(index)})
	var event := InputEventScreenTouch.new()
	event.index = int(index)
	event.position = position
	event.pressed = true
	Input.parse_input_event(event)
	active_touches[int(index)] = position
	_trace_action_finished("touch_press", {"position": position, "index": int(index)})


func touch_move(position: Vector2, index := 0) -> void:
	_trace_action_started("touch_move", {"position": position, "index": int(index)})
	var touch_index := int(index)
	var previous_position: Vector2 = active_touches.get(touch_index, position)
	var event := InputEventScreenDrag.new()
	event.index = touch_index
	event.position = position
	event.relative = position - previous_position
	event.screen_relative = event.relative
	Input.parse_input_event(event)
	active_touches[touch_index] = position
	_trace_action_finished("touch_move", {"position": position, "index": int(index)})


func touch_release(position: Vector2, index := 0) -> void:
	_trace_action_started("touch_release", {"position": position, "index": int(index)})
	var event := InputEventScreenTouch.new()
	event.index = int(index)
	event.position = position
	event.pressed = false
	Input.parse_input_event(event)
	active_touches.erase(int(index))
	_trace_action_finished("touch_release", {"position": position, "index": int(index)})


func touch_tap(position: Vector2, index := 0, hold_frames := 1) -> void:
	_trace_action_started("touch_tap", {"position": position, "index": int(index), "hold_frames": int(hold_frames)})
	touch_press(position, index)
	await wait_frames(max(int(hold_frames), 1))
	touch_release(position, index)
	await wait_frames(1)
	_trace_action_finished("touch_tap", {"position": position, "index": int(index), "hold_frames": int(hold_frames)})


func touch_drag(from: Vector2, to: Vector2, index := 0, duration_sec := 0.2, steps := 12) -> void:
	_trace_action_started("touch_drag", {
		"from": from,
		"to": to,
		"index": int(index),
		"duration_sec": float(duration_sec),
		"steps": int(steps),
	})
	touch_press(from, index)
	var safe_steps: int = max(int(steps), 1)
	var safe_duration: float = max(float(duration_sec), 0.0)
	var delay_sec: float = safe_duration / float(safe_steps)
	for step in range(1, safe_steps + 1):
		var weight := float(step) / float(safe_steps)
		touch_move(from.lerp(to, weight), index)
		if delay_sec > 0.0:
			await tree.create_timer(delay_sec).timeout
		else:
			await wait_frames(1)
	touch_release(to, index)
	await wait_frames(1)
	_trace_action_finished("touch_drag", {
		"from": from,
		"to": to,
		"index": int(index),
	})


func touch_pinch(
	start_a: Vector2,
	start_b: Vector2,
	end_a: Vector2,
	end_b: Vector2,
	duration_sec := 0.2,
	steps := 12,
	index_a := 0,
	index_b := 1
) -> void:
	_trace_action_started("touch_pinch", {
		"start_a": start_a,
		"start_b": start_b,
		"end_a": end_a,
		"end_b": end_b,
		"duration_sec": float(duration_sec),
		"steps": int(steps),
	})
	touch_press(start_a, index_a)
	touch_press(start_b, index_b)
	var safe_steps: int = max(int(steps), 1)
	var safe_duration: float = max(float(duration_sec), 0.0)
	var delay_sec: float = safe_duration / float(safe_steps)
	for step in range(1, safe_steps + 1):
		var weight := float(step) / float(safe_steps)
		touch_move(start_a.lerp(end_a, weight), index_a)
		touch_move(start_b.lerp(end_b, weight), index_b)
		if delay_sec > 0.0:
			await tree.create_timer(delay_sec).timeout
		else:
			await wait_frames(1)
	touch_release(end_a, index_a)
	touch_release(end_b, index_b)
	await wait_frames(1)
	_trace_action_finished("touch_pinch", {
		"start_a": start_a,
		"start_b": start_b,
		"end_a": end_a,
		"end_b": end_b,
	})


func release_all_actions() -> void:
	release_all_inputs()


func release_all_inputs() -> void:
	for action_name in pressed_actions.keys():
		Input.action_release(str(action_name))
	pressed_actions.clear()
	for keycode in pressed_keys.keys():
		key_release(int(keycode))
	pressed_keys.clear()
	for joy_key in pressed_joy_buttons.keys():
		var parts := str(joy_key).split(":")
		joy_button_release(int(parts[1]), int(parts[0]))
	pressed_joy_buttons.clear()
	for axis_key in joy_axis_values.keys():
		var parts := str(axis_key).split(":")
		joy_axis_reset(int(parts[1]), int(parts[0]))
	joy_axis_values.clear()
	for touch_index in active_touches.keys():
		touch_release(active_touches[touch_index], int(touch_index))
	active_touches.clear()


func screenshot(file_name: String = "screenshot.png") -> String:
	_trace_event("artifact_started", {
		"message": "screenshot(%s)" % file_name,
		"artifact_kind": "screenshot",
	})
	var image := _capture_screen_image()
	if image == null:
		return ""

	return _save_png_image(image, file_name)


func capture_locator(target: Variant, file_name: String = "locator.png") -> String:
	_trace_event("artifact_started", {
		"message": "capture_locator(%s, %s)" % [str(target), file_name],
		"artifact_kind": "locator_capture",
		"target": str(target),
	})
	var image := _capture_locator_image(target)
	if image == null:
		return ""

	return _save_png_image(image, file_name)


func capture_camera(camera_target: Variant, file_name: String = "camera.png") -> String:
	_trace_event("artifact_started", {
		"message": "capture_camera(%s, %s)" % [str(camera_target), file_name],
		"artifact_kind": "camera_capture",
		"target": str(camera_target),
	})
	var image := await _capture_camera_image(camera_target)
	if image == null:
		return ""

	return _save_png_image(image, file_name)


func can_screenshot() -> bool:
	if DisplayServer.get_name() == "headless":
		return false

	return tree.root.get_viewport().get_texture() != null


func expect_snapshot(file_name: String, options: Dictionary = {}) -> bool:
	_trace_event("artifact_started", {
		"message": "expect_snapshot(%s)" % file_name,
		"artifact_kind": "snapshot_assertion",
	})
	var image := _capture_screen_image()
	if image == null:
		return false
	return _assert_snapshot_image(image, file_name, options, "screen")


func expect_locator_snapshot(target: Variant, file_name: String, options: Dictionary = {}) -> bool:
	_trace_event("artifact_started", {
		"message": "expect_locator_snapshot(%s, %s)" % [str(target), file_name],
		"artifact_kind": "snapshot_assertion",
		"target": str(target),
	})
	var image := _capture_locator_image(target)
	if image == null:
		return false
	return _assert_snapshot_image(image, file_name, options, "locator(%s)" % str(target))


func expect_camera_snapshot(camera_target: Variant, file_name: String, options: Dictionary = {}) -> bool:
	_trace_event("artifact_started", {
		"message": "expect_camera_snapshot(%s, %s)" % [str(camera_target), file_name],
		"artifact_kind": "snapshot_assertion",
		"target": str(camera_target),
	})
	var image := await _capture_camera_image(camera_target)
	if image == null:
		return false
	return _assert_snapshot_image(image, file_name, options, "camera(%s)" % str(camera_target))


func screen_reader_supported() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_ACCESSIBILITY_SCREEN_READER)


func screen_reader_active() -> int:
	return int(DisplayServer.accessibility_screen_reader_active())


func accessible_name(target: Variant) -> String:
	return _accessible_name(node(target))


func accessible_description(target: Variant) -> String:
	return _accessible_description(node(target))


func accessibility_rid(target: Variant) -> RID:
	var target_node := node(target)
	if target_node == null:
		return RID()
	return target_node.get_accessibility_element()


func has_accessibility_element(target: Variant) -> bool:
	return _accessibility_rid_valid(accessibility_rid(target))


func accessibility_snapshot(target: Variant) -> Dictionary:
	return _accessibility_snapshot(node(target))


func accessibility_tree(root_target: Variant = null, options: Dictionary = {}) -> Dictionary:
	var include_hidden := bool(options.get("include_hidden", false))
	return _accessibility_tree_for_node(_query_root(root_target), include_hidden)


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


func expect_has_accessibility_element(target: Variant, message: String = "") -> void:
	if not has_accessibility_element(target):
		if message == "":
			message = "Expected accessibility element to exist: %s" % str(target)
		_record_failure(message)


func expect_accessibility_role(target: Variant, expected: String, message: String = "") -> void:
	var actual := str(accessibility_snapshot(target).get("role", ""))
	if actual != expected:
		if message == "":
			message = "Accessibility role mismatch expected=%s actual=%s" % [expected, actual]
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


func get_all_by_role(role: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocatorList:
	return _get_all_locators(_build_role_query("get_all_by_role", role, options, root_target))


func query_all_by_role(role: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocatorList:
	return _query_all_locators(_build_role_query("query_all_by_role", role, options, root_target))


func find_all_by_role(role: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocatorList:
	return await _find_all_locators(_build_role_query("find_all_by_role", role, options, root_target))


func get_by_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return _get_single_locator(_build_text_query("get_by_text", "text", text, options, root_target))


func query_by_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return _query_single_locator(_build_text_query("query_by_text", "text", text, options, root_target))


func find_by_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return await _find_single_locator(_build_text_query("find_by_text", "text", text, options, root_target))


func get_all_by_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocatorList:
	return _get_all_locators(_build_text_query("get_all_by_text", "text", text, options, root_target))


func query_all_by_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocatorList:
	return _query_all_locators(_build_text_query("query_all_by_text", "text", text, options, root_target))


func find_all_by_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocatorList:
	return await _find_all_locators(_build_text_query("find_all_by_text", "text", text, options, root_target))


func get_by_label_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return _get_single_locator(_build_text_query("get_by_label_text", "label_text", text, options, root_target))


func query_by_label_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return _query_single_locator(_build_text_query("query_by_label_text", "label_text", text, options, root_target))


func find_by_label_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return await _find_single_locator(_build_text_query("find_by_label_text", "label_text", text, options, root_target))


func get_all_by_label_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocatorList:
	return _get_all_locators(_build_text_query("get_all_by_label_text", "label_text", text, options, root_target))


func query_all_by_label_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocatorList:
	return _query_all_locators(_build_text_query("query_all_by_label_text", "label_text", text, options, root_target))


func find_all_by_label_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocatorList:
	return await _find_all_locators(_build_text_query("find_all_by_label_text", "label_text", text, options, root_target))


func get_by_placeholder_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return _get_single_locator(_build_text_query("get_by_placeholder_text", "placeholder_text", text, options, root_target))


func query_by_placeholder_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return _query_single_locator(_build_text_query("query_by_placeholder_text", "placeholder_text", text, options, root_target))


func find_by_placeholder_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocator:
	return await _find_single_locator(_build_text_query("find_by_placeholder_text", "placeholder_text", text, options, root_target))


func get_all_by_placeholder_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocatorList:
	return _get_all_locators(_build_text_query("get_all_by_placeholder_text", "placeholder_text", text, options, root_target))


func query_all_by_placeholder_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocatorList:
	return _query_all_locators(_build_text_query("query_all_by_placeholder_text", "placeholder_text", text, options, root_target))


func find_all_by_placeholder_text(text: String, options: Dictionary = {}, root_target: Variant = null) -> GodoteerLocatorList:
	return await _find_all_locators(_build_text_query("find_all_by_placeholder_text", "placeholder_text", text, options, root_target))


func get_by_node_name(name: String, root_target: Variant = null) -> GodoteerLocator:
	return _get_single_locator(_build_node_name_query("get_by_node_name", name, root_target))


func query_by_node_name(name: String, root_target: Variant = null) -> GodoteerLocator:
	return _query_single_locator(_build_node_name_query("query_by_node_name", name, root_target))


func get_all_by_node_name(name: String, root_target: Variant = null) -> GodoteerLocatorList:
	return _get_all_locators(_build_node_name_query("get_all_by_node_name", name, root_target))


func query_all_by_node_name(name: String, root_target: Variant = null) -> GodoteerLocatorList:
	return _query_all_locators(_build_node_name_query("query_all_by_node_name", name, root_target))


func find_all_by_node_name(name: String, root_target: Variant = null) -> GodoteerLocatorList:
	return await _find_all_locators(_build_node_name_query("find_all_by_node_name", name, root_target))


func resolve_query(query: Dictionary) -> Node:
	match str(query.get("kind", "")):
		"target":
			return node(query.get("value", null))
		"collection_position":
			return _resolve_collection_position(query)
		_:
			return null


func resolve_query_nodes(query: Dictionary) -> Array:
	return _resolve_matches(query)


func describe_missing_query(query: Dictionary, action_name: String = "", fallback_description: String = "locator") -> String:
	var prefix := "%s() " % action_name if action_name != "" else ""
	if str(query.get("kind", "")) == "collection_position":
		var collection_query: Dictionary = query.get("query", {})
		var matches := _resolve_matches(collection_query)
		var collection_label := str(collection_query.get("label", fallback_description))
		var mode := str(query.get("mode", "nth"))
		if matches.is_empty():
			return "%scollection is empty: %s" % [prefix, collection_label]
		if mode == "nth":
			return "%starget index %d out of range for %s current_count=%d" % [
				prefix,
				int(query.get("index", -1)),
				collection_label,
				matches.size(),
			]
		return "%scollection is empty: %s" % [prefix, collection_label]
	return "%slocator not found: %s" % [prefix, fallback_description]


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


func trace_event(kind: String, details: Dictionary = {}) -> void:
	_trace_event(kind, details)


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
		"description": str(options.get("description", "")),
		"exact": bool(options.get("exact", true)),
		"include_hidden": bool(options.get("include_hidden", false)),
		"checked": bool(options.get("checked", false)),
		"has_checked": options.has("checked"),
		"disabled": bool(options.get("disabled", false)),
		"has_disabled": options.has("disabled"),
	}


func _get_single_locator(query: Dictionary) -> GodoteerLocator:
	_trace_query_started(query)
	var matches := _resolve_matches(query)
	if matches.is_empty():
		_trace_query_failed(query, 0)
		_record_failure("Expected exactly one match for %s, found none" % query["label"])
		return null
	if matches.size() > 1:
		_trace_query_failed(query, matches.size())
		_record_failure("Expected exactly one match for %s, found %d" % [query["label"], matches.size()])
		return null
	_trace_query_resolved(query, matches.size())
	return _target_locator(matches[0], str(query["label"]))


func _query_single_locator(query: Dictionary) -> GodoteerLocator:
	_trace_query_started(query)
	var matches := _resolve_matches(query)
	if matches.is_empty():
		_trace_query_resolved(query, 0)
		return null
	if matches.size() > 1:
		_trace_query_failed(query, matches.size())
		_record_failure("Expected at most one match for %s, found %d" % [query["label"], matches.size()])
		return null
	_trace_query_resolved(query, matches.size())
	return _target_locator(matches[0], str(query["label"]))


func _find_single_locator(query: Dictionary, timeout_sec: float = 2.0, step_frames: int = 1) -> GodoteerLocator:
	_trace_query_started(query, {
		"timeout_sec": timeout_sec,
		"step_frames": step_frames,
	})
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() <= deadline:
		var matches := _resolve_matches(query)
		if matches.size() == 1:
			_trace_query_resolved(query, matches.size())
			return _target_locator(matches[0], str(query["label"]))
		await wait_frames(step_frames)

	var final_matches := _resolve_matches(query)
	if final_matches.is_empty():
		_trace_query_failed(query, 0)
		_record_failure("Timed out waiting for exactly one match for %s" % query["label"])
	else:
		_trace_query_failed(query, final_matches.size())
		_record_failure("Expected exactly one match for %s, found %d" % [query["label"], final_matches.size()])
	return null


func _get_all_locators(query: Dictionary) -> GodoteerLocatorList:
	_trace_query_started(query)
	var matches := _resolve_matches(query)
	if matches.is_empty():
		_trace_query_failed(query, 0)
		_record_failure("Expected at least one match for %s, found none" % query["label"])
	else:
		_trace_query_resolved(query, matches.size())
	return _locator_list(query)


func _query_all_locators(query: Dictionary) -> GodoteerLocatorList:
	_trace_query_started(query)
	var matches := _resolve_matches(query)
	_trace_query_resolved(query, matches.size())
	return _locator_list(query)


func _find_all_locators(query: Dictionary, timeout_sec: float = 2.0, step_frames: int = 1) -> GodoteerLocatorList:
	_trace_query_started(query, {
		"timeout_sec": timeout_sec,
		"step_frames": step_frames,
	})
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() <= deadline:
		var matches := _resolve_matches(query)
		if not matches.is_empty():
			_trace_query_resolved(query, matches.size())
			return _locator_list(query)
		await wait_frames(step_frames)

	_trace_query_failed(query, 0)
	_record_failure("Timed out waiting for at least one match for %s" % query["label"])
	return _locator_list(query)


func _nodes_to_locators(nodes: Array, description: String) -> Array:
	var locators: Array = []
	for candidate in nodes:
		locators.append(_target_locator(candidate, description))
	return locators


func _target_locator(target: Variant, description: String) -> GodoteerLocator:
	return GodoteerLocator.new(self, {"kind": "target", "value": target}, description)


func _locator_list(query: Dictionary) -> GodoteerLocatorList:
	return GodoteerLocatorList.new(self, query, str(query.get("label", "locator_list")))


func _resolve_matches(query: Dictionary) -> Array:
	var start := _query_root(query.get("root", null))
	var matches: Array = []
	_collect_matches(start, query, matches)
	return matches


func _resolve_collection_position(query: Dictionary) -> Node:
	var collection_query: Dictionary = query.get("query", {})
	var matches := _resolve_matches(collection_query)
	if matches.is_empty():
		return null

	match str(query.get("mode", "nth")):
		"first":
			return matches[0]
		"last":
			return matches[matches.size() - 1]
		_:
			var index := int(query.get("index", -1))
			if index < 0 or index >= matches.size():
				return null
			return matches[index]


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

	var wanted_description := str(query["options"]["description"])
	if wanted_description != "":
		if not _string_matches(_accessible_description(candidate), wanted_description, bool(query["options"]["exact"])):
			return false

	if bool(query["options"]["has_checked"]):
		var checked_state = _checked_state(candidate)
		if checked_state == null or checked_state != bool(query["options"]["checked"]):
			return false

	if bool(query["options"]["has_disabled"]):
		if _is_accessibility_disabled(candidate) != bool(query["options"]["disabled"]):
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

	var explicit := _string_from_method(candidate, "get_accessibility_name")
	if explicit != "":
		return explicit

	var relation_label := _relation_text(candidate, "accessibility_labeled_by_nodes")
	if relation_label != "":
		return relation_label

	if _supports_text_accessible_name(candidate):
		return _visible_text(candidate)

	if _is_labelable_control(candidate):
		return _associated_label_text(candidate)

	return ""


func _accessible_description(candidate: Node) -> String:
	if candidate == null or not candidate is Control:
		return ""

	var explicit := _string_from_method(candidate, "get_accessibility_description")
	if explicit != "":
		return explicit

	return _relation_text(candidate, "accessibility_described_by_nodes")


func _label_text(candidate: Node) -> String:
	if candidate == null or not candidate is Control:
		return ""

	var direct_relation_label := _relation_text(candidate, "accessibility_labeled_by_nodes")
	if direct_relation_label != "":
		return direct_relation_label

	var direct_label := _string_from_method(candidate, "get_accessibility_name")
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
	var sibling_label := _previous_label_sibling_text(candidate)
	if sibling_label != "":
		return sibling_label

	var parent := candidate.get_parent()
	while parent != null and parent != app_root.get_parent():
		var container_label := _unambiguous_container_label_text(parent, candidate)
		if container_label != "":
			return container_label
		parent = parent.get_parent()

	return ""


func _previous_label_sibling_text(candidate: Node) -> String:
	var parent := candidate.get_parent()
	if parent == null:
		return ""

	var siblings := parent.get_children()
	var index := siblings.find(candidate)
	if index <= 0:
		return ""

	for sibling_index in range(index - 1, -1, -1):
		var sibling = siblings[sibling_index]
		if sibling is Label and _is_query_visible(sibling):
			var text := _visible_text(sibling)
			if text != "":
				return text
		if sibling is Control and _is_labelable_control(sibling):
			break

	return ""


func _unambiguous_container_label_text(container: Node, candidate: Node) -> String:
	var labels := _collect_visible_labels(container)
	if labels.size() != 1:
		return ""

	var controls := _collect_labelable_controls(container)
	if controls.size() != 1 or controls[0] != candidate:
		return ""

	return labels[0]


func _collect_visible_labels(root: Node) -> Array[String]:
	var labels: Array[String] = []
	for child in root.get_children():
		if child is Label and _is_query_visible(child):
			var text := _visible_text(child)
			if text != "":
				labels.append(text)
				continue

		labels.append_array(_collect_visible_labels(child))

	return labels


func _collect_labelable_controls(root: Node) -> Array:
	var controls: Array = []
	for child in root.get_children():
		if child is Control and _is_labelable_control(child) and _is_query_visible(child):
			controls.append(child)
			continue

		controls.append_array(_collect_labelable_controls(child))

	return controls


func _supports_text_accessible_name(candidate: Node) -> bool:
	return candidate is BaseButton or candidate is Label or candidate is RichTextLabel or candidate is CheckBox or candidate is CheckButton or candidate is OptionButton


func _is_labelable_control(candidate: Node) -> bool:
	return candidate is LineEdit or candidate is TextEdit or candidate is BaseButton or candidate is CheckBox or candidate is CheckButton or candidate is OptionButton


func _is_textbox(candidate: Node) -> bool:
	return candidate is LineEdit or candidate is TextEdit


func _checked_state(candidate: Node):
	if candidate is CheckBox or candidate is CheckButton:
		return bool(candidate.button_pressed)
	return null


func _is_accessibility_disabled(candidate: Node) -> bool:
	if not candidate is Control:
		return false

	if _has_property(candidate, "disabled") and bool(candidate.get("disabled")):
		return true

	if (candidate is LineEdit or candidate is TextEdit) and _has_property(candidate, "editable") and not bool(candidate.get("editable")):
		return true

	return false


func _is_hidden(candidate: Node) -> bool:
	return candidate is CanvasItem and not candidate.is_visible_in_tree()


func _is_query_visible(candidate: Node) -> bool:
	return not _is_hidden(candidate)


func _viewport_image() -> Image:
	return _viewport_image_from(tree.root.get_viewport())


func _viewport_image_from(viewport: Viewport) -> Image:
	if viewport == null:
		return null

	var texture := viewport.get_texture()
	if texture == null:
		return null

	return texture.get_image()


func _capture_screen_image() -> Image:
	if not can_screenshot():
		_record_failure("Screenshots unavailable with current renderer/window mode")
		return null

	var image := _viewport_image()
	if image == null:
		_record_failure("Could not read viewport image for screenshot")
		return null

	return image


func _capture_locator_image(target: Variant) -> Image:
	if not can_screenshot():
		_record_failure("Screenshots unavailable with current renderer/window mode")
		return null

	var target_node := node(target)
	if not target_node is Control:
		_record_failure("capture_locator() supports Control only: %s" % str(target))
		return null

	var control: Control = target_node
	if not control.is_visible_in_tree():
		_record_failure("capture_locator() target is not visible: %s" % str(target))
		return null

	var image := _viewport_image()
	if image == null:
		_record_failure("Could not read viewport image for locator capture")
		return null

	var crop_rect := _locator_capture_rect(control, Vector2i(image.get_width(), image.get_height()))
	if crop_rect.size.x <= 0 or crop_rect.size.y <= 0:
		_record_failure("capture_locator() invalid crop rect for %s: %s" % [str(target), str(crop_rect)])
		return null

	var cropped := image.get_region(crop_rect)
	if cropped == null or cropped.is_empty():
		_record_failure("capture_locator() failed to crop image for %s" % str(target))
		return null

	return cropped


func _capture_camera_image(camera_target: Variant) -> Image:
	if DisplayServer.get_name() == "headless":
		_record_failure("Camera screenshots unavailable with current renderer/window mode")
		return null

	var camera_node := node(camera_target)
	if not (camera_node is Camera2D or camera_node is Camera3D):
		_record_failure("capture_camera() supports Camera2D and Camera3D only: %s" % str(camera_target))
		return null

	var viewport := camera_node.get_viewport()
	if viewport == null or viewport.get_texture() == null:
		_record_failure("capture_camera() could not resolve viewport texture for %s" % str(camera_target))
		return null

	var previous_camera: Variant = _active_camera_for_viewport(viewport, camera_node)
	if previous_camera != camera_node:
		camera_node.make_current()
		await wait_frames(2)

	var image := _viewport_image_from(viewport)
	_restore_camera(previous_camera, camera_node)
	if image == null:
		_record_failure("Could not read viewport image for camera capture")
		return null

	return image


func _save_png_image(image: Image, file_name: String) -> String:
	var save_path := artifacts_dir.path_join(file_name)
	var absolute_path := ProjectSettings.globalize_path(save_path)
	var absolute_dir := absolute_path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK:
		_record_failure("Could not create screenshot dir: %s" % absolute_dir)
		return ""

	var save_error := image.save_png(absolute_path)
	if save_error != OK:
		_record_failure("Could not save screenshot: %s" % save_path)
		return ""

	_trace_artifact(absolute_path, _artifact_kind_for_path(save_path), "Saved artifact %s" % save_path)
	return absolute_path


func _assert_snapshot_image(image: Image, file_name: String, options: Dictionary, source_label: String) -> bool:
	var baseline_info := _snapshot_baseline_info(file_name)
	if baseline_info.is_empty():
		_record_failure("Could not derive snapshot baseline path for %s" % file_name)
		return false

	var baseline_res_path := str(baseline_info["res_path"])
	var baseline_absolute_path := str(baseline_info["absolute_path"])
	var threshold := max(int(options.get("max_diff_pixels", 0)), 0)
	var baseline_exists := FileAccess.file_exists(baseline_absolute_path)

	if not baseline_exists:
		if update_snapshots:
			if _write_snapshot_baseline(image, baseline_absolute_path):
				print("    SNAPSHOT create %s [%s]" % [baseline_res_path, source_label])
				_trace_event("artifact_finished", {
					"message": "Created snapshot baseline %s" % baseline_res_path,
					"artifact_kind": "snapshot_baseline",
					"file_path": baseline_absolute_path,
				})
				return true
			return false

		_record_failure("Missing snapshot baseline for %s: %s" % [source_label, baseline_res_path])
		return false

	var baseline := Image.load_from_file(baseline_absolute_path)
	if baseline == null or baseline.is_empty():
		_record_failure("Could not load snapshot baseline: %s" % baseline_res_path)
		return false

	var comparison := _compare_snapshot_images(baseline, image)
	var diff_pixels := int(comparison.get("diff_pixels", -1))
	if diff_pixels >= 0 and diff_pixels <= threshold:
		_trace_event("artifact_finished", {
			"message": "Snapshot matched %s" % baseline_res_path,
			"artifact_kind": "snapshot_assertion",
			"file_path": baseline_absolute_path,
		})
		return true

	if update_snapshots:
		if _write_snapshot_baseline(image, baseline_absolute_path):
			print("    SNAPSHOT update %s [%s]" % [baseline_res_path, source_label])
			_trace_event("artifact_finished", {
				"message": "Updated snapshot baseline %s" % baseline_res_path,
				"artifact_kind": "snapshot_baseline",
				"file_path": baseline_absolute_path,
			})
			return true
		return false

	var artifact_dir := _snapshot_artifact_dir(file_name)
	var actual_path := _save_png_image(image, artifact_dir.path_join("actual.png"))
	var diff_image: Image = comparison.get("diff_image")
	var diff_path := ""
	if diff_image != null and not diff_image.is_empty():
		diff_path = _save_png_image(diff_image, artifact_dir.path_join("diff.png"))

	var failure_message := "Snapshot mismatch for %s baseline=%s diff_pixels=%d max_diff_pixels=%d actual=%s diff=%s" % [
		source_label,
		baseline_res_path,
		diff_pixels,
		threshold,
		actual_path,
		diff_path,
	]
	if baseline.get_width() != image.get_width() or baseline.get_height() != image.get_height():
		failure_message = "Snapshot size mismatch for %s baseline=%s expected=%dx%d actual=%dx%d actual=%s diff=%s" % [
			source_label,
			baseline_res_path,
			baseline.get_width(),
			baseline.get_height(),
			image.get_width(),
			image.get_height(),
			actual_path,
			diff_path,
		]
	_record_failure(failure_message)
	return false


func _write_snapshot_baseline(image: Image, absolute_path: String) -> bool:
	var absolute_dir := absolute_path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK:
		_record_failure("Could not create snapshot baseline dir: %s" % absolute_dir)
		return false

	var save_error := image.save_png(absolute_path)
	if save_error != OK:
		_record_failure("Could not save snapshot baseline: %s" % absolute_path)
		return false

	_trace_event("artifact_written", {
		"message": "Saved snapshot baseline %s" % absolute_path,
		"artifact_kind": "snapshot_baseline",
		"file_path": absolute_path,
	})
	return true


func _compare_snapshot_images(expected: Image, actual: Image) -> Dictionary:
	var width := max(expected.get_width(), actual.get_width())
	var height := max(expected.get_height(), actual.get_height())
	var diff_image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	diff_image.fill(Color(0, 0, 0, 0))

	var diff_pixels := 0
	for y in range(height):
		for x in range(width):
			var expected_in_bounds := x < expected.get_width() and y < expected.get_height()
			var actual_in_bounds := x < actual.get_width() and y < actual.get_height()
			if expected_in_bounds and actual_in_bounds and expected.get_pixel(x, y) == actual.get_pixel(x, y):
				continue

			diff_pixels += 1
			if not expected_in_bounds or not actual_in_bounds:
				diff_image.set_pixel(x, y, Color(1.0, 0.6, 0.0, 1.0))
			else:
				diff_image.set_pixel(x, y, Color(1.0, 0.0, 0.6, 1.0))

	return {
		"diff_pixels": diff_pixels,
		"diff_image": diff_image,
	}


func _snapshot_baseline_info(file_name: String) -> Dictionary:
	var suite_dir := _snapshot_suite_relative_dir()
	var test_segment := _sanitize_snapshot_segment(active_test_name)
	var file_segment := _sanitize_snapshot_file_name(file_name)
	if suite_dir == "" or test_segment == "" or file_segment == "":
		return {}

	var res_path := "res://tests/__snapshots__/%s/%s/%s" % [suite_dir, test_segment, file_segment]
	return {
		"res_path": res_path,
		"absolute_path": ProjectSettings.globalize_path(res_path),
	}


func _snapshot_suite_relative_dir() -> String:
	var suite_path := active_suite_path
	if suite_path == "":
		return ""

	if suite_path.begins_with("res://tests/"):
		suite_path = suite_path.trim_prefix("res://tests/")
	elif suite_path.begins_with("res://"):
		suite_path = suite_path.trim_prefix("res://")

	suite_path = suite_path.trim_suffix(".gd")
	var parts := suite_path.split("/", false)
	for index in range(parts.size()):
		parts[index] = _sanitize_snapshot_segment(parts[index])
	return "/".join(parts)


func _snapshot_artifact_dir(file_name: String) -> String:
	return "visual_failures/%s/%s/%s" % [
		_snapshot_suite_relative_dir(),
		_sanitize_snapshot_segment(active_test_name),
		_sanitize_snapshot_stem(file_name),
	]


func _sanitize_snapshot_file_name(file_name: String) -> String:
	var stem := _sanitize_snapshot_stem(file_name)
	if stem == "":
		return ""
	return "%s.png" % stem


func _sanitize_snapshot_stem(value: String) -> String:
	var segments := str(value).split("/", false)
	var sanitized_segments: Array[String] = []
	for segment in segments:
		var trimmed_segment := str(segment).trim_suffix(".png")
		var sanitized := _sanitize_snapshot_segment(trimmed_segment)
		if sanitized != "":
			sanitized_segments.append(sanitized)
	return "__".join(sanitized_segments)


func _sanitize_snapshot_segment(value: String) -> String:
	var sanitized := str(value).strip_edges()
	for char in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", " "]:
		sanitized = sanitized.replace(char, "_")
	while sanitized.contains("__"):
		sanitized = sanitized.replace("__", "_")
	while sanitized.begins_with("_"):
		sanitized = sanitized.substr(1)
	while sanitized.ends_with("_"):
		sanitized = sanitized.left(sanitized.length() - 1)
	return sanitized


func _locator_capture_rect(control: Control, image_size: Vector2i) -> Rect2i:
	var visible_rect := control.get_global_rect()
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.clip_contents:
			visible_rect = visible_rect.intersection(ancestor.get_global_rect())
			if visible_rect.size.x <= 0.0 or visible_rect.size.y <= 0.0:
				return Rect2i()
		ancestor = ancestor.get_parent()

	var viewport_rect := Rect2(Vector2.ZERO, Vector2(image_size))
	var clamped_rect := visible_rect.intersection(viewport_rect)
	if clamped_rect.size.x <= 0.0 or clamped_rect.size.y <= 0.0:
		return Rect2i()

	var position := Vector2i(
		int(floor(clamped_rect.position.x)),
		int(floor(clamped_rect.position.y))
	)
	var end_position := Vector2i(
		int(ceil(clamped_rect.end.x)),
		int(ceil(clamped_rect.end.y))
	)
	return Rect2i(position, end_position - position)


func _active_camera_for_viewport(viewport: Viewport, camera_node: Node):
	if camera_node is Camera2D:
		return viewport.get_camera_2d()
	if camera_node is Camera3D:
		return viewport.get_camera_3d()
	return null


func _restore_camera(previous_camera, target_camera) -> void:
	if previous_camera != null and previous_camera != target_camera:
		previous_camera.make_current()
		return

	if previous_camera == null:
		if _has_property(target_camera, "enabled"):
			target_camera.set("enabled", false)
		if _has_property(target_camera, "current"):
			target_camera.set("current", false)


func _ensure_control_enabled(action_name: String, target_node: Node, original_target: Variant, label: String = "target") -> bool:
	if target_node is Control and _has_property(target_node, "disabled") and bool(target_node.get("disabled")):
		_record_failure("%s() %s is disabled: %s" % [action_name, label, str(original_target)])
		return false
	return true


func _ensure_text_input_editable(action_name: String, target_node: Node, original_target: Variant) -> bool:
	if (target_node is LineEdit or target_node is TextEdit) and _has_property(target_node, "editable") and not bool(target_node.get("editable")):
		_record_failure("%s() target is not editable: %s" % [action_name, str(original_target)])
		return false
	return true


func _ensure_action_exists(action_name: String, input_action: String) -> bool:
	if InputMap.has_action(input_action):
		return true

	_record_failure("%s() unknown action: %s" % [action_name, input_action])
	return false


func _option_button_popup(option_button: OptionButton) -> PopupMenu:
	return option_button.get_popup()


func _option_button_item_index(option_button: OptionButton, option_text: String) -> int:
	for index in range(option_button.item_count):
		if option_button.get_item_text(index) == option_text:
			return index
	return -1


func _wait_for_popup_visible(popup: PopupMenu, timeout_sec: float = 0.2) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while Time.get_ticks_msec() <= deadline:
		if popup.visible:
			return true
		await wait_frames(1)
	return popup.visible


func _resolve_optional_position(target: Variant = null) -> Vector2:
	if target == null:
		return last_mouse_position
	if target is Vector2:
		return target
	if target is Vector2i:
		return Vector2(target)
	var position := _resolve_position(target)
	return position if position != null else last_mouse_position


func _wait_signal_frame(physics: bool) -> void:
	if physics:
		await wait_physics_frames(1)
		return
	await wait_frames(1)


func _wait_for_signal_match(
	wait_kind: String,
	target: Variant,
	signal_name: String,
	max_frames: int,
	physics: bool,
	matcher: Callable,
	message: String
) -> Dictionary:
	_trace_event("wait_started", {
		"message": message,
		"signal_name": signal_name,
		"target": str(target),
		"max_frames": int(max_frames),
		"wait_kind": wait_kind,
		"physics": physics,
	})
	var target_node := node(target)
	if target_node == null:
		_record_failure("%s() could not resolve target: %s" % [wait_kind, str(target)])
		return {"fired": false, "args": [], "count": 0, "history": []}
	if not target_node.has_signal(signal_name):
		_record_failure("%s() target has no signal %s: %s" % [wait_kind, signal_name, str(target)])
		return {"fired": false, "args": [], "count": 0, "history": []}

	var probe := _connect_signal_probe(target_node, signal_name)
	if probe == null:
		_record_failure("%s() could not watch signal %s: %s" % [wait_kind, signal_name, str(target)])
		return {"fired": false, "args": [], "count": 0, "history": []}

	var wait_message := message
	if wait_message == "":
		wait_message = "Timed out waiting for signal %s on %s" % [signal_name, str(target)]

	var matched_args: Array = _matching_signal_args(probe, matcher)
	if matched_args.is_empty():
		for _frame in range(max(int(max_frames), 0)):
			await _wait_signal_frame(physics)
			matched_args = _matching_signal_args(probe, matcher)
			if not matched_args.is_empty():
				break

	var history := _duplicate_signal_history(probe.history)
	var received := not matched_args.is_empty()
	_disconnect_signal_probe(target_node, signal_name, probe)
	_trace_event("wait_finished" if received else "wait_timed_out", {
		"message": wait_message,
		"signal_name": signal_name,
		"target": str(target),
		"max_frames": int(max_frames),
		"wait_kind": wait_kind,
		"physics": physics,
		"args": matched_args.duplicate(),
		"count": probe.count,
		"history": history,
	})
	if not received:
		_record_failure(wait_message)

	return {
		"fired": received,
		"args": matched_args.duplicate(),
		"count": probe.count,
		"history": history,
	}


func _matching_signal_args(probe: SignalProbe, matcher: Callable) -> Array:
	if probe == null:
		return []
	for entry in probe.history:
		var args := entry as Array
		if matcher.call(args):
			return args.duplicate()
	return []


func _duplicate_signal_history(history: Array) -> Array:
	var duplicated: Array = []
	for entry in history:
		duplicated.append((entry as Array).duplicate())
	return duplicated


func _joy_input_key(device: int, input_code: int) -> String:
	return "%d:%d" % [device, input_code]


func _connect_signal_probe(target: Object, signal_name: String) -> SignalProbe:
	if target == null or not target.has_signal(signal_name):
		return null

	var probe := SignalProbe.new()
	probe.arg_count = _signal_arg_count(target, signal_name)
	target.connect(signal_name, Callable(probe, "mark"))
	return probe


func _disconnect_signal_probe(target: Object, signal_name: String, probe: SignalProbe) -> bool:
	if target == null or probe == null:
		return false

	var callable := Callable(probe, "mark")
	if target.is_connected(signal_name, callable):
		target.disconnect(signal_name, callable)
	return probe.fired


func _mouse_click_cycle(position: Vector2, button: int, double_click := false, target_node: Node = null) -> void:
	_dispatch_pointer_button(target_node, position, button, true, double_click)
	await wait_frames(1)
	_dispatch_pointer_button(target_node, position, button, false, double_click)


func _dispatch_pointer_button(
	target_node: Node,
	position: Vector2,
	button: int,
	pressed: bool,
	double_click := false
) -> void:
	mouse_button(position, button, pressed, double_click)
	if target_node is Control:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = button
		event.pressed = pressed
		event.double_click = bool(double_click)
		target_node.gui_input.emit(event)


func _accessibility_snapshot(target_node: Node) -> Dictionary:
	if target_node == null:
		return {}

	return {
		"node_path": str(target_node.get_path()),
		"node_name": target_node.name,
		"rid_valid": has_accessibility_element(target_node),
		"role": _node_role(target_node),
		"name": _accessible_name(target_node),
		"description": _accessible_description(target_node),
		"contextual_info": _accessibility_contextual_info(target_node),
		"value": node_value(target_node),
		"placeholder": _placeholder_text(target_node),
		"disabled": _is_accessibility_disabled(target_node),
		"checked": _checked_state(target_node),
		"hidden": _is_hidden(target_node),
		"live": _accessibility_live(target_node),
		"labeled_by": _related_node_paths(target_node, "accessibility_labeled_by_nodes"),
		"described_by": _related_node_paths(target_node, "accessibility_described_by_nodes"),
		"controls": _related_node_paths(target_node, "accessibility_controls_nodes"),
		"flow_to": _related_node_paths(target_node, "accessibility_flow_to_nodes"),
	}


func _accessibility_tree_for_node(target_node: Node, include_hidden: bool) -> Dictionary:
	if target_node == null:
		return {}

	var children: Array = []
	for child in target_node.get_children():
		var child_tree := _accessibility_tree_for_node(child, include_hidden)
		if not child_tree.is_empty():
			children.append(child_tree)

	if not _should_include_accessibility_tree_node(target_node, include_hidden):
		if children.is_empty():
			return {}
		return {
			"node_path": str(target_node.get_path()),
			"node_name": target_node.name,
			"rid_valid": false,
			"role": "",
			"name": "",
			"description": "",
			"contextual_info": "",
			"value": null,
			"placeholder": "",
			"disabled": false,
			"checked": null,
			"hidden": _is_hidden(target_node),
			"live": 0,
			"labeled_by": [],
			"described_by": [],
			"controls": [],
			"flow_to": [],
			"children": children,
		}

	var snapshot := _accessibility_snapshot(target_node)
	snapshot["children"] = children
	return snapshot


func _should_include_accessibility_tree_node(target_node: Node, include_hidden: bool) -> bool:
	if target_node == null:
		return false
	if not include_hidden and _is_hidden(target_node):
		return false
	return target_node is Control or target_node is Window


func _accessibility_rid_valid(rid: RID) -> bool:
	return rid.is_valid() and DisplayServer.accessibility_has_element(rid)


func _accessibility_contextual_info(candidate: Node) -> String:
	if candidate == null or not candidate is Control or not candidate.has_method("_accessibility_get_contextual_info"):
		return ""

	var value = candidate.call("_accessibility_get_contextual_info")
	return str(value) if value is String else ""


func _trace_action_started(action_name: String, details: Dictionary = {}) -> void:
	var payload := details.duplicate()
	payload["action_name"] = action_name
	payload["message"] = "Action started: %s" % action_name
	_trace_event("action_started", payload)


func _trace_action_finished(action_name: String, details: Dictionary = {}) -> void:
	var payload := details.duplicate()
	payload["action_name"] = action_name
	payload["message"] = "Action finished: %s" % action_name
	_trace_event("action_finished", payload)


func _trace_query_started(query: Dictionary, details: Dictionary = {}) -> void:
	var payload := details.duplicate()
	payload["query_label"] = str(query.get("label", ""))
	payload["message"] = "Query started: %s" % str(query.get("label", ""))
	_trace_event("query_started", payload)


func _trace_query_resolved(query: Dictionary, match_count: int) -> void:
	_trace_event("query_resolved", {
		"query_label": str(query.get("label", "")),
		"match_count": match_count,
		"message": "Query resolved: %s (%d)" % [str(query.get("label", "")), match_count],
	})


func _trace_query_failed(query: Dictionary, match_count: int) -> void:
	_trace_event("query_failed", {
		"query_label": str(query.get("label", "")),
		"match_count": match_count,
		"message": "Query failed: %s (%d)" % [str(query.get("label", "")), match_count],
	})


func _trace_artifact(file_path: String, artifact_kind: String, message: String = "") -> void:
	if trace_recorder == null or file_path == "":
		return
	trace_recorder.record_artifact(file_path, artifact_kind, message)


func _trace_event(kind: String, details: Dictionary = {}) -> void:
	if trace_recorder == null:
		return
	trace_recorder.record(kind, details)


func _artifact_kind_for_path(save_path: String) -> String:
	if save_path.contains("/failures/"):
		return "failure_screenshot"
	if save_path.contains("/visual_failures/"):
		return "visual_artifact"
	if save_path.contains("/traces/"):
		return "trace_bundle"
	return "screenshot"


func _accessibility_live(candidate: Node) -> int:
	if candidate == null or not candidate is Control or not _has_property(candidate, "accessibility_live"):
		return 0
	return int(candidate.get("accessibility_live"))


func _relation_text(candidate: Node, property_name: String) -> String:
	var parts: Array[String] = []
	for related_node in _related_nodes(candidate, property_name):
		var text := _visible_text(related_node)
		if text != "":
			parts.append(text)
	return " ".join(parts)


func _related_node_paths(candidate: Node, property_name: String) -> Array[String]:
	var paths: Array[String] = []
	for related_node in _related_nodes(candidate, property_name):
		paths.append(str(related_node.get_path()))
	return paths


func _related_nodes(candidate: Node, property_name: String) -> Array:
	var related: Array = []
	if candidate == null or not candidate is Control:
		return related

	for relation_path in _get_array_property(candidate, property_name):
		if relation_path is NodePath:
			var related_node := candidate.get_node_or_null(relation_path)
			if related_node != null:
				related.append(related_node)

	return related


func _signal_arg_count(target: Object, signal_name: String) -> int:
	if target == null:
		return 0

	for signal_info in target.get_signal_list():
		if str(signal_info.get("name", "")) != signal_name:
			continue

		var args = signal_info.get("args", [])
		return args.size() if args is Array else 0

	return 0


func _get_string_property(target: Object, property_name: String) -> String:
	if target == null:
		return ""

	for property_info in target.get_property_list():
		if str(property_info.get("name", "")) != property_name:
			continue

		var value = target.get(property_name)
		return str(value) if value is String else ""

	return ""


func _get_array_property(target: Object, property_name: String) -> Array:
	if target == null:
		return []

	for property_info in target.get_property_list():
		if str(property_info.get("name", "")) != property_name:
			continue

		var value = target.get(property_name)
		return value if value is Array else []

	return []


func _string_from_method(target: Object, method_name: String) -> String:
	if target == null or not target.has_method(method_name):
		return ""

	var value = target.call(method_name)
	return str(value) if value is String else ""


func _node_role(candidate: Node) -> String:
	if candidate is Window:
		return "window"
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
