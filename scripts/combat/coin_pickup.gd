extends Area3D
const Sfx := preload("res://scripts/audio/sfx.gd")
## CoinPickup - TUMPUKAN koin emas di hutan (model "3d_gold_coin_-_jb.glb": satu file berisi 4 bentuk tumpukan,
## dipecah otomatis lewat kode). Tumpukan makin besar = jumlah koin makin banyak (acak):
##   0 satu koin 30-90 | 1 tumpukan kecil 100-250 | 2 tumpukan tersebar 250-500 | 3 tumpukan besar 500-1200
## Hanya 1-2 tumpukan per hutan per hari. Disentuh pemain -> koin masuk. Sudah diambil -> tidak muncul lagi hari itu.

const ForestState := preload("res://scripts/combat/forest_state.gd")
const AssetFinder := preload("res://scripts/world/asset_finder.gd")
const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"
const FALLBACK := "res://assets/Models/GLB format/coin-gold.glb"
const RANGES := [Vector2i(30, 90), Vector2i(100, 250), Vector2i(250, 500), Vector2i(500, 1200)]
const WIDTHS := [0.45, 0.8, 1.05, 1.3]                      # lebar tumpukan di dunia (m)
const SPLIT_GAP := 0.12                                      # celah antar tumpukan di model (satuan model)

static var _clusters: Array = []                             # [{mesh, size}] urut dari yang terkecil
static var _built := false

var rank := 0
var amount := 100
var forest_id := 1
var coin_index := 0
var ground_y := 1.5
var _model: Node3D
var _t := 0.0
var _taken := false


## Pilih jenis tumpukan (yang kecil lebih sering) dan jumlah koinnya.
static func roll(rng: RandomNumberGenerator) -> Array:
	var r := rng.randf()
	var k := 0 if r < 0.3 else (1 if r < 0.62 else (2 if r < 0.88 else 3))
	var span: Vector2i = RANGES[k]
	return [k, int(round(rng.randi_range(span.x, span.y) / 10.0)) * 10]


func _ready() -> void:
	add_to_group("coin_pickup")
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.0
	cs.shape = sh
	cs.position.y = 0.5
	add_child(cs)
	_build_model()
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.82, 0.4)
	glow.light_energy = 0.7
	glow.omni_range = 3.0
	glow.position.y = 0.8
	add_child(glow)
	_t = randf() * TAU
	body_entered.connect(_on_body)


func _build_model() -> void:
	_ensure_clusters()
	var holder := Node3D.new()
	add_child(holder)
	_model = holder
	if not _clusters.is_empty():
		var c: Dictionary = _clusters[clampi(rank, 0, _clusters.size() - 1)]
		var mi := MeshInstance3D.new()
		mi.mesh = c["mesh"]
		var size: Vector3 = c["size"]
		var s: float = float(WIDTHS[clampi(rank, 0, 3)]) / maxf(maxf(size.x, size.z), 0.01)
		mi.scale = Vector3.ONE * s
		holder.add_child(mi)
		return
	var mi2 := MeshInstance3D.new()                                         # cadangan: koin tunggal
	var cm := CylinderMesh.new()
	cm.top_radius = 0.25
	cm.bottom_radius = 0.25
	cm.height = 0.06
	mi2.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.8, 0.2)
	m.metallic = 0.9
	m.roughness = 0.3
	mi2.material_override = m
	mi2.position.y = 0.03
	holder.add_child(mi2)


