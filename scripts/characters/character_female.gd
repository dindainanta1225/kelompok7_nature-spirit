extends Node3D
class_name CharacterFemale
## Karakter cewe chibi (seragam, rambut hitam, mata biru besar) low-poly, dibuat murni dari kode + animasi.
## Hadap default: +Z. Titik origin = telapak kaki. Chibi, tinggi ± 1.15 m.
##   play_anim("idle" | "walk" | "tool" | "celebrate")
## Ganti warna lewat properti (hair_color, dress_color, dst) SEBELUM masuk tree.

@export var skin_color := Color("fbd5b5")
@export var hair_color := Color("1d1722")
@export var dress_color := Color("2c3a6b")
@export var apron_color := Color("f6f1ea")
@export var boot_color := Color("3a2a2e")
@export var hat_color := Color("5aa0e8")
@export var ribbon_color := Color("d9404a")
@export var sock_color := Color("f4f1f8")
@export var eye_color := Color("4a8fe0")
@export var blush_color := Color("f5929a")
@export var streak_color := Color("e0384a")
@export var streak2_color := Color("3f8fe8")

var anim: AnimationPlayer
var body: Node3D
var head: Node3D
var leg_l: Node3D
var leg_r: Node3D
var arm_l: Node3D
var arm_r: Node3D
var tail: Node3D
var _current := ""
var _fainted := false
var _props := {}                  # nama -> Node3D (alat di tangan kanan, tampil saat dipakai)
var _water: CPUParticles3D


func _ready() -> void:
	_build()
	_build_props()
	_build_animations()
	play_anim("idle")


# ---------------------------------------------------------------- helpers
const BioMat := preload("res://scripts/world/bio_mat.gd")
const METALS := ["9aa0aa", "d8dde6", "aab2c0", "c9a030"]
const WOODS := ["8a5a30", "5a3a22"]


## Pilih material PBR sesuai peran warna: kulit (SSS), rambut (kilau), mata (basah), sepatu (kulit), logam, kayu, sisanya kain.
func _mat(c: Color, rough := 0.85) -> StandardMaterial3D:
	if c == skin_color:
		return BioMat.skin(c)
	if c == blush_color:
		return BioMat.skin(c, 0.6)
	if c == hair_color or c == streak_color or c == streak2_color:
		return BioMat.hair(c)
	if c == boot_color:
		return BioMat.leather(c)
	if c == Color.WHITE or c == eye_color or c == Color("17202e"):
		return BioMat.eye(c)
	var hx := c.to_html(false)
	if hx in METALS:
		return BioMat.metal(c)
	if hx in WOODS:
		return BioMat.wood(c)
	return BioMat.cloth(c)


