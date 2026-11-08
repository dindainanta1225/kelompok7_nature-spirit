extends Node
## VillageIntro - cerita pembuka bagian 1 (di Desa): player datang dari jalan selatan, bertemu Mayor Harold, mereka mengobrol,
## lalu Centorea datang dan membawa player ke farm. Bagian 2 (tutorial di farm) ada di guide_cutscene.gd.
## Dipasang village.gd saat GameState.intro_stage == 0 (game baru).

const Cinematic := preload("res://scripts/world/cinematic.gd")
const NPCActor := preload("res://scripts/world/npc_actor.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")
const GY := 1.5
const FARM_SCENE := "res://scene/world/farm/farm.tscn"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func _walk_player(player: Node3D, to: Vector3, limit := 16.0) -> void:
	player.call("auto_walk", to, 2.6)
	var waited := 0.0
	while player.call("is_auto_walking") and waited < limit:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if player.call("is_auto_walking"):
		player.set("_auto_target", Vector3.INF)
		player.global_position = Vector3(to.x, player.global_position.y, to.z)


func _walk_npc(n: Node3D, pts: Array, limit := 16.0) -> void:
	var st := {"done": false}
	n.call("walk_along", pts, func() -> void: st["done"] = true)
	var waited := 0.0
	while not st["done"] and waited < limit:
		await get_tree().process_frame
		waited += get_process_delta_time()


func _face_player(player: Node3D, to: Vector3) -> void:
	var pv: Node3D = player.get("visual")
	if pv != null:
		create_tween().tween_property(pv, "rotation:y", atan2(to.x - player.global_position.x, to.z - player.global_position.z), 0.3)


func _run() -> void:
	var vil := get_parent()
	var player: Node3D = null
	for i in 40:
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")
		if player != null and i > 8:
			break
	var mayor: Node3D = vil.get("_npc_nodes").get("harold") if vil.get("_npc_nodes") != null else null
	if player == null or mayor == null:
		GameState.intro_stage = 1                              # tidak bisa memutar cutscene -> langsung ke tutorial di farm
		queue_free()
		return
	var cin := Cinematic.new(get_tree())
	await cin.begin()
	Sfx.play("stinger", -6.0)
	# Mayor menunggu di tepi jalan dekat alun-alun
	mayor.call("walk_along", [])
	mayor.visible = true
	mayor.position = Vector3(2.4, GY, 10.0)
	mayor.call("look_at_point", Vector3(0.0, GY, 18.0))
	# 1) player berjalan dari selatan ke Mayor
	await cin.wait(0.6)
	await _walk_player(player, Vector3(0.2, GY, 13.4))
	_face_player(player, mayor.global_position)
	mayor.call("look_at_point", player.global_position)
	mayor.set("force_talk", true)
	Sfx.play("npc_hi", -2.0)
	await cin.wait(0.4)
	await cin.say("Mayor Harold", [
		"Ah, there you are! You must be the new farmer. Welcome to our village, I'm Harold, the mayor here.",
		"The old farm on the edge of the village has stood empty for years. The spirits of nature have been restless without a keeper.",
	])
	await cin.say("You", ["...Me? A farmer? I only came to look around."])
	await cin.say("Mayor Harold", [
		"Ha ha! Everyone says that at first. Here's my offer: earn 1,000,000 coins in 30 days, and the farm is yours for good.",
		"Fall short, and I'm afraid you'll have to leave. Don't look so worried! I'll visit your front yard on day 31 to see how you did.",
	])
	await cin.say("You", ["A million coins in 30 days... Alright. I'll do it!"])
	Sfx.play("quest", -6.0)
	# 2) Centorea datang
	mayor.set("force_talk", false)
	var cen := NPCActor.new()
	cen.npc_id = "centorea"
	cen.display_name = "Centorea"
	cen.guide = true
	cen.greetings = ["Hello!"]
	cen.look = {"model": "centorea", "hair": Color("e8c860")}
	cen.spot_name = "Escorting you"
	cen.position = Vector3(0.0, GY, 24.5)
	vil.add_child(cen)
	await get_tree().process_frame
	cen.call("look_at_point", Vector3(0.0, GY, 12.0))
	Sfx.play("npc_hi", -2.0, 0.9)
	await _walk_npc(cen, [Vector3(-1.9, GY, 14.6)], 12.0)
	cen.call("look_at_point", player.global_position)
	mayor.call("look_at_point", cen.global_position)
	cen.set("force_talk", true)
	await cin.say("Mayor Harold", ["Ah, and here's Centorea! She'll be your guide. She knows everything about farming, the village and the forests."])
	await cin.say("Centorea", [
		"Nice to meet you! I'm Centorea. The Mayor asked me to look after you.",
		"Come, I'll show you your farm and teach you everything you need. Follow me!",
	])
	cen.set("force_talk", false)
	await cin.say("Mayor Harold", ["Good luck, farmer! I'll be watching... in a friendly way."])
	# 3) menuju farm: Centorea di depan, player mengikuti
	Sfx.play("whoosh", -12.0)
	cen.set("walk_speed", 2.5)
	cen.call("walk_along", [Vector3(-0.2, GY, 18.0), Vector3(0.0, GY, 25.8)])
	await cin.wait(1.4)                                         # Centorea jalan duluan, player menyusul di belakangnya (lebih lambat)
	player.call("auto_walk", Vector3(0.0, GY, 23.6), 2.1)
	var waited := 0.0
	while player.call("is_auto_walking") and waited < 14.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	player.set("_auto_target", Vector3.INF)
	GameState.intro_stage = 1
	await cin.end(true)                                         # HUD tetap tersembunyi sampai tutorial selesai
	GameState.cutscene = true
	await GameState.change_area(FARM_SCENE, "from_village")
