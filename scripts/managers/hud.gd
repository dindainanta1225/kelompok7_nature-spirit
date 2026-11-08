extends CanvasLayer
const Sfx := preload("res://scripts/audio/sfx.gd")
## HUD (AUTOLOAD) - papan kayu bertema hutan: tas (kiri-atas), uang + kartu tanggal + jam (kanan-atas, terpisah),
## energi (kiri-bawah, tanpa angka). Klik kartu tanggal (atau tekan C) = buka kalender quest.
## Dibangun lewat kode dan hanya tampil saat GameState.playing = true.
##
## PASANG: Project Settings > Globals (Autoload) > tambah script ini dengan nama "HUD",
## letakkan SETELAH GameState.
##
## Pesan singkat dari script lain:  HUD.show_toast("Seeds planted!")

# --- warna papan kayu
const WOOD := Color(0.36, 0.22, 0.12, 0.96)
const WOOD_DARK := Color(0.17, 0.09, 0.05)
const WOOD_LIGHT := Color(0.62, 0.42, 0.22)
const CREAM := Color(1.0, 0.94, 0.78)
const GOLD := Color(1.0, 0.84, 0.30)
const GREEN := Color(0.55, 0.85, 0.30)
const AMBER := Color(1.0, 0.72, 0.18)
const RED := Color(1.0, 0.30, 0.25)
const TRACK := Color(0.10, 0.05, 0.03)
const OUTLINE := Color(0.14, 0.07, 0.03)
const WEEKDAYS := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const WoodPanel := preload("res://scripts/managers/wood_panel.gd")
const PAUSE_SCRIPT := "res://scripts/managers/pause_menu.gd"
const INVENTORY_UI_SCRIPT := "res://scripts/managers/inventory_ui.gd"
const CALENDAR_SCRIPT := "res://scripts/managers/calendar_ui.gd"
const SHOP_SCRIPT := "res://scripts/shops/shop_ui.gd"
const DIALOGUE_SCRIPT := "res://scripts/ui/dialogue_box.gd"
const MAP_UI_SCRIPT := "res://scripts/managers/map_ui.gd"
const BGM_SCRIPT := "res://scripts/managers/bgm.gd"
const CHEST_UI_SCRIPT := "res://scripts/managers/chest_ui.gd"
const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"      # font pixel-mu (kosongkan kalau tidak mau)

var _root: Control
var _weekday_label: Label
var _day_label: Label
var _time_label: ClockText
var _phase_label: Label
var _last_phase := ""
var _coin_label: Label
var _calendar: Node
var _shop_ui: Node
var _dialogue: Node
var _was_busy := false
var _chest_ui: Node
var _map_ui: Node
var _inventory_ui: Node
var _card_art: Control
var _energy_panel: Control
var _energy_bar: ProgressBar
var _energy_fill: StyleBoxFlat
var _energy_icon: HudIcon
var _hp_bar: ProgressBar
var _hp_icon: HudIcon
var _toast_panel: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _prompt_key: Label
var _prompt_keycap: Control
var _prompt_owner: Object
var _coin_icon: HudIcon
var _coin_panel: PanelContainer
var _shown_coins := 0
var _coin_tween: Tween
var _t := 0.0
var _font: Font
const PhaseNames := preload("res://scripts/world/day_cycle.gd")


