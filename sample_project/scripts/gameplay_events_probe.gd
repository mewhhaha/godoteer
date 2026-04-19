extends Node

signal probe_signal(kind: String, step: int, payload: String)

const HOLD_ACTION := "move_right"
const HOLD_KEY := KEY_RIGHT
const LONG_PRESS_THRESHOLD_FRAMES := 10
const POINTER_POSITION := Vector2(48, 48)
const POINTER_SIZE := Vector2(140, 84)
const SENSOR_POSITION := Vector2(320, 180)
const BODY_START_POSITION := Vector2(520, 180)
const AREA_START_POSITION := Vector2(520, 240)

var action_hold_frames := 0
var action_hold_reached := false
var key_hold_frames := 0
var key_hold_reached := false
var chord_detected := false
var chord_detection_count := 0

var single_click_count := 0
var double_click_count := 0
var right_click_count := 0
var long_press_count := 0
var pointer_status := "idle"

var process_signal_count := 0
var physics_signal_count := 0
var animation_finished_count := 0
var animation_finished_name := ""
var audio_finished_count := 0
var body_entered_count := 0
var area_entered_count := 0
var last_body_name := ""
var last_area_name := ""

var pointer_target: Panel
var animation_player: AnimationPlayer
var audio_player: AudioStreamPlayer
var sensor_area: Area2D
var body_probe: CharacterBody2D
var area_probe: Area2D

var _left_press_frame := -1
var _process_once_armed := false
var _process_once_payload := ""
var _process_burst_remaining := 0
var _process_burst_prefix := "process"
var _physics_burst_remaining := 0
var _physics_burst_prefix := "physics"
var _queue_body_overlap := false
var _queue_area_overlap := false


func _ready() -> void:
	_build_ui()
	_build_animation_player()
	_build_audio_player()
	_build_physics_nodes()


func _process(_delta: float) -> void:
	if Input.is_action_pressed(HOLD_ACTION):
		action_hold_frames += 1
		if action_hold_frames >= 5:
			action_hold_reached = true
	else:
		action_hold_frames = 0

	if Input.is_key_pressed(HOLD_KEY):
		key_hold_frames += 1
		if key_hold_frames >= 5:
			key_hold_reached = true
	else:
		key_hold_frames = 0

	if Input.is_key_pressed(KEY_CTRL) and Input.is_key_pressed(KEY_S) and not chord_detected:
		chord_detected = true
		chord_detection_count += 1

	if _process_once_armed:
		_emit_process_probe("once", _process_once_payload)
		_process_once_armed = false

	if _process_burst_remaining > 0:
		_emit_process_probe(_process_burst_prefix, "%s-%d" % [_process_burst_prefix, process_signal_count + 1])
		_process_burst_remaining -= 1


func _physics_process(_delta: float) -> void:
	if _physics_burst_remaining > 0:
		_emit_physics_probe(_physics_burst_prefix, "%s-%d" % [_physics_burst_prefix, physics_signal_count + 1])
		_physics_burst_remaining -= 1

	if _queue_body_overlap:
		body_probe.global_position = SENSOR_POSITION
		_queue_body_overlap = false

	if _queue_area_overlap:
		area_probe.global_position = SENSOR_POSITION + Vector2(6, 0)
		_queue_area_overlap = false


func arm_process_signal_once(payload := "once") -> void:
	_process_once_armed = true
	_process_once_payload = str(payload)


func start_process_burst(count: int, payload_prefix := "process") -> void:
	_process_burst_remaining = max(count, 0)
	_process_burst_prefix = str(payload_prefix)


func start_physics_burst(count: int, payload_prefix := "physics") -> void:
	_physics_burst_remaining = max(count, 0)
	_physics_burst_prefix = str(payload_prefix)


func play_probe_animation(animation_name := "pulse") -> void:
	animation_player.play(str(animation_name))


func play_probe_audio() -> void:
	audio_player.stop()
	audio_player.play()


func queue_body_entry() -> void:
	body_probe.global_position = BODY_START_POSITION
	_queue_body_overlap = true


