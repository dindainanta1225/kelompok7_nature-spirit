extends RefCounted
## NativeRig - memakai skeleton BAWAAN file GLB (mis. Judy & Centorea) alih-alih membuat skeleton sendiri (AutoRig).
## Tulang yang dipakai dipetakan ke nama kanonik rig_anim.gd (hips, spine, head, up_R, low_R, th_R, sh_R, ...), jadi animasi
## prosedural yang sama (jalan, ayun alat, bicara) bisa dipakai. Tulang lain (jari, telinga, rok, ekor) ikut bergerak otomatis.
##
## map: Array [nama_kanonik, awalan_nama_tulang, awalan_tulang_ujung] — "{S}" diganti R / L. Tulang ujung dipakai untuk arah tulang.
## opts: front = [dari_tulang, ke_tulang] (arah hadap model), yaw (derajat tambahan), swap_sides (otomatis: R harus di sisi +X).
## Hasil: {"root","skeleton","bones","specs","native","height","arm_bias","hand"} atau {}.
## PENTING: inst ikut menjadi anak root (jangan di-free).


static func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := _find_skel(c)
		if r != null:
			return r
	return null


static func _bone(skel: Skeleton3D, prefix: String) -> int:
	var best := -1
	var bl := 9999
	for i in skel.get_bone_count():
		var nm := skel.get_bone_name(i)
		if nm.begins_with(prefix) and nm.length() < bl:
			best = i
			bl = nm.length()
	return best


static func build(inst: Node3D, map: Array, opts := {}) -> Dictionary:
	var skel := _find_skel(inst)
	if skel == null:
		return {}
	var xf := Transform3D.IDENTITY                              # skeleton -> ruang inst
	var n: Node = skel
	while n != null and n != inst:
		xf = (n as Node3D).transform * xf
		n = n.get_parent()
	var sb := xf.basis.orthonormalized()
	var yaw := deg_to_rad(float(opts.get("yaw", 0.0)))
	if opts.has("front"):
		var a := _bone(skel, opts["front"][0])
		var b := _bone(skel, opts["front"][1])
		if a >= 0 and b >= 0:
			var d: Vector3 = xf * skel.get_bone_global_rest(b).origin - xf * skel.get_bone_global_rest(a).origin
			yaw += -atan2(d.x, d.z)
	var yb := Basis(Vector3.UP, yaw)
	# ukuran & posisi kaki: dari AABB mesh (ruang inst) lalu diputar yaw
	# (AABB mesh skinned tidak bisa dipercaya: satuan/rotasi FBX berbeda dari skeleton) -> ukur dari posisi semua tulang
	var box := AABB(xf * skel.get_bone_global_rest(0).origin, Vector3.ZERO)
	for i in skel.get_bone_count():
		box = box.expand(xf * skel.get_bone_global_rest(i).origin)
	box = box.grow(box.size.y * 0.015)
	var pts: Array = []
	for i in 8:
		pts.append(yb * box.get_endpoint(i))
	var mn: Vector3 = pts[0]
	var mx: Vector3 = pts[0]
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	var offset := Vector3(-(mn.x + mx.x) * 0.5, -mn.y, -(mn.z + mx.z) * 0.5)
	var root := Node3D.new()
	root.add_child(inst)
	inst.transform = Transform3D(yb, offset)
	var to_root := Transform3D(yb, offset) * xf                  # skeleton -> ruang root
	var s_q := Quaternion(yb * sb)
	# kiri/kanan: tulang "R" harus berada di +X
	var swap := false
	for e in map:
		if String(e[0]).ends_with("_R") and String(e[1]).contains("{S}"):
			var bi := _bone(skel, String(e[1]).replace("{S}", "R"))
			if bi >= 0:
				swap = (to_root * skel.get_bone_global_rest(bi).origin).x < 0.0
			break
	var bones := {}
	var specs: Array = []
	var native := {}
	var made := {}
	for e in map:
		var name := String(e[0])
		var side := "R"
		if name.ends_with("_R") or name.ends_with("_L"):
			side = name.substr(name.length() - 1)
		var real_side := side
		if swap:
			real_side = "L" if side == "R" else "R"
		var bn := _bone(skel, String(e[1]).replace("{S}", real_side))
		if bn < 0:
			continue
		var tn := _bone(skel, String(e[2]).replace("{S}", real_side)) if String(e[2]) != "" else -1
		var head: Vector3 = to_root * skel.get_bone_global_rest(bn).origin
		var tail: Vector3
		if tn >= 0:
			tail = to_root * skel.get_bone_global_rest(tn).origin
		else:
			tail = head + Vector3(0, 0.1, 0)
		var par := skel.get_bone_parent(bn)
		var rp := Quaternion.IDENTITY
		if par >= 0:
			rp = Quaternion(skel.get_bone_global_rest(par).basis.orthonormalized())
		var r := Quaternion(skel.get_bone_global_rest(bn).basis.orthonormalized())
		bones[name] = bn
		specs.append({"name": name, "head": head, "tail": tail})
		native[name] = {"rp_inv": rp.inverse(), "r": r, "s": s_q, "s_inv": s_q.inverse()}
		made[name] = {"head": head, "tail": tail}
	if not bones.has("hips"):
		return {}
	# tangan yang melenceng dari "lurus ke bawah" -> bias supaya pose diam rapi
	var bias := 0.0
	if made.has("up_R"):
		var dv: Vector3 = ((made["up_R"]["tail"] as Vector3) - (made["up_R"]["head"] as Vector3)).normalized()
		var ang := rad_to_deg(acos(clampf(dv.dot(Vector3.DOWN), -1.0, 1.0)))
		if ang > 8.0:
			bias = ang
	return {"root": root, "skeleton": skel, "bones": bones, "specs": specs, "native": native,
		"height": mx.y - mn.y, "arm_bias": bias, "swap": swap, "s_q": s_q, "to_root": to_root}


static func _mesh_box(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var has := false
	var stack: Array = [[n, xf]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var node: Node = it[0]
		for c in node.get_children():
			if not c is Node3D:
				continue
			var cx: Transform3D = (it[1] as Transform3D) * (c as Node3D).transform
			var nm := String(c.name)
			if c is MeshInstance3D and (c as MeshInstance3D).mesh != null and not nm.begins_with("Expressions") and (c as MeshInstance3D).visible:
				var bx: AABB = cx * (c as MeshInstance3D).mesh.get_aabb()
				out = bx if not has else out.merge(bx)
				has = true
			stack.append([c, cx])
	return out
