extends Control
## MenuFX - efek tambahan untuk main menu tanpa mengubah node lain.
##
## PASANG:
##  1. Add Node > Control, namai "MenuFX", attach script ini.
##  2. Taruh MenuFX tepat DI BAWAH node Background (urutan: Background, MenuFX,
##     MainButtons, Title ...) supaya efek berada di atas gambar tapi di bawah UI.
##  3. Kalau nama node-mu beda, ubah path di grup "Node target" lewat Inspector.
##
## Setiap efek bisa dimatikan satu per satu di Inspector.
 
@export_group("Node target (path relatif dari MenuFX)")
@export var background_path: NodePath = ^"../Background"
@export var buttons_path: NodePath = ^"../MainButtons"
@export var title_path: NodePath = ^"../Title"
 
@export_group("Aktifkan efek")
## Centang untuk scene tanpa tombol/judul yang perlu dianimasikan (misal credits):
## hanya efek latar (daun, kunang-kunang, sinar, vignette, sparkle klik) yang aktif.
@export var ambient_only := false
@export var intro_animation := true     # fade-in, judul jatuh, tombol muncul satu per satu
@export var button_animation := true    # hover: membesar + miring + terang, klik: menekan
@export var title_animation := true     # judul melayang, miring tipis, kilau emas menyapu
@export var mouse_parallax := true      # background bergeser pelan mengikuti mouse
@export var light_rays := true          # sinar matahari menembus pohon
@export var leaves := true              # daun berguguran tertiup angin
@export var fireflies := true           # kunang-kunang / serbuk sari bercahaya
@export var vignette := true            # tepi layar sedikit gelap
@export var click_sparkles := true      # percikan emas saat klik
 
@export_group("Pengaturan")
@export var pixel_scale := 3.0          # ukuran "piksel" daun, sesuaikan dengan art-mu
@export var parallax_strength := 14.0   # maksimal geseran background (px)
@export var leaf_amount := 20
@export var firefly_amount := 28
@export var hover_scale := 1.08
 
@export_group("Suara (opsional, kosongkan kalau sudah diurus script lain)")
@export var hover_sound: AudioStreamPlayer
@export var click_sound: AudioStreamPlayer
 
const LEAF := [
	"..##",
	".###",
	"###.",
	"o#..",
]
 
