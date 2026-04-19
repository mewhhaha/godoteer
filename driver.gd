extends RefCounted
class_name GodoteerDriver

const GodoteerScreen = preload("screen.gd")
const GodoteerTraceRecorder = preload("trace_recorder.gd")

var tree: SceneTree
var failure_sink: Object
var artifacts_dir := "user://artifacts"
var active_suite_path := ""
var active_test_name := ""
var update_snapshots := false
var current_screen: GodoteerScreen
var current_app_root: Node
var trace_recorder: GodoteerTraceRecorder


func _init(
	scene_tree: SceneTree,
	sink: Object,
	artifacts_path: String = "user://artifacts",
	suite_path: String = "",
	should_update_snapshots: bool = false
) -> void:
	tree = scene_tree
	failure_sink = sink
	artifacts_dir = artifacts_path.trim_suffix("/")
	active_suite_path = suite_path
	update_snapshots = should_update_snapshots


func set_active_test(test_name: String) -> void:
	active_test_name = test_name
	trace_recorder = GodoteerTraceRecorder.new(artifacts_dir, active_suite_path, active_test_name)


func screen(scene_ref: Variant) -> GodoteerScreen:
	await close_screen()

	var packed_scene := _resolve_scene(scene_ref)
	if packed_scene == null:
		_record_failure("Could not resolve scene: %s" % str(scene_ref))
		return null

	current_app_root = packed_scene.instantiate()
	tree.root.add_child(current_app_root)
	tree.current_scene = current_app_root
	await tree.process_frame
	var scene_path := _scene_path(scene_ref, packed_scene)
	if trace_recorder != null:
		trace_recorder.set_scene_path(scene_path)
		trace_recorder.record("scene_opened", {
			"message": "Opened scene %s" % scene_path,
		})

	current_screen = GodoteerScreen.new(
		tree,
		current_app_root,
		failure_sink,
		artifacts_dir,
		active_suite_path,
		active_test_name,
		update_snapshots,
		trace_recorder
	)
	return current_screen


func close_screen() -> void:
	if current_screen != null:
		if trace_recorder != null:
			trace_recorder.record("scene_closing", {
				"message": "Closing active scene",
			})
		current_screen.release_all_inputs()
	_restore_runtime_state()
	current_screen = null

	if current_app_root == null:
		_restore_runtime_state()
		return

	if tree.current_scene == current_app_root:
		tree.current_scene = null

	current_app_root.queue_free()
	current_app_root = null
	await tree.process_frame
	if trace_recorder != null:
		trace_recorder.record("scene_closed", {
			"message": "Closed active scene",
		})


func reset() -> void:
	if trace_recorder != null:
		trace_recorder.record("scene_reset", {
			"message": "Driver reset",
		})
	await close_screen()


func _resolve_scene(scene_ref: Variant) -> PackedScene:
	if scene_ref is PackedScene:
		return scene_ref

	var path := str(scene_ref)
	if path == "":
		return null

	var loaded = load(path)
	if loaded is PackedScene:
		return loaded

	return null


func write_failure_trace_bundle(failures: Array[String]) -> Dictionary:
	if trace_recorder == null:
		return {"trace_path": "", "summary_path": ""}
	return trace_recorder.write_failure_bundle(failures)


func trace_event(kind: String, details: Dictionary = {}) -> void:
	if trace_recorder != null:
		trace_recorder.record(kind, details)


func _scene_path(scene_ref: Variant, packed_scene: PackedScene) -> String:
	if scene_ref is String:
		return str(scene_ref)
	if packed_scene != null and packed_scene.resource_path != "":
		return packed_scene.resource_path
	return str(scene_ref)


func _record_failure(message: String) -> void:
	if failure_sink != null and failure_sink.has_method("record_failure"):
		failure_sink.record_failure(message)
	else:
		printerr(message)


func _restore_runtime_state() -> void:
	tree.paused = false
	Engine.time_scale = 1.0
