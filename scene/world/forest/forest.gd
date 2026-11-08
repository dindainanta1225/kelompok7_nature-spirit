extends Node3D
## Forest - hutan (dibangun lewat kode). Dipakai oleh forest1.tscn dan forest2.tscn (atur `forest_id`).
##   Forest 1 (mudah): 5 Imp + 3 Bear.   Forest 2 (sulit): 4 Werewolf + 4 Skeleton.
## Tiap pagi (hari berganti) 8 monster muncul di 8 dari 14 titik tetap; yang sudah dikalahkan tidak muncul lagi
## di hari yang sama (lihat scripts/combat/forest_state.gd). Pingsan di sini -> bangun di rumah (aturan GDD).
## Jalur: Village <-> Forest 1 <-> Forest 2.

const WorldArea := preload("res://scripts/map/world_area.gd")
const ExitScript := preload("res://scripts/map/scene_exit.gd")
const InteractScript := preload("res://scripts/map/interactable.gd")
const Placer := preload("res://scripts/world/placer.gd")
const Scenery := preload("res://scripts/world/scenery.gd")
const Realism := preload("res://scripts/world/realism.gd")
const DayCycle := preload("res://scripts/world/day_cycle.gd")
const Props := preload("res://scripts/world/prop_builder.gd")
const DecorUtil := preload("res://scripts/world/decor_util.gd")
const Ambient := preload("res://scripts/world/ambient_particles.gd")
const Monster := preload("res://scripts/combat/monster.gd")
const ForestState := preload("res://scripts/combat/forest_state.gd")
const CoinPickup := preload("res://scripts/combat/coin_pickup.gd")
const PLAYER_SCENE := "res://scene/player/player.tscn"
const VILLAGE_SCENE := "res://scene/world/village/village.tscn"
const FOREST1_SCENE := "res://scene/world/forest/forest1.tscn"
const FOREST2_SCENE := "res://scene/world/forest/forest2.tscn"
const LAND_LIB := "res://assets/Models/Land.meshlib"
const DECOR_LIB := "res://assets/Models/decor.meshlib"
const AMBIENCE := "res://sounds/chrysalyn-morning-forest-ambience-with-birds-chirping-562428.mp3"
const Visitors := preload("res://scripts/world/npc_visitors.gd")
const GY := 1.5
const X0 := -26                       # tanah x: X0 .. X1-1
const X1 := 26
const Z0 := -18
const Z1 := 18
const CLEARINGS := 14
const MONSTERS_PER_DAY := 8

@export var forest_id := 1

var _decor: GridMap
var _placer := Placer.new()
var _clearings: Array = []            # Vector2 (x, z): titik muncul monster
var _map_rects: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	Realism.flat = true                      # low-poly (home tetap realistis)
	set_meta("no_farming", true)
	_rng.seed = 7000 + forest_id * 131
	_pick_clearings()
	_build_environment()
	_build_ground()
	_build_path()
	_build_exits()
	_build_trees()
	_build_props()
	_build_player_and_area()
	_spawn_monsters()
	if forest_id == 1:                                # warga desa kadang jalan-jalan di jalur hutan 1
		var vis := Visitors.new()
		vis.place = "forest"
		var ex := float(X0) + 1.5
		vis.entrance = Vector3(ex, GY, path_z(ex, forest_id))
		for x in [-19.0, -15.0, -11.0, -7.0]:
			vis.spots.append(Vector3(x, GY, path_z(x, forest_id) + 1.2))
		add_child(vis)
	_spawn_coins()
	_build_audio()
	_setup_map()
	add_child(Ambient.new())
	_welcome.call_deferred()


# ------------------------------------------------------------------ bentuk jalur
## Tengah jalur setapak (z) pada posisi x.
static func path_z(x: float, fid: int) -> float:
	return sin(x * 0.22 + float(fid)) * 4.0 + sin(x * 0.07) * 2.0


func _pick_clearings() -> void:
	var tries := 0
	while _clearings.size() < CLEARINGS and tries < 600:
		tries += 1
		var p := Vector2(_rng.randf_range(-19.0, 19.0), _rng.randf_range(-13.0, 13.0))
		var ok := true
		for c in _clearings:
			if (c as Vector2).distance_to(p) < 6.0:
				ok = false
		if absf(p.y - path_z(p.x, forest_id)) > 9.0:
			ok = false
		if ok:
			_clearings.append(p)


# ------------------------------------------------------------------ lingkungan
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	Props.grade_environment(env)
	Realism.environment(env, 1)
	env.fog_enabled = true
	env.fog_light_color = Color(0.55, 0.68, 0.55) if forest_id == 1 else Color(0.42, 0.52, 0.50)
	env.fog_density = 0.012 if forest_id == 1 else 0.028
	env.ambient_light_energy = 0.9 if forest_id == 1 else 0.6
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	Realism.sun(sun, 0.95 if forest_id == 1 else 0.65)
	add_child(sun)
	DayCycle.attach(self, env, sun)


