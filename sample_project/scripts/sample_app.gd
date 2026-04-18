extends Control

@onready var status_label: Label = $StatusLabel
@onready var action_button: Button = $ActionButton


func _ready() -> void:
	action_button.pressed.connect(_on_action_button_pressed)


func _on_action_button_pressed() -> void:
	status_label.text = "Started"
