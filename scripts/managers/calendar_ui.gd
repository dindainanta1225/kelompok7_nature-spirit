extends CanvasLayer
## CalendarUI - kalender 30 hari. Dibuka dengan klik kartu tanggal di HUD (atau tekan C). Esc / C / X menutup.
##   - Hari ini diberi lingkaran hijau, hari target (GameState.LAST_DAY) diberi bendera merah "TARGET".
##   - Hari yang punya quest diberi gulungan. Isi quest baru terbaca setelah pemain menemui NPC-nya
##     (GameState.meet_npc("id")). Data quest ada di scripts/managers/quest_data.gd.
## Dibuat otomatis oleh HUD.

const WoodPanel := preload("res://scripts/managers/wood_panel.gd")
const QuestData := preload("res://scripts/managers/quest_data.gd")
const Icons := preload("res://scripts/managers/hud_icons.gd")
const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"

const WEEKDAYS := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const WEEKDAYS_SHORT := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
const CREAM := Color(1.0, 0.94, 0.78)
const GOLD := Color(1.0, 0.84, 0.30)
const MOSS := Color(0.62, 0.86, 0.45)
const MUTED := Color(0.80, 0.72, 0.55)
const OUTLINE := Color(0.14, 0.07, 0.03)
const FLAG_RED := Color(0.90, 0.26, 0.22)

var _font: Font
var _open := false
var _selected := 1
var _root: Control
var _dim: ColorRect
var _card: Control
var _cells: Array = []
var _info: VBoxContainer
var _title_sub: Label
var _tween: Tween


# ------------------------------------------------------------------ satu kotak tanggal
class DayCell extends Control:
	signal pressed(day: int)
	var day := 1
	var is_today := false
	var is_selected := false
	var is_past := false
	var is_goal := false
	var quests := 0
	var revealed := 0
	var font: Font
	var hover := false

	func _init(d: int, f: Font) -> void:
		day = d
		font = f
		custom_minimum_size = Vector2(58, 58)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func() -> void:
			hover = true
			queue_redraw())
		mouse_exited.connect(func() -> void:
			hover = false
			queue_redraw())

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit(day)
			accept_event()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var bg := Color(0.24, 0.14, 0.08, 0.92)
		if is_today:
			bg = Color(0.26, 0.50, 0.26)
		elif is_past:
			bg = Color(0.17, 0.10, 0.06, 0.9)
		if hover:
			bg = bg.lightened(0.12)
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(3 if is_selected else 2)
		sb.border_color = Color(1.0, 0.84, 0.30) if is_selected else Color(0.07, 0.035, 0.02)
		draw_style_box(sb, r)
		var col := CREAM
		if is_past and not is_today:
			col = Color(0.62, 0.55, 0.42)
		var txt := str(day)
		var fs := 24
		var ts := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var pos := Vector2(8, 8 + ts.y * 0.8)
		draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, OUTLINE)
		draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		if quests > 0:
			Icons.draw_scroll(self, Vector2(size.x - 24, size.y - 24), 17.0, MOSS if revealed >= quests else GOLD)
		if is_goal:
			Icons.draw_flag(self, Vector2(size.x - 22, 6), 19.0)


# ------------------------------------------------------------------ siklus
func _ready() -> void:
	layer = 54
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font
	if not InputMap.has_action("calendar"):
		InputMap.add_action("calendar")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_C
		InputMap.action_add_event("calendar", ev)
	_build()
	_root.visible = false
	GameState.npc_met.connect(func(_id: String) -> void: _refresh())
	GameState.day_changed.connect(func(_d: int) -> void: _refresh())
	GameState.coins_changed.connect(func(_c: int) -> void: _refresh())
	GameState.playing_changed.connect(func(on: bool) -> void:
		if not on and _open:
			_hide_now())


func _input(event: InputEvent) -> void:
	if not GameState.playing:
		return
	if _open:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("calendar"):
			close()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("calendar") and not GameState.input_locked and not get_tree().paused:
		open()
		get_viewport().set_input_as_handled()


