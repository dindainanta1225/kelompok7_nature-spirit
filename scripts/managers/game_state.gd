extends Node
## GameState (AUTOLOAD) - inti aturan game: waktu, hari, energi, koin, tidur, pingsan, ending.
##
## PASANG: Project > Project Settings > Globals (Autoload) > tambah script ini dengan
## nama "GameState". Urutan: GameState dulu, baru HUD.
##
## CARA PAKAI DARI SCRIPT LAIN:
##   GameState.new_game()                      # panggil saat tombol Start ditekan
##   if GameState.spend_energy(GameState.COST_HOE): ...   # aksi alat; false = tak bisa
##   GameState.damage_energy(12)               # kena serangan monster
##   GameState.try_sleep()                     # dipanggil saat interaksi dengan kasur
##   GameState.try_eat(22.0)                   # makan; false kalau sudah 3x hari ini
##   GameState.add_coins(1800) / spend_coins(600)
##   GameState.day_started.connect(...)        # tumbuhkan tanaman, respawn monster
##   GameState.input_locked                    # true saat transisi tidur: player jangan bergerak
##
## Tombol debug (hanya saat dijalankan dari editor):
##   F1 waktu x10 | F2 +50.000 koin | F3 energi penuh | F4 lompat ke 21:00
##   F5 lompat ke 23:50 | F6 lompat ke hari 30 | F7 koin jadi 1.000.000 | F8 mulai game baru

signal playing_changed(on: bool)
signal time_changed(hour: int, minute: int)
signal hour_changed(hour: int)
signal day_changed(day: int)
signal day_started(day: int)               # setelah bangun tidur / pingsan (tanaman tumbuh di sini)
signal energy_changed(energy: float, max_energy: float)
signal hp_changed(hp: float, max_hp: float)
signal coins_changed(coins: int)
signal overtime_started
signal toast(text: String)
signal transition_started
signal transition_finished
signal game_ended(good: bool)
signal npc_met(id: String)
signal crops_changed                     # tanaman tumbuh / berubah (ladang menggambar ulang)

# --- aturan (sesuai dokumen desain) ---
const Sfx := preload("res://scripts/audio/sfx.gd")
const DevMode := preload("res://scripts/ui/dev_mode.gd")
const InventoryData := preload("res://scripts/managers/inventory.gd")
const DayTransition := preload("res://scripts/ui/day_transition.gd")
const FarmLayout := preload("res://scripts/farm/farm_layout.gd")

const GOAL_COINS := 1_000_000
const LAST_DAY := 30
const START_COINS := 10_000
const AppSettings := preload("res://scripts/ui/app_settings.gd")
# Kecepatan waktu diatur di Settings: Slow 1 / Normal 2 / Fast 3 menit game per detik nyata (AppSettings)
const MAX_ENERGY := 100.0
const MAX_HP := 100.0
const HEAL_PER_ENERGY := 0.5                # makanan memulihkan HP setengah dari energinya
const STARVE_HP_PER_MIN := 0.08            # energi habis -> HP berkurang pelan (per menit game)
const DAY_START := 360.0                   # 06:00 (menit sejak 00:00 hari itu)
const SLEEP_OPEN := 1260.0                 # 21:00, kasur baru bisa dipakai
const MIDNIGHT := 1440.0                   # 24:00
const FORCED_FAINT := 1800.0               # 06:00 pagi berikutnya (belum tidur -> pingsan)
const LATE_WAKE := 600.0                   # bangun jam 10:00
const OVERTIME_COST_MULT := 1.5
const OVERTIME_DRAIN_PER_MIN := 1.0 / 24.0 # lembur: energi menyusut pelan
const LATE_SLEEP_ENERGY := 70.0
const FAINT_ENERGY := 50.0
const FAINT_COIN_LOSS := 0.25
const MAX_MEALS_PER_DAY := 3

# biaya energi per aksi (dasar, sebelum pengali lembur)
const COST_HOE := 1.5
const COST_CAN := 1.0
const COST_SCYTHE := 1.0
const COST_SWORD := 2.0

