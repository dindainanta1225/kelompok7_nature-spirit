extends CanvasLayer
## DevMode - panel tes untuk developer. Tekan F12 (atau tombol ` / ~) untuk buka-tutup.
## Isi: cheat (god mode, energi tak habis, waktu berhenti), waktu & hari, koin, teleport antar area,
## cutscene / ending, item, monster, info debug (FPS, posisi, area). Semua lewat GameState jadi aman dipakai kapan saja.
## Catatan: di build final, matikan dengan mengubah ENABLED menjadi false.

const ENABLED := true
const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"
const AREAS := {
	"Home": ["res://scene/world/home/home.tscn", "from_farm"],
	"Farm": ["res://scene/world/farm/farm.tscn", "from_village"],
	"Village": ["res://scene/world/village/village.tscn", "from_farm"],
	"Forest 1": ["res://scene/world/forest/forest1.tscn", "from_village"],
	"Forest 2": ["res://scene/world/forest/forest2.tscn", "from_forest1"],
}

var _panel: PanelContainer
var _info: Label
var _font: Font
var _open := false
var _show_info := true
var _checks := {}


func _ready() -> void:
	if not ENABLED:
		queue_free()
		return
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	_info = Label.new()
	_info.position = Vector2(10, 8)
	_info.add_theme_font_size_override("font_size", 15)
	_info.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	_info.add_theme_constant_override("outline_size", 5)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info.visible = false
	add_child(_info)
	_build_panel()
	_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not ENABLED:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_F12 or event.keycode == KEY_QUOTELEFT):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	_open = not _open
	_panel.visible = _open
	_info.visible = _open and _show_info
	if _open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_sync_checks()


func _process(_d: float) -> void:
	if not _open or not _show_info:
		return
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	var cs := get_tree().current_scene
	var pos := "-"
	if pl:
		pos = "%.1f, %.1f, %.1f" % [pl.global_position.x, pl.global_position.y, pl.global_position.z]
	_info.text = "[DEV MODE]  FPS %d\nScene: %s\nPlayer: %s\nDay %d  %s  x%.0f%s\nCoins %d   HP %d   Energy %d\nMonsters: %d   NPC: %d" % [
		Engine.get_frames_per_second(), cs.name if cs else "-", pos, GameState.day, GameState.time_text(), GameState.time_scale,
		"  (frozen)" if GameState.time_frozen else "", GameState.coins, int(GameState.hp), int(GameState.energy),
		get_tree().get_nodes_in_group("monster").size(), get_tree().get_nodes_in_group("npc").size()]


# ------------------------------------------------------------------ UI
func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	b.pressed.connect(cb)
	return b


func _check(text: String, prop: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 15)
	c.toggled.connect(func(on: bool) -> void: GameState.set(prop, on); GameState.toast.emit("[dev] %s = %s" % [prop, str(on)]))
	_checks[prop] = c
	return c


func _sync_checks() -> void:
	for p in _checks:
		(_checks[p] as CheckBox).set_pressed_no_signal(bool(GameState.get(p)))


func _section(parent: Control, title: String) -> GridContainer:
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	parent.add_child(l)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	parent.add_child(g)
	return g


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_panel.offset_left = -400.0
	_panel.offset_top = 10.0
	_panel.offset_right = -10.0
	_panel.offset_bottom = 640.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.08, 0.93)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.4, 0.9, 0.5)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(sc)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(370, 0)
	v.add_theme_constant_override("separation", 6)
	sc.add_child(v)
	var t := Label.new()
	t.text = "DEV MODE   (F12 / ` to close)"
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	v.add_child(t)

	var g := _section(v, "Cheats")
	g.add_child(_check("God mode", "god_mode"))
	g.add_child(_check("Infinite energy", "infinite_energy"))
	g.add_child(_check("Freeze time", "time_frozen"))
	var ic := CheckBox.new()
	ic.text = "Debug info"
	ic.button_pressed = true
	ic.focus_mode = Control.FOCUS_NONE
	ic.toggled.connect(func(on: bool) -> void: _show_info = on; _info.visible = _open and on)
	g.add_child(ic)
	g.add_child(_btn("Full energy", func() -> void: GameState.restore_energy(GameState.MAX_ENERGY)))
	g.add_child(_btn("Full HP", func() -> void: GameState.heal_hp(GameState.MAX_HP)))
	g.add_child(_btn("HP -20", func() -> void: GameState.damage_hp(20.0)))
	g.add_child(_btn("Energy 0", func() -> void: GameState._change_energy(-GameState.MAX_ENERGY)))
	g.add_child(_btn("Heal all", func() -> void: GameState.restore_energy(GameState.MAX_ENERGY); GameState.heal_hp(GameState.MAX_HP); GameState.meals_today = 0))

	g = _section(v, "Coins")
	for n in [1000, 10000, 100000]:
		g.add_child(_btn("+%d" % n, func() -> void: GameState.add_coins(n)))
	g.add_child(_btn("Set goal (1M)", func() -> void: GameState.coins = GameState.GOAL_COINS; GameState.coins_changed.emit(GameState.coins)))
	g.add_child(_btn("Just below goal", func() -> void: GameState.coins = GameState.GOAL_COINS - 1000; GameState.coins_changed.emit(GameState.coins)))
	g.add_child(_btn("Set 0", func() -> void: GameState.coins = 0; GameState.coins_changed.emit(0)))

	g = _section(v, "Time")
	for s in [1.0, 5.0, 20.0, 60.0]:
		g.add_child(_btn("Speed x%d" % int(s), func() -> void: GameState.time_scale = s))
	for h in [6, 12, 17, 21, 23]:
		g.add_child(_btn("%02d:00" % h, func() -> void: _set_clock(h)))
	g.add_child(_btn("Next day", func() -> void: _skip_days(1)))
	g.add_child(_btn("Day 30", func() -> void: _goto_day(30)))
	g.add_child(_btn("Day 30 night", func() -> void: _goto_day(30); _set_clock(22)))

	g = _section(v, "Teleport")
	for a in AREAS:
		g.add_child(_btn(a, func() -> void: _teleport(a)))

	g = _section(v, "Cutscenes & Endings")
	g.add_child(_btn("Centorea intro", _replay_intro))
	g.add_child(_btn("Good ending", func() -> void: _force_ending(true)))
	g.add_child(_btn("Bad ending", func() -> void: _force_ending(false)))
	g.add_child(_btn("Credits", func() -> void: close(); get_tree().change_scene_to_file("res://scene/cutscene/ending_credits.tscn")))
	g.add_child(_btn("Story intro", func() -> void: close(); get_tree().change_scene_to_file("res://scene/cutscene/story_intro.gd") if false else _play_story()))

	g = _section(v, "Items & World")
	g.add_child(_btn("Give tools+food", _give_kit))
	g.add_child(_btn("Give seeds x20", _give_seeds))
	g.add_child(_btn("Give drops x10", _give_drops))
	g.add_child(_btn("Grow crops +1d", func() -> void: _grow()))
	g.add_child(_btn("Kill monsters", _kill_monsters))
	g.add_child(_btn("Meet all NPC", func() -> void: _meet_all()))
	g.add_child(_btn("New game", func() -> void: close(); GameState.new_game()))
	g.add_child(_btn("Faint", func() -> void: close(); GameState.faint()))
	g.add_child(_btn("Quit to menu", func() -> void: close(); GameState.quit_to_menu(); get_tree().change_scene_to_file("res://scene/main/mainmenu/main_menu.tscn")))


