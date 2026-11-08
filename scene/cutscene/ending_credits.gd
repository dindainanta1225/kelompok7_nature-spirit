extends Control
## Credits setelah ending (Good / Bad): latar HITAM + asap tipis + daun melayang (seperti cerita pembuka),
## isinya sama dengan credits di main menu. Selesai -> kembali ke main menu. Esc / klik = lewati.

const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"
const MUSIC_PATH := "res://audio/music/farran_ez-soft-indie-guitar-sample-456142.mp3"
const MENU := "res://scene/main/mainmenu/main_menu.tscn"
const GOLD := Color(1.0, 0.84, 0.30)
const CREAM := Color(0.97, 0.93, 0.82)

## Isi sama dengan scene/main/Credits/credits.tscn. [teks, jenis]  jenis: "h" judul bagian, "t" teks biasa, "b" jeda
const LINES := [
	["DIREKSI & DESAIN", "h"], ["Game Designer", "t"], ["Dinda", "t"], ["Raihan", "t"], ["", "b"],
	["PEMROGRAMAN", "h"], ["Gameplay & System Programmer", "t"], ["Raihan", "t"], ["Dinda", "t"], ["", "b"],
	["ARTISTIK & VISUAL", "h"], ["3D Character & Environment Artist", "t"], ["Lareina", "t"], ["Dinda", "t"], ["Aura", "t"], ["", "b"],
	["UI/UX Designer", "t"], ["Raihan", "t"], ["", "b"],
	["AUDIO", "h"], ["Lareina", "t"], ["Aura", "t"], ["", "b"],
	["KONTRIBUSI ASET PIHAK KETIGA", "h"], ["Asset 3D & Lingkungan", "t"], ["....", "t"], ["", "b"],
	["Audio & Musik", "t"], ["Ikoliks_aj - background music (pixabay.com)", "t"], ["creatorshome - digital click (pixabay.com)", "t"], ["farran_ez - soft indie guitar sample (pixabay.com)", "t"], ["", "b"],
	["TERIMA KASIH KHUSUS", "h"], ["Guru Pembimbing", "t"], ["Pak Maul", "t"], ["", "b"],
	["SMKN 21 JAKARTA", "t"], ["Komunitas Godot Engine Indonesia", "t"],
]

var good := true
var _font: Font
var _scroll: VBoxContainer
var _speed := 62.0
var _music: AudioStreamPlayer
var _leaving := false
var _fade: ColorRect


func _ready() -> void:
	good = GameState.ending_kind != "bad"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	var bg := ColorRect.new()                                  # hitam
	bg.color = Color.BLACK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_particles()
	_build_text()
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "modulate:a", 0.0, 1.5)
	_music = AudioStreamPlayer.new()
	if ResourceLoader.exists(MUSIC_PATH):
		var st: AudioStream = load(MUSIC_PATH)
		if st is AudioStreamMP3:
			st.loop = true
		_music.stream = st
		_music.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
		_music.volume_db = -80.0
		add_child(_music)
		_music.play()
		create_tween().tween_property(_music, "volume_db", -8.0, 2.5)


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", maxi(4, size / 7))
	if _font:
		l.add_theme_font_override("font", _font)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_text() -> void:
	_scroll = VBoxContainer.new()
	_scroll.add_theme_constant_override("separation", 10)
	_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scroll)
	_scroll.add_child(_label("THE END" if good else "THE END ...for now", 54, GOLD))
	_scroll.add_child(_label("A new keeper for the spirits of nature." if good else "Some roads lead back home.", 26, CREAM))
	_scroll.add_child(Control.new())
	_scroll.add_child(_label("Credits", 40, CREAM))
	_scroll.add_child(_label("NATURE SPIRIT", 56, GOLD))
	for ln in LINES:
		match ln[1]:
			"h":
				_scroll.add_child(_label(ln[0], 32, GOLD))
			"b":
				var sp := Control.new()
				sp.custom_minimum_size = Vector2(0, 30)
				_scroll.add_child(sp)
			_:
				_scroll.add_child(_label(ln[0], 26, CREAM))
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 120)
	_scroll.add_child(sp2)
	_scroll.add_child(_label("Thank you for playing!", 52, GOLD))
	_scroll.add_child(_label("Kelompok 7", 26, CREAM))
	_scroll.resized.connect(_place)
	_place.call_deferred()


