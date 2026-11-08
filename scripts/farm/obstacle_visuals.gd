extends RefCounted
## ObstacleVisuals - bentuk 3D rintangan di petak tanam: batu (rock), kayu tumbang (wood), rumput liar (weed).
## Dibuat dari bangun dasar (tanpa model). Dipanggil oleh farming_controller.gd.

static var _mats := {}


static func mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		_mats[key] = m
	return _mats[key]


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, col: Color, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(col)
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func _cone(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 6
	m.rings = 1
	return m


static func _cyl(r: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 8
	m.rings = 1
	return m


static func _ball(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 5
	return m


## Rumpun helai rumput: n helai kerucut tipis yang sedikit miring ke luar.
static func _tuft(parent: Node3D, col: Color, n: int, height: float, spread: float, tilt: float) -> void:
	for i in n:
		var ang := float(i) / float(n) * TAU + height
		var r := spread * (0.35 + 0.65 * fmod(float(i) * 0.618, 1.0))
		var blade := _add(parent, _cone(0.045, height * (0.75 + 0.5 * fmod(float(i) * 0.37, 1.0))),
				Vector3(cos(ang) * r, height * 0.38, sin(ang) * r), col)
		blade.rotation = Vector3(sin(ang) * tilt, 0.0, -cos(ang) * tilt)


## Rintangan di petak tanam: "rock" (batu), "wood" (ranting/kayu tumbang), "weed" (rumput liar). seed_v = variasi bentuk.
static func obstacle(kind: String, seed_v: int) -> Node3D:
	var root := Node3D.new()
	var a := float(absi(seed_v) % 9) * 0.7
	match kind:
		"rock":
			_add(root, _ball(0.30), Vector3(0.0, 0.14, 0.0), Color(0.55, 0.56, 0.60), Vector3(1.1, 0.7, 0.95)).rotation.y = a
			_add(root, _ball(0.20), Vector3(0.26 * cos(a), 0.09, 0.26 * sin(a)), Color(0.46, 0.47, 0.52), Vector3(1.0, 0.7, 1.1))
			_add(root, _ball(0.13), Vector3(-0.22 * cos(a + 1.0), 0.06, -0.22 * sin(a + 1.0)), Color(0.62, 0.63, 0.67), Vector3(1.0, 0.7, 1.0))
		"wood":
			for k in 2:
				var log_m := _add(root, _cyl(0.075, 0.82), Vector3(0.0, 0.09 + k * 0.13, 0.0), Color(0.46, 0.29, 0.15))
				log_m.rotation = Vector3(0.0, a + k * 1.1, PI * 0.5)
				var cap := _add(root, _cyl(0.062, 0.02), Vector3(0.0, 0.09 + k * 0.13, 0.0), Color(0.78, 0.60, 0.36))
				cap.rotation = log_m.rotation
				cap.position = log_m.position + Vector3(0.41, 0.0, 0.0).rotated(Vector3.UP, a + k * 1.1)
			_add(root, _cone(0.05, 0.22), Vector3(0.2 * cos(a), 0.11, 0.2 * sin(a) + 0.2), Color(0.34, 0.60, 0.26))      # tunas kecil
		"weed":
			_tuft(root, Color(0.34, 0.70, 0.26), 9, 0.55, 0.34, 0.28)
			_tuft(root, Color(0.28, 0.60, 0.22), 6, 0.38, 0.5, 0.45)
	return root
