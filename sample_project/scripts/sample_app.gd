extends Control

@onready var status_label: Label = $FormPanel/StatusLabel
@onready var action_button: Button = $FormPanel/ActionButton


func _ready() -> void:
	action_button.pressed.connect(_on_action_button_pressed)


func _on_action_button_pressed() -> void:
	await get_tree().create_timer(0.05).timeout
	status_label.text = "Started"
