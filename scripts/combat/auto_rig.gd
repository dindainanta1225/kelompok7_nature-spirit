extends RefCounted
## AutoRig - memasang Skeleton3D + skin (bobot tulang otomatis) pada model GLB statis yang tidak punya tulang.
## Mesh asli "dipanggang" (vertex digabung dengan transform node + putaran yaw), lalu tiap vertex diberi bobot
## ke maksimal 4 tulang terdekat (jarak ke ruas tulang, makin dekat makin besar), sehingga kaki/tangan/kepala/ekor
## bisa digerakkan lewat kode (lihat rig_anim.gd) dan kulitnya ikut melengkung mulus di sendi.
## Posisi tulang dibaca dari rig_specs.gd (koordinat model: +Z = depan, +Y = atas, X = kiri/kanan).

const SMALL_W := 0.04


## inst: hasil instantiate() GLB. spec: {"bones": [...], "rigid": {...}} ATAU Callable(tinggi_model, ukuran_vector3) -> spec (kalau tulang
## bergantung pada ukuran model). yaw_deg: putaran supaya model menghadap +Z. recenter: geser model supaya kaki di y=0
## dan titik tengah di x=z=0 (perlu untuk model yang posisinya jauh dari titik asal).
## Hasil: {"root": Node3D, "skeleton": Skeleton3D, "bones": {nama: index}, "height": float, "spec": Dictionary} atau {} kalau gagal.
static func build(inst: Node3D, spec_in: Variant, yaw_deg: float, recenter := false) -> Dictionary:
	var srcs: Array = []
	_gather(inst, Transform3D.IDENTITY, srcs)
	if srcs.is_empty():
		return {}
	var yaw := Basis(Vector3.UP, deg_to_rad(yaw_deg))
	# --- lintasan 1: "panggang" semua vertex ke ruang model (xf + yaw) dan cari kotak batas
	var baked: Array = []                                  # per mesh: [ [verts, norms, arrays] per surface ]
	var all_box := AABB()
	var first := true
	for src in srcs:
		var mi: MeshInstance3D = src["mi"]
		var xf: Transform3D = src["xf"]
		var nb := xf.basis.inverse().transposed()
		var surfs: Array = []
		for s in mi.mesh.get_surface_count():
			var a: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var norms = a[Mesh.ARRAY_NORMAL]
			var nv := PackedVector3Array()
			nv.resize(verts.size())
			var nn := PackedVector3Array()
			nn.resize(verts.size())
			for v in verts.size():
				var p: Vector3 = yaw * (xf * verts[v])
				nv[v] = p
				if norms != null and norms.size() == verts.size():
					nn[v] = (yaw * (nb * (norms[v] as Vector3))).normalized()
				if first:
					all_box = AABB(p, Vector3.ZERO)
					first = false
				else:
					all_box = all_box.expand(p)
			surfs.append({"v": nv, "n": nn, "a": a, "s": s})
		baked.append(surfs)
	var offset := Vector3.ZERO
	if recenter:
		offset = Vector3(-all_box.get_center().x, -all_box.position.y, -all_box.get_center().z)
		all_box.position += offset
	var height := all_box.size.y
	var spec: Dictionary = spec_in.call(height, all_box.size) if spec_in is Callable else spec_in
	var bones: Array = spec["bones"]
	var rigid: Dictionary = spec.get("rigid", {})
	var skel := Skeleton3D.new()
	skel.name = "Skeleton"
	var idx := {}
	for b in bones:                                        # induk harus sudah ada sebelum anak
		var i := skel.add_bone(b["name"])
		idx[b["name"]] = i
		var head: Vector3 = b["head"]
		if b.get("parent", "") != "":
			var pi: int = idx[b["parent"]]
			skel.set_bone_parent(i, pi)
			var phead: Vector3 = bones[pi]["head"]
			skel.set_bone_rest(i, Transform3D(Basis(), head - phead))
		else:
			skel.set_bone_rest(i, Transform3D(Basis(), head))
	skel.reset_bone_poses()
	var skin := Skin.new()
	skin.set_bind_count(bones.size())
	for i in bones.size():
		skin.set_bind_bone(i, i)
		skin.set_bind_pose(i, Transform3D(Basis(), -(bones[i]["head"] as Vector3)))
	var eps := 0.02 * maxf(height, 0.1)
	# --- lintasan 2: bobot tulang + bangun ArrayMesh bertulang
	for mi_i in srcs.size():
		var mi: MeshInstance3D = srcs[mi_i]["mi"]
		var rigid_bone := ""
		for key in rigid:
			if str(mi.name).to_lower().contains(key):
				rigid_bone = rigid[key]
		var am := ArrayMesh.new()
		for sd in baked[mi_i]:
			var nv: PackedVector3Array = sd["v"]
			var nn: PackedVector3Array = sd["n"]
			var a: Array = sd["a"]
			var n := nv.size()
			var bi := PackedInt32Array()
			bi.resize(n * 4)
			var bw := PackedFloat32Array()
			bw.resize(n * 4)
			for v in n:
				nv[v] += offset
				var wts: Array = _weights(nv[v], bones, eps, idx, rigid_bone)
				for k in 4:
					bi[v * 4 + k] = wts[0][k]
					bw[v * 4 + k] = wts[1][k]
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = nv
			if a[Mesh.ARRAY_NORMAL] != null:
				arrays[Mesh.ARRAY_NORMAL] = nn
			arrays[Mesh.ARRAY_TEX_UV] = a[Mesh.ARRAY_TEX_UV]
			if a[Mesh.ARRAY_COLOR] != null:
				arrays[Mesh.ARRAY_COLOR] = a[Mesh.ARRAY_COLOR]
			arrays[Mesh.ARRAY_INDEX] = a[Mesh.ARRAY_INDEX]
			arrays[Mesh.ARRAY_BONES] = bi
			arrays[Mesh.ARRAY_WEIGHTS] = bw
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			am.surface_set_material(am.get_surface_count() - 1, mi.get_active_material(sd["s"]))
		var out := MeshInstance3D.new()
		out.name = mi.name
		out.mesh = am
		skel.add_child(out)
		out.skeleton = NodePath("..")
		out.skin = skin
	var root := Node3D.new()
	root.name = "Rigged"
	root.add_child(skel)
	for c in skel.get_children():                          # kotak batas besar supaya tidak terpotong saat tulang bergerak
		(c as MeshInstance3D).custom_aabb = all_box.grow(0.8)
	return {"root": root, "skeleton": skel, "bones": idx, "height": height, "spec": spec}


