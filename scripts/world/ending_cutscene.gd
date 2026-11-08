extends Node
## EndingCutscene - ending (Good / Bad) di halaman depan rumah player (scene Farm).
##   Hari ke-31 pagi: Mayor Harold datang dari gerbang, membawa hasil keputusan desa.
##   GOOD  : koin >= 1.000.000 -> penduduk berbondong-bondong datang, sorak, konfeti & kembang api, rumah jadi milik player.
##   BAD   : koin kurang -> hujan, Mayor menyampaikan dengan berat hati, warga melepas kepergian, player berjalan keluar desa.
## Selesai -> ending_credits.tscn (credits dengan latar hitam, asap & daun).
## Dipasang farm_setup.gd kalau GameState.ending_kind != "".

const NPCActor := preload("res://scripts/world/npc_actor.gd")
const NpcRoster := preload("res://scripts/world/npc_roster.gd")
const Cinematic := preload("res://scripts/world/cinematic.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")
const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"
const CREDITS := "res://scene/cutscene/ending_credits.tscn"

const GY := 1.5
const DOOR := Vector3(-9.0, GY, -3.3)        # pintu rumah
const YARD := Vector3(-9.0, GY, -0.6)        # halaman depan
const GATE := Vector3(-0.5, GY, 18.2)        # gerbang dari desa
const CROWD := ["martha", "gordon", "lily", "anna", "tom", "mia", "joe", "rose", "finn"]
const LANE_X := -0.5                          # jalan setapak dari gerbang (utara-selatan)
const LANE_Z := -1.2                          # jalan setapak di depan rumah (barat-timur)
const MAYOR_SPOT := Vector3(-6.6, GY, -0.7)
const GUIDE_SPOT := Vector3(-11.4, GY, -0.9)
## Benda di halaman depan (x, z, radius) yang tidak boleh ditembus / ditempati warga: lampu, bedeng bunga, kotak surat,
## bangku, sumur, peti + kotak, semak, dan pagar (dibagi per ~0.8 m).
const OBST := [[-10.6, -3.2, 0.8], [-7.4, -3.2, 0.8], [-12.8, -4.1, 1.4], [-7.8, 0.4, 1.0], [-6.0, 3.4, 1.8], [-15.0, -2.0, 2.2],
	[-5.2, -3.6, 1.6], [-3.3, -4.6, 1.1], [-2.7, -5.8, 1.0], [-5.9, -6.4, 1.0]]

var good := true
var _cin: RefCounted
var _player: Node3D
var _guide: Node3D
var _cam: Node
var _farm: Node
var _mayor: Node3D
var _crowd := {}
var _curtain: ColorRect
var _layer: CanvasLayer
var _font: Font
var _tint: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	good = GameState.ending_kind != "bad"
	_farm = get_parent()
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	_run()


# ------------------------------------------------------------------ alat bantu
func _spawn(id: String, pos: Vector3, speed := 3.2) -> Node3D:
	var d: Dictionary = NpcRoster.DATA[id]
	var n := NPCActor.new()
	n.npc_id = id
	n.display_name = d["name"]
	n.greetings = d["greet"]
	n.look = d["look"]
	n.position = pos
	n.walk_speed = speed
	n.monitoring = false                          # tak bisa diajak bicara selama cutscene
	n.monitorable = false
	_farm.add_child(n)
	return n


func _free(x: float, z: float) -> bool:
	if x < -14.2 or x > -2.4 or z < -2.5 or z > 0.9:
		return false
	for o in OBST:
		if Vector2(x, z).distance_to(Vector2(o[0], o[1])) < float(o[2]):
			return false
	for fx in [-14.5, -13.7, -12.9, -12.1, -11.3, -10.5, -7.5, -6.7, -5.9, -5.1, -4.3, -3.5]:     # pagar di z = 1.8
		if Vector2(x, z).distance_to(Vector2(fx, 1.8)) < 1.0:
			return false
	return true


