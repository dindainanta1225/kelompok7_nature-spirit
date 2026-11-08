extends CanvasLayer
## SettingsMenu - jendela pengaturan: Game / Audio / Controls / Other. Dipakai main menu dan menu ESC.
##   var s = SettingsMenu.new(); add_child(s); s.open(in_game)   # in_game=true -> ada Teleport & Back to Main Menu
## Esc = tutup. Pengaturan disimpan otomatis (AppSettings).

signal closed

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const AppSettings := preload("res://scripts/ui/app_settings.gd")
const Sfx := preload("res://scripts/audio/sfx.gd")
const MENU_SCENE := "res://scene/main/mainmenu/main_menu.tscn"
const CATS := ["Game", "Audio", "Controls", "Other"]

var _root: Control
var _content: VBoxContainer
var _scroll: ScrollContainer
var _cat_btns: Array[Button] = []
var _cat := 0
var _open := false
var _in_game := false
var _rebinding := ""
var _rebind_btn: Button
var _confirm_btn: Button
var _tip: Label
var _notice: PanelContainer
var _notice_label: Label
var _notice_tween: Tween


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false


func is_open() -> bool:
	return _open


func open(in_game := false) -> void:
	_in_game = in_game
	_open = true
	_root.visible = true
	_select(_cat)
	Sfx.play("open", -6.0)


func close() -> void:
	if not _open:
		return
	_open = false
	_rebinding = ""
	_root.visible = false
	AppSettings.save()
	Sfx.play("close", -6.0)
	closed.emit()


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if _rebinding != "":
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			if event.keycode != KEY_ESCAPE:
				var k: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
				AppSettings.rebind(_rebinding, k)
			_rebinding = ""
			_select(_cat)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			close()
		elif event.keycode == KEY_DOWN:
			get_viewport().set_input_as_handled()
			_select((_cat + 1) % CATS.size())
		elif event.keycode == KEY_UP:
			get_viewport().set_input_as_handled()
			_select((_cat + CATS.size() - 1) % CATS.size())


# ------------------------------------------------------------------ rangka
func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = UiStyle.DIM
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_notice = PanelContainer.new()
	_notice.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.BG, UiStyle.BORDER, 3, 5, true))
	_notice.anchor_left = 0.5
	_notice.anchor_right = 0.5
	_notice.anchor_top = 0.5
	_notice.anchor_bottom = 0.5
	_notice.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notice.offset_top = -262.0                           # di atas jendela, tidak menutupi pengaturan
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.modulate.a = 0.0
	_notice_label = UiStyle.label("", 16)
	_notice.add_child(_notice_label)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	center.add_child(hb)
	_root.add_child(_notice)                              # di atas semuanya

	# kiri: judul + kategori
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UiStyle.frame())
	var lwrap := Control.new()                           # pembungkus supaya judul bisa menggantung di tepi atas bingkai
	lwrap.custom_minimum_size = Vector2(250, 410)
	hb.add_child(lwrap)
	left.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lwrap.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 10)
	left.add_child(lv)
	var topgap := Control.new()
	topgap.custom_minimum_size = Vector2(0, 26)
	lv.add_child(topgap)
	var title := PanelContainer.new()
	title.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.BG_LIGHT, UiStyle.BORDER, 4, 4))
	var tl := UiStyle.label("Settings", 28)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_child(tl)
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -105.0
	title.offset_right = 105.0
	title.offset_top = -26.0                              # setengah di atas bingkai, setengah di dalam
	title.offset_bottom = 26.0
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lwrap.add_child(title)
	for i in CATS.size():
		var b := Button.new()
		b.text = CATS[i]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 52)
		UiStyle.style_button(b, 26)
		var idx := i
		b.pressed.connect(func() -> void: _select(idx))
		b.mouse_entered.connect(func() -> void: Sfx.play("hotbar", -10.0))
		lv.add_child(b)
		_cat_btns.append(b)

	# kanan: isi
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UiStyle.frame())
	right.custom_minimum_size = Vector2(470, 410)
	hb.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	right.add_child(rv)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.add_theme_stylebox_override("panel", UiStyle.box(Color(0.80, 0.62, 0.40), UiStyle.BORDER, 3, 3, false))
	rv.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)
	_tip = UiStyle.label("", 18, Color(0.55, 0.30, 0.15))
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip.custom_minimum_size = Vector2(0, 26)
	rv.add_child(_tip)
	var closeb := Button.new()
	closeb.text = "Close  [Esc]"
	closeb.custom_minimum_size = Vector2(0, 40)
	UiStyle.style_button(closeb, 22, true)
	closeb.pressed.connect(close)
	rv.add_child(closeb)


