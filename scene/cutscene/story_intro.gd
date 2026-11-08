extends Control
## Cerita pembuka (gaya film, hanya teks). Dijalankan saat menekan Start di main menu.
## Alur: halaman cerita -> halaman perlengkapan awal -> "HARI 1" -> GameState.new_game() -> Farm.
##
## Kontrol: Space / Enter / klik = lanjut (atau tampilkan semua baris dulu). Esc = lewati semua.
## Ganti bahasa di Inspector (Language), edit isi cerita di PAGES_ID / PAGES_EN di bawah.

const Inv := preload("res://scripts/managers/inventory.gd")
const ItemIcons := preload("res://scripts/managers/item_icons.gd")
const VillageScenery := preload("res://scripts/ui/village_scenery.gd")

enum Lang { INDONESIAN, ENGLISH }
@export var language := Lang.ENGLISH
@export_file("*.tscn") var next_scene := "res://scene/world/village/village.tscn"          # cerita pembuka dimulai di desa (bertemu Mayor)
@export var auto_advance := true
@export var line_delay := 1.35          # jeda antar baris (detik)
@export var hold_time := 2.4            # lama halaman ditahan setelah semua baris muncul
@export var font_path := "res://assets/fonts/Matcha Mint.ttf"
@export_file("*.ogg", "*.mp3") var music_path := "res://audio/music/nature_spirit_story_theme.ogg"
@export_file("*.ogg", "*.mp3") var ambience_path := "res://sounds/chrysalyn-morning-forest-ambience-with-birds-chirping-562428.mp3"

const GOLD := Color(1.0, 0.84, 0.30)
const CREAM := Color(0.97, 0.93, 0.82)
const OUTLINE := Color(0.03, 0.03, 0.05)

## Tiap halaman: lines = teks; "q" = indeks baris yang disorot emas; bg = [warna atas, warna bawah];
## "items" = tampilkan ikon perlengkapan; "title" = kartu judul besar.
const PAGES_ID := [
	{"lines": ["Kota terlalu bising.", "Pekerjaan hilang, tabungan pun habis.", "Yang tersisa hanya sebuah tas dan harapan kecil."],
		"bg": [Color(0.04, 0.05, 0.12), Color(0.10, 0.12, 0.24)]},
	{"lines": ["Bus terakhir berhenti di kaki gunung.", "Di sanalah desa kecil bernama Nature Spirit berada,", "tempat roh alam konon masih menjaga tanah dan hutan."],
		"bg": [Color(0.16, 0.10, 0.26), Color(0.62, 0.36, 0.30)]},
	{"lines": ["Kepala Desa menerimamu dengan tangan terbuka,", "meski kamu datang tanpa tujuan dan tanpa apa-apa.", "Desa ini punya satu syarat untuk orang yang ingin menetap."],
		"bg": [Color(0.22, 0.16, 0.28), Color(0.70, 0.48, 0.32)]},
	{"lines": ["Kumpulkan 1.000.000 koin", "dalam waktu 30 hari."], "q": [0],
		"bg": [Color(0.10, 0.08, 0.14), Color(0.36, 0.22, 0.16)]},
	{"lines": ["Sebuah rumah kosong dan sepetak tanah menunggu di ujung desa.", "Jika berhasil, semuanya menjadi milikmu selamanya.", "Jika tidak, kamu harus pergi."],
		"bg": [Color(0.10, 0.08, 0.14), Color(0.30, 0.20, 0.16)]},
	{"lines": ["Bertanam, memanen, lalu menjual hasil bumi.", "Atau berani masuk ke hutan yang gelap.", "Caranya, kamu yang menentukan."],
		"bg": [Color(0.06, 0.14, 0.12), Color(0.18, 0.36, 0.26)]},
	{"lines": ["Tapi waktu terus berjalan", "dan tubuh membutuhkan istirahat.", "Tidurlah sebelum tengah malam."], "q": [2],
		"bg": [Color(0.04, 0.06, 0.14), Color(0.08, 0.14, 0.26)]},
	{"lines": ["Sebelum berangkat, kamu dibekali perlengkapan awal:"], "items": true,
		"caption": "Hoe, Watering Can, Scythe, Sword, dan 10 benih untuk setiap tanaman",
		"bg": [Color(0.12, 0.20, 0.14), Color(0.34, 0.50, 0.28)]},
	{"lines": ["HARI 1", "Matahari terbit pukul 06:00.", "Kumpulkan 1.000.000 koin."], "title": true,
		"bg": [Color(0.40, 0.58, 0.78), Color(0.98, 0.80, 0.52)]},
]