## Titik berdiri yang kosong (tidak menembus apa pun), tersebar mengelilingi player. `avoid` = titik yang sudah dipakai.
func _stand_spots(count: int, avoid: Array, spacing := 1.35) -> Array:
	var cands: Array = []
	var x := -14.0
	while x <= -2.5:
		var z := -2.4
		while z <= 0.8:
			if _free(x, z):
				cands.append(Vector3(x, GY, z))
			z += 0.45
		x += 0.45
	var c := Vector3(-9.0, GY, -0.9)
	cands.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_to(c) < b.distance_to(c))
	var out: Array = []
	for v in cands:
		if out.size() >= count:
			break
		if v.distance_to(c) < 2.0:
			continue
		var ok := true
		for q in out + avoid:
			if v.distance_to(q) < spacing:
				ok = false
				break
		if ok:
			out.append(v)
	return out


## Jalur masuk dari gerbang ke titik berdiri lewat jalan setapak (bukan menembus bangku / pagar / sumur).
func _lane_to(dest: Vector3) -> Array:
	return [Vector3(LANE_X, GY, 10.0), Vector3(LANE_X, GY, LANE_Z), Vector3(dest.x, GY, LANE_Z), dest]


func _wait_walk(n: Node3D, timeout := 20.0) -> void:
	var t := 0.0
	while n != null and n.call("is_walking") and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
	if n != null and n.call("is_walking"):
		n.call("walk_along", [])


func _face(a: Node3D, b: Node3D) -> void:
	a.call("look_at_point", b.global_position)


func _player_face(p: Vector3) -> void:
	var pv: Node3D = _player.get("visual")
	if pv != null:
		create_tween().tween_property(pv, "rotation:y", atan2(p.x - _player.global_position.x, p.z - _player.global_position.z), 0.35)


func _label(text: String, size: int, low := false) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART                       # teks panjang turun ke baris berikutnya, tidak terpotong
	if low:                                                                # teks akhir di bagian bawah layar
		l.anchor_left = 0.07
		l.anchor_right = 0.93
		l.anchor_top = 0.60
		l.anchor_bottom = 0.90
		l.offset_left = 0.0
		l.offset_right = 0.0
		l.offset_top = 0.0
		l.offset_bottom = 0.0
	else:
		l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.03))
	l.add_theme_constant_override("outline_size", maxi(6, size / 6))
	if _font:
		l.add_theme_font_override("font", _font)
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Kartu teks besar di tengah layar (judul / narasi). Muncul, ditahan, hilang.
signal card_finished


func _card(lines: Array, hold := 2.2, size := 64, low := false) -> void:
	for ln in lines:
		var l := _label(String(ln), size, low)
		_layer.add_child(l)
		var t := create_tween()
		t.tween_property(l, "modulate:a", 1.0, 0.8)
		t.tween_interval(hold)
		t.tween_property(l, "modulate:a", 0.0, 0.8)
		await t.finished
		l.queue_free()
	card_finished.emit()


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return out


func _cam_to(dist: float, off: Vector3, sec := 2.0) -> void:
	if _cam == null:
		return
	var t := create_tween().set_parallel(true)
	t.tween_property(_cam, "distance", dist, sec).set_trans(Tween.TRANS_SINE)
	t.tween_property(_cam, "look_offset", off, sec).set_trans(Tween.TRANS_SINE)


