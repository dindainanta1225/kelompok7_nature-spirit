extends Control
## Layar pembuka setelah menekan Play: latar hutan + papan nama gantung "Nature Spirit" + musik.
## Otomatis lanjut ke cerita pembuka (story_intro). Space / Esc / Enter / klik = lewati.
## Semua gambar dibuat lewat kode. Dipanggil dari main_menu.gd (tombol Start).
## Ganti nama tim / judul / slogan di Inspector (Studio Name, Game Title, Tagline).

const WoodPanel := preload("res://scripts/managers/wood_panel.gd")
const VillageScenery := preload("res://scripts/ui/village_scenery.gd")

@export var game_title := "Nature Spirit"
@export var tagline := "Tanam. Panen. Jadi bagian desa."
@export_file("*.tscn") var next_scene := "res://scene/cutscene/story_intro.tscn"
@export var font_path := "res://assets/fonts/Matcha Mint.ttf"
@export var auto_continue := true
@export var title_hold := 9.0                       # lama layar judul sebelum otomatis ke menu (detik)
@export_file("*.mp3", "*.ogg") var music_path := "res://audio/music/farran_ez-soft-indie-guitar-sample-456142.mp3"
@export_file("*.mp3", "*.ogg") var ambience_path := "res://sounds/chrysalyn-morning-forest-ambience-with-birds-chirping-562428.mp3"
@export var use_photo := false                      # true = pakai foto latar (Photo Path) alih-alih ilustrasi kode
@export_file("*.jpg", "*.png") var photo_path := "res://assets/MOUNTAIN.jpg"

const GOLD_TOP := Color(1.0, 0.96, 0.62)
const GOLD_BOT := Color(0.96, 0.62, 0.12)
const LIME_TOP := Color(0.84, 1.0, 0.50)
const LIME_BOT := Color(0.26, 0.70, 0.24)
const OUTLINE := Color(0.20, 0.09, 0.03)
const CREAM := Color(1.0, 0.94, 0.78)

const SHINE_SHADER := """
shader_type canvas_item;
uniform float y_top = 0.0;
uniform float y_bot = 100.0;
uniform float x_left = 0.0;
uniform float x_width = 100.0;
uniform vec4 c_top : source_color = vec4(1.0, 0.95, 0.55, 1.0);
uniform vec4 c_bot : source_color = vec4(0.95, 0.62, 0.12, 1.0);
uniform float shine = -1.0;
varying vec2 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy; }
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float g = clamp((wpos.y - y_top) / max(y_bot - y_top, 1.0), 0.0, 1.0);
	vec3 col = mix(c_top.rgb, c_bot.rgb, g);
	float fx = (wpos.x - x_left) / max(x_width, 1.0);
	float band = smoothstep(0.10, 0.0, abs(fx - shine - g * 0.18));
	col += vec3(1.0, 0.97, 0.80) * band * 0.6;
	COLOR = vec4(col, tex.a * COLOR.a);
}
"""

var _font: Font
var _scenery: Control
var _sign: WoodPanel
var _title_words: Array = []
var _orn: Control
var _tag: Label
var _hint: Label
var _fade: ColorRect
var _phase := 0                  # 0 = mulai, 1 = judul, 2 = keluar
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _tween: Tween
var _shaders: Array = []
var _tex_glow: Texture2D


# ================================================================== setup
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ResourceLoader.exists(font_path):
		_font = load(font_path)
	_tex_glow = _glow_texture()
	_build_scenery()
	_build_particles()
	_build_vignette()
	_build_sign()
	_build_hud_bits()
	_start_music()
	_play_title()


func _process(delta: float) -> void:
	if _phase == 1:
		_update_shader_bounds()
		_orn.queue_redraw()


func _input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventKey and event.pressed and not event.echo:
		pressed = event.keycode in [KEY_SPACE, KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER]
	elif event is InputEventMouseButton and event.pressed:
		pressed = true
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	_go_menu()


# ------------------------------------------------------------------ pembangun elemen
func _label(text: String, px: int, col: Color, outline := true) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", px)
	l.add_theme_color_override("font_color", col)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0.10, 0.05, 0.02))
		l.add_theme_constant_override("outline_size", maxi(4, px / 8))
	if _font:
		l.add_theme_font_override("font", _font)
	return l


func _build_scenery() -> void:
	_scenery = VillageScenery.new()
	_scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if use_photo and ResourceLoader.exists(photo_path):
		_scenery.photo = load(photo_path)
	_scenery.modulate.a = 0.0
	add_child(_scenery)


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


func _glow_texture() -> Texture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t


func _build_particles() -> void:
	var vp := get_viewport_rect().size
	# daun melayang
	var leaves := CPUParticles2D.new()
	leaves.texture = _leaf_texture()
	leaves.amount = 26
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
	leaves.scale_amount_max = 2.0
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(0.45, 0.82, 0.30), Color(0.96, 0.78, 0.30)])
	leaves.color_initial_ramp = gr
	add_child(leaves)


