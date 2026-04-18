extends SceneTree

const EXIT_OK := 0
const EXIT_FAIL := 1
const EXIT_USAGE := 2
const GodoteerDriver = preload("driver.gd")
const GodoteerTest = preload("test.gd")
const GodoteerSceneTest = preload("test_scene.gd")


func _initialize() -> void:
	call_deferred("_boot")


func _boot() -> void:
	var config := _parse_args(OS.get_cmdline_user_args())
	if config.has("error"):
		_fatal(config["error"], EXIT_USAGE)
		return

	var script: Script = load(config["test"])
	if script == null:
		_fatal("Could not load test: %s" % config["test"], EXIT_FAIL)
		return

	var test_case = script.new()
	if test_case == null:
		_fatal("Could not instantiate test: %s" % config["test"], EXIT_FAIL)
		return

	var driver: GodoteerDriver = null
	var is_scene_test := test_case is GodoteerSceneTest
	var is_unit_test := test_case is GodoteerTest
	if not is_scene_test and not is_unit_test:
		_fatal("Test must extend res://addons/godoteer/test.gd or res://addons/godoteer/test_scene.gd: %s" % config["test"], EXIT_FAIL)
		return

	if is_scene_test:
		driver = GodoteerDriver.new(self, test_case, config["artifacts"])
		test_case.set_meta("godoteer_driver", driver)

	print("GodoteerGD running %s" % config["test"])
	if is_scene_test:
		await _run_scene_test_case(test_case, driver)
	else:
		await _run_unit_test_case(test_case)

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

	if is_scene_test:
		test_case.remove_meta("godoteer_driver")
	test_case = null
	driver = null
	quit(exit_code)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var config := {
		"test": "",
		"artifacts": "user://artifacts",
	}

	var index := 0
	while index < args.size():
		var arg := args[index]
		match arg:
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
	return "Usage: godot --headless --path sample_project -s addons/godoteer/runner.gd -- --test res://tests/scene/smoke_test.gd"


func _fatal(message: String, code: int) -> void:
	printerr("GodoteerGD: %s" % message)
	quit(code)


func _run_unit_test_case(test_case: GodoteerTest) -> void:
	var test_methods := test_case.list_tests()
	if test_methods.is_empty():
		test_case.record_failure("No test methods found. Define methods named test_* in %s" % config_path(test_case))
		return

	for test_name in test_methods:
		print("GodoteerGD test %s" % test_name)
		await test_case.before_each(test_name)
		var test_callable := Callable(test_case, test_name)
		await test_callable.callv([])
		await test_case.after_each(test_name)


func _run_scene_test_case(test_case: GodoteerSceneTest, driver: GodoteerDriver) -> void:
	var test_methods := test_case.list_tests()
	if test_methods.is_empty():
		test_case.record_failure("No test methods found. Define methods named test_* in %s" % config_path(test_case))
		return

	for test_name in test_methods:
		print("GodoteerGD test %s" % test_name)
		await test_case.before_each(driver, test_name)
		var test_callable := Callable(test_case, test_name)
		await test_callable.callv([driver])
		await test_case.after_each(driver, test_name)


func config_path(test_case: Object) -> String:
	return test_case.get_script().resource_path
