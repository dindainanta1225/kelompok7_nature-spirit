extends Node3D
## Village - desa Nature Spirit, dibangun lewat kode (tanah Land.meshlib, dekor decor.meshlib, bangunan FBX).
##   General Store (Martha)  - beli benih, jual hasil panen / loot
##   Blacksmith (Gordon)     - upgrade alat & beli pedang
##   Food Shop (Lily)        - makanan pemulih energi
##   Mayor Harold, Anna, Old Tom, Mia, Farmer Joe, Granny Rose - quest warga (lihat quest_data.gd)
## Pintu keluar ke Farm ada di tepi selatan. Jalan ke Forest 1 ada di tepi timur.
##
## Mau menambah/mengubah isi desa: edit _build_buildings(), _build_npcs() di bawah.

const WorldArea := preload("res://scripts/map/world_area.gd")
const ExitScript := preload("res://scripts/map/scene_exit.gd")
const ModelUtil := preload("res://scripts/world/model_util.gd")
const Ambient := preload("res://scripts/world/ambient_particles.gd")
const Props := preload("res://scripts/world/prop_builder.gd")
const Placer := preload("res://scripts/world/placer.gd")
const Scenery := preload("res://scripts/world/scenery.gd")
const Realism := preload("res://scripts/world/realism.gd")
const DayCycle := preload("res://scripts/world/day_cycle.gd")
const Critter := preload("res://scripts/world/critter.gd")
const DecorUtil := preload("res://scripts/world/decor_util.gd")
const NpcSchedule := preload("res://scripts/world/npc_schedule.gd")
const NpcRoster := preload("res://scripts/world/npc_roster.gd")
const QuestData := preload("res://scripts/managers/quest_data.gd")
const InteractScript := preload("res://scripts/map/interactable.gd")
const NPCActor := preload("res://scripts/world/npc_actor.gd")
const PLAYER_SCENE := "res://scene/player/player.tscn"
const FOREST1_SCENE := "res://scene/world/forest/forest1.tscn"
const FARM_SCENE := "res://scene/world/farm/farm.tscn"
const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"
const LAND_LIB := "res://assets/Models/Land.meshlib"
const DECOR_LIB := "res://assets/Models/decor.meshlib"
const AMBIENCE := "res://sounds/chrysalyn-morning-forest-ambience-with-birds-chirping-562428.mp3"

const GY := 1.5                       # tinggi permukaan tanah (puncak tile "block-grass-overhang-large", sama seperti Farm)
const HALF := 28                      # tanah dari -HALF .. HALF-1
const WALL := 26                      # ring pohon di luar batas ini
const BS := 2.0                       # skala bangunan

var _font: Font
var _blocked: Array = []              # Rect2 (x,z) yang tidak boleh diberi dekor
var _decor: GridMap
var _map_rects: Array = []            # untuk peta (M)
var _npc_nodes := {}                  # id -> NPCActor
## Bangunan pertanian tambahan (aset FBX): [kunci, x, z, skala]
const EXTRA_BUILDINGS := [["OpenBarn", -21.0, 3.5, 0.85], ["Windmill", 21.8, -18.0, 0.75], ["WaterTower", 23.0, 0.0, 0.9], ["Coop", -12.0, -0.8, 1.2]]

var _placer := Placer.new()
var _scenery
var _loc := {}                        # id -> "village" | "farm" | "forest" | "away"
var _spots := {}                      # id -> [[nama tempat, Vector3], ...]


func _ready() -> void:
	Realism.flat = true                      # low-poly (home tetap realistis)
	set_meta("no_farming", true)               # tidak bisa mencangkul di desa
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	_build_environment()
	_build_ground()
	_build_roads()
	_build_buildings()
	_build_well()
	_build_exits()
	_build_npcs()
	_setup_schedule()
	_build_decor()
	DecorUtil.make_walkable(_decor)              # bunga & rumput bisa ditembus
	_build_props()
	_build_audio()
	_build_player_and_area()
	_setup_map()
	_setup_routes()
	add_child(Ambient.new())                   # daun berguguran + serbuk cahaya
	if GameState.playing and GameState.intro_stage == 0 and not GameState.guide_met and GameState.ending_kind == "":
		add_child(load("res://scripts/world/village_intro.gd").new())        # cerita pembuka: Mayor + Centorea


