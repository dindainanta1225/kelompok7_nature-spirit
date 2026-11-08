extends Node3D
const Sfx := preload("res://scripts/audio/sfx.gd")
const AppSettings := preload("res://scripts/ui/app_settings.gd")
## FruitPickup - buah liar yang tersebar acak di farm, desa, dan hutan. Dekati -> muncul "[E] Pick up ...",
## tekan E untuk mengambil. Buahnya bisa dimakan (menambah energi sedikit). Muncul baru tiap hari.
## Dibuat otomatis oleh Player lewat FruitPickup.spawn_for_scene(player).

const KINDS := [
	{"id": "apple", "color": Color(0.88, 0.18, 0.16), "w": 4},
	{"id": "orange", "color": Color(1.0, 0.58, 0.12), "w": 3},
	{"id": "pear", "color": Color(0.74, 0.82, 0.25), "w": 3},
	{"id": "berry", "color": Color(0.50, 0.20, 0.62), "w": 2},
]
const GY := 1.5
const REACH := 1.5

static var taken := {}                  # kunci buah yang sudah diambil (per hari)

var item_id := "apple"
var color := Color(0.88, 0.18, 0.16)
var key := ""
var _t := 0.0
var _near := false
var _vis: Node3D
var _tag: Label3D


static func spawn_for_scene(player: Node3D) -> void:
	var scene := player.get_tree().current_scene
	if scene == null or player.get_world_3d() == null:
		return
	var path := scene.scene_file_path
	var rect := Rect2()
	var count := 0
	var area := ""
	var skip: Array = []
	if "farm" in path:
		area = "farm"
		rect = Rect2(-17.5, -17.0, 35.0, 33.0)
		count = 5
		skip = [Rect2(-1.0, -8.0, 7.0, 7.0), Rect2(6.0, -8.0, 7.0, 7.0)]      # petak tanam
	elif "village" in path:
		area = "village"
		rect = Rect2(-23.0, -21.0, 46.0, 42.0)
		count = 7
	elif "forest" in path:
		area = path.get_file().get_basename()
		rect = Rect2(-24.0, -15.0, 48.0, 30.0)
		count = 7
	else:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(area) + GameState.day * 7919 + int(GameState.run_stamp % 100000)
	var space := player.get_world_3d().direct_space_state
	# buah jatuh di dekat pangkal pohon (bukan di tengah jalan): kumpulkan posisi pohon dulu
	var trees: Array = []
	var st: Array = [scene]
	while not st.is_empty():
		var nd: Node = st.pop_back()
		for ch in nd.get_children():
			st.append(ch)
		if nd is Node3D and not (nd is CharacterBody3D) and "tree" in String(nd.name).to_lower():
			var tp := (nd as Node3D).global_position
			if rect.has_point(Vector2(tp.x, tp.z)):
				trees.append(Vector2(tp.x, tp.z))
	var placed := 0
	for i in count * 25:
		if placed >= count:
			break
		var x := rng.randf_range(rect.position.x, rect.end.x)
		var z := rng.randf_range(rect.position.y, rect.end.y)
		if not trees.is_empty():
			var tpos: Vector2 = trees[rng.randi() % trees.size()]
			var ang := rng.randf() * TAU
			var dist := rng.randf_range(1.0, 1.7)
			x = tpos.x + cos(ang) * dist
			z = tpos.y + sin(ang) * dist
		var bad := false
		for r in skip:
			if (r as Rect2).has_point(Vector2(x, z)):
				bad = true
		if bad:
			continue
		var ray := PhysicsRayQueryParameters3D.create(Vector3(x, GY + 8.0, z), Vector3(x, GY - 3.0, z))
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or hit["position"].y < GY - 0.5 or hit["position"].y > GY + 0.5:
			continue
		var sq := PhysicsShapeQueryParameters3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 0.55
		sq.shape = sp
		sq.transform = Transform3D(Basis.IDENTITY, Vector3(x, hit["position"].y + 0.9, z))
		if not space.intersect_shape(sq, 1).is_empty():
			continue
		var pick := rng.randf() * 12.0
		var kind: Dictionary = KINDS[0]
		for k in KINDS:
			pick -= float(k["w"])
			if pick <= 0.0:
				kind = k
				break
		var f = load("res://scripts/world/fruit_pickup.gd").new()
		f.item_id = kind["id"]
		f.color = kind["color"]
		f.key = "%d_%s_%d_%d" % [GameState.run_stamp, area, GameState.day, placed]
		f.position = Vector3(x, hit["position"].y, z)
		if taken.has(f.key):
			f.free()
		else:
			scene.add_child(f)
		placed += 1