func open() -> void:
	if _open or not GameState.playing or get_tree().paused:
		return
	_open = true
	_selected = clampi(GameState.day, 1, GameState.LAST_DAY)
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	if _tween and _tween.is_valid():
		_tween.kill()
	_dim.modulate.a = 0.0
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.92, 0.92)
	_card.pivot_offset = _card.size * 0.5
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 1.0, 0.15)
	_tween.tween_property(_card, "modulate:a", 1.0, 0.15)
	_tween.tween_property(_card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not _open:
		return
	_open = false
	get_tree().paused = false
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 0.0, 0.1)
	_tween.tween_property(_card, "modulate:a", 0.0, 0.1)
	_tween.chain().tween_callback(func() -> void: _root.visible = false)


func _hide_now() -> void:
	_open = false
	_root.visible = false


func is_open() -> bool:
	return _open


## Pilih tanggal (dipakai juga untuk tes).
func select_day(d: int) -> void:
	_selected = clampi(d, 1, GameState.LAST_DAY)
	_refresh()


# ------------------------------------------------------------------ data -> tampilan
func _refresh() -> void:
	if _cells.is_empty():
		return
	for c in _cells:
		var cell: DayCell = c
		cell.is_today = cell.day == mini(GameState.day, GameState.LAST_DAY)
		cell.is_past = cell.day < GameState.day
		cell.is_selected = cell.day == _selected
		cell.is_goal = cell.day == GameState.LAST_DAY
		var qs := QuestData.for_day(cell.day)
		cell.quests = qs.size()
		cell.revealed = 0
		for q in qs:
			if GameState.has_met(q["npc"]):
				cell.revealed += 1
		cell.queue_redraw()
	_title_sub.text = "Day %d of %d" % [mini(GameState.day, GameState.LAST_DAY), GameState.LAST_DAY]
	_rebuild_info()


func _rebuild_info() -> void:
	for ch in _info.get_children():
		ch.queue_free()
	var d := _selected
	var head := _label(30, GOLD)
	head.text = "Day %d" % d
	_info.add_child(head)
	var wd := _label(20, MUTED)
	var rel := ""
	if d == GameState.day:
		rel = "  ·  today"
	elif d < GameState.day:
		rel = "  ·  past"
	else:
		rel = "  ·  in %d days" % (d - GameState.day)
	wd.text = WEEKDAYS[(d - 1) % 7] + rel
	_info.add_child(wd)
	_info.add_child(_separator())

	var any := false
	if d == GameState.LAST_DAY:
		any = true
		_info.add_child(_goal_block())
	for q in QuestData.for_day(d):
		any = true
		_info.add_child(_quest_block(q))
	if not any:
		var none := _label(18, MUTED)
		none.text = "Nothing planned.\nA good day to farm!"
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(250, 0)
		_info.add_child(none)


func _separator() -> Control:
	var s := ColorRect.new()
	s.color = Color(0.07, 0.035, 0.02, 0.8)
	s.custom_minimum_size = Vector2(0, 3)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _block_box() -> PanelContainer:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.09, 0.05, 0.85)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.07, 0.035, 0.02)
	sb.set_content_margin_all(10.0)
	pc.add_theme_stylebox_override("panel", sb)
	return pc


func _goal_block() -> Control:
	var pc := _block_box()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var fl := Control.new()
	fl.custom_minimum_size = Vector2(22, 22)
	fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.draw.connect(func() -> void: Icons.draw_flag(fl, Vector2(0, 1), 22.0))
	row.add_child(fl)
	var t := _label(22, Color(1.0, 0.55, 0.45))
	t.text = "GOAL"
	row.add_child(t)
	var txt := _label(17, CREAM)
	txt.text = "Collect %s coins before the morning of day %d." % [_fmt(GameState.GOAL_COINS), GameState.LAST_DAY + 1]
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.custom_minimum_size = Vector2(250, 0)
	v.add_child(txt)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = GameState.GOAL_COINS
	bar.value = GameState.coins
	bar.custom_minimum_size = Vector2(0, 12)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.05, 0.03)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	v.add_child(bar)
	var prog := _label(16, MUTED)
	prog.text = "%s / %s" % [_fmt(GameState.coins), _fmt(GameState.GOAL_COINS)]
	v.add_child(prog)
	return pc