func _build_ground() -> void:
	var land := GridMap.new()
	land.name = "Land"
	land.mesh_library = load(LAND_LIB)
	land.cell_size = Vector3(1, 1, 1)
	var grass := land.mesh_library.find_item_by_name("block-grass-overhang-large")
	for x in range(X0, X1):
		for z in range(Z0, Z1):
			land.set_cell_item(Vector3i(x, 0, z), grass)
	add_child(land)
	_decor = GridMap.new()
	_decor.name = "Decor"
	_decor.mesh_library = load(DECOR_LIB)
	_decor.cell_size = Vector3(1, 1, 1)
	add_child(_decor)
	var tint := Color(0.30, 0.50, 0.24) if forest_id == 1 else Color(0.20, 0.36, 0.22)
	add_child(Props.lawn_base(Rect2(float(X0), float(Z0), float(X1 - X0), float(Z1 - Z0)), GY, tint))


func _build_path() -> void:
	var dirt := Color(0.55, 0.42, 0.26) if forest_id == 1 else Color(0.42, 0.34, 0.24)
	var x := float(X0)
	while x < float(X1):
		var cz := path_z(x + 1.2, forest_id)
		var r := Rect2(x, cz - 2.0, 2.4, 4.0)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(r.size.x, 0.05, r.size.y)
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = dirt.lightened(randf_range(-0.04, 0.04))
		m.roughness = 1.0
		mi.material_override = m
		mi.position = Vector3(r.get_center().x, GY + 0.03, r.get_center().y)
		add_child(mi)
		_placer.keep_rect(r.grow(0.4))
		_map_rects.append({"r": r, "c": Color(0.76, 0.66, 0.46)})
		x += 2.0


# ------------------------------------------------------------------ pintu keluar
func _exit(pos: Vector3, scene: String, spawn: String, prompt: String) -> void:
	var ex := ExitScript.new()
	ex.mode = InteractScript.Mode.AUTO
	ex.target_scene = scene
	ex.target_spawn = spawn
	ex.prompt = prompt
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 4.0, 6.0)
	cs.shape = box
	ex.add_child(cs)
	ex.position = pos
	add_child(ex)


func _build_exits() -> void:
	var wz := path_z(float(X0) + 1.0, forest_id)
	var ez := path_z(float(X1) - 2.0, forest_id)
	_exit(Vector3(float(X0) + 0.8, GY + 2.0, wz), VILLAGE_SCENE if forest_id == 1 else FOREST1_SCENE,
			"from_forest" if forest_id == 1 else "from_forest2", "Back to the Village" if forest_id == 1 else "Back to Forest 1")
	_placer.keep_disc(float(X0) + 2.5, wz, 3.0)
	if forest_id == 1:
		_exit(Vector3(float(X1) - 1.0, GY + 2.0, ez), FOREST2_SCENE, "from_forest1", "Deeper into the woods (Forest 2)")
		_placer.keep_disc(float(X1) - 3.0, ez, 3.0)
	else:
		# ujung jalan: tanda saja
		var sign_area := InteractScript.new()
		sign_area.mode = InteractScript.Mode.PRESS
		sign_area.prompt = "Old signpost"
		sign_area.arm_delay = 0.0
		var cs2 := CollisionShape3D.new()
		var b2 := BoxShape3D.new()
		b2.size = Vector3(4.0, 4.0, 5.0)
		cs2.shape = b2
		sign_area.add_child(cs2)
		sign_area.position = Vector3(float(X1) - 3.0, GY + 2.0, ez)
		sign_area.interacted.connect(func(_p: Node3D) -> void:
			HUD.say("Signpost", ["The path ends in thick fog. Nobody has ever come back from further in...", "(Nothing more to find here. Go back and sell your loot!)"]))
		add_child(sign_area)
		_placer.keep_disc(float(X1) - 3.0, ez, 3.0)