# ------------------------------------------------------------------ lingkungan
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	Props.grade_environment(env)
	Realism.environment(env, 0)
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	Realism.sun(sun)
	add_child(sun)
	DayCycle.attach(self, env, sun)


func _build_ground() -> void:
	var land := GridMap.new()
	land.name = "Land"
	land.mesh_library = load(LAND_LIB)
	land.cell_size = Vector3(1, 1, 1)
	var grass := land.mesh_library.find_item_by_name("block-grass-overhang-large")   # tile datar yang sama dengan Farm
	for x in range(-HALF, HALF):
		for z in range(-HALF, HALF):
			land.set_cell_item(Vector3i(x, 0, z), grass)
	add_child(land)
	_decor = GridMap.new()
	_decor.name = "Decor"
	_decor.mesh_library = load(DECOR_LIB)
	_decor.cell_size = Vector3(1, 1, 1)
	add_child(_decor)


func _flat(rect: Rect2, color: Color, y_off := 0.03, block := true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(rect.size.x, 0.06, rect.size.y)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	mi.material_override = m
	mi.position = Vector3(rect.position.x + rect.size.x * 0.5, GY + y_off, rect.position.y + rect.size.y * 0.5)
	add_child(mi)
	_map_rects.append({"r": rect, "c": color.lightened(0.15) if y_off < 0.05 else Color(0.78, 0.78, 0.80), "label": "Plaza" if y_off >= 0.05 else ""})
	if block:
		_blocked.append(rect.grow(1.0))
	if y_off < 0.05:
		_placer.keep_rect(rect)                       # jalan: tidak boleh ada dekorasi


func _build_roads() -> void:
	var dirt := Color(0.58, 0.45, 0.28)
	_flat(Rect2(-2.5, -7.0, 5.0, 34.0), dirt)              # jalan utama utara-selatan
	_flat(Rect2(-24.0, -7.0, 48.0, 4.0), dirt)            # jalan toko
	_flat(Rect2(-24.0, 16.0, 48.0, 4.0), dirt)            # jalan rumah warga
	_flat(Rect2(5.0, -18.0, 4.0, 11.0), dirt)             # jalan ke balai desa
	_flat(Rect2(-6.0, -2.0, 12.0, 12.0), Color(0.40, 0.40, 0.44), 0.05)   # alun-alun batu
	_flat(Rect2(2.5, 3.0, 22.0, 3.0), dirt)               # jalan ke Forest (timur)


# ------------------------------------------------------------------ bangunan
## Taruh bangunan: pusat footprint (cx) dan bidang depan (front_z, pintu menghadap +Z). Kembalikan pusat footprint.
func _place_building(bname: String, cx: float, front_z: float, scale: float, sign_text := "", sign_w := 4.4) -> Vector3:
	var inst: Node3D = load("res://assets/Buildings/FBX/%s.fbx" % bname).instantiate()
	var raw := ModelUtil.bounds(inst)                                   # ukuran asli model (sebelum skala)
	var cz := front_z - raw.size.z * scale * 0.5
	var box := ModelUtil.place(inst, scale, cx, cz, GY)                 # dasar pas di tanah
	add_child(inst)
	# tabrakan
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	cs.shape = shape
	body.position = Vector3(cx, GY + box.size.y * 0.5, cz)
	body.add_child(cs)
	add_child(body)
	_blocked.append(Rect2(cx - box.size.x * 0.5 - 1.0, front_z - box.size.z - 1.0, box.size.x + 2.0, box.size.z + 2.0))
	_placer.keep_rect(Rect2(cx - box.size.x * 0.5 - 0.3, front_z - box.size.z - 0.3, box.size.x + 0.6, box.size.z + 0.6))
	var map_names := {"Bell_Tower": "Bell Tower", "Mill": "Mill", "Sawmill": "Sawmill", "House_1": "House", "House_2": "House", "House_4": "House"}
	_map_rects.append({"r": Rect2(cx - box.size.x * 0.5, front_z - box.size.z, box.size.x, box.size.z), "c": Color(0.66, 0.42, 0.28),
			"label": sign_text if sign_text != "" else String(map_names.get(bname, "")), "outline": true, "fs": 14})
	if sign_text != "":
		_make_sign(Vector3(cx, GY + 3.7, front_z + 0.5), sign_text, sign_w)
	return Vector3(cx, GY, cz)


func _make_sign(pos: Vector3, text: String, w: float) -> void:
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, 1.0, 0.18)
	board.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.40, 0.25, 0.13)
	m.roughness = 0.9
	board.material_override = m
	board.position = pos
	add_child(board)
	for sx in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.09
		pm.bottom_radius = 0.09
		pm.height = pos.y - GY + 0.5
		post.mesh = pm
		post.material_override = m
		post.position = Vector3(pos.x + sx * (w * 0.5 - 0.2), GY + (pos.y - GY + 0.5) * 0.5 - 0.5 + 0.25, pos.z)
		add_child(post)
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.pixel_size = 0.0075
	l.outline_size = 16
	l.modulate = Color(1.0, 0.92, 0.62)
	l.outline_modulate = Color(0.16, 0.08, 0.03)
	l.position = pos + Vector3(0, 0, 0.11)
	if _font:
		l.font = _font
	add_child(l)