func _select(i: int) -> void:
	_cat = i
	_confirm_btn = null
	for k in _cat_btns.size():
		UiStyle.select_style(_cat_btns[k], k == i)
	for c in _content.get_children():
		c.queue_free()
	_tip.text = ""
	match i:
		0:
			_build_game()
		1:
			_build_audio()
		2:
			_build_controls()
		3:
			_build_other()


# ------------------------------------------------------------------ baris
func _row_box() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.BG, UiStyle.BG, 0, 3, false))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(p)
	return p


func _row_button(text: String, btn_text: String, cb: Callable, tip := "") -> Button:
	var p := _row_box()
	var h := HBoxContainer.new()
	p.add_child(h)
	var l := UiStyle.label(text, 22)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	var b := Button.new()
	b.text = btn_text
	b.custom_minimum_size = Vector2(150, 36)
	UiStyle.style_button(b, 20, true)
	b.pressed.connect(cb)
	h.add_child(b)
	if tip != "":
		b.mouse_entered.connect(func() -> void: _tip.text = tip)
	return b


## Pilihan berputar: klik sisi kiri = mundur, sisi kanan = maju.
func _row_option(text: String, names: Array, get_i: Callable, set_i: Callable, tip := "") -> void:
	var b := _row_button(text, "", func() -> void: pass, tip)
	var refresh := func() -> void: b.text = "<  %s  >" % names[get_i.call()]
	refresh.call()
	for c in b.pressed.get_connections():
		b.pressed.disconnect(c["callable"])
	b.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			var dir := 1 if e.position.x > b.size.x * 0.5 else -1
			set_i.call((int(get_i.call()) + dir + names.size()) % names.size())
			Sfx.play("select", -8.0)
			refresh.call()
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_RIGHT:
			set_i.call((int(get_i.call()) + 1) % names.size())
			refresh.call())


func _row_check(text: String, on: bool, cb: Callable) -> void:
	var p := _row_box()
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	var f := UiStyle.font()
	if f:
		c.add_theme_font_override("font", f)
	c.add_theme_font_size_override("font_size", 22)
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		c.add_theme_color_override(col, UiStyle.TEXT)
	c.toggled.connect(func(v: bool) -> void:
		Sfx.play("select", -8.0)
		cb.call(v))
	p.add_child(c)


func _row_slider(text: String, v: float, cb: Callable) -> void:
	var p := _row_box()
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	p.add_child(vb)
	var h := HBoxContainer.new()
	vb.add_child(h)
	var l := UiStyle.label(text, 22)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var pc := UiStyle.label("%d%%" % roundi(v * 100.0), 22)
	h.add_child(pc)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = v
	s.custom_minimum_size = Vector2(0, 20)
	s.focus_mode = Control.FOCUS_NONE
	var track := UiStyle.box(Color(0.25, 0.16, 0.08), Color.BLACK, 2, 2, false)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	var fill := UiStyle.box(Color(1.0, 0.95, 0.10), Color.BLACK, 2, 2, false)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var blank := ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	for ic in ["grabber", "grabber_highlight", "grabber_disabled"]:
		s.add_theme_icon_override(ic, blank)
	s.value_changed.connect(func(x: float) -> void:
		pc.text = "%d%%" % roundi(x * 100.0)
		cb.call(x))
	vb.add_child(s)


# ------------------------------------------------------------------ isi kategori
func _notify(text: String) -> void:
	_notice_label.text = text
	if _notice_tween != null and _notice_tween.is_valid():
		_notice_tween.kill()
	_notice.modulate.a = 1.0
	_notice_tween = create_tween()
	_notice_tween.tween_interval(2.6)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 0.5)


