extends RefCounted


func _init(required_value: String) -> void:
	if required_value == "":
		push_error("required_value should not be empty")