func _add(parent: Node3D, mesh: Mesh, c: Color, pos := Vector3.ZERO, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	if c == hair_color or c == streak_color or c == streak2_color:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF      # rambut tidak menjatuhkan bayangan bergaris di wajah
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 40
	s.rings = 20
	return s


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 24
	c.rings = 8
	return c


func _cyl(rt: float, rb: float, h: float, seg := 24) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = seg
	return c


func _pivot(parent: Node3D, n: String, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = n
	p.position = pos
	parent.add_child(p)
	return p


# ---------------------------------------------------------------- model (chibi)
const HIP := 0.5                   # tinggi pinggul dari tanah (kaki pendek ala chibi)

func _build() -> void:
	# Kaki
	for side in [-1, 1]:
		var leg := _pivot(self, "LegL" if side < 0 else "LegR", Vector3(0.085 * side, HIP, 0))
		_add(leg, _capsule(0.055, 0.40), skin_color, Vector3(0, -0.22, 0))
		_add(leg, _cyl(0.07, 0.075, 0.12), sock_color, Vector3(0, -0.34, 0))
		_add(leg, _sphere(0.085), boot_color, Vector3(0, -0.44, 0.03), Vector3(1, 0.62, 1.45))
		if side < 0: leg_l = leg
		else: leg_r = leg

	body = _pivot(self, "Body", Vector3(0, HIP, 0))
	# Rok + blus seragam
	_add(body, _cyl(0.15, 0.27, 0.24), dress_color, Vector3(0, -0.02, 0))
	_add(body, _cyl(0.15, 0.17, 0.30), apron_color, Vector3(0, 0.23, 0))
	_add(body, _cyl(0.175, 0.175, 0.035), dress_color, Vector3(0, 0.37, 0), Vector3(1, 1, 1))          # kerah laut
	_add(body, _cyl(0.17, 0.17, 0.03), ribbon_color, Vector3(0, 0.10, 0))                             # sabuk
	# Pita dada
	_add(body, _sphere(0.045), ribbon_color, Vector3(-0.05, 0.33, 0.145), Vector3(1.3, 0.9, 0.6))
	_add(body, _sphere(0.045), ribbon_color, Vector3(0.05, 0.33, 0.145), Vector3(1.3, 0.9, 0.6))
	_add(body, _sphere(0.03), ribbon_color.darkened(0.2), Vector3(0, 0.33, 0.16), Vector3(1, 1, 0.8))
	# Leher
	_add(body, _cyl(0.04, 0.04, 0.06), skin_color, Vector3(0, 0.42, 0))

	# Lengan
	for side in [-1, 1]:
		var arm := _pivot(body, "ArmL" if side < 0 else "ArmR", Vector3(0.19 * side, 0.36, 0))
		_add(arm, _sphere(0.06), apron_color, Vector3.ZERO)
		_add(arm, _capsule(0.045, 0.34), skin_color, Vector3(0, -0.17, 0))
		_add(arm, _cyl(0.06, 0.065, 0.14), apron_color, Vector3(0, -0.08, 0))
		_add(arm, _sphere(0.05), skin_color, Vector3(0, -0.36, 0))
		if side < 0: arm_l = arm
		else: arm_r = arm

	# Kepala besar
	head = _pivot(body, "Head", Vector3(0, 0.72, 0))
	_add(head, _sphere(0.30), skin_color, Vector3.ZERO, Vector3(1.05, 0.95, 0.97))
	# Rambut hitam
	_add(head, _sphere(0.315), hair_color, Vector3(0, 0.035, -0.05), Vector3(1.06, 1.0, 1.0))
	_add(head, _sphere(0.30), hair_color, Vector3(0, 0.13, 0.04), Vector3(1.05, 0.62, 1.0))              # poni atas
	for sx in [-1.0, 1.0]:
		_add(head, _capsule(0.045, 0.30), hair_color, Vector3(0.265 * sx, -0.08, 0.06), Vector3(1, 1, 1))   # rambut samping
		_add(head, _sphere(0.07), hair_color, Vector3(0.10 * sx, 0.12, 0.25), Vector3(1.4, 1.5, 0.5), Vector3(0, 0, -22 * sx))  # poni depan
	_add(head, _capsule(0.018, 0.2), streak_color, Vector3(0.27, -0.06, 0.10))                         # helai merah
	_add(head, _capsule(0.018, 0.16), streak2_color, Vector3(-0.275, -0.03, 0.10))                      # helai biru
	# Mata besar berkilau
	for sx in [-1.0, 1.0]:
		_add(head, _sphere(0.062), Color.WHITE, Vector3(0.105 * sx, -0.03, 0.262), Vector3(1.0, 1.35, 0.32))
		_add(head, _sphere(0.052), eye_color, Vector3(0.105 * sx, -0.035, 0.278), Vector3(1.0, 1.35, 0.3))
		_add(head, _sphere(0.028), Color("17202e"), Vector3(0.105 * sx, -0.04, 0.287), Vector3(1.0, 1.4, 0.3))
		_add(head, _sphere(0.016), Color.WHITE, Vector3(0.105 * sx - 0.016 * sx, 0.005, 0.292), Vector3(1, 1, 0.3))
		_add(head, _sphere(0.045), blush_color, Vector3(0.17 * sx, -0.11, 0.22), Vector3(1.2, 0.65, 0.35))     # pipi
		_add(head, _capsule(0.012, 0.075), Color("1b1216"), Vector3(0.105 * sx, 0.047, 0.272), Vector3.ONE, Vector3(0, 0, 90))  # garis kelopak
	_add(head, _sphere(0.016), Color("b5524a"), Vector3(0, -0.14, 0.275), Vector3(1.5, 0.6, 0.4))         # mulut
	# detail wajah realistis: hidung, telinga, alis, bulu mata, bibir atas
	_add(head, _sphere(0.02), skin_color.darkened(0.04), Vector3(0, -0.085, 0.292), Vector3(0.9, 1.0, 0.8))   # hidung
	for sx in [-1.0, 1.0]:
		_add(head, _sphere(0.045), skin_color, Vector3(0.30 * sx, -0.03, 0.0), Vector3(0.45, 1.0, 0.7))       # telinga
		_add(head, _capsule(0.009, 0.09), hair_color.darkened(0.1), Vector3(0.108 * sx, 0.085, 0.27), Vector3.ONE, Vector3(0, 0, 90 - 8 * sx))  # alis
		_add(head, _capsule(0.006, 0.05), Color("1b1216"), Vector3(0.155 * sx, 0.035, 0.268), Vector3.ONE, Vector3(0, 0, 90 + 35 * sx))        # bulu mata
	_add(head, _sphere(0.013), Color("c9665c"), Vector3(0, -0.152, 0.272), Vector3(1.6, 0.4, 0.4))            # bibir bawah
	# Kuncir + pita
	tail = _pivot(head, "Tail", Vector3(0, 0.1, -0.30))
	_add(tail, _sphere(0.05), ribbon_color, Vector3.ZERO)
	_add(tail, _capsule(0.07, 0.34), hair_color, Vector3(0, -0.19, -0.04), Vector3.ONE, Vector3(-12, 0, 0))
	_add(head, _sphere(0.034), hat_color, Vector3(-0.2, 0.2, 0.15), Vector3(1.2, 0.8, 0.6))              # jepit rambut


# ---------------------------------------------------------------- alat di tangan
func _prop(n: String) -> Node3D:
	var p := Node3D.new()
	p.name = n
	p.position = Vector3(0, -0.36, 0)             # telapak tangan
	p.visible = false
	arm_r.add_child(p)
	_props[n] = p
	return p


func _build_props() -> void:
	var wood := Color("8a5a30")
	var iron := Color("9aa0aa")
	# cangkul: gagang memanjang searah lengan, mata cangkul tegak lurus di ujung
	var hoe := _prop("PropHoe")
	_add(hoe, _cyl(0.025, 0.025, 1.0, 8), wood, Vector3(0, -0.42, 0))
	_add(hoe, _box(0.30, 0.04, 0.20), iron, Vector3(0, -0.93, 0.10))
	# sabit (scythe): gagang panjang + bilah melengkung
	var sc := _prop("PropScythe")
	_add(sc, _cyl(0.022, 0.022, 1.1, 8), wood, Vector3(0, -0.45, 0))
	for i in 6:
		var a := float(i) / 5.0
		_add(sc, _box(0.13, 0.035, 0.02), iron, Vector3(0.0, -0.98 + a * 0.05, 0.05 + a * 0.30), Vector3.ONE, Vector3(-30.0 + a * 70.0, 0, 0))
	# pedang: gagang + pelindung + bilah baja (searah lengan)
	var sw := _prop("PropSword")
	_add(sw, _cyl(0.025, 0.025, 0.22, 8), Color("5a3a22"), Vector3(0, -0.02, 0))
	_add(sw, _box(0.24, 0.04, 0.06), Color("c9a030"), Vector3(0, -0.15, 0))
	_add(sw, _box(0.07, 0.78, 0.018), Color("d8dde6"), Vector3(0, -0.56, 0))
	_add(sw, _box(0.03, 0.78, 0.022), Color("aab2c0"), Vector3(0, -0.56, 0))
	_add(sw, _box(0.07, 0.07, 0.018), Color("d8dde6"), Vector3(0, -0.97, 0), Vector3.ONE, Vector3(0, 0, 45))
	# penyiram: badan kaleng + corong
	var can := _prop("PropCan")
	_add(can, _cyl(0.10, 0.12, 0.20, 12), Color("5a8fc8"), Vector3(0, -0.10, 0.10))
	_add(can, _cyl(0.02, 0.03, 0.30, 8), Color("5a8fc8"), Vector3(0, -0.02, 0.30), Vector3.ONE, Vector3(-65, 0, 0))
	_add(can, _box(0.03, 0.18, 0.03), Color("3f6fa0"), Vector3(0, -0.06, -0.02))
	_water = CPUParticles3D.new()
	_water.name = "Water"
	_water.position = Vector3(0, -0.05, 0.50)
	_water.emitting = false
	_water.amount = 26
	_water.lifetime = 0.5
	_water.direction = Vector3(0, -0.3, 1)
	_water.spread = 14.0
	_water.initial_velocity_min = 1.2
	_water.initial_velocity_max = 1.8
	_water.gravity = Vector3(0, -9.0, 0)
	var pm := SphereMesh.new()
	pm.radius = 0.018
	pm.height = 0.036
	pm.radial_segments = 6
	pm.rings = 3
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.55, 0.78, 1.0)
	wm.emission_enabled = true
	wm.emission = Color(0.45, 0.7, 1.0)
	pm.material = wm
	_water.mesh = pm
	can.add_child(_water)
	# benih di tangan
	var seed_p := _prop("PropSeed")
	_add(seed_p, _sphere(0.045), Color("c9a063"), Vector3(0, -0.04, 0.05))
	_add(seed_p, _sphere(0.03), Color("e0c080"), Vector3(0.05, -0.06, 0.02))
	# hasil panen di tangan
	var prod := _prop("PropProduce")
	_add(prod, _sphere(0.10), Color("e8832a"), Vector3(0, -0.08, 0.05))
	_add(prod, _cone_up(0.05, 0.10), Color("4aa03a"), Vector3(0, 0.0, 0.05))


func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func _cone_up(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 6
	return c


# ---------------------------------------------------------------- animations
func V(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)


func _track(a: Animation, path: String, times: Array, vals: Array) -> void:
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(path))
	a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC if a.loop_mode == Animation.LOOP_LINEAR else Animation.INTERPOLATION_LINEAR)
	for i in times.size():
		a.track_insert_key(t, times[i], vals[i])


