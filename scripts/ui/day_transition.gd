extends CanvasLayer
## DayTransition - layar ganti hari.
##   Tidur  : layar menjadi malam berbintang (bulan, "Zzz", rumah kecil) -> fajar, matahari terbit -> "Day N".
##   Pingsan: dunia menyempit seperti lubang (iris) ke hitam -> bintang berputar -> bangun pelan.
## Dipakai GameState: await cover(kind, k) ... ganti hari ... await reveal(kind, title, sub, k) ... await uncover(k).
## k = pengali durasi (kecilkan untuk tes).

const Sfx := preload("res://scripts/audio/sfx.gd")
const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"

const IRIS_SHADER := """
shader_type canvas_item;
uniform float radius = 1.2;
uniform float aspect = 1.78;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	float d = length(p);
	float edge = smoothstep(radius, radius + 0.02, d);
	COLOR = vec4(0.0, 0.0, 0.0, edge);
}
"""


class NightScene extends Control:
	## Kartu kalender: halaman hari lama membalik jadi hari baru + progres menuju 1.000.000 koin + tips.
	## (Tanpa pemandangan: latar gelap hangat, asap tipis, daun melayang.)
	var phase := 0.0               # 0 = awal, 1 = hari baru
	var kind := "sleep_early"
	var t := 0.0
	var font: Font
	var day_from := 1
	var day_to := 2
	var coins := 0
	var goal := 1000000
	var last_day := 30
	var tip := ""
	var puffs: Array = []
	var leaves: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 16:
			puffs.append([rng.randf(), rng.randf(), rng.randf_range(50.0, 120.0), rng.randf_range(0.01, 0.03), rng.randf() * 6.28])
		for i in 22:
			leaves.append([rng.randf(), rng.randf(), rng.randf_range(5.0, 11.0), rng.randf_range(18.0, 46.0), rng.randf() * 6.28, rng.randf()])

	func _process(delta: float) -> void:
		t += delta
		queue_redraw()

	func _f() -> Font:
		return font if font != null else ThemeDB.fallback_font

	func _text(pos: Vector2, s: String, size: int, col: Color, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
		draw_string_outline(_f(), pos, s, align, width, size, maxi(4, size / 8), Color(0.12, 0.06, 0.03, col.a))
		draw_string(_f(), pos, s, align, width, size, col)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var ph := clampf(phase, 0.0, 1.0)
		var e := ph * ph * (3.0 - 2.0 * ph)
		# latar gelap hangat (bukan pemandangan)
		var top := Color(0.04, 0.035, 0.06).lerp(Color(0.16, 0.10, 0.10), e)
		var bot := Color(0.10, 0.07, 0.09).lerp(Color(0.34, 0.20, 0.14), e)
		if kind == "faint":
			top = top.lerp(Color(0.10, 0.02, 0.03), 0.5 * (1.0 - e))
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([top, top, bot, bot]))
		# asap tipis yang naik pelan
		for p in puffs:
			var y: float = fposmod(float(p[1]) - t * float(p[3]), 1.2) - 0.1
			var x: float = float(p[0]) * w + sin(t * 0.3 + float(p[4])) * 40.0
			for k in 3:
				draw_circle(Vector2(x + k * 22.0, h * y + k * 8.0), float(p[2]) * (0.6 + 0.2 * k), Color(0.7, 0.75, 0.8, 0.028))
		# daun melayang
		for l in leaves:
			var ly: float = fposmod(float(l[1]) + t * float(l[3]) / h, 1.1) - 0.05
			var lx: float = float(l[0]) * w + sin(t * 0.9 + float(l[4])) * 36.0
			var a: float = t * 1.2 + float(l[4])
			var sz: float = float(l[2])
			var col := Color(0.45, 0.78, 0.30).lerp(Color(0.96, 0.74, 0.28), float(l[5]))
			col.a = 0.55
			var c := Vector2(lx, h * ly)
			draw_colored_polygon(PackedVector2Array([c + Vector2(cos(a), sin(a)) * sz, c + Vector2(cos(a + 1.7), sin(a + 1.7)) * sz * 0.5, c + Vector2(cos(a + PI), sin(a + PI)) * sz, c + Vector2(cos(a - 1.7), sin(a - 1.7)) * sz * 0.5]), col)
		# kartu kalender
		var s := minf(w / 1152.0, h / 648.0)
		var cw := 430.0 * s
		var ch := 312.0 * s
		var c0 := Vector2(w * 0.5 - cw * 0.5, h * 0.5 - ch * 0.5 + 18.0 * s)
		draw_rect(Rect2(c0 + Vector2(8, 12) * s, Vector2(cw, ch)), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(c0, Vector2(cw, ch)), Color(0.96, 0.92, 0.80))
		draw_rect(Rect2(c0, Vector2(cw, 46.0 * s)), Color(0.62, 0.20, 0.18))
		draw_rect(Rect2(c0, Vector2(cw, ch)), Color(0.35, 0.18, 0.10), false, 3.0 * s)
		for rx in [0.28, 0.72]:
			draw_circle(c0 + Vector2(cw * rx, 0), 9.0 * s, Color(0.18, 0.12, 0.10))
			draw_circle(c0 + Vector2(cw * rx, 0), 4.0 * s, Color(0.7, 0.7, 0.72))
		_text(c0 + Vector2(0, 32.0 * s), "NATURE SPIRIT  -  %d DAYS" % last_day, int(22 * s), Color(1.0, 0.94, 0.78), cw, HORIZONTAL_ALIGNMENT_CENTER)
		# angka hari membalik (lebar mengecil -> halaman baru)
		var flip := clampf((ph - 0.25) / 0.3, 0.0, 1.0)
		var sx := absf(cos(flip * PI))
		var shown := day_from if flip < 0.5 else day_to
		var cc := c0 + Vector2(cw * 0.5, 156.0 * s)
		draw_set_transform(cc, 0.0, Vector2(maxf(sx, 0.03), 1.0))
		var num := str(mini(shown, last_day))
		if shown > last_day:
			num = "!"
		draw_string(_f(), Vector2(-cw * 0.5, 0.0), num, HORIZONTAL_ALIGNMENT_CENTER, cw, int(100 * s), Color(0.28, 0.14, 0.08))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var left := maxi(last_day - mini(shown, last_day), 0)
		draw_string(_f(), c0 + Vector2(0, 200.0 * s), "%d day%s left" % [left, "" if left == 1 else "s"], HORIZONTAL_ALIGNMENT_CENTER, cw, int(24 * s), Color(0.45, 0.25, 0.14))
		# progres menuju target koin
		var bx := c0.x + 28.0 * s
		var bw := cw - 56.0 * s
		var by := c0.y + 224.0 * s
		draw_rect(Rect2(bx, by, bw, 20.0 * s), Color(0.28, 0.18, 0.12, 0.35))
		var frac := clampf(float(coins) / float(goal), 0.0, 1.0)
		var fill := Color(0.35, 0.72, 0.30).lerp(Color(0.95, 0.78, 0.25), frac)
		draw_rect(Rect2(bx, by, bw * frac * minf(1.0, 0.4 + ph * 1.2), 20.0 * s), fill)
		draw_rect(Rect2(bx, by, bw, 20.0 * s), Color(0.35, 0.18, 0.10), false, 2.0 * s)
		draw_string(_f(), Vector2(bx, by + 50.0 * s), "%s / %s coins" % [_fmt(coins), _fmt(goal)], HORIZONTAL_ALIGNMENT_CENTER, bw, int(22 * s), Color(0.28, 0.14, 0.08))
		# ikon kecil di sudut: bulan -> matahari
		var ic := c0 + Vector2(cw - 40.0 * s, 96.0 * s)
		if ph < 0.5:
			draw_circle(ic, 15.0 * s, Color(0.95, 0.9, 0.62))
			draw_circle(ic + Vector2(7, -4) * s, 13.0 * s, Color(0.96, 0.92, 0.80))
		else:
			draw_circle(ic, 14.0 * s, Color(1.0, 0.8, 0.25))
			for i in 8:
				var a := t * 0.5 + float(i) * TAU / 8.0
				draw_line(ic + Vector2(cos(a), sin(a)) * 19.0 * s, ic + Vector2(cos(a), sin(a)) * 26.0 * s, Color(1.0, 0.8, 0.25), 3.0 * s)
		if kind == "faint" and ph < 0.7:                              # stempel merah
			draw_set_transform(c0 + Vector2(cw * 0.32, ch * 0.42), -0.28, Vector2.ONE)
			draw_rect(Rect2(-86 * s, -24 * s, 172 * s, 48 * s), Color(0.8, 0.1, 0.1, 0.7 * (1.0 - ph)), false, 5.0 * s)
			draw_string(_f(), Vector2(-86 * s, 12 * s), "PASSED OUT", HORIZONTAL_ALIGNMENT_CENTER, 172 * s, int(30 * s), Color(0.8, 0.1, 0.1, 0.8 * (1.0 - ph)))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# tips
		if tip != "" and ph > 0.5:
			_text(Vector2(0, c0.y + ch + 56.0 * s), "Tip: " + tip, int(22 * s), Color(1.0, 0.92, 0.7, clampf((ph - 0.5) * 3.0, 0.0, 1.0)), w, HORIZONTAL_ALIGNMENT_CENTER)

	static func _fmt(n: int) -> String:
		var s := str(absi(n))
		var out := ""
		var c := 0
		for i in range(s.length() - 1, -1, -1):
			out = s[i] + out
			c += 1
			if c % 3 == 0 and i > 0:
				out = "." + out
		return out


