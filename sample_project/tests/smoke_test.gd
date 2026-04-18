extends "res://addons/godoteer_gd/test_case.gd"


func run(screen: GodoteerDriver) -> void:
	var status = screen.get_by_name("StatusLabel")
	var start_button = screen.get_by_role("button", "Start")

	status.expect_exists("Idle label should exist")
	status.expect_text("Idle", "Label should start idle")
	start_button.expect_exists("Start button should exist")

	await start_button.click()

	var changed := await status.wait_for_text("Started", 2.0, 1, "Status label never changed to Started")
	expect_true(changed, "wait_until should succeed")
	status.expect_text("Started", "Button click should update label")

	if screen.can_screenshot():
		var screenshot_path := screen.screenshot("smoke.png")
		expect_true(FileAccess.file_exists(screenshot_path), "Screenshot should exist on disk")
