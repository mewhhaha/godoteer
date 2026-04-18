extends SceneTree

const EXIT_OK := 0
const EXIT_FAIL := 1
const EXIT_USAGE := 2
const GodoteerDriver = preload("res://addons/godoteer_gd/driver.gd")
const GodoteerTestCase = preload("res://addons/godoteer_gd/test_case.gd")


func _initialize() -> void:
	call_deferred("_boot")


func _boot() -> void:
	var config := _parse_args(OS.get_cmdline_user_args())
	if config.has("error"):
		_fatal(config["error"], EXIT_USAGE)
		return

	var app_root: Node = root
	var owns_scene := false
	if config["scene"] != "":
		var packed_scene: PackedScene = load(config["scene"])
		if packed_scene == null:
			_fatal("Could not load scene: %s" % config["scene"], EXIT_FAIL)
			return

		app_root = packed_scene.instantiate()
		root.add_child(app_root)
		current_scene = app_root
		owns_scene = true
		await process_frame

	var script: Script = load(config["test"])
	if script == null:
		_fatal("Could not load test: %s" % config["test"], EXIT_FAIL)
		return

	var test_case = script.new()
	if test_case == null:
		_fatal("Could not instantiate test: %s" % config["test"], EXIT_FAIL)
		return

	if not test_case is GodoteerTestCase:
		_fatal("Test must extend GodoteerTestCase: %s" % config["test"], EXIT_FAIL)
		return

	var screen := GodoteerDriver.new(self, app_root, test_case, config["artifacts"])
	test_case.bind(screen, app_root)

	print("GodoteerGD running %s" % config["test"])
	await test_case.execute()

	var exit_code := EXIT_OK
	if test_case.has_failures():
		printerr("GodoteerGD FAIL (%d failure%s)" % [
			test_case.failure_count(),
			"" if test_case.failure_count() == 1 else "s",
		])
		printerr(test_case.summary())
		exit_code = EXIT_FAIL
	else:
		print("GodoteerGD PASS %s" % config["test"])

	if owns_scene:
		current_scene = null
		app_root.queue_free()
		await process_frame

	test_case = null
	screen = null
	quit(exit_code)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var config := {
		"scene": "",
		"test": "",
		"artifacts": "user://artifacts",
	}

	var index := 0
	while index < args.size():
		var arg := args[index]
		match arg:
			"--scene":
				index += 1
				if index >= args.size():
					return {"error": "Missing value after --scene"}
				config["scene"] = args[index]
			"--test":
				index += 1
				if index >= args.size():
					return {"error": "Missing value after --test"}
				config["test"] = args[index]
			"--artifacts":
				index += 1
				if index >= args.size():
					return {"error": "Missing value after --artifacts"}
				config["artifacts"] = args[index]
			"--help", "-h":
				return {"error": _usage_text()}
			_:
				return {"error": "Unknown arg: %s\n%s" % [arg, _usage_text()]}

		index += 1

	if config["test"] == "":
		return {"error": "Missing --test\n%s" % _usage_text()}

	return config


func _usage_text() -> String:
	return "Usage: godot --headless --path sample_project -s addons/godoteer_gd/runner.gd -- --scene res://scenes/sample_app.tscn --test res://tests/smoke_test.gd"


func _fatal(message: String, code: int) -> void:
	printerr("GodoteerGD: %s" % message)
	quit(code)