static func _gather(n: Node3D, xf: Transform3D, out: Array) -> void:
	for c in n.get_children():
		if not c is Node3D:
			continue
		var nm := String(c.name)
		if nm.begins_with("Camera") or nm.begins_with("Light") or nm.begins_with("Expressions"):
			continue                                           # kamera/lampu/wajah cadangan bawaan file GLB
		var cx: Transform3D = xf * (c as Node3D).transform
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			out.append({"mi": c, "xf": cx})
		_gather(c as Node3D, cx, out)


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 1e-9:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Bobot 4 tulang terdekat (bobot = 1/jarak^3, dinormalkan).
static func _weights(p: Vector3, bones: Array, eps: float, idx: Dictionary, rigid_bone: String) -> Array:
	var ids := [0, 0, 0, 0]
	var ws := [0.0, 0.0, 0.0, 0.0]
	if rigid_bone != "":
		ids[0] = idx[rigid_bone]
		ws[0] = 1.0
		return [ids, ws]
	var cand: Array = []
	for i in bones.size():
		var b: Dictionary = bones[i]
		var d := maxf(_seg_dist(p, b["head"], b["tail"]) - float(b.get("r", 0.0)), 0.0)
		cand.append([1.0 / pow(d + eps, 3.0), i])
	cand.sort_custom(func(x, y): return x[0] > y[0])
	var total := 0.0
	var top: float = cand[0][0]
	for k in 4:
		if cand[k][0] < top * SMALL_W and k > 0:
			break
		ids[k] = cand[k][1]
		ws[k] = cand[k][0]
		total += cand[k][0]
	for k in 4:
		ws[k] = ws[k] / total
	return [ids, ws]
