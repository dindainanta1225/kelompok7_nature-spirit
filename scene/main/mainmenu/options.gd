extends Control
## OptionsFX - mempercantik panel Settings tanpa mengubah node atau script yang sudah ada.
##
## PASANG:
##  1. Di main_menu.tscn, klik node "Options" (panel Settings), lalu Attach Script > Load
##     > pilih options_fx.gd. (Kalau Options sudah punya script lain, bilang aku dulu.)
##  2. Jalankan. Semua slider, toggle, dan tombol di dalam Options otomatis ikut dipercantik.
##
## Node dicari lewat nama: Title, AudioLabel, DisplayLabel, MasterLabel (untuk font).
## Setiap bagian bisa dimatikan di Inspector.
 
@export_group("Warna")
@export var panel_color := Color(0.06, 0.14, 0.10, 0.95)
@export var border_color := Color(0.0, 0.95, 0.33)
@export var accent_color := Color(0.0, 0.95, 0.33)       # samakan dengan warna tombol hijau-mu
@export var track_color := Color(0.02, 0.07, 0.05, 1.0)
 
@export_group("Aktifkan")
@export var style_panel := true
@export var style_sliders := true
@export var value_labels := true        # angka persen di kanan slider
@export var style_toggles := true       # toggle Fullscreen jadi bentuk pil hijau
@export var heading_underlines := true  # garis emas/hijau di bawah judul bagian
@export var open_animation := true      # panel muncul membesar, isinya masuk berurutan
@export var dim_background := true      # menu di belakang digelapkan dan tidak bisa diklik
@export var button_animation := true    # hover dan klik pada tombol (misal Back)
 
@export_group("Suara (opsional)")
@export var tick_sound: AudioStreamPlayer   # bunyi kecil saat slider digeser
 
var _value_labels: Dictionary = {}
var _open_tween: Tween
var _dimmer: ColorRect
var _dim_tween: Tween
var _btn_tweens: Dictionary = {}
var _last_tick := 0.0
 
 
func _ready() -> void:
	if style_panel:
		_style_panel()
	if style_sliders:
		_style_sliders()
	if style_toggles:
		_style_toggles()
	if button_animation:
		_setup_buttons()
	if dim_background:
		_make_dimmer.call_deferred()
	pivot_offset = size * 0.5
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	visibility_changed.connect(_on_visibility_changed)
 
	await get_tree().process_frame            # tunggu layout selesai untuk garis judul
	if heading_underlines:
		for nm in ["AudioLabel", "DisplayLabel"]:
			var lbl := find_child(nm, true, false) as Label
			if lbl:
				_add_underline(lbl)
	if is_visible_in_tree():
		_on_visibility_changed()
 
 
# ------------------------------------------------------------------ panel
 
func _style_panel() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = panel_color
	sb.set_border_width_all(4)
	sb.border_color = border_color
	sb.set_corner_radius_all(22)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 6)
	if is_class("Panel") or is_class("PanelContainer"):
		add_theme_stylebox_override("panel", sb)
	else:
		var p := Panel.new()
		p.add_theme_stylebox_override("panel", sb)
		p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(p)
		move_child(p, 0)
 
 
# ------------------------------------------------------------------ slider
 
func _style_sliders() -> void:
	var grab := _circle_texture(false)
	var grab_hi := _circle_texture(true)
	for n in find_children("*", "HSlider", true, false):
		var s := n as HSlider
		s.add_theme_stylebox_override("slider", _track(track_color))
		s.add_theme_stylebox_override("grabber_area", _track(accent_color))
		s.add_theme_stylebox_override("grabber_area_highlight", _track(accent_color.lightened(0.25)))
		s.add_theme_icon_override("grabber", grab)
		s.add_theme_icon_override("grabber_highlight", grab_hi)
		s.add_theme_icon_override("grabber_disabled", grab)
		if value_labels:
			_add_value_label(s)
		s.value_changed.connect(_on_slider_changed.bind(s))
 
 
