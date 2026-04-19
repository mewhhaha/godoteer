extends Node

signal jumped

@export var speed := 120.0

var position_x := 0.0
var jump_count := 0
var last_horizontal_input := 0.0


func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("move_right"):
		last_horizontal_input = 1.0
		position_x += speed * delta
	else:
		last_horizontal_input = 0.0

	if Input.is_action_just_pressed("jump"):
		jump_count += 1
		jumped.emit()
