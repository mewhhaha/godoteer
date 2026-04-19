extends "res://addons/godoteer/test_scene.gd"

const SAMPLE_APP := preload("res://scenes/sample_app.tscn")


func test_visual_snapshots_match_baselines(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	if not screen.can_screenshot():
		drain_failures()
		set_failures_quiet(true)
		var unavailable := screen.expect_snapshot("sample-app")
		set_failures_quiet(false)
		var headless_failures := drain_failures()

		expect(not unavailable, "Headless snapshot run should fail honestly")
		expect(headless_failures.size() == 1, "Headless snapshot run should record one failure", headless_failures)
		expect(str(headless_failures[0]).contains("Screenshots unavailable"), "Headless snapshot failure should explain screenshot support", headless_failures)
		return

	var form := screen.within(screen.get_by_node_name("FormPanel"))
	var start_button := form.get_by_role("button", {"name": "Start"})
	var left_camera := screen.get_by_node_name("LeftCamera").node()

	expect(screen.expect_snapshot("sample-app"), "Full-screen snapshot should match baseline")
	expect(start_button.expect_snapshot("start-button"), "Locator snapshot should match baseline")
	expect(await screen.expect_camera_snapshot(left_camera, "left-camera"), "Camera snapshot should match baseline")


func test_visual_snapshot_failure_paths(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	if not screen.can_screenshot():
		return

	expect(screen.expect_snapshot("sample-app"), "Failure-path suite should start from matching baseline")
	if _update_snapshots_enabled():
		return

	drain_failures()
	set_failures_quiet(true)
	var missing_baseline := screen.expect_snapshot("missing-baseline")
	set_failures_quiet(false)
	var missing_failures := drain_failures()

	expect(not missing_baseline, "Missing baseline should fail without update mode")
	expect(missing_failures.size() == 1, "Missing baseline should record one failure", missing_failures)
	expect(str(missing_failures[0]).contains("Missing snapshot baseline"), "Missing baseline failure should explain baseline path", missing_failures)

	var status_label := screen.get_by_node_name("StatusLabel").node()
	status_label.text = "Snapshot Drift"
	await screen.wait_frames(1)

	drain_failures()
	set_failures_quiet(true)
	var mismatch := screen.expect_snapshot("sample-app")
	set_failures_quiet(false)
	var mismatch_failures := drain_failures()
	var artifact_dir := ProjectSettings.globalize_path(
		"user://artifacts/visual_failures/scene/visual_snapshot_test/test_visual_snapshot_failure_paths/sample-app"
	)
	var actual_path := artifact_dir.path_join("actual.png")
	var diff_path := artifact_dir.path_join("diff.png")

	expect(not mismatch, "Snapshot mismatch should fail without update mode")
	expect(mismatch_failures.size() == 1, "Snapshot mismatch should record one failure", mismatch_failures)
	expect(str(mismatch_failures[0]).contains("Snapshot mismatch"), "Mismatch failure should explain diff", mismatch_failures)
	expect(FileAccess.file_exists(actual_path), "Mismatch should write actual artifact", actual_path)
	expect(FileAccess.file_exists(diff_path), "Mismatch should write diff artifact", diff_path)


func _update_snapshots_enabled() -> bool:
	return OS.get_cmdline_user_args().has("--update-snapshots")
