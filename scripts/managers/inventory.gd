extends RefCounted
## Inventory - data tas pemain. 18 slot; 9 slot pertama = hotbar (tombol 1-9), sisanya backpack.
## Dimiliki GameState:  GameState.inventory.add("carrot", 3)  /  .remove("carrot_seed", 1)  /  .count("carrot")
##
## Menambah item baru: tambahkan satu baris di _static_init() di bawah (atau di daftar CROPS).
## Gambar ikon dibuat lewat kode; kalau kamu punya gambar, taruh di res://assets/items/<id>.png dan otomatis dipakai.

signal changed
signal selected_changed(index: int)
signal item_added(id: String, amount: int)

const SLOTS := 18
const HOTBAR := 9
const STACK := 99

## id -> {name, kind (tool/seed/crop/food/drop), shape, color, desc}
static var items := {}

## [id, nama, warna, bentuk ikon, hari tumbuh]  (7 tanaman; hari tumbuh sementara, nanti disamakan dengan ekonomi final)
const CROPS := [
	["carrot", "Carrot", Color(0.95, 0.52, 0.12), "carrot", 2],
	["potato", "Potato", Color(0.80, 0.62, 0.36), "potato", 3],
	["strawberry", "Strawberry", Color(0.92, 0.18, 0.28), "strawberry", 4],
	["corn", "Corn", Color(0.98, 0.84, 0.25), "corn", 5],
	["tomato", "Tomato", Color(0.90, 0.20, 0.15), "tomato", 6],
	["pumpkin", "Pumpkin", Color(0.96, 0.55, 0.12), "pumpkin", 8],
	["melon", "Melon", Color(0.45, 0.75, 0.30), "melon", 10],
]

## Tanaman yang bisa dipanen berulang: hari sampai berbuah lagi setelah dipanen (tanaman lain sekali panen).
const REGROW := {"strawberry": 2, "corn": 3, "tomato": 3}

var slots: Array = []        # tiap elemen: {} (kosong) atau {"id": String, "n": int}
var selected := 0


static func _static_init() -> void:
	items["hoe"] = {"name": "Hoe", "kind": "tool", "shape": "hoe", "color": Color(0.75, 0.77, 0.82),
		"desc": "Tills soil so it can be planted. Uses 1.5 energy."}
	items["watering_can"] = {"name": "Watering Can", "kind": "tool", "shape": "can", "color": Color(0.36, 0.58, 0.88),
		"desc": "Waters crops so they keep growing. Uses 1 energy."}
	items["scythe"] = {"name": "Scythe", "kind": "tool", "shape": "scythe", "color": Color(0.80, 0.82, 0.86),
		"desc": "Harvests ripe crops. Uses 1 energy."}
	items["sword"] = {"name": "Sword", "kind": "tool", "shape": "sword", "color": Color(0.85, 0.88, 0.94),
		"desc": "For fighting monsters in the forests. Uses 2 energy per swing."}
	for c in CROPS:
		items[c[0] + "_seed"] = {"name": c[1] + " Seed", "kind": "seed", "shape": "seed", "color": c[2],
			"desc": "Plant in tilled soil. Ripe after %d days%s." % [c[4], (", then fruits again every %d days" % REGROW[c[0]]) if REGROW.has(c[0]) else ""]}
		items[c[0]] = {"name": c[1], "kind": "crop", "shape": c[3], "color": c[2],
			"desc": "Fresh from the field. Sell it at the General Store."}
	items["apple"] = {"name": "Apple", "kind": "food", "shape": "apple", "color": Color(0.88, 0.2, 0.18), "desc": "Restores 8 energy and 4 HP."}
	items["orange"] = {"name": "Wild Orange", "kind": "food", "shape": "orange", "color": Color(1.0, 0.58, 0.12), "desc": "Restores 6 energy and 3 HP."}
	items["pear"] = {"name": "Wild Pear", "kind": "food", "shape": "pear", "color": Color(0.74, 0.82, 0.25), "desc": "Restores 7 energy and 3 HP."}
	items["berry"] = {"name": "Wild Berries", "kind": "food", "shape": "berries", "color": Color(0.50, 0.20, 0.62), "desc": "Restores 5 energy and 2 HP."}
	items["bread"] = {"name": "Bread", "kind": "food", "shape": "bread", "color": Color(0.82, 0.58, 0.28), "desc": "Restores 22 energy and 11 HP."}
	items["grilled_fish"] = {"name": "Grilled Fish", "kind": "food", "shape": "fish", "color": Color(0.92, 0.66, 0.34), "desc": "Restores 50 energy and 25 HP."}
	items["meat_stew"] = {"name": "Meat Stew", "kind": "food", "shape": "bowl", "color": Color(0.62, 0.32, 0.16), "desc": "Restores 78 energy and 39 HP."}
	items["royal_feast"] = {"name": "Royal Feast", "kind": "food", "shape": "feast", "color": Color(0.96, 0.78, 0.25), "desc": "Restores 100 energy and 50 HP."}
	items["imp_horn"] = {"name": "Imp Horn", "kind": "drop", "shape": "horn", "color": Color(0.85, 0.30, 0.25), "desc": "A tiny horn snapped off a forest Imp. Old folks say Imps are lost spirits that never found a home, so keep it as a charm."}
	items["bear_claw"] = {"name": "Bear Claw", "kind": "drop", "shape": "claw", "color": Color(0.45, 0.35, 0.28), "desc": "A claw as long as a finger. The big forest bear guards the berry patches and has never lost a fight, until now."}
	items["werewolf_fur"] = {"name": "Werewolf Fur", "kind": "drop", "shape": "fur", "color": Color(0.62, 0.64, 0.70), "desc": "Silver fur that still smells of moonlight. Villagers say it howls when the full moon rises."}
	items["skeleton_bone"] = {"name": "Skeleton Bone", "kind": "drop", "shape": "bone", "color": Color(0.90, 0.88, 0.80), "desc": "A bone from a restless skeleton of the deep forest. Nobody remembers whose it was, and it is better not to ask."}
	items["goblin_tooth"] = {"name": "Goblin Tooth", "kind": "drop", "shape": "tooth", "color": Color(0.85, 0.88, 0.62), "desc": "A chipped tooth from a sneaky goblin. They collect shiny things and always seem to be missing a few."}
	items["hunter_badge"] = {"name": "Hunter Badge", "kind": "drop", "shape": "badge", "color": Color(0.82, 0.68, 0.30), "desc": "Badge of a Monster Hunter who went looking for a bounty and never left the forest. His armor still stands watch."}
	items["gold_nugget"] = {"name": "Gold Nugget", "kind": "drop", "shape": "nugget", "color": Color(1.0, 0.80, 0.22), "desc": "A rare nugget that glints like a tiny sun. Forest spirits are said to leave these for people who are kind to nature."}
	items["forest_herb"] = {"name": "Forest Herb", "kind": "drop", "shape": "herb", "color": Color(0.36, 0.72, 0.34), "desc": "A sweet-smelling herb the spirits grow between the trees. Restores 30 energy and 15 HP and does not count toward the 3 meals a day."}


