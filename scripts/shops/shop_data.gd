extends RefCounted
## ShopData - semua harga & isi toko (sesuai GDD). Ubah angka di sini untuk balancing.
##
## SELL_PRICE_MULTIPLIER = knob tunggal untuk membuat jual-beli lebih mudah/sulit (default 1.0).

const SELL_PRICE_MULTIPLIER := 1.0

const SEED_PRICE := {"carrot": 600, "potato": 1000, "strawberry": 1400, "corn": 2000, "tomato": 4000, "pumpkin": 10000, "melon": 20000}
const CROP_SELL := {"carrot": 1800, "potato": 3400, "strawberry": 4800, "corn": 6800, "tomato": 14400, "pumpkin": 38000, "melon": 80000}
const DROP_SELL := {"imp_horn": 150, "bear_claw": 400, "werewolf_fur": 900, "skeleton_bone": 2000, "goblin_tooth": 450, "hunter_badge": 3500, "gold_nugget": 5000}

## makanan: id -> [harga, energi]
const FOOD := {
	"apple": [150, 8], "bread": [400, 22], "grilled_fish": [900, 50], "meat_stew": [1400, 78], "royal_feast": [1800, 100],
}
## buah liar (dipetik di farm/desa/hutan): energi kecil, tidak dihitung sebagai makan, tidak dijual di toko
const WILD_FRUIT := {"orange": 6.0, "pear": 7.0, "berry": 5.0}
const HERB_ENERGY := 30.0            # Forest Herb (tidak dihitung sebagai makan)

## harga naik level: alat -> {level_tujuan: harga}. Hoe/Can/Scythe mulai di L1 (gratis); Sword dibeli di L1.
const TOOL_COST := {
	"hoe": {2: 15000, 3: 60000},
	"watering_can": {2: 15000, 3: 60000},
	"scythe": {2: 15000, 3: 60000},
	"sword": {1: 3000, 2: 18000, 3: 60000},
}
const TOOL_ORDER := ["hoe", "watering_can", "scythe", "sword"]
const SWORD_DAMAGE := {1: 10, 2: 20, 3: 35}

const SHOPS := {
	"general": {"title": "General Store", "keeper": "Martha", "tabs": ["Buy", "Sell"],
		"hello": "Seeds to buy, crops and loot to sell!"},
	"blacksmith": {"title": "Blacksmith", "keeper": "Gordon", "tabs": ["Upgrade"],
		"hello": "Better tools cover more soil per swing."},
	"food": {"title": "Food Shop", "keeper": "Lily", "tabs": ["Menu"],
		"hello": "Hot meals restore energy. Max 3 meals a day!"},
}


static func sell_price(id: String) -> int:
	var base := 0
	if CROP_SELL.has(id):
		base = CROP_SELL[id]
	elif DROP_SELL.has(id):
		base = DROP_SELL[id]
	return int(round(base * SELL_PRICE_MULTIPLIER))


static func buy_price(id: String) -> int:
	if id.ends_with("_seed"):
		return int(SEED_PRICE.get(id.trim_suffix("_seed"), 0))
	if FOOD.has(id):
		return int(FOOD[id][0])
	return 0


static func food_energy(id: String) -> float:
	if FOOD.has(id):
		return float(FOOD[id][1])
	if id == "forest_herb":
		return HERB_ENERGY
	if WILD_FRUIT.has(id):
		return float(WILD_FRUIT[id])
	return 0.0


## Hoe/Can/Scythe level -> jumlah petak yang kena sekaligus (lurus ke depan).
static func tiles_for_level(level: int) -> int:
	return clampi(level, 1, 3)


static func tool_display(id: String) -> String:
	match id:
		"hoe": return "Hoe"
		"watering_can": return "Watering Can"
		"scythe": return "Scythe"
		"sword": return "Sword"
	return id


static func tool_effect(id: String, level: int) -> String:
	if id == "sword":
		return "Damage %d" % int(SWORD_DAMAGE.get(level, 0))
	var n := tiles_for_level(level)
	return "%d tile%s per use" % [n, "" if n == 1 else "s"]
