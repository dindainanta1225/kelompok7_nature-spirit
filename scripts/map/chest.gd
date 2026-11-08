extends Interactable
## Chest - peti kayu di depan rumah. Tekan E untuk membuka (perlengkapan awal ada di sini).
## Dipasang oleh farm_setup.gd. Origin = dasar peti di tanah.


func _init() -> void:
	prompt = "Open chest"
	arm_delay = 0.0


func _ready() -> void:
	_build()
	super._ready()


const ModelUtil := preload("res://scripts/world/model_util.gd")
const AssetFinder := preload("res://scripts/world/asset_finder.gd")
const MODEL := "res://assets/Models/GLB format/chest.glb"        # cadangan kalau chest buatan sendiri tidak ditemukan
const WIDTH := 1.5                                            # lebar peti di dunia (m)


## Pakai model chest.glb (Models/GLB format); kalau tidak ada, peti buatan kode di bawah dipakai sebagai cadangan.
func _build() -> void:
	var path := AssetFinder.find_glb(["medieval", "chest"])        # medieval_fantasy_-_chest.glb
	if path == "":
		path = AssetFinder.find_glb(["chest"])
	if path == "":
		path = MODEL
	if ResourceLoader.exists(path):
		var ps := load(path) as PackedScene
		if ps != null:
			var inst := ps.instantiate() as Node3D
			add_child(inst)
			var b := ModelUtil.bounds(inst)
			var sc := WIDTH / maxf(b.size.x, b.size.z)
			inst.scale = Vector3.ONE * sc
			inst.position = Vector3(-b.get_center().x * sc, -b.position.y * sc, -b.get_center().z * sc)
			_collide(Vector3(b.size.x * sc, b.size.y * sc, b.size.z * sc))
			return
	_build_fallback()


func _collide(size: Vector3) -> void:
	var sb := StaticBody3D.new()
	var scs := CollisionShape3D.new()
	var sbox := BoxShape3D.new()
	sbox.size = size
	scs.shape = sbox
	sb.position = Vector3(0, size.y * 0.5, 0)
	sb.add_child(scs)
	add_child(sb)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x + 1.5, 2.0, size.z + 1.8)
	cs.shape = box
	cs.position = Vector3(0, 1.0, 0.4)
	add_child(cs)


func _build_fallback() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.50, 0.31, 0.15)
	wood.roughness = 0.9
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.30, 0.18, 0.09)
	dark.roughness = 0.9
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.78, 0.66, 0.30)
	metal.metallic = 0.5
	metal.roughness = 0.5
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.3, 0.7, 0.85)
	body.mesh = bm
	body.material_override = wood
	body.position = Vector3(0, 0.35, 0)
	add_child(body)
	var lid := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.42
	cm.bottom_radius = 0.42
	cm.height = 1.3
	cm.radial_segments = 14
	lid.mesh = cm
	lid.material_override = wood
	lid.rotation = Vector3(0, 0, PI * 0.5)
	lid.scale = Vector3(1.0, 1.0, 1.0)
	lid.position = Vector3(0, 0.72, 0)
	add_child(lid)
	for x in [-0.45, 0.45]:                                   # pita kayu gelap
		var band := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.12, 0.72, 0.9)
		band.mesh = bb
		band.material_override = dark
		band.position = Vector3(x, 0.36, 0)
		add_child(band)
	var lock := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.2, 0.22, 0.06)
	lock.mesh = lm
	lock.material_override = metal
	lock.position = Vector3(0, 0.62, 0.45)
	add_child(lock)
	# tabrakan (padat) + area interaksi lebih besar
	var sb := StaticBody3D.new()
	var scs := CollisionShape3D.new()
	var sbox := BoxShape3D.new()
	sbox.size = Vector3(1.3, 1.1, 0.85)
	scs.shape = sbox
	sb.position = Vector3(0, 0.55, 0)
	sb.add_child(scs)
	add_child(sb)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.8, 2.0, 2.6)
	cs.shape = box
	cs.position = Vector3(0, 1.0, 0.4)
	add_child(cs)


func _on_interact(_player: Node3D) -> void:
	HUD.open_chest()
