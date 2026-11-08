extends Control
## VillageScenery - ilustrasi desa saat fajar (matahari, awan, gunung, bukit berpinus, rumah, ladang) yang digambar
## lewat kode. Dipakai oleh layar judul (splash) dan cerita pembuka. Set "photo" untuk memakai foto sebagai gantinya.

var t := 0.0
var parallax := Vector2.ZERO
var photo: Texture2D
var forest := true            # true = hutan (default), false = desa fajar lama

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	t += delta
	var vp := get_viewport_rect().size
	var m := get_viewport().get_mouse_position()
	var target := (m / vp - Vector2(0.5, 0.5)).clampf(-0.5, 0.5)
	parallax = parallax.lerp(target, 1.0 - exp(-3.0 * delta))
	queue_redraw()

func _p(x: float, y: float, off := 0.0) -> Vector2:
	return Vector2(x * size.x + parallax.x * off, y * size.y + parallax.y * off * 0.4)

func _gradient_rect(r: Rect2, top: Color, bot: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]),
		PackedColorArray([top, top, bot, bot]))

func _draw() -> void:
	if photo:
		draw_texture_rect(photo, Rect2(Vector2(-24, -16) + parallax * -18.0, size + Vector2(48, 32)), false)
		return
	if forest:
		_draw_forest()
		return
	# langit fajar
	_gradient_rect(Rect2(Vector2.ZERO, size), Color(0.36, 0.62, 0.90), Color(1.0, 0.86, 0.60))
	# matahari + sinar
	var sun := _p(0.30, 0.50)
	var sr := size.y * 0.085
	for i in 14:
		var a := t * 0.06 + i * TAU / 14.0
		var w := 0.07
		draw_polygon(PackedVector2Array([sun, sun + Vector2(cos(a - w), sin(a - w)) * size.x * 0.9, sun + Vector2(cos(a + w), sin(a + w)) * size.x * 0.9]),
			PackedColorArray([Color(1, 0.95, 0.7, 0.20), Color(1, 0.95, 0.7, 0.0), Color(1, 0.95, 0.7, 0.0)]))
	for k in 5:
		draw_circle(sun, sr * (3.2 - k * 0.55), Color(1.0, 0.92, 0.6, 0.07 + k * 0.03))
	draw_circle(sun, sr, Color(1.0, 0.97, 0.78))
	# awan
	for c in [[0.10, 0.16, 1.0, 0.012], [0.45, 0.10, 0.8, 0.008], [0.72, 0.22, 1.2, 0.010], [0.90, 0.12, 0.7, 0.007]]:
		var cx := fposmod(c[0] + t * c[3], 1.35) - 0.2
		_cloud(_p(cx, c[1], 8.0), size.y * 0.05 * c[2])
	# gunung jauh + puncak salju
	var peaks := [Vector2(-0.05, 0.64), Vector2(0.10, 0.42), Vector2(0.19, 0.52), Vector2(0.31, 0.36), Vector2(0.43, 0.54), Vector2(0.56, 0.42),
		Vector2(0.69, 0.53), Vector2(0.81, 0.34), Vector2(0.93, 0.50), Vector2(1.06, 0.42), Vector2(1.06, 0.64)]
	var pts := PackedVector2Array()
	for v in peaks:
		pts.append(_p(v.x, v.y, 10.0))
	draw_colored_polygon(pts, Color(0.46, 0.54, 0.76))
	for v in [Vector2(0.10, 0.42), Vector2(0.31, 0.36), Vector2(0.56, 0.42), Vector2(0.81, 0.34)]:
		var c := _p(v.x, v.y, 10.0)
		draw_colored_polygon(PackedVector2Array([c, c + Vector2(-size.x * 0.022, size.y * 0.05), c + Vector2(-size.x * 0.006, size.y * 0.04),
			c + Vector2(size.x * 0.004, size.y * 0.055), c + Vector2(size.x * 0.024, size.y * 0.05)]), Color(1, 1, 1, 0.85))
	# bukit
	_hill(0.64, 0.035, 5.0, 3.0, 1.2, Color(0.36, 0.62, 0.42), 16.0)
	_pines(0.64, 0.035, 5.0, 3.0, 1.2, 0.045, Color(0.16, 0.40, 0.30), 16.0)
	_hill(0.72, 0.040, 4.0, 1.0, 2.0, Color(0.30, 0.56, 0.32), 26.0)
	_pines(0.72, 0.040, 4.0, 1.0, 2.0, 0.062, Color(0.12, 0.34, 0.22), 26.0)
	_farmhouse(0.80, 0.745, 30.0)
	# ladang depan
	_gradient_rect(Rect2(_p(0, 0.80), Vector2(size.x, size.y * 0.20 + 4.0)), Color(0.50, 0.36, 0.20), Color(0.34, 0.22, 0.12))
	for r in 7:
		var y := 0.82 + r * 0.027
		var depth := 0.4 + r * 0.14
		var x := -0.02 + fposmod(r * 0.37, 0.05)
		while x < 1.04:
			var p := _p(x, y, 40.0)
			var s := size.y * 0.012 * depth * 1.6
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s * 1.8), p + Vector2(-s, 0), p + Vector2(s, 0)]), Color(0.36, 0.72, 0.30))
			draw_colored_polygon(PackedVector2Array([p + Vector2(s * 0.2, -s * 1.4), p + Vector2(s * 1.4, -s * 0.6), p + Vector2(s * 0.4, 0)]), Color(0.46, 0.82, 0.36))
			x += 0.055 * (0.8 + depth * 0.35)
		draw_line(_p(0, y + 0.012, 40.0), _p(1, y + 0.012, 40.0), Color(0.26, 0.16, 0.08, 0.5), 2.0)
	# semak bingkai kiri dan kanan bawah
	for s in [[0.0, 1.0], [1.0, 1.0], [0.06, 1.02], [0.94, 1.02], [0.14, 1.04], [0.86, 1.04]]:
		var c := _p(s[0], s[1], 60.0)
		var rr := size.y * (0.16 if absf(s[0] - 0.5) > 0.45 else 0.11)
		draw_circle(c, rr, Color(0.14, 0.36, 0.20))
		draw_circle(c + Vector2(-rr * 0.2, -rr * 0.25), rr * 0.7, Color(0.20, 0.46, 0.24))
		draw_circle(c + Vector2(-rr * 0.3, -rr * 0.35), rr * 0.32, Color(0.34, 0.62, 0.30))

