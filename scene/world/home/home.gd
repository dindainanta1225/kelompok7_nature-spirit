extends Node3D
## Home - rumah player (interior). Dibangun lewat kode dari bangun dasar, tanpa model tambahan.
## Isi: kasur (E = tidur), meja + kursi, lemari, rak buku, dapur kecil, karpet, jendela, lampu, tanaman.
## Pintu keluar di tengah sisi selatan (berjalan ke luar -> kembali ke Farm).
## Mau mengubah isi rumah: edit _build_furniture(). Ukuran ruangan: ROOM_W x ROOM_D (meter).

const WorldArea := preload("res://scripts/map/world_area.gd")
const BedScript := preload("res://scripts/map/bed.gd")
const ExitScript := preload("res://scripts/map/scene_exit.gd")
const InteractScript := preload("res://scripts/map/interactable.gd")
const Realism := preload("res://scripts/world/realism.gd")
const DayCycle := preload("res://scripts/world/day_cycle.gd")
const PLAYER_SCENE := "res://scene/player/player.tscn"
const FARM_SCENE := "res://scene/world/farm/farm.tscn"
const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"

const ROOM_W := 9.0                    # lebar (x)
const ROOM_D := 7.0                    # kedalaman (z); dinding belakang di z = -ROOM_D/2
const WALL_H := 3.2
const WALL_T := 0.3
const DOOR_W := 2.4

var _mats := {}


func _ready() -> void:
	Realism.flat = false                      # rumah player: tetap realistis
	set_meta("no_farming", true)
	_build_environment()
	_build_room()
	_build_furniture()
	_build_extras()
	_build_player_and_area()


# ------------------------------------------------------------------ helpers
func _mat(c: Color, glow := false) -> StandardMaterial3D:
	var key := c.to_html() + ("g" if glow else "")
	if not _mats.has(key):
		_mats[key] = Realism.detail(c, glow)               # PBR: kayu bergaris, plester, normal map halus
	return _mats[key]


func _box(parent: Node, size: Vector3, pos: Vector3, c: Color, solid := false, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c, glow)
	mi.position = pos
	parent.add_child(mi)
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


func _cyl(parent: Node, r: float, h: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 12
	mi.mesh = cm
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _label(text: String, pos: Vector3, size := 56) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.006
	l.outline_size = 12
	l.modulate = Color(1.0, 0.92, 0.62)
	l.outline_modulate = Color(0.16, 0.08, 0.03)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = pos
	if ResourceLoader.exists(FONT_PATH):
		l.font = load(FONT_PATH)
	add_child(l)


# ------------------------------------------------------------------ lingkungan
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.04, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.92, 0.80)
	env.ambient_light_energy = 0.28
	Realism.environment(env, 2)
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, -25, 0)
	Realism.sun(sun, 0.22)
	add_child(sun)
	DayCycle.attach(self, env, sun, true)               # cahaya jendela ikut berubah; lampu rumah tetap menyala
	# lampu gantung di tengah ruangan (bayangan lembut)
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.5, 0.2)
	lamp.light_color = Color(1.0, 0.80, 0.52)
	lamp.light_energy = 1.25
	lamp.omni_range = 10.0
	lamp.shadow_enabled = true
	add_child(lamp)


