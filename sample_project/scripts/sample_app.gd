extends Control

@onready var status_label: Label = $FormPanel/StatusLabel
@onready var action_button: Button = $FormPanel/ActionButton
@onready var name_input: LineEdit = $FormPanel/NameRow/NameInput
@onready var notes_input: TextEdit = $FormPanel/NotesRow/NotesInput
@onready var terms_toggle: CheckBox = $FormPanel/TermsToggle
@onready var role_select: OptionButton = $FormPanel/RoleSelect
@onready var hidden_message: Label = $FormPanel/HiddenMessage
@onready var disabled_button: Button = $FormPanel/DisabledButton
@onready var transient_notice: Label = $FormPanel/TransientNotice
@onready var dismiss_notice_button: Button = $FormPanel/DismissNoticeButton
@onready var drag_handle: ColorRect = $FormPanel/DragRow/DragHandle
@onready var drop_zone: ColorRect = $FormPanel/DragRow/DropZone

var dragging := false


func _ready() -> void:
	_build_camera_preview()
	action_button.pressed.connect(_on_action_button_pressed)
	dismiss_notice_button.pressed.connect(_on_dismiss_notice_pressed)
	name_input.focus_entered.connect(_on_name_focus_entered)
	name_input.focus_exited.connect(_on_name_focus_exited)
	name_input.text_submitted.connect(_on_name_submitted)
	notes_input.text_changed.connect(_on_notes_changed)
	terms_toggle.mouse_entered.connect(_on_terms_mouse_entered)
	drag_handle.gui_input.connect(_on_drag_handle_gui_input)
	drop_zone.gui_input.connect(_on_drop_zone_gui_input)


func _on_action_button_pressed() -> void:
	await get_tree().create_timer(0.05).timeout
	status_label.text = "Started %s / %s / %s" % [
		name_input.text if name_input.text != "" else "Anonymous",
		"Accepted" if terms_toggle.button_pressed else "Pending",
		role_select.get_item_text(role_select.selected) if role_select.selected >= 0 else "No Role"
	]


func _on_dismiss_notice_pressed() -> void:
	transient_notice.queue_free()


func _on_name_focus_entered() -> void:
	status_label.text = "Focused Name"


func _on_name_focus_exited() -> void:
	status_label.text = "Blurred Name"


func _on_terms_mouse_entered() -> void:
	status_label.text = "Hover Terms"


func _on_name_submitted(text: String) -> void:
	status_label.text = "Submitted: %s" % text


func _on_notes_changed() -> void:
	status_label.text = "Notes: %s" % notes_input.text


func _on_drag_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed


func _on_drop_zone_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dragging:
		dragging = false
		status_label.text = "Dropped"


func _build_camera_preview() -> void:
	if has_node("CameraPreviewViewport"):
		return

	var preview_viewport := SubViewport.new()
	preview_viewport.name = "CameraPreviewViewport"
	preview_viewport.size = Vector2i(120, 120)
	preview_viewport.handle_input_locally = false
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(preview_viewport)

	var world_root := Node2D.new()
	world_root.name = "CameraWorld"
	preview_viewport.add_child(world_root)

	var left_camera := Camera2D.new()
	left_camera.name = "LeftCamera"
	left_camera.position = Vector2.ZERO
	world_root.add_child(left_camera)

	var right_camera := Camera2D.new()
	right_camera.name = "RightCamera"
	right_camera.position = Vector2(120, 0)
	world_root.add_child(right_camera)

	var left_marker := Polygon2D.new()
	left_marker.name = "LeftMarker"
	left_marker.position = Vector2.ZERO
	left_marker.color = Color(0.95, 0.2, 0.2, 1.0)
	left_marker.polygon = PackedVector2Array([
		Vector2(-40, -40),
		Vector2(40, -40),
		Vector2(40, 40),
		Vector2(-40, 40),
	])
	world_root.add_child(left_marker)

	var right_marker := Polygon2D.new()
	right_marker.name = "RightMarker"
	right_marker.position = Vector2(120, 0)
	right_marker.color = Color(0.2, 0.4, 0.95, 1.0)
	right_marker.polygon = PackedVector2Array([
		Vector2(-40, -40),
		Vector2(40, -40),
		Vector2(40, 40),
		Vector2(-40, 40),
	])
	world_root.add_child(right_marker)

	left_camera.make_current()
