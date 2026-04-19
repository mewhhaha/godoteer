extends SceneTree

const EXIT_OK := 0
const EXIT_FAIL := 1
const EXIT_USAGE := 2
const RUNNER_FAILURE_SUITE := "<runner>"
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
var junit_suites: Array = []
var matched_test_count := 0


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

	if str(config["grep"]) == "":
		run_stats["suites_total"] = suite_paths.size()
	else:
		run_stats["suites_total"] = _count_runnable_suites(suite_paths, str(config["grep"]))
	print("GodoteerGD start %d %s" % [int(run_stats["suites_total"]), _pluralize("suite", "suites", int(run_stats["suites_total"]))])

	var had_failures := false
	for suite_path in suite_paths:
		var suite_failed: bool = await _run_suite(suite_path, config)
		had_failures = had_failures or suite_failed

	if str(config["grep"]) != "" and matched_test_count == 0:
		had_failures = true
		run_stats["failure_messages"] += 1
		var no_match_message := "No tests matched --grep: %s" % str(config["grep"])
		_record_suite_failure(RUNNER_FAILURE_SUITE, "<load>", no_match_message)
		_append_junit_load_failure(RUNNER_FAILURE_SUITE, "runner", no_match_message, 0)

	var junit_path := ""
	if str(config["junit"]) != "":
		junit_path = _write_junit_report(str(config["junit"]))
		if junit_path == "":
			had_failures = true

	if had_failures:
		run_stats["suites_failed"] = _failed_executed_suite_count()
		printerr("GodoteerGD FAIL %s" % _run_summary())
		if junit_path != "":
			printerr("GodoteerGD JUnit %s" % junit_path)
		_print_grouped_failures()
		quit(EXIT_FAIL)
		return

	print("GodoteerGD PASS %s" % _run_summary())
	if junit_path != "":
		print("GodoteerGD JUnit %s" % junit_path)
	quit(EXIT_OK)


func _run_suite(suite_path: String, config: Dictionary) -> bool:
	var suite_started_at_msec: int = Time.get_ticks_msec()
	var script: Script = load(suite_path)
	if script == null:
		var load_message := "Could not load test: %s" % suite_path
		run_stats["failure_messages"] += 1
		_record_suite_failure(suite_path, "<load>", load_message)
		_append_junit_load_failure(suite_path, "load", load_message, Time.get_ticks_msec() - suite_started_at_msec)
		_print_suite_result(suite_path, "<load>", true, 0, Time.get_ticks_msec() - suite_started_at_msec)
		return true

	var test_case = script.new()
	if test_case == null:
		var instantiate_message := "Could not instantiate test: %s" % suite_path
		run_stats["failure_messages"] += 1
		_record_suite_failure(suite_path, "<load>", instantiate_message)
		_append_junit_load_failure(suite_path, "load", instantiate_message, Time.get_ticks_msec() - suite_started_at_msec)
		_print_suite_result(suite_path, "<load>", true, 0, Time.get_ticks_msec() - suite_started_at_msec)
		return true

	var driver: GodoteerDriver = null
	var is_scene_test := test_case is GodoteerSceneTest
	var is_unit_test := test_case is GodoteerTest
	if not is_scene_test and not is_unit_test:
		var extends_message := "Test must extend res://addons/godoteer/test.gd or res://addons/godoteer/test_scene.gd: %s" % suite_path
		run_stats["failure_messages"] += 1
		_record_suite_failure(suite_path, "<load>", extends_message)
		_append_junit_load_failure(suite_path, "load", extends_message, Time.get_ticks_msec() - suite_started_at_msec)
		_print_suite_result(suite_path, "<load>", true, 0, Time.get_ticks_msec() - suite_started_at_msec)
		return true

	if is_scene_test:
		driver = GodoteerDriver.new(self, test_case, config["artifacts"])
		test_case.set_meta("godoteer_driver", driver)

	var all_test_methods: PackedStringArray = test_case.list_tests()
	if all_test_methods.is_empty():
		var no_tests_message := "No test methods found. Define methods named test_* in %s" % suite_path
		run_stats["failure_messages"] += 1
		_record_suite_failure(suite_path, "<load>", no_tests_message)
		_append_junit_load_failure(suite_path, "scene" if is_scene_test else "unit", no_tests_message, Time.get_ticks_msec() - suite_started_at_msec)
		_print_suite_result(suite_path, "scene" if is_scene_test else "unit", true, 0, Time.get_ticks_msec() - suite_started_at_msec)
		if is_scene_test:
			test_case.remove_meta("godoteer_driver")
		return true

	var test_methods: PackedStringArray = _filter_test_methods(all_test_methods, suite_path, str(config["grep"]))
	if test_methods.is_empty():
		if is_scene_test:
			test_case.remove_meta("godoteer_driver")
		return false

	matched_test_count += test_methods.size()
	var suite_kind := "scene" if is_scene_test else "unit"
	var suite_record := {
		"name": suite_path,
		"kind": suite_kind,
		"time_sec": 0.0,
		"testcases": [],
	}

	print("GodoteerGD suite %s [%s]" % [suite_path, suite_kind])
	if is_scene_test:
		await _run_scene_test_case(test_case, driver, suite_path, test_methods, suite_record)
	else:
		await _run_unit_test_case(test_case, suite_path, test_methods, suite_record)

	var suite_failed: bool = test_case.has_failures()
	var suite_duration_msec: int = Time.get_ticks_msec() - suite_started_at_msec
	suite_record["time_sec"] = float(suite_duration_msec) / 1000.0
	junit_suites.append(suite_record)
	_print_suite_result(suite_path, suite_kind, suite_failed, test_methods.size(), suite_duration_msec)
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
		"grep": "",
		"junit": "",
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
			"--grep":
				index += 1
				if index >= args.size():
					return {"error": "Missing value after --grep"}
				config["grep"] = args[index]
			"--junit":
				index += 1
				if index >= args.size():
					return {"error": "Missing value after --junit"}
				config["junit"] = args[index]
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
	return "Usage: godot --headless --path sample_project -s addons/godoteer/runner.gd -- --test res://tests/scene/smoke_test.gd [--grep text] [--junit user://artifacts/results.xml]\n   or: godot --headless --path sample_project -s addons/godoteer/runner.gd -- --dir res://tests [--grep text] [--junit user://artifacts/results.xml]"


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


