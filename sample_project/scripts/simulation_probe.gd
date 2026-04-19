extends Node

signal process_pulse(frame_count, delta_sum)
signal physics_pulse(frame_count, delta_sum)

var process_count := 0
var physics_count := 0
var process_delta_sum := 0.0
var physics_delta_sum := 0.0


func _ready() -> void:
	set_process(true)
	set_physics_process(true)


func _process(delta: float) -> void:
	process_count += 1
	process_delta_sum += delta
	process_pulse.emit(process_count, process_delta_sum)


func _physics_process(delta: float) -> void:
	physics_count += 1
	physics_delta_sum += delta
	physics_pulse.emit(physics_count, physics_delta_sum)
