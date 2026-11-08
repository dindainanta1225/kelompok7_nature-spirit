extends PanelContainer
## WoodPanel - papan kayu realistis yang digambar lewat kode: tekstur serat kayu (noise), sambungan papan,
## pencahayaan atas-bawah, bevel, paku logam, tali berpilin, daun bergradasi, bayangan lembut.
## Dipakai oleh HUD, menu Pause, inventori, kalender, peta, dll. Tidak butuh file gambar.
##
## Pakai: var p = WoodPanel.new(); p.ropes = true; p.margin = 12; lalu add_child isi ke p.
## Tombol bergaya kayu: WoodPanel.style_button(button)  (dipakai main menu lewat HUD).

@export var wood := Color(0.40, 0.25, 0.13)
@export var seed_value := 1
@export var nails := true
@export var ropes := false          # tergantung dari tepi atas layar
@export var rope_length := 30.0
@export var leaves := false         # daun di sudut kiri-atas dan kanan-bawah
@export var corner_radius := 10
@export var margin := 12

const BORDER := Color(0.10, 0.05, 0.02)
const ROPE := Color(0.74, 0.58, 0.36)
const LEAF_COLORS := [Color(0.30, 0.62, 0.28), Color(0.40, 0.74, 0.32), Color(0.22, 0.50, 0.24), Color(0.52, 0.82, 0.38)]
const TEX_W := 512
const TEX_H := 256

static var _grain_tex: ImageTexture
static var _btn_cache := {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func _ready() -> void:
	var e := StyleBoxEmpty.new()
	e.set_content_margin_all(float(margin))
	add_theme_stylebox_override("panel", e)
	resized.connect(queue_redraw)
	queue_redraw()


# ------------------------------------------------------------------ tekstur kayu
## Tekstur abu-abu serat kayu (dibuat sekali, dipakai semua panel). Nilai 0.55..1.0, dikalikan warna kayu.
static func grain_texture() -> ImageTexture:
	if _grain_tex:
		return _grain_tex
	var img := Image.create(TEX_W, TEX_H, false, Image.FORMAT_RGBA8)
	var n1 := FastNoiseLite.new()
	n1.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n1.seed = 11
	n1.frequency = 1.0
	var n2 := FastNoiseLite.new()
	n2.noise_type = FastNoiseLite.TYPE_PERLIN
	n2.seed = 29
	n2.frequency = 1.0
	var knots := [Vector2(110, 60), Vector2(380, 150), Vector2(250, 215)]
	for y in TEX_H:
		for x in TEX_W:
			var yy := float(y)
			# lengkung serat di sekitar mata kayu
			for k in knots:
				var d: Vector2 = Vector2(x, y) - k
				var dist := d.length()
				if dist < 34.0:
					yy += (34.0 - dist) * 0.55 * signf(d.y + 0.001) * exp(-dist * 0.04)
			var g := n1.get_noise_2d(x * 0.012, yy * 0.22)            # serat memanjang horizontal
			var fine := n2.get_noise_2d(x * 0.06, yy * 0.9)           # serat halus
			var v := 0.78 + g * 0.20 + fine * 0.10
			if fposmod(yy, 64.0) < 2.0:                              # sambungan papan
				v *= 0.55
			elif fposmod(yy, 64.0) < 3.5:
				v *= 1.08
			for k in knots:
				var dd: float = (Vector2(x, y) - k).length()
				if dd < 7.0:
					v *= 0.62 + dd * 0.03
				elif dd < 11.0:
					v *= 0.9
			v = clampf(v, 0.4, 1.1)
			img.set_pixel(x, y, Color(v, v, v, 1.0))
	_grain_tex = ImageTexture.create_from_image(img)
	return _grain_tex


# ------------------------------------------------------------------ tombol kayu
## Ubah Button jadi papan kayu (normal / hover / pressed / disabled) dengan font krem.
static func style_button(b: Button, base := Color(0.46, 0.29, 0.15)) -> void:
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxTexture.new()
		sb.texture = _button_texture(st, base)
		sb.set_texture_margin_all(22.0)
		sb.set_content_margin(SIDE_LEFT, 20.0)
		sb.set_content_margin(SIDE_RIGHT, 20.0)
		sb.set_content_margin(SIDE_TOP, 8.0)
		sb.set_content_margin(SIDE_BOTTOM, 10.0)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78))
	b.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.45))
	b.add_theme_color_override("font_pressed_color", Color(0.95, 0.85, 0.6))
	b.add_theme_color_override("font_disabled_color", Color(0.6, 0.52, 0.4))
	b.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.03))
	b.add_theme_constant_override("outline_size", 6)