func _quest_block(q: Dictionary) -> Control:
	var pc := _block_box()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(v)
	var known := GameState.has_met(q["npc"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(22, 22)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icol := MOSS if known else GOLD
	ic.draw.connect(func() -> void: Icons.draw_scroll(ic, Vector2(0, 1), 21.0, icol))
	row.add_child(ic)
	var head := _label(22, MOSS if known else GOLD)
	head.text = q["title"] if known else "Hidden quest"
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size = Vector2(220, 0)
	row.add_child(head)
	var body := _label(17, CREAM if known else MUTED)
	if known:
		body.text = "From: %s\n%s" % [QuestData.npc_name(q["npc"]), q["text"]]
		if GameState.is_quest_done(q["id"]):
			body.text += "\n(Completed)"
	else:
		body.text = "Meet someone in the village to unlock this quest."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(250, 0)
	v.add_child(body)
	return pc


static func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return out


# ------------------------------------------------------------------ bangun UI
func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	l.add_theme_font_override("font", _font)
	return l


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.03, 0.02, 0.6)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var card := WoodPanel.new()
	_card = card
	card.wood = Color(0.40, 0.25, 0.13)
	card.seed_value = 41
	card.margin = 22
	card.corner_radius = 16
	card.leaves = true
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)

	# judul + tombol tutup
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var title := _label(40, GOLD)
	title.text = "Calendar"
	top.add_child(title)
	_title_sub = _label(20, MUTED)
	_title_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_sub.size_flags_vertical = Control.SIZE_SHRINK_END
	_title_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_title_sub)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.add_theme_font_override("font", _font)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.add_theme_color_override("font_color", CREAM)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color(0.55, 0.20, 0.16), "hover": Color(0.72, 0.28, 0.22), "pressed": Color(0.42, 0.14, 0.11)}[st]
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.07, 0.035, 0.02)
		close_btn.add_theme_stylebox_override(st, sb)
	close_btn.pressed.connect(close)
	top.add_child(close_btn)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(body)

	# ---- kiri: kisi tanggal
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(left)
	var wk := HBoxContainer.new()
	wk.add_theme_constant_override("separation", 6)
	wk.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(wk)
	for i in 7:
		var l := _label(18, MOSS if i > 0 else Color(1.0, 0.55, 0.45))
		l.text = WEEKDAYS_SHORT[i]
		l.custom_minimum_size = Vector2(58, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		wk.add_child(l)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(grid)
	var blanks := 0
	for d in range(1, GameState.LAST_DAY + 1):
		var cell := DayCell.new(d, _font)
		cell.pressed.connect(select_day)
		grid.add_child(cell)
		_cells.append(cell)
	# legenda
	var leg := HBoxContainer.new()
	leg.add_theme_constant_override("separation", 14)
	leg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(leg)
	_legend(leg, "scroll", "Quest")
	_legend(leg, "flag", "Goal")
	_legend(leg, "today", "Today")

	# ---- kanan: rincian hari terpilih
	var info_panel := PanelContainer.new()
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0.25, 0.14, 0.08, 0.9)
	isb.set_corner_radius_all(10)
	isb.set_border_width_all(3)
	isb.border_color = Color(0.07, 0.035, 0.02)
	isb.set_content_margin_all(14.0)
	info_panel.add_theme_stylebox_override("panel", isb)
	info_panel.custom_minimum_size = Vector2(300, 330)
	body.add_child(info_panel)
	_info = VBoxContainer.new()
	_info.add_theme_constant_override("separation", 8)
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.add_child(_info)


func _legend(parent: Control, kind: String, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var ic := Control.new()
	ic.custom_minimum_size = Vector2(20, 20)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.draw.connect(func() -> void:
		if kind == "scroll":
			Icons.draw_scroll(ic, Vector2(0, 1), 19.0, GOLD)
		elif kind == "flag":
			Icons.draw_flag(ic, Vector2(0, 0), 20.0)
		else:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.26, 0.50, 0.26)
			sb.set_corner_radius_all(5)
			ic.draw_style_box(sb, Rect2(Vector2(1, 2), Vector2(17, 17))))
	row.add_child(ic)
	var l := _label(16, MUTED)
	l.text = text
	row.add_child(l)