func _track(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(7)
	sb.content_margin_top = 7.0
	sb.content_margin_bottom = 7.0
	sb.content_margin_left = 0.0
	sb.content_margin_right = 0.0
	return sb
 
 
func _add_value_label(s: HSlider) -> void:
	var l := Label.new()
	l.name = "ValueLabel"
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.anchor_left = 1.0
	l.anchor_right = 1.0
	l.anchor_top = 0.5
	l.anchor_bottom = 0.5
	l.offset_left = 16.0
	l.offset_right = 86.0
	l.offset_top = -16.0
	l.offset_bottom = 16.0
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.06, 0.04))
	l.add_theme_constant_override("outline_size", 6)
	var ref := find_child("MasterLabel", true, false) as Control
	if ref:
		l.add_theme_font_override("font", ref.get_theme_font("font"))
	s.add_child(l)
	_value_labels[s] = l
	_update_value(s)
 
 
func _update_value(s: HSlider) -> void:
	var l := _value_labels.get(s) as Label
	if l == null:
		return
	var span := s.max_value - s.min_value
	var pct := 0.0 if span <= 0.0 else (s.value - s.min_value) / span * 100.0
	l.text = "%d%%" % roundi(pct)
 
 
func _on_slider_changed(_v: float, s: HSlider) -> void:
	_update_value(s)
	var now := Time.get_ticks_msec() / 1000.0
	if tick_sound and now - _last_tick > 0.06:
		_last_tick = now
		var span := s.max_value - s.min_value
		var f := 0.0 if span <= 0.0 else (s.value - s.min_value) / span
		tick_sound.pitch_scale = 0.8 + f * 0.6
		tick_sound.play()
 
 
func _circle_texture(highlight: bool) -> ImageTexture:
	var d := 30
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d, d) * 0.5 - Vector2(0.5, 0.5)
	var r := d * 0.5 - 1.0
	var ring := accent_color.lightened(0.2) if highlight else accent_color
	for y in d:
		for x in d:
			var dist := Vector2(x, y).distance_to(c)
			var a := clampf(r - dist + 0.5, 0.0, 1.0)
			var col := ring if dist > r - 5.0 else Color.WHITE
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)
 
 
# ------------------------------------------------------------------ toggle
 
func _style_toggles() -> void:
	var on := _toggle_texture(true)
	var off := _toggle_texture(false)
	for n in find_children("*", "CheckButton", true, false):
		var b := n as CheckButton
		for nm in ["checked", "checked_disabled", "checked_mirrored", "checked_disabled_mirrored"]:
			b.add_theme_icon_override(nm, on)
		for nm in ["unchecked", "unchecked_disabled", "unchecked_mirrored", "unchecked_disabled_mirrored"]:
			b.add_theme_icon_override(nm, off)
 
 
func _toggle_texture(is_on: bool) -> ImageTexture:
	var w := 52
	var h := 28
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r := h * 0.5
	var knob_x := (w - r) if is_on else r
	var base := accent_color if is_on else Color(0.2, 0.25, 0.22)
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(p.x, r, w - r)
			var a := clampf(r - p.distance_to(Vector2(cx, r)) + 0.5, 0.0, 1.0)
			var ka := clampf(r - 4.0 - p.distance_to(Vector2(knob_x, r)) + 0.5, 0.0, 1.0)
			var col := base.lerp(Color.WHITE, ka)
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))
	return ImageTexture.create_from_image(img)
 
 
# ------------------------------------------------------------------ judul
 
func _add_underline(lbl: Label) -> void:
	var w := lbl.get_minimum_size().x
	var bar := ColorRect.new()
	bar.color = accent_color
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = 2.0
	bar.offset_bottom = 5.0
	match lbl.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_LEFT:
			bar.anchor_left = 0.0
			bar.anchor_right = 0.0
			bar.offset_left = -6.0
			bar.offset_right = w + 6.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			bar.anchor_left = 1.0
			bar.anchor_right = 1.0
			bar.offset_left = -w - 6.0
			bar.offset_right = 6.0
		_:
			bar.anchor_left = 0.5
			bar.anchor_right = 0.5
			bar.offset_left = -w * 0.5 - 8.0
			bar.offset_right = w * 0.5 + 8.0
	lbl.add_child(bar)
 
 