## Pecah model koin jadi beberapa tumpukan berdasarkan celah kosong di sumbu X (sekali saja, di-cache).
static func _ensure_clusters() -> void:
	if _built:
		return
	_built = true
	var path := AssetFinder.find_glb(["gold_coin"])
	if path == "":
		return
	var ps := load(path) as PackedScene
	if ps == null:
		return
	var root := ps.instantiate() as Node3D
	var parts: Array = []
	_gather(root, Transform3D.IDENTITY, parts)
	for part in parts:
		var mi: MeshInstance3D = part["mi"]
		var xf: Transform3D = part["xf"]
		for s in mi.mesh.get_surface_count():
			var a: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var norms = a[Mesh.ARRAY_NORMAL]
			var uvs = a[Mesh.ARRAY_TEX_UV]
			var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			var wv := PackedVector3Array()
			wv.resize(verts.size())
			for i in verts.size():
				wv[i] = xf * verts[i]
			var order := range(wv.size())
			order.sort_custom(func(p, q): return wv[p].x < wv[q].x)
			var cut: Array = []                                              # batas x antar tumpukan
			for k in range(1, order.size()):
				if wv[order[k]].x - wv[order[k - 1]].x > SPLIT_GAP:
					cut.append((wv[order[k]].x + wv[order[k - 1]].x) * 0.5)
			var bins := cut.size() + 1
			for b in bins:
				var lo: float = -1e9 if b == 0 else cut[b - 1]
				var hi: float = 1e9 if b == bins - 1 else cut[b]
				var remap := {}
				var nv := PackedVector3Array()
				var nn := PackedVector3Array()
				var nu := PackedVector2Array()
				var ni := PackedInt32Array()
				var t := 0
				while t < idx.size():
					var tri := [idx[t], idx[t + 1], idx[t + 2]]
					t += 3
					var cx := (wv[tri[0]].x + wv[tri[1]].x + wv[tri[2]].x) / 3.0
					if cx < lo or cx >= hi:
						continue
					for vi in tri:
						if not remap.has(vi):
							remap[vi] = nv.size()
							nv.append(wv[vi])
							if norms != null:
								nn.append((xf.basis * (norms[vi] as Vector3)).normalized())
							if uvs != null:
								nu.append(uvs[vi])
						ni.append(remap[vi])
				if nv.size() < 3:
					continue
				var box := AABB(nv[0], Vector3.ZERO)
				for v in nv:
					box = box.expand(v)
				var c := box.get_center()
				for i in nv.size():                                          # pusat tumpukan di (0,0,0), dasar di y=0
					nv[i] = Vector3(nv[i].x - c.x, nv[i].y - box.position.y, nv[i].z - c.z)
				var arrays := []
				arrays.resize(Mesh.ARRAY_MAX)
				arrays[Mesh.ARRAY_VERTEX] = nv
				if norms != null:
					arrays[Mesh.ARRAY_NORMAL] = nn
				if uvs != null:
					arrays[Mesh.ARRAY_TEX_UV] = nu
				arrays[Mesh.ARRAY_INDEX] = ni
				var am := ArrayMesh.new()
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				am.surface_set_material(0, mi.get_active_material(s))
				_clusters.append({"mesh": am, "size": box.size, "vol": nv.size()})
	root.free()
	_clusters.sort_custom(func(p, q): return (p["size"].x * p["size"].z * p["size"].y) < (q["size"].x * q["size"].z * q["size"].y))


static func _gather(n: Node3D, xf: Transform3D, out: Array) -> void:
	for c in n.get_children():
		if not c is Node3D:
			continue
		var cx: Transform3D = xf * (c as Node3D).transform
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			out.append({"mi": c, "xf": cx})
		_gather(c as Node3D, cx, out)


func _process(delta: float) -> void:
	_t += delta
	if _model != null and not _taken:
		_model.rotation.y += delta * 0.7                                     # berputar pelan supaya berkilau


func _on_body(body: Node3D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	Sfx.play("pickup", -2.0)
	ForestState.mark_coin(forest_id, GameState.day, coin_index)
	GameState.add_coins(amount)
	GameState.toast.emit("Found %d coins!" % amount)
	_float_text("+%d" % amount)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_model, "scale", Vector3.ONE * 0.05, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(_model, "position:y", 0.8, 0.3)
	tw.chain().tween_callback(queue_free)


func _float_text(text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.pixel_size = 0.0055
	l.modulate = Color(1.0, 0.86, 0.3)
	l.outline_size = 14
	l.outline_modulate = Color(0.12, 0.06, 0.03)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	if ResourceLoader.exists(FONT_PATH):
		l.font = load(FONT_PATH)
	l.top_level = true
	get_parent().add_child(l)
	l.global_position = global_position + Vector3(0, 1.3, 0)
	var tw := l.create_tween()
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.0, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.tween_callback(l.queue_free)
