extends RefCounted
class_name GodoteerRuntimeErrorCollector

const ERROR_PREFIXES := [
	"ERROR:",
	"SCRIPT ERROR:",
]

var log_path := ""
var offset := 0


func _init() -> void:
	log_path = _resolve_log_path()
	offset = _current_length()


func begin_test() -> void:
	if log_path == "":
		log_path = _resolve_log_path()
	offset = _current_length()


func end_test() -> Array[String]:
	if log_path == "":
		log_path = _resolve_log_path()
	if log_path == "":
		return []

	var next_offset := _current_length()
	if next_offset <= offset:
		offset = next_offset
		return []

	var chunk := _read_chunk(offset, next_offset - offset)
	offset = next_offset
	if chunk == "":
		return []

	return _extract_error_blocks(chunk)


func _resolve_log_path() -> String:
	var logs_dir := ProjectSettings.globalize_path("user://logs")
	var current_log := logs_dir.path_join("godot.log")
	if FileAccess.file_exists(current_log):
		return current_log

	var dir := DirAccess.open(logs_dir)
	if dir == null:
		return ""

	var latest_path := ""
	var latest_mtime := 0
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if dir.current_is_dir() or not entry.ends_with(".log"):
			continue

		var absolute_path := logs_dir.path_join(entry)
		var modified_at := int(FileAccess.get_modified_time(absolute_path))
		if modified_at >= latest_mtime:
			latest_mtime = modified_at
			latest_path = absolute_path
	dir.list_dir_end()
	return latest_path


func _current_length() -> int:
	if log_path == "" or not FileAccess.file_exists(log_path):
		return 0

	var file := FileAccess.open(log_path, FileAccess.READ)
	if file == null:
		return 0
	var length := int(file.get_length())
	file.close()
	return length


func _read_chunk(start: int, size: int) -> String:
	var file := FileAccess.open(log_path, FileAccess.READ)
	if file == null:
		return ""
	file.seek(start)
	var text := file.get_buffer(size).get_string_from_utf8()
	file.close()
	return text


func _extract_error_blocks(chunk: String) -> Array[String]:
	var blocks: Array[String] = []
	var lines := chunk.split("\n", true)
	var current_lines: PackedStringArray = []

	for raw_line in lines:
		var line := raw_line.trim_suffix("\r")
		if _is_error_start(line):
			if not current_lines.is_empty():
				blocks.append("\n".join(current_lines))
			current_lines = PackedStringArray([line])
			continue

		if current_lines.is_empty():
			continue

		if _is_error_continuation(line):
			current_lines.append(line)
			continue

		blocks.append("\n".join(current_lines))
		current_lines = PackedStringArray()

	if not current_lines.is_empty():
		blocks.append("\n".join(current_lines))

	return blocks


func _is_error_start(line: String) -> bool:
	for prefix in ERROR_PREFIXES:
		if line.begins_with(prefix):
			return true
	return false


func _is_error_continuation(line: String) -> bool:
	return line == "" or line.begins_with(" ") or line.begins_with("\t")