# ------------------------------------------------------------------ ruangan
func _build_room() -> void:
	var hw := ROOM_W * 0.5
	var hd := ROOM_D * 0.5
	var floor_c := Color(0.62, 0.43, 0.24)
	# lantai (papan-papan)
	var fl := StaticBody3D.new()
	var fcs := CollisionShape3D.new()
	var fsh := BoxShape3D.new()
	fsh.size = Vector3(ROOM_W + 8.0, 0.4, ROOM_D + 8.0)
	fcs.shape = fsh
	fl.position = Vector3(0, -0.2, 0)
	fl.add_child(fcs)
	add_child(fl)
	var n := int(ROOM_D / 0.5)
	for i in n:
		var shade := 0.0 if i % 2 == 0 else -0.05
		_box(self, Vector3(ROOM_W, 0.06, 0.48), Vector3(0, -0.03, -hd + 0.25 + i * 0.5),
				Color(floor_c.r + shade, floor_c.g + shade, floor_c.b + shade))
	# tanah gelap di luar rumah (cutaway)
	_box(self, Vector3(ROOM_W + 8.0, 0.02, ROOM_D + 8.0), Vector3(0, -0.09, 0), Color(0.16, 0.12, 0.09))
	# dinding: belakang, kiri, kanan penuh; depan hanya dinding rendah dengan celah pintu
	var wall_c := Color(0.90, 0.80, 0.62)
	var trim_c := Color(0.45, 0.28, 0.14)
	_box(self, Vector3(ROOM_W + WALL_T * 2.0, WALL_H, WALL_T), Vector3(0, WALL_H * 0.5, -hd - WALL_T * 0.5), wall_c, true)
	_box(self, Vector3(WALL_T, WALL_H, ROOM_D), Vector3(-hw - WALL_T * 0.5, WALL_H * 0.5, 0), wall_c, true)
	_box(self, Vector3(WALL_T, WALL_H, ROOM_D), Vector3(hw + WALL_T * 0.5, WALL_H * 0.5, 0), wall_c, true)
	var side_w := (ROOM_W - DOOR_W) * 0.5
	for sx in [-1.0, 1.0]:
		_box(self, Vector3(side_w, 0.7, WALL_T), Vector3(sx * (DOOR_W * 0.5 + side_w * 0.5), 0.35, hd + WALL_T * 0.5), wall_c, true)
		_box(self, Vector3(side_w, 0.08, WALL_T + 0.1), Vector3(sx * (DOOR_W * 0.5 + side_w * 0.5), 0.74, hd + WALL_T * 0.5), trim_c)
	# papan kayu bawah dinding + balok atap tipis
	_box(self, Vector3(ROOM_W, 0.8, 0.06), Vector3(0, 0.4, -hd + 0.03), Color(0.55, 0.36, 0.18))
	_box(self, Vector3(0.06, 0.8, ROOM_D), Vector3(-hw + 0.03, 0.4, 0), Color(0.55, 0.36, 0.18))
	_box(self, Vector3(0.06, 0.8, ROOM_D), Vector3(hw - 0.03, 0.4, 0), Color(0.55, 0.36, 0.18))
	for z in [-hd + 0.05]:
		_box(self, Vector3(ROOM_W, 0.12, 0.1), Vector3(0, WALL_H - 0.06, z), trim_c)
	# keset pintu & keset kaki
	_box(self, Vector3(DOOR_W - 0.4, 0.03, 0.9), Vector3(0, 0.01, hd - 0.5), Color(0.55, 0.22, 0.20))
	# jendela di dinding belakang (kiri & kanan)
	for wx in [-2.6, 2.6]:
		_box(self, Vector3(1.5, 1.3, 0.1), Vector3(wx, 1.9, -hd + 0.05), trim_c)
		_box(self, Vector3(1.3, 1.1, 0.12), Vector3(wx, 1.9, -hd + 0.06), Color(0.72, 0.88, 1.0), false, true)
		_box(self, Vector3(0.07, 1.1, 0.14), Vector3(wx, 1.9, -hd + 0.07), trim_c)
		_box(self, Vector3(1.3, 0.07, 0.14), Vector3(wx, 1.9, -hd + 0.07), trim_c)
	# pintu keluar (berjalan ke luar)
	var ex := ExitScript.new()
	ex.mode = InteractScript.Mode.AUTO
	ex.target_scene = FARM_SCENE
	ex.target_spawn = "from_home"
	ex.prompt = "Go outside"
	var ecs := CollisionShape3D.new()
	var esh := BoxShape3D.new()
	esh.size = Vector3(DOOR_W, 2.0, 1.2)
	ecs.shape = esh
	ex.add_child(ecs)
	ex.position = Vector3(0, 1.0, hd + 0.9)
	add_child(ex)


