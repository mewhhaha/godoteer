extends Control

@onready var status_label: Label = $FormPanel/StatusLabel
@onready var action_button: Button = $FormPanel/ActionButton
@onready var name_input: LineEdit = $FormPanel/NameInput
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
	action_button.pressed.connect(_on_action_button_pressed)
	dismiss_notice_button.pressed.connect(_on_dismiss_notice_pressed)
	name_input.focus_entered.connect(_on_name_focus_entered)
	name_input.focus_exited.connect(_on_name_focus_exited)
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


func _on_drag_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed


func _on_drop_zone_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and dragging:
		dragging = false
		status_label.text = "Dropped"
