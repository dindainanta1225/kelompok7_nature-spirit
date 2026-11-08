extends Node3D
const Sfx := preload("res://scripts/audio/sfx.gd")
## Critter - hewan kecil hiasan yang berkeliaran: ayam (berjalan + mematuk) dan kupu-kupu (terbang melayang).
## Dibuat dari bangun dasar. Ayam/kuda/domba padat (tidak bisa ditembus); kupu-kupu hanya hiasan.

const NpcModels := preload("res://scripts/characters/npc_models.gd")

var kind := "chicken"                 # "chicken" | "butterfly"
var home := Vector3.ZERO              # titik pusat berkeliaran
var radius := 3.0
var ground_y := 1.5
var wing_color := Color(1.0, 0.7, 0.2)

var _target := Vector3.ZERO
var _wait := 0.0
var _t := 0.0
var _body: Node3D
var _wing_l: Node3D
var _wing_r: Node3D
var _head: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_t = _rng.randf() * 10.0
	if kind == "chicken":
		_build_chicken()
	elif kind == "horse" or kind == "sheep":
		if not _build_livestock():
			queue_free()
			return
	else:
		_build_butterfly()
	position = Vector3(home.x, ground_y if kind != "butterfly" else ground_y + 1.2, home.z)
	if kind != "butterfly":
		_add_solid(0.28 if kind == "chicken" else (0.7 if kind == "horse" else 0.5), 0.7 if kind == "chicken" else 1.4)
	_pick()