func _build_animations() -> void:
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	add_child(anim)
	anim.root_node = anim.get_path_to(self)
	var lib := AnimationLibrary.new()

	# --- idle: napas pelan, lengan goyang tipis, ekor kuda bergoyang
	var idle := Animation.new()
	idle.length = 2.4
	idle.loop_mode = Animation.LOOP_LINEAR
	_track(idle, "Body:position", [0.0, 1.2, 2.4], [V(0, HIP, 0), V(0, HIP + 0.015, 0), V(0, HIP, 0)])
	# kaki & badan SELALU kembali tegak saat diam (sebelumnya berhenti di tengah langkah)
	_track(idle, "LegL:rotation_degrees", [0.0, 2.4], [V(0, 0, 0), V(0, 0, 0)])
	_track(idle, "LegR:rotation_degrees", [0.0, 2.4], [V(0, 0, 0), V(0, 0, 0)])
	_track(idle, "Body:rotation_degrees", [0.0, 2.4], [V(0, 0, 0), V(0, 0, 0)])
	_track(idle, "Body/ArmL:rotation_degrees", [0.0, 1.2, 2.4], [V(0, 0, 4), V(2, 0, 7), V(0, 0, 4)])
	_track(idle, "Body/ArmR:rotation_degrees", [0.0, 1.2, 2.4], [V(0, 0, -4), V(2, 0, -7), V(0, 0, -4)])
	_track(idle, "Body/Head:rotation_degrees", [0.0, 0.8, 1.6, 2.4], [V(0, 0, 0), V(2, 6, 1), V(0, -5, -1), V(0, 0, 0)])
	_track(idle, "Body/Head/Tail:rotation_degrees", [0.0, 1.2, 2.4], [V(0, 0, -5), V(0, 0, 5), V(0, 0, -5)])
	lib.add_animation("idle", idle)

	# --- walk: ayun kaki & lengan berlawanan, badan naik-turun
	var walk := Animation.new()
	walk.length = 0.64
	walk.loop_mode = Animation.LOOP_LINEAR
	var h := walk.length
	var w := [0.0, h * 0.25, h * 0.5, h * 0.75, h]
	_track(walk, "LegL:rotation_degrees", w, [V(32, 0, 0), V(0, 0, 0), V(-32, 0, 0), V(0, 0, 0), V(32, 0, 0)])
	_track(walk, "LegR:rotation_degrees", w, [V(-32, 0, 0), V(0, 0, 0), V(32, 0, 0), V(0, 0, 0), V(-32, 0, 0)])
	_track(walk, "Body/ArmL:rotation_degrees", w, [V(-34, 0, 6), V(0, 0, 6), V(34, 0, 6), V(0, 0, 6), V(-34, 0, 6)])
	_track(walk, "Body/ArmR:rotation_degrees", w, [V(34, 0, -6), V(0, 0, -6), V(-34, 0, -6), V(0, 0, -6), V(34, 0, -6)])
	_track(walk, "Body:position", w, [V(0, HIP, 0), V(0, HIP + 0.035, 0), V(0, HIP, 0), V(0, HIP + 0.035, 0), V(0, HIP, 0)])
	_track(walk, "Body:rotation_degrees", w, [V(4, 5, 0), V(4, 0, 0), V(4, -5, 0), V(4, 0, 0), V(4, 5, 0)])
	_track(walk, "Body/Head:rotation_degrees", w, [V(-3, -5, 0), V(-3, 0, 0), V(-3, 5, 0), V(-3, 0, 0), V(-3, -5, 0)])
	_track(walk, "Body/Head/Tail:rotation_degrees", w, [V(18, 0, 8), V(8, 0, 0), V(18, 0, -8), V(8, 0, 0), V(18, 0, 8)])
	lib.add_animation("walk", walk)

	# --- tool: ayun alat (cangkul/sabit/siram) – angkat lalu hentak
	var tool := Animation.new()
	tool.length = 0.55
	tool.loop_mode = Animation.LOOP_NONE
	var tt := [0.0, 0.18, 0.3, 0.42, 0.55]
	_track(tool, "Body/ArmR:rotation_degrees", tt, [V(0, 0, -6), V(-150, 0, -8), V(-40, 0, -8), V(-30, 0, -8), V(0, 0, -6)])
	_track(tool, "Body/ArmL:rotation_degrees", tt, [V(0, 0, 6), V(-110, 0, 10), V(-30, 0, 10), V(-25, 0, 10), V(0, 0, 6)])
	_track(tool, "Body:rotation_degrees", tt, [V(0, 0, 0), V(-8, 0, 0), V(24, 0, 0), V(18, 0, 0), V(0, 0, 0)])
	_track(tool, "Body/Head:rotation_degrees", tt, [V(0, 0, 0), V(-5, 0, 0), V(12, 0, 0), V(8, 0, 0), V(0, 0, 0)])
	_track(tool, "LegL:rotation_degrees", tt, [V(0, 0, 0), V(-6, 0, 0), V(10, 0, 0), V(8, 0, 0), V(0, 0, 0)])
	_track(tool, "LegR:rotation_degrees", tt, [V(0, 0, 0), V(6, 0, 0), V(-8, 0, 0), V(-6, 0, 0), V(0, 0, 0)])
	lib.add_animation("tool", tool)

	# --- celebrate: lompat + dua tangan ke atas
	var cel := Animation.new()
	cel.length = 1.0
	cel.loop_mode = Animation.LOOP_LINEAR
	var cc := [0.0, 0.25, 0.5, 0.75, 1.0]
	_track(cel, "Body/ArmL:rotation_degrees", cc, [V(-20, 0, 20), V(-170, 0, 20), V(-20, 0, 20), V(-170, 0, 20), V(-20, 0, 20)])
	_track(cel, "Body/ArmR:rotation_degrees", cc, [V(-20, 0, -20), V(-170, 0, -20), V(-20, 0, -20), V(-170, 0, -20), V(-20, 0, -20)])
	_track(cel, "Body:position", cc, [V(0, HIP, 0), V(0, HIP + 0.25, 0), V(0, HIP, 0), V(0, HIP + 0.25, 0), V(0, HIP, 0)])
	_track(cel, "LegL:position", cc, [V(-0.085, HIP, 0), V(-0.085, HIP + 0.25, 0), V(-0.085, HIP, 0), V(-0.085, HIP + 0.25, 0), V(-0.085, HIP, 0)])
	_track(cel, "LegR:position", cc, [V(0.085, HIP, 0), V(0.085, HIP + 0.25, 0), V(0.085, HIP, 0), V(0.085, HIP + 0.25, 0), V(0.085, HIP, 0)])
	_track(cel, "Body/Head/Tail:rotation_degrees", cc, [V(0, 0, -10), V(25, 0, 10), V(0, 0, -10), V(25, 0, 10), V(0, 0, -10)])
	lib.add_animation("celebrate", cel)


	# --- aksi-aksi pertanian (masing-masing beda gerakan + alat sendiri)
	_make_action_anims(lib)

	anim.add_animation_library("", lib)
	anim.animation_finished.connect(_on_finished)


