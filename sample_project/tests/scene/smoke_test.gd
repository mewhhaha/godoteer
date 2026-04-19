extends "res://addons/godoteer/test_scene.gd"

const SAMPLE_APP := preload("res://scenes/sample_app.tscn")


func test_accessibility_first_queries(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	var form := screen.within(screen.get_by_node_name("FormPanel"))
	var status := form.get_by_node_name("StatusLabel")
	var start_button := form.get_by_role("button", {"name": "Start"})
	var name_field := form.get_by_role("textbox", {"name": "Player Name"})
	var notes_field := form.get_by_role("textbox", {"name": "Notes"})
	var label_field := form.get_by_label_text("Player Name")
	var notes_label_field := form.get_by_label_text("Notes")
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
	await terms_toggle.to_be_unchecked()
	await name_field.not_to_have_value("Mew")
	await start_button.to_have_accessible_name("Start")
	await start_button.to_have_accessible_description("Starts sample flow")
	await name_field.to_have_accessible_name("Player Name")
	await name_field.to_have_accessible_description("Type player name before starting")
	await notes_field.to_have_accessible_name("Notes")
	await notes_field.to_have_accessible_description("Type freeform notes")
	expect(name_field.node() == label_field.node(), "Role and label query should find same input")
	expect(notes_field.node() == notes_label_field.node(), "Notes role and label query should find same input")
	expect(name_field.node() == placeholder_field.node(), "Placeholder query should find same input")
	expect(role_select.value() == "Mage", "Combobox should start at first option")
	screen.expect_accessible_name(start_button, "Start")
	screen.expect_accessible_description(start_button, "Starts sample flow")
	screen.expect_accessible_name(name_field, "Player Name")
	screen.expect_accessible_description(status, "Current sample status")
	screen.screen_reader_supported()
	screen.screen_reader_active()


func test_exact_text_and_accessibility_preserve_edge_whitespace(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	var form := screen.within(screen.get_by_node_name("FormPanel"))
	drain_failures()
	var whitespace_text := form.get_by_text("  Exact Trim\n")
	var whitespace_button := form.get_by_role("button", {"name": "  Space Name  "})

	await whitespace_text.to_have_text("  Exact Trim\n")
	await whitespace_button.to_have_accessible_name("  Space Name  ")
	await whitespace_button.to_have_accessible_description("  Space Desc\n")
	screen.expect_accessible_name(whitespace_button, "  Space Name  ")
	screen.expect_accessible_description(whitespace_button, "  Space Desc\n")

	set_failures_quiet(true)
	var trimmed_text := form.get_by_text("Exact Trim")
	screen.expect_accessible_name(whitespace_button, "Space Name")
	screen.expect_accessible_description(whitespace_button, "Space Desc")
	set_failures_quiet(false)
	var failures := drain_failures()

	expect(trimmed_text == null, "Exact text query should fail for trimmed text")
	expect(failures.size() == 3, "Trimmed exact text and accessibility checks should record three failures", failures)
	expect(str(failures[0]).contains("get_by_text"), "Trimmed exact text failure should mention get_by_text", failures)
	expect(str(failures[1]).contains("Accessible name mismatch"), "Trimmed exact name failure should mention accessible name mismatch", failures)
	expect(str(failures[2]).contains("Accessible description mismatch"), "Trimmed exact description failure should mention accessible description mismatch", failures)

	var fuzzy_text := form.get_by_text("Exact Trim", {"exact": false})
	expect(fuzzy_text != null, "Non-exact text query should still match whitespace-padded text")
	if fuzzy_text != null:
		await fuzzy_text.to_have_text("  Exact Trim\n")


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
	await status.to_have_text("Role: Rogue")
	await name_field.focus()
	await name_field.press(KEY_ENTER)
	await status.to_have_text("Submitted: Mew")
	await screen.move_mouse_between(Vector2(0, 0), Vector2(120, 120), 0.05, 6)
	await start_button.click()

	var started := await screen.find_by_text("Started Mew / Accepted / Rogue")
	expect(started != null, "find_by_text should wait for delayed Started text")
	if started != null:
		await started.to_have_text("Started Mew / Accepted / Rogue")


func test_checkbox_and_clear_actions(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	var form := screen.within(screen.get_by_node_name("FormPanel"))
	var status := form.get_by_node_name("StatusLabel")
	var name_field := form.get_by_role("textbox", {"name": "Player Name"})
	var notes_field := form.get_by_role("textbox", {"name": "Notes"})
	var terms_toggle := form.get_by_role("checkbox", {"name": "Accept Terms"})

	await name_field.fill("Temp")
	await name_field.clear()
	await name_field.to_have_value("")
	await notes_field.fill("Journal")
	await notes_field.to_have_value("Journal")
	await status.to_have_text("Notes: Journal")
	await notes_field.clear()
	await notes_field.to_have_value("")
	await status.to_have_text("Notes: ")
	await terms_toggle.click()
	await terms_toggle.to_have_value(true)
	await terms_toggle.check()
	await terms_toggle.to_have_value(true)
	await terms_toggle.uncheck()
	await terms_toggle.to_have_value(false)
	await terms_toggle.to_be_unchecked()
	await terms_toggle.set_checked(false)
	await terms_toggle.to_be_unchecked()


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


func test_disabled_controls_block_actions(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	var form := screen.within(screen.get_by_node_name("FormPanel"))
	var status := form.get_by_node_name("StatusLabel")
	var start_button := form.get_by_role("button", {"name": "Start"})
	var name_field := form.get_by_role("textbox", {"name": "Player Name"})
	var terms_toggle := form.get_by_role("checkbox", {"name": "Accept Terms"})
	var role_select := form.get_by_role("combobox", {"name": "Role"})
	var disabled_button := form.get_by_node_name("DisabledButton")

	var start_button_node := start_button.node()
	var name_field_node := name_field.node()
	var terms_toggle_node := terms_toggle.node()
	var role_select_node := role_select.node()

	await name_field.focus()
	await status.to_have_text("Focused Name")
	start_button_node.disabled = true
	name_field_node.editable = false
	terms_toggle_node.disabled = true
	role_select_node.disabled = true

	drain_failures()
	set_failures_quiet(true)
	await start_button.click()
	await disabled_button.focus()
	await name_field.fill("Blocked")
	await name_field.press(KEY_ENTER)
	await terms_toggle.check()
	await terms_toggle.uncheck()
	await role_select.select_option("Warrior")
	await disabled_button.hover()
	await name_field.blur()
	set_failures_quiet(false)
	var failures := drain_failures()

	expect(failures.size() == 7, "Disabled/non-editable action attempts should record seven failures", failures)
	expect(str(failures[0]).contains("click() target is disabled"), "Disabled click should explain disabled target", failures)
	expect(str(failures[1]).contains("focus() target is disabled"), "Disabled focus should explain disabled target", failures)
	expect(str(failures[2]).contains("fill() target is not editable"), "Non-editable fill should explain non-editable target", failures)
	expect(str(failures[3]).contains("press() target is not editable"), "Non-editable press should explain non-editable target", failures)
	expect(str(failures[4]).contains("check() target is disabled"), "Disabled check should explain disabled target", failures)
	expect(str(failures[5]).contains("uncheck() target is disabled"), "Disabled uncheck should explain disabled target", failures)
	expect(str(failures[6]).contains("select_option() target is disabled"), "Disabled select should explain disabled target", failures)
	expect(status.text() == "Blurred Name", "Disabled click or press should not change status beyond allowed blur", status.text())
	expect(name_field.value() == "", "Non-editable fill should not change text input value", name_field.value())
	expect(terms_toggle.value() == false, "Disabled checkbox actions should not change checked state", terms_toggle.value())
	expect(role_select.value() == "Mage", "Disabled select should not change current option", role_select.value())


func test_select_option_records_failure_for_missing_option(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	var form := screen.within(screen.get_by_node_name("FormPanel"))
	var role_select := form.get_by_role("combobox", {"name": "Role"})

	drain_failures()
	set_failures_quiet(true)
	await role_select.select_option("Paladin")
	set_failures_quiet(false)
	var failures := drain_failures()

	expect(failures.size() == 1, "Missing option should record one failure", failures)
	expect(str(failures[0]).contains("Option not found for select_option()"), "Missing option failure should explain lookup", failures)
	expect(role_select.value() == "Mage", "Missing option should not change combobox value", role_select.value())


func test_query_returns_null_for_zero_matches(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	drain_failures()
	var missing := screen.query_by_text("Nope")

	expect(missing == null, "query_by_text should return null on zero matches")
	expect(drain_failures().size() == 0, "query_by_text zero matches should not record failure")


func test_get_records_failure_for_zero_matches(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	drain_failures()
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
		var form := screen.within(screen.get_by_node_name("FormPanel"))
		var start_button := form.get_by_role("button", {"name": "Start"})
		var hidden_message := form.get_by_node_name("HiddenMessage")
		var cropped_path := start_button.capture("start-button.png")
		var full_path := screen.screenshot("full-screen.png")
		expect(FileAccess.file_exists(cropped_path), "Cropped screenshot should exist on disk", cropped_path)
		expect(FileAccess.file_exists(full_path), "Full screenshot should exist on disk", full_path)
		if FileAccess.file_exists(cropped_path) and FileAccess.file_exists(full_path):
			var cropped_image := Image.load_from_file(cropped_path)
			var full_image := Image.load_from_file(full_path)
			expect(cropped_image.get_width() < full_image.get_width(), "Locator capture should crop width", cropped_image.get_width(), full_image.get_width())
			expect(cropped_image.get_height() < full_image.get_height(), "Locator capture should crop height", cropped_image.get_height(), full_image.get_height())

		var left_camera_path := await screen.capture_camera("CameraPreviewViewport/CameraWorld/LeftCamera", "camera-left.png")
		var right_camera_path := await screen.capture_camera("CameraPreviewViewport/CameraWorld/RightCamera", "camera-right.png")
		expect(FileAccess.file_exists(left_camera_path), "Left camera screenshot should exist", left_camera_path)
		expect(FileAccess.file_exists(right_camera_path), "Right camera screenshot should exist", right_camera_path)
		if FileAccess.file_exists(left_camera_path) and FileAccess.file_exists(right_camera_path):
			var left_camera_image := Image.load_from_file(left_camera_path)
			var right_camera_image := Image.load_from_file(right_camera_path)
			var center := Vector2i(left_camera_image.get_width() / 2, left_camera_image.get_height() / 2)
			var left_pixel := left_camera_image.get_pixelv(center)
			var right_pixel := right_camera_image.get_pixelv(center)
			expect(left_pixel.r > left_pixel.b, "Left camera should center red marker", left_pixel)
			expect(right_pixel.b > right_pixel.r, "Right camera should center blue marker", right_pixel)

		set_failures_quiet(true)
		var hidden_path := hidden_message.capture("hidden-message.png")
		set_failures_quiet(false)
		var failures := drain_failures()
		expect(hidden_path == "", "Hidden locator capture should fail hard", hidden_path)
		expect(failures.size() == 1, "Hidden locator capture should record one failure", failures)
		expect(str(failures[0]).contains("not visible") or str(failures[0]).contains("invalid crop"), "Hidden locator capture should explain failure", failures)