static func _button_texture(state: String, base: Color) -> ImageTexture:
	var key := "%s_%s" % [state, base.to_html()]
	if _btn_cache.has(key):
		return _btn_cache[key]
	var w := 160
	var h := 64
	var r := 16.0
	var src := grain_texture().get_image()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var tint := base
	var lift := 0.0
	match state:
		"hover", "focus":
			tint = base.lightened(0.18)
			lift = 0.05
		"pressed":
			tint = base.darkened(0.22)
			lift = -0.08
		"disabled":
			tint = base.darkened(0.4).lerp(Color(0.4, 0.4, 0.4), 0.5)
	for y in h:
		for x in w:
			# jarak ke tepi bulat
			var cx := clampf(float(x), r, w - r)
			var cy := clampf(float(y), r, h - r)
			var d := Vector2(x - cx, y - cy).length()
			if d > r:
				continue
			var alpha := clampf(r - d + 0.5, 0.0, 1.0)
			var g: float = src.get_pixel(x * 3 % TEX_W, (y * 3 + 40) % TEX_H).r
			var light := 1.0 + 0.30 * (1.0 - float(y) / h) - 0.30 * (float(y) / h) + lift
			var c := Color(tint.r * g * 1.7 * light, tint.g * g * 1.7 * light, tint.b * g * 1.7 * light, alpha)
			var edge := r - d                                      # 0 di tepi luar
			var ex := minf(minf(x, w - 1 - x), minf(y, h - 1 - y))
			var e := minf(edge if d > 0.0 else 999.0, ex)
			if e < 3.0:
				c = BORDER
				c.a = alpha
			elif e < 5.0:                                          # bevel
				var top: bool = (float(y) / h) < 0.5
				c = c.lightened(0.28) if top else c.darkened(0.30)
				c.a = alpha
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_btn_cache[key] = tex
	return tex