# ------------------------------------------------------------------ perabot
func _build_furniture() -> void:
	var hw := ROOM_W * 0.5
	var hd := ROOM_D * 0.5
	var wood := Color(0.50, 0.32, 0.16)
	var wood_d := Color(0.36, 0.22, 0.11)
	# --- karpet tengah
	_box(self, Vector3(3.6, 0.03, 2.4), Vector3(0.2, 0.02, 0.6), Color(0.70, 0.30, 0.28))
	_box(self, Vector3(3.2, 0.035, 2.0), Vector3(0.2, 0.03, 0.6), Color(0.86, 0.60, 0.40))
	# --- kasur (pojok kiri belakang): kepala di dinding
	var bed := Node3D.new()
	bed.position = Vector3(-hw + 1.35, 0, -hd + 1.85)
	add_child(bed)
	_box(bed, Vector3(2.0, 0.35, 3.4), Vector3(0, 0.3, 0), wood, true)
	_box(bed, Vector3(1.8, 0.28, 3.2), Vector3(0, 0.62, 0.0), Color(0.95, 0.92, 0.84))               # kasur
	_box(bed, Vector3(1.8, 0.14, 2.0), Vector3(0, 0.78, 0.55), Color(0.30, 0.55, 0.78))              # selimut
	_box(bed, Vector3(1.4, 0.18, 0.6), Vector3(0, 0.83, -1.2), Color(1.0, 0.98, 0.94))              # bantal
	_box(bed, Vector3(2.0, 1.1, 0.18), Vector3(0, 0.8, -1.7), wood_d)                                  # papan kepala
	_box(bed, Vector3(2.0, 0.5, 0.14), Vector3(0, 0.45, 1.7), wood_d)                                  # papan kaki
	var b := BedScript.new()
	var bcs := CollisionShape3D.new()
	var bsh := BoxShape3D.new()
	bsh.size = Vector3(3.4, 2.0, 4.6)
	bcs.shape = bsh
	b.add_child(bcs)
	b.position = Vector3(0, 1.0, 0.4)
	b.prompt = "Sleep"
	bed.add_child(b)
	# meja kecil di samping kasur + lampu
	_box(self, Vector3(0.8, 0.7, 0.8), Vector3(-hw + 0.6, 0.35, -hd + 4.0), wood, true)
	_cyl(self, 0.12, 0.3, Vector3(-hw + 0.6, 0.85, -hd + 4.0), Color(1.0, 0.85, 0.45))
	# --- lemari (dinding belakang, tengah-kiri)
	var ward := Node3D.new()
	ward.position = Vector3(-0.6, 0, -hd + 0.55)
	add_child(ward)
	_box(ward, Vector3(2.0, 2.3, 0.9), Vector3(0, 1.15, 0), wood, true)
	_box(ward, Vector3(0.95, 2.1, 0.06), Vector3(-0.5, 1.15, 0.47), wood_d)
	_box(ward, Vector3(0.95, 2.1, 0.06), Vector3(0.5, 1.15, 0.47), wood_d)
	_cyl(ward, 0.04, 0.1, Vector3(-0.1, 1.15, 0.52), Color(0.9, 0.8, 0.4)).rotation.x = PI * 0.5
	_cyl(ward, 0.04, 0.1, Vector3(0.1, 1.15, 0.52), Color(0.9, 0.8, 0.4)).rotation.x = PI * 0.5
	# --- rak buku (dinding kanan)
	var shelf := Node3D.new()
	shelf.position = Vector3(hw - 0.45, 0, -0.9)
	add_child(shelf)
	_box(shelf, Vector3(0.7, 2.4, 2.2), Vector3(0, 1.2, 0), wood, true)
	var book_cols := [Color(0.75, 0.25, 0.25), Color(0.25, 0.5, 0.75), Color(0.35, 0.65, 0.35), Color(0.9, 0.75, 0.3)]
	for row in 3:
		_box(shelf, Vector3(0.62, 0.05, 2.1), Vector3(-0.04, 0.5 + row * 0.7, 0), wood_d)
		for k in 6:
			_box(shelf, Vector3(0.4, 0.5, 0.18), Vector3(-0.1, 0.78 + row * 0.7, -0.85 + k * 0.33), book_cols[(row + k) % 4])
	# --- dapur kecil (dinding kanan belakang): meja dapur + kompor
	var kit := Node3D.new()
	kit.position = Vector3(hw - 0.55, 0, -hd + 1.0)
	add_child(kit)
	_box(kit, Vector3(0.9, 0.95, 1.8), Vector3(0, 0.475, 0), Color(0.85, 0.82, 0.76), true)
	_box(kit, Vector3(0.95, 0.06, 1.85), Vector3(0, 0.98, 0), wood_d)
	_box(kit, Vector3(0.6, 0.12, 0.6), Vector3(0, 1.06, 0.4), Color(0.2, 0.2, 0.22))                  # kompor
	_cyl(kit, 0.2, 0.18, Vector3(0, 1.2, 0.4), Color(0.6, 0.62, 0.66))                                  # panci
	_box(kit, Vector3(0.5, 0.04, 0.5), Vector3(0, 1.03, -0.5), Color(0.55, 0.75, 0.9))                  # wastafel
	# --- meja makan + 2 kursi (kanan-depan)
	var table := Node3D.new()
	table.position = Vector3(2.4, 0, 1.5)
	add_child(table)
	_cyl(table, 0.8, 0.1, Vector3(0, 0.8, 0), wood)
	_cyl(table, 0.12, 0.8, Vector3(0, 0.4, 0), wood_d)
	_cyl(table, 0.45, 0.06, Vector3(0, 0.1, 0), wood_d)
	var tcs := StaticBody3D.new()
	var tsh := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.8
	cyl.height = 0.9
	tsh.shape = cyl
	tcs.position = Vector3(0, 0.45, 0)
	tcs.add_child(tsh)
	table.add_child(tcs)
	_cyl(table, 0.18, 0.12, Vector3(0.1, 0.92, 0.1), Color(0.40, 0.70, 0.35))                           # vas
	_box(table, Vector3(0.25, 0.05, 0.25), Vector3(-0.35, 0.88, -0.2), Color(0.95, 0.9, 0.8))          # piring
	for cx in [-1.25, 1.25]:
		_box(table, Vector3(0.55, 0.12, 0.55), Vector3(cx, 0.5, 0), wood)
		_box(table, Vector3(0.1, 0.5, 0.1), Vector3(cx, 0.25, 0), wood_d)
		_box(table, Vector3(0.1, 0.7, 0.55), Vector3(cx + (-0.25 if cx < 0 else 0.25), 0.85, 0), wood_d)   # sandaran
	# --- tanaman pot (dekat pintu), peti kecil, gambar di dinding
	for px in [-3.7, 3.7]:
		_cyl(self, 0.28, 0.4, Vector3(px, 0.2, hd - 0.5), Color(0.72, 0.42, 0.25))
		var leaf := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.4
		sm.height = 0.8
		leaf.mesh = sm
		leaf.material_override = _mat(Color(0.30, 0.65, 0.30))
		leaf.position = Vector3(px, 0.75, hd - 0.5)
		add_child(leaf)
	_box(self, Vector3(0.9, 0.7, 0.06), Vector3(-0.6, 2.35, -hd + 0.06), Color(0.30, 0.55, 0.78))      # lukisan
	_box(self, Vector3(0.8, 0.6, 0.07), Vector3(-0.6, 2.35, -hd + 0.07), Color(0.65, 0.82, 0.5))