func _run_unit_test_case(test_case: GodoteerTest, suite_path: String, test_methods: PackedStringArray, suite_record: Dictionary) -> void:
	for test_name in test_methods:
		var test_started_at_msec: int = Time.get_ticks_msec()
		var failure_count_before := test_case.failure_count()
		await test_case.before_each(test_name)
		var test_callable := Callable(test_case, test_name)
		await test_callable.callv([])
		await test_case.after_each(test_name)
		var new_failures: Array[String] = _capture_new_failures(test_case, suite_path, test_name, failure_count_before)
		var duration_msec: int = Time.get_ticks_msec() - test_started_at_msec
		_append_junit_testcase(suite_record, test_name, duration_msec, new_failures)
		_print_test_result(test_name, new_failures.size() > 0, new_failures.size(), duration_msec)


func _run_scene_test_case(test_case: GodoteerSceneTest, driver: GodoteerDriver, suite_path: String, test_methods: PackedStringArray, suite_record: Dictionary) -> void:
	for test_name in test_methods:
		var test_started_at_msec: int = Time.get_ticks_msec()
		var failure_count_before := test_case.failure_count()
		await test_case.before_each(driver, test_name)
		var test_callable := Callable(test_case, test_name)
		await test_callable.callv([driver])
		await test_case.after_each(driver, test_name)
		var new_failures: Array[String] = _capture_new_failures(test_case, suite_path, test_name, failure_count_before)
		var duration_msec: int = Time.get_ticks_msec() - test_started_at_msec
		_append_junit_testcase(suite_record, test_name, duration_msec, new_failures)
		_print_test_result(test_name, new_failures.size() > 0, new_failures.size(), duration_msec)


func _capture_new_failures(test_case: Object, suite_path: String, test_name: String, start_index: int) -> Array[String]:
	run_stats["tests_total"] += 1
	if test_case.failure_count() <= start_index:
		return []

	var new_failures: Array[String] = []
	run_stats["tests_failed"] += 1
	for failure_index in range(start_index, test_case.failure_count()):
		var message := str(test_case.failures[failure_index])
		new_failures.append(message)
		_record_suite_failure(suite_path, test_name, message)
	run_stats["failure_messages"] += new_failures.size()
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


func _count_runnable_suites(suite_paths: PackedStringArray, grep_text: String) -> int:
	if grep_text == "":
		return 0

	var total := 0
	for suite_path in suite_paths:
		if _is_runnable_suite(suite_path, grep_text):
			total += 1
	return total


