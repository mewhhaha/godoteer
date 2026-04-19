extends "res://addons/godoteer/test_scene.gd"

const GAMEPLAY_EVENTS_PROBE := preload("res://scenes/gameplay_events_probe.tscn")


func test_hold_helpers_and_key_chord(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(GAMEPLAY_EVENTS_PROBE)
	var probe := screen.get_by_node_name("GameplayEventsProbe").node()

	var held_action := await screen.hold_action_until(
		"move_right",
		func() -> bool:
			return probe.action_hold_reached,
		30
	)
	expect(held_action, "hold_action_until should succeed for move_right")
	expect(probe.action_hold_reached, "hold_action_until should advance action-driven state")
	expect(not Input.is_action_pressed("move_right"), "hold_action_until should release held action")

	var held_key := await screen.hold_key_until(
		KEY_RIGHT,
		func() -> bool:
			return probe.key_hold_reached,
		30
	)
	expect(held_key, "hold_key_until should succeed for KEY_RIGHT")
	expect(probe.key_hold_reached, "hold_key_until should advance key-driven state")
	expect(not Input.is_key_pressed(KEY_RIGHT), "hold_key_until should release held key")

	await screen.key_chord([KEY_CTRL, KEY_S], 2)
	await screen.wait_frames(2)
	expect(probe.chord_detected, "key_chord should trigger CTRL+S detection")
	expect(probe.chord_detection_count == 1, "key_chord should only detect once", probe.chord_detection_count)


func test_pointer_variants(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(GAMEPLAY_EVENTS_PROBE)
	var probe := screen.get_by_node_name("GameplayEventsProbe").node()
	var pointer_target := screen.get_by_node_name("PointerTarget")

	await pointer_target.dblclick()
	await screen.wait_frames(2)
	await pointer_target.right_click()
	await screen.wait_frames(1)
	await pointer_target.long_press(12)
	await screen.wait_frames(2)

	expect(probe.double_click_count >= 1, "dblclick should record double-click event", probe.double_click_count)
	expect(probe.right_click_count == 1, "right_click should record right-click event", probe.right_click_count)
	expect(probe.long_press_count == 1, "long_press should record held click", probe.long_press_count)
	expect(probe.pointer_status == "long", "last pointer status should reflect long press", probe.pointer_status)


func test_signal_assertions(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(GAMEPLAY_EVENTS_PROBE)
	var probe := screen.get_by_node_name("GameplayEventsProbe").node()

	probe.arm_process_signal_once("alpha")
	var next_process := await screen.expect_signal(probe, "probe_signal", 30, false)
	expect(next_process.get("fired", false), "expect_signal should capture one emitted signal", next_process)
	expect(next_process.get("args", [])[0] == "once", "expect_signal should capture kind arg", next_process)
	expect(next_process.get("args", [])[2] == "alpha", "expect_signal should capture payload arg", next_process)

	var quiet_pass := await screen.expect_no_signal(probe, "probe_signal", 3, false)
	expect(quiet_pass, "expect_no_signal should pass when signal stays silent")

	probe.start_process_burst(3, "burst")
	var process_history := await screen.expect_signal_count(probe, "probe_signal", 3, 12, false)
	expect(process_history.size() == 3, "expect_signal_count should capture three process emissions", process_history)
	expect(process_history[0][0] == "burst", "expect_signal_count should keep arg history", process_history)

	probe.start_physics_burst(2, "physics")
	var physics_history := await screen.expect_signal_count(probe, "probe_signal", 2, 12, true)
	expect(physics_history.size() == 2, "expect_signal_count should work on physics frames too", physics_history)
	expect(physics_history[0][0] == "physics", "physics signal history should preserve payload kind", physics_history)

	drain_failures()
	set_failures_quiet(true)
	probe.arm_process_signal_once("boom")
	var silent := await screen.expect_no_signal(probe, "probe_signal", 10, false)
	set_failures_quiet(false)
	var failures := drain_failures()

	expect(not silent, "expect_no_signal should fail when signal fires")
	expect(failures.size() == 1, "expect_no_signal failure should record one message", failures)
	expect(str(failures[0]).contains("Expected no signal probe_signal"), "expect_no_signal failure should explain unexpected signal", failures)


func test_wait_for_animation_and_overlap_events(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(GAMEPLAY_EVENTS_PROBE)
	var probe := screen.get_by_node_name("GameplayEventsProbe").node()
	var animation_player := screen.get_by_node_name("AnimationPlayer").node()
	var sensor_area := screen.get_by_node_name("SensorArea").node()

	probe.play_probe_animation("pulse")
	var animation_result := await screen.wait_for_animation_finished(animation_player, "pulse", 30)
	expect(animation_result.get("fired", false), "wait_for_animation_finished should capture animation end", animation_result)
	expect(animation_result.get("args", [])[0] == "pulse", "animation wait should return finished animation name", animation_result)
	expect(probe.animation_finished_count == 1, "animation callback should fire once", probe.animation_finished_count)

	probe.queue_body_entry()
	var body_result := await screen.wait_for_body_entered(sensor_area, 30)
	expect(body_result.get("fired", false), "wait_for_body_entered should capture overlap", body_result)
	expect((body_result.get("args", [])[0] as Node).name == "BodyProbe", "body_entered should report BodyProbe", body_result)
	expect(probe.last_body_name == "BodyProbe", "fixture should record body name", probe.last_body_name)

	probe.queue_area_entry()
	var area_result := await screen.wait_for_area_entered(sensor_area, 30)
	expect(area_result.get("fired", false), "wait_for_area_entered should capture overlap", area_result)
	expect((area_result.get("args", [])[0] as Node).name == "AreaProbe", "area_entered should report AreaProbe", area_result)
	expect(probe.last_area_name == "AreaProbe", "fixture should record area name", probe.last_area_name)


func test_wait_for_audio_finished_windowed(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(GAMEPLAY_EVENTS_PROBE)
	if DisplayServer.get_name() == "headless":
		expect(true, "Audio finished verification skipped in headless")
		return

	var probe := screen.get_by_node_name("GameplayEventsProbe").node()
	var audio_player := screen.get_by_node_name("AudioPlayer").node()
	probe.play_probe_audio()
	var finished := await screen.wait_for_audio_finished(audio_player, 120)
	expect(finished, "wait_for_audio_finished should succeed in windowed run")
	expect(not audio_player.playing, "wait_for_audio_finished should end with stopped playback", audio_player.playing)
