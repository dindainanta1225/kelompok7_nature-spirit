extends Node
## FarmSetup - dipasang sebagai child scene Farm. Membangun: rumah (bisa dimasuki), peti perlengkapan,
## 2 petak tanam 5x5, dan partikel suasana. Juga membersihkan dekorasi (pohon/bunga) yang menghalangi.
## Posisi diatur di scripts/farm/farm_layout.gd.

const Layout := preload("res://scripts/farm/farm_layout.gd")
const DecorUtil := preload("res://scripts/world/decor_util.gd")
const Props := preload("res://scripts/world/prop_builder.gd")
const Critter := preload("res://scripts/world/critter.gd")
const Placer := preload("res://scripts/world/placer.gd")
const Scenery := preload("res://scripts/world/scenery.gd")
const Realism := preload("res://scripts/world/realism.gd")
const DayCycle := preload("res://scripts/world/day_cycle.gd")
const ChestScript := preload("res://scripts/map/chest.gd")
const ExitScript := preload("res://scripts/map/scene_exit.gd")
const InteractScript := preload("res://scripts/map/interactable.gd")
const Ambient := preload("res://scripts/world/ambient_particles.gd")
const HOME_SCENE := "res://scene/world/home/home.tscn"
const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"
const NPCActor := preload("res://scripts/world/npc_actor.gd")
const GuideTalk := preload("res://scripts/world/guide_talk.gd")
const GY := 1.5                                    # permukaan tanah Farm
const HOUSE_FBX := "res://assets/Buildings/FBX/House_1.fbx"
const HOUSE_DEPTH := 3.0
const ModelUtil := preload("res://scripts/world/model_util.gd")
const HOUSE_SCALE := 2.0

## Bangunan pertanian (aset FBX): [kunci, x, z, skala]
const FARM_BUILDINGS := [["Barn", 15.5, -14.0, 1.0], ["Silo", 5.0, -15.0, 1.0], ["Windmill", -3.0, -16.0, 1.0],
		["WaterTower", 18.0, 3.0, 1.0], ["OpenBarn", 4.5, 10.0, 1.0], ["SmallBarn", 12.8, 9.5, 1.0], ["Coop", -18.3, 6.0, 1.0]]

var _farm: Node
var _font: Font


func _ready() -> void:
	Realism.flat = true                      # low-poly (home tetap realistis)
	_farm = get_parent()
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	_clear_decor()
	DecorUtil.make_walkable(_farm.get_node_or_null("Decor") as GridMap)       # bunga & rumput bisa ditembus
	_build_plots()
	_build_house()
	_build_chest()
	_build_yard()
	_setup_look()
	_setup_map()
	_add_guide()
	if GameState.ending_kind != "":
		var ec := preload("res://scripts/world/ending_cutscene.gd").new()        # ending good / bad di halaman depan rumah
		_farm.add_child.call_deferred(ec)
	elif not GameState.guide_met and GameState.playing:
		var cs := preload("res://scripts/world/guide_cutscene.gd").new()          # perkenalan dengan Centorea (sekali, hari 1)
		_farm.add_child.call_deferred(cs)
	var amb := Ambient.new()
	_farm.add_child.call_deferred(amb)


func _house_rect() -> Rect2:
	var w := 4.3
	var d := 6.8
	return Rect2(Layout.HOUSE_X - w * 0.5, Layout.HOUSE_FRONT_Z - d, w, d)


