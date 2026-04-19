extends SceneTree

const EXIT_OK := 0
const EXIT_FAIL := 1
const EXIT_USAGE := 2
const GodoteerDriver = preload("driver.gd")
const GodoteerTest = preload("test.gd")
const GodoteerSceneTest = preload("test_scene.gd")

var suite_failures: Dictionary = {}
var run_stats := {
	"suites_total": 0,
	"suites_failed": 0,
	"tests_total": 0,
	"tests_failed": 0,
	"failure_messages": 0,
}
var run_started_at_msec := 0


func _initialize() -> void:
	call_deferred("_boot")


func _boot() -> void:
	run_started_at_msec = Time.get_ticks_msec()
	var config := _parse_args(OS.get_cmdline_user_args())
	if config.has("error"):
		_fatal(config["error"], EXIT_USAGE)
		return

	var suite_paths := _collect_suite_paths(config)
	if suite_paths.is_empty():
		_fatal("No test files found\n%s" % _usage_text(), EXIT_FAIL)
		return

	run_stats["suites_total"] = suite_paths.size()
	print("GodoteerGD start %d %s" % [suite_paths.size(), _pluralize("suite", "suites", suite_paths.size())])

	var had_failures := false
	for suite_path in suite_paths:
		var suite_failed: bool = await _run_suite(suite_path, config)
		had_failures = had_failures or suite_failed

	if had_failures:
		run_stats["suites_failed"] = suite_failures.size()
		printerr("GodoteerGD FAIL %s" % _run_summary())
		_print_grouped_failures()
		quit(EXIT_FAIL)
		return

	print("GodoteerGD PASS %s" % _run_summary())
	quit(EXIT_OK)


func _run_suite(suite_path: String, config: Dictionary) -> bool:
	var suite_started_at_msec := Time.get_ticks_msec()
	var script: Script = load(suite_path)
	if script == null:
		run_stats["failure_messages"] += 1
		_record_suite_failure(suite_path, "<load>", "Could not load test: %s" % suite_path)
		_print_suite_result(suite_path, "<load>", true, 0, Time.get_ticks_msec() - suite_started_at_msec)
		return true

	var test_case = script.new()
	if test_case == null:
		run_stats["failure_messages"] += 1
		_record_suite_failure(suite_path, "<load>", "Could not instantiate test: %s" % suite_path)
		_print_suite_result(suite_path, "<load>", true, 0, Time.get_ticks_msec() - suite_started_at_msec)
		return true

	var driver: GodoteerDriver = null
	var is_scene_test := test_case is GodoteerSceneTest
	var is_unit_test := test_case is GodoteerTest
	if not is_scene_test and not is_unit_test:
		run_stats["failure_messages"] += 1
		_record_suite_failure(suite_path, "<load>", "Test must extend res://addons/godoteer/test.gd or res://addons/godoteer/test_scene.gd: %s" % suite_path)
		_print_suite_result(suite_path, "<load>", true, 0, Time.get_ticks_msec() - suite_started_at_msec)
		return true

	if is_scene_test:
		driver = GodoteerDriver.new(self, test_case, config["artifacts"])
		test_case.set_meta("godoteer_driver", driver)

	print("GodoteerGD suite %s [%s]" % [suite_path, "scene" if is_scene_test else "unit"])
	if is_scene_test:
		await _run_scene_test_case(test_case, driver, suite_path)
	else:
		await _run_unit_test_case(test_case, suite_path)

	var suite_failed: bool = test_case.has_failures()
	var suite_duration_msec: int = Time.get_ticks_msec() - suite_started_at_msec
	var suite_test_count: int = test_case.list_tests().size()
	_print_suite_result(suite_path, "scene" if is_scene_test else "unit", suite_failed, suite_test_count, suite_duration_msec)
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
		run_stats["failure_messages"] += 1
		_record_suite_failure(suite_path, "<load>", "No test methods found. Define methods named test_* in %s" % suite_path)
		return

	for test_name in test_methods:
		var test_started_at_msec: int = Time.get_ticks_msec()
		var failure_count_before := test_case.failure_count()
		await test_case.before_each(test_name)
		var test_callable := Callable(test_case, test_name)
		await test_callable.callv([])
		await test_case.after_each(test_name)
		var new_failures: int = _capture_new_failures(test_case, suite_path, test_name, failure_count_before)
		_print_test_result(test_name, new_failures > 0, new_failures, Time.get_ticks_msec() - test_started_at_msec)