# ------------------------------------------------------------------ alur utama
func _run() -> void:
	for i in 30:
		await get_tree().process_frame
		_player = get_tree().get_first_node_in_group("player")
		_guide = null
		for n in get_tree().get_nodes_in_group("npc"):
			if n.get("npc_id") == "centorea":
				_guide = n
		if _player != null and _guide != null and i > 6:
			break
	if _player == null:
		get_tree().change_scene_to_file(CREDITS)
		return
	_cam = _player.get_node_or_null("CameraController")
	_layer = CanvasLayer.new()
	_layer.layer = 70
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	_tint = ColorRect.new()                                                  # nuansa suasana
	_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tint.color = Color(1.0, 0.86, 0.55, 0.07) if good else Color(0.18, 0.24, 0.34, 0.30)
	_layer.add_child(_tint)
	_curtain = ColorRect.new()
	_curtain.color = Color.BLACK
	_curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_curtain)
	_cin = Cinematic.new(get_tree())
	await _cin.begin()
	if _guide != null:
		_guide.monitoring = false
		_guide.monitorable = false
	_player.global_position = DOOR + Vector3(0, 0.1, 0)
	var pv: Node3D = _player.get("visual")
	if pv != null:
		pv.rotation.y = 0.0
	if _cam != null:
		_cam.set("distance", 10.5)
	if not good:
		_rain()
	# --- judul
	_card(["Day 31", "Morning"], 1.2, 80)                   # berjalan sambil layar hitam memudar
	await get_tree().create_timer(0.6).timeout
	create_tween().tween_property(_curtain, "modulate:a", 0.0, 2.0)
	await card_finished
	Sfx.play("morning", -4.0)
	# --- player keluar rumah, Mayor datang
	_player.call("auto_walk", YARD, 1.9)
	await _wait_player()
	await _cin.wait(0.5)
	_cam_to(12.0, Vector3(0, 1.0, 1.5), 3.0)
	_mayor = _spawn("harold", GATE, 3.4)
	_mayor.call("walk_along", _lane_to(MAYOR_SPOT))
	if _guide != null:
		var gp := _guide.global_position
		_guide.set("wander_radius", 0.0)
		if gp.z < 4.0:                                                  # sudah di halaman depan rumah
			_guide.call("walk_along", [GUIDE_SPOT])
		else:
			_guide.call("walk_along", [Vector3(gp.x, GY, 11.0), Vector3(LANE_X, GY, 10.0), Vector3(LANE_X, GY, LANE_Z), Vector3(GUIDE_SPOT.x, GY, LANE_Z), GUIDE_SPOT])
		_guide.set("walk_speed", 2.6)
	await _wait_walk(_mayor)
	_mayor.call("look_at_point", _player.global_position)
	_player_face(_mayor.global_position)
	if _guide != null:
		await _wait_walk(_guide, 10.0)
		_guide.call("look_at_point", _mayor.global_position)
	_cam_to(8.5, Vector3(0, 1.0, 0.4), 1.6)
	await _cin.wait(1.0)
	if good:
		await _good()
	else:
		await _bad()


func _wait_player() -> void:
	var t := 0.0
	while _player.call("is_auto_walking") and t < 14.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	if _player.call("is_auto_walking"):
		_player.set("_auto_target", Vector3.INF)