func _cloud(c: Vector2, r: float) -> void:
	var col := Color(1, 1, 1, 0.92)
	for o in [Vector2(-1.4, 0.2), Vector2(-0.5, -0.3), Vector2(0.5, -0.4), Vector2(1.4, 0.1), Vector2(0, 0.25)]:
		draw_circle(c + o * r, r * (0.9 if o.y < 0 else 0.7), col)
	draw_rect(Rect2(c + Vector2(-1.9, 0.2) * r, Vector2(3.8, 0.8) * r), col)

func _hill_y(x: float, base: float, amp: float, f1: float, ph: float) -> float:
	return base + sin(x * f1 + ph) * amp + sin(x * f1 * 2.3 + ph * 2.0) * amp * 0.4

func _hill(base: float, amp: float, f1: float, ph: float, f2: float, col: Color, off: float) -> void:
	var pts := PackedVector2Array()
	var x := -0.05
	while x <= 1.05:
		pts.append(_p(x, _hill_y(x, base, amp, f1, ph), off))
		x += 0.02
	pts.append(_p(1.05, 1.0, off))
	pts.append(_p(-0.05, 1.0, off))
	draw_colored_polygon(pts, col)

func _pines(base: float, amp: float, f1: float, ph: float, _f2: float, hgt: float, col: Color, off: float) -> void:
	var x := 0.01
	var i := 0
	while x < 1.0:
		var y := _hill_y(x, base, amp, f1, ph)
		if not (x > 0.74 and x < 0.88 and base > 0.7):          # sisakan ruang untuk rumah
			var h := size.y * hgt * (0.8 + 0.4 * fposmod(i * 0.37, 1.0))
			var b := _p(x, y + 0.004, off)
			for k in 3:
				var w := h * (0.34 - k * 0.07)
				var yy := b.y - h * 0.25 * k
				draw_colored_polygon(PackedVector2Array([Vector2(b.x, yy - h * 0.5), Vector2(b.x - w, yy), Vector2(b.x + w, yy)]), col.lightened(k * 0.04))
		x += 0.034 + fposmod(i * 0.013, 0.02)
		i += 1

func _farmhouse(x: float, y: float, off: float) -> void:
	var b := _p(x, y, off)
	var w := size.x * 0.085
	var h := size.y * 0.07
	draw_rect(Rect2(b + Vector2(-w * 0.5, -h), Vector2(w, h)), Color(0.78, 0.30, 0.24))
	draw_rect(Rect2(b + Vector2(-w * 0.5, -h), Vector2(w, h * 0.12)), Color(0.60, 0.20, 0.16))
	draw_colored_polygon(PackedVector2Array([b + Vector2(-w * 0.62, -h), b + Vector2(0, -h * 1.75), b + Vector2(w * 0.62, -h)]), Color(0.42, 0.26, 0.20))
	draw_rect(Rect2(b + Vector2(-w * 0.14, -h * 0.62), Vector2(w * 0.28, h * 0.62)), Color(0.36, 0.22, 0.12))
	draw_rect(Rect2(b + Vector2(w * 0.22, -h * 0.82), Vector2(w * 0.18, h * 0.3)), Color(1.0, 0.88, 0.5))
	draw_rect(Rect2(b + Vector2(w * 0.30, -h * 1.5), Vector2(w * 0.1, h * 0.5)), Color(0.5, 0.3, 0.22))
	for k in 4:                                                  # pagar
		var fx := b.x - w * 0.9 - k * 14.0
		draw_rect(Rect2(Vector2(fx, b.y - h * 0.42), Vector2(5, h * 0.42)), Color(0.82, 0.66, 0.42))
	draw_rect(Rect2(Vector2(b.x - w * 0.9 - 3 * 14.0, b.y - h * 0.32), Vector2(3 * 14.0 + 5, 4)), Color(0.82, 0.66, 0.42))


