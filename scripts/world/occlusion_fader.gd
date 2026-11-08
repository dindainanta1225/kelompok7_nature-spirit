extends Node
## OcclusionFader - rumah, pohon, dinding, dll. yang menghalangi pandangan kamera ke player jadi tembus pandang.
## Dipasang oleh Player. Tidak butuh tabrakan: tiap mesh tinggi dicek dengan garis kamera -> kepala player (AABB).

const MIN_TOP := 2.0                # hanya benda yang puncaknya lebih tinggi dari ini yang bisa memudar
const MAX_SPAN := 30.0              # mesh raksasa (tanah, bukit) tidak ikut
const PAD := 0.0                   # pelebaran kotak supaya tepi benda ikut memudar
const FADE_TO := 0.82               # seberapa tembus pandang (1 = hilang)
const FADE_SPEED := 7.0

var _items: Array = []              # {mi, box}
var _fade := {}                     # MeshInstance3D -> transparansi sekarang
var _hit := {}                      # MeshInstance3D -> true bila sedang menghalangi
var _t := 0.0
var _scan_in := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _skip(n: Node) -> bool:
	var a := n
	while a != null:
		if a is CharacterBody3D or a.is_in_group("npc") or a.is_in_group("player") or a.is_in_group("no_fade"):
			return true
		var sc: Script = a.get_script()
		if sc != null:
			var path := sc.resource_path
			if "monster" in path or "critter" in path or "npc_actor" in path:
				return true
		a = a.get_parent()
	return false


func _scan() -> void:
	_items.clear()
	var root := get_tree().current_scene
	if root == null:
		return
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if not (n is MeshInstance3D):
			continue
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		if box.end.y < MIN_TOP or maxf(box.size.x, box.size.z) > MAX_SPAN or box.size.y < 0.3:
			continue
		if _skip(mi):
			continue
		_items.append({"mi": mi, "box": box.grow(PAD)})


func _process(delta: float) -> void:
	_scan_in -= delta
	if _scan_in <= 0.0:
		_scan_in = 6.0
		_scan()
	var pl := get_parent() as Node3D
	var cam := get_viewport().get_camera_3d()
	if pl == null or cam == null:
		return
	_t -= delta
	if _t <= 0.0:
		_t = 0.07
		_hit.clear()
		var from := cam.global_position
		var to := pl.global_position + Vector3(0, 1.0, 0)
		for it in _items:
			var mo: Variant = it["mi"]
			if mo == null or not is_instance_valid(mo):
				continue
			var mi: MeshInstance3D = mo
			var box: AABB = it["box"]
			if box.size.x > 9.0 and box.has_point(to):           # bangunan besar yang melingkupi player (interior): jangan dihilangkan
				continue
			# tembus pandang hanya bila benar-benar menutupi player: kaki, badan, dan kepala semuanya terhalang
			var base := pl.global_position
			if _segment_hits(box, from, base + Vector3(0, 0.3, 0)) and _segment_hits(box, from, to) \
					and _segment_hits(box, from, base + Vector3(0, 1.8, 0)):
				_hit[mi] = true
				if not _fade.has(mi):
					_fade[mi] = 0.0
	var done := []
	for mi in _fade.keys():
		if mi == null or not is_instance_valid(mi):
			done.append(mi)
			continue
		var goal := FADE_TO if _hit.has(mi) else 0.0
		var v: float = lerpf(_fade[mi], goal, 1.0 - exp(-FADE_SPEED * delta))
		if absf(v - goal) < 0.01:
			v = goal
		_fade[mi] = v
		(mi as GeometryInstance3D).transparency = v
		if v == 0.0 and goal == 0.0:
			done.append(mi)
	for mi in done:
		_fade.erase(mi)


## Uji potong garis-kotak (slab method).
static func _segment_hits(box: AABB, a: Vector3, b: Vector3) -> bool:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	var mn := box.position
	var mx := box.end
	for i in 3:
		var o: float = a[i]
		var dir: float = d[i]
		if absf(dir) < 1.0e-6:
			if o < mn[i] or o > mx[i]:
				return false
		else:
			var ta: float = (mn[i] - o) / dir
			var tb: float = (mx[i] - o) / dir
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
			t0 = maxf(t0, ta)
			t1 = minf(t1, tb)
			if t0 > t1:
				return false
	return true