func _run_scene_test_case(test_case: GodoteerSceneTest, driver: GodoteerDriver, suite_path: String) -> void:
	var test_methods := test_case.list_tests()
	if test_methods.is_empty():
		run_stats["failure_messages"] += 1
		_record_suite_failure(suite_path, "<load>", "No test methods found. Define methods named test_* in %s" % suite_path)
		return

	for test_name in test_methods:
		var test_started_at_msec: int = Time.get_ticks_msec()
		var failure_count_before := test_case.failure_count()
		await test_case.before_each(driver, test_name)
		var test_callable := Callable(test_case, test_name)
		await test_callable.callv([driver])
		await test_case.after_each(driver, test_name)
		var new_failures: int = _capture_new_failures(test_case, suite_path, test_name, failure_count_before)
		_print_test_result(test_name, new_failures > 0, new_failures, Time.get_ticks_msec() - test_started_at_msec)


func _capture_new_failures(test_case: Object, suite_path: String, test_name: String, start_index: int) -> int:
	run_stats["tests_total"] += 1
	if test_case.failure_count() <= start_index:
		return 0

	var new_failures: int = test_case.failure_count() - start_index
	run_stats["tests_failed"] += 1
	run_stats["failure_messages"] += new_failures
	for failure_index in range(start_index, test_case.failure_count()):
		_record_suite_failure(suite_path, test_name, test_case.failures[failure_index])
	return new_failures


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


func _print_test_result(test_name: String, failed: bool, failure_count: int, duration_msec: int) -> void:
	if failed:
		printerr("  FAIL %s (%s, %s)" % [test_name, _pluralize("failure", "failures", failure_count, true), _format_duration(duration_msec)])
		return

	print("  PASS %s (%s)" % [test_name, _format_duration(duration_msec)])


func _print_suite_result(suite_path: String, suite_kind: String, failed: bool, test_count: int, duration_msec: int) -> void:
	var status := "FAIL" if failed else "PASS"
	var line := "GodoteerGD %s suite %s [%s] (%d %s, %s)" % [
		status,
		suite_path,
		suite_kind,
		test_count,
		_pluralize("test", "tests", test_count),
		_format_duration(duration_msec),
	]
	if failed:
		printerr(line)
		return
	print(line)


func _run_summary() -> String:
	return "%d %s, %d failed %s, %d %s, %d failed %s, %d %s in %s" % [
		int(run_stats["suites_total"]),
		_pluralize("suite", "suites", int(run_stats["suites_total"])),
		int(run_stats["suites_failed"]),
		_pluralize("suite", "suites", int(run_stats["suites_failed"])),
		int(run_stats["tests_total"]),
		_pluralize("test", "tests", int(run_stats["tests_total"])),
		int(run_stats["tests_failed"]),
		_pluralize("test", "tests", int(run_stats["tests_failed"])),
		int(run_stats["failure_messages"]),
		_pluralize("failure", "failures", int(run_stats["failure_messages"])),
		_format_duration(Time.get_ticks_msec() - run_started_at_msec),
	]


func _pluralize(singular: String, plural: String, count: int, include_count: bool = false) -> String:
	var value := singular if count == 1 else plural
	if include_count:
		return "%d %s" % [count, value]
	return value


func _format_duration(duration_msec: int) -> String:
	if duration_msec < 1000:
		return "%dms" % duration_msec
	return "%.2fs" % (float(duration_msec) / 1000.0)
