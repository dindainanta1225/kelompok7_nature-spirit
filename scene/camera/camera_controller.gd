extends Node3D
## Kamera tetap yang mengikuti Player. Tidak ada mouse-look; mouse tetap terlihat untuk UI. Scroll mouse = zoom.
## Tekan V = ganti tampilan: "Top-down" (perspektif miring, default) <-> "Isometric" (ortografis, diputar 45 derajat).
## Gerak WASD otomatis mengikuti arah kamera (W = ke arah layar atas).

@export var pitch_deg := -32.0          # makin mendekati -90 makin "dari atas"
@export var distance := 9.5
@export var fov := 40.0
@export var follow_speed := 8.0         # 0 = kaku, makin besar makin cepat menyusul
@export var look_offset := Vector3(0, 1.0, 0)
@export var zoom_min := 5.0
@export var zoom_max := 40.0
@export var zoom_step := 2.0
@export var start_isometric := false
@export var iso_pitch_deg := -35.264    # sudut isometric sejati
@export var iso_yaw_deg := 45.0
@export var iso_size := 11.0            # tinggi pandang ortografis (meter)
@export var iso_size_min := 5.0
@export var iso_size_max := 22.0

const AppSettings := preload("res://scripts/ui/app_settings.gd")

@onready var camera: Camera3D = $Camera3D

var isometric := false
var _target: Node3D


func _ready() -> void:
	top_level = true                     # supaya tidak ikut berputar/berpindah kasar bersama Player
	_target = get_parent() as Node3D
	_ensure_action()
	camera.current = true
	_apply_mode()
	if start_isometric:
		set_isometric(true, false)
	if _target:
		global_position = _target.global_position + look_offset


func _ensure_action() -> void:
	if InputMap.has_action("camera_toggle"):
		return
	InputMap.add_action("camera_toggle")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_V
	InputMap.action_add_event("camera_toggle", ev)


func set_isometric(on: bool, announce := true) -> void:
	isometric = on
	_apply_mode()
	if announce and GameState.playing:
		GameState.toast.emit("Isometric view" if on else "Top-down view")


func _apply_mode() -> void:
	camera.rotation = Vector3.ZERO         # buang rotasi bawaan Camera3D di player.tscn; arah ditentukan node ini
	if isometric:
		rotation = Vector3(deg_to_rad(iso_pitch_deg), deg_to_rad(iso_yaw_deg), 0.0)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = iso_size
		camera.position = Vector3(0, 0, 40.0)
	else:
		rotation = Vector3(deg_to_rad(pitch_deg), 0.0, 0.0)
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = fov
		camera.position = Vector3(0, 0, distance * _cam_scale())


## Skala jarak kamera dari Settings (25-100%).
func _cam_scale() -> float:
	return maxf(0.25, float(AppSettings.cam_scale))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_toggle") and not GameState.input_locked and not get_tree().paused:
		set_isometric(not isometric)
		return
	if event is InputEventMouseButton and event.pressed:
		var dir := 0.0
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			dir = -1.0
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dir = 1.0
		if dir != 0.0:
			if isometric:
				iso_size = clampf(iso_size + dir * zoom_step * 0.5, iso_size_min, iso_size_max)
			else:
				distance = clampf(distance + dir * zoom_step, zoom_min, zoom_max)


func _process(delta: float) -> void:
	if _target == null:
		return
	var goal := _target.global_position + look_offset
	global_position = goal if follow_speed <= 0.0 else global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))
	if isometric:
		camera.size = lerpf(camera.size, iso_size * _cam_scale(), 1.0 - exp(-10.0 * delta))
	else:
		camera.position.z = lerpf(camera.position.z, distance * _cam_scale(), 1.0 - exp(-10.0 * delta))