# SESUAIKAN path ini dengan scene-mu (kalau file tidak ada, hanya muncul peringatan)
const SCENE_ENDING_GOOD := "res://scene/cutscene/ending_good/ending_good.tscn"
const SCENE_ENDING_BAD := "res://scene/cutscene/ending_bad/ending_bad.tscn"
const AUTO_START_HINT := "/world/"         # menjalankan scene di folder ini langsung memulai game (debug)
# Scene tempat player bangun setelah tidur/pingsan di luar (scene yang punya spawn "bed",
# biasanya interior rumah player). Contoh: "res://scene/world/farm/player_house.tscn"
const WAKE_SCENE := "res://scene/world/home/home.tscn"

var playing := false
var run_stamp := 0                         # berubah tiap new_game (dipakai penyimpan monster yang sudah dikalahkan)
var day := 1
var clock := DAY_START
var energy := MAX_ENERGY
var hp := MAX_HP
var _warned_empty := false
var coins := START_COINS
var meals_today := 0
var time_scale := 1.0
var transitioning := false
var cutscene := false                      # true saat cutscene berjalan (player & waktu dikunci)
var intro_stage := 0                       # cerita pembuka: 0 = belum, 1 = bagian desa selesai (lanjut tutorial di farm)
var guide_met := false                     # sudah bertemu Centorea (cutscene awal sudah diputar)
var ending_kind := ""                      # "good" / "bad" saat ending sedang diputar
var god_mode := false                      # (dev) tidak kena damage
var infinite_energy := false               # (dev) energi tidak berkurang
var chatting := false                     # true saat ngobrol dengan NPC non-penjual: dunia & waktu tetap jalan, tapi player tidak bisa bergerak/aksi
var time_frozen := false                   # (dev) waktu berhenti
var transition_speed := 1.0                # 1.0 normal; kecilkan untuk tes
var area_changing := false                 # true saat pindah area (layar gelap sebentar)
var next_facing := Vector3.ZERO            # arah hadap player saat pindah area (dipakai lagi di scene tujuan)
var next_yaw := 0.0
var next_spawn := ""                       # nama spawn point yang dituju di scene berikutnya
var input_locked: bool:
	get:
		return transitioning or area_changing or cutscene

var _fade: ColorRect
var _fade_layer: CanvasLayer
var _day_title: Label
var _day_sub: Label
var _day_tr: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AppSettings.load_and_apply(get_tree())
	_build_transition_overlay()
	add_child(Sfx.new())
	add_child(DevMode.new())
	if not InputMap.has_action("interact"):       # tombol E untuk kasur, pintu, toko
		InputMap.add_action("interact")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		InputMap.action_add_event("interact", ev)
	if OS.is_debug_build():
		await get_tree().process_frame
		var cs := get_tree().current_scene
		if cs and AUTO_START_HINT in cs.scene_file_path and not playing:
			new_game()


func _process(delta: float) -> void:
	if not playing or input_locked or get_tree().paused or time_frozen:
		return
	advance_minutes(delta * AppSettings.minutes_per_second() * time_scale)


# ------------------------------------------------------------------ mulai / reset

var inventory = InventoryData.new()      # tas pemain (lihat inventory.gd)

## Data ladang: area (path scene) -> {Vector2i: {"tilled": bool, "crop": String, "age": int, "watered": bool}}
var farm := {}


func farm_cells(area: String) -> Dictionary:
	if not farm.has(area):
		farm[area] = {}
	return farm[area]


## Dipanggil tiap pagi: tanaman yang disiram hari itu tumbuh 1 hari, lalu air mengering.
func _grow_crops() -> void:
	for area in farm:
		for cell in (farm[area] as Dictionary).values():
			if cell["crop"] != "":
				if cell["watered"]:
					cell["age"] += 1
				cell["watered"] = false
	crops_changed.emit()


## NPC yang sudah ditemui (membuka isi quest-nya di kalender).
var met_npcs := {}
var chest = InventoryData.new()               # peti di depan rumah (perlengkapan awal ada di sini)
var quests_done := {}                        # id quest -> true
var tool_levels := {"hoe": 1, "watering_can": 1, "scythe": 1, "sword": 0}   # sword 0 = belum dibeli