func _ready() -> void:
	add_to_group("no_fade")
	_vis = Node3D.new()
	add_child(_vis)
	_build_fruit_mesh()
	_tag = Label3D.new()
	_tag.text = _item_name()
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.no_depth_test = true
	_tag.fixed_size = false
	_tag.pixel_size = 0.0045
	_tag.font_size = 64
	_tag.outline_size = 14
	_tag.modulate = Color(1, 1, 1)
	_tag.outline_modulate = Color(0.18, 0.09, 0.04)
	_tag.position = Vector3(0, 0.85, 0)
	_tag.visible = false
	add_child(_tag)
	_t = randf() * TAU


func _mat(c: Color, rough := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _part(mesh: Mesh, c: Color, pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	mi.scale = scl
	mi.rotation = rot
	_vis.add_child(mi)


func _sphere(r: float) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 14
	sm.rings = 8
	return sm


## Bentuk tiap buah berbeda: apel (bulat + batang + daun), jeruk (bulat + bintik), pir (dua bola), beri (gerombol kecil).
func _build_fruit_mesh() -> void:
	var leafc := Color(0.25, 0.6, 0.2)
	var stemc := Color(0.35, 0.22, 0.10)
	var leaf := BoxMesh.new()
	leaf.size = Vector3(0.14, 0.02, 0.07)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.012
	stem.bottom_radius = 0.014
	stem.height = 0.1
	match item_id:
		"orange":
			_part(_sphere(0.19), color, Vector3(0, 0.2, 0), Vector3(1, 0.93, 1))
			_part(_sphere(0.03), Color(0.35, 0.55, 0.15), Vector3(0, 0.38, 0), Vector3(1.4, 0.5, 1.4))
			_part(leaf, leafc, Vector3(0.07, 0.4, 0), Vector3.ONE, Vector3(0, 0.4, 0.3))
		"pear":
			_part(_sphere(0.19), color, Vector3(0, 0.17, 0), Vector3(1, 0.95, 1))
			_part(_sphere(0.12), color, Vector3(0, 0.4, 0), Vector3(1, 1.15, 1))
			_part(stem, stemc, Vector3(0.01, 0.56, 0), Vector3.ONE, Vector3(0, 0, 0.3))
			_part(leaf, leafc, Vector3(0.08, 0.56, 0), Vector3.ONE, Vector3(0, 0.5, 0.4))
		"berry":
			for o in [Vector3(-0.07, 0.14, 0.02), Vector3(0.08, 0.14, -0.02), Vector3(0.0, 0.14, 0.09), Vector3(0.0, 0.26, 0.0), Vector3(-0.06, 0.24, -0.06)]:
				_part(_sphere(0.075), color, o)
			_part(leaf, leafc, Vector3(0.05, 0.36, 0.0), Vector3.ONE, Vector3(0, 0.4, 0.2))
		_:                                                      # apple
			_part(_sphere(0.15), color, Vector3(-0.07, 0.2, 0))
			_part(_sphere(0.15), color, Vector3(0.07, 0.2, 0))
			_part(_sphere(0.14), color, Vector3(0, 0.2, 0.0), Vector3(1.0, 0.95, 1.0))
			_part(stem, stemc, Vector3(0, 0.40, 0), Vector3.ONE, Vector3(0, 0, 0.25))
			_part(leaf, leafc, Vector3(0.08, 0.43, 0), Vector3.ONE, Vector3(0, 0.4, 0.4))


func _item_name() -> String:
	var inv = GameState.inventory
	if inv != null and inv.items.has(item_id):
		return String(inv.items[item_id]["name"])
	return item_id.capitalize()


func _process(delta: float) -> void:
	_t += delta
	_vis.position.y = 0.06 + sin(_t * 2.4) * 0.05
	_vis.rotation.y += delta * 1.1
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	var near := false
	if pl != null and GameState.playing and not GameState.input_locked and not GameState.chatting and not get_tree().paused:
		near = Vector2(pl.global_position.x - global_position.x, pl.global_position.z - global_position.z).length() < REACH
	if near != _near:
		_near = near
		_tag.visible = near                                   # nama buah hanya muncul saat bisa diambil
		if near:
			HUD.set_prompt(self, "[%s] Pick up" % AppSettings.key_name("interact"))
		else:
			HUD.clear_prompt(self)


func _unhandled_input(event: InputEvent) -> void:
	if _near and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_pick()


func _pick() -> void:
	var inv = GameState.inventory
	if inv.add(item_id, 1) > 0:
		GameState.toast.emit("Your bag is full!")
		return
	taken[key] = true
	Sfx.play("pickup", -4.0)
	GameState.toast.emit("Picked up %s" % _item_name())
	HUD.clear_prompt(self)
	queue_free()


func _exit_tree() -> void:
	if _near:
		HUD.clear_prompt(self)