func queue_area_entry() -> void:
	area_probe.global_position = AREA_START_POSITION
	_queue_area_overlap = true


func _build_ui() -> void:
	var ui_root := Control.new()
	ui_root.name = "UiRoot"
	ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_root)

	pointer_target = Panel.new()
	pointer_target.name = "PointerTarget"
	pointer_target.position = POINTER_POSITION
	pointer_target.size = POINTER_SIZE
	pointer_target.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(pointer_target)
	pointer_target.gui_input.connect(_on_pointer_target_gui_input)


func _build_animation_player() -> void:
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	add_child(animation_player)
	var animation_library := AnimationLibrary.new()
	var animation := Animation.new()
	animation.length = 0.05
	animation_library.add_animation("pulse", animation)
	animation_player.add_animation_library("", animation_library)
	animation_player.animation_finished.connect(_on_animation_finished)


func _build_audio_player() -> void:
	audio_player = AudioStreamPlayer.new()
	audio_player.name = "AudioPlayer"
	audio_player.stream = _build_audio_stream()
	add_child(audio_player)
	audio_player.finished.connect(_on_audio_finished)


func _build_physics_nodes() -> void:
	sensor_area = Area2D.new()
	sensor_area.name = "SensorArea"
	sensor_area.monitoring = true
	sensor_area.monitorable = true
	sensor_area.global_position = SENSOR_POSITION
	sensor_area.body_entered.connect(_on_body_entered)
	sensor_area.area_entered.connect(_on_area_entered)
	add_child(sensor_area)
	sensor_area.add_child(_collision_shape("SensorShape"))

	body_probe = CharacterBody2D.new()
	body_probe.name = "BodyProbe"
	body_probe.global_position = BODY_START_POSITION
	add_child(body_probe)
	body_probe.add_child(_collision_shape("BodyShape"))

	area_probe = Area2D.new()
	area_probe.name = "AreaProbe"
	area_probe.monitoring = true
	area_probe.monitorable = true
	area_probe.global_position = AREA_START_POSITION
	add_child(area_probe)
	area_probe.add_child(_collision_shape("AreaShape"))


func _collision_shape(shape_name: String) -> CollisionShape2D:
	var collision_shape := CollisionShape2D.new()
	collision_shape.name = shape_name
	var circle := CircleShape2D.new()
	circle.radius = 20.0
	collision_shape.shape = circle
	return collision_shape


func _build_audio_stream() -> AudioStreamWAV:
	var sample_rate := 11025
	var frame_count := int(sample_rate * 0.08)
	var data := PackedByteArray()
	data.resize(frame_count * 2)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func _emit_process_probe(kind: String, payload: String) -> void:
	process_signal_count += 1
	probe_signal.emit(kind, process_signal_count, payload)


func _emit_physics_probe(kind: String, payload: String) -> void:
	physics_signal_count += 1
	probe_signal.emit(kind, physics_signal_count, payload)


func _on_pointer_target_gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return

	var mouse_event: InputEventMouseButton = event
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		right_click_count += 1
		pointer_status = "right"
		return

	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return

	if mouse_event.pressed:
		_left_press_frame = Engine.get_process_frames()
		if mouse_event.double_click:
			double_click_count += 1
			pointer_status = "double"
		else:
			single_click_count += 1
			pointer_status = "left"
		return

	if _left_press_frame >= 0 and Engine.get_process_frames() - _left_press_frame >= LONG_PRESS_THRESHOLD_FRAMES:
		long_press_count += 1
		pointer_status = "long"
	_left_press_frame = -1


func _on_animation_finished(animation_name: StringName) -> void:
	animation_finished_count += 1
	animation_finished_name = str(animation_name)


func _on_audio_finished() -> void:
	audio_finished_count += 1


func _on_body_entered(body: Node2D) -> void:
	body_entered_count += 1
	last_body_name = body.name


func _on_area_entered(area: Area2D) -> void:
	area_entered_count += 1
	last_area_name = area.name
