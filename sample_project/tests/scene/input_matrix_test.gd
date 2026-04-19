extends "res://addons/godoteer/test_scene.gd"

const INPUT_MATRIX_PROBE := preload("res://scenes/input_matrix_probe.tscn")


func test_raw_keyboard_gamepad_mouse_and_touch_inputs(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(INPUT_MATRIX_PROBE)
	var probe := screen.get_by_node_name("InputMatrixProbe").node()

	screen.key_press(KEY_A)
	await screen.wait_frames(1)
	screen.key_release(KEY_A)
	await screen.wait_frames(1)
	await screen.key_tap(KEY_B, 2)
	expect(probe.last_key_pressed == KEY_B, "key_tap should end with KEY_B press", probe.last_key_pressed)
	expect(probe.last_key_released == KEY_B, "key_tap should end with KEY_B release", probe.last_key_released)
	expect(probe.key_press_count >= 2, "Raw key helpers should record press events", probe.key_press_count)
	expect(probe.key_release_count >= 2, "Raw key helpers should record release events", probe.key_release_count)

	screen.joy_button_press(JOY_BUTTON_A)
	await screen.wait_frames(1)
	screen.joy_button_release(JOY_BUTTON_A)
	await screen.wait_frames(1)
	await screen.joy_button_tap(JOY_BUTTON_B, 2)
	expect(probe.last_joy_button_pressed == JOY_BUTTON_B, "joy_button_tap should press JOY_BUTTON_B", probe.last_joy_button_pressed)
	expect(not probe.joy_button_b_down, "joy_button_tap should end with JOY_BUTTON_B released", probe.joy_button_b_down)
	expect(probe.joy_button_press_count >= 2, "Gamepad button helpers should record presses", probe.joy_button_press_count)

	screen.joy_axis_set(JOY_AXIS_LEFT_X, 0.75)
	await screen.wait_frames(1)
	expect(is_equal_approx(probe.joy_axis_left_x_now, 0.75), "joy_axis_set should record current axis value", probe.joy_axis_left_x_now)
	screen.joy_axis_reset(JOY_AXIS_LEFT_X)
	await screen.wait_frames(1)
	expect(is_equal_approx(probe.joy_axis_left_x_now, 0.0), "joy_axis_reset should restore neutral axis", probe.joy_axis_left_x_now)

	await screen.mouse_wheel(2, -1, Vector2(30, 30))
	expect(probe.mouse_wheel_vertical == 2, "mouse_wheel should accumulate vertical steps", probe.mouse_wheel_vertical)
	expect(probe.mouse_wheel_horizontal == -1, "mouse_wheel should accumulate horizontal steps", probe.mouse_wheel_horizontal)
	var relative_before: Vector2 = probe.mouse_relative_total
	screen.mouse_move_relative(Vector2(8, -3))
	await screen.wait_frames(1)
	var relative_delta: Vector2 = probe.mouse_relative_total - relative_before
	expect(relative_delta.length() > 0.0, "mouse_move_relative should produce non-zero relative motion", relative_delta)

	screen.touch_press(Vector2(10, 10), 0)
	await screen.wait_frames(1)
	screen.touch_move(Vector2(20, 20), 0)
	await screen.wait_frames(1)
	screen.touch_release(Vector2(20, 20), 0)
	await screen.wait_frames(1)
	expect(probe.touch_press_count == 1, "touch_press should record one press", probe.touch_press_count)
	expect(probe.touch_move_count >= 1, "touch_move should record move event", probe.touch_move_count)
	expect(probe.touch_release_count == 1, "touch_release should record one release", probe.touch_release_count)

	await screen.touch_tap(Vector2(40, 40), 0, 2)
	expect(probe.touch_press_count == 2, "touch_tap should add one press", probe.touch_press_count)
	expect(probe.touch_release_count == 2, "touch_tap should add one release", probe.touch_release_count)

	await screen.touch_drag(Vector2(50, 50), Vector2(80, 50), 0, 0.05, 4)
	expect(probe.touch_move_count >= 5, "touch_drag should produce drag move events", probe.touch_move_count)

	await screen.touch_pinch(Vector2(100, 100), Vector2(140, 100), Vector2(90, 100), Vector2(150, 100), 0.05, 4, 0, 1)
	expect(probe.active_touch_count == 0, "touch_pinch should release both touches", probe.active_touch_count)
	expect(probe.pinch_distance_total > 0.0, "touch_pinch should change pinch distance", probe.pinch_distance_total)


func test_release_all_inputs_on_reset(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(INPUT_MATRIX_PROBE)

	screen.action_press("move_right")
	screen.key_press(KEY_Q)
	screen.joy_button_press(JOY_BUTTON_A)
	screen.joy_axis_set(JOY_AXIS_LEFT_X, 0.5)
	screen.touch_press(Vector2(12, 12), 0)
	await driver.reset()

	var reset_screen := await driver.screen(INPUT_MATRIX_PROBE)
	var probe := reset_screen.get_by_node_name("InputMatrixProbe").node()
	expect(not probe.key_q_pressed_on_ready, "reset should release held key state", probe.key_q_pressed_on_ready)
	expect(not probe.action_move_right_pressed_on_ready, "reset should release held action state", probe.action_move_right_pressed_on_ready)
	expect(not probe.joy_button_a_pressed_on_ready, "reset should release held joy button state", probe.joy_button_a_pressed_on_ready)
	expect(is_equal_approx(probe.joy_axis_left_x_on_ready, 0.0), "reset should neutralize joy axis state", probe.joy_axis_left_x_on_ready)

	await reset_screen.touch_tap(Vector2(30, 30), 0)
	expect(probe.touch_press_count == 1 and probe.touch_release_count == 1, "touch cleanup should allow fresh touch_tap after reset", probe.touch_press_count, probe.touch_release_count)