# ------------------------------------------------------------------ pohon & dekor
func _build_trees() -> void:
	var lib := _decor.mesh_library
	var tree := lib.find_item_by_name("tree")
	var pine := lib.find_item_by_name("tree-pine")
	var density := 0.42 if forest_id == 1 else 0.6
	var rng := RandomNumberGenerator.new()
	rng.seed = 90 + forest_id
	for x in range(X0, X1):
		for z in range(Z0, Z1):
			var edge := x <= X0 + 1 or x >= X1 - 2 or z <= Z0 + 1 or z >= Z1 - 2
			var cx := float(x) + 0.5
			var cz := float(z) + 0.5
			var near_path := absf(cz - path_z(cx, forest_id)) < 3.4
			if near_path and (x <= X0 + 1 or x >= X1 - 2):
				continue                                          # jalan masuk/keluar
			var in_clear := false
			for c in _clearings:
				if (c as Vector2).distance_to(Vector2(cx, cz)) < 3.2:
					in_clear = true
			var put := false
			if edge:
				put = not near_path
			elif not near_path and not in_clear:
				put = rng.randf() < density
			if put:
				_decor.set_cell_item(Vector3i(x, 1, z), pine if rng.randf() < (0.5 if forest_id == 1 else 0.7) else tree, [0, 10, 16, 22][rng.randi_range(0, 3)])
	# bunga/jamur/rumput/batu kecil
	var names := ["flowers", "grass", "mushrooms", "rocks", "plant", "flowers-tall"] if forest_id == 1 else ["mushrooms", "rocks", "grass", "plant", "mushrooms"]
	for i in 160:
		var x2 := rng.randi_range(X0 + 2, X1 - 3)
		var z2 := rng.randi_range(Z0 + 2, Z1 - 3)
		var cx2 := float(x2) + 0.5
		var cz2 := float(z2) + 0.5
		if absf(cz2 - path_z(cx2, forest_id)) < 2.6 or _decor.get_cell_item(Vector3i(x2, 1, z2)) >= 0:
			continue
		var item := lib.find_item_by_name(names[rng.randi() % names.size()])
		if item >= 0:
			_decor.set_cell_item(Vector3i(x2, 1, z2), item, [0, 10, 16, 22][rng.randi_range(0, 3)])
	DecorUtil.make_walkable(_decor)


func _build_props() -> void:
	for c in _clearings:
		_placer.keep_disc((c as Vector2).x, (c as Vector2).y, 2.0)
	var sc := Scenery.new(_placer, GY)
	sc.scatter(self, Rect2(float(X0 + 2), float(Z0 + 2), float(X1 - X0 - 4), float(Z1 - Z0 - 4)), 70, 40 + forest_id, 1.8)
	var gok := func(x: float, z: float) -> bool:
		return x > float(X0 + 1) and x < float(X1 - 1) and z > float(Z0 + 1) and z < float(Z1 - 1) and _placer.ok(x, z, 0.05)
	Realism.grass(self, Rect2(float(X0), float(Z0), float(X1 - X0), float(Z1 - Z0)), 6000, GY, 29 + forest_id, gok, Color(0.07, 0.17, 0.05), Color(0.26, 0.42, 0.13))
	# tebangan & tumpukan kayu di dekat jalur
	var wl := _rng.randf_range(-14.0, -6.0)
	for k in 3:
		var x := wl + float(k) * 11.0
		var z := path_z(x, forest_id) + (3.6 if k % 2 == 0 else -3.6)
		if _placer.ok(x, z, 1.0):
			var wp := Props.woodpile()
			wp.position = Vector3(x, GY, z)
			wp.rotation.y = _rng.randf() * TAU
			add_child(wp)
			_placer.claim(x, z, 1.0)
	# tanda peringatan di dekat pintu masuk
	var sx := float(X0) + 4.5
	var sz := path_z(sx, forest_id) - 3.0
	var sg := load("res://assets/Models/GLB format/sign.glb")
	if sg != null and _placer.ok(sx, sz, 0.6):
		var s: Node3D = sg.instantiate()
		s.position = Vector3(sx, GY, sz)
		s.scale = Vector3.ONE * 2.2
		add_child(s)
		_placer.claim(sx, sz, 0.6)


# ------------------------------------------------------------------ player & area
func _build_player_and_area() -> void:
	var player: Node3D = load(PLAYER_SCENE).instantiate()
	var wz := path_z(float(X0) + 3.0, forest_id)
	player.position = Vector3(float(X0) + 3.0, GY + 1.0, wz)
	add_child(player)
	var area := WorldArea.new()
	area.area_name = "Forest %d" % forest_id
	area.default_spawn = "default"
	var ez := path_z(float(X1) - 4.0, forest_id)
	var spawns := [["default", Vector3(float(X0) + 3.0, GY + 0.6, wz)],
			["from_village", Vector3(float(X0) + 3.0, GY + 0.6, wz)],
			["from_forest2", Vector3(float(X1) - 4.0, GY + 0.6, ez)],
			["from_forest1", Vector3(float(X0) + 3.0, GY + 0.6, wz)]]
	for spawn in spawns:
		var m := Marker3D.new()
		m.name = spawn[0]
		m.position = spawn[1]
		m.add_to_group("spawn")
		area.add_child(m)
	add_child(area)