func _clear_decor() -> void:
	var decor := _farm.get_node_or_null("Decor") as GridMap
	if decor == null:
		return
	var rects: Array = []
	var hr := _house_rect()
	rects.append(Rect2(hr.position - Vector2(1.5, 1.5), hr.size + Vector2(3.0, 6.5)))       # rumah + halaman depan
	for r in Layout.PLOTS:
		rects.append(Rect2(Vector2(r.position), Vector2(r.size)).grow(1.0))
	rects.append(Rect2(Layout.CHEST_POS.x - 1.5, Layout.CHEST_POS.z - 1.5, 3.0, 3.0))
	for fb in FARM_BUILDINGS:
		rects.append(Scenery.footprint(fb[0], fb[1], fb[2], fb[3]).grow(1.0))
	rects.append(Rect2(-17.5, 3.0, 7.0, 6.0))                                                  # kandang ayam
	rects.append(Rect2(6.0, 12.0, 10.0, 6.0))                                                  # padang kuda & domba
	rects.append(Rect2(-12.0, -3.0, 16.0, 3.5))                                              # jalan setapak rumah -> petak
	var inside := Rect2(-19.0, -19.0, 37.0, 36.0)        # cincin terluar (pagar & pohon batas) tidak boleh dibuka
	for rc in rects:
		var r: Rect2 = (rc as Rect2).intersection(inside)
		if r.size.x <= 0.0 or r.size.y <= 0.0:
			continue
		for x in range(floori(r.position.x), ceili(r.end.x)):
			for z in range(floori(r.position.y), ceili(r.end.y)):
				for y in range(0, 4):
					decor.set_cell_item(Vector3i(x, y, z), GridMap.INVALID_CELL_ITEM)


