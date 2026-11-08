extends CanvasLayer
## PauseMenu - menu Esc berbentuk cincin ikon. Panah kiri/kanan memutar cincin, ikon terpilih membesar di bawah
## dan namanya muncul di bar. Enter / E / Space / klik = pilih. Esc = tutup.
## Isi: Backpack, Map, Save (belum berfungsi), Settings, Calendar, Nap (belum berfungsi).

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const SettingsMenu := preload("res://scripts/ui/settings_menu.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")

const ITEMS := [
	{"id": "backpack", "name": "Backpack"},
	{"id": "map", "name": "Map"},
	{"id": "save", "name": "Save  (coming soon)"},
	{"id": "settings", "name": "Settings"},
	{"id": "calendar", "name": "Calendar"},
	{"id": "nap", "name": "Take a Nap  (coming soon)"},
]

var _root: Control
var _ring: Control
var _label: Label
var _open := false
var _sel := 0
var _pos := 0.0                    # posisi putar yang dianimasikan (menuju _sel)
var _settings: Node
var _t := 0.0


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_ring = Ring.new()
	_ring.menu = self
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_ring)
	var bar := PanelContainer.new()
	var sb := UiStyle.box(Color(0.05, 0.04, 0.08, 0.88), Color(0.10, 0.08, 0.14), 3, 6, false)
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	bar.add_theme_stylebox_override("panel", sb)
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.anchor_top = 0.5
	bar.anchor_bottom = 0.5
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.offset_top = 128.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = UiStyle.label("", 26, Color.WHITE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(300, 0)
	bar.add_child(_label)
	_root.add_child(bar)
	var hint := UiStyle.label("<  >  turn      Enter  select      Esc  close", 20, Color(1, 1, 1, 0.75))
	hint.anchor_left = 0.5
	hint.anchor_right = 0.5
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.offset_top = -50.0
	_root.add_child(hint)
	_root.visible = false


func is_open() -> bool:
	return _open


func _can_open() -> bool:
	if not GameState.playing or GameState.input_locked or GameState.cutscene or GameState.chatting:
		return false
	if get_tree().paused:
		return false
	if HUD.has_method("ui_busy") and HUD.ui_busy():
		return false
	return true


func _unhandled_input(event: InputEvent) -> void:
	if _settings != null and _settings.is_open():
		return
	if not _open:
		if event.is_action_pressed("ui_cancel") and _can_open():
			get_viewport().set_input_as_handled()
			open()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
		elif k == KEY_LEFT or k == KEY_A:
			get_viewport().set_input_as_handled()
			_turn(-1)
		elif k == KEY_RIGHT or k == KEY_D:
			get_viewport().set_input_as_handled()
			_turn(1)
		elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE or k == KEY_E or k == KEY_F:
			get_viewport().set_input_as_handled()
			_activate()


func open() -> void:
	_open = true
	_sel = 0
	_pos = 0.0
	_root.visible = true
	if HUD.has_method("set_hud_hidden"):
		HUD.set_hud_hidden(true)             # sembunyikan inventory & energi selama menu cincin
	get_tree().paused = true
	_refresh()
	Sfx.play("open", -4.0)


func close(unpause := true) -> void:
	if not _open:
		return
	_open = false
	_root.visible = false
	if HUD.has_method("set_hud_hidden"):
		HUD.set_hud_hidden(false)
	if unpause:
		get_tree().paused = false
	Sfx.play("close", -6.0)


func _turn(d: int) -> void:
	_sel = (_sel + d + ITEMS.size()) % ITEMS.size()
	Sfx.play("hotbar", -6.0)
	_refresh()


func select(i: int) -> void:
	_sel = i
	_refresh()


func _refresh() -> void:
	_label.text = ITEMS[_sel]["name"]


func _process(delta: float) -> void:
	if not _open:
		return
	_t += delta
	# putar lewat jalur terpendek
	var n := float(ITEMS.size())
	var d := fposmod(_sel - _pos + n * 0.5, n) - n * 0.5
	_pos += d * (1.0 - exp(-14.0 * delta))
	_ring.queue_redraw()


func _activate() -> void:
	var id: String = ITEMS[_sel]["id"]
	match id:
		"settings":
			if _settings == null:
				_settings = SettingsMenu.new()
				add_child(_settings)
				_settings.closed.connect(func() -> void: _ring.queue_redraw())
			_settings.open(true)
		"save", "nap":
			Sfx.play("select", -6.0)
			GameState.toast.emit("Not available yet.")
		_:
			close()
			var target: Variant = null
			match id:
				"backpack":
					target = HUD.get("_inventory_ui")
				"map":
					target = HUD.get("_map_ui")
				"calendar":
					target = HUD.get("_calendar")
			if target != null and (target as Object).has_method("open"):
				(target as Object).call_deferred("open")


# ------------------------------------------------------------------ cincin ikon
class Ring extends Control:
	var menu

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var best := -1
			var bd := 1.0e9
			for i in ITEMS.size():
				var p: Vector2 = _tile_pos(i)
				var d := p.distance_to(e.position)
				if d < bd:
					bd = d
					best = i
			if best >= 0 and bd < 40.0:
				if best == menu._sel:
					menu._activate()
				else:
					menu.select(best)

	func _center() -> Vector2:
		return size * 0.5 + Vector2(0, 8)

	func _tile_pos(i: int) -> Vector2:
		var n := float(ITEMS.size())
		var a: float = PI * 0.5 + (float(i) - float(menu._pos)) * TAU / n         # terpilih = di bawah
		return _center() + Vector2(cos(a) * 115.0, sin(a) * 78.0)

	func _draw() -> void:
		var order: Array = range(ITEMS.size())
		order.sort_custom(func(x: int, y: int) -> bool: return _tile_pos(x).y < _tile_pos(y).y)
		for i in order:
			var p := _tile_pos(i)
			var nn := float(ITEMS.size())
			var dd := absf(fposmod(float(i) - float(menu._pos) + nn * 0.5, nn) - nn * 0.5)
			var near := clampf(1.0 - dd, 0.0, 1.0)
			var s := lerpf(34.0, 58.0, near)
			var r := Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s))
			var sel: bool = i == menu._sel
			var sb := UiStyle.box(UiStyle.BG if sel else Color(0.86, 0.74, 0.55, 0.95), UiStyle.BORDER, 4, 5, true)
			draw_style_box(sb, r)
			draw_style_box(UiStyle.box(Color(0, 0, 0, 0), Color(1, 0.95, 0.8, 0.55), 2, 3, false), r.grow(-5.0))
			_icon(ITEMS[i]["id"], p, s * 0.5, sel)

	func _icon(id: String, c: Vector2, r: float, sel: bool) -> void:
		var ink := Color(0.45, 0.24, 0.10) if sel else Color(0.55, 0.38, 0.22)
		var hi := Color(0.95, 0.65, 0.20)
		match id:
			"backpack":
				draw_rect(Rect2(c + Vector2(-r * 0.5, -r * 0.35), Vector2(r, r * 0.95)), ink)
				draw_rect(Rect2(c + Vector2(-r * 0.5, -r * 0.62), Vector2(r, r * 0.4)), hi)
				draw_rect(Rect2(c + Vector2(-r * 0.28, r * 0.05), Vector2(r * 0.56, r * 0.38)), hi)
			"map":
				var pts := PackedVector2Array([c + Vector2(-r * 0.6, -r * 0.5), c + Vector2(-r * 0.2, -r * 0.35), c + Vector2(r * 0.2, -r * 0.5), c + Vector2(r * 0.6, -r * 0.35),
					c + Vector2(r * 0.6, r * 0.5), c + Vector2(r * 0.2, r * 0.35), c + Vector2(-r * 0.2, r * 0.5), c + Vector2(-r * 0.6, r * 0.35)])
				draw_colored_polygon(pts, ink)
				draw_line(c + Vector2(-r * 0.2, -r * 0.35), c + Vector2(-r * 0.2, r * 0.5), hi, 2.0)
				draw_line(c + Vector2(r * 0.2, -r * 0.5), c + Vector2(r * 0.2, r * 0.35), hi, 2.0)
			"save":
				draw_rect(Rect2(c - Vector2(r * 0.55, r * 0.55), Vector2(r * 1.1, r * 1.1)), ink)
				draw_rect(Rect2(c + Vector2(-r * 0.32, -r * 0.55), Vector2(r * 0.64, r * 0.36)), hi)
				draw_rect(Rect2(c + Vector2(-r * 0.36, r * 0.05), Vector2(r * 0.72, r * 0.5)), Color(1, 0.93, 0.75))
			"settings":
				for k in 8:
					var a := TAU * k / 8.0
					draw_line(c + Vector2(cos(a), sin(a)) * r * 0.45, c + Vector2(cos(a), sin(a)) * r * 0.7, ink, r * 0.28)
				draw_circle(c, r * 0.5, ink)
				draw_circle(c, r * 0.2, Color(1, 0.93, 0.75))
			"calendar":
				draw_rect(Rect2(c - Vector2(r * 0.6, r * 0.5), Vector2(r * 1.2, r * 1.1)), ink)
				draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.5), Vector2(r * 1.2, r * 0.3)), Color(0.78, 0.25, 0.20))
				for gx in 3:
					for gy in 2:
						draw_rect(Rect2(c + Vector2(-r * 0.42 + gx * r * 0.34, -r * 0.05 + gy * r * 0.3), Vector2(r * 0.22, r * 0.2)), Color(1, 0.93, 0.75))
			"nap":
				draw_circle(c + Vector2(-r * 0.05, 0), r * 0.55, ink)
				draw_circle(c + Vector2(r * 0.18, -r * 0.1), r * 0.5, Color(0.86, 0.74, 0.55) if not sel else UiStyle.BG)
				draw_string(ThemeDB.fallback_font, c + Vector2(r * 0.25, -r * 0.25), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r * 0.9), hi)
