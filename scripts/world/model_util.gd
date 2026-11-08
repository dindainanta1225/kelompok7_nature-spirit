extends RefCounted
## ModelUtil - ukur kotak batas (AABB) model 3D yang sebenarnya (termasuk rotasi/skala bawaan hasil import FBX),
## supaya bangunan bisa diletakkan PAS di tanah (tidak melayang / tenggelam) dan tabrakannya sesuai ukuran asli.


## AABB gabungan semua MeshInstance3D di dalam node, dalam ruang lokal node itu (skala 1).
static func bounds(root: Node3D) -> AABB:
	var out := {"box": AABB(), "has": false}
	_walk(root, Transform3D.IDENTITY, out)
	return out["box"]


static func _walk(n: Node3D, xf: Transform3D, out: Dictionary) -> void:
	for c in n.get_children():
		if not c is Node3D:
			continue
		var cx: Transform3D = xf * (c as Node3D).transform
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			var box: AABB = cx * (c as MeshInstance3D).mesh.get_aabb()
			if out["has"]:
				out["box"] = (out["box"] as AABB).merge(box)
			else:
				out["box"] = box
				out["has"] = true
		_walk(c as Node3D, cx, out)


## Letakkan model: dasarnya di y = ground_y, titik tengah footprint di (cx, cz). Kembalikan AABB dunia hasilnya.
static func place(inst: Node3D, scale: float, cx: float, cz: float, ground_y: float) -> AABB:
	var b := bounds(inst)
	inst.scale = Vector3.ONE * scale
	var c := b.get_center()
	inst.position = Vector3(cx - c.x * scale, ground_y - b.position.y * scale, cz - c.z * scale)
	return AABB(Vector3(cx - b.size.x * scale * 0.5, ground_y, cz - b.size.z * scale * 0.5), b.size * scale)