func _build_buildings() -> void:
	# Barisan toko (pintu menghadap selatan ke jalan toko)
	_place_building("Stable", -14.0, -8.0, BS, "General Store", 5.2)
	_place_building("Blacksmith", 0.0, -8.0, BS, "Blacksmith", 4.6)
	_place_building("Inn", 14.0, -8.0, BS, "Food Shop", 4.4)
	# Balai desa
	_place_building("House_3", 7.0, -17.0, BS, "Village Hall", 4.6)
	_place_building("Bell_Tower", -7.0, -17.0, 1.5)
	_place_building("Mill", -20.0, -12.0, 1.4)
	# Rumah warga
	_place_building("House_1", -16.0, 15.0, BS)
	_place_building("House_2", -8.0, 15.0, BS)
	_place_building("House_4", 8.0, 15.0, BS)
	_place_building("Sawmill", 17.0, 15.0, BS)
	_scenery = Scenery.new(_placer, GY)
	for eb in EXTRA_BUILDINGS:
		if _scenery.building(self, eb[0], eb[1], eb[2], eb[3]):
			var fp := Scenery.footprint(eb[0], eb[1], eb[2], eb[3])
			_blocked.append(fp.grow(1.0))
			_map_rects.append({"r": fp, "c": Color(0.66, 0.42, 0.28), "outline": true})


func _build_well() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.50, 0.52, 0.56)
	stone.roughness = 1.0
	var ring := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.5
	cm.bottom_radius = 1.6
	cm.height = 0.9
	ring.mesh = cm
	ring.material_override = stone
	ring.position = Vector3(0, GY + 0.45, 4.0)
	add_child(ring)
	var water := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 1.2
	wm.bottom_radius = 1.2
	wm.height = 0.05
	water.mesh = wm
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.30, 0.60, 0.85)
	wmat.roughness = 0.2
	water.material_override = wmat
	water.position = Vector3(0, GY + 0.86, 4.0)
	add_child(water)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 1.6
	sh.height = 1.2
	cs.shape = sh
	body.position = Vector3(0, GY + 0.6, 4.0)
	body.add_child(cs)
	add_child(body)


# ------------------------------------------------------------------ pintu keluar & tanda
func _build_exits() -> void:
	# ke Farm (tepi selatan)
	var ex := ExitScript.new()
	ex.mode = InteractScript.Mode.AUTO
	ex.target_scene = FARM_SCENE
	ex.target_spawn = "from_village"
	ex.prompt = "Go to Farm"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 4.0, 1.6)
	cs.shape = box
	ex.add_child(cs)
	ex.position = Vector3(0, GY + 2.0, float(HALF) - 2.2)
	add_child(ex)
	# ke Forest 1 (tepi timur, ujung jalan hutan)
	var fx := ExitScript.new()
	fx.mode = InteractScript.Mode.AUTO
	fx.target_scene = FOREST1_SCENE
	fx.target_spawn = "from_village"
	fx.prompt = "Go to Forest 1"
	var cs2 := CollisionShape3D.new()
	var b2 := BoxShape3D.new()
	b2.size = Vector3(1.6, 4.0, 6.0)
	cs2.shape = b2
	fx.add_child(cs2)
	fx.position = Vector3(float(WALL) - 1.5, GY + 2.0, 4.5)
	add_child(fx)