## Hewan padat (ayam, kuda, domba): player tidak bisa menembusnya. Kupu-kupu tetap tanpa tabrakan.
func _add_solid(r: float, h: float) -> void:
	var b := AnimatableBody3D.new()
	b.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	cs.position = Vector3(0, h * 0.5, 0)
	b.add_child(cs)
	add_child(b)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _mesh(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 5
	return s


func _build_chicken() -> void:
	var m := NpcModels.build_chicken(0.42)
	if not m.is_empty():
		_body = Node3D.new()
		add_child(_body)
		_body.add_child(m["node"])
		_ranim = m["anim"]
		return
	_body = Node3D.new()
	add_child(_body)
	var white := Color(0.97, 0.95, 0.90) if _rng.randf() < 0.7 else Color(0.78, 0.5, 0.28)
	_mesh(_body, _sphere(0.17), white, Vector3(0, 0.22, 0), Vector3(1.0, 0.9, 1.25))
	_mesh(_body, _sphere(0.11), white.darkened(0.04), Vector3(0, 0.22, -0.2), Vector3(0.8, 0.9, 1.0))          # ekor
	_head = Node3D.new()
	_head.position = Vector3(0, 0.38, 0.17)
	_body.add_child(_head)
	_mesh(_head, _sphere(0.085), white, Vector3.ZERO)
	_mesh(_head, _sphere(0.035), Color(0.85, 0.15, 0.12), Vector3(0, 0.08, 0.0), Vector3(0.6, 1.0, 1.3))     # jengger
	var beak := CylinderMesh.new()
	beak.top_radius = 0.0
	beak.bottom_radius = 0.03
	beak.height = 0.08
	var bm := _mesh(_head, beak, Color(0.95, 0.65, 0.15), Vector3(0, -0.01, 0.1))
	bm.rotation.x = PI * 0.5
	_mesh(_head, _sphere(0.014), Color(0.05, 0.05, 0.05), Vector3(0.05, 0.02, 0.06))
	_mesh(_head, _sphere(0.014), Color(0.05, 0.05, 0.05), Vector3(-0.05, 0.02, 0.06))
	for sx in [-1.0, 1.0]:
		var leg := CylinderMesh.new()
		leg.top_radius = 0.012
		leg.bottom_radius = 0.012
		leg.height = 0.12
		_mesh(self, leg, Color(0.95, 0.65, 0.15), Vector3(0.06 * sx, 0.06, 0.0))


## Kuda & domba (GLB buatan sendiri + skeleton): berjalan pelan, berhenti merumput.
func _build_livestock() -> bool:
	var m := NpcModels.build_animal(kind)
	if m.is_empty():
		return false
	_body = Node3D.new()
	add_child(_body)
	_body.add_child(m["node"])
	_ranim = m["anim"]
	return true


func _build_butterfly() -> void:
	_body = Node3D.new()
	add_child(_body)
	var b := CylinderMesh.new()
	b.top_radius = 0.012
	b.bottom_radius = 0.012
	b.height = 0.12
	var bm := _mesh(_body, b, Color(0.2, 0.12, 0.1), Vector3.ZERO)
	bm.rotation.x = PI * 0.5
	for sx in [-1.0, 1.0]:
		var piv := Node3D.new()
		_body.add_child(piv)
		var q := QuadMesh.new()
		q.size = Vector2(0.16, 0.12)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		var m := _mat(wing_color)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		mi.position = Vector3(0.08 * sx, 0, 0)
		mi.rotation.x = -PI * 0.5
		piv.add_child(mi)
		if sx < 0:
			_wing_l = piv
		else:
			_wing_r = piv


func _pick() -> void:
	var a := _rng.randf() * TAU
	var r := _rng.randf() * radius
	_target = Vector3(home.x + cos(a) * r, position.y, home.z + sin(a) * r)
	_wait = _rng.randf_range(0.5, 3.0) if kind != "butterfly" else 0.0


func _process(delta: float) -> void:
	_t += delta
	_voice_t -= delta
	if _voice_t <= 0.0:
		_voice_t = _rng.randf_range(7.0, 18.0)
		match kind:
			"chicken":
				Sfx.play_at("cluck", global_position, 12.0, -4.0, _rng.randf_range(0.9, 1.25))
			"sheep":
				Sfx.play_at("baa", global_position, 14.0, -5.0, _rng.randf_range(0.85, 1.2))
			"horse":
				Sfx.play_at("neigh", global_position, 16.0, -6.0, _rng.randf_range(0.9, 1.1))
	if kind != "butterfly":
		var spd := 0.9 if kind == "chicken" else (1.2 if kind == "horse" else 0.7)
		if _wait > 0.0:
			_wait -= delta
			if _ranim:
				_peck = 1.0 if fmod(_t, 5.0) < 2.2 else 0.0                 # mematuk / merumput
				_ranim.update({"speed": 0.0, "peck": _peck, "flap": 0.0, "windup": -1.0, "lunge": 0.0, "hit": 0.0, "t": _t, "delta": delta})
			if _head:
				_head.rotation.x = 0.6 * maxf(0.0, sin(_t * 10.0)) if fmod(_t, 4.0) < 1.6 else 0.0      # mematuk tanah
			if _wait <= 0.0:
				_pick()
				_wait = 0.0
				_target = Vector3(_target.x, position.y, _target.z)
				_move = true
			return
		_step_to(delta, spd)
		if _ranim:
			_ranim.update({"speed": 1.0, "peck": 0.0, "flap": 0.0, "windup": -1.0, "lunge": 0.0, "hit": 0.0, "t": _t, "delta": delta})
		elif _body:
			_body.position.y = absf(sin(_t * 12.0)) * 0.03
	else:
		_step_to(delta, 0.7)
		position.y = ground_y + 1.2 + sin(_t * 2.0) * 0.35
		if _wing_l:
			var f := sin(_t * 22.0) * 0.9
			_wing_l.rotation.z = f
			_wing_r.rotation.z = -f


var _move := true
var _voice_t := 6.0
var _ranim: RefCounted
var _peck := 0.0
var _flap := 0.0


func _step_to(delta: float, speed: float) -> void:
	var d := _target - position
	d.y = 0.0
	if d.length() < 0.15:
		if kind != "butterfly":
			_wait = _rng.randf_range(1.0, 3.5) if kind == "chicken" else _rng.randf_range(3.0, 7.0)
		else:
			_pick()
		return
	var dir := d.normalized()
	position += dir * speed * delta
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-8.0 * delta))