# ------------------------------------------------------------------ tambahan: perapian, kursi, tirai, hiasan, lampu
func _sphere(parent: Node, r: float, pos: Vector3, c: Color, scl := Vector3.ONE, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = _mat(c, glow)
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _cone(parent: Node, r: float, h: float, pos: Vector3, c: Color, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	mi.mesh = cm
	mi.material_override = _mat(c, glow)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _light(parent: Node, pos: Vector3, c: Color, energy: float, rng: float, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng
	l.shadow_enabled = shadow
	parent.add_child(l)
	return l


func _flicker(l: OmniLight3D, base: float, amp: float) -> void:
	var tw := create_tween().set_loops()
	for i in 6:
		tw.tween_property(l, "light_energy", base + randf_range(-amp, amp), randf_range(0.08, 0.22))


func _build_extras() -> void:
	var hw := ROOM_W * 0.5
	var hd := ROOM_D * 0.5
	var stone := Color(0.40, 0.38, 0.36)
	var wood := Color(0.50, 0.32, 0.16)
	var wood_d := Color(0.36, 0.22, 0.11)
	# --- perapian batu di dinding kiri (dekat pintu) + api yang berkelip
	var fp := Node3D.new()
	fp.position = Vector3(-hw + 0.5, 0, 1.9)
	add_child(fp)
	var smat := Realism.stone(stone)
	for part in [[Vector3(0.9, 1.5, 2.0), Vector3(0, 0.75, 0)], [Vector3(0.9, 1.7, 1.4), Vector3(0, 2.35, 0)], [Vector3(1.05, 0.12, 2.2), Vector3(0.02, 1.52, 0)]]:
		var mi := _box(fp, part[0], part[1], stone, part[1].y < 1.0)
		mi.material_override = smat
	_box(fp, Vector3(0.5, 0.9, 1.2), Vector3(0.28, 0.55, 0), Color(0.06, 0.04, 0.03))                # ruang api (gelap)
	_box(fp, Vector3(0.5, 0.06, 1.3), Vector3(0.28, 0.12, 0), Color(0.18, 0.12, 0.09))               # dasar
	for k in 3:
		var f := _cone(fp, 0.17 - k * 0.03, 0.55 - k * 0.1, Vector3(0.32, 0.45 + k * 0.03, -0.3 + k * 0.3), Color(1.0, 0.55 - k * 0.12, 0.12), true)
		var tw := create_tween().set_loops()
		tw.tween_property(f, "scale", Vector3(1.0, 1.25, 1.0), randf_range(0.12, 0.25))
		tw.tween_property(f, "scale", Vector3(1.0, 0.85, 1.0), randf_range(0.12, 0.25))
	for k in 3:
		var lg := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07
		cm.bottom_radius = 0.07
		cm.height = 0.9
		lg.mesh = cm
		lg.material_override = _mat(Color(0.30, 0.18, 0.09))
		lg.position = Vector3(0.28, 0.2 + (k % 2) * 0.08, -0.35 + k * 0.35)
		lg.rotation_degrees = Vector3(90, 0, 0)
		fp.add_child(lg)
	var fl := _light(fp, Vector3(0.5, 0.7, 0), Color(1.0, 0.55, 0.22), 2.2, 7.0, true)
	_flicker(fl, 2.2, 0.8)
	# tumpukan kayu bakar di samping perapian
	for k in 5:
		var lg2 := MeshInstance3D.new()
		var cm2 := CylinderMesh.new()
		cm2.top_radius = 0.09
		cm2.bottom_radius = 0.09
		cm2.height = 0.6
		lg2.mesh = cm2
		lg2.material_override = _mat(Color(0.44, 0.28, 0.14))
		lg2.position = Vector3(-hw + 0.5, 0.1 + (k / 3) * 0.17, 3.15 + (k % 3) * 0.19)
		lg2.rotation_degrees = Vector3(0, 0, 90)
		add_child(lg2)
	# --- kursi santai menghadap perapian + bantal bulat
	var ch := Node3D.new()
	ch.position = Vector3(-2.3, 0, 1.9)
	ch.rotation.y = -PI * 0.5
	add_child(ch)
	var cloth := Color(0.52, 0.30, 0.26)
	_box(ch, Vector3(1.1, 0.35, 0.95), Vector3(0, 0.3, 0), cloth, true)
	_box(ch, Vector3(1.1, 0.85, 0.22), Vector3(0, 0.72, -0.42), cloth.darkened(0.1))
	for sx in [-1.0, 1.0]:
		_box(ch, Vector3(0.18, 0.55, 0.95), Vector3(sx * 0.58, 0.45, 0), cloth.darkened(0.15))
	_sphere(ch, 0.25, Vector3(0, 0.55, 0.05), Color(0.85, 0.72, 0.45), Vector3(1.4, 0.45, 1.4))
	for sx in [-0.45, 0.45]:
		_cyl(ch, 0.05, 0.2, Vector3(sx, 0.1, 0.4), wood_d)
		_cyl(ch, 0.05, 0.2, Vector3(sx, 0.1, -0.4), wood_d)
	# --- lampu berdiri di sebelah kursi
	_cyl(self, 0.03, 1.5, Vector3(-2.3, 0.75, 0.7), Color(0.20, 0.16, 0.12))
	_cyl(self, 0.2, 0.04, Vector3(-2.3, 0.02, 0.7), Color(0.20, 0.16, 0.12))
	var shade := _cyl(self, 0.24, 0.3, Vector3(-2.3, 1.62, 0.7), Color(1.0, 0.88, 0.62))
	shade.material_override = _mat(Color(1.0, 0.88, 0.62), true)
	_light(self, Vector3(-2.3, 1.6, 0.7), Color(1.0, 0.82, 0.55), 1.2, 5.0)
	# --- tirai jendela + tiang
	for wx in [-2.6, 2.6]:
		_cyl(self, 0.025, 2.0, Vector3(wx, 2.72, -hd + 0.14), Color(0.30, 0.20, 0.10)).rotation.z = PI * 0.5
		for sx in [-1.0, 1.0]:
			var cur := _box(self, Vector3(0.45, 1.7, 0.08), Vector3(wx + sx * 0.95, 1.85, -hd + 0.15), Color(0.82, 0.50, 0.42))
			cur.rotation_degrees.z = sx * 2.5
	# --- bingkai foto & jam dinding
	for fr in [[-3.6, 2.2, Color(0.55, 0.72, 0.85)], [3.9, 2.35, Color(0.85, 0.72, 0.50)], [1.6, 2.5, Color(0.65, 0.78, 0.55)]]:
		_box(self, Vector3(0.7, 0.55, 0.05), Vector3(fr[0], fr[1], -hd + 0.07), wood_d)
		_box(self, Vector3(0.58, 0.43, 0.055), Vector3(fr[0], fr[1], -hd + 0.075), fr[2])
	var clk := _cyl(self, 0.28, 0.06, Vector3(hw - 0.07, 2.4, 1.6), Color(0.94, 0.90, 0.80))
	clk.rotation_degrees = Vector3(0, 0, 90)
	_box(self, Vector3(0.03, 0.03, 0.18), Vector3(hw - 0.12, 2.4, 1.6), Color(0.1, 0.08, 0.06))
	_box(self, Vector3(0.03, 0.2, 0.03), Vector3(hw - 0.12, 2.47, 1.6), Color(0.1, 0.08, 0.06))
	# --- keranjang apel dekat dapur
	_cyl(self, 0.3, 0.3, Vector3(hw - 1.5, 0.15, -hd + 0.5), Color(0.62, 0.45, 0.22))
	for k in 5:
		_sphere(self, 0.09, Vector3(hw - 1.5 + cos(k * 1.3) * 0.12, 0.34 + (k % 2) * 0.05, -hd + 0.5 + sin(k * 1.3) * 0.12), Color(0.80, 0.14, 0.12))
	# --- rak dapur di atas meja dapur: toples & panci gantung
	var rack := Vector3(hw - 0.3, 1.9, -hd + 1.0)
	_box(self, Vector3(0.3, 0.05, 1.8), rack, wood_d)
	for k in 4:
		_cyl(self, 0.1, 0.22, rack + Vector3(0.0, 0.14, -0.7 + k * 0.45), [Color(0.8, 0.7, 0.5), Color(0.85, 0.4, 0.3), Color(0.6, 0.7, 0.4), Color(0.9, 0.85, 0.7)][k])
	# --- meja makan: lilin kecil, cangkir, buku
	var cand := _cyl(self, 0.04, 0.16, Vector3(2.4 - 0.2, 0.93, 1.5 + 0.25), Color(0.95, 0.92, 0.82))
	_cone(self, 0.03, 0.09, Vector3(2.2, 1.06, 1.75), Color(1.0, 0.7, 0.2), true)
	var cl := _light(self, Vector3(2.2, 1.12, 1.75), Color(1.0, 0.7, 0.35), 0.7, 3.0)
	_flicker(cl, 0.7, 0.25)
	_cyl(self, 0.06, 0.1, Vector3(2.75, 0.9, 1.35), Color(0.9, 0.9, 0.9))
	_box(self, Vector3(0.3, 0.05, 0.22), Vector3(2.3, 0.87, 1.0), Color(0.35, 0.50, 0.75)).rotation.y = 0.4
	# --- karpet kecil di depan pintu & di depan perapian
	_box(self, Vector3(1.6, 0.025, 1.0), Vector3(-2.7, 0.025, 1.9), Color(0.45, 0.55, 0.40))
	# --- lampu tidur menyala di meja samping kasur
	_light(self, Vector3(-hw + 0.6, 1.2, -hd + 4.0), Color(1.0, 0.85, 0.5), 0.8, 4.0)


# ------------------------------------------------------------------ player + area
func _build_player_and_area() -> void:
	var player: Node3D = load(PLAYER_SCENE).instantiate()
	player.position = Vector3(0, 0.3, ROOM_D * 0.5 - 2.0)
	add_child(player)
	var area := WorldArea.new()
	area.area_name = "Home"
	area.default_spawn = "from_farm"
	var hd := ROOM_D * 0.5
	for spawn in [["from_farm", Vector3(0, 0.3, hd - 2.0)], ["bed", Vector3(-ROOM_W * 0.5 + 3.0, 0.3, -hd + 2.4)]]:
		var m := Marker3D.new()
		m.name = spawn[0]
		m.position = spawn[1]
		m.add_to_group("spawn")
		area.add_child(m)
	add_child(area)
