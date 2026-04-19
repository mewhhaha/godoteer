extends Control

@onready var status_label: Label = $FormPanel/StatusLabel
@onready var action_button: Button = $FormPanel/ActionButton
@onready var name_input: LineEdit = $FormPanel/NameInput
@onready var terms_toggle: CheckBox = $FormPanel/TermsToggle
@onready var role_select: OptionButton = $FormPanel/RoleSelect


func _ready() -> void:
	action_button.pressed.connect(_on_action_button_pressed)


func _on_action_button_pressed() -> void:
	await get_tree().create_timer(0.05).timeout
	status_label.text = "Started %s / %s / %s" % [
		name_input.text if name_input.text != "" else "Anonymous",
		"Accepted" if terms_toggle.button_pressed else "Pending",
		role_select.get_item_text(role_select.selected) if role_select.selected >= 0 else "No Role"
	]