func tool_level(id: String) -> int:
	return int(tool_levels.get(id, 1))


func is_quest_done(id: String) -> bool:
	return quests_done.has(id)


func meet_npc(id: String) -> void:
	if met_npcs.has(id):
		return
	met_npcs[id] = true
	npc_met.emit(id)


func has_met(id: String) -> bool:
	return met_npcs.has(id)


func new_game() -> void:
	run_stamp = Time.get_ticks_msec()
	met_npcs.clear()
	quests_done.clear()
	tool_levels = {"hoe": 1, "watering_can": 1, "scythe": 1, "sword": 0}
	inventory.reset()
	chest.reset()
	chest.fill_start_kit()
	farm.clear()
	farm[FarmLayout.AREA] = FarmLayout.generate()      # 2 petak 5x5 + rintangan acak
	day = 1
	AppSettings.applied_speed = -1
	clock = DAY_START
	energy = MAX_ENERGY
	hp = MAX_HP
	coins = START_COINS
	meals_today = 0
	time_scale = 1.0
	transitioning = false
	cutscene = false
	guide_met = false
	intro_stage = 0
	ending_kind = ""
	playing = true
	playing_changed.emit(true)
	day_changed.emit(day)
	coins_changed.emit(coins)
	energy_changed.emit(energy, MAX_ENERGY)
	hp_changed.emit(hp, MAX_HP)
	time_changed.emit(hour(), minute())
	day_started.emit(day)


func quit_to_menu() -> void:
	playing = false
	playing_changed.emit(false)


# ------------------------------------------------------------------ waktu

func hour() -> int:
	return int(clock / 60.0) % 24


func minute() -> int:
	return int(clock) % 60


func time_text() -> String:
	return "%02d:%02d" % [hour(), minute()]


func is_overtime() -> bool:
	return clock >= MIDNIGHT


func can_sleep() -> bool:
	return clock >= SLEEP_OPEN


func advance_minutes(m: float) -> void:
	if not playing or transitioning:
		return
	var prev_hour := hour()
	var prev_minute := minute()
	var was_overtime := is_overtime()
	clock += m
	if is_overtime():
		if not was_overtime:
			overtime_started.emit()
			toast.emit("It's past midnight. Go to sleep!")
		var over := minf(m, clock - MIDNIGHT)
		_change_energy(-over * OVERTIME_DRAIN_PER_MIN)
	if energy <= 0.0 and playing and not transitioning and not infinite_energy:
		_change_hp(-m * STARVE_HP_PER_MIN)       # kelelahan: HP terkuras pelan-pelan
	if hour() != prev_hour:
		hour_changed.emit(hour())
		if is_overtime() and was_overtime and hour() >= 1 and hour() < 6:
			toast.emit("It's %02d:00. Go to bed, or you'll pass out at 06:00!" % hour())
	if minute() != prev_minute or hour() != prev_hour:
		time_changed.emit(hour(), minute())
	if clock >= FORCED_FAINT and not transitioning:
		toast.emit("You stayed up all night...")
		faint()


# ------------------------------------------------------------------ energi

func spend_energy(base_cost: float) -> bool:
	if not playing or transitioning or energy <= 0.0:
		return false
	var cost := base_cost * (OVERTIME_COST_MULT if is_overtime() else 1.0)
	if not infinite_energy:
		_change_energy(-cost)
	return true


## Kena serangan: HP yang berkurang (bukan energi). Nama lama dipertahankan supaya monster.gd tak perlu diubah.
func damage_energy(amount: float) -> void:
	damage_hp(amount)


func damage_hp(amount: float) -> void:
	if playing and not transitioning and not god_mode:
		_change_hp(-amount)
		Sfx.play("player_hurt", -2.0)


func heal_hp(amount: float) -> void:
	if amount > 0.0:
		_change_hp(amount)


func _change_hp(delta: float) -> void:
	hp = clampf(hp + delta, 0.0, MAX_HP)
	hp_changed.emit(hp, MAX_HP)
	if hp <= 0.0 and playing and not transitioning:
		toast.emit("You collapsed...")
		faint()