const TIPS := [
	"Water your crops every day - dry plants don't grow.",
	"Eat at Lily's: three meals a day at most.",
	"Sleep before midnight to wake up fully rested.",
	"Gordon's upgrades make tools faster and cheaper on energy.",
	"1-2 coin piles appear in the forests every day.",
	"Villagers' quests pay well. Check the calendar!",
	"Forget something? Ask Centorea on your farm.",
	"Pricey crops take longer to grow, but pay far more.",
	"Villagers go home at night. Shops are quiet after dark.",
]

var _scene: NightScene
var _iris: ColorRect
var _title: Label
var _sub: Label
var _font: Font
var _root: Control


func _ready() -> void:
	layer = 101
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)
	_scene = NightScene.new()
	_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scene.font = _font
	_scene.modulate.a = 0.0
	_root.add_child(_scene)
	_iris = ColorRect.new()
	_iris.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_iris.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = IRIS_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_iris.material = mat
	_iris.visible = false
	_root.add_child(_iris)
	_title = _make_label(92)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.offset_top = 90
	_title.offset_left = -400
	_title.offset_right = 400
	_sub = _make_label(36)
	_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_sub.offset_top = 70
	_sub.offset_left = -500
	_sub.offset_right = 500
	_root.add_child(_title)
	_root.add_child(_sub)


