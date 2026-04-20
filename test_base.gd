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
		_print_failure_message(message)


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
	var index := 0
	while index < details.size():
		var detail = details[index]
		var label := str(detail)
		if label.ends_with("=") and index + 1 < details.size():
			parts.append("%s %s" % [label, _format_detail(details[index + 1])])
			index += 2
			continue
		parts.append(_format_detail(detail))
		index += 1
	record_failure("Expectation failed: %s" % " ".join(parts))


func _format_detail(detail: Variant) -> String:
	if detail is Array or detail is Dictionary:
		return var_to_str(detail)
	return str(detail)


func _print_failure_message(message: String) -> void:
	var lines := str(message).split("\n", true)
	if lines.is_empty():
		printerr("FAIL:")
		return

	printerr("FAIL: %s" % lines[0])
	for line_index in range(1, lines.size()):
		printerr("      %s" % lines[line_index])
