extends RefCounted
class_name GodoteerBaseTest

var failures: Array[String] = []
var quiet_failures := false


func list_tests() -> PackedStringArray:
	var names: PackedStringArray = []
	for method_info in get_method_list():
		var method_name := str(method_info.get("name", ""))
		if method_name.begins_with("test_"):
			names.append(method_name)

	names.sort()
	return names


func record_failure(message: String) -> void:
	failures.append(message)
	if not quiet_failures:
		printerr("FAIL: %s" % message)


func has_failures() -> bool:
	return failures.size() > 0


func failure_count() -> int:
	return failures.size()


func summary() -> String:
	return "\n".join(failures)


func drain_failures() -> Array[String]:
	var drained := failures.duplicate()
	failures.clear()
	return drained


func set_failures_quiet(enabled: bool) -> void:
	quiet_failures = enabled


func fail(message: String) -> void:
	record_failure(message)


func expect(condition: bool, ...details) -> void:
	if condition:
		return

	if details.is_empty():
		record_failure("Expectation failed")
		return

	var parts: Array[String] = []
	for detail in details:
		parts.append(str(detail))
	record_failure("Expectation failed: %s" % " ".join(parts))
