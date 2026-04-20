extends "res://addons/godoteer/test.gd"


func test_reports_push_error_blocks() -> void:
	push_error("Godoteer runtime error probe")
	expect(true, "probe body should keep running")
