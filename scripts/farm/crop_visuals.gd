extends RefCounted
## CropVisuals - bentuk 3D tanaman dari bangun dasar (tanpa model). 4 tahap: tunas, tumbuh, hampir, siap panen.
## Ganti dengan model-mu nanti: cukup ubah plant() supaya mengembalikan Node3D dari scene-mu.

static var _mats := {}

const PLANT_SCALE := 1.55
const LEAF := Color(0.30, 0.66, 0.26)
const LEAF_D := Color(0.20, 0.50, 0.20)


static func mat(c: Color, glow := false) -> StandardMaterial3D:
	var key := c.to_html() + ("g" if glow else "")
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		if glow:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 1.4
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


static func _cone(r: float, h: float, inverted := false) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r if inverted else 0.0
	m.bottom_radius = 0.0 if inverted else r
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
	m.rings = 6
	return m


## Rumpun daun runcing yang menyebar ke luar.
static func _tuft(parent: Node3D, col: Color, n: int, height: float, spread: float, tilt: float, y0 := 0.0) -> void:
	for i in n:
		var a := TAU * i / n + 0.4
		var mi := _add(parent, _cone(0.05 + height * 0.04, height), Vector3(cos(a) * spread * 0.5, y0 + height * 0.5, sin(a) * spread * 0.5), col.lightened(0.06 * (i % 3)))
		mi.basis = Basis(Vector3(sin(a), 0, -cos(a)), tilt)


static func _bush(parent: Node3D, col: Color, r: float, offsets: Array, y := 0.0) -> void:
	for o in offsets:
		_add(parent, _ball(r), Vector3(o.x, y + r * 0.6 + o.y, o.z), col, Vector3(1, 0.75, 1))


static func _fruits(parent: Node3D, col: Color, r: float, spots: Array) -> void:
	for p in spots:
		_add(parent, _ball(r), p, col)


static func soil(watered: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.92, 0.05, 0.92)
	mi.mesh = b
	mi.material_override = mat(Color(0.22, 0.13, 0.07) if watered else Color(0.40, 0.26, 0.14))
	mi.position = Vector3(0, 0.03, 0)
	return mi


## Tahap tumbuh 0..3 dari umur dan lama tumbuh.
static func stage_of(age: int, days: int) -> int:
	if days <= 0 or age >= days:
		return 3
	var f := float(age) / float(days)
	return 0 if f < 0.34 else (1 if f < 0.67 else 2)


