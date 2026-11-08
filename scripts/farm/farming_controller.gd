extends Node3D
const Sfx := preload("res://scripts/audio/sfx.gd")
## FarmingController - bercocok tanam sederhana. Dipasang otomatis oleh Player (tidak perlu atur scene).
##
## Tekan E (interact) pada petak di depan Player. Yang terjadi tergantung item di hotbar:
##   Benih          -> menanam (di mana saja, tanah otomatis digemburkan)
##   Watering Can   -> menyiram tanaman (hanya tanaman yang disiram hari itu yang tumbuh)
##   Hoe            -> menggemburkan tanah
##   Scythe         -> mencabut tanaman yang belum matang
##   (apa pun)      -> panen kalau tanaman sudah matang (tanda emas di atasnya)
## Tanaman tumbuh 1 hari tiap pagi kalau kemarin disiram. F10 (debug): semua tanaman +1 hari.

const Inv := preload("res://scripts/managers/inventory.gd")
const CropVisuals := preload("res://scripts/farm/crop_visuals.gd")
const ObstacleVisuals := preload("res://scripts/farm/obstacle_visuals.gd")
const ShopData := preload("res://scripts/shops/shop_data.gd")
const Layout := preload("res://scripts/farm/farm_layout.gd")

@export var require_tilled := true           # benih hanya bisa ditanam di tanah yang sudah di-Hoe
@export var max_plots := 0                   # 0 = tanpa batas; isi 50 untuk aturan GDD

var _player: CharacterBody3D
var _area := ""
var _visuals := {}                           # Vector2i -> Node3D
var _cursor: Node3D
var _cursor_mats: Array = []
var _cell := Vector2i.ZERO
var _ground_y := 0.0
var _has_ground := false
var _plan := {}
var _prompt_shown := false


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_player = get_parent() as CharacterBody3D
	_build_cursor()
	GameState.crops_changed.connect(_rebuild)
	GameState.playing_changed.connect(func(_on: bool) -> void: _rebuild())
	_init_area.call_deferred()


func _exit_tree() -> void:
	HUD.clear_prompt(self)


func _init_area() -> void:
	var cs := get_tree().current_scene
	_area = cs.scene_file_path if cs and cs.scene_file_path != "" else "default"
	_rebuild()


func _cells() -> Dictionary:
	return GameState.farm_cells(_area)


# ------------------------------------------------------------------ target & petunjuk

func _physics_process(_delta: float) -> void:
	if _area == "" or _player == null:
		return
	var active := GameState.playing and not GameState.input_locked and not GameState.chatting and not get_tree().paused
	_cursor.visible = active
	if not active:
		_plan = {}
		_set_prompt("")
		return
	if _farm_disabled():                       # mis. di Village: tidak bisa bertani, tapi tetap bisa makan
		_cursor.visible = false
		_plan = _eat_plan()
		_set_prompt(_plan.get("text", ""))
		return
	var f: Vector3 = _player.get("facing")
	var p := _player.global_position + f * 1.0
	_cell = Vector2i(floori(p.x), floori(p.z))
	_has_ground = _find_ground(Vector3(_cell.x + 0.5, _player.global_position.y, _cell.y + 0.5))
	_cursor.visible = _has_ground
	_plan = _make_plan() if _has_ground else {}
	_cursor.global_position = Vector3(_cell.x + 0.5, _ground_y + 0.04, _cell.y + 0.5)
	var col := Color(0.55, 1.0, 0.45, 0.9) if not _plan.is_empty() else Color(1, 1, 1, 0.45)
	for m in _cursor_mats:
		(m as StandardMaterial3D).albedo_color = col
	_set_prompt(_plan.get("text", ""), _plan.get("action", "") != "")


## Scene bertanda meta "no_farming" (Village) tidak bisa dicangkul/ditanami.
func _farm_disabled() -> bool:
	var cs := get_tree().current_scene
	return cs != null and cs.has_meta("no_farming")


