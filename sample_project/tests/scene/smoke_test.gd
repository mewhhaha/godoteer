extends "res://addons/godoteer/test_scene.gd"

const SAMPLE_APP := preload("res://scenes/sample_app.tscn")


func test_accessibility_first_queries(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	var form := screen.within(screen.get_by_node_name("FormPanel"))
	var status := form.get_by_node_name("StatusLabel")
	var start_button := form.get_by_role("button", {"name": "Start"})
	var name_field := form.get_by_role("textbox", {"name": "Player Name"})
	var label_field := form.get_by_label_text("Player Name")
	var placeholder_field := form.get_by_placeholder_text("Enter hero name")

	status.expect_text("Idle", "Status should start idle")
	start_button.expect_exists("Start button should resolve by role and accessible name")
	expect(name_field.node() == label_field.node(), "Role and label query should find same input")
	expect(name_field.node() == placeholder_field.node(), "Placeholder query should find same input")
	screen.expect_accessible_name(start_button, "Start")
	screen.expect_accessible_description(start_button, "Starts sample flow")
	screen.expect_accessible_description(status, "Current sample status")
	screen.screen_reader_supported()
	screen.screen_reader_active()


func test_click_updates_visible_text_with_find(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	var form := screen.within(screen.get_by_node_name("FormPanel"))
	var start_button := form.get_by_role("button", {"name": "Start"})

	screen.get_by_text("Idle").expect_exists("Idle text should be visible before click")
	await screen.move_mouse_between(Vector2(0, 0), Vector2(120, 120), 0.05, 6)
	await start_button.click()

	var started := await screen.find_by_text("Started")
	expect(started != null, "find_by_text should wait for delayed Started text")
	if started != null:
		started.expect_text("Started", "Visible text should update after click")


func test_query_returns_null_for_zero_matches(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	var missing := screen.query_by_text("Nope")

	expect(missing == null, "query_by_text should return null on zero matches")
	expect(drain_failures().size() == 0, "query_by_text zero matches should not record failure")


func test_get_records_failure_for_zero_matches(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	set_failures_quiet(true)
	var missing := screen.get_by_text("Nope")
	set_failures_quiet(false)
	var failures := drain_failures()

	expect(missing == null, "get_by_text should return null when it records failure")
	expect(failures.size() == 1, "get_by_text zero matches should record exactly one failure", failures)
	expect(str(failures[0]).contains("get_by_text"), "Failure should mention strict get_by_text lookup", failures)


func test_windowed_screenshot_if_available(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	if screen.can_screenshot():
		var screenshot_path := screen.screenshot("smoke.png")
		expect(FileAccess.file_exists(screenshot_path), "Screenshot should exist on disk", screenshot_path)
