extends Node3D

@export var mouse_sensitivity := 0.003
@export var distance := 5.0
@export var height := 2.5

@onready var camera: Camera3D = $Camera3D

var pitch := -10.0


func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	# Kamera di belakang dan sedikit di atas Player
	camera.position = Vector3(0, 4.0, 5.0)
	camera.rotation.x = deg_to_rad(pitch)


func _input(event):
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:

			# Kiri / kanan
			rotate_y(-event.relative.x * mouse_sensitivity)

			# Atas / bawah
			pitch -= event.relative.y * mouse_sensitivity
			pitch = clamp(pitch, -45.0, 30.0)

			camera.rotation.x = deg_to_rad(pitch)

	# ESC untuk melepas mouse
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Klik untuk mengambil mouse lagi
	if event is InputEventMouseButton:
		if event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