func _place() -> void:
	_scroll.size.x = size.x
	_scroll.position = Vector2(0, size.y + 40.0)


func _process(delta: float) -> void:
	if _scroll == null or _leaving:
		return
	var sp := _speed * (4.0 if Input.is_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else 1.0)
	_scroll.position.y -= sp * delta
	if _scroll.position.y + _scroll.size.y < size.y * 0.5:        # "Thank you" sudah di tengah layar -> berhenti, lalu selesai
		_speed = 0.0
		_leave(3.5)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_leave(0.0)


func _leave(wait: float) -> void:
	if _leaving:
		return
	_leaving = true
	await get_tree().create_timer(wait).timeout
	var t := create_tween().set_parallel(true)
	t.tween_property(_fade, "modulate:a", 1.0, 1.2)
	if _music:
		t.tween_property(_music, "volume_db", -80.0, 1.2)
	await t.finished
	GameState.ending_kind = ""
	GameState.quit_to_menu()
	get_tree().change_scene_to_file(MENU)


# ------------------------------------------------------------------ asap & daun (seperti cerita pembuka)
func _particles() -> void:
	var vp := get_viewport_rect().size
	var smoke := CPUParticles2D.new()
	smoke.texture = _glow_texture()
	smoke.amount = 18
	smoke.lifetime = 18.0
	smoke.preprocess = 18.0
	smoke.position = Vector2(vp.x * 0.5, vp.y + 60.0)
	smoke.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke.emission_rect_extents = Vector2(vp.x * 0.6, 20.0)
	smoke.direction = Vector2(0.2, -1.0)
	smoke.spread = 20.0
	smoke.gravity = Vector2.ZERO
	smoke.initial_velocity_min = 14.0
	smoke.initial_velocity_max = 30.0
	smoke.angular_velocity_min = -6.0
	smoke.angular_velocity_max = 6.0
	smoke.scale_amount_min = 5.0
	smoke.scale_amount_max = 9.0
	var sg := Gradient.new()
	sg.colors = PackedColorArray([Color(0.62, 0.70, 0.74, 0.0), Color(0.62, 0.70, 0.74, 0.16), Color(0.62, 0.70, 0.74, 0.0)])
	sg.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	smoke.color_ramp = sg
	add_child(smoke)
	var leaves := CPUParticles2D.new()
	leaves.texture = _leaf_texture()
	leaves.amount = 46
	leaves.lifetime = 11.0
	leaves.preprocess = 11.0
	leaves.position = Vector2(vp.x * 0.5, -30)
	leaves.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	leaves.emission_rect_extents = Vector2(vp.x * 0.62, 4)
	leaves.direction = Vector2(0.4, 1)
	leaves.spread = 25.0
	leaves.gravity = Vector2(14, 6)
	leaves.initial_velocity_min = 28.0
	leaves.initial_velocity_max = 62.0
	leaves.angular_velocity_min = -90.0
	leaves.angular_velocity_max = 90.0
	leaves.scale_amount_min = 1.0
	leaves.scale_amount_max = 2.4
	var lg := Gradient.new()
	lg.colors = PackedColorArray([Color(0.45, 0.82, 0.30), Color(0.96, 0.78, 0.30)])
	leaves.color_initial_ramp = lg
	add_child(leaves)


func _leaf_texture() -> ImageTexture:
	var img := Image.create(18, 10, false, Image.FORMAT_RGBA8)
	for x in 18:
		var tt := (x + 0.5) / 18.0
		var hw := 4.6 * sin(PI * tt)
		for y in 10:
			var d := absf(y + 0.5 - 5.0)
			if d < hw:
				img.set_pixel(x, y, Color(0.20, 0.45, 0.20) if d < 0.6 else Color(1, 1, 1))
	return ImageTexture.create_from_image(img)


func _glow_texture() -> ImageTexture:
	var d := 24
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d, d) * 0.5 - Vector2(0.5, 0.5)
	for y in d:
		for x in d:
			var a := clampf(1.0 - Vector2(x, y).distance_to(c) / (d * 0.5), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)