static func plant(id: String, stage: int) -> Node3D:
	var root := Node3D.new()
	var g: float = [0.30, 0.58, 0.85, 1.0][stage]
	match id:
		"carrot":
			_tuft(root, LEAF, 6, 0.42 * g, 0.28 * g, 0.55)
			if stage >= 3:
				_add(root, _cone(0.075, 0.2, true), Vector3(0, 0.1, 0), Color(0.96, 0.52, 0.12))
		"potato":
			_bush(root, LEAF_D, 0.17 * g, [Vector3(0, 0, 0), Vector3(0.12, 0, 0.05), Vector3(-0.1, 0, 0.08), Vector3(0.0, 0, -0.12)])
			if stage >= 3:
				_fruits(root, Color(0.78, 0.60, 0.34), 0.07, [Vector3(0.28, 0.07, 0.1), Vector3(-0.25, 0.07, -0.05), Vector3(0.05, 0.07, 0.3)])
		"strawberry":
			_bush(root, LEAF, 0.13 * g, [Vector3(0, 0, 0), Vector3(0.14, 0, 0.1), Vector3(-0.14, 0, 0.08), Vector3(0.05, 0, -0.14)])
			if stage == 2:
				_fruits(root, Color(1, 1, 1), 0.035, [Vector3(0.1, 0.2, 0.05), Vector3(-0.12, 0.18, 0.1), Vector3(0.0, 0.2, -0.1)])
			if stage >= 3:
				_fruits(root, Color(0.92, 0.16, 0.26), 0.065, [Vector3(0.16, 0.1, 0.18), Vector3(-0.2, 0.1, 0.14), Vector3(0.1, 0.12, -0.18), Vector3(-0.08, 0.1, 0.24), Vector3(0.24, 0.09, -0.04), Vector3(-0.22, 0.09, -0.12)])
		"corn":
			_add(root, _cyl(0.035, 1.0 * g), Vector3(0, 0.5 * g, 0), LEAF_D)
			_tuft(root, LEAF, 4, 0.55 * g, 0.5 * g, 0.9, 0.25 * g)
			_tuft(root, LEAF.lightened(0.1), 4, 0.45 * g, 0.4 * g, 1.0, 0.55 * g)
			if stage >= 3:
				for d in [Vector3(0.09, 0.58, 0.04), Vector3(-0.09, 0.5, -0.04)]:
					var cob := MeshInstance3D.new()
					var cm := CapsuleMesh.new()
					cm.radius = 0.055
					cm.height = 0.3
					cob.mesh = cm
					cob.material_override = mat(Color(0.98, 0.84, 0.25))
					cob.position = d
					cob.rotation = Vector3(0.0, 0.0, -0.25 if d.x > 0 else 0.25)
					root.add_child(cob)
				_add(root, _cone(0.05, 0.16), Vector3(0, 1.04, 0), Color(0.95, 0.85, 0.35))
		"tomato":
			_add(root, _cyl(0.015, 0.85 * g), Vector3(0.0, 0.42 * g, 0.0), Color(0.55, 0.38, 0.2))
			_bush(root, LEAF, 0.16 * g, [Vector3(0.06, 0, 0), Vector3(-0.06, 0.2 * g, 0.04), Vector3(0.05, 0.4 * g, -0.03)])
			if stage == 2:
				_fruits(root, Color(0.55, 0.78, 0.30), 0.05, [Vector3(0.16, 0.25, 0.05), Vector3(-0.14, 0.42, 0.08), Vector3(0.08, 0.2, -0.14)])
			if stage >= 3:
				_fruits(root, Color(0.90, 0.18, 0.14), 0.07, [Vector3(0.17, 0.25, 0.05), Vector3(-0.16, 0.45, 0.08), Vector3(0.1, 0.2, -0.15), Vector3(0.14, 0.55, 0.0), Vector3(-0.12, 0.2, -0.1)])
		"pumpkin":
			for i in 4:
				var a := TAU * i / 4.0 + 0.5
				_add(root, _cyl(0.17 * g, 0.02), Vector3(cos(a) * 0.3 * g, 0.05, sin(a) * 0.3 * g), LEAF)
			if stage == 2:
				_add(root, _ball(0.11), Vector3(0, 0.1, 0), Color(0.55, 0.72, 0.28), Vector3(1, 0.8, 1))
			if stage >= 3:
				_add(root, _ball(0.27), Vector3(0, 0.2, 0), Color(0.96, 0.54, 0.12), Vector3(1, 0.75, 1))
				_add(root, _cyl(0.035, 0.1), Vector3(0, 0.42, 0), Color(0.35, 0.5, 0.2))
		"melon":
			for i in 4:
				var a := TAU * i / 4.0 + 0.2
				_add(root, _cyl(0.16 * g, 0.02), Vector3(cos(a) * 0.3 * g, 0.05, sin(a) * 0.3 * g), LEAF_D)
			if stage == 2:
				_add(root, _ball(0.11), Vector3(0, 0.1, 0), Color(0.45, 0.68, 0.30))
			if stage >= 3:
				_add(root, _ball(0.26), Vector3(0, 0.26, 0), Color(0.34, 0.66, 0.28))
				for k in 3:
					var a := TAU * k / 3.0
					_add(root, _ball(0.09), Vector3(cos(a) * 0.17, 0.3, sin(a) * 0.17), Color(0.20, 0.46, 0.20), Vector3(0.5, 1.4, 0.5))
		_:
			_tuft(root, LEAF, 4, 0.3 * g, 0.2 * g, 0.5)
	if stage >= 3:   # tanda siap panen
		var tip := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.05
		sm.height = 0.1
		tip.mesh = sm
		tip.material_override = mat(Color(1.0, 0.85, 0.25), true)
		tip.position = Vector3(0, 1.35 if id == "corn" else 0.95, 0)
		tip.name = "RipeMark"
		root.add_child(tip)
	root.scale = Vector3.ONE * PLANT_SCALE      # supaya tanaman terlihat jelas dari kamera atas
	return root
