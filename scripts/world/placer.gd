extends RefCounted
## Placer - penjaga penempatan dekorasi supaya benda tidak saling menembus dan tidak menutup jalan / titik NPC.
##   keep_rect(rect)       : area terlarang (jalan setapak, petak tanam, jalan desa)
##   keep_disc(x, z, r)    : titik terlarang (tempat NPC berdiri, pintu)
##   ok(x, z, r)           : true kalau lingkaran r di (x,z) tidak menyentuh area terlarang / benda lain
##   claim(x, z, r)        : catat benda yang sudah ditaruh (otomatis dipanggil oleh place())
## Benda yang gagal ditaruh dilewati dan dicatat ke `rejected` (dicetak sebagai peringatan saat debug).

const Props := preload("res://scripts/world/prop_builder.gd")

var rects: Array = []                  # Rect2
var discs: Array = []                  # Vector3(x, z, r)
var placed: Array = []                 # Vector3(x, z, r)
var rejected: Array = []


func keep_rect(r: Rect2) -> void:
	rects.append(r)


func keep_disc(x: float, z: float, r: float) -> void:
	discs.append(Vector3(x, z, r))


func ok(x: float, z: float, r: float) -> bool:
	for rc in rects:
		if (rc as Rect2).grow(r).has_point(Vector2(x, z)):
			return false
	for d in discs:
		if Vector2(x, z).distance_to(Vector2(d.x, d.y)) < r + d.z:
			return false
	for p in placed:
		if Vector2(x, z).distance_to(Vector2(p.x, p.y)) < r + p.z:
			return false
	return true


## Seluruh kotak r aman (tidak memotong area terlarang / benda lain)?
func rect_ok(r: Rect2) -> bool:
	for rc in rects:
		if (rc as Rect2).intersects(r):
			return false
	for d in discs:
		var c := Vector2(clampf(d.x, r.position.x, r.end.x), clampf(d.y, r.position.y, r.end.y))
		if c.distance_to(Vector2(d.x, d.y)) < d.z:
			return false
	for p in placed:
		var c2 := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		if c2.distance_to(Vector2(p.x, p.y)) < p.z:
			return false
	return true


func claim(x: float, z: float, r: float) -> void:
	placed.append(Vector3(x, z, r))


## Taruh node kalau aman. Kembalikan true kalau berhasil.
func place(parent: Node, node: Node3D, x: float, z: float, y: float, r: float, yaw := 0.0, label := "") -> bool:
	if not ok(x, z, r):
		rejected.append("%s (%.1f, %.1f)" % [label if label != "" else node.get_class(), x, z])
		node.queue_free()
		return false
	node.position = Vector3(x, y, z)
	node.rotation.y = yaw
	parent.add_child.call_deferred(node)
	claim(x, z, r)
	return true


## Pagar dari a ke b: aman kalau titik-titik sepanjang garisnya aman.
func place_fence(parent: Node, a: Vector3, b: Vector3, label := "fence") -> bool:
	var d := Vector2(b.x - a.x, b.z - a.z)
	var n := maxi(int(d.length() / 0.8), 1)
	for i in n + 1:
		var p := Vector2(a.x, a.z) + d * (float(i) / float(n))
		if not ok(p.x, p.y, 0.25):
			rejected.append("%s (%.1f, %.1f)" % [label, a.x, a.z])
			return false
	var f: Node3D = Props.fence(Vector3.ZERO, b - a)
	f.position = a
	parent.add_child.call_deferred(f)
	for i in n + 1:
		var p := Vector2(a.x, a.z) + d * (float(i) / float(n))
		claim(p.x, p.y, 0.25)
	return true
