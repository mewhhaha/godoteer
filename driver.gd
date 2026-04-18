extends RefCounted
class_name GodoteerDriver

const GodoteerScreen = preload("screen.gd")

var tree: SceneTree
var failure_sink: Object
var artifacts_dir := "user://artifacts"
var current_screen: GodoteerScreen
var current_app_root: Node


func _init(scene_tree: SceneTree, sink: Object, artifacts_path: String = "user://artifacts") -> void:
	tree = scene_tree
	failure_sink = sink
	artifacts_dir = artifacts_path.trim_suffix("/")


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

	current_screen = GodoteerScreen.new(tree, current_app_root, failure_sink, artifacts_dir)
	return current_screen


func close_screen() -> void:
	current_screen = null

	if current_app_root == null:
		return

	if tree.current_scene == current_app_root:
		tree.current_scene = null

	current_app_root.queue_free()
	current_app_root = null
	await tree.process_frame


func reset() -> void:
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


func _record_failure(message: String) -> void:
	if failure_sink != null and failure_sink.has_method("record_failure"):
		failure_sink.record_failure(message)
	else:
		printerr(message)
