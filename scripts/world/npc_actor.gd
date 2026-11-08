extends "res://scripts/map/interactable.gd"
const Sfx := preload("res://scripts/audio/sfx.gd")
## NPCActor - penduduk desa. Dekati lalu tekan E:
##   - NPC "dikenali" (GameState.meet_npc) -> isi quest-nya terbuka di kalender
##   - Kalau ada quest dari NPC ini: dialog permintaan, atau serah-terima barang + hadiah
##   - Kalau punya toko (shop_id): setelah dialog, toko terbuka
## Tanda "!" emas di atas kepala = ada quest yang bisa dikerjakan.

const QuestData := preload("res://scripts/managers/quest_data.gd")
const CharacterScript := preload("res://scripts/characters/character_female.gd")
const GuideTalk := preload("res://scripts/world/guide_talk.gd")
const NpcModels := preload("res://scripts/characters/npc_models.gd")
const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"

var npc_id := ""
var display_name := "Villager"
var shop_id := ""
var greetings: Array = ["Hello there!"]
var all_lines := false               # true: semua kalimat greetings ditampilkan sekaligus (pemandu), bukan satu per percakapan
var look := {}                       # warna: skin, hair, outfit (rok), top (blus), ribbon, scale, yaw (derajat)

var guide := false                   # true: bicara -> menu tanya-jawab Centorea (GuideTalk.open)
var force_talk := false              # animasi bicara dipaksa (cutscene)
var spot_name := ""                  # nama tempat NPC hari ini (dipakai peta)
var _char: Node3D
var _anim: RefCounted
var _h := 1.75
var _marker: Label3D
var _tag: Label3D                    # nama NPC: hanya tampil saat player cukup dekat untuk berinteraksi
var _yaw := 0.0
var _t := 0.0
var _talk_index := 0
var wander_center := Vector3.ZERO    # kalau wander_radius > 0, NPC jalan-jalan kecil di sekitar titik ini (pengunjung farm/hutan)
var wander_radius := 0.0
var walk_speed := 1.7
var _path: Array = []
var _on_arrive := Callable()
var _face := 0.0
var _moving := false
var _wander_wait := 2.0
var _chatting := false               # sedang bicara dengan player lewat dialog (animasi bicara)


func _ready() -> void:
	add_to_group("npc")
	prompt = "Talk to %s" % display_name
	mode = Mode.PRESS
	arm_delay = 0.0
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 2.0
	sh.height = 3.0
	cs.shape = sh
	cs.position = Vector3(0, 1.5, 0)
	add_child(cs)
	_build_visual()
	super._ready()
	GameState.day_changed.connect(func(_d: int) -> void: _update_marker())
	GameState.npc_met.connect(func(_i: String) -> void: _update_marker())
	_update_marker()


func _build_visual() -> void:
	var sc: float = look.get("scale", 1.0)
	var m := {}
	if look.has("model"):
		m = NpcModels.build(String(look["model"]))
	if not m.is_empty():
		_char = m["node"]
		_anim = m["anim"]
		_h = float(m["height"])
		sc = 1.0
	else:
		_char = CharacterScript.new()
		_char.skin_color = look.get("skin", Color("fbd5b5"))
		var hair: Color = look.get("hair", Color("3a2a22"))
		_char.hair_color = hair
		_char.streak_color = hair.lightened(0.12)
		_char.streak2_color = hair.lightened(0.12)
		_char.dress_color = look.get("outfit", Color("4a6a9a"))
		_char.apron_color = look.get("top", Color("f2ead8"))
		_char.ribbon_color = look.get("ribbon", Color("d9a441"))
		_char.eye_color = look.get("eye", Color("5a7a4a"))
		_char.scale = Vector3.ONE * sc
		_h = 1.75 * sc
	_yaw = deg_to_rad(float(look.get("yaw", 0.0)))
	_face = _yaw
	_char.rotation.y = _yaw
	add_child(_char)
	var tag := Label3D.new()
	tag.text = display_name
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.fixed_size = false
	tag.pixel_size = 0.006
	tag.font_size = 44
	tag.outline_size = 14
	tag.modulate = Color(1.0, 0.96, 0.82)
	tag.outline_modulate = Color(0.12, 0.06, 0.03)
	tag.position = Vector3(0, _h + 0.1, 0)
	if ResourceLoader.exists(FONT_PATH):
		tag.font = load(FONT_PATH)
	tag.visible = false
	_tag = tag
	add_child(tag)
	_add_solid()
	_marker = Label3D.new()
	_marker.text = "!"
	_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker.no_depth_test = true
	_marker.pixel_size = 0.01
	_marker.font_size = 64
	_marker.outline_size = 16
	_marker.modulate = Color(1.0, 0.84, 0.30)
	_marker.outline_modulate = Color(0.25, 0.12, 0.03)
	_marker.position = Vector3(0, _h + 0.55, 0)
	if ResourceLoader.exists(FONT_PATH):
		_marker.font = load(FONT_PATH)
	_marker.visible = false
	add_child(_marker)


## Jalan lewat titik-titik (x,z) satu per satu; `then` dipanggil setelah sampai di titik terakhir.
func walk_along(points: Array, then := Callable()) -> void:
	_path = points.duplicate()
	_on_arrive = then


## Hadapkan NPC ke titik dunia (cutscene).
func look_at_point(p: Vector3) -> void:
	_face = atan2(p.x - global_position.x, p.z - global_position.z)