## Jam dengan lebar karakter TETAP: angka berganti tapi posisinya tidak bergeser.
class ClockText extends Control:
	var text := "00:00" :
		set(v):
			text = v
			queue_redraw()
	var color := Color(1.0, 0.94, 0.78) :
		set(v):
			color = v
			queue_redraw()
	var font: Font
	var font_size := 30
	const CELL := 19.0
	const COLON := 11.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(CELL * 4.0 + COLON, 38.0)

	func _draw() -> void:
		var f: Font = font if font else ThemeDB.fallback_font
		var x := 0.0
		for ch in text:
			var w := COLON if ch == ":" else CELL
			var cw := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var pos := Vector2(x + (w - cw) * 0.5, size.y * 0.5 + font_size * 0.36)
			draw_string_outline(f, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 7, Color(0.14, 0.07, 0.03))
			draw_string(f, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
			x += w


## Ikon kecil yang digambar lewat kode (tanpa file gambar).
class HudIcon extends Control:
	var kind := "coin"
	var color := Color.WHITE

	func _init(k: String = "coin", min_size: float = 28.0) -> void:
		kind = k
		custom_minimum_size = Vector2(min_size, min_size)
		pivot_offset = Vector2(min_size, min_size) * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		resized.connect(queue_redraw)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.0
		match kind:
			"coin":
				draw_circle(c, r, Color(0.40, 0.24, 0.04))
				draw_circle(c, r - 2.0, Color(1.0, 0.82, 0.25))
				draw_circle(c, r - 5.0, Color(0.93, 0.66, 0.12))
				draw_arc(c, r - 3.5, deg_to_rad(200), deg_to_rad(290), 10, Color(1.0, 0.96, 0.7), 2.0)
			"bolt":
				var pts := PackedVector2Array()
				for p in [Vector2(0.60, 0.02), Vector2(0.16, 0.56), Vector2(0.45, 0.56), Vector2(0.36, 0.98), Vector2(0.84, 0.40), Vector2(0.55, 0.40)]:
					pts.append(p * size)
				var outline := pts.duplicate()
				outline.append(pts[0])
				draw_colored_polygon(pts, color)
				draw_polyline(outline, Color(0.14, 0.07, 0.03), 2.0, true)
			"backpack":
				var o := Color(0.14, 0.07, 0.03)
				var w := size.x
				var h := size.y
				draw_arc(Vector2(w * 0.5, h * 0.2), w * 0.15, PI, TAU, 12, o, 4.0)
				draw_arc(Vector2(w * 0.5, h * 0.2), w * 0.15, PI, TAU, 12, Color(0.55, 0.36, 0.18), 2.0)
				var body := Rect2(w * 0.14, h * 0.2, w * 0.72, h * 0.74)
				draw_rect(body.grow(2.0), o)
				draw_rect(body, Color(0.30, 0.56, 0.30))
				draw_rect(Rect2(body.position, Vector2(body.size.x, body.size.y * 0.36)), Color(0.42, 0.70, 0.34))
				draw_rect(Rect2(w * 0.43, h * 0.46, w * 0.14, h * 0.12), Color(1.0, 0.84, 0.30))
				draw_rect(Rect2(w * 0.24, h * 0.66, w * 0.52, h * 0.22), Color(0.22, 0.44, 0.24))
				draw_rect(Rect2(w * 0.24, h * 0.66, w * 0.52, h * 0.22), o, false, 1.5)
			"map":
				var o2 := Color(0.14, 0.07, 0.03)
				var w2 := size.x
				var h2 := size.y
				var sheet := PackedVector2Array([Vector2(0.08, 0.20) * size, Vector2(0.36, 0.10) * size, Vector2(0.64, 0.22) * size, Vector2(0.92, 0.12) * size, Vector2(0.92, 0.82) * size, Vector2(0.64, 0.92) * size, Vector2(0.36, 0.80) * size, Vector2(0.08, 0.90) * size])
				draw_colored_polygon(sheet, Color(0.90, 0.82, 0.58))
				var ol := sheet.duplicate()
				ol.append(sheet[0])
				draw_polyline(ol, o2, 2.5, true)
				draw_line(Vector2(0.36, 0.10) * size, Vector2(0.36, 0.80) * size, o2.lightened(0.3), 1.5)
				draw_line(Vector2(0.64, 0.22) * size, Vector2(0.64, 0.92) * size, o2.lightened(0.3), 1.5)
				draw_line(Vector2(0.52, 0.40) * size, Vector2(0.78, 0.66) * size, Color(0.75, 0.15, 0.15), 3.0)
				draw_line(Vector2(0.78, 0.40) * size, Vector2(0.52, 0.66) * size, Color(0.75, 0.15, 0.15), 3.0)
			"heart":
				var hp_pts := PackedVector2Array()
				for i in 40:
					var t := TAU * i / 40.0
					hp_pts.append(c + Vector2(16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * (r / 17.0))
				draw_colored_polygon(hp_pts, color)
				draw_polyline(hp_pts + PackedVector2Array([hp_pts[0]]), Color(0.14, 0.07, 0.03), 2.0, true)
			"clock":
				draw_circle(c, r, Color(0.14, 0.07, 0.03))
				draw_circle(c, r - 2.0, color)
				draw_line(c, c + Vector2(0, -r * 0.55), Color(0.14, 0.07, 0.03), 2.0)
				draw_line(c, c + Vector2(r * 0.4, r * 0.2), Color(0.14, 0.07, 0.03), 2.0)


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	if FONT_PATH != "" and ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	_build()
	visible = false
	if ResourceLoader.exists(PAUSE_SCRIPT):
		get_tree().root.add_child.call_deferred(load(PAUSE_SCRIPT).new())     # menu Esc
	if ResourceLoader.exists(INVENTORY_UI_SCRIPT):
		_inventory_ui = load(INVENTORY_UI_SCRIPT).new()
		get_tree().root.add_child.call_deferred(_inventory_ui)   # hotbar + tas (I / Tab / B)
	if ResourceLoader.exists(CALENDAR_SCRIPT):
		_calendar = load(CALENDAR_SCRIPT).new()
		get_tree().root.add_child.call_deferred(_calendar)       # kalender (C / klik tanggal)
	if ResourceLoader.exists(SHOP_SCRIPT):
		_shop_ui = load(SHOP_SCRIPT).new()
		get_tree().root.add_child.call_deferred(_shop_ui)        # jendela toko
	if ResourceLoader.exists(CHEST_UI_SCRIPT):
		_chest_ui = load(CHEST_UI_SCRIPT).new()
		get_tree().root.add_child.call_deferred(_chest_ui)       # jendela peti
	if ResourceLoader.exists(MAP_UI_SCRIPT):
		_map_ui = load(MAP_UI_SCRIPT).new()
		get_tree().root.add_child.call_deferred(_map_ui)         # peta (M)
	if ResourceLoader.exists(DIALOGUE_SCRIPT):
		_dialogue = load(DIALOGUE_SCRIPT).new()
		get_tree().root.add_child.call_deferred(_dialogue)       # dialog NPC
	if ResourceLoader.exists(BGM_SCRIPT):
		add_child(load(BGM_SCRIPT).new())                        # musik latar "Nature-Spirit Soundtrack" (loop)
	GameState.playing_changed.connect(_on_playing_changed)
	GameState.coins_changed.connect(_on_coins_changed)
	GameState.energy_changed.connect(_on_energy_changed)
	GameState.hp_changed.connect(_on_hp_changed)
	GameState.day_changed.connect(_on_day_changed)
	GameState.toast.connect(show_toast)
	_shown_coins = GameState.coins
	_refresh_all()


func _process(delta: float) -> void:
	_sync_chat_hud()
	var busy := ui_busy()
	if busy != _was_busy:
		_was_busy = busy
		Sfx.play("open" if busy else "close", -6.0)
	if not visible:
		return
	_t += delta
	var txt := GameState.time_text()
	if _time_label.text != txt:
		_time_label.text = txt
	_update_phase()
	# warna jam tetap krem (peringatan lembur lewat toast, bukan warna)
	var col := CREAM
	_time_label.color = col
	# energi berkedip saat hampir habis
	if GameState.energy < 20.0:
		var k := 0.5 + 0.5 * sin(_t * 8.0)
		_energy_bar.self_modulate = Color.WHITE.lerp(Color(1.4, 0.6, 0.6), k)
		_energy_icon.scale = Vector2.ONE * (1.0 + 0.12 * k)
	else:
		_energy_bar.self_modulate = Color.WHITE
		_energy_icon.scale = Vector2.ONE


# ------------------------------------------------------------------ sinkron

## Saat dialog terbuka, bar energi & hotbar disembunyikan supaya kotak chat lega.
func _sync_chat_hud() -> void:
	var chat: bool = _dialogue != null and _dialogue.has_method("is_open") and _dialogue.is_open()
	if _energy_panel != null and _energy_panel.visible == chat:
		_energy_panel.visible = not chat
	if _inventory_ui != null:
		var hw = _inventory_ui.get("_hotbar_wrap")
		if hw != null and (hw as Control).visible == chat:
			(hw as Control).visible = not chat

const PHASE_COLOR := {"Morning": Color(1.0, 0.92, 0.55), "Noon": Color(1.0, 0.98, 0.85), "Evening": Color(1.0, 0.68, 0.38), "Night": Color(0.62, 0.74, 1.0)}
const PHASE_TOAST := {"Morning": "Good morning! A new day begins.", "Noon": "It's noon. The sun is at its highest.",
	"Evening": "Evening is here. The villagers will head home at 19:00.", "Night": "Night has fallen. The villagers went home - don't forget to sleep!"}


func _update_phase() -> void:
	var ph := PhaseNames.phase_name(GameState.hour())
	if _phase_label.text != ph:
		_phase_label.text = ph
		_phase_label.add_theme_color_override("font_color", PHASE_COLOR.get(ph, CREAM))
		if _last_phase != "" and GameState.playing:
			GameState.toast.emit(PHASE_TOAST.get(ph, ""))
		_last_phase = ph


func _refresh_all() -> void:
	_on_day_changed(GameState.day)
	_on_energy_changed(GameState.energy, GameState.MAX_ENERGY)
	_on_hp_changed(GameState.hp, GameState.MAX_HP)
	_shown_coins = GameState.coins
	_set_coin_text(float(_shown_coins))
	_time_label.text = GameState.time_text()


func _on_playing_changed(on: bool) -> void:
	visible = on
	if on:
		_refresh_all()


func _on_day_changed(d: int) -> void:
	var shown := mini(d, GameState.LAST_DAY)
	_day_label.text = str(shown)
	_weekday_label.text = WEEKDAYS[(shown - 1) % 7]


func _on_energy_changed(e: float, m: float) -> void:
	_energy_bar.max_value = m
	_energy_bar.value = e
	var f := e / m
	var col := GREEN
	if f <= 0.25:
		col = RED
	elif f <= 0.5:
		col = AMBER
	_energy_fill.bg_color = col
	_energy_icon.color = col
	_energy_icon.queue_redraw()


func _on_hp_changed(h: float, m: float) -> void:
	_hp_bar.max_value = m
	_hp_bar.value = h


## Dipanggil menu ESC: sembunyikan/tampilkan seluruh HUD (hotbar, energi, HP, dst).
func set_hud_hidden(h: bool) -> void:
	_root.visible = not h


func _on_coins_changed(c: int) -> void:
	var diff := c - _shown_coins
	if _coin_tween and _coin_tween.is_valid():
		_coin_tween.kill()
	if visible and diff != 0:
		_popup(diff)
		_coin_tween = create_tween()
		_coin_tween.tween_method(_set_coin_text, float(_shown_coins), float(c), 0.45)
		var bump := create_tween()
		bump.tween_property(_coin_icon, "scale", Vector2(1.3, 1.3), 0.08)
		bump.tween_property(_coin_icon, "scale", Vector2.ONE, 0.15)
	else:
		_set_coin_text(float(c))
	_shown_coins = c


func _set_coin_text(v: float) -> void:
	_coin_label.text = fmt(int(v))


func _popup(diff: int) -> void:
	var l := _label(24, GREEN if diff > 0 else RED)
	l.text = ("+" if diff > 0 else "-") + fmt(absi(diff))
	l.add_theme_constant_override("outline_size", 8)
	_root.add_child(l)
	# muncul tepat di bawah plank koin
	var base := _coin_panel.get_global_position()
	l.position = Vector2(base.x + _coin_panel.size.x - 150.0, base.y + _coin_panel.size.y + 6.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y + 26.0, 0.9)
	t.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	t.chain().tween_callback(l.queue_free)


## Format angka dengan titik ribuan: 1234567 -> "1.234.567"
static func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if n < 0 else "") + out


# ------------------------------------------------------------------ toko & dialog

## Buka toko: "general", "blacksmith", atau "food".
func open_shop(shop_id: String) -> void:
	if _shop_ui and _shop_ui.has_method("open"):
		_shop_ui.open(shop_id)


## Buka jendela peti (dipanggil Chest).
func open_chest() -> void:
	Sfx.play("chest")
	if _chest_ui and _chest_ui.has_method("open"):
		_chest_ui.open()


## Tampilkan dialog NPC. on_done dipanggil setelah baris terakhir ditutup.
func say(speaker: String, lines: Array, on_done: Callable = Callable(), freeze := true) -> void:
	if _dialogue and _dialogue.has_method("say"):
		_dialogue.say(speaker, lines, on_done, freeze)
	elif on_done.is_valid():
		on_done.call()


## Pertanyaan berpilihan (lihat DialogueBox.ask). on_pick menerima indeks pilihan.
func ask(speaker: String, prompt: String, options: Array, on_pick: Callable, freeze := true) -> void:
	if _dialogue and _dialogue.has_method("ask"):
		_dialogue.ask(speaker, prompt, options, on_pick, freeze)


## true kalau ada jendela (toko / dialog / tas / kalender) yang sedang terbuka.
func ui_busy() -> bool:
	for n in [_shop_ui, _dialogue, _calendar, _inventory_ui, _chest_ui, _map_ui]:
		if n and n.has_method("is_open") and n.is_open():
			return true
	return false


# ------------------------------------------------------------------ toast

func show_toast(text: String) -> void:
	Sfx.play("toast", -8.0)
	_toast_label.text = text
	_toast_panel.visible = true
	await get_tree().process_frame
	_toast_panel.pivot_offset = _toast_panel.size * 0.5
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_panel.modulate.a = 0.0
	_toast_panel.scale = Vector2(0.9, 0.9)
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_property(_toast_panel, "scale", Vector2.ONE, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.chain().tween_interval(2.2)
	_toast_tween.chain().tween_property(_toast_panel, "modulate:a", 0.0, 0.4)
	_toast_tween.chain().tween_callback(func() -> void: _toast_panel.visible = false)


# ------------------------------------------------------------------ petunjuk interaksi

## Tampilkan petunjuk di bawah-tengah, misalnya "[E] Sleep". Dipakai oleh Interactable.
func set_prompt(owner: Object, text: String) -> void:
	_prompt_owner = owner
	var parsed := _parse_prompt(text)
	_prompt_key.text = parsed[0]
	_prompt_keycap.visible = parsed[0] != ""
	var words: PackedStringArray = String(parsed[1]).split(" ", false)
	_prompt_label.text = words[0] if words.size() > 0 else ""      # cukup satu kata: "F Talk", "F Pick"
	_prompt_panel.visible = true


## "[F / Click] Swing sword" -> ["F", "Swing sword"]; "E: Talk" -> ["E", "Talk"]; teks tanpa tombol -> ["", teks].
static func _parse_prompt(text: String) -> Array:
	var t := text.strip_edges()
	if t.begins_with("["):
		var e := t.find("]")
		if e > 0:
			var key := t.substr(1, e - 1).split("/")[0].strip_edges().to_upper()
			return [key, t.substr(e + 1).strip_edges()]
	var c := t.find(":")
	if c > 0 and c <= 6 and not t.substr(0, c).contains(" "):
		return [t.substr(0, c).to_upper(), t.substr(c + 1).strip_edges()]
	return ["", t]


func clear_prompt(owner: Object) -> void:
	if _prompt_owner == owner:
		_prompt_owner = null
		_prompt_panel.visible = false


# ------------------------------------------------------------------ bangun UI

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# ---- kiri-atas: tombol tas (B)
	var bp := _wood(8, true)
	bp.position = Vector2(16, 34)
	_root.add_child(bp)
	var bcol := VBoxContainer.new()
	bcol.add_theme_constant_override("separation", 0)
	bcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bp.add_child(bcol)
	var bicon := HudIcon.new("backpack", 46.0)
	bicon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bcol.add_child(bicon)
	var bkey := _label(15, GOLD)
	bkey.text = "B"
	bkey.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bcol.add_child(bkey)
	_make_button(bp, func() -> void:
		if _inventory_ui and _inventory_ui.has_method("open") and not get_tree().paused:
			_inventory_ui.open())

	# ---- kiri-atas, di samping tas: tombol peta (M)
	var mp := _wood(8, true)
	mp.position = Vector2(16 + 100, 34)
	_root.add_child(mp)
	bp.resized.connect(func() -> void: mp.position = Vector2(bp.position.x + bp.size.x + 10.0, bp.position.y))
	var mcol := VBoxContainer.new()
	mcol.add_theme_constant_override("separation", 0)
	mcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mp.add_child(mcol)
	var micon := HudIcon.new("map", 46.0)
	micon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mcol.add_child(micon)
	var mkey := _label(15, GOLD)
	mkey.text = "M"
	mkey.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mcol.add_child(mkey)
	_make_button(mp, func() -> void:
		if _map_ui and _map_ui.has_method("open") and not get_tree().paused:
			_map_ui.open())

	# ---- kiri-bawah: energi (tanpa angka)
	var ep := _wood(10, false)
	ep.anchor_top = 1.0
	ep.anchor_bottom = 1.0
	ep.offset_left = 16.0
	ep.offset_bottom = -16.0
	ep.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(ep)
	_energy_panel = ep
	var evb := VBoxContainer.new()
	evb.add_theme_constant_override("separation", 6)
	evb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ep.add_child(evb)
	var hr := HBoxContainer.new()                      # HP di atas energi
	hr.add_theme_constant_override("separation", 10)
	hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	evb.add_child(hr)
	_hp_icon = HudIcon.new("heart", 32.0)
	_hp_icon.color = Color(0.92, 0.25, 0.30)
	hr.add_child(_hp_icon)
	_hp_bar = _bar(Color(0.92, 0.25, 0.30), 20)
	_hp_bar.custom_minimum_size = Vector2(200, 20)
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(_hp_bar)
	var er := HBoxContainer.new()
	er.add_theme_constant_override("separation", 10)
	er.mouse_filter = Control.MOUSE_FILTER_IGNORE
	evb.add_child(er)
	_energy_icon = HudIcon.new("bolt", 32.0)
	_energy_icon.color = GREEN
	er.add_child(_energy_icon)
	_energy_bar = _bar(GREEN, 20)
	_energy_bar.custom_minimum_size = Vector2(200, 20)
	_energy_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_energy_fill = _energy_bar.get_theme_stylebox("fill") as StyleBoxFlat
	er.add_child(_energy_bar)

	# ---- kanan-atas: [uang] [kartu tanggal] , jam di bawah kartu (semuanya terpisah)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_right = -16.0
	right.offset_top = 34.0
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(right)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.alignment = BoxContainer.ALIGNMENT_END
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(top)

	# uang
	var cp := _wood(10, true)
	_coin_panel = cp
	cp.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(cp)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 10)
	crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cp.add_child(crow)
	_coin_label = _label(30, GOLD)
	_coin_label.custom_minimum_size = Vector2(176, 0)
	_coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	crow.add_child(_coin_label)
	_coin_icon = HudIcon.new("coin", 30.0)
	crow.add_child(_coin_icon)

	# kartu tanggal (klik = kalender)
	var dp := _wood(6, true)
	top.add_child(dp)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 3)
	dv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dp.add_child(dv)
	_card_art = Control.new()
	_card_art.custom_minimum_size = Vector2(100, 72)
	_card_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_art.draw.connect(_draw_card_art)
	dv.add_child(_card_art)
	_day_label = _label(46, Color.WHITE)
	_day_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_art.add_child(_day_label)
	var strip := PanelContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color(0.30, 0.62, 0.36)
	ssb.set_corner_radius_all(6)
	ssb.content_margin_top = 2.0
	ssb.content_margin_bottom = 2.0
	strip.add_theme_stylebox_override("panel", ssb)
	dv.add_child(strip)
	_weekday_label = _label(20, Color(0.97, 1.0, 0.92))
	_weekday_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	strip.add_child(_weekday_label)
	_make_button(dp, func() -> void:
		if _calendar and _calendar.has_method("open"):
			_calendar.open())

	# jam (papan sendiri di bawah kartu)
	var tp := _wood(8, false)
	tp.size_flags_horizontal = Control.SIZE_SHRINK_END
	tp.custom_minimum_size = Vector2(172, 0)          # papan jam dipanjangkan & ukurannya tetap
	right.add_child(tp)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 8)
	trow.alignment = BoxContainer.ALIGNMENT_CENTER
	trow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tp.add_child(trow)
	var ci := HudIcon.new("clock", 22.0)
	ci.color = Color(0.95, 0.88, 0.7)
	trow.add_child(ci)
	_time_label = ClockText.new()
	_time_label.font = _font
	trow.add_child(_time_label)
	# fase hari (Morning / Noon / Evening / Night) tepat di bawah jam
	var pp := _wood(6, false)
	pp.size_flags_horizontal = Control.SIZE_SHRINK_END
	pp.custom_minimum_size = Vector2(172, 0)
	right.add_child(pp)
	_phase_label = _label(24, CREAM)
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pp.add_child(_phase_label)

	# ---- atas-tengah: toast
	_toast_panel = _wood()
	_toast_panel.anchor_left = 0.5
	_toast_panel.anchor_right = 0.5
	_toast_panel.offset_top = 90.0
	_toast_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_panel.visible = false
	_toast_label = _label(26, CREAM)
	_toast_panel.add_child(_toast_label)
	_root.add_child(_toast_panel)

	# ---- kanan-bawah: petunjuk interaksi (kotak krem + tombol keyboard)
	_prompt_panel = PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(1.0, 0.92, 0.70)
	psb.set_corner_radius_all(6)
	psb.set_border_width_all(5)
	psb.border_color = Color(0.64, 0.40, 0.22)
	psb.shadow_color = Color(0, 0, 0, 0.3)
	psb.shadow_size = 6
	psb.content_margin_left = 14
	psb.content_margin_right = 18
	psb.content_margin_top = 10
	psb.content_margin_bottom = 10
	_prompt_panel.add_theme_stylebox_override("panel", psb)
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.custom_minimum_size = Vector2(0, 0)
	_prompt_panel.anchor_left = 1.0
	_prompt_panel.anchor_right = 1.0
	_prompt_panel.anchor_top = 1.0
	_prompt_panel.anchor_bottom = 1.0
	_prompt_panel.offset_right = -24.0
	_prompt_panel.offset_bottom = -24.0
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_prompt_panel.visible = false
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 16)
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.add_child(ph)
	var cap := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.27, 0.31, 0.50)
	csb.set_corner_radius_all(7)
	csb.set_border_width_all(3)
	csb.border_color = Color(0.13, 0.15, 0.27)
	csb.border_width_bottom = 6
	csb.content_margin_left = 12
	csb.content_margin_right = 12
	csb.content_margin_top = 2
	csb.content_margin_bottom = 2
	cap.add_theme_stylebox_override("panel", csb)
	cap.custom_minimum_size = Vector2(46, 46)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_key = Label.new()
	_prompt_key.add_theme_font_size_override("font_size", 28)
	_prompt_key.add_theme_color_override("font_color", Color.WHITE)
	_prompt_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if _font:
		_prompt_key.add_theme_font_override("font", _font)
	cap.add_child(_prompt_key)
	_prompt_keycap = cap
	ph.add_child(cap)
	_prompt_label = Label.new()
	_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 26)
	_prompt_label.add_theme_color_override("font_color", Color(0.38, 0.17, 0.10))
	if _font:
		_prompt_label.add_theme_font_override("font", _font)
	ph.add_child(_prompt_label)
	_root.add_child(_prompt_panel)