const PAGES_EN := [
	{"lines": ["The city was too loud.", "Your job is gone, and so are your savings.", "All that's left is a bag and a small hope."],
		"bg": [Color(0.04, 0.05, 0.12), Color(0.10, 0.12, 0.24)]},
	{"lines": ["The last bus stops at the foot of the mountain.", "There lies a small village called Nature Spirit,", "where the spirits of nature are said to still guard the land and forests."],
		"bg": [Color(0.16, 0.10, 0.26), Color(0.62, 0.36, 0.30)]},
	{"lines": ["The Mayor welcomes you with open arms,", "even though you arrive with no plan and nothing to your name.", "The village has just one condition for anyone who wants to stay."],
		"bg": [Color(0.22, 0.16, 0.28), Color(0.70, 0.48, 0.32)]},
	{"lines": ["Earn 1,000,000 coins", "within 30 days."], "q": [0],
		"bg": [Color(0.10, 0.08, 0.14), Color(0.36, 0.22, 0.16)]},
	{"lines": ["An empty house and a patch of land wait at the edge of the village.", "If you succeed, they are yours for good.", "If not, you must leave."],
		"bg": [Color(0.10, 0.08, 0.14), Color(0.30, 0.20, 0.16)]},
	{"lines": ["Plant, harvest, and sell what the earth gives.", "Or dare to enter the dark forests.", "How you do it is up to you."],
		"bg": [Color(0.06, 0.14, 0.12), Color(0.18, 0.36, 0.26)]},
	{"lines": ["But time keeps moving", "and your body needs rest.", "Get to bed before midnight."], "q": [2],
		"bg": [Color(0.04, 0.06, 0.14), Color(0.08, 0.14, 0.26)]},
	{"lines": ["Before setting out, you are given some starting gear:"], "items": true,
		"caption": "Hoe, Watering Can, Scythe, Sword, and 10 seeds of every crop",
		"bg": [Color(0.12, 0.20, 0.14), Color(0.34, 0.50, 0.28)]},
	{"lines": ["DAY 1", "The sun rises at 06:00.", "Earn 1,000,000 coins."], "title": true,
		"bg": [Color(0.40, 0.58, 0.78), Color(0.98, 0.80, 0.52)]},
]

var _font: Font
var _grad := Gradient.new()
var _bg: TextureRect
var _scenery: Control
var _music: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _box: VBoxContainer
var _bars: Array[ColorRect] = []
var _fade: ColorRect
var _hint: Label
var _dots: HBoxContainer
var _page := -1
var _labels: Array[Label] = []
var _extra: Control
var _tween: Tween
var _bg_tween: Tween
var _revealed := true
var _busy := false
var _finished := false


## Kotak ikon item untuk halaman perlengkapan.
class IconBox extends Control:
	var item_id := ""

	func _init(id: String, px: float) -> void:
		item_id = id
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.04, 0.06, 0.65)
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(2)
		sb.border_color = Color(1.0, 0.84, 0.30, 0.55)
		sb.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		var d: Dictionary = Inv.items.get(item_id, {})
		ItemIcons.draw(self, Rect2(Vector2(8, 8), size - Vector2(16, 16)), d.get("kind", "drop"), d.get("shape", ""), d.get("color", Color.WHITE))


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if ResourceLoader.exists(font_path):
		_font = load(font_path)
	_build()
	_start_music()
	_next_page()


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


## Musik tema cerita (dibuat khusus) + suara hutan pelan. Diulang terus sampai cerita selesai.
func _start_music() -> void:
	_music = AudioStreamPlayer.new()
	_music.volume_db = -80.0
	if music_path != "" and ResourceLoader.exists(music_path):
		_music.stream = load(music_path)
	add_child(_music)
	_music.finished.connect(func() -> void: _music.play())
	_ambience = AudioStreamPlayer.new()
	_ambience.volume_db = -80.0
	if ambience_path != "" and ResourceLoader.exists(ambience_path):
		_ambience.stream = load(ambience_path)
	add_child(_ambience)
	_ambience.finished.connect(func() -> void: _ambience.play())
	var t := create_tween().set_parallel(true)
	t.tween_property(_music, "volume_db", -9.0, 3.0)
	t.tween_property(_ambience, "volume_db", -20.0, 3.0)
	if _music.stream:
		_music.play()
	if _ambience.stream:
		_ambience.play()


