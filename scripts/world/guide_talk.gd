extends RefCounted
## GuideTalk - percakapan Centorea (pemandu di Farm).
##   intro_lines() : dialog cutscene pertama kali bertemu.
##   open()        : menu "Ada yang ingin kau tahu atau tanyakan?" -> pilih topik (tips & trik) -> jawaban -> menu lagi.
## Tambah / ubah topik di TOPICS: [judul pertanyaan, [baris jawaban...]].

const NAME := "Centorea"

const TOPICS := [
	["What exactly is my goal?", [
		"You must earn 1,000,000 coins within 30 days. On the morning of day 31, Mayor Harold will visit your front yard and count them.",
		"Reach the goal and this house and land become yours forever. Fall short... and you'll have to leave the village.",
	]],
	["How does farming work?", [
		"Buy seeds from Martha at the General Store. Hoe the soil, plant a seed, and water it every single day. Dry plants don't grow!",
		"Rocks need the Hoe to clear, weeds and branches need the Scythe. Once a crop is ripe, harvest it with the Scythe and sell it back to Martha.",
		"Carrots ripen in 2 days, potatoes 3, strawberries 4, corn 5, tomatoes 6, pumpkins 8 and melons 10. Strawberries, corn and tomatoes keep fruiting after you harvest them. The slow ones pay far more!",
	]],
	["What's the fastest way to earn money?", [
		"Mix them all! Farming gives steady money, but the forests pay faster: monsters drop coins and loot worth up to thousands each.",
		"Every day 1-2 piles of coins appear in the forests, with random amounts. Grab them early.",
		"Villagers' quests pay a lot, sometimes tens of thousands of coins. Always check the calendar. And plan your big crops early so they ripen before day 30!",
	]],
	["How do I survive the forests?", [
		"Buy a sword from Gordon, the Blacksmith. Swing it with F or left click. Each swing costs a little energy, and monsters hurt your health.",
		"Forest 1 has Imps, Goblins and Bears. Forest 2 has Werewolves, Skeletons and Monster Hunters. They hit hard, so bring food!",
		"Defeated monsters stay down for the day and come back tomorrow. Ranger Finn knows the forests well, ask him for advice.",
	]],
	["How do energy, food and sleep work?", [
		"Every action costs a little energy. At zero, your health slowly drains, and if that runs out you pass out and lose 25% of your coins as a medical fee. Ouch.",
		"Eat at Lily's Food Shop to recover. You can eat three meals a day at most. Forest Herbs heal 30 energy and don't count as a meal.",
		"Sleep in your bed after 21:00. Go to sleep before midnight to wake up at 06:00 fully rested. Stay up too late and you'll wake up tired.",
	]],
	["Tell me about the villagers and time.", [
		"Morning, noon, evening, night: the sky changes with the time. The villagers wander around the village and forest, and go home at night.",
		"Shops are best visited during the day. Talk to everyone at least once, quests only appear in your calendar after you meet them.",
		"Press M for the map, B for your bag, and check the calendar for deadlines.",
	]],
	["Any secret tips?", [
		"Upgrade your tools at Gordon's. They work in wider lines and cost less energy.",
		"Store spare items in the chest by your front door, and keep some food in your bag.",
		"Sell drops, not just crops. A Goblin Ear is worth 2,000 coins, and a Gold Nugget 5,000!",
		"And remember: it's fine to rest. A tired farmer is a slow farmer.",
	]],
]


## Tutorial setelah tiba di farm (cerita pembuka bagian 2). Baris terakhir sengaja terpisah di guide_cutscene.
static func tutorial_lines() -> Array:
	return [
		"Here we are, this is your farm! The house, the fields and the chest by the front door are all yours to use.",
		"Your goal: earn 1,000,000 coins in 30 days. On the morning of day 31, the Mayor will come to your front yard to count them.",
		"Farming first. Buy seeds from Martha at the General Store, hoe the soil, plant a seed and water it every day. Rocks need the Hoe, weeds and branches need the Scythe.",
		"Harvest ripe crops with the Scythe and sell them back to Martha. Slow crops like pumpkins and melons pay far more!",
		"Need money faster? The forests east of the village are full of monsters and coin piles. Buy a sword from Gordon, and eat at Lily's to keep your energy up.",
		"Sleep in your bed after 21:00, before midnight. Press B for your bag, M for the map, and check the calendar for the villagers' quests.",
	]


static func intro_lines() -> Array:
	return [
		"Oh! You must be the new farmer. Welcome to your farm! I'm Centorea.",
		"The Mayor asked me to stay here and guide you. I'll be right here whenever you need me.",
		"Your mission is simple: earn 1,000,000 coins in 30 days. Do it, and this land is yours for good.",
		"Come talk to me whenever you have questions. Good luck, farmer!",
	]


## Menu tanya-jawab. first = pertama kali (salam), selanjutnya "ada lagi?".
static func open(first := true) -> void:
	var opts: Array = []
	for t in TOPICS:
		opts.append(t[0])
	opts.append("Nothing, thank you!")
	var prompt := "Is there anything you'd like to know, or ask?" if first else "Anything else you'd like to ask?"
	HUD.ask(NAME, prompt, opts, func(i: int) -> void:
		if i >= TOPICS.size():
			HUD.say(NAME, ["Alright! Good luck out there. Come back anytime."], Callable(), false)
			return
		var again := func() -> void: open(false)
		HUD.say(NAME, ["> " + String(TOPICS[i][0])] + TOPICS[i][1], again, false), false)
