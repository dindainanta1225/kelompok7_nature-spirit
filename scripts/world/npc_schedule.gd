extends RefCounted
## NpcSchedule - jadwal harian warga + jalur jalan kaki di desa. Hasilnya deterministik (hari & jam sama -> hasil sama).
##   - Pemilik toko (ALWAYS) selalu ada di desa: lebih sering di tokonya, kadang ke alun-alun / jalan toko.
##   - Warga lain: ~70% hari muncul. Tiap blok 3 jam mereka pindah: di desa (berjalan antar titik) atau ke HUTAN 1.
##     (Farm player hanya didatangi Centorea, yang memang tinggal di sana.)
##   - Pagi (06-09) mereka di titik "rumah"; MALAM (>= 19:00) semua warga berjalan pulang ke rumah masing-masing lalu masuk.
##   - Ranger Finn lebih sering berada di hutan.

const QuestData := preload("res://scripts/managers/quest_data.gd")
const ALWAYS := ["martha", "gordon", "lily", "finn"]
const NIGHT_START := 19                       # jam mulai malam (warga pulang)
const PRESENT_CHANCE := 70

const FARM_EXIT := Vector3(0, 0, 25.8)       # gerbang ke Farm (tempat warga muncul/menghilang)
const FOREST_EXIT := Vector3(22.5, 0, 4.5)   # jalan ke Hutan 1


static func block_of(hour: int) -> int:
	return clampi((hour - 6) / 3, 0, 5)


static func slot_of(hour: int) -> int:
	return block_of(hour)


static func is_night(hour: int) -> bool:
	return hour >= NIGHT_START or hour < 6


static func _h(a: String, day: int, extra: int) -> int:
	var x := absi(hash("%s_%d_%d" % [a, day, extra])) & 0xFFFFFFFF      # hash String berurutan -> acak dulu (mixing bit)
	x = ((x ^ (x >> 16)) * 0x45d9f3b) & 0xFFFFFFFF
	x = ((x ^ (x >> 16)) * 0x45d9f3b) & 0xFFFFFFFF
	return x ^ (x >> 16)


static func is_present(id: String, day: int) -> bool:
	if ALWAYS.has(id):
		return true
	return _h(id, day, 7) % 100 < PRESENT_CHANCE


static func spot_index(id: String, day: int, hour: int, n: int) -> int:
	return _h(id, day, block_of(hour) + 31) % maxi(n, 1)


## Di mana warga ini sekarang? -> {"where": "village" | "forest" | "home" | "away", "spot": index tempat desa}
## "home" = malam / sudah pulang (di dalam rumah); "away" = tidak muncul hari ini (juga di dalam rumah).
static func where(id: String, day: int, hour: int, n_spots: int) -> Dictionary:
	var quest := not QuestData.active_for(id, day, GameState.quests_done).is_empty()
	var b := block_of(hour)
	var h := _h(id, day, b + 31)
	var r := h % 100
	var pick := (h >> 8) % maxi(n_spots, 1)
	if is_night(hour):
		return {"where": "home", "spot": 0}
	if not quest and not is_present(id, day):
		return {"where": "away", "spot": 0}
	if quest or b == 0:
		return {"where": "village", "spot": 0}
	if id == "finn":
		return {"where": "village" if r < 35 else "forest", "spot": pick}
	if ALWAYS.has(id):
		return {"where": "village", "spot": 0 if r < 60 else 1 + pick % maxi(n_spots - 1, 1)}
	return {"where": "village" if r < 72 else "forest", "spot": pick}


# ------------------------------------------------------------------ jalur jalan (A* di grid, menghindari bangunan & benda besar)
const CELL := 0.5
const GRID_MIN := Vector2(-27.0, -21.0)
const GRID_W := 108
const GRID_H := 100
static var _blocked_cells := PackedByteArray()
static var _road_cells := PackedByteArray()
static var _ready_grid := false


## Dipanggil village.gd setelah semua bangunan & dekor jadi. rects: Rect2(x,z) bangunan; discs: Vector3(x, z, r) benda bulat;
## roads: Rect2 jalan/alun-alun (jalur lebih murah -> warga memilih lewat jalan).
static func set_obstacles(rects: Array, discs: Array, roads: Array) -> void:
	_blocked_cells = PackedByteArray()
	_blocked_cells.resize(GRID_W * GRID_H)
	_road_cells = PackedByteArray()
	_road_cells.resize(GRID_W * GRID_H)
	for gz in GRID_H:
		for gx in GRID_W:
			var p := Vector2(GRID_MIN.x + (gx + 0.5) * CELL, GRID_MIN.y + (gz + 0.5) * CELL)
			var blocked := false
			for r in rects:
				if (r as Rect2).grow(0.45).has_point(p):
					blocked = true
					break
			if not blocked:
				for d in discs:
					if p.distance_to(Vector2(d.x, d.y)) < d.z + 0.3:
						blocked = true
						break
			_blocked_cells[gz * GRID_W + gx] = 1 if blocked else 0
			var on_road := false
			for r in roads:
				if (r as Rect2).has_point(p):
					on_road = true
					break
			_road_cells[gz * GRID_W + gx] = 1 if on_road else 0
	_ready_grid = true