# ------------------------------------------------------------------ NPC
func _npc(id: String, name: String, pos: Vector3, shop: String, greet: Array, look: Dictionary) -> void:
	var n := NPCActor.new()
	n.npc_id = id
	n.display_name = name
	n.shop_id = shop
	n.greetings = greet
	n.look = look
	n.position = Vector3(pos.x, GY, pos.z)
	add_child(n)
	_npc_nodes[id] = n
	_spots[id] = [[("At the shop" if shop != "" else "Village"), pos]]


func _build_npcs() -> void:
	for id in NpcRoster.IDS:
		var d: Dictionary = NpcRoster.DATA[id]
		var first: Vector3 = d["spots"][0][1]
		_npc(id, d["name"], first, d["shop"], d["greet"], d["look"])
		_spots[id] = d["spots"]


# ------------------------------------------------------------------ jadwal NPC
func _setup_schedule() -> void:
	GameState.day_changed.connect(func(_d: int) -> void: _apply_schedule(false))
	GameState.hour_changed.connect(func(_h: int) -> void: _apply_schedule(false))
	_apply_schedule(true)


## Atur siapa ada di mana sesuai hari/jam (npc_schedule.gd). Saat jam berganti warga BERJALAN lewat jalan (menghindari
## bangunan & sumur) ke tempat barunya. Jadwal ke Hutan: berjalan ke ujung jalan timur lalu menghilang. MALAM (>= 19:00):
## semua berjalan pulang ke pintu rumahnya lalu masuk (menghilang); paginya mereka keluar dari pintu yang sama.
func _apply_schedule(initial: bool) -> void:
	var day: int = GameState.day
	var hour: int = GameState.hour()
	for id in _npc_nodes.keys():
		var n: Node3D = _npc_nodes[id]
		var spots: Array = _spots[id]
		var w := NpcSchedule.where(id, day, hour, spots.size())
		var prev := String(_loc.get(id, "away"))
		_loc[id] = w["where"]
		var door: Vector3 = spots[0][1]
		if w["where"] == "village":
			var sp: Array = spots[int(w["spot"]) % spots.size()]
			var dest := Vector3(sp[1].x, GY, sp[1].z)
			n.set("spot_name", sp[0])
			if initial:
				n.position = dest
				n.visible = true
			elif not n.visible:                                      # baru datang: keluar dari rumah / masuk dari ujung jalan hutan
				var entry := Vector3(door.x, GY, door.z)
				if prev == "forest":
					entry = Vector3(NpcSchedule.FOREST_EXIT.x, GY, NpcSchedule.FOREST_EXIT.z)
				n.position = entry
				n.visible = true
				n.walk_along(NpcSchedule.route(n.position, dest))
			else:
				n.walk_along(NpcSchedule.route(n.position, dest))
		else:
			var label := "In the forest" if w["where"] == "forest" else ("Asleep at home" if NpcSchedule.is_night(hour) else "At home")
			n.set("spot_name", label)
			var exit_pt := Vector3(door.x, GY, door.z)
			if w["where"] == "forest":
				exit_pt = Vector3(NpcSchedule.FOREST_EXIT.x, GY, NpcSchedule.FOREST_EXIT.z)
			if initial or not n.visible:
				n.visible = false
				n.position = Vector3(0, -200, 0)
			else:
				n.walk_along(NpcSchedule.route(n.position, exit_pt), func() -> void:
					n.visible = false
					n.position = Vector3(0, -200, 0))


## Rintangan untuk jalur jalan warga: bangunan (kotak), sumur, & semua benda yang sudah ditaruh Placer (bundar).
func _setup_routes() -> void:
	var rects: Array = []
	var roads: Array = []
	for m in _map_rects:
		if m.get("outline", false):
			rects.append(m["r"])
		elif m.get("label", "") != "Plaza":
			roads.append(m["r"])
		else:
			roads.append(m["r"])
	var discs: Array = [Vector3(0, 4.0, 2.2)]                      # sumur di tengah alun-alun
	for d in _placer.placed:
		if d.z < 3.0:
			discs.append(Vector3(d.x, d.y, d.z * 0.7 + 0.1))
	NpcSchedule.set_obstacles(rects, discs, roads)