func _anim(length: float) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_NONE
	return a


## Tampilkan alat `prop_name` selama animasi (di luar itu semua alat tersembunyi).
func _show_prop(a: Animation, prop_name: String) -> void:
	for n in _props.keys():
		var t := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(t, NodePath("Body/ArmR/%s:visible" % n))
		a.track_set_interpolation_type(t, Animation.INTERPOLATION_NEAREST)
		a.track_insert_key(t, 0.0, n == prop_name)
		a.track_insert_key(t, a.length, false)


func _make_action_anims(lib: AnimationLibrary) -> void:
	# CANGKUL: angkat tinggi di atas kepala, hentak ke tanah dua kali
	var hoe := _anim(0.8)
	var t1 := [0.0, 0.22, 0.34, 0.46, 0.62, 0.72, 0.8]
	_track(hoe, "Body/ArmR:rotation_degrees", t1, [V(0, 0, -6), V(-165, 0, -8), V(-42, 0, -8), V(-120, 0, -8), V(-42, 0, -8), V(-30, 0, -8), V(0, 0, -6)])
	_track(hoe, "Body/ArmL:rotation_degrees", t1, [V(0, 0, 6), V(-150, 0, 14), V(-40, 0, 14), V(-110, 0, 14), V(-40, 0, 14), V(-30, 0, 10), V(0, 0, 6)])
	_track(hoe, "Body:rotation_degrees", t1, [V(0, 0, 0), V(-10, 0, 0), V(28, 0, 0), V(-6, 0, 0), V(30, 0, 0), V(20, 0, 0), V(0, 0, 0)])
	_track(hoe, "Body:position", t1, [V(0, HIP, 0), V(0, HIP + 0.03, 0), V(0, HIP - 0.06, 0), V(0, HIP + 0.02, 0), V(0, HIP - 0.07, 0), V(0, HIP - 0.03, 0), V(0, HIP, 0)])
	_track(hoe, "Body/Head:rotation_degrees", t1, [V(0, 0, 0), V(-8, 0, 0), V(14, 0, 0), V(-4, 0, 0), V(14, 0, 0), V(8, 0, 0), V(0, 0, 0)])
	_show_prop(hoe, "PropHoe")
	lib.add_animation("hoe", hoe)

	# SIRAM: condong ke depan, tangan kanan menjulur, kaleng dimiringkan
	var wat := _anim(1.0)
	var t2 := [0.0, 0.2, 0.35, 0.8, 1.0]
	_track(wat, "Body/ArmR:rotation_degrees", t2, [V(0, 0, -6), V(-70, 0, -12), V(-82, 0, -12), V(-82, 0, -12), V(0, 0, -6)])
	_track(wat, "Body/ArmL:rotation_degrees", t2, [V(0, 0, 6), V(-30, 0, 24), V(-36, 0, 24), V(-36, 0, 24), V(0, 0, 6)])
	_track(wat, "Body:rotation_degrees", t2, [V(0, 0, 0), V(8, 0, 0), V(14, 0, 0), V(14, 0, 0), V(0, 0, 0)])
	_track(wat, "Body/Head:rotation_degrees", t2, [V(0, 0, 0), V(8, 0, 0), V(12, 0, 0), V(12, 0, 0), V(0, 0, 0)])
	_track(wat, "Body/ArmR/PropCan:rotation_degrees", t2, [V(0, 0, 0), V(0, 0, 0), V(38, 0, 0), V(38, 0, 0), V(0, 0, 0)])
	_show_prop(wat, "PropCan")
	lib.add_animation("water", wat)

	# TANAM: jongkok, tangan menyentuh tanah, tepuk-tepuk
	var pla := _anim(0.9)
	var t3 := [0.0, 0.25, 0.4, 0.55, 0.7, 0.9]
	_track(pla, "Body:position", t3, [V(0, HIP, 0), V(0, HIP - 0.17, 0.05), V(0, HIP - 0.17, 0.05), V(0, HIP - 0.17, 0.05), V(0, HIP - 0.17, 0.05), V(0, HIP, 0)])
	_track(pla, "Body:rotation_degrees", t3, [V(0, 0, 0), V(34, 0, 0), V(38, 0, 0), V(34, 0, 0), V(38, 0, 0), V(0, 0, 0)])
	_track(pla, "LegL:rotation_degrees", t3, [V(0, 0, 0), V(-34, 0, 0), V(-34, 0, 0), V(-34, 0, 0), V(-34, 0, 0), V(0, 0, 0)])
	_track(pla, "LegR:rotation_degrees", t3, [V(0, 0, 0), V(-34, 0, 0), V(-34, 0, 0), V(-34, 0, 0), V(-34, 0, 0), V(0, 0, 0)])
	_track(pla, "Body/ArmR:rotation_degrees", t3, [V(0, 0, -6), V(-62, 0, -8), V(-76, 0, -8), V(-60, 0, -8), V(-78, 0, -8), V(0, 0, -6)])
	_track(pla, "Body/ArmL:rotation_degrees", t3, [V(0, 0, 6), V(-40, 0, 12), V(-52, 0, 12), V(-40, 0, 12), V(-52, 0, 12), V(0, 0, 6)])
	_track(pla, "Body/Head:rotation_degrees", t3, [V(0, 0, 0), V(-6, 0, 0), V(-6, 12, 0), V(-6, -10, 0), V(-6, 0, 0), V(0, 0, 0)])
	_show_prop(pla, "PropSeed")
	lib.add_animation("plant", pla)

	# SABIT: ayunan mendatar dari kanan ke kiri, badan memutar
	var scy := _anim(0.75)
	var t4 := [0.0, 0.18, 0.4, 0.56, 0.75]
	_track(scy, "Body/ArmR:rotation_degrees", t4, [V(0, 0, -6), V(-72, 0, -34), V(-76, 0, -10), V(-70, 0, 6), V(0, 0, -6)])
	_track(scy, "Body/ArmL:rotation_degrees", t4, [V(0, 0, 6), V(-60, 0, 20), V(-62, 0, 24), V(-56, 0, 26), V(0, 0, 6)])
	_track(scy, "Body:rotation_degrees", t4, [V(0, 0, 0), V(14, 62, 0), V(18, 0, 0), V(14, -64, 0), V(0, 0, 0)])
	_track(scy, "Body/Head:rotation_degrees", t4, [V(0, 0, 0), V(6, -20, 0), V(8, 0, 0), V(6, 22, 0), V(0, 0, 0)])
	_track(scy, "Body:position", t4, [V(0, HIP, 0), V(0, HIP - 0.04, 0), V(0, HIP - 0.06, 0), V(0, HIP - 0.04, 0), V(0, HIP, 0)])
	_show_prop(scy, "PropScythe")
	lib.add_animation("scythe", scy)

	# PEDANG: angkat tinggi lalu tebas diagonal ke bawah (kena di ~0.25 detik)
	var swd := _anim(0.55)
	var tsw := [0.0, 0.12, 0.26, 0.38, 0.55]
	_track(swd, "Body/ArmR:rotation_degrees", tsw, [V(0, 0, -6), V(-160, 0, -24), V(-62, 0, 14), V(-52, 0, 16), V(0, 0, -6)])
	_track(swd, "Body/ArmL:rotation_degrees", tsw, [V(0, 0, 6), V(-30, 0, 24), V(-20, 0, 24), V(-20, 0, 20), V(0, 0, 6)])
	_track(swd, "Body:rotation_degrees", tsw, [V(0, 0, 0), V(-8, -26, 0), V(16, 22, 0), V(12, 14, 0), V(0, 0, 0)])
	_track(swd, "Body:position", tsw, [V(0, HIP, 0), V(0, HIP + 0.03, 0), V(0, HIP - 0.07, 0), V(0, HIP - 0.04, 0), V(0, HIP, 0)])
	_track(swd, "Body/Head:rotation_degrees", tsw, [V(0, 0, 0), V(-6, 12, 0), V(10, -10, 0), V(6, -6, 0), V(0, 0, 0)])
	_show_prop(swd, "PropSword")
	lib.add_animation("sword", swd)

	# PANEN: membungkuk, tarik ke atas, angkat hasil panen tinggi-tinggi
	var har := _anim(1.0)
	var t5 := [0.0, 0.22, 0.4, 0.62, 0.85, 1.0]
	_track(har, "Body:position", t5, [V(0, HIP, 0), V(0, HIP - 0.15, 0.04), V(0, HIP - 0.15, 0.04), V(0, HIP + 0.05, 0), V(0, HIP + 0.05, 0), V(0, HIP, 0)])
	_track(har, "Body:rotation_degrees", t5, [V(0, 0, 0), V(38, 0, 0), V(38, 0, 0), V(-6, 0, 0), V(-6, 0, 0), V(0, 0, 0)])
	_track(har, "LegL:rotation_degrees", t5, [V(0, 0, 0), V(-30, 0, 0), V(-30, 0, 0), V(0, 0, 0), V(0, 0, 0), V(0, 0, 0)])
	_track(har, "LegR:rotation_degrees", t5, [V(0, 0, 0), V(-30, 0, 0), V(-30, 0, 0), V(0, 0, 0), V(0, 0, 0), V(0, 0, 0)])
	_track(har, "Body/ArmR:rotation_degrees", t5, [V(0, 0, -6), V(-50, 0, -8), V(-62, 0, -8), V(-165, 0, -14), V(-160, 0, -14), V(0, 0, -6)])
	_track(har, "Body/ArmL:rotation_degrees", t5, [V(0, 0, 6), V(-40, 0, 10), V(-50, 0, 10), V(-30, 0, 16), V(-30, 0, 16), V(0, 0, 6)])
	_track(har, "Body/Head:rotation_degrees", t5, [V(0, 0, 0), V(-4, 0, 0), V(-4, 0, 0), V(-18, 0, 0), V(-18, 0, 0), V(0, 0, 0)])
	var ph := har.add_track(Animation.TYPE_VALUE)
	har.track_set_path(ph, NodePath("Body/ArmR/PropProduce:visible"))
	har.track_set_interpolation_type(ph, Animation.INTERPOLATION_NEAREST)
	har.track_insert_key(ph, 0.0, false)
	har.track_insert_key(ph, 0.4, true)
	har.track_insert_key(ph, 1.0, false)
	lib.add_animation("harvest", har)

	# MAKAN: tangan ke mulut, mengunyah (kepala mengangguk)
	var eat := _anim(1.0)
	var t6 := [0.0, 0.25, 0.45, 0.65, 0.85, 1.0]
	_track(eat, "Body/ArmR:rotation_degrees", t6, [V(0, 0, -6), V(-135, 0, -25), V(-135, 0, -25), V(-135, 0, -25), V(-135, 0, -25), V(0, 0, -6)])
	_track(eat, "Body/Head:rotation_degrees", t6, [V(0, 0, 0), V(-4, 0, 0), V(6, 0, 0), V(-2, 0, 0), V(6, 0, 0), V(0, 0, 0)])
	var pe := eat.add_track(Animation.TYPE_VALUE)
	eat.track_set_path(pe, NodePath("Body/ArmR/PropProduce:visible"))
	eat.track_set_interpolation_type(pe, Animation.INTERPOLATION_NEAREST)
	eat.track_insert_key(pe, 0.0, true)
	eat.track_insert_key(pe, 0.6, false)
	eat.track_insert_key(pe, 1.0, false)
	lib.add_animation("eat", eat)

	# PINGSAN: terhuyung lalu roboh ke samping (diam di lantai sampai dipanggil stand_up())
	var fa := _anim(1.6)
	var t7 := [0.0, 0.35, 0.7, 1.1, 1.6]
	_track(fa, ":rotation_degrees:z", t7, [0.0, 6.0, -8.0, 40.0, 88.0])
	_track(fa, "Body/Head:rotation_degrees", t7, [V(0, 0, 0), V(0, 0, 14), V(0, 0, -14), V(8, 0, 10), V(10, 0, 0)])
	_track(fa, "Body/ArmL:rotation_degrees", t7, [V(0, 0, 6), V(0, 0, 40), V(0, 0, 60), V(-20, 0, 70), V(-10, 0, 40)])
	_track(fa, "Body/ArmR:rotation_degrees", t7, [V(0, 0, -6), V(0, 0, -40), V(0, 0, -60), V(-20, 0, -70), V(-10, 0, -40)])
	_track(fa, "Body:position", t7, [V(0, HIP, 0), V(0, HIP, 0), V(0, HIP - 0.02, 0), V(0, HIP - 0.05, 0), V(0, HIP - 0.08, 0)])
	_track(fa, ":position:y", t7, [0.0, 0.0, 0.0, 0.02, 0.1])
	lib.add_animation("faint", fa)


