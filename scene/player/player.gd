extends CharacterBody3D

@export var speed: float = 5.0
@export var gravity: float = 15.0
@export var turn_speed: float = 14.0

@onready var visual: Node3D = $MeshInstance3D

const Sfx := preload("res://scripts/audio/sfx.gd")
const FARMING := "res://scripts/farm/farming_controller.gd"
const COMBAT := "res://scripts/combat/combat_controller.gd"
const GIRL := "res://scripts/characters/character_female.gd"
const HERO := "res://scripts/characters/hero_character.gd"
const FADER := "res://scripts/world/occlusion_fader.gd"
const FRUIT := "res://scripts/world/fruit_pickup.gd"
const SWAY := "res://scripts/world/sway_system.gd"

var girl: Node3D = null
var _step_t := 0.0
var _auto_target := Vector3.INF         # cutscene: jalan sendiri ke titik ini
var _auto_speed := 2.6
signal auto_walk_done

## Arah hadap (4 arah, dibulatkan ke sumbu). Dipakai untuk menentukan petak yang dituju.
var facing := Vector3(0, 0, 1)

var _trail: Array = []                  # jejak posisi aman (untuk "Teleport to safe spot" di Settings)
var _trail_t := 0.0


func _ready() -> void:
	add_to_group("player")               # dibutuhkan pintu/exit/interaksi
	if ResourceLoader.exists(HERO):        # model 3D buatan sendiri (Judy); kalau file GLB-nya tidak ada -> chibi bawaan
		var hero: Node3D = load(HERO).new()
		add_child(hero)                    # _ready() dijalankan di sini -> hero.ok menandakan GLB ditemukan
		if hero.get("ok"):
			girl = hero
		else:
			hero.queue_free()
	if girl == null and ResourceLoader.exists(GIRL):       # ganti kapsul dengan karakter cewe
		girl = load(GIRL).new()
		add_child(girl)
	if girl != null:
		visual.visible = false
		visual = girl
	_ensure_interact_action()
	if GameState.next_facing != Vector3.ZERO:               # tiba di area baru dengan arah hadap yang sama seperti saat pergi
		facing = GameState.next_facing
		visual.rotation.y = GameState.next_yaw
		var keep_f := facing
		var keep_y := GameState.next_yaw
		GameState.next_facing = Vector3.ZERO
		(func() -> void:
			await get_tree().create_timer(0.25).timeout        # setelah scene menaruh player di titik spawn
			if is_inside_tree() and visual != null:
				facing = keep_f
				visual.rotation.y = keep_y).call_deferred()
	if ResourceLoader.exists(FADER):
		add_child(load(FADER).new())         # benda yang menutupi player jadi tembus pandang
	if ResourceLoader.exists(FRUIT):
		(func() -> void:
			await get_tree().create_timer(1.5).timeout          # tunggu tabrakan dunia siap
			if is_inside_tree():
				load(FRUIT).spawn_for_scene(self)).call_deferred()
	if ResourceLoader.exists(SWAY):
		add_child(load(SWAY).new())          # bunga/rumput bergoyang saat dilewati
	if ResourceLoader.exists(FARMING):
		add_child(load(FARMING).new())       # sistem bercocok tanam (tekan E)
	if ResourceLoader.exists(COMBAT):
		add_child(load(COMBAT).new())        # pedang (klik kiri / F)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Kamera tetap menghadap -Z, jadi W = atas layar (-Z), D = kanan layar (+X).
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if _input_locked():
		input_dir = Vector2.ZERO
	var direction := Vector3(input_dir.x, 0.0, input_dir.y)
	var cam := get_node_or_null("CameraController") as Node3D
	if cam != null:
		direction = direction.rotated(Vector3.UP, cam.rotation.y)      # W = arah layar atas (juga di mode isometric)
	var cur_speed := speed
	if _auto_target != Vector3.INF:                          # cutscene: jalan sendiri
		var d := _auto_target - Vector3(global_position.x, 0.0, global_position.z)
		if d.length() < 0.12:
			_auto_target = Vector3.INF
			auto_walk_done.emit()
		else:
			direction = d.normalized()
			cur_speed = _auto_speed

	velocity.x = direction.x * cur_speed
	velocity.z = direction.z * cur_speed

	if direction.length() > 0.1:
		var ax := absf(direction.x)
		var az := absf(direction.z)
		if absf(ax - az) < 0.05:                       # diagonal: pertahankan arah hadap kalau masih searah
			if not (facing.x != 0.0 and signf(direction.x) == facing.x) and not (facing.z != 0.0 and signf(direction.z) == facing.z):
				facing = Vector3(0, 0, signf(direction.z))
		elif ax > az:
			facing = Vector3(signf(direction.x), 0, 0)
		else:
			facing = Vector3(0, 0, signf(direction.z))
		var target_yaw := atan2(direction.x, direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))

	move_and_slide()

	_trail_t -= delta
	if _trail_t <= 0.0 and is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.5:
		_trail_t = 0.7
		if _trail.is_empty() or (_trail[_trail.size() - 1] as Vector3).distance_to(global_position) > 1.2:
			_trail.append(global_position)
			if _trail.size() > 10:
				_trail.pop_front()

	if girl != null:
		var moving := Vector2(velocity.x, velocity.z).length() > 0.3
		girl.play_anim("walk" if moving else "idle", 1.0)
		if moving and is_on_floor():
			_step_t -= delta
			if _step_t <= 0.0:
				_step_t = 0.36 if cur_speed <= speed else 0.3
				Sfx.step()
		else:
			_step_t = 0.0


## Pindahkan ke posisi aman terdekat di area yang sama (dipakai saat nyangkut): titik jalan beberapa detik lalu.
func safe_teleport() -> bool:
	if _trail.size() < 2:
		return false
	var here := global_position
	var spot: Vector3 = _trail[0]
	for p in _trail:                                  # titik paling awal yang cukup jauh dari tempat nyangkut
		if (p as Vector3).distance_to(here) > 1.5:
			spot = p
			break
	if spot.distance_to(here) < 0.5:
		return false
	global_position = spot + Vector3(0, 0.2, 0)
	velocity = Vector3.ZERO
	return true


## Dipanggil sistem farming saat memakai alat → animasi ayun.
func play_tool(kind := "tool") -> void:
	match kind:
		"sword":
			Sfx.play("swing")
		"hoe":
			get_tree().create_timer(0.28).timeout.connect(func() -> void: Sfx.play("hoe"))
		"scythe":
			Sfx.play("scythe")
		"can", "watering_can", "water":
			Sfx.play("water")
		"eat":
			Sfx.play("eat")
	if girl != null:
		girl.play_tool(kind)


## Cutscene: player berjalan sendiri ke titik (x,z) lalu memancarkan sinyal auto_walk_done.
func auto_walk(to: Vector3, speed := 2.6) -> void:
	_auto_target = Vector3(to.x, 0.0, to.z)
	_auto_speed = speed


func is_auto_walking() -> bool:
	return _auto_target != Vector3.INF


## Pingsan (roboh) – dipakai GameState sebelum layar gelap. Berdiri lagi lewat stand_up().
func play_faint() -> void:
	if girl != null:
		await girl.play_faint()


func stand_up() -> void:
	if girl != null:
		girl.stand_up()


func _input_locked() -> bool:
	var gs := get_node_or_null("/root/GameState")
	return gs != null and (bool(gs.get("input_locked")) or bool(gs.get("chatting")))


func _ensure_interact_action() -> void:
	if InputMap.has_action("interact"):
		return
	InputMap.add_action("interact")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_E
	InputMap.action_add_event("interact", ev)