# ------------------------------------------------------------------ buka / tutup
 
func _on_visibility_changed() -> void:
	var shown := is_visible_in_tree()
	for s in _value_labels:
		_update_value(s as HSlider)           # sinkronkan angka dengan nilai terkini
	_show_dimmer(shown)
	if shown and open_animation:
		_play_open()
 
 
func _play_open() -> void:
	if _open_tween and _open_tween.is_valid():
		_open_tween.kill()
	pivot_offset = size * 0.5
	modulate.a = 0.0
	scale = Vector2(0.88, 0.88)
	var t := create_tween().set_parallel(true)
	_open_tween = t
	t.tween_property(self, "modulate:a", 1.0, 0.18)
	t.tween_property(self, "scale", Vector2.ONE, 0.35) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
 
	# Isi panel masuk berurutan dari atas ke bawah.
	var kids: Array[Control] = []
	for c in get_children():
		if c is Control and (c as Control).visible:
			kids.append(c as Control)
	kids.sort_custom(func(a: Control, b: Control) -> bool:
		return a.position.y < b.position.y or (a.position.y == b.position.y and a.position.x < b.position.x))
	for i in kids.size():
		var k := kids[i]
		k.modulate.a = 0.0
		t.tween_property(k, "modulate:a", 1.0, 0.25).set_delay(0.08 + i * 0.035)
 
 
func _make_dimmer() -> void:
	var p := get_parent()
	if p == null:
		return
	_dimmer = ColorRect.new()
	_dimmer.color = Color(0.0, 0.03, 0.05, 0.5)
	_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP     # menu di belakang tidak bisa diklik
	_dimmer.visible = false
	_dimmer.modulate.a = 0.0
	p.add_child(_dimmer)
	p.move_child(_dimmer, get_index())                   # tepat di bawah panel Settings
	_show_dimmer(is_visible_in_tree())
 
 
func _show_dimmer(on: bool) -> void:
	if _dimmer == null:
		return
	if _dim_tween and _dim_tween.is_valid():
		_dim_tween.kill()
	_dim_tween = create_tween()
	if on:
		_dimmer.visible = true
		_dim_tween.tween_property(_dimmer, "modulate:a", 1.0, 0.2)
	else:
		_dim_tween.tween_property(_dimmer, "modulate:a", 0.0, 0.15)
		_dim_tween.tween_callback(func() -> void: _dimmer.visible = false)
 
 
# ------------------------------------------------------------------ tombol
 
func _setup_buttons() -> void:
	for n in find_children("*", "Button", true, false):
		if n is CheckBox or n is CheckButton:
			continue
		var b := n as Button
		b.pivot_offset = b.size * 0.5
		b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
		b.mouse_entered.connect(_btn_to.bind(b, 1.08, Color(1.15, 1.15, 1.15), 0.14))
		b.mouse_exited.connect(_btn_to.bind(b, 1.0, Color.WHITE, 0.14))
		b.focus_entered.connect(_btn_to.bind(b, 1.08, Color(1.15, 1.15, 1.15), 0.14))
		b.focus_exited.connect(_btn_to.bind(b, 1.0, Color.WHITE, 0.14))
		b.button_down.connect(_btn_to.bind(b, 0.93, Color(0.95, 0.95, 0.95), 0.07))
		b.button_up.connect(func() -> void:
			var hov := b.is_hovered()
			_btn_to(b, 1.08 if hov else 1.0, Color(1.15, 1.15, 1.15) if hov else Color.WHITE, 0.12))
 
 
func _btn_to(b: Button, s: float, col: Color, dur: float) -> void:
	var old: Tween = _btn_tweens.get(b)
	if old and old.is_valid():
		old.kill()
	var t := create_tween().set_parallel(true)
	t.tween_property(b, "scale", Vector2(s, s), dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "modulate", col, dur)
	_btn_tweens[b] = t
 
