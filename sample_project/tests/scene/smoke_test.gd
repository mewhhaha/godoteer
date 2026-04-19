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
	var terms_toggle := form.get_by_role("checkbox", {"name": "Accept Terms"})
	var role_select := form.get_by_role("combobox", {"name": "Role"})
	var hidden_message := form.get_by_node_name("HiddenMessage")
	var disabled_button := form.get_by_node_name("DisabledButton")

	await status.to_have_text("Idle")
	await status.not_to_have_text("Started")
	await start_button.to_exist()
	await terms_toggle.to_be_visible()
	await start_button.to_be_enabled()
	await hidden_message.to_be_hidden()
	await disabled_button.to_be_disabled()
	expect(name_field.node() == label_field.node(), "Role and label query should find same input")
	expect(name_field.node() == placeholder_field.node(), "Placeholder query should find same input")
	expect(role_select.value() == "Mage", "Combobox should start at first option")
	screen.expect_accessible_name(start_button, "Start")
	screen.expect_accessible_description(start_button, "Starts sample flow")
	screen.expect_accessible_description(status, "Current sample status")
	screen.screen_reader_supported()
	screen.screen_reader_active()


func test_click_updates_visible_text_with_find(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	var form := screen.within(screen.get_by_node_name("FormPanel"))
	var status := form.get_by_node_name("StatusLabel")
	var start_button := form.get_by_role("button", {"name": "Start"})
	var name_field := form.get_by_role("textbox", {"name": "Player Name"})
	var terms_toggle := form.get_by_role("checkbox", {"name": "Accept Terms"})
	var role_select := form.get_by_role("combobox", {"name": "Role"})

	await name_field.focus()
	await status.to_have_text("Focused Name")
	await name_field.blur()
	await status.to_have_text("Blurred Name")
	await terms_toggle.hover()
	await status.to_have_text("Hover Terms")
	await name_field.fill("Mew")
	await name_field.to_have_value("Mew")
	await terms_toggle.set_checked(true)
	await terms_toggle.to_be_checked()
	await role_select.select_option("Rogue")
	await role_select.to_have_value("Rogue")
	await name_field.press(KEY_ENTER)
	await screen.move_mouse_between(Vector2(0, 0), Vector2(120, 120), 0.05, 6)
	await start_button.click()

	var started := await screen.find_by_text("Started Mew / Accepted / Rogue")
	expect(started != null, "find_by_text should wait for delayed Started text")
	if started != null:
		await started.to_have_text("Started Mew / Accepted / Rogue")


func test_checkbox_and_clear_actions(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	var form := screen.within(screen.get_by_node_name("FormPanel"))
	var name_field := form.get_by_role("textbox", {"name": "Player Name"})
	var terms_toggle := form.get_by_role("checkbox", {"name": "Accept Terms"})

	await name_field.fill("Temp")
	await name_field.clear()
	await name_field.to_have_value("")
	await terms_toggle.check()
	await terms_toggle.to_have_value(true)
	await terms_toggle.uncheck()
	await terms_toggle.to_have_value(false)


func test_drag_and_negative_assertions(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	var form := screen.within(screen.get_by_node_name("FormPanel"))
	var status := form.get_by_node_name("StatusLabel")
	var drag_handle := form.get_by_node_name("DragHandle")
	var drop_zone := form.get_by_node_name("DropZone")
	var transient_notice := form.get_by_node_name("TransientNotice")
	var dismiss_notice := form.get_by_role("button", {"name": "Dismiss Notice"})

	await transient_notice.to_exist()
	await drag_handle.drag_to(drop_zone)
	await status.to_have_text("Dropped")
	await dismiss_notice.click()
	await transient_notice.not_to_exist()


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
		var screenshot_path := screen.get_by_role("button", {"name": "Start"}).capture("start-button.png")
		expect(FileAccess.file_exists(screenshot_path), "Screenshot should exist on disk", screenshot_path)