# ------------------------------------------------------------------ gambar panel
## Bentuk daun (lensa runcing) mulai dari titik p, menghadap sudut ang.
static func leaf_points(p: Vector2, ang: float, length: float, width: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(0, 11):
		var t := i / 10.0
		pts.append(p + Vector2(t * length, sin(t * PI) * width * 0.5).rotated(ang))
	for i in range(9, 0, -1):
		var t := i / 10.0
		pts.append(p + Vector2(t * length, -sin(t * PI) * width * 0.5).rotated(ang))
	return pts


func _draw_leaf(p: Vector2, ang: float, length: float, width: float, col: Color) -> void:
	var pts := leaf_points(p, ang, length, width)
	draw_colored_polygon(pts, col.darkened(0.12))
	# setengah daun lebih terang -> kesan lipatan
	var half := PackedVector2Array()
	for i in range(0, 11):
		var t := i / 10.0
		half.append(p + Vector2(t * length, sin(t * PI) * width * 0.5).rotated(ang))
	half.append(p)
	draw_colored_polygon(half, col.lightened(0.10))
	draw_line(p, p + Vector2(length * 0.92, 0).rotated(ang), col.darkened(0.4), 1.5, true)
	for k in range(1, 5):
		var q := p + Vector2(length * k * 0.2, 0).rotated(ang)
		draw_line(q, q + Vector2(length * 0.12, width * 0.30).rotated(ang), col.darkened(0.3), 1.0, true)
		draw_line(q, q + Vector2(length * 0.12, -width * 0.30).rotated(ang), col.darkened(0.3), 1.0, true)
	draw_polyline(pts + PackedVector2Array([pts[0]]), col.darkened(0.55), 1.2, true)


func _round_rect(r: Rect2, rad: float, steps := 6) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [
		[Vector2(r.end.x - rad, r.position.y + rad), -PI * 0.5],
		[Vector2(r.end.x - rad, r.end.y - rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), PI * 0.5],
		[Vector2(r.position.x + rad, r.position.y + rad), PI]]
	for c in corners:
		for i in range(0, steps + 1):
			var a: float = c[1] + (PI * 0.5) * float(i) / steps
			pts.append(c[0] + Vector2(cos(a), sin(a)) * rad)
	return pts


func _nail(p: Vector2, rad: float) -> void:
	draw_circle(p + Vector2(1.5, 2.0), rad + 1.0, Color(0, 0, 0, 0.45))
	draw_circle(p, rad + 1.2, Color(0.08, 0.05, 0.03))
	draw_circle(p, rad, Color(0.34, 0.33, 0.33))
	draw_circle(p + Vector2(-rad * 0.15, -rad * 0.2), rad * 0.72, Color(0.58, 0.57, 0.55))
	draw_circle(p + Vector2(-rad * 0.3, -rad * 0.35), rad * 0.32, Color(0.92, 0.92, 0.90))
	draw_arc(p, rad * 0.8, deg_to_rad(20), deg_to_rad(120), 6, Color(0.2, 0.2, 0.2, 0.7), 1.2)


func _rope(x: float, y_top: float, y_bot: float) -> void:
	draw_line(Vector2(x + 2.0, y_top), Vector2(x + 2.0, y_bot), Color(0, 0, 0, 0.35), 9.0)
	draw_line(Vector2(x, y_top), Vector2(x, y_bot), Color(0.30, 0.20, 0.10), 8.0)
	draw_line(Vector2(x, y_top), Vector2(x, y_bot), ROPE.darkened(0.15), 6.0)
	var y := y_top
	while y < y_bot:
		draw_line(Vector2(x - 3.0, y + 3.0), Vector2(x + 3.0, y - 1.0), ROPE.darkened(0.45), 1.6)
		draw_line(Vector2(x - 3.0, y + 5.0), Vector2(x + 3.0, y + 1.0), ROPE.lightened(0.25), 1.0)
		y += 5.0
	draw_line(Vector2(x - 2.0, y_top), Vector2(x - 2.0, y_bot), Color(1, 1, 1, 0.12), 1.5)


func _draw() -> void:
	if size.x < 4.0 or size.y < 4.0:
		return
	var r := Rect2(Vector2.ZERO, size)
	var rad := float(corner_radius)

	# tali gantung (di belakang papan)
	if ropes:
		var rl := rope_length
		_rope(size.x * 0.2, -rl, 10.0)
		_rope(size.x * 0.8, -rl, 10.0)

	# bayangan lembut berlapis
	for i in range(7, 0, -1):
		var grown := r.grow(float(i) * 1.1)
		var pts := _round_rect(Rect2(grown.position + Vector2(0, 3.0 + i * 0.6), grown.size), rad + i)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.055))

	# badan kayu bertekstur
	var body := _round_rect(r, rad)
	var uvs := PackedVector2Array()
	var sx := 1.0 / maxf(size.x, 1.0)
	var sy := 1.0 / maxf(size.y, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var off := Vector2(rng.randf(), rng.randf() * 0.5)
	for p in body:
		uvs.append(Vector2(p.x * sx * 0.55 + off.x * 0.4, p.y * sy * 0.55 + off.y))
	var tint := Color(wood.r * 1.75, wood.g * 1.75, wood.b * 1.75, 1.0)
	draw_colored_polygon(body, tint, uvs, grain_texture())

	# pencahayaan: terang di atas, gelap di bawah
	var cols := PackedColorArray()
	for p in body:
		var t := clampf(p.y / size.y, 0.0, 1.0)
		cols.append(Color(1, 1, 1, 0.20 * (1.0 - t * 1.8)) if t < 0.55 else Color(0, 0, 0, 0.30 * (t - 0.45)))
	draw_polygon(body, cols)

	# bayangan dalam di tepi (inset)
	var inner := _round_rect(r.grow(-3.0), maxf(rad - 3.0, 2.0))
	draw_polyline(inner + PackedVector2Array([inner[0]]), Color(0, 0, 0, 0.22), 3.0, true)

	# bevel: sorot di tepi atas-kiri, gelap di bawah-kanan
	var hi := r.grow(-5.0)
	draw_line(Vector2(hi.position.x + rad * 0.6, hi.position.y), Vector2(hi.end.x - rad * 0.6, hi.position.y), Color(1.0, 0.82, 0.55, 0.45), 2.0)
	draw_line(Vector2(hi.position.x, hi.position.y + rad * 0.6), Vector2(hi.position.x, hi.end.y - rad * 0.6), Color(1.0, 0.82, 0.55, 0.25), 1.5)
	draw_line(Vector2(hi.position.x + rad * 0.6, hi.end.y), Vector2(hi.end.x - rad * 0.6, hi.end.y), Color(0, 0, 0, 0.35), 2.0)

	# garis tepi luar
	draw_polyline(body + PackedVector2Array([body[0]]), BORDER, 4.0, true)

	# paku logam
	if nails and size.x > 56.0 and size.y > 40.0:
		var m := clampf(rad * 0.9 + 3.0, 9.0, 16.0)
		for c in [Vector2(m, m), Vector2(size.x - m, m), Vector2(m, size.y - m), Vector2(size.x - m, size.y - m)]:
			_nail(c, 3.6)

	# daun
	if leaves:
		var lr := RandomNumberGenerator.new()
		lr.seed = seed_value * 7 + 1
		for i in 5:
			_draw_leaf(Vector2(6, 8), deg_to_rad(lr.randf_range(-20, 80)), lr.randf_range(22, 40), lr.randf_range(10, 17), LEAF_COLORS[lr.randi() % LEAF_COLORS.size()])
		for i in 5:
			_draw_leaf(Vector2(size.x - 6, size.y - 8), deg_to_rad(lr.randf_range(160, 260)), lr.randf_range(22, 40), lr.randf_range(10, 17), LEAF_COLORS[lr.randi() % LEAF_COLORS.size()])