# ====================================================================== HUTAN
func _rnd(i: int, seed_v: int) -> float:
	return fposmod(sin(float(i * 37 + seed_v * 131)) * 43758.5453, 1.0)


func _draw_forest() -> void:
	var W := size.x
	var H := size.y
	# langit pagi berkabut
	_gradient_rect(Rect2(Vector2.ZERO, size), Color(0.46, 0.74, 0.72), Color(0.99, 0.94, 0.70))
	# matahari menyelinap di sela pohon
	var sun := _p(0.64, 0.34)
	for k in 6:
		draw_circle(sun, H * (0.36 - k * 0.05), Color(1.0, 0.95, 0.68, 0.06 + k * 0.025))
	draw_circle(sun, H * 0.06, Color(1.0, 0.98, 0.84))
	# lapisan hutan: jauh -> dekat (makin gelap, makin besar)
	var layers := [
		[0.56, 0.17, Color(0.56, 0.75, 0.70), 6.0, 1],
		[0.62, 0.23, Color(0.42, 0.65, 0.56), 12.0, 2],
		[0.70, 0.31, Color(0.28, 0.53, 0.40), 22.0, 3],
		[0.79, 0.42, Color(0.15, 0.37, 0.27), 36.0, 4],
	]
	for L in layers:
		_tree_row(L[0], L[1], L[2], L[3], L[4])
		# kabut tipis di antara lapisan
		var y0: float = L[0]
		var mist := Color(1.0, 0.96, 0.78, 0.0)
		var mist2 := Color(1.0, 0.96, 0.78, 0.30)
		var top := _p(0, y0 - 0.02)
		var mid := _p(0, y0 + 0.06)
		var bot := _p(0, y0 + 0.16)
		draw_polygon(PackedVector2Array([top, top + Vector2(W, 0), mid + Vector2(W, 0), mid]), PackedColorArray([mist, mist, mist2, mist2]))
		draw_polygon(PackedVector2Array([mid, mid + Vector2(W, 0), bot + Vector2(W, 0), bot]), PackedColorArray([mist2, mist2, mist, mist]))
	# tanah depan + jalan setapak
	_gradient_rect(Rect2(_p(0, 0.84, 40.0), Vector2(W, H * 0.17)), Color(0.30, 0.56, 0.28), Color(0.13, 0.30, 0.17))
	var path_c := Color(0.84, 0.70, 0.46)
	var pa := PackedVector2Array([_p(0.465, 0.835, 40.0), _p(0.535, 0.835, 40.0), _p(0.70, 1.02, 50.0), _p(0.30, 1.02, 50.0)])
	draw_colored_polygon(pa, path_c)
	draw_polyline(PackedVector2Array([pa[0], pa[3]]), Color(0.55, 0.40, 0.22), 3.0)
	draw_polyline(PackedVector2Array([pa[1], pa[2]]), Color(0.55, 0.40, 0.22), 3.0)
	for i in 8:
		var q := _p(0.40 + _rnd(i, 7) * 0.2, 0.88 + _rnd(i, 9) * 0.1, 45.0)
		draw_circle(q, 3.0 + _rnd(i, 3) * 4.0, Color(0.72, 0.58, 0.36))
	# berkas cahaya
	var pulse := 0.75 + 0.25 * sin(t * 0.7)
	for i in 6:
		var x0 := 0.30 + i * 0.09
		var a0 := Color(1.0, 0.97, 0.72, 0.16 * pulse)
		var a1 := Color(1.0, 0.97, 0.72, 0.0)
		var sw := 0.025 + 0.012 * _rnd(i, 5)
		draw_polygon(PackedVector2Array([_p(x0, -0.02), _p(x0 + sw, -0.02), _p(x0 - 0.18 + sw * 2.0, 0.95), _p(x0 - 0.18, 0.95)]),
			PackedColorArray([a0, a0, a1, a1]))
	# pakis di pinggir jalan
	for i in 16:
		var side := -1.0 if i % 2 == 0 else 1.0
		var fy := 0.86 + _rnd(i, 11) * 0.14
		var fx := 0.5 + side * (0.10 + (fy - 0.84) * 0.8 + _rnd(i, 13) * 0.10)
		_fern(_p(fx, fy, 50.0), H * (0.04 + (fy - 0.84) * 0.25), i)
	# batang pohon besar membingkai + tajuk
	for side in [0.0, 1.0]:
		var tx := 0.035 if side == 0.0 else 0.965
		var tw := W * 0.075
		var base := _p(tx, 0.0, 70.0)
		draw_rect(Rect2(base + Vector2(-tw * 0.5, 0), Vector2(tw, H * 1.02)), Color(0.28, 0.17, 0.10))
		draw_rect(Rect2(base + Vector2(-tw * 0.5, 0), Vector2(tw * 0.28, H * 1.02)), Color(0.38, 0.24, 0.14))
		for k in 7:
			var by := H * (0.08 + k * 0.14)
			draw_line(base + Vector2(-tw * 0.2, by), base + Vector2(tw * 0.1, by + H * 0.05), Color(0.17, 0.10, 0.06), 3.0)
		for k in 5:
			var cc := base + Vector2((-0.5 if side == 0.0 else 0.5) * W * 0.04 + (k - 2) * W * 0.045 * (1.0 if side == 0.0 else -1.0), H * 0.02 + _rnd(k, 21) * H * 0.07)
			var rr := H * (0.15 + _rnd(k, 23) * 0.05)
			draw_circle(cc, rr, Color(0.10, 0.30, 0.18))
			draw_circle(cc + Vector2(rr * 0.15, rr * 0.2), rr * 0.7, Color(0.16, 0.40, 0.22))
	# tajuk menggantung di atas
	for k in 9:
		var cx := 0.14 + k * 0.09
		var cc := _p(cx, -0.02 + 0.015 * sin(t * 0.5 + k), 30.0)
		draw_circle(cc, H * (0.09 + _rnd(k, 31) * 0.04), Color(0.12, 0.34, 0.20, 0.92))