func _pages() -> Array:
	return PAGES_ID if language == Lang.INDONESIAN else PAGES_EN


# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("ui_cancel"):
		_finish()
		get_viewport().set_input_as_handled()
		return
	var go := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		go = true
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		go = true
	if go:
		get_viewport().set_input_as_handled()
		if not _revealed:
			_reveal_all()
		elif not _busy:
			_next_page()


# ------------------------------------------------------------------ halaman

func _next_page() -> void:
	if _busy or _finished:
		return
	_busy = true
	if _tween and _tween.is_valid():
		_tween.kill()
	# keluar dari halaman lama
	if _page >= 0:
		var out := create_tween().set_parallel(true)
		for l in _labels:
			out.tween_property(l, "modulate:a", 0.0, 0.5)
		if _extra:
			out.tween_property(_extra, "modulate:a", 0.0, 0.5)
		await out.finished
	_clear_page()
	_page += 1
	if _page >= _pages().size():
		_busy = false
		_finish()
		return
	_build_page(_pages()[_page])
	_update_dots()
	_busy = false


func _clear_page() -> void:
	for c in _box.get_children():
		c.queue_free()
	_labels.clear()
	_extra = null


func _build_page(p: Dictionary) -> void:
	var is_title: bool = p.get("title", false)
	var quoted: Array = p.get("q", [])
	var lines: Array = p["lines"]
	for i in lines.size():
		var size := 36
		var col := CREAM
		if i in quoted:
			col = GOLD
			size = 42
		if is_title:
			size = 92 if i == 0 else (34 if i == 1 else 44)
			col = GOLD if i != 1 else CREAM
		var l := _label(String(lines[i]), size, col)
		l.modulate.a = 0.0
		_box.add_child(l)
		_labels.append(l)
	if p.get("items", false):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for id in ["hoe", "watering_can", "scythe", "sword"]:
			row.add_child(IconBox.new(id, 72.0))
		for c in Inv.CROPS:
			row.add_child(IconBox.new(c[0] + "_seed", 72.0))
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 14)
		_box.add_child(gap)
		_box.add_child(row)
		var cap := _label(String(p.get("caption", "")), 26, Color(0.85, 0.92, 0.78))
		_box.add_child(cap)
		row.modulate.a = 0.0
		cap.modulate.a = 0.0
		_extra = row
		_labels.append(cap)
	# warna latar
	var bg: Array = p["bg"]
	if _bg_tween and _bg_tween.is_valid():
		_bg_tween.kill()
	var from_top := _grad.get_color(0)
	var from_bot := _grad.get_color(1)
	var dim := 1.0     # seberapa gelap gradien menutup ilustrasi
	_bg_tween = create_tween()
	_bg_tween.tween_property(_bg, "modulate:a", dim, 1.4)
	_bg_tween.parallel().tween_method(func(t: float) -> void:
		_grad.set_color(0, from_top.lerp(bg[0], t))
		_grad.set_color(1, from_bot.lerp(bg[1], t)), 0.0, 1.0, 1.4)
	# munculkan baris demi baris
	_revealed = false
	_tween = create_tween()
	var t := 0.5
	for l in _labels:
		_tween.parallel().tween_property(l, "modulate:a", 1.0, 0.9).set_delay(t)
		t += line_delay
	if _extra:
		_tween.parallel().tween_property(_extra, "modulate:a", 1.0, 0.9).set_delay(0.8)
	_tween.chain().tween_callback(func() -> void: _revealed = true)
	if auto_advance:
		_tween.chain().tween_interval(hold_time)
		_tween.chain().tween_callback(_next_page)