# ------------------------------------------------------------------ peta (M)
func _setup_map() -> void:
	var rects: Array = [{"r": Rect2(-WALL, -WALL, WALL * 2, WALL * 2), "c": Color(0.58, 0.72, 0.42)}]
	rects.append_array(_map_rects)
	set_meta("map_data", {
		"title": "Village Map",
		"bounds": Rect2(-26, -21, 52, 47),
		"rects": rects,
		"marks": [
			{"p": Vector2(0, float(HALF) - 2.2), "label": "To the Farm", "c": Color(0.35, 0.75, 0.30)},
			{"p": Vector2(float(WALL) - 3.5, 4.5), "label": "Forest 1", "c": Color(0.35, 0.75, 0.30)},
		]})


# ------------------------------------------------------------------ dekor
func _in_blocked(x: float, z: float) -> bool:
	for r in _blocked:
		if (r as Rect2).has_point(Vector2(x, z)):
			return true
	return false


func _build_decor() -> void:
	var lib := _decor.mesh_library
	var tree := lib.find_item_by_name("tree")
	var pine := lib.find_item_by_name("tree-pine")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	# ring pohon di tepi (dengan celah di gerbang selatan)
	for x in range(-HALF, HALF):
		for z in range(-HALF, HALF):
			var edge := maxi(absi(x), absi(z)) >= WALL - (1 if (x + z) % 2 == 0 else 0)
			if not edge:
				continue
			if z >= WALL - 3 and absi(x) <= 3:
				continue                                  # gerbang ke Farm
			if x >= WALL - 3 and absi(z - 4) <= 3:
				continue                                  # jalan Forest (tertutup tanda)
			_decor.set_cell_item(Vector3i(x, 1, z), pine if rng.randf() < 0.45 else tree)
	# hiasan acak
	var names := ["flowers", "flowers-tall", "grass", "rocks", "mushrooms", "plant", "tree", "tree-pine"]
	var weights := [5, 4, 5, 1, 2, 3, 2, 2]
	var bag: Array = []
	for i in names.size():
		for k in weights[i]:
			bag.append(names[i])
	for i in 260:
		var x := rng.randi_range(-WALL + 2, WALL - 3)
		var z := rng.randi_range(-WALL + 2, WALL - 3)
		if _in_blocked(x + 0.5, z + 0.5):
			continue
		var nm: String = bag[rng.randi() % bag.size()]
		var item := lib.find_item_by_name(nm)
		if item >= 0:
			_decor.set_cell_item(Vector3i(x, 1, z), item, [0, 10, 16, 22][rng.randi_range(0, 3)])   # 4 putaran tegak (jangan 5/15: miring)


# ------------------------------------------------------------------ dekorasi desa
func _prop(node: Node3D, x: float, z: float, yaw := 0.0, r := 0.7) -> void:
	_placer.place(self, node, x, z, GY, r, yaw)


## Area terlarang untuk dekorasi: titik berdiri semua NPC (semua tempat jadwalnya) dan titik toko.
func _reserve_spots() -> void:
	_placer.keep_disc(0.0, 4.0, 1.8)                    # sumur alun-alun
	for id in _spots:
		for sp in _spots[id]:
			_placer.keep_disc(sp[1].x, sp[1].z, 1.1)
	for v in [Vector2(-14, -5.4), Vector2(0, -5.4), Vector2(14, -5.4), Vector2(7, -14.8)]:
		_placer.keep_disc(v.x, v.y, 1.1)