func _box(size: Vector3, pos: Vector3, color: Color, soil := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = Realism.soil() if soil else Props.mat(color)
	mi.position = pos
	return mi


func _build_plots() -> void:
	var dirt := Color(0.47, 0.32, 0.19)
	var plank := Color(0.52, 0.34, 0.17)
	for pr in Layout.PLOTS:
		var r: Rect2i = pr
		var cx := r.position.x + r.size.x * 0.5
		var cz := r.position.y + r.size.y * 0.5
		var holder := Node3D.new()
		_farm.add_child.call_deferred(holder)
		holder.add_child(_box(Vector3(r.size.x, 0.02, r.size.y), Vector3(cx, GY + 0.011, cz), dirt, true))
		for i in range(0, r.size.x + 1):                       # garis petak halus
			holder.add_child(_box(Vector3(0.03, 0.022, r.size.y), Vector3(r.position.x + i, GY + 0.013, cz), dirt.darkened(0.25)))
		for i in range(0, r.size.y + 1):
			holder.add_child(_box(Vector3(r.size.x, 0.022, 0.03), Vector3(cx, GY + 0.013, r.position.y + i), dirt.darkened(0.25)))
		var t := 0.12                                          # papan pinggir
		holder.add_child(_box(Vector3(r.size.x + t * 2.0, 0.16, t), Vector3(cx, GY + 0.08, r.position.y - t * 0.5), plank))
		holder.add_child(_box(Vector3(r.size.x + t * 2.0, 0.16, t), Vector3(cx, GY + 0.08, r.position.y + r.size.y + t * 0.5), plank))
		holder.add_child(_box(Vector3(t, 0.16, r.size.y), Vector3(r.position.x - t * 0.5, GY + 0.08, cz), plank))
		holder.add_child(_box(Vector3(t, 0.16, r.size.y), Vector3(r.position.x + r.size.x + t * 0.5, GY + 0.08, cz), plank))


func _build_house() -> void:
	var cx := Layout.HOUSE_X
	var front_z := Layout.HOUSE_FRONT_Z
	var holder := Node3D.new()
	var cz := front_z - HOUSE_DEPTH * 0.5
	var size := Vector3(4.3, 5.3, HOUSE_DEPTH)
	if ResourceLoader.exists(HOUSE_FBX):
		var inst: Node3D = load(HOUSE_FBX).instantiate()
		var raw := ModelUtil.bounds(inst)
		cz = front_z - raw.size.z * HOUSE_SCALE * 0.5
		size = ModelUtil.place(inst, HOUSE_SCALE, cx, cz, GY).size
		holder.add_child(inst)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.position = Vector3(cx, GY + size.y * 0.5, cz)
	body.add_child(cs)
	holder.add_child(body)
	# pintu masuk
	var ex := ExitScript.new()
	ex.mode = InteractScript.Mode.PRESS
	ex.target_scene = HOME_SCENE
	ex.target_spawn = "from_farm"
	ex.prompt = "Enter home"
	ex.arm_delay = 0.0
	var ecs := CollisionShape3D.new()
	var ebox := BoxShape3D.new()
	ebox.size = Vector3(3.4, 2.6, 2.4)
	ecs.shape = ebox
	ex.add_child(ecs)
	ex.position = Vector3(cx, GY + 1.3, front_z + 1.0)
	holder.add_child(ex)
	_farm.add_child.call_deferred(holder)


func _build_chest() -> void:
	var holder := Node3D.new()
	var chest := ChestScript.new()
	chest.position = Vector3(Layout.CHEST_POS.x, GY, Layout.CHEST_POS.z)
	holder.add_child(chest)
	_farm.add_child.call_deferred(holder)


# ------------------------------------------------------------------ halaman & suasana
var _placer := Placer.new()


func _put(node: Node3D, x: float, z: float, yaw := 0.0, r := 0.7) -> void:
	_placer.place(_farm, node, x, z, GY, r, yaw)


func _reserve_yard() -> void:
	var hx := Layout.HOUSE_X
	var fz := Layout.HOUSE_FRONT_Z
	var hr := _house_rect()
	_placer.keep_rect(hr.grow(0.2))
	for r in Layout.PLOTS:
		_placer.keep_rect(Rect2(Vector2(r.position), Vector2(r.size)).grow(0.3))
	# jalan setapak (pintu -> ladang -> gerbang desa)
	_placer.keep_rect(Rect2(hx - 1.0, fz, 2.0, 4.4))
	_placer.keep_rect(Rect2(hx - 1.0, -1.7, 9.8, 1.4))
	_placer.keep_rect(Rect2(-1.4, -1.7, 1.8, 18.0))
	_placer.keep_disc(Layout.CHEST_POS.x, Layout.CHEST_POS.z, 1.0)            # peti + ruang berdiri
	_placer.keep_disc(hx, fz + 0.8, 1.4)                                       # depan pintu
	_placer.keep_rect(Rect2(-17.0, 3.5, 6.0, 5.0))                             # kandang ayam
	_placer.keep_disc(-0.5, 16.5, 2.5)                                         # gerbang ke desa


func _build_yard() -> void:
	var hx := Layout.HOUSE_X
	var fz := Layout.HOUSE_FRONT_Z
	_reserve_yard()
	var sc := Scenery.new(_placer, GY)
	for fb in FARM_BUILDINGS:
		sc.building(_farm, fb[0], fb[1], fb[2], fb[3])
	# bercak rumput/tanah supaya hamparan tidak polos
	_farm.add_child.call_deferred(Realism.ground_plane(Rect2(-20, -20, 40, 40), GY))
	# jalan setapak: pintu -> ladang -> gerbang desa
	_farm.add_child.call_deferred(Props.stepping_stones(Vector3(hx, GY, fz + 0.9), Vector3(hx, GY, -1.0), 0.95, 2))
	_farm.add_child.call_deferred(Props.stepping_stones(Vector3(hx, GY, -1.0), Vector3(-0.6, GY, -1.0), 0.95, 4))
	_farm.add_child.call_deferred(Props.stepping_stones(Vector3(-0.6, GY, -1.0), Vector3(-0.5, GY, 15.5), 0.95, 6))
	# pagar halaman depan (dua potong, di selatan jalan setapak)
	_placer.place_fence(_farm, Vector3(-14.5, GY, 1.8), Vector3(-10.5, GY, 1.8))
	_placer.place_fence(_farm, Vector3(-7.5, GY, 1.8), Vector3(-3.5, GY, 1.8))
	# bedeng bunga, lampu, semak
	_put(Props.flower_bed(2.0, 0.8, 3), hx - 3.8, fz + 0.9, 0.0, 1.1)
	_put(Props.lamp_post(), hx - 1.6, fz + 1.8, 0.0, 0.3)
	_put(Props.lamp_post(), hx + 1.6, fz + 1.8, 0.0, 0.3)
	_put(Props.bush(0.6, Color(0.26, 0.50, 0.30)), hx + 3.1, fz - 1.4, 0.0, 0.7)
	_put(Props.bush(0.8), hx + 3.3, fz - 6.0, 0.0, 0.9)
	_put(Props.bush(0.7), hx - 3.3, fz - 4.8, 0.0, 0.8)
	# sumur, kayu, tong, peti, jerami, kotak surat, bangku
	_put(Props.well(), hx - 6.0, fz + 3.0, 0.0, 1.4)
	_put(Props.woodpile(), hx - 3.8, fz - 2.6, PI * 0.5, 1.0)
	_put(Props.barrel(), hx + 4.2, fz - 4.0, 0.0, 0.5)
	_put(Props.barrel(), hx + 5.1, fz - 4.9, 0.0, 0.5)
	_put(Props.crate(0.8), Layout.CHEST_POS.x + 1.9, Layout.CHEST_POS.z - 1.0, 0.3, 0.65)
	_put(Props.crate(0.6), Layout.CHEST_POS.x + 2.5, Layout.CHEST_POS.z - 2.2, -0.4, 0.5)
	_put(Props.hay_bale(), hx + 5.6, fz - 6.4, 0.4, 0.9)
	_put(Props.mailbox(), hx + 1.2, fz + 5.4, 0.0, 0.35)
	_put(Props.bench(), hx + 3.0, fz + 8.4, 0.0, 1.1)
	# di ladang: orang-orangan sawah, gerobak
	_put(Props.scarecrow(), 6.0, -4.5, 0.0, 0.4)
	_put(Props.cart(), 15.5, -4.5, 0.4, 1.5)
	_put(Props.hay_bale(), 14.5, -8.5, 0.2, 0.9)
	_put(Props.bush(0.8), 14.0, -0.5, 0.0, 0.9)
	_put(Props.bush(0.7), -1.5, -10.0, 0.0, 0.8)
	# kandang ayam kecil + ayam berkeliaran
	var px := -16.5
	var pz := 4.0
	var pen := [[Vector3(px, GY, pz), Vector3(px + 5, GY, pz)], [Vector3(px + 5, GY, pz), Vector3(px + 5, GY, pz + 4)],
			[Vector3(px + 5, GY, pz + 4), Vector3(px, GY, pz + 4)], [Vector3(px, GY, pz + 4), Vector3(px, GY, pz)]]
	for seg in pen:
		var f := Props.fence(Vector3.ZERO, seg[1] - seg[0])
		f.position = seg[0]
		_farm.add_child.call_deferred(f)
	for i in 4:
		_add_critter("chicken", Vector3(px + 2.5, GY, pz + 2.0), 1.7)
	for i in 3:
		_add_critter("chicken", Vector3(-4.5, GY, 10.0), 2.0)
	# padang kecil: kuda + domba (model GLB buatan sendiri, berskeleton)
	var qx := 7.0
	var qz := 12.8
	var pen2 := [[Vector3(qx, GY, qz), Vector3(qx + 8, GY, qz)], [Vector3(qx + 8, GY, qz), Vector3(qx + 8, GY, qz + 4.5)],
			[Vector3(qx + 8, GY, qz + 4.5), Vector3(qx, GY, qz + 4.5)], [Vector3(qx, GY, qz + 4.5), Vector3(qx, GY, qz)]]
	for seg in pen2:
		var f2 := Props.fence(Vector3.ZERO, seg[1] - seg[0])
		f2.position = seg[0]
		_farm.add_child.call_deferred(f2)
	_add_critter("horse", Vector3(qx + 5.2, GY, qz + 2.3), 1.6)
	for i in 3:
		_add_critter("sheep", Vector3(qx + 2.2 + i * 0.4, GY, qz + 2.2), 1.5)
	sc.scatter(_farm, Rect2(-19.0, -18.5, 38.0, 36.0), 110, 5)
	_build_grass()                 # bunga, jamur, batu, rumput, pohon kecil
	var bcols := [Color(1.0, 0.7, 0.2), Color(0.5, 0.7, 1.0), Color(1.0, 0.55, 0.7), Color(0.95, 0.95, 0.5)]
	for i in 6:
		_add_critter("butterfly", Vector3(hx + (i - 3) * 2.2, GY, fz + 2.0 + (i % 3) * 3.0), 5.0, bcols[i % bcols.size()])


func _add_critter(kind: String, home: Vector3, radius: float, wing := Color(1.0, 0.7, 0.2)) -> void:
	var c := Critter.new()
	c.kind = kind
	c.home = home
	c.radius = radius
	c.ground_y = GY
	c.wing_color = wing
	_farm.add_child.call_deferred(c)


## Centorea: pemandu tetap di Farm player. Berdiri di halaman; cutscene awal memperkenalkannya, lalu bicara = menu tips & trik.
func _add_guide() -> void:
	var g := NPCActor.new()
	g.npc_id = "centorea"
	g.display_name = "Centorea"
	g.guide = true                                  # bicara -> menu "Ada yang ingin kau tahu / tanyakan?"
	g.greetings = ["Hello!"]
	g.look = {"model": "centorea", "hair": Color("e8c860")}
	g.position = Vector3(-1.0, GY, 12.5)               # tetap di sini (tidak berkeliaran)
	g.look["yaw"] = 180.0
	g.spot_name = "Your farm"
	_farm.add_child.call_deferred(g)


func _setup_look() -> void:
	var we := _farm.find_child("WorldEnvironment", true, false) as WorldEnvironment
	if we != null:
		var env: Environment = we.environment
		env.background_mode = Environment.BG_SKY
		if env.sky == null:
			var sky := Sky.new()
			var psm := ProceduralSkyMaterial.new()
			psm.sky_top_color = Color(0.30, 0.50, 0.80)
			psm.sky_horizon_color = Color(0.72, 0.82, 0.90)
			psm.ground_horizon_color = Color(0.62, 0.70, 0.62)
			sky.sky_material = psm
			env.sky = sky
		Props.grade_environment(env)
		Realism.environment(env, 0)
	var sun := _farm.find_child("DirectionalLight3D", true, false) as DirectionalLight3D
	Realism.sun(sun)
	if we != null and sun != null:
		sun.rotation_degrees = Vector3(-52, -35, 0)                 # arah dasar sama seperti village (DayCycle hanya mengubah tinggi matahari)
		var dc = DayCycle.new()
		dc.env = we.environment
		dc.sun = sun
		_farm.add_child.call_deferred(dc)                           # add_child langsung gagal: parent masih menyiapkan anak-anaknya
	_build_walls()
	_restyle_hedges()
	_build_outskirts()


## Pohon/pagar tanaman pastel-mint di tepi peta -> hijau hutan (lihat Realism.foliage).
func _restyle_hedges() -> void:
	for gn in ["Decor", "Land"]:
		var grid := _farm.get_node_or_null(gn) as GridMap
		if grid == null or grid.mesh_library == null:
			continue
		var ml := grid.mesh_library
		for id in ml.get_item_list():
			var nm := ml.get_item_name(id)
			if gn == "Decor" and not (nm == "tree" or nm == "tree-pine" or nm.begins_with("hedge") or nm == "plant" or nm == "grass"):
				continue
			var m := ml.get_item_mesh(id)
			for i in m.get_surface_count():
				var old := m.surface_get_material(i) as BaseMaterial3D
				if old != null and old.albedo_texture != null:
					m.surface_set_material(i, Realism.foliage(old))
		grid.mesh_library = null                      # paksa GridMap membangun ulang mesh dengan material baru
		grid.mesh_library = ml


## Tutup "lubang" di tepi peta: hamparan rumput gelap jauh ke segala arah + sabuk pohon rapat di luar pagar,
## jadi dari sudut kamera mana pun (termasuk pojok kanan) tidak ada ruang kosong/langit gelap di tepi Farm.
func _build_outskirts() -> void:
	_farm.add_child.call_deferred(Props.lawn_base(Rect2(-120, -120, 240, 240), GY - 0.04, Color(0.20, 0.34, 0.16)))
	var sc2 := Scenery.new(_placer, GY)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var n := 0
	for i in 2500:
		var x := rng.randf_range(-38.0, 38.0)
		var z := rng.randf_range(-38.0, 38.0)
		var d := maxf(absf(x), absf(z))
		if d < 19.8:
			continue
		var kind := "tree" if rng.randf() < 0.55 else "tree-pine-small"
		if sc2.nature(_farm, kind, x, z, rng.randf_range(2.4, 3.4), rng.randf() * TAU, 0.0):
			n += 1
		if n >= 190:
			break


## Dinding tak terlihat di luar pagar/pohon batas: pemain tidak bisa keluar peta (gerbang desa ada di selatan, di dalam batas).
func _build_walls() -> void:
	var body := StaticBody3D.new()
	body.name = "MapBounds"
	var defs := [[Vector3(0, 0, -20.4), Vector3(44, 12, 1.0)], [Vector3(0, 0, 20.4), Vector3(44, 12, 1.0)],
			[Vector3(-20.4, 0, 0), Vector3(1.0, 12, 44)], [Vector3(20.4, 0, 0), Vector3(1.0, 12, 44)]]
	for d in defs:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = d[1]
		cs.shape = sh
		cs.position = Vector3(d[0].x, GY + 5.0, d[0].z)
		body.add_child(cs)
	_farm.add_child.call_deferred(body)


## Rumput 3D bergoyang di tanah kosong (di luar petak, jalan, bangunan, dekorasi).
func _build_grass() -> void:
	var ok := func(x: float, z: float) -> bool:
		return x > -18.6 and x < 18.4 and z > -18.6 and z < 17.6 and _placer.ok(x, z, 0.05)
	Realism.grass.call_deferred(_farm, Rect2(-19.0, -19.0, 38.0, 37.0), 6500, GY, 17, ok)


func _setup_map() -> void:
	var hr := _house_rect()
	var rects: Array = [
		{"r": Rect2(-20, -20, 40, 40), "c": Color(0.58, 0.72, 0.42)},
		{"r": Rect2(-1.3, -1.5, 14.3, 1.0), "c": Color(0.76, 0.66, 0.46)},
		{"r": Rect2(-1.1, -1.5, 1.2, 17.0), "c": Color(0.76, 0.66, 0.46)},
		{"r": hr, "c": Color(0.66, 0.42, 0.28), "label": "Home", "outline": true},
	]
	var i := 1
	for pr in Layout.PLOTS:
		var r: Rect2i = pr
		rects.append({"r": Rect2(r.position.x, r.position.y, r.size.x, r.size.y), "c": Color(0.47, 0.32, 0.19), "label": "Field %d" % i, "outline": true})
		i += 1
	for fb in FARM_BUILDINGS:
		rects.append({"r": Scenery.footprint(fb[0], fb[1], fb[2], fb[3]), "c": Color(0.66, 0.42, 0.28), "outline": true})
	rects.append({"r": Rect2(-19.0, 4.0, 5.0, 4.0), "c": Color(0.80, 0.70, 0.40), "label": "Chickens", "outline": true, "fs": 13})
	rects.append({"r": Rect2(7.0, 12.8, 8.0, 4.5), "c": Color(0.62, 0.74, 0.38), "label": "Pasture", "outline": true, "fs": 13})
	_farm.set_meta("map_data", {
		"title": "Farm Map",
		"bounds": Rect2(-20, -20, 40, 40),
		"rects": rects,
		"marks": [
			{"p": Vector2(Layout.CHEST_POS.x, Layout.CHEST_POS.z), "label": "Chest", "c": Color(0.9, 0.65, 0.2)},
			{"p": Vector2(-0.5, 17.5), "label": "To the Village", "c": Color(0.35, 0.75, 0.30)},
		]})
