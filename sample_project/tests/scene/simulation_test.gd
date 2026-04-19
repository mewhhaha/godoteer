extends "res://addons/godoteer/test_scene.gd"

const SIMULATION_PROBE := preload("res://scenes/simulation_probe.tscn")


func test_frame_budget_waits_and_signal_payloads(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SIMULATION_PROBE)
	var probe := screen.get_by_node_name("SimulationProbe").node()

	var process_ready := await screen.wait_until_frames(
		func() -> bool:
			return probe.process_count >= 3,
		30,
		"process_count should advance within frame budget"
	)
	expect(process_ready, "wait_until_frames should succeed for process progression", probe.process_count)

	var physics_ready := await screen.wait_until_physics(
		func() -> bool:
			return probe.physics_count >= 3,
		30,
		"physics_count should advance within frame budget"
	)
	expect(physics_ready, "wait_until_physics should succeed for physics progression", probe.physics_count)

	var process_signal := await screen.next_signal(probe, "process_pulse", 30, false)
	expect(process_signal.get("fired", false), "next_signal should capture process_pulse")
	expect((process_signal.get("args", []) as Array).size() == 2, "process_pulse should expose two payload args", process_signal)
	expect(int((process_signal.get("args", []) as Array)[0]) > 0, "process_pulse frame_count payload should be positive", process_signal)
	expect(float((process_signal.get("args", []) as Array)[1]) > 0.0, "process_pulse delta_sum payload should be positive", process_signal)

	var physics_signal := await screen.next_signal(probe, "physics_pulse", 30, true)
	expect(physics_signal.get("fired", false), "next_signal should capture physics_pulse")
	expect((physics_signal.get("args", []) as Array).size() == 2, "physics_pulse should expose two payload args", physics_signal)
	expect(int((physics_signal.get("args", []) as Array)[0]) > 0, "physics_pulse frame_count payload should be positive", physics_signal)
	expect(float((physics_signal.get("args", []) as Array)[1]) > 0.0, "physics_pulse delta_sum payload should be positive", physics_signal)

	drain_failures()
	set_failures_quiet(true)
	screen.pause_scene()
	var timed_out := await screen.next_signal(probe, "physics_pulse", 3, true)
	screen.resume_scene()
	set_failures_quiet(false)
	var failures := drain_failures()

	expect(not timed_out.get("fired", false), "next_signal should return fired=false on timeout", timed_out)
	expect((timed_out.get("args", []) as Array).is_empty(), "next_signal timeout should return empty args", timed_out)
	expect(failures.size() == 1, "next_signal timeout should record one failure", failures)
	expect(str(failures[0]).contains("Timed out waiting for signal physics_pulse"), "Timeout failure should mention signal name", failures)


func test_pause_time_scale_and_reset_cleanup(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SIMULATION_PROBE)
	var probe := screen.get_by_node_name("SimulationProbe").node()

	await screen.wait_until_physics(
		func() -> bool:
			return probe.physics_count >= 3,
		30,
		"physics_count should be ready before pause"
	)

	var process_before_pause: int = probe.process_count
	var physics_before_pause: int = probe.physics_count
	screen.pause_scene()
	await screen.wait_frames(6)
	expect(probe.process_count == process_before_pause, "pause_scene should stop _process progression", process_before_pause, probe.process_count)
	expect(probe.physics_count == physics_before_pause, "pause_scene should stop _physics_process progression", physics_before_pause, probe.physics_count)

	screen.resume_scene()
	var resumed := await screen.wait_until_frames(
		func() -> bool:
			return probe.process_count > process_before_pause and probe.physics_count > physics_before_pause,
		30,
		"resume_scene should restore process and physics progression"
	)
	expect(resumed, "resume_scene should restart scene progression", probe.process_count, probe.physics_count)

	var baseline_before: float = probe.physics_delta_sum
	await screen.wait_physics_frames(6)
	var baseline_gain: float = probe.physics_delta_sum - baseline_before

	screen.set_time_scale(2.0)
	var scaled_before: float = probe.physics_delta_sum
	await screen.wait_physics_frames(6)
	var scaled_gain: float = probe.physics_delta_sum - scaled_before
	expect(scaled_gain > baseline_gain * 1.5, "set_time_scale(2.0) should increase accumulated physics delta", baseline_gain, scaled_gain)

	drain_failures()
	set_failures_quiet(true)
	screen.set_time_scale(0.0)
	set_failures_quiet(false)
	var scale_failures := drain_failures()
	expect(scale_failures.size() == 1, "set_time_scale(0.0) should record one failure", scale_failures)
	expect(str(scale_failures[0]).contains("set_time_scale() requires scale > 0.0"), "Invalid time scale failure should explain constraint", scale_failures)

	screen.pause_scene()
	screen.set_time_scale(2.0)
	await driver.reset()

	var reset_screen := await driver.screen(SIMULATION_PROBE)
	expect(not reset_screen.tree.paused, "driver.reset() should restore SceneTree.paused", reset_screen.tree.paused)
	expect(is_equal_approx(Engine.time_scale, 1.0), "driver.reset() should restore Engine.time_scale", Engine.time_scale)