func try_eat(energy_gain: float) -> bool:
	if not playing or transitioning:
		return false
	if meals_today >= MAX_MEALS_PER_DAY:
		toast.emit("I can't eat any more today.")
		Sfx.play("error")
		return false
	meals_today += 1
	_change_energy(energy_gain)
	heal_hp(energy_gain * HEAL_PER_ENERGY)
	return true


func restore_energy(amount: float) -> void:
	_change_energy(amount)                    # untuk item seperti Forest Herb (tak dihitung makan)
	if amount > 0.0:
		heal_hp(amount * HEAL_PER_ENERGY)


func _change_energy(delta: float) -> void:
	energy = clampf(energy + delta, 0.0, MAX_ENERGY)
	energy_changed.emit(energy, MAX_ENERGY)
	if energy <= 0.0 and playing and not transitioning and not _warned_empty:
		_warned_empty = true
		toast.emit("You're exhausted! Eat something or your health will drain.")
	elif energy > 0.0:
		_warned_empty = false


# ------------------------------------------------------------------ koin

func add_coins(amount: int) -> void:
	if amount > 0:
		Sfx.play("coin" if amount < 300 else "coins_big", -4.0)
	coins += amount
	coins_changed.emit(coins)


func spend_coins(amount: int) -> bool:
	if coins < amount:
		toast.emit("Not enough coins.")
		Sfx.play("error")
		return false
	Sfx.play("buy", -3.0)
	coins -= amount
	coins_changed.emit(coins)
	return true


# ------------------------------------------------------------------ tidur / pingsan

func try_sleep() -> bool:
	if not playing or transitioning:
		return false
	if not can_sleep():
		toast.emit("I'm not sleepy yet. (after 21:00)")
		return false
	Sfx.play("bed")
	if is_overtime():
		_begin_transition("sleep_late")
	else:
		_begin_transition("sleep_early")
	return true


func faint() -> void:
	if not playing or transitioning:
		return
	_begin_transition("faint")


func _begin_transition(kind: String) -> void:
	transitioning = true
	transition_started.emit()
	var k := transition_speed
	if _day_tr == null:
		_day_tr = DayTransition.new()
		add_child(_day_tr)
	var pl := get_tree().get_first_node_in_group("player")
	if kind == "faint" and pl != null and pl.has_method("play_faint"):
		pl.play_faint()                                   # roboh sambil layar menyempit
	await _day_tr.cover(kind, k)

	var info := _apply_wake(kind)
	pl = get_tree().get_first_node_in_group("player")
	if pl != null and pl.has_method("stand_up"):
		pl.stand_up()
	var title := "Day %d" % mini(day, LAST_DAY) if day <= LAST_DAY else "The 31st morning..."
	await _day_tr.reveal(kind, title, info, k)

	if day > LAST_DAY:
		_end_game()
	await _day_tr.uncover(k)
	transitioning = false
	transition_finished.emit()


func _apply_wake(kind: String) -> String:
	var info := ""
	match kind:
		"sleep_early":
			clock = DAY_START
			energy = MAX_ENERGY
			hp = MAX_HP
			info = "You slept well."
		"sleep_late":
			clock = LATE_WAKE
			energy = LATE_SLEEP_ENERGY
			hp = minf(MAX_HP, hp + 50.0)
			info = "You slept in..."
		_:
			clock = LATE_WAKE
			energy = FAINT_ENERGY
			hp = maxf(hp, 40.0)
			var fee := int(coins * FAINT_COIN_LOSS)
			coins -= fee
			coins_changed.emit(coins)
			info = "You passed out. Medical fee: %d coins" % fee
	day += 1
	AppSettings.applied_speed = -1                  # pilihan kecepatan waktu baru mulai berlaku hari ini
	meals_today = 0
	_grow_crops()
	day_changed.emit(day)
	energy_changed.emit(energy, MAX_ENERGY)
	hp_changed.emit(hp, MAX_HP)
	time_changed.emit(hour(), minute())
	if day <= LAST_DAY:
		day_started.emit(day)
		_relocate_to_bed()
	return info