# ------------------------------------------------------------------ monster
func _spawn_monsters() -> void:
	var day: int = GameState.day
	var drng := RandomNumberGenerator.new()
	drng.seed = forest_id * 100003 + day * 7919 + int(GameState.get("run_stamp")) % 997
	var idxs: Array = range(_clearings.size())
	for i in range(idxs.size() - 1, 0, -1):                      # acak urutan titik
		var j := drng.randi_range(0, i)
		var t = idxs[i]
		idxs[i] = idxs[j]
		idxs[j] = t
	var comp: Array = []
	if forest_id == 1:
		comp = ["slime", "slime", "slime", "goblin", "goblin", "goblin", "boar", "boar"]
	else:
		comp = ["wolf", "wolf", "wolf", "skeleton", "skeleton", "skeleton", "hunter", "hunter"]
	for i in MONSTERS_PER_DAY:
		if ForestState.is_killed(forest_id, day, i):
			continue
		var c: Vector2 = _clearings[idxs[i]]
		var m := Monster.new()
		m.kind = comp[i]
		m.forest_id = forest_id
		m.spawn_index = i
		m.home = Vector3(c.x, GY, c.y)
		var sv := ForestState.saved_monster(forest_id, day, i)
		if not sv.is_empty():
			m.home = Vector3(sv["pos"].x, GY, sv["pos"].z)
			m.saved_hp = int(sv["hp"])
		m.ground_y = GY
		add_child(m)


## Koin tambahan: tiap hari 1-2 tumpukan koin muncul acak (ukuran tumpukan & jumlah acak) di tempat terbuka (jalan setapak & sekitar titik monster).
func _spawn_coins() -> void:
	var day: int = GameState.day
	var crng := RandomNumberGenerator.new()
	crng.seed = forest_id * 77003 + day * 6173 + int(GameState.get("run_stamp")) % 991
	var n := crng.randi_range(1, 2)                        # hanya 1-2 tumpukan koin per hari
	for i in n:
		var pos := Vector2.ZERO
		if crng.randf() < 0.5 and not _clearings.is_empty():
			var c: Vector2 = _clearings[crng.randi() % _clearings.size()]
			var a := crng.randf() * TAU
			pos = c + Vector2(cos(a), sin(a)) * crng.randf_range(0.8, 2.4)
		else:
			var x := crng.randf_range(X0 + 6.0, X1 - 6.0)
			pos = Vector2(x, path_z(x, forest_id) + crng.randf_range(-1.6, 1.6))
		var info: Array = CoinPickup.roll(crng)
		if ForestState.is_coin_taken(forest_id, day, i):
			continue
		var coin := CoinPickup.new()
		coin.rank = info[0]
		coin.amount = info[1]
		coin.forest_id = forest_id
		coin.coin_index = i
		coin.ground_y = GY
		coin.position = Vector3(pos.x, GY + 0.05, pos.y)
		add_child(coin)


func _welcome() -> void:
	if GameState.tool_level("sword") <= 0:
		GameState.toast.emit("Monsters live here. You'll want a sword (Blacksmith, Gordon).")
	else:
		GameState.toast.emit("Forest %d - %s" % [forest_id, "Imps, Goblins and Bears" if forest_id == 1 else "Werewolves, Skeletons and Hunters (dangerous!)"])


func _build_audio() -> void:
	if not ResourceLoader.exists(AMBIENCE):
		return
	var p := AudioStreamPlayer.new()
	var st = load(AMBIENCE)
	if st is AudioStreamMP3:
		st.loop = true
	p.stream = st
	p.volume_db = -16.0
	add_child(p)
	p.play()


func _setup_map() -> void:
	var rects: Array = [{"r": Rect2(float(X0), float(Z0), float(X1 - X0), float(Z1 - Z0)), "c": Color(0.40, 0.58, 0.34) if forest_id == 1 else Color(0.30, 0.44, 0.30)}]
	rects.append_array(_map_rects)
	var marks: Array = [{"p": Vector2(float(X0) + 2.0, path_z(float(X0) + 2.0, forest_id)), "label": "Village" if forest_id == 1 else "Forest 1", "c": Color(0.35, 0.75, 0.30)}]
	if forest_id == 1:
		marks.append({"p": Vector2(float(X1) - 2.5, path_z(float(X1) - 2.5, forest_id)), "label": "Forest 2", "c": Color(0.85, 0.45, 0.25)})
	set_meta("map_data", {"title": "Forest %d" % forest_id, "bounds": Rect2(float(X0), float(Z0), float(X1 - X0), float(Z1 - Z0)), "rects": rects, "marks": marks})
