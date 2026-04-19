extends SceneTree

const EXIT_OK := 0
const EXIT_FAIL := 1
const EXIT_USAGE := 2
const GodoteerDriver = preload("driver.gd")
const GodoteerTest = preload("test.gd")
const GodoteerSceneTest = preload("test_scene.gd")

var suite_failures: Dictionary = {}


func _initialize() -> void:
	call_deferred("_boot")


func _boot() -> void:
	var config := _parse_args(OS.get_cmdline_user_args())
	if config.has("error"):
		_fatal(config["error"], EXIT_USAGE)
		return

	var suite_paths := _collect_suite_paths(config)
	if suite_paths.is_empty():
		_fatal("No test files found\n%s" % _usage_text(), EXIT_FAIL)
		return

	var had_failures := false
	for suite_path in suite_paths:
		var suite_failed: bool = await _run_suite(suite_path, config)
		had_failures = had_failures or suite_failed

	if had_failures:
		printerr("GodoteerGD FAIL")
		_print_grouped_failures()
		quit(EXIT_FAIL)
		return

	print("GodoteerGD PASS %d suite%s" % [suite_paths.size(), "" if suite_paths.size() == 1 else "s"])
	quit(EXIT_OK)


func _run_suite(suite_path: String, config: Dictionary) -> bool:
	var script: Script = load(suite_path)
	if script == null:
		_record_suite_failure(suite_path, "<load>", "Could not load test: %s" % suite_path)
		return true

	var test_case = script.new()
	if test_case == null:
		_record_suite_failure(suite_path, "<load>", "Could not instantiate test: %s" % suite_path)
		return true

	var driver: GodoteerDriver = null
	var is_scene_test := test_case is GodoteerSceneTest
	var is_unit_test := test_case is GodoteerTest
	if not is_scene_test and not is_unit_test:
		_record_suite_failure(suite_path, "<load>", "Test must extend res://addons/godoteer/test.gd or res://addons/godoteer/test_scene.gd: %s" % suite_path)
		return true

	if is_scene_test:
		driver = GodoteerDriver.new(self, test_case, config["artifacts"])
		test_case.set_meta("godoteer_driver", driver)

	print("GodoteerGD running %s" % suite_path)
	if is_scene_test:
		await _run_scene_test_case(test_case, driver, suite_path)
	else:
		await _run_unit_test_case(test_case, suite_path)

	var suite_failed: bool = test_case.has_failures()
	if is_scene_test:
		test_case.remove_meta("godoteer_driver")
	test_case = null
	driver = null
	return suite_failed


func _parse_args(args: PackedStringArray) -> Dictionary:
	var config := {
		"test": "",
		"dir": "",
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
			"--dir":
				index += 1
				if index >= args.size():
					return {"error": "Missing value after --dir"}
				config["dir"] = args[index]
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

	if config["test"] != "" and config["dir"] != "":
		return {"error": "Use either --test or --dir, not both\n%s" % _usage_text()}
	if config["test"] == "" and config["dir"] == "":
		return {"error": "Missing --test or --dir\n%s" % _usage_text()}

	return config


func _usage_text() -> String:
	return "Usage: godot --headless --path sample_project -s addons/godoteer/runner.gd -- --test res://tests/scene/smoke_test.gd\n   or: godot --headless --path sample_project -s addons/godoteer/runner.gd -- --dir res://tests"


func _fatal(message: String, code: int) -> void:
	printerr("GodoteerGD: %s" % message)
	quit(code)


func _collect_suite_paths(config: Dictionary) -> PackedStringArray:
	var suite_paths: PackedStringArray = []
	if config["test"] != "":
		suite_paths.append(config["test"])
		return suite_paths

	var absolute_dir := ProjectSettings.globalize_path(str(config["dir"]))
	_walk_suite_dir(absolute_dir, str(config["dir"]).trim_suffix("/"), suite_paths)
	suite_paths.sort()
	return suite_paths


func _walk_suite_dir(absolute_dir: String, res_dir: String, suite_paths: PackedStringArray) -> void:
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry.begins_with("."):
			continue

		var absolute_path := absolute_dir.path_join(entry)
		var res_path := res_dir.path_join(entry)
		if dir.current_is_dir():
			_walk_suite_dir(absolute_path, res_path, suite_paths)
		elif entry.ends_with(".gd"):
			suite_paths.append(res_path)
	dir.list_dir_end()


func _run_unit_test_case(test_case: GodoteerTest, suite_path: String) -> void:
	var test_methods := test_case.list_tests()
	if test_methods.is_empty():
		_record_suite_failure(suite_path, "<load>", "No test methods found. Define methods named test_* in %s" % suite_path)
		return

	for test_name in test_methods:
		print("GodoteerGD test %s" % test_name)
		var failure_count_before := test_case.failure_count()
		await test_case.before_each(test_name)
		var test_callable := Callable(test_case, test_name)
		await test_callable.callv([])
		await test_case.after_each(test_name)
		_capture_new_failures(test_case, suite_path, test_name, failure_count_before)


func _run_scene_test_case(test_case: GodoteerSceneTest, driver: GodoteerDriver, suite_path: String) -> void:
	var test_methods := test_case.list_tests()
	if test_methods.is_empty():
		_record_suite_failure(suite_path, "<load>", "No test methods found. Define methods named test_* in %s" % suite_path)
		return

	for test_name in test_methods:
		print("GodoteerGD test %s" % test_name)
		var failure_count_before := test_case.failure_count()
		await test_case.before_each(driver, test_name)
		var test_callable := Callable(test_case, test_name)
		await test_callable.callv([driver])
		await test_case.after_each(driver, test_name)
		_capture_new_failures(test_case, suite_path, test_name, failure_count_before)


func _capture_new_failures(test_case: Object, suite_path: String, test_name: String, start_index: int) -> void:
	if test_case.failure_count() <= start_index:
		return

	for failure_index in range(start_index, test_case.failure_count()):
		_record_suite_failure(suite_path, test_name, test_case.failures[failure_index])


func _record_suite_failure(suite_path: String, test_name: String, message: String) -> void:
	if not suite_failures.has(suite_path):
		suite_failures[suite_path] = {}
	var suite_entry: Dictionary = suite_failures[suite_path]
	if not suite_entry.has(test_name):
		suite_entry[test_name] = []
	var test_failures: Array = suite_entry[test_name]
	test_failures.append(message)
	suite_entry[test_name] = test_failures
	suite_failures[suite_path] = suite_entry


func _print_grouped_failures() -> void:
	var suite_paths := suite_failures.keys()
	suite_paths.sort()
	for suite_path in suite_paths:
		printerr("[%s]" % suite_path)
		var suite_entry: Dictionary = suite_failures[suite_path]
		var test_names := suite_entry.keys()
		test_names.sort()
		for test_name in test_names:
			printerr("  %s" % test_name)
			for message in suite_entry[test_name]:
				printerr("    %s" % str(message))