const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float strength = 0.5;
void fragment() {
	vec2 uv = UV - 0.5;
	float d = length(uv * vec2(1.0, 0.95));
	float v = smoothstep(0.30, 0.85, d);
	COLOR = vec4(0.02, 0.05, 0.08, v * strength);
}
"""
 
# Kilau emas yang menyapu judul. Hanya piksel terang (isi huruf) yang berubah,
# outline gelap tetap.
const SHINE_SHADER := """
shader_type canvas_item;
uniform vec2 x_range = vec2(0.0, 1000.0);
uniform float y0 = 0.0;
uniform float interval = 4.5;
uniform float band = 46.0;
uniform vec3 shine_color : source_color = vec3(1.0, 0.8, 0.25);
varying vec2 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	float ph = fract(TIME / interval) / 0.4;
	float center = mix(x_range.x - band, x_range.y + band, clamp(ph, 0.0, 1.0));
	float d = wpos.x + (wpos.y - y0) * 0.5;
	float k = smoothstep(band, 0.0, abs(d - center)) * step(ph, 1.0);
	float lum = dot(COLOR.rgb, vec3(0.3333));
	k *= smoothstep(0.45, 0.85, lum);
	COLOR.rgb = mix(COLOR.rgb, shine_color, k * 0.95);
}
"""
 
var _bg: Control
var _title: Control
var _buttons: Array[Control] = []
var _tweens: Dictionary = {}
var _t := 0.0
var _par := Vector2.ZERO
var _bg_off := Vector2.ZERO
var _title_off := Vector2.ZERO
var _title_intro_y := 0.0
var _rays: Array[Polygon2D] = []
var _leaf_particles: CPUParticles2D
var _sparkles: CPUParticles2D
var _top_layer: CanvasLayer
var _fade: ColorRect
var _title_mat: ShaderMaterial
var _intro_done := false
 
 
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ambient_only:
		intro_animation = false
		button_animation = false
		title_animation = false
		mouse_parallax = false
 
	_bg = get_node_or_null(background_path) as Control
	_title = get_node_or_null(title_path) as Control
	var box := get_node_or_null(buttons_path)
	if box:
		for c in box.get_children():
			if c is Control:
				_buttons.append(c as Control)
 
	_top_layer = CanvasLayer.new()
	_top_layer.layer = 10
	add_child(_top_layer)
 
	if light_rays:
		_make_light_rays()
	if leaves:
		_make_leaves()
	if fireflies:
		_make_fireflies()
	if vignette:
		_make_vignette()
	if click_sparkles:
		_make_sparkles()
	if button_animation:
		_setup_buttons()
	if title_animation:
		_setup_title()
	if intro_animation:
		_prepare_intro()
 
	# Tunggu satu frame supaya container selesai menghitung ukuran.
	await get_tree().process_frame
	_refresh_pivots()
	if intro_animation:
		_run_intro()
	else:
		_intro_done = true
 
 
# ------------------------------------------------------------------ per frame
 
func _process(delta: float) -> void:
	_t += delta
	var vp := get_viewport_rect().size
	var m := get_viewport().get_mouse_position()
	var n := (m / vp - Vector2(0.5, 0.5)).clamp(Vector2(-0.5, -0.5), Vector2(0.5, 0.5))
	_par = _par.lerp(n, 1.0 - exp(-4.0 * delta))
 
	if mouse_parallax and _bg:
		var off := -_par * parallax_strength * 2.0
		off.y *= 0.6
		_bg.position += off - _bg_off
		_bg_off = off
 
	if title_animation and _title:
		var off := Vector2(
			-_par.x * 10.0,
			sin(_t * 1.6) * 5.0 - _par.y * 6.0 + _title_intro_y)
		_title.position += off - _title_off
		_title_off = off
		_title.rotation_degrees = sin(_t * 0.9) * 0.7
		var s := 1.0 + sin(_t * 1.3) * 0.012
		_title.scale = Vector2(s, s)
 
	for r in _rays:
		var phase: float = r.get_meta("phase")
		var base: float = r.get_meta("base")
		r.self_modulate.a = base * (0.55 + 0.45 * sin(_t * 0.7 + phase))
		r.position.x = sin(_t * 0.25 + phase) * 22.0
 
	if _leaf_particles:
		# Angin berhembus berubah-ubah: daun melambat dan mempercepat.
		_leaf_particles.gravity.x = 12.0 + 16.0 * sin(_t * 0.45)
 
 
func _input(event: InputEvent) -> void:
	if _sparkles and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_sparkles.position = mb.position
			_sparkles.restart()
 
 
# ------------------------------------------------------------------ efek latar
 
func _make_light_rays() -> void:
	var vp := get_viewport_rect().size
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var specs := [[0.38, 90.0, 0.16], [0.52, 140.0, 0.12], [0.66, 70.0, 0.18], [0.80, 110.0, 0.10]]
	var warm := Color(1.0, 0.95, 0.7, 1.0)
	var clear := Color(1.0, 0.95, 0.7, 0.0)
	for s in specs:
		var x0: float = vp.x * s[0]
		var w0: float = s[1]
		var skew := vp.y * 0.5
		var phase := randf() * TAU
		# 3 lapis (lebar -> sempit) ditumpuk additive supaya tepi sinar lembut.
		for layer in 3:
			var w := w0 * (1.0 - layer * 0.32)
			var x := x0 + (w0 - w) * 0.5
			var poly := Polygon2D.new()
			poly.polygon = PackedVector2Array([
				Vector2(x, -10), Vector2(x + w, -10),
				Vector2(x + w * 1.8 - skew, vp.y), Vector2(x - skew, vp.y)])
			poly.vertex_colors = PackedColorArray([warm, warm, clear, clear])
			poly.material = mat
			poly.set_meta("base", float(s[2]) * 0.55)
			poly.set_meta("phase", phase)
			add_child(poly)
			_rays.append(poly)
 
 
func _make_leaves() -> void:
	var vp := get_viewport_rect().size
	var colors := Gradient.new()
	colors.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	colors.offsets = PackedFloat32Array([0.0, 0.3, 0.55, 0.8])
	colors.colors = PackedColorArray([
		Color(0.45, 0.78, 0.25), Color(0.65, 0.85, 0.3),
		Color(0.95, 0.75, 0.2), Color(0.85, 0.45, 0.15)])
 
	var p := CPUParticles2D.new()
	p.texture = _pixel_texture(LEAF)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.amount = leaf_amount
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.position = Vector2(vp.x * 0.3, -30.0)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(vp.x * 0.6, 10.0)
	p.direction = Vector2(1.0, 1.0)
	p.spread = 25.0
	p.initial_velocity_min = 25.0
	p.initial_velocity_max = 55.0
	p.gravity = Vector2(12.0, 10.0)
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.angular_velocity_min = -120.0
	p.angular_velocity_max = 120.0
	p.scale_amount_min = pixel_scale * 0.9
	p.scale_amount_max = pixel_scale * 1.4
	p.color_initial_ramp = colors
	add_child(p)
	_leaf_particles = p
 
 
func _make_fireflies() -> void:
	var vp := get_viewport_rect().size
	var glow_grad := Gradient.new()
	glow_grad.offsets = PackedFloat32Array([0.0, 1.0])
	glow_grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = glow_grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 16
	tex.height = 16
 
	var life := Gradient.new()
	life.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	life.colors = PackedColorArray([
		Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
 
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
 
	var p := CPUParticles2D.new()
	p.texture = tex
	p.material = mat
	p.amount = firefly_amount
	p.lifetime = 8.0
	p.lifetime_randomness = 0.5
	p.preprocess = 8.0
	p.position = Vector2(vp.x * 0.5, vp.y * 0.68)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(vp.x * 0.5, vp.y * 0.28)
	p.direction = Vector2(0.0, -1.0)
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 14.0
	p.gravity = Vector2(0.0, -3.0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	p.color = Color(1.0, 0.92, 0.45)
	p.color_ramp = life
	add_child(p)
 
 
func _make_vignette() -> void:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	add_child(rect)
 
 
func _make_sparkles() -> void:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
 
	var p := CPUParticles2D.new()
	p.texture = ImageTexture.create_from_image(img)
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.one_shot = true
	p.emitting = false
	p.amount = 14
	p.explosiveness = 1.0
	p.lifetime = 0.6
	p.direction = Vector2(0.0, -1.0)
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 150.0
	p.gravity = Vector2(0.0, 260.0)
	p.scale_amount_min = pixel_scale
	p.scale_amount_max = pixel_scale * 1.8
	p.scale_amount_curve = curve
	p.color = Color(1.0, 0.85, 0.3)
	_top_layer.add_child(p)
	_sparkles = p
 
 
# ------------------------------------------------------------------ judul
 
func _setup_title() -> void:
	if _title == null:
		return
	var shader := Shader.new()
	shader.code = SHINE_SHADER
	_title_mat = ShaderMaterial.new()
	_title_mat.shader = shader
	_title.material = _title_mat
	_title.resized.connect(_refresh_pivots)
 
 
func _update_shine_range() -> void:
	if _title_mat == null or _title == null:
		return
	var r := _title.get_global_rect()
	var x0 := r.position.x
	var x1 := r.end.x
	if _title is Label:
		# Sapuan hanya selebar teks, bukan selebar label.
		var w := _title.get_minimum_size().x
		x0 = r.get_center().x - w * 0.5
		x1 = x0 + w
	_title_mat.set_shader_parameter("x_range", Vector2(x0, x1))
	_title_mat.set_shader_parameter("y0", r.position.y)
 
 
# ------------------------------------------------------------------ tombol
 
func _setup_buttons() -> void:
	for b in _buttons:
		b.resized.connect(_refresh_pivots)
		b.mouse_entered.connect(_set_hover.bind(b, true))
		b.mouse_exited.connect(_set_hover.bind(b, false))
		b.focus_entered.connect(_set_hover.bind(b, true))
		b.focus_exited.connect(_set_hover.bind(b, false))
		if b is BaseButton:
			var bb := b as BaseButton
			bb.button_down.connect(_on_down.bind(b))
			bb.button_up.connect(_on_up.bind(b))
			bb.pressed.connect(_on_pressed)
 
 
func _set_hover(b: Control, on: bool) -> void:
	if not _intro_done:
		return
	var tilt := -1.6 if _buttons.find(b) % 2 == 0 else 1.6
	var bright := Color(1.15, 1.15, 1.15, 1.0)
	_tween_button(b, hover_scale if on else 1.0, tilt if on else 0.0,
		bright if on else Color.WHITE, 0.16)
	if on and hover_sound:
		hover_sound.pitch_scale = randf_range(0.95, 1.1)
		hover_sound.play()
 
 
func _on_down(b: Control) -> void:
	if _intro_done:
		_tween_button(b, 0.93, 0.0, Color(0.95, 0.95, 0.95, 1.0), 0.07)
 
 
func _on_up(b: Control) -> void:
	if not _intro_done:
		return
	var hovered: bool = (b as BaseButton).is_hovered() or b.has_focus()
	_tween_button(b, hover_scale if hovered else 1.0, 0.0,
		Color(1.15, 1.15, 1.15, 1.0) if hovered else Color.WHITE, 0.12)
 
 
func _on_pressed() -> void:
	if click_sound:
		click_sound.pitch_scale = randf_range(0.97, 1.05)
		click_sound.play()
 
 
func _tween_button(b: Control, s: float, rot: float, col: Color, dur: float) -> void:
	var old: Tween = _tweens.get(b)
	if old and old.is_valid():
		old.kill()
	var t := create_tween().set_parallel(true)
	t.tween_property(b, "scale", Vector2(s, s), dur) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "rotation_degrees", rot, dur) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(b, "modulate", col, dur)
	_tweens[b] = t
 
 
# ------------------------------------------------------------------ intro
 
func _prepare_intro() -> void:
	for b in _buttons:
		b.scale = Vector2.ZERO
		b.modulate.a = 0.0
	if _title:
		_title.modulate.a = 0.0
		_title_intro_y = -90.0
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_layer.add_child(_fade)
 
 
func _run_intro() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(_fade, "modulate:a", 0.0, 0.6)
	if _title:
		t.tween_property(self, "_title_intro_y", 0.0, 0.9) \
			.set_delay(0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		t.tween_property(_title, "modulate:a", 1.0, 0.35).set_delay(0.2)
	for i in _buttons.size():
		var b := _buttons[i]
		var delay := 0.65 + i * 0.12
		t.tween_property(b, "scale", Vector2.ONE, 0.45) \
			.set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(b, "modulate:a", 1.0, 0.2).set_delay(delay)
	await t.finished
	_fade.queue_free()
	_intro_done = true
 
 
# ------------------------------------------------------------------ util
 
func _refresh_pivots() -> void:
	if _bg:
		_bg.pivot_offset = _bg.size * 0.5
		if mouse_parallax:
			_bg.scale = Vector2(1.04, 1.04)       # sedikit diperbesar agar tepi tak terlihat saat bergeser
	if _title:
		_title.pivot_offset = _title.size * 0.5
		_update_shine_range()
	for b in _buttons:
		b.pivot_offset = b.size * 0.5
 
 
func _pixel_texture(rows: Array) -> ImageTexture:
	var h := rows.size()
	var w: int = rows[0].length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var ch: String = rows[y][x]
			match ch:
				"#":
					img.set_pixel(x, y, Color(1, 1, 1, 1))
				"o":
					img.set_pixel(x, y, Color(0.7, 0.7, 0.7, 1))
				_:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
 
