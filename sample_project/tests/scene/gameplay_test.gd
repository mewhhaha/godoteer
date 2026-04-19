extends "res://addons/godoteer/test_scene.gd"

const GAMEPLAY_INPUT_PROBE := preload("res://scenes/gameplay_input_probe.tscn")


func _tap_jump(screen) -> void:
	await screen.action_tap("jump", 1)


func test_action_press_release_and_tap(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(GAMEPLAY_INPUT_PROBE)
	var gameplay := screen.get_by_node_name("GameplayInputProbe").node()

	await screen.wait_physics_frames(2)
	var initial_x: float = gameplay.position_x
	screen.action_press("move_right")
	await screen.wait_physics_frames(6)
	var moved_x: float = gameplay.position_x
	expect(moved_x > initial_x, "action_press(move_right) should move fixture right", initial_x, moved_x)

	screen.action_release("move_right")
	var stopped_x: float = gameplay.position_x
	await screen.wait_physics_frames(6)
	expect(is_equal_approx(gameplay.position_x, stopped_x), "action_release(move_right) should stop movement", gameplay.position_x, stopped_x)
	expect(gameplay.last_horizontal_input == 0.0, "Released action should clear horizontal input", gameplay.last_horizontal_input)

	call_deferred("_tap_jump", screen)
	var jumped := await screen.wait_for_signal(gameplay, "jumped", 0.5)
	expect(jumped, "action_tap(jump) should emit jumped signal")
	expect(gameplay.jump_count == 1, "Jump action should increment jump_count once", gameplay.jump_count)


func test_wait_for_signal_timeout_and_unknown_action_failures(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(GAMEPLAY_INPUT_PROBE)
	var gameplay := screen.get_by_node_name("GameplayInputProbe").node()

	drain_failures()
	set_failures_quiet(true)
	var did_fire := await screen.wait_for_signal(gameplay, "jumped", 0.05)
	screen.action_press("missing_action")
	set_failures_quiet(false)
	var failures := drain_failures()

	expect(not did_fire, "wait_for_signal should return false on timeout")
	expect(failures.size() == 2, "Timeout and unknown action should record two failures", failures)
	expect(str(failures[0]).contains("Timed out waiting for signal jumped"), "Timeout failure should mention jumped signal", failures)
	expect(str(failures[1]).contains("action_press() unknown action"), "Unknown action failure should explain missing action", failures)