func _build_vignette() -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.02, 0.05, 0.03, 0.62)])
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.85)
	t.width = 256
	t.height = 256
	var v := TextureRect.new()
	v.texture = t
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(v)


## Papan kayu gantung berisi judul, slogan, dan ornamen daun.
func _build_sign() -> void:
	var vp := get_viewport_rect().size
	_sign = WoodPanel.new()
	_sign.wood = Color(0.40, 0.25, 0.13)
	_sign.seed_value = 33
	_sign.margin = 36
	_sign.corner_radius = 20
	_sign.ropes = true
	_sign.rope_length = 900.0
	_sign.leaves = true
	_sign.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_sign.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_sign)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sign.add_child(v)
	var words := HBoxContainer.new()
	words.add_theme_constant_override("separation", 26)
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(words)
	var px := int(clampf(vp.y * 0.15, 72.0, 160.0))
	var parts := game_title.split(" ")
	for i in parts.size():
		var top := LIME_TOP if i == 0 else GOLD_TOP
		var bot := LIME_BOT if i == 0 else GOLD_BOT
		var w := _make_word(parts[i], px, top, bot)
		words.add_child(w)
		_title_words.append(w)
	_tag = _label(tagline, int(clampf(vp.y * 0.036, 22.0, 40.0)), CREAM)
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_tag)
	_sign.visible = false
	# ornamen daun di kiri-kanan papan
	_orn = Control.new()
	_orn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_orn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orn.draw.connect(_draw_sign_ornaments)
	_orn.modulate.a = 0.0
	add_child(_orn)


func _make_word(text: String, px: int, top: Color, bot: Color) -> Control:
	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := _label(text, px, OUTLINE, false)
	back.add_theme_color_override("font_outline_color", OUTLINE)
	back.add_theme_constant_override("outline_size", maxi(14, px / 6))
	var shadow := _label(text, px, Color(0, 0, 0, 0.45), false)
	shadow.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.45))
	shadow.add_theme_constant_override("outline_size", maxi(14, px / 6))
	var front := _label(text, px, Color.WHITE, false)
	var sh := Shader.new()
	sh.code = SHINE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("c_top", top)
	mat.set_shader_parameter("c_bot", bot)
	front.material = mat
	_shaders.append([mat, front])
	var ms := front.get_minimum_size()
	stack.custom_minimum_size = ms
	shadow.position = Vector2(0, 8)
	for l in [shadow, back, front]:
		(l as Label).size = ms
		stack.add_child(l)
	stack.pivot_offset = ms * 0.5
	stack.modulate.a = 0.0
	return stack


## Ukuran tiap kata dihitung ulang setelah masuk tree (supaya font sudah terpasang).
func _fit_words() -> void:
	for w in _title_words:
		var stack := w as Control
		var front := stack.get_child(2) as Label
		var ms := front.get_minimum_size()
		stack.custom_minimum_size = ms
		stack.size = ms
		for l in stack.get_children():
			(l as Control).size = ms
		stack.pivot_offset = ms * 0.5


func _update_shader_bounds() -> void:
	for e in _shaders:
		var mat: ShaderMaterial = e[0]
		var l: Label = e[1]
		var r := l.get_global_rect()
		mat.set_shader_parameter("y_top", r.position.y + r.size.y * 0.12)
		mat.set_shader_parameter("y_bot", r.end.y - r.size.y * 0.06)
		mat.set_shader_parameter("x_left", r.position.x)
		mat.set_shader_parameter("x_width", r.size.x)


