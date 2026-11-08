extends RefCounted
## FarmLayout - tata letak Farm: 2 petak tanam 5x5 (= 50 petak), rumah, dan peti.
## Semua koordinat dalam "petak" grid dunia (x, z). Ubah angka di sini kalau mau menggeser.
##
## Aturan tanam:
##   - Hanya petak di dalam PLOTS yang bisa dipakai.
##   - Awalnya tiap petak bisa berisi rintangan: batu (butuh Hoe), kayu & rumput liar (butuh Scythe).
##   - Setelah bersih, petak harus dicangkul (Hoe) dulu baru bisa ditanami.

const AREA := "res://scene/world/farm/farm.tscn"
const PLOTS := [Rect2i(0, -7, 5, 5), Rect2i(7, -7, 5, 5)]       # x, z (pojok kiri-atas), lebar, tinggi

## rintangan -> alat yang membersihkannya
const OBSTACLE_TOOL := {"rock": "hoe", "wood": "scythe", "weed": "scythe"}
const OBSTACLE_NAME := {"rock": "Rock", "wood": "Fallen branch", "weed": "Weeds"}
const TOOL_NAME := {"hoe": "Hoe", "scythe": "Scythe", "watering_can": "Watering Can"}
const OBSTACLE_CHANCE := 0.62            # peluang sebuah petak berisi rintangan di awal permainan

const HOUSE_X := -9.0                    # pusat rumah
const HOUSE_FRONT_Z := -5.0              # sisi depan rumah (pintu menghadap +Z)
const CHEST_POS := Vector3(-5.2, 0.0, -3.6)


static func in_plot(c: Vector2i) -> bool:
	for r in PLOTS:
		if (r as Rect2i).has_point(c):
			return true
	return false


static func plot_cells() -> Array:
	var out: Array = []
	for r in PLOTS:
		for x in range(r.position.x, r.position.x + r.size.x):
			for z in range(r.position.y, r.position.y + r.size.y):
				out.append(Vector2i(x, z))
	return out


## Data awal Farm: tiap petak { tilled, crop, age, watered, obs }.
static func generate(seed_value := 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	var cells := {}
	for c in plot_cells():
		var obs := ""
		if rng.randf() < OBSTACLE_CHANCE:
			var r := rng.randf()
			obs = "rock" if r < 0.32 else ("wood" if r < 0.55 else "weed")
		cells[c] = {"tilled": false, "crop": "", "age": 0, "watered": false, "obs": obs}
	return cells
