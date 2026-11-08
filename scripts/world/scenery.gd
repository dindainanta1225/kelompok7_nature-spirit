extends RefCounted
## Scenery - mengisi area dengan aset 3D yang sudah ada di project (lumbung, silo, kincir, kandang ayam,
## menara air, pohon, batu, jamur, bunga, rumput). Semua penempatan lewat Placer, jadi tidak menimpa jalan,
## NPC, bangunan, atau dekorasi lain.
##
##   var sc := Scenery.new(placer, ground_y)
##   sc.building(parent, "Barn", cx, cz, 1.0)         # bangunan besar (FBX), ada tabrakan
##   sc.scatter(parent, Rect2(...), 80, seed)         # taburan bunga/jamur/batu/pohon kecil
## File FBX dicari di res://assets/Farm/, res://assets/Models/, lalu res://  (letak aslinya di root project).

const Placer := preload("res://scripts/world/placer.gd")
const ModelUtil := preload("res://scripts/world/model_util.gd")
const GLB_DIR := "res://assets/Models/GLB format/"
const FBX_DIRS := ["res://assets/Farm/", "res://assets/Models/", "res://"]

## nama pendek -> [nama file fbx, lebar x, kedalaman z] (ukuran asli, skala 1)
const BUILDINGS := {
	"Barn": ["Barn - Salin", 7.73, 8.22],
	"BigBarn": ["BigBarn", 7.73, 8.22],
	"OpenBarn": ["OpenBarn", 5.74, 6.18],
	"SmallBarn": ["SmallBarn - Salin", 6.08, 6.27],
	"Silo": ["Silo_House", 5.34, 3.51],
	"Windmill": ["TowerWindmill", 7.92, 4.99],
	"WaterTower": ["WaterTower", 2.53, 2.49],
	"Coop": ["ChickenCoop", 2.41, 2.15],
}

## [nama glb, bobot, solid?(lebar tabrakan, 0 = tembus)]
const NATURE := [
	["flowers", 5, 0.0], ["flowers-tall", 5, 0.0], ["grass", 6, 0.0], ["plant", 3, 0.0],
	["mushrooms", 2, 0.0], ["stones", 2, 0.0], ["rocks", 2, 0.55], ["tree-pine-small", 1, 0.35], ["tree", 1, 0.4],
]

const Realism := preload("res://scripts/world/realism.gd")

var placer
var gy := 1.5
var _cache := {}


func _init(p, ground_y: float) -> void:
	placer = p
	gy = ground_y


func _load(path: String) -> PackedScene:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


func _fbx(name: String) -> PackedScene:
	for d in FBX_DIRS:
		var p: String = d + name + ".fbx"
		if ResourceLoader.exists(p):
			return _load(p)
	return null


## Footprint (Rect2 x,z) sebuah bangunan bila diletakkan di (cx, cz) dengan skala tertentu.
static func footprint(key: String, cx: float, cz: float, scale := 1.0) -> Rect2:
	var b: Array = BUILDINGS[key]
	var w: float = b[1] * scale
	var d: float = b[2] * scale
	return Rect2(cx - w * 0.5, cz - d * 0.5, w, d)


## Taruh bangunan FBX (pintu menghadap +Z). Mengembalikan true kalau berhasil.
func building(parent: Node, key: String, cx: float, cz: float, scale := 1.0, yaw := 0.0) -> bool:
	var scn := _fbx(String((BUILDINGS[key] as Array)[0]))
	var fp := footprint(key, cx, cz, scale)
	if scn == null:
		return false
	if not placer.rect_ok(fp):
		placer.rejected.append("%s (%.1f, %.1f)" % [key, cx, cz])
		return false
	var inst: Node3D = scn.instantiate()
	var box := ModelUtil.place(inst, scale, cx, cz, gy)
	parent.add_child.call_deferred(inst)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(box.size.x * 0.92, box.size.y, box.size.z * 0.92)
	cs.shape = sh
	body.position = Vector3(cx, gy + box.size.y * 0.5, cz)
	body.add_child(cs)
	parent.add_child.call_deferred(body)
	placer.keep_rect(fp.grow(0.3))
	return true


## Satu model GLB kecil di (x, z). solid > 0 -> tabrakan kotak selebar itu.
func nature(parent: Node, name: String, x: float, z: float, scale: float, yaw: float, solid := 0.0) -> bool:
	var scn := _load(GLB_DIR + name + ".glb")
	if scn == null:
		return false
	var r := maxf(0.3, 0.45 * scale)
	if not placer.ok(x, z, r):
		return false
	var inst: Node3D = scn.instantiate()
	inst.position = Vector3(x, gy, z)
	inst.rotation.y = yaw
	inst.scale = Vector3.ONE * scale
	Realism.restyle_tree(inst)
	parent.add_child.call_deferred(inst)
	if solid > 0.0:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(solid * scale, 1.2, solid * scale)
		cs.shape = sh
		body.position = Vector3(x, gy + 0.6, z)
		body.add_child(cs)
		parent.add_child.call_deferred(body)
	placer.claim(x, z, r if solid > 0.0 else r * 0.6)
	return true


## Taburkan benda alam di dalam rect (sampai `count` percobaan), acak tapi tetap (seed).
func scatter(parent: Node, rect: Rect2, count: int, seed_v: int, scale := 1.8) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var total := 0.0
	for n in NATURE:
		total += float(n[1])
	var placed := 0
	for i in count * 3:
		if placed >= count:
			break
		var pick := rng.randf() * total
		var item: Array = NATURE[0]
		for n in NATURE:
			pick -= float(n[1])
			if pick <= 0.0:
				item = n
				break
		var x := rng.randf_range(rect.position.x, rect.end.x)
		var z := rng.randf_range(rect.position.y, rect.end.y)
		var s := scale * rng.randf_range(0.85, 1.25)
		if nature(parent, String(item[0]), x, z, s, rng.randf() * TAU, float(item[2])):
			placed += 1
	return placed