## Makan / pakai Forest Herb dari hotbar (berlaku di mana saja).
func _eat_plan() -> Dictionary:
	var other = HUD.get("_prompt_owner")
	if other != null and other != self and is_instance_valid(other):
		return {}
	var held: String = GameState.inventory.selected_item()
	if held != "" and ShopData.food_energy(held) > 0.0:
		return {"action": "eat", "text": ("Use " if held == "forest_herb" else "Eat ") + _name_of(held)}
	return {}


## Dekor kecil ini boleh ditimpa tanaman; dekor lain (pohon, batu, pagar, peti, ...) memblokir petak.
const SOFT_DECOR := ["grass", "flowers", "flowers-tall", "plant", "mushrooms"]


func _find_ground(at: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var base_y := _player.global_position.y
	var q := PhysicsRayQueryParameters3D.create(Vector3(at.x, base_y + 0.7, at.z), Vector3(at.x, base_y - 2.0, at.z))
	q.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		_ground_y = base_y
		return true
	var pos: Vector3 = hit["position"]
	var col = hit["collider"]
	if col is GridMap and col.mesh_library != null:
		var g := col as GridMap
		var cell := g.local_to_map(g.to_local(pos - (hit["normal"] as Vector3) * 0.05))
		var item := g.get_cell_item(cell)
		if item >= 0:
			var nm: String = g.mesh_library.get_item_name(item)
			# Land punya banyak potongan (miring/overhang) -> tetap bisa ditanam; Decor tertentu memblokir
			if not nm.begins_with("block-") and not SOFT_DECOR.has(nm):
				return false
			if SOFT_DECOR.has(nm):
				_ground_y = base_y
				return true
	elif (hit["normal"] as Vector3).y < 0.7:
		return false
	_ground_y = pos.y
	return true


func _set_prompt(text: String, actionable := true) -> void:
	if text == "":
		if _prompt_shown:
			HUD.clear_prompt(self)
			_prompt_shown = false
	else:
		HUD.set_prompt(self, ("[E] " if actionable else "") + text)
		_prompt_shown = true


func _name_of(id: String) -> String:
	return Inv.items[id]["name"] if Inv.items.has(id) else id


func _ripe(cell: Dictionary) -> bool:
	return cell["crop"] != "" and int(cell["age"]) >= Inv.crop_days(cell["crop"])


## Tentukan aksi untuk petak yang dituju: {"action": ..., "text": ...} ("action" kosong = hanya petunjuk) atau {}.
func _make_plan() -> Dictionary:
	var other = HUD.get("_prompt_owner")          # pintu/kasur punya petunjuk E sendiri -> jangan bentrok
	if other != null and other != self and is_instance_valid(other):
		return {}
	var held: String = GameState.inventory.selected_item()
	var eat := _eat_plan()
	var in_plot: bool = _area == Layout.AREA and Layout.in_plot(_cell)
	if not in_plot:
		return eat                                # di luar petak tanam hanya bisa makan
	var cell: Dictionary = _cells().get(_cell, {})
	var obs: String = cell.get("obs", "")
	if obs != "":
		var need: String = Layout.OBSTACLE_TOOL[obs]
		if held == need:
			return {"action": "clear_obs", "text": "Clear " + String(Layout.OBSTACLE_NAME[obs]).to_lower()}
		return {}                                     # alat salah: tidak ada tulisan, tidak bisa apa-apa
	if not cell.is_empty() and _ripe(cell):
		return {"action": "harvest", "text": "Harvest " + _name_of(cell["crop"])}
	if not eat.is_empty():
		return eat
	if held.ends_with("_seed"):
		if not cell.is_empty() and cell["crop"] != "":
			return {}
		if cell.is_empty() or not cell["tilled"]:
			return {}                                 # belum dicangkul: tanpa tulisan, tidak bisa menanam
		return {"action": "plant", "text": "Plant " + _name_of(held)}
	match held:
		"watering_can":
			if not cell.is_empty() and cell["crop"] != "" and not cell["watered"]:
				return {"action": "water", "text": "Water"}
		"hoe":
			if cell.is_empty() or not cell["tilled"]:
				return {"action": "till", "text": "Till soil"}
		"scythe":
			if not cell.is_empty() and cell["crop"] != "":
				return {"action": "clear", "text": "Clear plant"}
	return {}


# ------------------------------------------------------------------ aksi

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if not GameState.playing or GameState.input_locked or GameState.chatting or get_tree().paused or _plan.is_empty() or _plan.get("action", "") == "":
		return
	_do(_plan["action"])
	get_viewport().set_input_as_handled()


func _tired() -> bool:
	GameState.toast.emit("Too tired...")
	return false


func _pay(cost: float) -> bool:
	return GameState.spend_energy(cost) or _tired()


## Arah hadap sebagai langkah grid (±1 di x atau z).
func _step() -> Vector2i:
	var f: Vector3 = _player.get("facing")
	return Vector2i(int(roundf(f.x)), int(roundf(f.z)))


## Petak yang kena alat: lurus ke depan sebanyak level alat (L1 = 1 petak, L3 = 3 petak).
func _line_cells(tool: String) -> Array:
	var n := ShopData.tiles_for_level(GameState.tool_level(tool))
	var out: Array = []
	for i in n:
		var c := _cell + _step() * i
		if not Layout.in_plot(c):
			continue
		if i == 0 or _find_ground(Vector3(c.x + 0.5, _player.global_position.y, c.y + 0.5)):
			out.append(c)
	return out


func _do(action: String) -> void:
	var cells := _cells()
	var inv = GameState.inventory
	if action == "eat":
		var id: String = inv.selected_item()
		var gain := ShopData.food_energy(id)
		if id == "forest_herb" or ShopData.WILD_FRUIT.has(id):
			GameState.restore_energy(gain)
		elif not GameState.try_eat(gain):
			return
		inv.remove(id, 1)
		GameState.toast.emit("+%d energy, +%d HP" % [int(gain), int(gain * GameState.HEAL_PER_ENERGY)])
		var pe := get_parent()
		if pe != null and pe.has_method("play_tool"):
			pe.play_tool("eat")
		return
	var pl := get_parent()
	if pl != null and pl.has_method("play_tool"):
		var kind := action
		if action == "till":
			kind = "hoe"
		elif action == "clear":
			kind = "scythe"
		elif action == "clear_obs":
			kind = String(inv.selected_item())
			kind = "hoe" if kind == "hoe" else "scythe"
		pl.play_tool(kind)
	var touched: Array = [_cell]
	match action:
		"plant":
			var seed_id: String = inv.selected_item()
			if not inv.remove(seed_id, 1):
				return
			cells[_cell] = {"tilled": true, "crop": seed_id.trim_suffix("_seed"), "age": 0, "watered": false}
			Sfx.play("plant")
		"water":
			if not _pay(GameState.COST_CAN):
				return
			touched = _line_cells("watering_can")
			for c in touched:
				var cell: Dictionary = cells.get(c, {})
				if not cell.is_empty() and cell["crop"] != "":
					cell["watered"] = true
		"till":
			if not _pay(GameState.COST_HOE):
				return
			touched = _line_cells("hoe")
			for c in touched:
				var cell: Dictionary = cells.get(c, {})
				if cell.is_empty():
					cells[c] = {"tilled": true, "crop": "", "age": 0, "watered": false, "obs": ""}
				elif cell.get("obs", "") == "":              # petak berbatu/berumput tidak ikut dicangkul
					cell["tilled"] = true
		"clear_obs":
			var tool_id: String = inv.selected_item()
			if not _pay(GameState.COST_SCYTHE if tool_id == "scythe" else GameState.COST_HOE):
				return
			touched = _line_cells(tool_id)
			for c in touched:
				var cell: Dictionary = cells.get(c, {})
				var o: String = cell.get("obs", "")
				if o != "" and Layout.OBSTACLE_TOOL[o] == tool_id:
					cell["obs"] = ""
		"clear":
			if not _pay(GameState.COST_SCYTHE):
				return
			touched = _line_cells("scythe")
			for c in touched:
				var cell: Dictionary = cells.get(c, {})
				if not cell.is_empty() and cell["crop"] != "":
					cell["crop"] = ""
					cell["age"] = 0
					cell["watered"] = false
		"harvest":
			if not _pay(GameState.COST_SCYTHE):
				return
			touched = _line_cells("scythe")
			for c in touched:
				var cell: Dictionary = cells.get(c, {})
				if cell.is_empty() or not _ripe(cell):
					continue
				if inv.add(cell["crop"], 1) > 0:
					GameState.toast.emit("Your bag is full!")
					break
				var rg: int = Inv.regrow_days(cell["crop"])
				if rg > 0:                                  # tanaman berulang: tetap di petak, berbuah lagi beberapa hari kemudian
					cell["age"] = Inv.crop_days(cell["crop"]) - rg
				else:
					cell["crop"] = ""
					cell["age"] = 0
				cell["watered"] = false
				Sfx.play("harvest", -2.0)
	for c in touched:
		_update_cell(c, true)


# ------------------------------------------------------------------ tampilan

func _rebuild() -> void:
	if _area == "":
		return
	for n in _visuals.values():
		(n as Node).queue_free()
	_visuals.clear()
	if not GameState.playing:
		return
	for c in _cells().keys():
		_update_cell(c, false)


func _update_cell(c: Vector2i, animate: bool) -> void:
	if _visuals.has(c):
		(_visuals[c] as Node).queue_free()
		_visuals.erase(c)
	var cell: Dictionary = _cells().get(c, {})
	if cell.is_empty():
		return
	var root := Node3D.new()
	var obs: String = cell.get("obs", "")
	if obs != "":
		root.add_child(ObstacleVisuals.obstacle(obs, c.x * 31 + c.y * 17))
		add_child(root)
		root.global_position = Vector3(c.x + 0.5, _ground_for(c), c.y + 0.5)
		_visuals[c] = root
		if animate:
			root.scale = Vector3(0.4, 0.4, 0.4)
			create_tween().tween_property(root, "scale", Vector3.ONE, 0.2)
		return
	if not cell["tilled"]:
		root.free()
		return
	root.add_child(CropVisuals.soil(cell["watered"]))
	if cell["crop"] != "":
		root.add_child(CropVisuals.plant(cell["crop"], CropVisuals.stage_of(int(cell["age"]), Inv.crop_days(cell["crop"]))))
	add_child(root)
	root.global_position = Vector3(c.x + 0.5, _ground_for(c), c.y + 0.5)
	_visuals[c] = root
	if animate:
		root.scale = Vector3(0.4, 0.4, 0.4)
		create_tween().tween_property(root, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Tinggi tanah untuk petak c (raycast dari atas; pakai tinggi petak yang sedang dituju kalau gagal).
func _ground_for(c: Vector2i) -> float:
	if c == _cell and _has_ground:
		return _ground_y
	var from := Vector3(c.x + 0.5, (_player.global_position.y if _player else 0.0) + 6.0, c.y + 0.5)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -14.0, 0))
	if _player:
		q.exclude = [_player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector3).y if not hit.is_empty() else (_player.global_position.y if _player else 0.0)


func _build_cursor() -> void:
	_cursor = Node3D.new()
	add_child(_cursor)
	var half := 0.47
	for e in [[Vector3(0, 0, -half), Vector3(0.98, 0.02, 0.06)], [Vector3(0, 0, half), Vector3(0.98, 0.02, 0.06)],
			[Vector3(-half, 0, 0), Vector3(0.06, 0.02, 0.98)], [Vector3(half, 0, 0), Vector3(0.06, 0.02, 0.98)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = e[1]
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = false
		m.albedo_color = Color(1, 1, 1, 0.45)
		mi.material_override = m
		mi.position = e[0]
		_cursor.add_child(mi)
		_cursor_mats.append(m)
	_cursor.visible = false
