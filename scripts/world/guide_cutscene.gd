extends Node
## GuideCutscene - cutscene pertama di Farm: player berjalan sendiri menghampiri Centorea, mereka berkenalan.
## Setelah selesai Centorea TETAP di tempatnya; bicara dengannya membuka menu tanya-jawab (GuideTalk.open).
## Dipasang farm_setup.gd saat GameState.guide_met masih false.

const Cinematic := preload("res://scripts/world/cinematic.gd")
const GuideTalk := preload("res://scripts/world/guide_talk.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")
const YARD_Z := -1.2          # jalan setapak di depan rumah
const GUIDE_X := -11.4        # tempat Centorea berdiri di halaman depan rumah
const PLAYER_X := -8.8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func _find_guide() -> Node3D:
	for n in get_tree().get_nodes_in_group("npc"):
		if n.get("npc_id") == "centorea":
			return n
	return null


func _run() -> void:
	var player: Node3D = null
	var guide: Node3D = null
	for i in 40:                                              # tunggu player & Centorea selesai dibuat
		await get_tree().process_frame
		player = get_tree().get_first_node_in_group("player")
		guide = _find_guide()
		if player != null and guide != null and i > 6:
			break
	if player == null or guide == null:
		GameState.guide_met = true
		queue_free()
		return
	var cin := Cinematic.new(get_tree())
	await cin.begin()
	var arrived := GameState.intro_stage >= 1                # datang bersama Centorea dari desa (cerita pembuka)
	var home_spot := guide.global_position
	var cam := player.get_node_or_null("CameraController")
	var cam_pitch := -32.0
	var cam_dist := 9.5
	if cam != null:
		cam_pitch = rad_to_deg(cam.rotation.x)
		cam_dist = float(cam.get("distance"))
	if arrived:
		# Centorea & player tiba di gerbang farm, lalu berjalan lewat jalan setapak ke halaman depan rumah (tempat tutorial)
		guide.set_deferred("visible", true)
		guide.call("walk_along", [])
		# Mulai agak di dalam gerbang & kamera dibuat lebih curam/dekat: kamera biasa (di belakang pemain) akan masuk ke sabuk pohon di tepi peta
		guide.global_position = Vector3(-0.5, home_spot.y, 12.6)
		player.global_position = Vector3(0.4, player.global_position.y, 14.0)
		guide.call("look_at_point", Vector3(-0.5, home_spot.y, 5.0))
		if cam != null:
			cam.rotation.x = deg_to_rad(-52.0)
			cam.set("distance", 7.0)
		await cin.wait(0.4)
		var st := {"done": false}
		guide.set("walk_speed", 3.0)
		guide.call("walk_along", [Vector3(-0.5, home_spot.y, YARD_Z), Vector3(GUIDE_X, home_spot.y, YARD_Z)], func() -> void: st["done"] = true)
		await cin.wait(0.6)
		for pt in [Vector3(-0.5, 0.0, YARD_Z), Vector3(PLAYER_X, 0.0, YARD_Z)]:
			player.call("auto_walk", pt, 3.0)
			var wp := 0.0
			while player.call("is_auto_walking") and wp < 14.0:
				await get_tree().process_frame
				wp += get_process_delta_time()
		player.set("_auto_target", Vector3.INF)
		var w0 := 0.0
		while not st["done"] and w0 < 10.0:
			await get_tree().process_frame
			w0 += get_process_delta_time()
		guide.set("walk_speed", 1.7)
		if cam != null:                                       # kembalikan sudut kamera normal pelan-pelan
			var tc := create_tween().set_parallel(true)
			tc.tween_property(cam, "rotation:x", deg_to_rad(cam_pitch), 1.4).set_trans(Tween.TRANS_SINE)
			tc.tween_property(cam, "distance", cam_dist, 1.4).set_trans(Tween.TRANS_SINE)
	Sfx.play("stinger", -6.0)
	await cin.wait(0.3)
	# 1) player berjalan sendiri ke Centorea
	var gp := guide.global_position
	var from := player.global_position
	var dir := Vector3(from.x - gp.x, 0.0, from.z - gp.z).normalized()
	var stop := gp + dir * 2.4
	player.call("auto_walk", stop, 2.6)
	var waited := 0.0
	while player.call("is_auto_walking") and waited < 14.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if player.call("is_auto_walking"):                       # tersangkut sesuatu -> pindahkan saja
		player.set("_auto_target", Vector3.INF)
		player.global_position = Vector3(stop.x, player.global_position.y, stop.z)
	# 2) saling menoleh
	var pv: Node3D = player.get("visual")
	if pv != null:
		var tw := create_tween()
		tw.tween_property(pv, "rotation:y", atan2(gp.x - player.global_position.x, gp.z - player.global_position.z), 0.3)
	guide.call("look_at_point", player.global_position)
	guide.set("force_talk", true)
	Sfx.play("npc_hi", -2.0, 1.1)
	await cin.wait(0.3)
	# 3) perkenalan
	await cin.say("Centorea", GuideTalk.tutorial_lines() if arrived else GuideTalk.intro_lines())
	# 4) player merayakan, Centorea tersenyum
	guide.set("force_talk", false)
	var girl: Node = player.get("girl")
	if girl != null and girl.has_method("play_anim"):
		girl.play_anim("celebrate")
	Sfx.play("quest", -4.0)
	await cin.wait(1.6)
	guide.set("force_talk", true)
	await cin.say("Centorea", ["If you have any questions, just say so! I'll be right here, talk to me anytime."])
	guide.set("force_talk", false)
	GameState.guide_met = true
	if arrived:                                              # Centorea tetap di halaman depan rumah (jalan-jalan kecil di sekitarnya)
		guide.set("wander_center", guide.global_position)
		guide.set("wander_radius", 1.8)
	await cin.end()
	GameState.toast.emit("Move: WASD  |  Interact: E  |  Bag: B  |  Map: M")
	queue_free()