# ------------------------------------------------------------------ GOOD ENDING
func _good() -> void:
	_mayor.set("force_talk", true)
	await _cin.say("Mayor Harold", [
		"Good morning, farmer! Thirty days have passed since you stepped off that last bus.",
		"I must confess, when you arrived with nothing but a bag, I had my doubts.",
		"So, let me check the village ledger... (He unrolls a long scroll and counts slowly.)",
	])
	Sfx.play("stinger", -4.0)
	await _cin.say("Mayor Harold", ["%s coins!" % _fmt(GameState.coins), "That's more than the 1.000.000 we asked for!"])
	# warga berdatangan
	var spots := _stand_spots(CROWD.size(), [MAYOR_SPOT, GUIDE_SPOT, Vector3(-9.0, GY, -0.6)])
	for i in CROWD.size():
		var id: String = CROWD[i]
		var n := _spawn(id, GATE + Vector3(randf_range(-1.0, 1.0), 0, 0), 3.8)
		var dest: Vector3 = spots[i] if i < spots.size() else MAYOR_SPOT + Vector3(0, 0, -1.6)
		n.call("walk_along", _lane_to(dest))
		_crowd[id] = n
		Sfx.play("npc_hi", -8.0, randf_range(0.9, 1.4))
		await get_tree().create_timer(0.35).timeout
	_cam_to(11.0, Vector3(0, 1.0, 0.2), 2.0)
	for id in _crowd:
		await _wait_walk(_crowd[id], 14.0)
		_crowd[id].call("look_at_point", _player.global_position)
	Sfx.play("cheer", -2.0)
	_confetti()
	await _cin.wait(1.2)
	await _cin.say("Mayor Harold", [
		"By the word of Nature Spirit village, this house and this land now belong to you. Forever.",
		"Welcome home, farmer. You've earned your place here.",
	])
	var girl: Node = _player.get("girl")
	if girl != null and girl.has_method("play_anim"):
		girl.play_anim("celebrate")
	Sfx.play("ending_good", -3.0)
	_fireworks()
	await _cin.wait(1.0)
	_crowd["martha"].set("force_talk", true)
	await _cin.say("Martha", ["Best customer this shop has ever had!"])
	_crowd["martha"].set("force_talk", false)
	await _cin.say("Gordon", ["Hmph. Not bad for a city kid. Come by, I'll sharpen that sword for free."])
	await _cin.say("Lily", ["I'm cooking a feast tonight, and you're the guest of honor!"])
	await _cin.say("Ranger Finn", ["The forests will miss their favorite visitor. Come back when you want some fun!"])
	if _guide != null:
		_guide.set("force_talk", true)
		await _cin.say("Centorea", ["I knew you could do it!", "If you'll have me, I'll stay on the farm and keep guiding you. Every season."])
		_guide.set("force_talk", false)
	await _cin.say("Mayor Harold", ["Nature Spirit has a new family member. Now, shall we celebrate?"])
	_cam_to(14.0, Vector3(0, 2.0, 0.8), 3.0)
	await _cin.wait(3.5)
	await _finish(["And so, the spirits of nature found a new keeper.", "GOOD ENDING"])


# ------------------------------------------------------------------ BAD ENDING
func _bad() -> void:
	_mayor.set("force_talk", true)
	await _cin.say("Mayor Harold", [
		"Good morning, farmer. The thirty days are over.",
		"I've counted everything you own. It came to %s coins." % _fmt(GameState.coins),
	])
	Sfx.play("ending_bad", -3.0)
	await _cin.say("Mayor Harold", [
		"The goal was 1.000.000. You were %s coins short." % _fmt(maxi(GameState.GOAL_COINS - GameState.coins, 0)),
		"I wish the rules were different. But a promise is a promise, even for a mayor.",
	])
	_mayor.set("force_talk", false)
	if _guide != null:
		_guide.set("force_talk", true)
		await _cin.say("Centorea", ["Mayor, wait! Look at what they built here. Look at those fields!"])
		_guide.set("force_talk", false)
	_mayor.set("force_talk", true)
	await _cin.say("Mayor Harold", [
		"I saw, Centorea. The whole village did. That is why I came myself, and not a letter.",
		"Please take your things. And know this: the road to Nature Spirit will always be open for you.",
	])
	_mayor.set("force_talk", false)
	# beberapa warga datang melepas
	var fids := ["martha", "gordon", "lily", "finn"]
	var fspots := _stand_spots(fids.size(), [MAYOR_SPOT, GUIDE_SPOT, Vector3(-9.0, GY, -0.6)])
	for i in fids.size():
		var n := _spawn(String(fids[i]), GATE + Vector3(randf_range(-1, 1), 0, 0), 3.4)
		n.call("walk_along", _lane_to(fspots[i] if i < fspots.size() else MAYOR_SPOT + Vector3(0, 0, -1.6)))
		_crowd[fids[i]] = n
		await get_tree().create_timer(0.5).timeout
	for id in _crowd:
		await _wait_walk(_crowd[id], 12.0)
		_crowd[id].call("look_at_point", _player.global_position)
	await _cin.say("Martha", ["Take care of yourself, dear. Eat well, sleep well."])
	await _cin.say("Gordon", ["...Don't let the road swallow you. You've got a good arm."])
	await _cin.say("Lily", ["I packed some bread for the journey. Come back and tell me everything, okay?"])
	# player pergi
	_cam_to(14.0, Vector3(0, 1.5, 3.0), 2.5)
	await _cin.wait(1.0)
	_player.call("auto_walk", Vector3(LANE_X, GY, LANE_Z), 1.8)
	await _wait_player()
	_player.call("auto_walk", Vector3(-0.5, GY, 19.5), 1.8)
	for id in _crowd:
		_crowd[id].call("look_at_point", Vector3(-0.5, GY, 19.5))
	if _guide != null:
		_guide.call("look_at_point", Vector3(-0.5, GY, 19.5))
		_guide.set("force_talk", true)                                    # melambai
	var t := 0.0
	while _player.call("is_auto_walking") and t < 16.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	await _cin.wait(1.0)
	await _finish(["Sometimes, the road home is the road ahead.", "BAD ENDING"])


