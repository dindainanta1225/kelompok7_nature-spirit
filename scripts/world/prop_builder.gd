extends RefCounted
## PropBuilder - dekorasi kecil dari bangun dasar (pagar, sumur, orang-orangan sawah, tong, peti, jerami, tumpukan kayu,
## bangku, tiang lampu, bedeng bunga, semak, kotak surat, batu pijakan, bercak rumput). Semua fungsi mengembalikan Node3D
## yang bisa langsung di-add_child; origin = dasar benda di tanah. solid=true menambah tabrakan.

const WOOD := Color(0.50, 0.33, 0.17)
const WOOD_D := Color(0.36, 0.23, 0.12)
const WOOD_L := Color(0.66, 0.48, 0.28)
const STONE := Color(0.58, 0.58, 0.60)
const Realism := preload("res://scripts/world/realism.gd")

static var _mats := {}


static func mat(c: Color, glow := false) -> StandardMaterial3D:
	var key := c.to_html() + ("g" if glow else "")
	if not _mats.has(key):
		_mats[key] = Realism.detail(c, glow)               # material PBR bertekstur (kayu bergaris, normal map halus)
	return _mats[key]


static func box(parent: Node, size: Vector3, pos: Vector3, c: Color, rot_y := 0.0, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(c, glow)
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	return mi


static func cyl(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, c: Color, seg := 10) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func ball(parent: Node, r: float, pos: Vector3, c: Color, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	mi.mesh = sm
	mi.material_override = mat(c)
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func solid(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.position = pos
	sb.add_child(cs)
	parent.add_child(sb)


# ------------------------------------------------------------------ benda
static func fence(a: Vector3, b: Vector3, gap_at := -1.0) -> Node3D:
	var root := Node3D.new()
	var d := b - a
	var len := d.length()
	var yaw := atan2(d.x, d.z)
	var n := maxi(int(len / 1.2), 1)
	var dirv := d.normalized()
	for i in n + 1:
		var p := a + dirv * (len * float(i) / float(n))
		cyl(root, 0.06, 0.07, 0.85, Vector3(p.x, p.y + 0.42, p.z), WOOD_D, 6)
	for h in [0.30, 0.62]:
		var mid := (a + b) * 0.5
		box(root, Vector3(0.05, 0.08, len), Vector3(mid.x, mid.y + h, mid.z), WOOD, yaw)
	solid(root, Vector3(0.3, 1.0, len), Vector3((a.x + b.x) * 0.5, a.y + 0.5, (a.z + b.z) * 0.5))
	(root.get_child(root.get_child_count() - 1) as Node3D).rotation.y = yaw
	return root


static func well() -> Node3D:
	var root := Node3D.new()
	cyl(root, 0.85, 0.9, 0.7, Vector3(0, 0.35, 0), STONE, 14)
	cyl(root, 0.62, 0.62, 0.05, Vector3(0, 0.72, 0), Color(0.18, 0.35, 0.55), 14)
	for sx in [-1.0, 1.0]:
		box(root, Vector3(0.12, 1.7, 0.12), Vector3(0.8 * sx, 1.45, 0), WOOD_D)
	box(root, Vector3(1.9, 0.1, 0.12), Vector3(0, 2.25, 0), WOOD_D)
	var roof1 := box(root, Vector3(2.2, 0.08, 1.2), Vector3(0, 2.55, 0.32), Color(0.65, 0.28, 0.20))
	roof1.rotation.x = deg_to_rad(-28)
	var roof2 := box(root, Vector3(2.2, 0.08, 1.2), Vector3(0, 2.55, -0.32), Color(0.60, 0.25, 0.18))
	roof2.rotation.x = deg_to_rad(28)
	cyl(root, 0.06, 0.06, 1.7, Vector3(0, 1.75, 0), WOOD).rotation.z = PI * 0.5
	cyl(root, 0.14, 0.12, 0.2, Vector3(0, 1.3, 0), WOOD_L)
	solid(root, Vector3(1.8, 1.0, 1.8), Vector3(0, 0.5, 0))
	return root


static func scarecrow() -> Node3D:
	var root := Node3D.new()
	cyl(root, 0.05, 0.06, 2.0, Vector3(0, 1.0, 0), WOOD_D, 6)
	var arm := cyl(root, 0.045, 0.045, 1.5, Vector3(0, 1.45, 0), WOOD_D, 6)
	arm.rotation.z = PI * 0.5
	box(root, Vector3(0.6, 0.75, 0.3), Vector3(0, 1.3, 0), Color(0.78, 0.6, 0.30))                   # badan jerami
	box(root, Vector3(0.62, 0.35, 0.32), Vector3(0, 1.1, 0), Color(0.30, 0.45, 0.70))                # celana
	ball(root, 0.22, Vector3(0, 1.95, 0), Color(0.88, 0.72, 0.45))
	cyl(root, 0.40, 0.40, 0.04, Vector3(0, 2.12, 0), Color(0.80, 0.62, 0.30), 12)                    # topi
	cyl(root, 0.18, 0.22, 0.25, Vector3(0, 2.25, 0), Color(0.80, 0.62, 0.30), 12)
	box(root, Vector3(0.04, 0.04, 0.02), Vector3(0.07, 1.98, 0.21), Color.BLACK)
	box(root, Vector3(0.04, 0.04, 0.02), Vector3(-0.07, 1.98, 0.21), Color.BLACK)
	for sx in [-1.0, 1.0]:
		box(root, Vector3(0.18, 0.05, 0.05), Vector3(0.75 * sx, 1.40, 0), Color(0.78, 0.6, 0.30))
	solid(root, Vector3(0.5, 1.5, 0.5), Vector3(0, 0.75, 0))
	return root


static func barrel() -> Node3D:
	var root := Node3D.new()
	cyl(root, 0.38, 0.32, 0.9, Vector3(0, 0.45, 0), WOOD, 12)
	for y in [0.18, 0.72]:
		cyl(root, 0.40, 0.40, 0.05, Vector3(0, y, 0), Color(0.25, 0.25, 0.28), 12)
	cyl(root, 0.32, 0.32, 0.03, Vector3(0, 0.91, 0), WOOD_D, 12)
	solid(root, Vector3(0.75, 0.9, 0.75), Vector3(0, 0.45, 0))
	return root


static func crate(s := 0.8) -> Node3D:
	var root := Node3D.new()
	box(root, Vector3(s, s, s), Vector3(0, s * 0.5, 0), WOOD_L)
	for sx in [-1.0, 1.0]:
		box(root, Vector3(0.06, s + 0.02, s + 0.02), Vector3(sx * (s * 0.5 - 0.03), s * 0.5, 0), WOOD_D)
	box(root, Vector3(s + 0.02, 0.06, s + 0.02), Vector3(0, s - 0.03, 0), WOOD_D)
	solid(root, Vector3(s, s, s), Vector3(0, s * 0.5, 0))
	return root


static func hay_bale() -> Node3D:
	var root := Node3D.new()
	var c := cyl(root, 0.45, 0.45, 0.9, Vector3(0, 0.45, 0), Color(0.88, 0.74, 0.34), 14)
	c.rotation.z = PI * 0.5
	for x in [-0.25, 0.25]:
		cyl(root, 0.46, 0.46, 0.04, Vector3(x, 0.45, 0), Color(0.6, 0.45, 0.2), 14).rotation.z = PI * 0.5
	solid(root, Vector3(0.9, 0.9, 0.9), Vector3(0, 0.45, 0))
	return root


static func woodpile() -> Node3D:
	var root := Node3D.new()
	var rows := [[0.16, 4], [0.44, 3], [0.72, 2]]
	for r in rows:
		var n: int = r[1]
		for i in n:
			var x := (float(i) - float(n - 1) * 0.5) * 0.34
			var l := cyl(root, 0.15, 0.15, 1.2, Vector3(x, float(r[0]), 0), WOOD if i % 2 == 0 else WOOD_D, 8)
			l.rotation.x = PI * 0.5
			cyl(root, 0.12, 0.12, 0.02, Vector3(x, float(r[0]), 0.6), Color(0.82, 0.66, 0.42), 8).rotation.x = PI * 0.5
	solid(root, Vector3(1.5, 0.9, 1.2), Vector3(0, 0.45, 0))
	return root


static func bench() -> Node3D:
	var root := Node3D.new()
	box(root, Vector3(1.6, 0.08, 0.5), Vector3(0, 0.5, 0), WOOD)
	box(root, Vector3(1.6, 0.4, 0.07), Vector3(0, 0.82, -0.22), WOOD)
	for sx in [-1.0, 1.0]:
		box(root, Vector3(0.08, 0.5, 0.45), Vector3(0.7 * sx, 0.25, 0), WOOD_D)
	solid(root, Vector3(1.6, 0.9, 0.55), Vector3(0, 0.45, 0))
	return root


static func lamp_post() -> Node3D:
	var root := Node3D.new()
	cyl(root, 0.05, 0.07, 2.4, Vector3(0, 1.2, 0), Color(0.18, 0.16, 0.16), 8)
	box(root, Vector3(0.3, 0.38, 0.3), Vector3(0, 2.55, 0), Color(1.0, 0.86, 0.5), 0.0, true)
	box(root, Vector3(0.4, 0.06, 0.4), Vector3(0, 2.78, 0), Color(0.18, 0.16, 0.16))
	var l := OmniLight3D.new()
	l.position = Vector3(0, 2.55, 0)
	l.light_color = Color(1.0, 0.85, 0.55)
	l.light_energy = 0.5
	l.omni_range = 5.0
	root.add_child(l)
	solid(root, Vector3(0.2, 2.4, 0.2), Vector3(0, 1.2, 0))
	return root


static func flower_bed(w := 2.0, d := 0.8, seed_v := 1) -> Node3D:
	var root := Node3D.new()
	box(root, Vector3(w, 0.18, d), Vector3(0, 0.09, 0), Color(0.38, 0.26, 0.15))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var cols := [Color(0.95, 0.35, 0.40), Color(1.0, 0.85, 0.30), Color(0.75, 0.45, 0.95), Color(1.0, 0.6, 0.75), Color(1.0, 1.0, 1.0)]
	for i in int(w * 5.0):
		var x := rng.randf_range(-w * 0.45, w * 0.45)
		var z := rng.randf_range(-d * 0.38, d * 0.38)
		cyl(root, 0.012, 0.012, 0.3, Vector3(x, 0.32, z), Color(0.25, 0.55, 0.25), 4)
		ball(root, 0.07, Vector3(x, 0.5, z), cols[rng.randi() % cols.size()], Vector3(1, 0.7, 1))
	return root


static func bush(r := 0.7, c := Color(0.30, 0.55, 0.28)) -> Node3D:
	var root := Node3D.new()
	ball(root, r, Vector3(0, r * 0.65, 0), c, Vector3(1.2, 0.85, 1.0))
	ball(root, r * 0.75, Vector3(r * 0.7, r * 0.5, 0.15), c.lightened(0.06), Vector3(1.0, 0.8, 1.0))
	ball(root, r * 0.7, Vector3(-r * 0.6, r * 0.45, -0.1), c.darkened(0.06), Vector3(1.0, 0.8, 1.0))
	return root


static func mailbox() -> Node3D:
	var root := Node3D.new()
	cyl(root, 0.05, 0.05, 1.0, Vector3(0, 0.5, 0), WOOD_D, 6)
	box(root, Vector3(0.45, 0.3, 0.3), Vector3(0, 1.1, 0), Color(0.75, 0.2, 0.2))
	box(root, Vector3(0.04, 0.2, 0.04), Vector3(0.24, 1.25, 0.0), Color(0.95, 0.85, 0.2))
	solid(root, Vector3(0.4, 1.1, 0.4), Vector3(0, 0.55, 0))
	return root


static func cart() -> Node3D:
	var root := Node3D.new()
	box(root, Vector3(1.8, 0.1, 1.0), Vector3(0, 0.6, 0), WOOD)
	for sz in [-1.0, 1.0]:
		box(root, Vector3(1.8, 0.4, 0.07), Vector3(0, 0.82, 0.5 * sz), WOOD_D)
	for sx in [-1.0, 1.0]:
		box(root, Vector3(0.07, 0.4, 1.0), Vector3(0.9 * sx, 0.82, 0), WOOD_D)
		var w := cyl(root, 0.4, 0.4, 0.07, Vector3(0.0, 0.4, 0.58 * sx), WOOD_D, 14)
		w.rotation.x = PI * 0.5
	box(root, Vector3(0.1, 0.08, 1.4), Vector3(0, 0.4, 0), WOOD_D)
	var tongue := box(root, Vector3(1.4, 0.06, 0.08), Vector3(-1.5, 0.5, 0), WOOD_D)
	tongue.rotation.z = deg_to_rad(8)
	for i in 5:
		ball(root, 0.2, Vector3(-0.5 + i * 0.25, 0.85, (i % 2) * 0.2 - 0.1), Color(0.86, 0.35, 0.18) if i % 2 == 0 else Color(0.35, 0.65, 0.25))
	solid(root, Vector3(1.9, 1.0, 1.2), Vector3(0, 0.5, 0))
	return root


## Batu pijakan (jalan setapak) dari titik a ke b.
static func stepping_stones(a: Vector3, b: Vector3, spacing := 0.95, seed_v := 3) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var d := b - a
	var n := maxi(int(d.length() / spacing), 1)
	for i in n + 1:
		var p := a + d * (float(i) / float(n))
		var side := Vector3(-d.z, 0, d.x).normalized() * rng.randf_range(-0.18, 0.18)
		var s := cyl(root, rng.randf_range(0.34, 0.46), rng.randf_range(0.36, 0.48), 0.05, Vector3(p.x + side.x, p.y + 0.025, p.z + side.z), STONE.lightened(rng.randf_range(-0.1, 0.1)), 9)
		s.rotation.y = rng.randf() * TAU
	return root


## Bercak warna rumput/tanah agar tanah tidak seragam. rect = Rect2(x, z, w, h).
static func lawn_patches(rect: Rect2, ground_y: float, count: int, seed_v := 5, palette := []) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	if palette.is_empty():
		palette = [Color(0.40, 0.58, 0.27), Color(0.33, 0.50, 0.23), Color(0.47, 0.62, 0.28), Color(0.52, 0.48, 0.28), Color(0.30, 0.47, 0.22), Color(0.43, 0.55, 0.26)]
	for i in count:
		var p := Vector3(rect.position.x + rng.randf() * rect.size.x, ground_y + 0.013 + i * 0.00005, rect.position.y + rng.randf() * rect.size.y)
		var r := rng.randf_range(0.8, 2.6)
		var c := cyl(root, r, r, 0.004, p, palette[rng.randi() % palette.size()], 14)
		c.scale = Vector3(1.0, 1.0, rng.randf_range(0.6, 1.0))
		c.rotation.y = rng.randf() * TAU
	return root


## Warna lebih natural (tidak terlalu neon): tonemap filmik, saturasi diturunkan, kabut tipis, ambient hangat.
static func grade_environment(env: Environment) -> void:
	if env == null:
		return
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.9
	env.adjustment_contrast = 1.06
	env.adjustment_brightness = 0.97
	env.fog_enabled = false
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.82, 0.86, 0.92)
	env.ambient_light_energy = 0.42
	env.glow_enabled = false


## Hamparan rumput warna natural di atas tile (menutupi warna tile yang terlalu neon). rect = Rect2(x, z, w, h).
static func lawn_base(rect: Rect2, ground_y: float, c := Color(0.36, 0.55, 0.25)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(rect.size.x, 0.01, rect.size.y)
	mi.mesh = bm
	mi.material_override = Realism.ground(Color(clampf(c.r / 0.36, 0.4, 1.4), clampf(c.g / 0.55, 0.4, 1.4), clampf(c.b / 0.25, 0.4, 1.4)))
	mi.position = Vector3(rect.position.x + rect.size.x * 0.5, ground_y + 0.005, rect.position.y + rect.size.y * 0.5)
	return mi