func _draw_sign_ornaments() -> void:
	if _sign == null:
		return
	var r := _sign.get_global_rect()
	var leaf := [Color(0.30, 0.62, 0.28), Color(0.40, 0.74, 0.32), Color(0.22, 0.50, 0.24), Color(0.52, 0.82, 0.38)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for side in [-1.0, 1.0]:
		var anchor := Vector2(r.position.x if side < 0.0 else r.end.x, r.position.y + r.size.y * 0.55)
		# sulur melengkung
		var pts := PackedVector2Array()
		for i in 21:
			var t := i / 20.0
			pts.append(anchor + Vector2(side * (t * 120.0 + 8.0), -sin(t * PI) * 70.0 + t * 50.0))
		_orn.draw_polyline(pts, Color(0.18, 0.40, 0.18), 5.0, true)
		_orn.draw_polyline(pts, Color(0.36, 0.66, 0.30), 2.5, true)
		for i in range(2, 21, 3):
			var p := pts[i]
			var dir := 1.0 if (i / 3) % 2 == 0 else -1.0
			var ang := (-PI * 0.5 + dir * 0.9) if side > 0.0 else (-PI * 0.5 - dir * 0.9)
			var lp := WoodPanel.leaf_points(p, ang, rng.randf_range(34.0, 52.0), rng.randf_range(15.0, 22.0))
			var col: Color = leaf[rng.randi() % leaf.size()]
			_orn.draw_colored_polygon(lp, col)
			_orn.draw_line(p, p + Vector2(34.0, 0).rotated(ang), col.darkened(0.4), 1.5)
		# bunga kecil di ujung
		var tip := pts[20]
		for k in 6:
			var a := k * TAU / 6.0
			_orn.draw_circle(tip + Vector2(cos(a), sin(a)) * 8.0, 6.0, Color(1.0, 0.86, 0.90))
		_orn.draw_circle(tip, 5.5, Color(1.0, 0.82, 0.30))
	# garis emas di bawah judul
	var yy := r.end.y + 16.0
	var mid := r.position.x + r.size.x * 0.5
	_orn.draw_line(Vector2(mid - 160, yy), Vector2(mid + 160, yy), Color(1.0, 0.84, 0.30, 0.0), 1.0)


func _build_hud_bits() -> void:
	_hint = _label("Space / Esc to skip", 24, CREAM)
	_hint.anchor_left = 0.5
	_hint.anchor_right = 0.5
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_top = -64.0
	_hint.offset_bottom = -20.0
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.modulate.a = 0.0
	add_child(_hint)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


# ================================================================== urutan
func _kill() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()


func _play_title() -> void:
	if _phase >= 1:
		return
	_phase = 1
	_kill()
	_sign.visible = true
	_fade.color.a = 1.0
	await get_tree().process_frame
	_fit_words()
	await get_tree().process_frame
	await get_tree().process_frame
	var final_y := size.y * 0.12
	_sign.position.y = final_y - 700.0
	_orn.queue_redraw()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_fade, "color:a", 0.0, 1.6)
	_tween.tween_property(_scenery, "modulate:a", 1.0, 1.6)
	_tween.tween_property(_sign, "position:y", final_y, 1.3).set_delay(0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	for i in _title_words.size():
		var w: Control = _title_words[i]
		w.scale = Vector2(0.55, 0.55)
		_tween.tween_property(w, "modulate:a", 1.0, 0.5).set_delay(1.9 + i * 0.35)
		_tween.tween_property(w, "scale", Vector2.ONE, 0.6).set_delay(1.9 + i * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tag.modulate.a = 0.0
	_tween.tween_property(_tag, "modulate:a", 1.0, 0.8).set_delay(2.9)
	_tween.tween_property(_orn, "modulate:a", 1.0, 0.9).set_delay(2.4)
	_tween.tween_property(_hint, "modulate:a", 0.9, 0.6).set_delay(3.6)
	_tween.chain().tween_callback(_start_loops)


func _start_loops() -> void:
	var blink := create_tween().set_loops()
	blink.tween_property(_hint, "modulate:a", 0.25, 0.9)
	blink.tween_property(_hint, "modulate:a", 0.95, 0.9)
	var sweep := create_tween().set_loops()
	for e in _shaders:
		(e[0] as ShaderMaterial).set_shader_parameter("shine", -0.4)
	sweep.tween_method(func(v: float) -> void:
		for e in _shaders:
			(e[0] as ShaderMaterial).set_shader_parameter("shine", v), -0.4, 1.4, 1.6)
	sweep.tween_interval(1.8)
	if auto_continue:
		var t := create_tween()
		t.tween_interval(title_hold)
		t.tween_callback(_go_menu)


func _start_music() -> void:
	# pemutar ditaruh di root supaya musik tetap jalan ke cerita pembuka (dihentikan lewat SplashMusic.fade_out)
	var root := get_tree().root
	var old := root.get_node_or_null("SplashMusic")
	if old:
		old.queue_free()
	_music = AudioStreamPlayer.new()
	_music.name = "SplashMusic"
	if music_path != "" and ResourceLoader.exists(music_path):
		_music.stream = load(music_path)
	_music.volume_db = -80.0
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child.call_deferred(_music)
	_music.finished.connect(func() -> void: _music.play())      # ulang terus
	_ambience = AudioStreamPlayer.new()
	if ambience_path != "" and ResourceLoader.exists(ambience_path):
		_ambience.stream = load(ambience_path)
	_ambience.volume_db = -80.0
	add_child(_ambience)
	var t := create_tween().set_parallel(true)
	t.tween_property(_music, "volume_db", -8.0, 2.5)
	t.tween_property(_ambience, "volume_db", -16.0, 2.5)
	if _music.stream:
		_music.play.call_deferred()
	if _ambience.stream:
		_ambience.play()


func _go_menu() -> void:
	if _phase >= 2:
		return
	_phase = 2
	_kill()
	var t := create_tween()
	t.tween_property(_fade, "color:a", 1.0, 0.6)
	if _ambience:
		t.parallel().tween_property(_ambience, "volume_db", -80.0, 0.6)
	t.tween_callback(func() -> void:
		if next_scene != "" and ResourceLoader.exists(next_scene):
			get_tree().change_scene_to_file(next_scene))