static func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int(floor((p.x - GRID_MIN.x) / CELL)), 0, GRID_W - 1), clampi(int(floor((p.y - GRID_MIN.y) / CELL)), 0, GRID_H - 1))


static func _pos_of(c: Vector2i) -> Vector2:
	return Vector2(GRID_MIN.x + (c.x + 0.5) * CELL, GRID_MIN.y + (c.y + 0.5) * CELL)


static func _is_blocked(c: Vector2i) -> bool:
	return c.x < 0 or c.y < 0 or c.x >= GRID_W or c.y >= GRID_H or _blocked_cells[c.y * GRID_W + c.x] == 1


static func _nearest_free(c: Vector2i) -> Vector2i:
	if not _is_blocked(c):
		return c
	for rad in range(1, 24):
		for dz in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if maxi(absi(dx), absi(dz)) != rad:
					continue
				var n := Vector2i(c.x + dx, c.y + dz)
				if not _is_blocked(n):
					return n
	return c


## Garis a-b bebas rintangan? need_road = true: seluruh garis juga harus di atas jalan/alun-alun (supaya jalur tetap "logis").
static func _clear_line(a: Vector2, b: Vector2, need_road := false) -> bool:
	var n := int(a.distance_to(b) / (CELL * 0.5)) + 1
	for i in n + 1:
		var c := _cell_of(a.lerp(b, float(i) / float(n)))
		if _is_blocked(c):
			return false
		if need_road and _road_cells[c.y * GRID_W + c.x] == 0:
			return false
	return true


## Jalur jalan antar dua titik: A* di grid (jalan lebih murah daripada rumput), lalu diluruskan. Hasil: Array Vector3 (y = from.y).
static func route(from: Vector3, to: Vector3) -> Array:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	if not _ready_grid:
		return [Vector3(to.x, from.y, to.z)]
	var sc := _nearest_free(_cell_of(a))
	var gc := _nearest_free(_cell_of(b))
	var open: Array = [sc]
	var g := {sc: 0.0}
	var came := {}
	var closed := {}
	var found := false
	while not open.is_empty():
		var bi := 0
		var bf := 1e18
		for i in open.size():
			var c: Vector2i = open[i]
			var f: float = float(g[c]) + Vector2(c).distance_to(Vector2(gc)) * 0.8
			if f < bf:
				bf = f
				bi = i
		var cur: Vector2i = open[bi]
		open.remove_at(bi)
		if cur == gc:
			found = true
			break
		if closed.has(cur):
			continue
		closed[cur] = true
		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var n := Vector2i(cur.x + dx, cur.y + dz)
				if _is_blocked(n) or closed.has(n):
					continue
				if dx != 0 and dz != 0 and (_is_blocked(Vector2i(cur.x + dx, cur.y)) or _is_blocked(Vector2i(cur.x, cur.y + dz))):
					continue                                                   # jangan memotong sudut bangunan
				var step := (1.414 if dx != 0 and dz != 0 else 1.0) * (1.0 if _road_cells[n.y * GRID_W + n.x] == 1 else 2.6)       # rumput 2.6x lebih "mahal": utamakan jalan
				var ng: float = float(g[cur]) + step
				if not g.has(n) or ng < float(g[n]):
					g[n] = ng
					came[n] = cur
					open.append(n)
	if not found:
		return [Vector3(to.x, from.y, to.z)]
	var cells: Array = [gc]
	while cells[0] != sc:
		cells.push_front(came[cells[0]])
	var pts: Array[Vector2] = [a]
	for c in cells:
		pts.append(_pos_of(c))
	pts.append(b if not _is_blocked(_cell_of(b)) else _pos_of(gc))
	# luruskan (string pulling) selama garis lurus tidak menembus rintangan
	var out: Array = []
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1 and not _clear_line(pts[i], pts[j], pts[i].distance_to(pts[j]) > 3.5):
			j -= 1
		out.append(Vector3(pts[j].x, from.y, pts[j].y))
		i = j
	return out