func _build_game() -> void:
	if _in_game:
		_row_button("Teleport to a safe spot", "Teleport", _do_unstuck, "Use this when you are stuck. You move to a free spot nearby, in the same area.")
	_row_option("Time Speed", AppSettings.TIME_NAMES, func() -> int: return AppSettings.time_speed,
		func(i: int) -> void:
			if _in_game and GameState.playing and i != AppSettings.time_speed:
				if AppSettings.applied_speed < 0:
					AppSettings.applied_speed = AppSettings.time_speed       # kecepatan lama tetap jalan sampai hari berganti
				_notify("Time speed will be set after 1 day has passed!")
			AppSettings.time_speed = i
			if AppSettings.applied_speed == i:
				AppSettings.applied_speed = -1
			AppSettings.save(),
		"Slow: 1 real second = 1 game minute.  Normal: 2.  Fast: 3.")
	_row_option("UI Size", ["25%", "50%", "75%", "100%"], func() -> int: return _pct_index(AppSettings.ui_scale),
		func(i: int) -> void:
			AppSettings.ui_scale = AppSettings.PERCENTS[i] / 100.0
			AppSettings.apply_ui_scale(get_tree()),
		"Scales the HUD and all menus. 25% is tiny and feels far away; 100% is normal.")
	_row_option("Camera Distance", ["25%", "50%", "75%", "100%"], func() -> int: return _pct_index(AppSettings.cam_scale),
		func(i: int) -> void: AppSettings.cam_scale = AppSettings.PERCENTS[i] / 100.0,
		"How high the camera is above the player. 25% is zoomed in close; 100% is normal.")
	_row_check("Fullscreen", AppSettings.fullscreen, func(v: bool) -> void:
		AppSettings.fullscreen = v
		AppSettings.apply_fullscreen())


func _pct_index(v: float) -> int:
	var best := 3
	var bd := 9.0
	for i in AppSettings.PERCENTS.size():
		var d := absf(AppSettings.PERCENTS[i] / 100.0 - v)
		if d < bd:
			bd = d
			best = i
	return best


func _build_audio() -> void:
	_row_slider("Master Volume", AppSettings.master, func(v: float) -> void:
		AppSettings.master = v
		AppSettings.apply_audio())
	_row_slider("Music Volume", AppSettings.music, func(v: float) -> void:
		AppSettings.music = v
		AppSettings.apply_audio())
	_row_slider("Sound Effects", AppSettings.sfx, func(v: float) -> void:
		AppSettings.sfx = v
		AppSettings.apply_audio())


func _build_controls() -> void:
	_tip.text = "Click a key, then press the new key. Esc cancels."
	for a in AppSettings.ACTIONS:
		var act: String = a[0]
		var b := _row_button(a[1], AppSettings.key_name(act), func() -> void: pass)
		for c in b.pressed.get_connections():
			b.pressed.disconnect(c["callable"])
		var btn := b
		b.pressed.connect(func() -> void:
			_rebinding = act
			_rebind_btn = btn
			btn.text = "Press a key...")


func _build_other() -> void:
	if _in_game:
		var b := _row_button("Back to Main Menu", "Go", func() -> void: pass)
		_wire_confirm(b, "Go", _to_menu)
	var q := _row_button("Quit Game", "Quit", func() -> void: pass)
	_wire_confirm(q, "Quit", func() -> void: get_tree().quit())


## Tombol berbahaya: klik pertama minta konfirmasi, klik kedua (dalam 3 detik) menjalankan.
func _wire_confirm(b: Button, label: String, action: Callable) -> void:
	for c in b.pressed.get_connections():
		b.pressed.disconnect(c["callable"])
	b.pressed.connect(func() -> void:
		if _confirm_btn == b:
			action.call()
			return
		_confirm_btn = b
		b.text = "Sure?"
		_tip.text = "Click again to confirm."
		get_tree().create_timer(3.0, true, false, true).timeout.connect(func() -> void:
			if is_instance_valid(b) and _confirm_btn == b:
				_confirm_btn = null
				b.text = label))


func _do_unstuck() -> void:
	var pl := get_tree().get_first_node_in_group("player")
	if pl != null and pl.has_method("safe_teleport") and pl.safe_teleport():
		GameState.toast.emit("Moved to a safe spot.")
		close()
	else:
		_tip.text = "No safe spot recorded yet. Walk around a little first."


func _to_menu() -> void:
	_open = false
	_root.visible = false
	AppSettings.save()
	get_tree().paused = false
	if GameState.has_method("quit_to_menu"):
		GameState.quit_to_menu()
	get_tree().change_scene_to_file(MENU_SCENE)
	closed.emit()