func close() -> void:
	if _open:
		_toggle()


# ------------------------------------------------------------------ aksi
func _set_clock(h: int) -> void:
	GameState.clock = float(h * 60)
	GameState.time_changed.emit(GameState.hour(), GameState.minute())
	GameState.hour_changed.emit(GameState.hour())


func _skip_days(n: int) -> void:
	GameState.day = mini(GameState.day + n, GameState.LAST_DAY)
	GameState.clock = GameState.DAY_START
	GameState.day_changed.emit(GameState.day)
	GameState.day_started.emit(GameState.day)
	GameState.time_changed.emit(GameState.hour(), GameState.minute())
	GameState.toast.emit("[dev] Day %d" % GameState.day)


func _goto_day(d: int) -> void:
	GameState.day = d
	GameState.day_changed.emit(d)
	GameState.day_started.emit(d)
	GameState.toast.emit("[dev] Day %d" % d)


func _teleport(area: String) -> void:
	var a: Array = AREAS[area]
	if not GameState.playing:
		GameState.new_game()
	close()
	GameState.cutscene = false
	GameState.change_area(a[0], a[1])


func _replay_intro() -> void:
	close()
	GameState.guide_met = false
	GameState.cutscene = false
	GameState.ending_kind = ""
	GameState.change_area("res://scene/world/farm/farm.tscn", "from_village")
	toast_later("Centorea intro will play on arrival")


func toast_later(t: String) -> void:
	GameState.toast.emit("[dev] " + t)


## Langsung ke ending: atur koin supaya sesuai, hari ke-31, lalu jalankan _end_game().
func _force_ending(good: bool) -> void:
	close()
	if not GameState.playing:
		GameState.new_game()
	GameState.cutscene = false
	GameState.transitioning = false
	GameState.day = GameState.LAST_DAY + 1
	GameState.coins = GameState.GOAL_COINS + 50000 if good else 123456
	GameState.coins_changed.emit(GameState.coins)
	GameState._end_game()


func _play_story() -> void:
	var p := "res://scene/cutscene/story_intro.tscn"
	if ResourceLoader.exists(p):
		get_tree().change_scene_to_file(p)
	else:
		toast_later("Story intro scene not found (it is created from code by the main menu)")


func _give_kit() -> void:
	for id in ["hoe", "watering_can", "scythe", "sword"]:
		if not GameState.inventory.has(id):
			GameState.inventory.add(id, 1)
	for id in ["apple", "bread", "grilled_fish", "meat_stew", "royal_feast"]:
		GameState.inventory.add(id, 5)
	toast_later("tools & food added")


func _give_seeds() -> void:
	for c in GameState.inventory.CROPS:
		GameState.inventory.add(String(c[0]) + "_seed", 20)
	toast_later("seeds x20")


func _give_drops() -> void:
	for id in ["imp_horn", "bear_claw", "werewolf_fur", "skeleton_bone", "goblin_tooth", "hunter_badge", "gold_nugget", "forest_herb"]:
		GameState.inventory.add(id, 10)
	toast_later("drops x10")


func _grow() -> void:
	for area in GameState.farm:
		for cell in (GameState.farm[area] as Dictionary).values():
			if cell["crop"] != "":
				cell["age"] += 1
	GameState.crops_changed.emit()
	toast_later("crops +1 day")


func _kill_monsters() -> void:
	var n := 0
	for m in get_tree().get_nodes_in_group("monster"):
		if m.has_method("take_hit"):
			m.call("take_hit", 99999, Vector3.FORWARD)
			n += 1
	toast_later("%d monsters defeated" % n)


func _meet_all() -> void:
	for id in preload("res://scripts/managers/quest_data.gd").NPCS:
		GameState.meet_npc(id)
	toast_later("all NPCs met")