func _reveal_all() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	var t := create_tween().set_parallel(true)
	for l in _labels:
		t.tween_property(l, "modulate:a", 1.0, 0.2)
	if _extra:
		t.tween_property(_extra, "modulate:a", 1.0, 0.2)
	_revealed = true
	if auto_advance:
		_tween = create_tween()
		_tween.tween_interval(hold_time)
		_tween.tween_callback(_next_page)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if _tween and _tween.is_valid():
		_tween.kill()
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 1.0, 0.7)
	t.parallel().tween_property(_music, "volume_db", -80.0, 0.9)
	t.parallel().tween_property(_ambience, "volume_db", -80.0, 0.9)
	await t.finished
	GameState.new_game()                       # HUD & waktu mulai di sini
	GameState.next_spawn = "from_farm"         # tiba dari jalan selatan desa
	if ResourceLoader.exists(next_scene):
		get_tree().change_scene_to_file(next_scene)
	else:
		push_warning("Scene tujuan tidak ditemukan: %s" % next_scene)


# ------------------------------------------------------------------ bangun

func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(900, 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", maxi(5, size / 6))
	if _font:
		l.add_theme_font_override("font", _font)
	return l


func _update_dots() -> void:
	for i in _dots.get_child_count():
		var d := _dots.get_child(i) as ColorRect
		d.color = GOLD if i == _page else Color(1, 1, 1, 0.25)


func _build() -> void:
	# latar gradasi
	_grad.set_color(0, Color(0.04, 0.05, 0.12))
	_grad.set_color(1, Color(0.10, 0.12, 0.24))
	var gt := GradientTexture2D.new()
	gt.gradient = _grad
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	gt.width = 4
	gt.height = 256
	_bg = TextureRect.new()
	_bg.texture = gt
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	var vp := get_viewport_rect().size
	# asap / kabut tipis yang naik pelan
	var smoke := CPUParticles2D.new()
	smoke.texture = _glow_texture()
	smoke.amount = 16
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
	# daun jatuh (seperti di main menu)
	var leaves := CPUParticles2D.new()
	leaves.texture = _leaf_texture()
	leaves.amount = 30
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
	leaves.scale_amount_max = 2.2
	var lg := Gradient.new()
	lg.colors = PackedColorArray([Color(0.45, 0.82, 0.30), Color(0.96, 0.78, 0.30)])
	leaves.color_initial_ramp = lg
	add_child(leaves)

	# vignette
	var vg := ColorRect.new()
	vg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() { vec2 uv = UV - 0.5; float d = dot(uv, uv) * 2.4; COLOR = vec4(0.0, 0.0, 0.0, clamp(d * 1.1, 0.0, 0.85)); }"
	var smat := ShaderMaterial.new()
	smat.shader = sh
	vg.material = smat
	add_child(vg)

	# teks di tengah
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 22)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_box)

	# bar sinematik atas & bawah
	for top in [true, false]:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.anchor_left = 0.0
		b.anchor_right = 1.0
		b.anchor_top = 0.0 if top else 1.0
		b.anchor_bottom = 0.0 if top else 1.0
		b.offset_top = 0.0 if top else 0.0
		b.offset_bottom = 0.0
		add_child(b)
		_bars.append(b)

	# penunjuk halaman & petunjuk
	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 8)
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.anchor_left = 0.0
	_dots.anchor_right = 1.0
	_dots.anchor_top = 1.0
	_dots.anchor_bottom = 1.0
	_dots.offset_top = -78.0
	_dots.offset_bottom = -66.0
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.visible = false                       # titik halaman dihilangkan
	add_child(_dots)
	for i in _pages().size():
		var d := ColorRect.new()
		d.custom_minimum_size = Vector2(10, 10)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_dots.add_child(d)
	_hint = _label("Space / Esc untuk melewati" if language == Lang.INDONESIAN else "Space / Esc to skip", 18, Color(1, 1, 1, 0.55))
	_hint.custom_minimum_size = Vector2(0, 0)
	_hint.anchor_left = 0.0
	_hint.anchor_right = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = 0.0
	_hint.offset_right = 0.0
	_hint.offset_top = -52.0
	_hint.offset_bottom = -20.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)

	# fade hitam (di paling atas)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_update_bars.call_deferred()
	var t := create_tween()
	t.tween_property(_fade, "modulate:a", 0.0, 1.0)
	resized.connect(_update_bars)


func _update_bars() -> void:
	var h := size.y * 0.11
	_bars[0].offset_bottom = h
	_bars[1].offset_top = -h


func _glow_texture() -> ImageTexture:
	var d := 24
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var c := Vector2(d, d) * 0.5 - Vector2(0.5, 0.5)
	for y in d:
		for x in d:
			var a := clampf(1.0 - Vector2(x, y).distance_to(c) / (d * 0.5), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)
