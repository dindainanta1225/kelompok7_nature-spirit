extends RefCounted
## HitFx - efek visual pedang: lengkung tebasan putih saat mengayun + percikan putih saat mengenai monster.
## Semua dibuat dari mesh/partikel sederhana (tanpa aset). Dipanggil oleh CombatController.

static var _arc_mesh: ArrayMesh


## Lengkung tebasan putih di depan player. facing = arah hadap (XZ).
static func slash(parent: Node, origin: Vector3, facing: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var root := Node3D.new()
	root.top_level = true
	parent.add_child(root)
	root.global_position = origin + Vector3(0, 0.95, 0)
	root.rotation.y = atan2(facing.x, facing.z)
	var mi := MeshInstance3D.new()
	mi.mesh = _arc()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1, 1, 1, 0.95)
	mat.no_depth_test = false
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	mi.rotation.y = deg_to_rad(65.0)                       # mulai dari kanan, menyapu ke kiri
	mi.scale = Vector3(0.85, 1.0, 0.85)
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(mi, "rotation:y", deg_to_rad(-65.0), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3(1.15, 1.0, 1.15), 0.2)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.22).set_delay(0.08)
	tw.chain().tween_callback(root.queue_free)


## Percikan putih di titik kena (posisi dunia).
static func spark(parent: Node, pos: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var root := Node3D.new()
	root.top_level = true
	parent.add_child(root)
	root.global_position = pos
	# kilatan bulat
	var flash := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	sm.radial_segments = 12
	sm.rings = 6
	flash.mesh = sm
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(1, 1, 1, 0.9)
	flash.material_override = fm
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(flash)
	# serpihan
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = 12
	p.lifetime = 0.35
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -4.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.09)
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pm.albedo_color = Color(1, 1, 1)
	qm.material = pm
	p.mesh = qm
	root.add_child(p)
	p.emitting = true
	var tw := root.create_tween().set_parallel(true)
	tw.tween_property(flash, "scale", Vector3(1.8, 1.8, 1.8), 0.14)
	tw.tween_property(fm, "albedo_color:a", 0.0, 0.16)
	tw.chain().tween_interval(0.3)
	tw.chain().tween_callback(root.queue_free)


## Mesh lengkung sabit (di bidang XZ, menghadap +Z): tebal di tengah, runcing di ujung.
static func _arc() -> ArrayMesh:
	if _arc_mesh != null:
		return _arc_mesh
	var steps := 18
	var r_out := 1.75
	var r_in_base := 1.15
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for i in steps + 1:
		var t := float(i) / steps
		var a := deg_to_rad(lerpf(-75.0, 75.0, t))
		var thick := sin(t * PI)                              # 0 di ujung, 1 di tengah
		var r_in := lerpf(r_out, r_in_base, thick)
		verts.append(Vector3(sin(a) * r_out, 0.0, cos(a) * r_out))
		verts.append(Vector3(sin(a) * r_in, 0.0, cos(a) * r_in))
	for i in steps:
		var b := i * 2
		idx.append_array([b, b + 1, b + 2, b + 1, b + 3, b + 2])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_arc_mesh = m
	return m