func _make_label(size: int) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.04))
	l.add_theme_constant_override("outline_size", maxi(8, size / 6))
	if _font:
		l.add_theme_font_override("font", _font)
	l.modulate.a = 0.0
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _set_iris(r: float) -> void:
	(_iris.material as ShaderMaterial).set_shader_parameter("radius", r)
	(_iris.material as ShaderMaterial).set_shader_parameter("aspect", maxf(size_aspect(), 0.1))


func size_aspect() -> float:
	var vs := _root.get_viewport_rect().size
	return vs.x / maxf(vs.y, 1.0)


## Layar menutup. Tidur: memudar ke malam. Pingsan: iris menyempit ke hitam.
func cover(kind: String, k: float) -> void:
	_root.visible = true
	_title.modulate.a = 0.0
	_sub.modulate.a = 0.0
	_scene.kind = kind
	_scene.phase = 0.0
	_scene.day_from = GameState.day
	_scene.day_to = GameState.day + 1
	_scene.coins = GameState.coins
	_scene.goal = GameState.GOAL_COINS
	_scene.last_day = GameState.LAST_DAY
	_scene.tip = TIPS[randi() % TIPS.size()]
	Sfx.play("faint" if kind == "faint" else "sleep")
	if kind == "faint":
		_scene.modulate.a = 0.0
		_iris.visible = true
		_set_iris(1.4)
		var t := create_tween()
		t.tween_method(_set_iris, 1.4, 0.0, 1.7 * k).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await t.finished
		_iris.visible = false
		_scene.modulate.a = 1.0
	else:
		_scene.modulate.a = 0.0
		var t2 := create_tween()
		t2.tween_property(_scene, "modulate:a", 1.0, 0.9 * k)
		await t2.finished
		await get_tree().create_timer(0.7 * k).timeout


## Layar penuh sudah gelap/malam; tampilkan fajar + judul hari.
func reveal(kind: String, title: String, sub: String, k: float) -> void:
	_title.text = ""                       # angka hari sudah ada di kartu kalender
	_sub.text = sub
	_scene.kind = kind
	_scene.coins = GameState.coins
	_scene.day_to = GameState.day
	_scene.tip = TIPS[randi() % TIPS.size()]
	Sfx.play("morning", -2.0)
	var t := create_tween()
	t.tween_property(_scene, "phase", 1.0, (2.6 if kind != "faint" else 3.2) * k)
	var tt := create_tween()
	tt.tween_interval(1.1 * k)
	tt.tween_property(_title, "modulate:a", 1.0, 0.5 * k)
	tt.tween_property(_sub, "modulate:a", 1.0, 0.5 * k)
	await t.finished
	await get_tree().create_timer(1.0 * k).timeout


func uncover(k: float) -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(_scene, "modulate:a", 0.0, 0.8 * k)
	t.tween_property(_title, "modulate:a", 0.0, 0.5 * k)
	t.tween_property(_sub, "modulate:a", 0.0, 0.5 * k)
	await t.finished
	_root.visible = false
	_scene.phase = 0.0