# ------------------------------------------------------------------ penutup
func _finish(lines: Array) -> void:
	await _card([lines[0]], 2.6, 44, true)
	await _card([lines[1]], 2.0, 72, true)
	create_tween().tween_property(_curtain, "modulate:a", 1.0, 1.2)
	await get_tree().create_timer(1.4).timeout
	_cin.abort()                                                     # bar sinematik jangan ikut terbawa ke credits / main menu
	GameState.playing = false
	get_tree().change_scene_to_file(CREDITS)


# ------------------------------------------------------------------ efek
func _confetti() -> void:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.mesh = q
	p.amount = 260
	p.lifetime = 4.5
	p.preprocess = 0.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(7.0, 0.5, 6.0)
	p.direction = Vector3(0, -1, 0)
	p.spread = 20.0
	p.gravity = Vector3(0, -2.2, 0)
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 3.0
	p.angular_velocity_min = -240.0
	p.angular_velocity_max = 240.0
	p.angle_max = 360.0
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.colors = PackedColorArray([Color(1, 0.35, 0.4), Color(1, 0.85, 0.3), Color(0.4, 0.85, 0.5), Color(0.4, 0.7, 1), Color(0.85, 0.5, 1), Color(1, 1, 1)])
	g.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 0.95])
	p.color_initial_ramp = g
	p.position = YARD + Vector3(0, 9.0, 2.0)
	_farm.add_child(p)
	get_tree().create_timer(14.0).timeout.connect(p.queue_free)


func _fireworks() -> void:
	for i in 7:
		get_tree().create_timer(0.4 + i * 0.85).timeout.connect(func() -> void: _burst(i))


func _burst(i: int) -> void:
	var cols := [Color(1, 0.4, 0.4), Color(1, 0.85, 0.3), Color(0.5, 0.9, 0.6), Color(0.5, 0.75, 1), Color(0.9, 0.55, 1)]
	var c: Color = cols[i % cols.size()]
	var p := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.09
	sm.height = 0.18
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	sm.material = m
	p.mesh = sm
	p.amount = 90
	p.lifetime = 1.7
	p.one_shot = true
	p.explosiveness = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.1
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3(0, -3.0, 0)
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 8.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.position = YARD + Vector3(randf_range(-9.0, 7.0), randf_range(8.0, 12.5), randf_range(1.0, 8.0))
	_farm.add_child(p)
	p.emitting = true
	Sfx.play("firework", -4.0, randf_range(0.9, 1.15))
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)


func _rain() -> void:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.55, 0.012)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.75, 0.85, 1.0, 0.45)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.material = m
	p.mesh = bm
	p.amount = 1100
	p.lifetime = 0.9
	p.preprocess = 1.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(16.0, 0.5, 16.0)
	p.direction = Vector3(0.08, -1, 0)
	p.spread = 3.0
	p.gravity = Vector3(0, -6.0, 0)
	p.initial_velocity_min = 16.0
	p.initial_velocity_max = 20.0
	p.position = Vector3(0, 12.0, 0)
	_player.add_child(p)