func _build_props() -> void:
	add_child(Props.lawn_base(Rect2(-float(WALL), -float(WALL), float(WALL) * 2.0, float(WALL) * 2.0), GY))
	_reserve_spots()
	# alun-alun: bangku & lampu (di luar jalan utama dan titik NPC)
	for p in [[-5.0, 1.0, 0.0], [5.7, 0.4, PI], [-5.2, 5.6, 0.0]]:
		_prop(Props.bench(), p[0], p[1], p[2], 1.0)
	for p in [[-5.5, -1.0], [5.5, -1.0], [-4.9, 10.0], [5.5, 9.5]]:
		_prop(Props.lamp_post(), p[0], p[1], 0.0, 0.3)
	_prop(Props.flower_bed(2.4, 0.9, 5), -8.5, 6.0, 0.0, 1.2)
	_prop(Props.flower_bed(2.4, 0.9, 9), 8.5, 8.2, 0.0, 1.2)
	# sisi toko (bukan di jalan / depan pintu): peti, tong, gerobak, kayu, jerami
	_prop(Props.cart(), -6.6, -9.8, 0.0, 1.5)
	_prop(Props.barrel(), -4.7, -12.8, 0.0, 0.5)
	_prop(Props.crate(0.8), -20.5, -9.5, 0.2, 0.65)
	_prop(Props.crate(0.6), -21.5, -10.4, -0.3, 0.5)
	_prop(Props.woodpile(), 20.4, -9.0, PI * 0.5, 1.0)
	_prop(Props.hay_bale(), 21.8, -11.6, 0.3, 0.9)
	for x in [-7.0, 7.0, 18.0, -18.0]:
		_prop(Props.lamp_post(), x, -2.6, 0.0, 0.3)
	# deretan rumah warga: bedeng bunga, kotak surat, semak di celah antar rumah
	_prop(Props.flower_bed(2.0, 0.8, 12), -12.05, 11.5, 0.0, 1.1)
	_prop(Props.flower_bed(1.6, 0.7, 14), 11.25, 12.0, 0.0, 0.8)
	_prop(Props.mailbox(), -12.0, 14.0, 0.0, 0.3)
	_prop(Props.mailbox(), -4.2, 14.0, 0.0, 0.3)
	_prop(Props.mailbox(), 11.25, 14.2, 0.0, 0.3)
	_prop(Props.bush(0.8), -19.6, 13.0, 0.0, 0.9)
	_prop(Props.bush(0.7), 4.3, 13.0, 0.0, 0.8)
	_prop(Props.bush(0.9), 22.8, 12.0, 0.0, 1.0)
	_prop(Props.lamp_post(), -3.6, 21.0, 0.0, 0.3)
	_prop(Props.lamp_post(), 3.6, 21.0, 0.0, 0.3)
	# taburan bunga, jamur, batu, rumput, pohon kecil (aset GLB) di tanah kosong
	_placer.keep_rect(Rect2(-6.0, -2.0, 12.0, 12.0))               # alun-alun batu
	_placer.keep_disc(0.0, 26.0, 4.0)                              # pintu ke Farm
	_placer.keep_disc(22.5, 4.5, 3.5)                              # tanda jalan ke Forest
	_scenery.scatter(self, Rect2(-25.0, -24.0, 50.0, 48.0), 150, 9)
	var gok := func(x: float, z: float) -> bool:
		return absf(x) < 24.5 and absf(z) < 24.5 and _placer.ok(x, z, 0.05)
	Realism.grass(self, Rect2(-25.0, -25.0, 50.0, 50.0), 7500, GY, 23, gok)
	# ayam & kupu-kupu
	for i in 4:
		var c := Critter.new()
		c.kind = "chicken"
		c.home = Vector3(-12.0, GY, 3.2)
		c.radius = 1.7
		c.ground_y = GY
		add_child(c)
	var bcols := [Color(1.0, 0.7, 0.2), Color(0.5, 0.7, 1.0), Color(1.0, 0.55, 0.7), Color(0.95, 0.95, 0.5)]
	for i in 8:
		var b := Critter.new()
		b.kind = "butterfly"
		b.home = Vector3(-18.0 + float(i) * 5.0, GY, 6.0 + float(i % 3) * 4.0)
		b.radius = 6.0
		b.ground_y = GY
		b.wing_color = bcols[i % bcols.size()]
		add_child(b)


# ------------------------------------------------------------------ suara
func _build_audio() -> void:
	if not ResourceLoader.exists(AMBIENCE):
		return
	var p := AudioStreamPlayer.new()
	var st = load(AMBIENCE)
	if st is AudioStreamMP3:
		st.loop = true
	p.stream = st
	p.volume_db = -14.0
	add_child(p)
	p.play()


# ------------------------------------------------------------------ player + area
func _build_player_and_area() -> void:
	var player: Node3D = load(PLAYER_SCENE).instantiate()
	player.position = Vector3(0, GY + 1.0, float(HALF) - 6.0)
	add_child(player)
	var area := WorldArea.new()
	area.area_name = "Village"
	area.default_spawn = "default"
	for spawn in [["default", Vector3(0, GY + 0.6, 20.0)], ["from_farm", Vector3(0, GY + 0.6, 22.0)], ["from_forest", Vector3(float(WALL) - 4.5, GY + 0.6, 4.5)]]:
		var m := Marker3D.new()
		m.name = spawn[0]
		m.position = spawn[1]
		m.add_to_group("spawn")
		area.add_child(m)
	add_child(area)                       # _ready WorldArea menaruh player di spawn yang dituju
