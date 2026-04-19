extends Node

const CLEANUP_KEY := KEY_Q
const CLEANUP_ACTION := "move_right"
const CLEANUP_DEVICE := 0
const CLEANUP_JOY_BUTTON := JOY_BUTTON_A
const CLEANUP_JOY_AXIS := JOY_AXIS_LEFT_X

var key_q_pressed_on_ready := false
var action_move_right_pressed_on_ready := false
var joy_button_a_pressed_on_ready := false
var joy_axis_left_x_on_ready := 0.0

var last_key_pressed := KEY_NONE
var last_key_released := KEY_NONE
var key_press_count := 0
var key_release_count := 0

var mouse_wheel_vertical := 0
var mouse_wheel_horizontal := 0
var mouse_relative_total := Vector2.ZERO

var last_joy_button_pressed := -1
var last_joy_button_released := -1
var joy_button_press_count := 0
var joy_button_release_count := 0
var joy_button_a_down := false
var joy_button_b_down := false
var last_joy_axis := -1
var last_joy_axis_value := 0.0
var joy_axis_values := {}
var joy_axis_left_x_now := 0.0

var touch_press_count := 0
var touch_move_count := 0
var touch_release_count := 0
var last_touch_position := Vector2.ZERO
var active_touch_count := 0
var pinch_distance_delta := 0.0
var pinch_distance_total := 0.0

var _touch_positions := {}
var _last_pinch_distance := -1.0


func _ready() -> void:
	set_process_input(true)
	key_q_pressed_on_ready = Input.is_key_pressed(CLEANUP_KEY)
	action_move_right_pressed_on_ready = Input.is_action_pressed(CLEANUP_ACTION)
	joy_button_a_pressed_on_ready = Input.is_joy_button_pressed(CLEANUP_DEVICE, CLEANUP_JOY_BUTTON)
	joy_axis_left_x_on_ready = Input.get_joy_axis(CLEANUP_DEVICE, CLEANUP_JOY_AXIS)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.pressed:
			last_key_pressed = event.keycode
			key_press_count += 1
		else:
			last_key_released = event.keycode
			key_release_count += 1
		return

	if event is InputEventMouseMotion:
		mouse_relative_total += event.relative
		return

	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				mouse_wheel_vertical += 1
			MOUSE_BUTTON_WHEEL_DOWN:
				mouse_wheel_vertical -= 1
			MOUSE_BUTTON_WHEEL_RIGHT:
				mouse_wheel_horizontal += 1
			MOUSE_BUTTON_WHEEL_LEFT:
				mouse_wheel_horizontal -= 1
		return

	if event is InputEventJoypadButton:
		if event.pressed:
			last_joy_button_pressed = event.button_index
			joy_button_press_count += 1
		else:
			last_joy_button_released = event.button_index
			joy_button_release_count += 1
		if event.button_index == JOY_BUTTON_A:
			joy_button_a_down = event.pressed
		elif event.button_index == JOY_BUTTON_B:
			joy_button_b_down = event.pressed
		return

	if event is InputEventJoypadMotion:
		last_joy_axis = event.axis
		last_joy_axis_value = event.axis_value
		joy_axis_values[str(event.axis)] = event.axis_value
		if event.axis == JOY_AXIS_LEFT_X:
			joy_axis_left_x_now = event.axis_value
		return

	if event is InputEventScreenTouch:
		last_touch_position = event.position
		if event.pressed:
			touch_press_count += 1
			_touch_positions[event.index] = event.position
		else:
			touch_release_count += 1
			_touch_positions.erase(event.index)
		active_touch_count = _touch_positions.size()
		_update_pinch_distance()
		return

	if event is InputEventScreenDrag:
		touch_move_count += 1
		last_touch_position = event.position
		_touch_positions[event.index] = event.position
		active_touch_count = _touch_positions.size()
		_update_pinch_distance()


func _update_pinch_distance() -> void:
	if _touch_positions.size() < 2:
		_last_pinch_distance = -1.0
		pinch_distance_delta = 0.0
		return

	var keys := _touch_positions.keys()
	var current_distance := (_touch_positions[keys[0]] as Vector2).distance_to(_touch_positions[keys[1]] as Vector2)
	if _last_pinch_distance >= 0.0:
		pinch_distance_delta = current_distance - _last_pinch_distance
		pinch_distance_total += absf(pinch_distance_delta)
	_last_pinch_distance = current_distance
