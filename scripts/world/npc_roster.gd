extends RefCounted
## NpcRoster - data semua warga (nama, toko, dialog, tampilan, tempat jadwal di desa).
## Dipakai village.gd (warga yang tinggal di desa) dan npc_visitors.gd (warga yang berkunjung ke farm / hutan).
## Titik pertama di "spots" = pintu "rumah" (pagi mereka di sini; malam mereka pulang & masuk); sisanya tempat singgah di desa.

const IDS := ["martha", "gordon", "lily", "harold", "anna", "tom", "mia", "joe", "rose", "finn"]

const DATA := {
	"martha": {"name": "Martha", "shop": "general",
		"greet": ["Welcome to the General Store! Seeds to buy, crops to sell.", "Fresh harvest fetches the best price. Come back anytime!"],
		"look": {"model": "martha", "hair": Color("7a4a2a"), "outfit": Color("a8584a"), "top": Color("f6efe0"), "ribbon": Color("e0b04a")},
		"spots": [["At the shop", Vector3(-14, 0, -5.4)], ["Plaza", Vector3(-2, 0, 8.5)], ["Market road", Vector3(-7, 0, -4.5)]]},
	"gordon": {"name": "Gordon", "shop": "blacksmith",
		"greet": ["Gordon's the name. Good tools make good farmers.", "Upgrade your tools and you'll cover more soil with every swing."],
		"look": {"model": "gordon", "hair": Color("5a5a60"), "outfit": Color("5a4636"), "top": Color("c9c2b8"), "ribbon": Color("8a5a30"), "scale": 1.1},
		"spots": [["At the shop", Vector3(0, 0, -5.4)], ["Plaza", Vector3(2.5, 0, 8.5)], ["Market road", Vector3(7, 0, -4.5)]]},
	"lily": {"name": "Lily", "shop": "food",
		"greet": ["Welcome to my kitchen! Hungry?", "Remember, you can only eat three meals a day."],
		"look": {"model": "lily", "hair": Color("e0b04a"), "outfit": Color("d8708a"), "top": Color("fff4f0"), "ribbon": Color("ffffff")},
		"spots": [["At the shop", Vector3(14, 0, -5.4)], ["Plaza", Vector3(3.5, 0, -0.5)], ["Market road", Vector3(10, 0, -4.5)]]},
	"harold": {"name": "Mayor Harold", "shop": "",
		"greet": ["Keep working hard. The village is watching, in a friendly way!", "Check the calendar for upcoming events and the deadline."],
		"look": {"model": "harold", "hair": Color("c8c8d0"), "outfit": Color("3a5a3a"), "top": Color("e8e0c8"), "ribbon": Color("c9a030"), "scale": 1.05},
		"spots": [["Village Hall", Vector3(7, 0, -14.8)], ["Plaza", Vector3(3, 0, 4)], ["Bell Tower", Vector3(-7, 0, -14.8)], ["Main road", Vector3(2.5, 0, -4.5)]]},
	"anna": {"name": "Anna", "shop": "",
		"greet": ["The bakery will open someday. For now, I bake at home!", "Nothing beats fresh carrots."],
		"look": {"model": "anna", "hair": Color("b05a38"), "outfit": Color("d99a4a"), "top": Color("fff0d8"), "ribbon": Color("d9404a")},
		"spots": [["Her house", Vector3(-16, 0, 17.6)], ["Plaza", Vector3(-3, 0, 4)], ["Market road", Vector3(-10, 0, -4.5)], ["West road", Vector3(-21, 0, 17.6)]]},
	"tom": {"name": "Old Tom", "shop": "",
		"greet": ["Back in my day, we farmed with our bare hands.", "Ahh, my knees..."],
		"look": {"model": "tom", "hair": Color("e0e0e8"), "outfit": Color("6a5a48"), "top": Color("b8c0a8"), "ribbon": Color("6a5a48"), "scale": 0.95, "yaw": 20},
		"spots": [["Home bench", Vector3(-8, 0, 17.6)], ["By the well", Vector3(-2.5, 0, 7.5)], ["Plaza", Vector3(4, 0, 5)], ["Market road", Vector3(8, 0, -4.5)]]},
	"mia": {"name": "Mia", "shop": "",
		"greet": ["Hi! I'm Mia. I love the festival season.", "Have you tried the corn here?"],
		"look": {"model": "mia", "hair": Color("2a3a6a"), "outfit": Color("5aa0c8"), "top": Color("ffffff"), "ribbon": Color("ffd84a"), "scale": 0.9},
		"spots": [["Her house", Vector3(8, 0, 17.6)], ["Plaza", Vector3(5, 0, 8)], ["Village Hall", Vector3(10.5, 0, -14.5)], ["East road", Vector3(18, 0, 4.5)]]},
	"joe": {"name": "Farmer Joe", "shop": "",
		"greet": ["Crows... always the crows.", "A farmer's life is never boring."],
		"look": {"model": "joe", "hair": Color("6a4a2a"), "outfit": Color("5a7a3a"), "top": Color("d8c898"), "ribbon": Color("8a5a30"), "scale": 1.08},
		"spots": [["Farm road", Vector3(17, 0, 17.6)], ["East road", Vector3(20, 0, 4.5)], ["Market road", Vector3(14, 0, -4.5)], ["Plaza", Vector3(0, 0, 9)]]},
	"rose": {"name": "Granny Rose", "shop": "",
		"greet": ["Sit with me by the well, dearie.", "This village has seen many seasons."],
		"look": {"model": "rose", "hair": Color("f0f0f4"), "outfit": Color("8a5aa0"), "top": Color("f0e0f0"), "ribbon": Color("d88ac0"), "scale": 0.88},
		"spots": [["West porch", Vector3(-12, 0, 17.6)], ["By the well", Vector3(-4, 0, 7.5)], ["Plaza bench", Vector3(3.2, 0, 1.0)], ["Market road", Vector3(-5, 0, -4.5)]]},
	"finn": {"name": "Ranger Finn", "shop": "",
		"greet": ["The forest east of here is dangerous. Imps and Goblins are weak, Werewolves and Skeletons are not!", "Bring a good tool and some food before you go in."],
		"look": {"model": "finn", "hair": Color("5a3a22"), "yaw": -70},
		"spots": [["Forest gate", Vector3(16.5, 0, 1.0)], ["East road", Vector3(10, 0, 1.5)], ["Plaza", Vector3(-2, 0, 1.5)]]},
}