func _tree_row(base_y: float, hgt: float, col: Color, off: float, seed_v: int) -> void:
	var W := size.x
	var H := size.y
	var th := H * hgt
	# isian tanah di bawah barisan (menutup celah antar pohon)
	draw_rect(Rect2(_p(-0.05, base_y + 0.005, off), Vector2(W * 1.1, H * 0.6)), col.darkened(0.06))
	var step := th * 0.42 / W
	var x := -0.06
	var i := 0
	while x < 1.08:
		var r := _rnd(i, seed_v)
		var h := th * (0.70 + 0.5 * r)
		var b := _p(x, base_y + (_rnd(i, seed_v + 5) - 0.5) * 0.03, off)
		var c := col.lightened((r - 0.5) * 0.10)
		if r < 0.62:
			_pine(b, h, c)
		else:
			_round_tree(b, h, c)
		x += step * (0.75 + 0.6 * _rnd(i, seed_v + 9))
		i += 1


func _pine(b: Vector2, h: float, c: Color) -> void:
	draw_rect(Rect2(b + Vector2(-h * 0.03, -h * 0.12), Vector2(h * 0.06, h * 0.14)), c.darkened(0.45))
	for k in 4:
		var w := h * (0.30 - k * 0.055)
		var yy := b.y - h * 0.10 - h * 0.21 * k
		draw_colored_polygon(PackedVector2Array([Vector2(b.x, yy - h * 0.34), Vector2(b.x - w, yy), Vector2(b.x + w, yy)]), c.lightened(k * 0.035))


func _round_tree(b: Vector2, h: float, c: Color) -> void:
	draw_rect(Rect2(b + Vector2(-h * 0.04, -h * 0.40), Vector2(h * 0.08, h * 0.42)), c.darkened(0.5))
	var cc := b + Vector2(0, -h * 0.62)
	draw_circle(cc + Vector2(-h * 0.16, h * 0.06), h * 0.22, c.darkened(0.04))
	draw_circle(cc + Vector2(h * 0.16, h * 0.06), h * 0.22, c.darkened(0.04))
	draw_circle(cc, h * 0.27, c)
	draw_circle(cc + Vector2(-h * 0.07, -h * 0.09), h * 0.14, c.lightened(0.10))


func _fern(b: Vector2, h: float, i: int) -> void:
	var c := Color(0.20, 0.50, 0.24).lightened(_rnd(i, 17) * 0.15)
	for k in 7:
		var a := deg_to_rad(-90.0 + (k - 3) * 22.0 + sin(t * 1.2 + i + k) * 3.0)
		var tip := b + Vector2(cos(a), sin(a)) * h
		var mid := b + Vector2(cos(a), sin(a)) * h * 0.5
		var nrm := Vector2(-sin(a), cos(a)) * h * 0.12
		draw_colored_polygon(PackedVector2Array([b, mid + nrm, tip, mid - nrm]), c)
