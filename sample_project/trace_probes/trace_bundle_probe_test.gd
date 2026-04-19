extends "res://addons/godoteer/test_scene.gd"

const SAMPLE_APP := preload("res://scenes/sample_app.tscn")


func test_trace_probe_passes(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	var name_field := screen.get_by_role("textbox", {"name": "Player Name"})
	var start_button := screen.get_by_role("button", {"name": "Start"})

	await name_field.fill("Trace Pass")
	await start_button.click()
	await screen.find_by_text("Started Trace Pass / Pending / Mage")


func test_trace_probe_fails(driver: GodoteerDriver) -> void:
	var screen := await driver.screen(SAMPLE_APP)
	var name_field := screen.get_by_role("textbox", {"name": "Player Name"})
	var status := screen.get_by_text("Idle")
	var start_button := screen.get_by_role("button", {"name": "Start"})

	await name_field.fill("Trace Fail")
	await start_button.click()
	await screen.wait_until_frames(
		func() -> bool:
			return status.text() == "Never Happens",
		5,
		"Intentional trace timeout"
	)