const ACTIONS := ["tool", "hoe", "water", "plant", "scythe", "harvest", "eat", "sword"]


func _on_finished(n: StringName) -> void:
	if ACTIONS.has(String(n)):
		_current = ""
		play_anim("idle")


## Mainkan animasi. Animasi loop tidak diulang dari awal jika sudah jalan.
func play_anim(n: String, speed := 1.0) -> void:
	if anim == null:
		return
	if _fainted and n != "faint":
		return                       # tetap tergeletak sampai stand_up()
	if ACTIONS.has(_current) and not ACTIONS.has(n) and n != "faint" and anim.is_playing():
		return                       # biar animasi aksi selesai dulu
	if _current == n and anim.is_playing():
		anim.speed_scale = speed
		return
	if not ACTIONS.has(n):
		_hide_props()
	_current = n
	anim.speed_scale = speed
	anim.play(n, 0.12)


## Dipanggil saat memakai alat. kind: "hoe" | "water" | "plant" | "scythe" | "harvest" | "eat" (lainnya = ayun umum).
func _hide_props() -> void:
	for n in _props.values():
		(n as Node3D).visible = false


func play_tool(kind := "tool") -> void:
	_current = ""
	_hide_props()
	if kind == "water" and _water != null:
		get_tree().create_timer(0.35).timeout.connect(func() -> void:
			if _water: _water.emitting = true)
		get_tree().create_timer(0.95).timeout.connect(func() -> void:
			if _water: _water.emitting = false)
	play_anim(kind if anim.has_animation(kind) else "tool", 1.0)


## Roboh pingsan. Return setelah animasi selesai (~1.6 detik).
func play_faint() -> void:
	_fainted = false
	_current = ""
	play_anim("faint", 1.0)
	_fainted = true
	await anim.animation_finished


## Bangun lagi (berdiri tegak, pose idle).
func stand_up() -> void:
	_fainted = false
	rotation.x = 0.0
	rotation.z = 0.0
	position.y = 0.0
	_current = ""
	play_anim("idle", 1.0)