func is_walking() -> bool:
	return not _path.is_empty()


## Badan padat supaya player tidak bisa menembus NPC.
func _add_solid() -> void:
	var b := AnimatableBody3D.new()
	b.sync_to_physics = false
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.42
	sh.height = maxf(_h, 1.2)
	cs.shape = sh
	cs.position = Vector3(0, sh.height * 0.5, 0)
	b.add_child(cs)
	add_child(b)


func _process(delta: float) -> void:
	_t += delta
	if _tag != null:
		var show := _player_inside != null or _chatting
		if _tag.visible != show:
			_tag.visible = show
	if _marker and _marker.visible:
		_marker.position.y = _h + 0.55 + sin(_t * 4.0) * 0.08
	var moving := false
	# NPC tidak berhenti / menoleh saat player mendekat: yang sedang jalan terus jalan, yang diam tetap diam.
	if _path.is_empty() and wander_radius > 0.0:
		_wander_wait -= delta
		if _wander_wait <= 0.0:
			_wander_wait = randf_range(3.0, 8.0)
			var a := randf() * TAU
			_path = [Vector3(wander_center.x + cos(a) * randf() * wander_radius, position.y, wander_center.z + sin(a) * randf() * wander_radius)]
	if not _path.is_empty():
		var tgt: Vector3 = _path[0]
		var dv := Vector3(tgt.x - position.x, 0.0, tgt.z - position.z)
		if dv.length() < 0.12:
			_path.pop_front()
			if _path.is_empty() and _on_arrive.is_valid():
				var cb := _on_arrive
				_on_arrive = Callable()
				cb.call()
		else:
			position += dv.normalized() * minf(walk_speed * delta, dv.length())
			_face = atan2(dv.x, dv.z)
			moving = true
	if moving != _moving:
		_moving = moving
		if _char and _char.has_method("play_anim"):
			_char.play_anim("walk" if moving else "idle")
	var target := _face
	if _chatting and not moving and _player_inside != null:      # hanya menoleh ke player kalau memang sedang diajak bicara dan sedang diam
		var d: Vector3 = _player_inside.global_position - global_position
		target = atan2(d.x, d.z)
	if _char:
		_char.rotation.y = lerp_angle(_char.rotation.y, target, 1.0 - exp(-8.0 * delta))
	if _anim:
		_anim.update({"speed": 1.0 if moving else 0.0, "windup": -1.0, "lunge": 0.0, "hit": 0.0, "talk": 1.0 if (_chatting or force_talk) else 0.0, "t": _t, "delta": delta})


func _update_marker() -> void:
	if _marker == null:
		return
	var q := QuestData.active_for(npc_id, GameState.day, GameState.quests_done)
	_marker.visible = not q.is_empty() and GameState.playing


const REPLIES := ["I see. Thanks for telling me!", "Sounds good. See you around!", "Hehe, I'll keep that in mind.", "Interesting! Take care now.", "Thanks! I'll be on my way."]


func _player_reply(is_shop: bool, q: Dictionary) -> String:
	if is_shop:
		return "Let me take a look at your goods."
	if not q.is_empty() and String(q["item"]) != "":
		return "Alright, leave it to me!"
	return REPLIES[randi() % REPLIES.size()]


func _on_interact(_player: Node3D) -> void:
	Sfx.play("npc_hi", -4.0, randf_range(0.9, 1.3))
	GameState.meet_npc(npc_id)
	var freeze := shop_id != ""                          # hanya penjual yang membuat dunia berhenti; yang lain tetap jalan & waktu terus berjalan
	if guide:
		GuideTalk.open(true)
		return
	_chatting = true
	var lines: Array = []
	var q := QuestData.active_for(npc_id, GameState.day, GameState.quests_done)
	if q.is_empty():
		if all_lines:
			lines.append_array(greetings)
		else:
			lines.append(greetings[_talk_index % greetings.size()])
			_talk_index += 1
	elif String(q["item"]) == "":
		lines.append(q["ask"])
		if q["id"] != "final":
			GameState.quests_done[q["id"]] = true          # quest cerita selesai setelah dibaca
	else:
		var inv = GameState.inventory
		var item: String = q["item"]
		var need: int = q["n"]
		if inv.count(item) >= need:
			inv.remove(item, need)
			GameState.add_coins(int(q["coins"]))
			var extra := []
			for rid in q["rewards"]:
				var n: int = q["rewards"][rid]
				if inv.add(rid, n) > 0:
					GameState.toast.emit("Your bag is full!")
				extra.append("%d %s" % [n, QuestData.items_name(rid)])
			GameState.quests_done[q["id"]] = true
			Sfx.play("quest")
			lines.append(q["done_line"])
			lines.append("(Reward: %s coins%s)" % [_fmt(int(q["coins"])), "" if extra.is_empty() else " + " + ", ".join(extra)])
		else:
			lines.append(q["ask"])
			lines.append("(Bring %d %s by day %d. You have %d.)" % [need, QuestData.items_name(item), int(q["due"]), inv.count(item)])
	_update_marker()
	var sid := shop_id
	lines.append("> " + _player_reply(sid != "", q))        # jawaban player muncul di kotak kanan (seperti VN)
	HUD.say(display_name, lines, func() -> void:
		_chatting = false
		if sid != "":
			HUD.open_shop(sid), freeze)


static func _fmt(n: int) -> String:
	return HUD.fmt(n)
