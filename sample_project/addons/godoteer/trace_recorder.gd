extends RefCounted
class_name GodoteerTraceRecorder

const EVENT_TAIL_COUNT := 20

var artifacts_dir := "user://artifacts"
var suite_path := ""
var test_name := ""
var scene_path := ""
var started_at_msec := 0
var bundle_written := false
var events: Array = []
var linked_artifacts: Array = []


func _init(artifact_root: String, active_suite_path: String, active_test_name: String) -> void:
	artifacts_dir = artifact_root.trim_suffix("/")
	suite_path = active_suite_path
	test_name = active_test_name
	started_at_msec = Time.get_ticks_msec()
	record("test_started", {"message": "Scene test started"})


func set_scene_path(path: String) -> void:
	scene_path = path


func record(kind: String, details: Dictionary = {}) -> void:
	var event := {
		"time_ms": Time.get_ticks_msec() - started_at_msec,
		"kind": kind,
		"suite_path": suite_path,
		"test_name": test_name,
		"scene_path": scene_path,
	}
	for key in details.keys():
		event[key] = _normalize_value(details[key])
	events.append(event)


func record_artifact(file_path: String, artifact_kind: String = "artifact_written", message: String = "") -> void:
	record("artifact_written", {
		"artifact_kind": artifact_kind,
		"file_path": file_path,
		"message": message,
	})
	if artifact_kind == "trace_bundle":
		return
	linked_artifacts.append({
		"artifact_kind": artifact_kind,
		"file_path": file_path,
		"message": message,
	})


func write_failure_bundle(failures: Array[String]) -> Dictionary:
	if bundle_written:
		return {"trace_path": "", "summary_path": ""}

	bundle_written = true
	var base_path := _bundle_base_path()
	var trace_path := ProjectSettings.globalize_path(base_path.path_join("trace.jsonl"))
	var summary_path := ProjectSettings.globalize_path(base_path.path_join("summary.txt"))
	var absolute_dir := trace_path.get_base_dir()
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK:
		return {"error": "Could not create trace dir: %s" % absolute_dir}

	record_artifact(trace_path, "trace_bundle", "Failure trace JSONL")
	record_artifact(summary_path, "trace_bundle", "Failure trace summary")

	var trace_lines: PackedStringArray = []
	for event in events:
		trace_lines.append(JSON.stringify(event))
	if not _write_text_file(trace_path, "\n".join(trace_lines) + "\n"):
		return {"error": "Could not write failure trace: %s" % trace_path}

	var summary_lines: PackedStringArray = []
	summary_lines.append("Suite: %s" % suite_path)
	summary_lines.append("Test: %s" % test_name)
	summary_lines.append("Scene: %s" % scene_path)
	summary_lines.append("First failure: %s" % (failures[0] if not failures.is_empty() else ""))
	summary_lines.append("")
	summary_lines.append("Recent events:")
	for event in _tail_events():
		summary_lines.append("- [%sms] %s %s" % [
			int(event.get("time_ms", 0)),
			str(event.get("kind", "")),
			_summary_message(event),
		])
	if not linked_artifacts.is_empty():
		summary_lines.append("")
		summary_lines.append("Artifacts:")
		for artifact in linked_artifacts:
			summary_lines.append("- %s (%s)" % [
				str(artifact.get("file_path", "")),
				str(artifact.get("artifact_kind", "")),
			])
	if not _write_text_file(summary_path, "\n".join(summary_lines) + "\n"):
		return {"error": "Could not write failure trace summary: %s" % summary_path}

	return {
		"trace_path": trace_path,
		"summary_path": summary_path,
	}


func _write_text_file(path: String, contents: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(contents)
	file.close()
	return true


func _tail_events() -> Array:
	if events.size() <= EVENT_TAIL_COUNT:
		return events
	return events.slice(events.size() - EVENT_TAIL_COUNT, events.size())


func _summary_message(event: Dictionary) -> String:
	if str(event.get("message", "")) != "":
		return str(event.get("message", ""))
	if str(event.get("query_label", "")) != "":
		return str(event.get("query_label", ""))
	if str(event.get("action_name", "")) != "":
		return str(event.get("action_name", ""))
	if str(event.get("artifact_kind", "")) != "":
		return "%s %s" % [str(event.get("artifact_kind", "")), str(event.get("file_path", ""))]
	return ""


func _normalize_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_ARRAY:
			var items: Array = []
			for item in value:
				items.append(_normalize_value(item))
			return items
		TYPE_DICTIONARY:
			var dict := {}
			for key in value.keys():
				dict[str(key)] = _normalize_value(value[key])
			return dict
		_:
			return str(value)


func _bundle_base_path() -> String:
	return artifacts_dir.path_join("traces").path_join(_sanitize_path(suite_path)).path_join(_sanitize_segment(test_name))


func _sanitize_path(path: String) -> String:
	var trimmed := path
	if trimmed.begins_with("res://"):
		trimmed = trimmed.trim_prefix("res://")
	trimmed = trimmed.trim_suffix(".gd")
	var parts := trimmed.split("/", false)
	for index in range(parts.size()):
		parts[index] = _sanitize_segment(parts[index])
	return "/".join(parts)


func _sanitize_segment(value: String) -> String:
	var sanitized := value.strip_edges()
	for char in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", " "]:
		sanitized = sanitized.replace(char, "_")
	while sanitized.contains("__"):
		sanitized = sanitized.replace("__", "_")
	while sanitized.begins_with("_"):
		sanitized = sanitized.substr(1)
	while sanitized.ends_with("_"):
		sanitized = sanitized.left(sanitized.length() - 1)
	return sanitized