## Pindahkan player ke kasur: langsung kalau scene sekarang punya spawn "bed",
## kalau tidak (misal pingsan di hutan) pindah ke WAKE_SCENE.
func _relocate_to_bed() -> void:
	next_spawn = "bed"
	var cs := get_tree().current_scene
	if cs and cs.has_method("place_player") and cs.place_player("bed"):
		next_spawn = ""
		return
	if WAKE_SCENE != "" and ResourceLoader.exists(WAKE_SCENE):
		get_tree().change_scene_to_file(WAKE_SCENE)
	else:
		push_warning("Tidak ada spawn 'bed' di scene ini dan WAKE_SCENE belum diatur di game_state.gd")


# ------------------------------------------------------------------ pindah area

## Pindah ke scene lain dengan fade singkat. spawn_name = nama Marker3D tujuan di scene baru.
func change_area(scene_path: String, spawn_name: String) -> void:
	if area_changing or transitioning or not playing:
		return
	if not ResourceLoader.exists(scene_path):
		push_warning("Scene tujuan tidak ditemukan: %s" % scene_path)
		return
	area_changing = true
	var pl0 := get_tree().get_first_node_in_group("player")
	if pl0 != null and pl0.get("facing") != null:
		next_facing = pl0.get("facing")
		var vis0: Node3D = pl0.get("visual")
		next_yaw = vis0.rotation.y if vis0 != null else 0.0
	Sfx.play("door")
	_fade.visible = true
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 1.0, 0.3 * transition_speed)
	await t.finished
	next_spawn = spawn_name
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_fade, "modulate:a", 0.0, 0.3 * transition_speed)
	await t2.finished
	_fade.visible = false
	area_changing = false


func _end_game() -> void:
	var good := coins >= GOAL_COINS
	ending_kind = "good" if good else "bad"
	playing = false
	playing_changed.emit(false)
	game_ended.emit(good)
	cutscene = true
	next_spawn = "from_home"
	# Ending dimainkan di halaman depan rumah player (scene Farm): Mayor datang membawa hasil keputusan.
	var path := FarmLayout.AREA
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		push_warning("Scene Farm tidak ditemukan: %s" % path)


# ------------------------------------------------------------------ overlay transisi

func _build_transition_overlay() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP     # klik tak tembus saat layar gelap
	_fade.modulate.a = 0.0
	_fade.visible = false
	_fade_layer.add_child(_fade)

	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 14)
	_fade.add_child(box)
	_day_title = _overlay_label(72, Color(1.0, 0.85, 0.35))
	_day_sub = _overlay_label(28, Color(0.9, 1.0, 0.92))
	box.add_child(_day_title)
	box.add_child(_day_sub)


func _overlay_label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02))
	l.add_theme_constant_override("outline_size", 10)
	l.modulate.a = 0.0
	return l


# ------------------------------------------------------------------ debug

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	match k.keycode:
		KEY_F1:
			time_scale = 10.0 if time_scale == 1.0 else 1.0
			toast.emit("[debug] time x%d" % int(time_scale))
		KEY_F2:
			add_coins(50_000)
		KEY_F3:
			restore_energy(MAX_ENERGY)
		KEY_F4:
			if clock < SLEEP_OPEN:
				clock = SLEEP_OPEN
				time_changed.emit(hour(), minute())
		KEY_F5:
			clock = 1430.0
			time_changed.emit(hour(), minute())
		KEY_F6:
			day = LAST_DAY
			day_changed.emit(day)
		KEY_F7:
			coins = GOAL_COINS
			coins_changed.emit(coins)
		KEY_F8:
			new_game()
		KEY_F11:                                  # temui semua NPC (tes kalender)
			for n in preload("res://scripts/managers/quest_data.gd").NPCS:
				meet_npc(n)
			toast.emit("[debug] semua NPC ditemui")
		KEY_F10:                                  # semua tanaman langsung tumbuh 1 hari (tes tampilan)
			for area in farm:
				for cell in (farm[area] as Dictionary).values():
					if cell["crop"] != "":
						cell["age"] += 1
			crops_changed.emit()
			toast.emit("[debug] crops +1 day")
