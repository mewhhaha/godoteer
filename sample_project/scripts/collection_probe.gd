extends Control

signal delayed_choices_ready(count: int)

var status_label: Label
var choice_list: VBoxContainer
var text_list: VBoxContainer
var form_list: VBoxContainer
var delayed_list: VBoxContainer


func _ready() -> void:
	_build_ui()
	get_tree().create_timer(0.05).timeout.connect(_spawn_delayed_choices)


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.name = "RootColumn"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24.0
	root.offset_top = 24.0
	root.offset_right = -24.0
	root.offset_bottom = -24.0
	add_child(root)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.text = "Idle"
	root.add_child(status_label)

	choice_list = VBoxContainer.new()
	choice_list.name = "ChoiceList"
	root.add_child(choice_list)
	for index in range(2):
		var button := Button.new()
		button.name = "ChoiceButton%d" % (index + 1)
		button.text = "Choice"
		button.accessibility_name = "Choice"
		button.pressed.connect(_on_choice_pressed.bind(index + 1))
		choice_list.add_child(button)

	text_list = VBoxContainer.new()
	text_list.name = "TextList"
	root.add_child(text_list)
	for index in range(3):
		var row := HBoxContainer.new()
		row.name = "TextRow%d" % (index + 1)
		text_list.add_child(row)

		var label := Label.new()
		label.name = "ValueLabel"
		label.text = "Echo"
		row.add_child(label)

	form_list = VBoxContainer.new()
	form_list.name = "FormList"
	root.add_child(form_list)
	for index in range(2):
		var row := HBoxContainer.new()
		row.name = "FormRow%d" % (index + 1)
		form_list.add_child(row)

		var label := Label.new()
		label.name = "FieldLabel"
		label.text = "Item Name"
		row.add_child(label)

		var input := LineEdit.new()
		input.name = "FieldInput"
		input.placeholder_text = "Type item"
		input.accessibility_labeled_by_nodes = [NodePath("../FieldLabel")]
		row.add_child(input)

	delayed_list = VBoxContainer.new()
	delayed_list.name = "DelayedList"
	root.add_child(delayed_list)


func _spawn_delayed_choices() -> void:
	for index in range(3):
		var button := Button.new()
		button.name = "DelayedChoiceButton%d" % (index + 1)
		button.text = "Delayed Choice"
		button.accessibility_name = "Delayed Choice"
		button.pressed.connect(_on_delayed_choice_pressed.bind(index + 1))
		delayed_list.add_child(button)
	delayed_choices_ready.emit(delayed_list.get_child_count())


func _on_choice_pressed(index: int) -> void:
	status_label.text = "Choice %d" % index


func _on_delayed_choice_pressed(index: int) -> void:
	status_label.text = "Delayed %d" % index