func _init() -> void:
	reset()


## Kosongkan semua slot (tas pemain mulai KOSONG; perlengkapan awal ada di peti dekat rumah).
func reset() -> void:
	slots.clear()
	for i in SLOTS:
		slots.append({})
	selected = 0
	changed.emit()
	selected_changed.emit(selected)


## Perlengkapan awal: Hoe, Watering Can, Scythe + 10 benih untuk SETIAP tanaman (7 jenis). Pedang dibeli di Blacksmith.
func fill_start_kit() -> void:
	slots[0] = {"id": "hoe", "n": 1}
	slots[1] = {"id": "watering_can", "n": 1}
	slots[2] = {"id": "scythe", "n": 1}
	var i := 3
	for c in CROPS:
		slots[i] = {"id": c[0] + "_seed", "n": 10}
		i += 1
	changed.emit()


## Hari yang dibutuhkan tanaman sampai siap panen (0 kalau id bukan tanaman).
static func crop_days(id: String) -> int:
	for c in CROPS:
		if c[0] == id:
			return int(c[4])
	return 0


static func regrow_days(id: String) -> int:
	return int(REGROW.get(id, 0))


static func has_item(id: String) -> bool:
	return items.has(id)


static func max_stack(id: String) -> int:
	return 1 if items.get(id, {}).get("kind", "") == "tool" else STACK


## Tambah item. Mengembalikan jumlah yang TIDAK muat (0 = semua masuk).
func add(id: String, amount: int = 1) -> int:
	if not items.has(id) or amount <= 0:
		return amount
	var left := amount
	var cap := max_stack(id)
	for s in slots:
		if left <= 0:
			break
		if not s.is_empty() and s["id"] == id and s["n"] < cap:
			var put := mini(cap - int(s["n"]), left)
			s["n"] += put
			left -= put
	for i in SLOTS:
		if left <= 0:
			break
		if slots[i].is_empty():
			var put := mini(cap, left)
			slots[i] = {"id": id, "n": put}
			left -= put
	if left != amount:
		item_added.emit(id, amount - left)
		changed.emit()
	return left


func count(id: String) -> int:
	var t := 0
	for s in slots:
		if not s.is_empty() and s["id"] == id:
			t += int(s["n"])
	return t


func has(id: String, amount: int = 1) -> bool:
	return count(id) >= amount


## Kurangi item. false (dan tidak ada yang berubah) kalau jumlahnya kurang.
func remove(id: String, amount: int = 1) -> bool:
	if count(id) < amount or amount <= 0:
		return false
	var left := amount
	for i in range(SLOTS - 1, -1, -1):          # ambil dari slot belakang dulu
		if left <= 0:
			break
		var s: Dictionary = slots[i]
		if not s.is_empty() and s["id"] == id:
			var take := mini(int(s["n"]), left)
			s["n"] -= take
			left -= take
			if s["n"] <= 0:
				slots[i] = {}
	changed.emit()
	return true


func swap(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= SLOTS or b >= SLOTS:
		return
	var sa: Dictionary = slots[a]
	var sb: Dictionary = slots[b]
	if not sa.is_empty() and not sb.is_empty() and sa["id"] == sb["id"] and max_stack(sa["id"]) > 1:
		var cap := max_stack(sa["id"])
		var put := mini(cap - int(sb["n"]), int(sa["n"]))      # gabung tumpukan
		sb["n"] += put
		sa["n"] -= put
		if sa["n"] <= 0:
			slots[a] = {}
	else:
		slots[a] = sb
		slots[b] = sa
	changed.emit()


func select(i: int) -> void:
	i = clampi(i, 0, HOTBAR - 1)
	if i != selected:
		selected = i
		selected_changed.emit(i)


## id item yang sedang dipegang di hotbar ("" kalau kosong).
func selected_item() -> String:
	var s: Dictionary = slots[selected]
	return "" if s.is_empty() else String(s["id"])


func slot_item(i: int) -> String:
	var s: Dictionary = slots[i]
	return "" if s.is_empty() else String(s["id"])
