extends RefCounted
## QuestData - jadwal quest yang tampil di KALENDER dan dipakai NPC desa.
##
## Tiap quest:  id, npc, day (muncul), due (batas hari, 0 = tanpa batas), title, text (ringkasan di kalender),
##              ask (dialog NPC saat meminta), done_line (dialog saat selesai),
##              item + n (barang yang diminta, "" = hanya cerita), coins + rewards (hadiah).
## Isi quest di kalender TERSEMBUNYI sampai pemain menemui NPC-nya (GameState.meet_npc dipanggil otomatis
## oleh NPC desa saat diajak bicara). Quest "item" selesai kalau pemain bicara lagi membawa barangnya.

const NPCS := {
	"harold": "Mayor Harold",
	"martha": "Martha (General Store)",
	"gordon": "Gordon (Blacksmith)",
	"lily": "Lily (Food Shop)",
	"anna": "Anna (Baker)",
	"tom": "Old Tom",
	"mia": "Mia",
	"joe": "Farmer Joe",
	"rose": "Granny Rose",
	"finn": "Ranger Finn (Forest guide)",
	"centorea": "Centorea (Farm guide)",
}

const QUESTS := [
	{"id": "welcome", "npc": "harold", "day": 1, "due": 0, "title": "Welcome to the Village",
		"text": "Meet Mayor Harold at the village hall. He will explain the terms of your stay.",
		"ask": "Welcome, stranger! You may stay in our village, but you must collect 1,000,000 coins within 30 days. Good luck!",
		"done_line": "", "item": "", "n": 0, "coins": 0, "rewards": {}},
	{"id": "anna_carrots", "npc": "anna", "day": 2, "due": 7, "title": "Fresh Carrots",
		"text": "Anna needs 5 Carrots by day 7. Reward: 11,000 coins + 1 Forest Herb.",
		"ask": "Oh, a farmer! Could you bring me 5 Carrots? My pies won't bake themselves. Please hurry, by day 7!",
		"done_line": "Wonderful, just what I needed! Here is your reward.",
		"item": "carrot", "n": 5, "coins": 11000, "rewards": {"forest_herb": 1}},
	{"id": "tom_potatoes", "npc": "tom", "day": 5, "due": 11, "title": "Potatoes for Stew",
		"text": "Old Tom needs 4 Potatoes by day 11. Reward: 16,000 coins + 1 Forest Herb.",
		"ask": "My knees are bad and my stew pot is empty. Bring me 4 Potatoes by day 11, would you?",
		"done_line": "Ahh, fine potatoes! My stew will be legendary. Take this.",
		"item": "potato", "n": 4, "coins": 16000, "rewards": {"forest_herb": 1}},
	{"id": "mia_corn", "npc": "mia", "day": 9, "due": 15, "title": "Corn for the Festival",
		"text": "Mia needs 5 Corn by day 15. Reward: 41,000 coins + 2 Forest Herbs.",
		"ask": "The festival is coming and we need 5 Corn for the popcorn stand! Can you help, by day 15?",
		"done_line": "Yay! The kids will love it. Thank you so much!",
		"item": "corn", "n": 5, "coins": 41000, "rewards": {"forest_herb": 2}},
	{"id": "joe_tomatoes", "npc": "joe", "day": 13, "due": 20, "title": "Tomato Shortage",
		"text": "Farmer Joe needs 4 Tomatoes by day 20. Reward: 69,000 coins + 1 Gold Nugget.",
		"ask": "My tomato field got eaten by crows. Bring me 4 Tomatoes by day 20 and I'll pay well.",
		"done_line": "Saved my market stall! A nugget for your trouble, friend.",
		"item": "tomato", "n": 4, "coins": 69000, "rewards": {"gold_nugget": 1}},
	{"id": "rose_pumpkins", "npc": "rose", "day": 17, "due": 26, "title": "Pumpkins for Granny",
		"text": "Granny Rose needs 3 Pumpkins by day 26. Reward: 137,000 coins + 1 Gold Nugget.",
		"ask": "Dearie, I'd love 3 big Pumpkins for my famous pie. Bring them by day 26 and I'll make it worth it.",
		"done_line": "Oh my, such beauties! Here, take this, and don't tell the Mayor.",
		"item": "pumpkin", "n": 3, "coins": 137000, "rewards": {"gold_nugget": 1}},
	{"id": "lily_melons", "npc": "lily", "day": 21, "due": 29, "title": "Melons for the Menu",
		"text": "Lily needs 2 Melons by day 29. Reward: 192,000 coins + 1 Gold Nugget.",
		"ask": "I'm designing a new dessert and I need 2 Melons. Bring them by day 29, and the payment is generous!",
		"done_line": "Perfect! This will be the dish of the year. Here's your payment.",
		"item": "melon", "n": 2, "coins": 192000, "rewards": {"gold_nugget": 1}},
	{"id": "final", "npc": "harold", "day": 30, "due": 0, "title": "Judgment Day",
		"text": "Tomorrow morning Mayor Harold will count your coins. Make sure you reach the goal!",
		"ask": "Tomorrow morning I will count your coins. I hope you made it!",
		"done_line": "", "item": "", "n": 0, "coins": 0, "rewards": {}},
]


static func for_day(d: int) -> Array:
	var out: Array = []
	for q in QUESTS:
		if int(q["day"]) == d:
			out.append(q)
	return out


static func npc_name(id: String) -> String:
	return NPCS.get(id, id)


## Quest yang sedang terbuka untuk NPC ini hari ini (belum selesai, sudah muncul, belum lewat batas). {} kalau tidak ada.
static func active_for(npc: String, today: int, done: Dictionary) -> Dictionary:
	for q in QUESTS:
		if q["npc"] != npc or done.has(q["id"]):
			continue
		if int(q["day"]) > today:
			continue
		if int(q["due"]) > 0 and today > int(q["due"]):
			continue
		return q
	return {}


## Nama tampilan item (untuk dialog).
static func items_name(id: String) -> String:
	var inv := preload("res://scripts/managers/inventory.gd")
	return inv.items[id]["name"] if inv.items.has(id) else id