func _is_runnable_suite(suite_path: String, grep_text: String) -> bool:
	var script: Script = load(suite_path)
	if script == null:
		return true

	var test_case = script.new()
	if test_case == null:
		return true

	var is_scene_test := test_case is GodoteerSceneTest
	var is_unit_test := test_case is GodoteerTest
	if not is_scene_test and not is_unit_test:
		return true

	var all_test_methods: PackedStringArray = test_case.list_tests()
	if all_test_methods.is_empty():
		return true

	return not _filter_test_methods(all_test_methods, suite_path, grep_text).is_empty()


func _filter_test_methods(test_methods: PackedStringArray, suite_path: String, grep_text: String) -> PackedStringArray:
	if grep_text == "":
		return test_methods

	var filtered: PackedStringArray = []
	var wanted := grep_text.to_lower()
	var suite_matches := suite_path.to_lower().contains(wanted)
	for test_name in test_methods:
		if suite_matches or test_name.to_lower().contains(wanted):
			filtered.append(test_name)
	return filtered


func _append_junit_testcase(suite_record: Dictionary, test_name: String, duration_msec: int, failures: Array[String]) -> void:
	var testcases: Array = suite_record.get("testcases", [])
	testcases.append({
		"name": test_name,
		"time_sec": float(duration_msec) / 1000.0,
		"failures": failures,
	})
	suite_record["testcases"] = testcases


func _append_junit_load_failure(suite_path: String, suite_kind: String, message: String, duration_msec: int) -> void:
	junit_suites.append({
		"name": suite_path,
		"kind": suite_kind,
		"time_sec": float(duration_msec) / 1000.0,
		"testcases": [{
			"name": "<load>",
			"time_sec": float(duration_msec) / 1000.0,
			"failures": [message],
		}],
	})


func _write_junit_report(report_path: String) -> String:
	var absolute_path := ProjectSettings.globalize_path(report_path)
	var absolute_dir := absolute_path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK:
		run_stats["failure_messages"] += 1
		_record_suite_failure(RUNNER_FAILURE_SUITE, "<load>", "Could not create JUnit dir: %s" % absolute_dir)
		return ""

	var lines: PackedStringArray = []
	lines.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
	lines.append("<testsuites tests=\"%d\" failures=\"%d\">" % [_junit_test_count(), _junit_failure_count()])
	for suite_record in junit_suites:
		var testcases: Array = suite_record.get("testcases", [])
		lines.append("\t<testsuite name=\"%s\" tests=\"%d\" failures=\"%d\" time=\"%.3f\">" % [
			_xml_escape(str(suite_record.get("name", ""))),
			testcases.size(),
			_junit_failure_count_for_cases(testcases),
			float(suite_record.get("time_sec", 0.0)),
		])
		for testcase in testcases:
			lines.append("\t\t<testcase name=\"%s\" classname=\"%s\" time=\"%.3f\">" % [
				_xml_escape(str(testcase.get("name", ""))),
				_xml_escape(str(suite_record.get("name", ""))),
				float(testcase.get("time_sec", 0.0)),
			])
			for failure in testcase.get("failures", []):
				var text := _xml_escape(str(failure))
				lines.append("\t\t\t<failure message=\"%s\">%s</failure>" % [text, text])
			lines.append("\t\t</testcase>")
		lines.append("\t</testsuite>")
	lines.append("</testsuites>")

	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	if file == null:
		run_stats["failure_messages"] += 1
		_record_suite_failure(RUNNER_FAILURE_SUITE, "<load>", "Could not open JUnit report for writing: %s" % report_path)
		return ""

	file.store_string("\n".join(lines) + "\n")
	file.close()
	return absolute_path


func _junit_test_count() -> int:
	var total := 0
	for suite_record in junit_suites:
		total += suite_record.get("testcases", []).size()
	return total


func _junit_failure_count() -> int:
	var total := 0
	for suite_record in junit_suites:
		total += _junit_failure_count_for_cases(suite_record.get("testcases", []))
	return total


func _junit_failure_count_for_cases(testcases: Array) -> int:
	var total := 0
	for testcase in testcases:
		total += testcase.get("failures", []).size()
	return total


func _failed_executed_suite_count() -> int:
	var total := 0
	for suite_path in suite_failures.keys():
		if str(suite_path) == RUNNER_FAILURE_SUITE:
			continue
		total += 1
	return total


func _xml_escape(value: String) -> String:
	return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&apos;")