## Gambar mini pemandangan di kartu tanggal (langit, gunung, pinus).
func _draw_card_art() -> void:
	var r := Rect2(Vector2.ZERO, _card_art.size)
	var c := _card_art
	c.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([Color(0.45, 0.72, 0.90), Color(0.45, 0.72, 0.90), Color(0.98, 0.92, 0.66), Color(0.98, 0.92, 0.66)]))
	c.draw_circle(Vector2(r.size.x * 0.78, r.size.y * 0.30), 9.0, Color(1.0, 0.97, 0.78))
	var w := r.size.x
	var h := r.size.y
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, h * 0.7), Vector2(w * 0.22, h * 0.34), Vector2(w * 0.42, h * 0.62), Vector2(w * 0.62, h * 0.30), Vector2(w * 0.86, h * 0.64), Vector2(w, h * 0.5), Vector2(w, h), Vector2(0, h)]), Color(0.46, 0.58, 0.76))
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, h * 0.78), Vector2(w * 0.3, h * 0.62), Vector2(w * 0.6, h * 0.74), Vector2(w, h * 0.6), Vector2(w, h), Vector2(0, h)]), Color(0.32, 0.62, 0.34))
	for px in [0.10, 0.24, 0.80, 0.92]:
		var b := Vector2(w * px, h * 0.92)
		for k in 3:
			var ww := 9.0 - k * 2.0
			var yy := b.y - 7.0 * k
			c.draw_colored_polygon(PackedVector2Array([Vector2(b.x, yy - 11.0), Vector2(b.x - ww, yy), Vector2(b.x + ww, yy)]), Color(0.12, 0.38, 0.24))
	c.draw_rect(r, Color(0.14, 0.07, 0.03), false, 2.0)


## Jadikan papan kayu bisa diklik (sedikit membesar saat disorot).
func _make_button(panel: Control, action: Callable) -> void:
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size * 0.5)
	panel.mouse_entered.connect(func() -> void:
		create_tween().tween_property(panel, "scale", Vector2(1.06, 1.06), 0.1))
	panel.mouse_exited.connect(func() -> void:
		create_tween().tween_property(panel, "scale", Vector2.ONE, 0.1))
	panel.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			action.call())


## Papan kayu coklat (serat, paku, tali gantung). ropes = tergantung dari atas layar.
func _wood(margin: int = 12, ropes: bool = false) -> PanelContainer:
	var p := WoodPanel.new()
	p.margin = margin
	p.ropes = false                  # tanpa tali gantung
	p.seed_value = 3 + randi() % 50
	return p


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	if _font:
		l.add_theme_font_override("font", _font)
	return l


func _bar(color: Color, h: int) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = TRACK
	bg.set_corner_radius_all(h / 2)
	bg.set_border_width_all(2)
	bg.border_color = Color(0.05, 0.02, 0.01)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(h / 2)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fill)
	return b
