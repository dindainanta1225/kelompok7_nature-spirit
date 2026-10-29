extends CharacterBody3D

@export var speed: float = 5.0
@export var gravity: float = 15.0

@onready var camera_controller: Node3D = $CameraController


func _physics_process(delta: float) -> void:
	# =========================
	# GRAVITASI
	# =========================
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0


	# =========================
	# INPUT WASD
	# =========================
	var input_dir := Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)


	# =========================
	# ARAH MENGIKUTI KAMERA
	# =========================
	var forward := -camera_controller.global_transform.basis.z
	var right := camera_controller.global_transform.basis.x

	forward.y = 0.0
	right.y = 0.0

	forward = forward.normalized()
	right = right.normalized()

	var direction := (
		right * input_dir.x
		+ forward * -input_dir.y
	).normalized()


	# =========================
	# GERAK PLAYER
	# =========================
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()
