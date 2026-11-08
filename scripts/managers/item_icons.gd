extends RefCounted
## ItemIcons - ikon 2D tiap item (dipakai tas, hotbar, peti, intro). Digambar lewat kode, tiap item punya bentuk sendiri
## dengan bayangan, sorotan, dan garis tepi supaya tidak ada yang terlihat sama.
##   ItemIcons.draw(canvas_item, rect, kind, shape, color)

const OUT := Color(0.16, 0.08, 0.04)


# ------------------------------------------------------------------ alat bantu gambar (koordinat 0..1 di dalam rect)
static func _p(r: Rect2, x: float, y: float) -> Vector2:
	return r.position + Vector2(x, y) * r.size


static func _poly(ci: CanvasItem, r: Rect2, pts: Array, col: Color, outline := true) -> void:
	var v := PackedVector2Array()
	for q in pts:
		v.append(_p(r, q[0], q[1]))
	ci.draw_colored_polygon(v, col)
	if outline:
		v.append(v[0])
		ci.draw_polyline(v, OUT, maxf(1.5, r.size.x * 0.035), true)


static func _ell(ci: CanvasItem, r: Rect2, cx: float, cy: float, rx: float, ry: float, col: Color, outline := true, rot := 0.0) -> void:
	var v := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		var q := Vector2(cos(a) * rx, sin(a) * ry).rotated(rot)
		v.append(_p(r, cx + q.x, cy + q.y))
	ci.draw_colored_polygon(v, col)
	if outline:
		v.append(v[0])
		ci.draw_polyline(v, OUT, maxf(1.5, r.size.x * 0.035), true)


static func _line(ci: CanvasItem, r: Rect2, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_line(_p(r, a.x, a.y), _p(r, b.x, b.y), col, maxf(1.0, w * r.size.x), true)


static func _shine(ci: CanvasItem, r: Rect2, cx: float, cy: float, rx: float, ry: float) -> void:
	_ell(ci, r, cx, cy, rx, ry, Color(1, 1, 1, 0.55), false, -0.6)


static func _sq(r: Rect2) -> Rect2:
	var s := minf(r.size.x, r.size.y)
	return Rect2(r.position + (r.size - Vector2(s, s)) * 0.5, Vector2(s, s))


# ------------------------------------------------------------------ pintu masuk
static func draw(ci: CanvasItem, rect: Rect2, kind: String, shape: String, color: Color) -> void:
	var r := _sq(rect)
	var dark := color.darkened(0.35)
	var lite := color.lightened(0.35)
	match shape:
		# ---- alat
		"hoe":
			_line(ci, r, Vector2(0.22, 0.92), Vector2(0.62, 0.22), Color(0.55, 0.36, 0.18), 0.10)
			_poly(ci, r, [[0.52, 0.16], [0.92, 0.12], [0.88, 0.34], [0.64, 0.30], [0.58, 0.38]], Color(0.78, 0.80, 0.86))
			_line(ci, r, Vector2(0.60, 0.20), Vector2(0.88, 0.17), Color(1, 1, 1, 0.7), 0.03)
		"can":
			_poly(ci, r, [[0.22, 0.38], [0.66, 0.38], [0.70, 0.88], [0.18, 0.88]], Color(0.36, 0.58, 0.88))
			_poly(ci, r, [[0.66, 0.50], [0.92, 0.28], [0.98, 0.34], [0.70, 0.66]], Color(0.30, 0.50, 0.80))
			_ell(ci, r, 0.94, 0.28, 0.07, 0.05, Color(0.82, 0.88, 0.95))
			ci.draw_arc(_p(r, 0.20, 0.54), r.size.x * 0.16, PI * 0.5, PI * 1.5, 12, OUT, maxf(2.0, r.size.x * 0.05), true)
			_line(ci, r, Vector2(0.28, 0.46), Vector2(0.28, 0.80), Color(1, 1, 1, 0.45), 0.04)
		"scythe":
			_line(ci, r, Vector2(0.24, 0.94), Vector2(0.60, 0.16), Color(0.55, 0.36, 0.18), 0.09)
			_poly(ci, r, [[0.56, 0.18], [0.80, 0.10], [0.96, 0.26], [0.92, 0.34], [0.78, 0.22], [0.62, 0.26]], Color(0.84, 0.86, 0.92))
			_line(ci, r, Vector2(0.64, 0.18), Vector2(0.88, 0.18), Color(1, 1, 1, 0.7), 0.03)
		"sword":
			_poly(ci, r, [[0.80, 0.06], [0.90, 0.16], [0.40, 0.66], [0.30, 0.56]], Color(0.86, 0.89, 0.95))
			_line(ci, r, Vector2(0.36, 0.56), Vector2(0.82, 0.10), Color(1, 1, 1, 0.8), 0.03)
			_poly(ci, r, [[0.22, 0.52], [0.46, 0.76], [0.40, 0.82], [0.16, 0.58]], Color(0.78, 0.60, 0.22))
			_line(ci, r, Vector2(0.30, 0.68), Vector2(0.12, 0.88), Color(0.45, 0.28, 0.14), 0.09)
			_ell(ci, r, 0.10, 0.90, 0.06, 0.06, Color(0.78, 0.60, 0.22))
		# ---- benih (kantong kertas berwarna sesuai tanaman)
		"seed":
			_poly(ci, r, [[0.24, 0.20], [0.76, 0.20], [0.82, 0.90], [0.18, 0.90]], Color(0.88, 0.76, 0.52))
			_poly(ci, r, [[0.24, 0.20], [0.76, 0.20], [0.78, 0.34], [0.22, 0.34]], color)
			_ell(ci, r, 0.50, 0.62, 0.20, 0.17, color.lightened(0.15))
			for sp in [Vector2(0.44, 0.60), Vector2(0.54, 0.58), Vector2(0.50, 0.68)]:
				_ell(ci, r, sp.x, sp.y, 0.025, 0.04, Color(0.35, 0.22, 0.10), false)
		# ---- hasil panen
		"carrot":
			_poly(ci, r, [[0.34, 0.26], [0.70, 0.26], [0.54, 0.96]], Color(0.95, 0.52, 0.12))
			for y in [0.42, 0.58, 0.72]:
				_line(ci, r, Vector2(0.44 + (y - 0.4) * 0.12, y), Vector2(0.56 - (y - 0.4) * 0.12, y), Color(0.75, 0.36, 0.06), 0.03)
			for lf in [[0.40, 0.04], [0.52, 0.02], [0.62, 0.06]]:
				_line(ci, r, Vector2(0.52, 0.26), Vector2(lf[0], lf[1] + 0.06), Color(0.30, 0.66, 0.24), 0.07)
		"potato", "round":
			_ell(ci, r, 0.50, 0.56, 0.38, 0.30, Color(0.80, 0.62, 0.36), true, -0.25)
			for e in [Vector2(0.36, 0.52), Vector2(0.58, 0.64), Vector2(0.62, 0.46), Vector2(0.42, 0.68)]:
				_ell(ci, r, e.x, e.y, 0.028, 0.02, Color(0.50, 0.36, 0.18), false)
			_shine(ci, r, 0.38, 0.44, 0.10, 0.05)
		"tomato":
			_ell(ci, r, 0.50, 0.58, 0.36, 0.32, Color(0.90, 0.20, 0.15))
			_shine(ci, r, 0.36, 0.46, 0.08, 0.05)
			_poly(ci, r, [[0.50, 0.30], [0.62, 0.20], [0.60, 0.34], [0.74, 0.34], [0.60, 0.42], [0.50, 0.44], [0.40, 0.42], [0.26, 0.34], [0.40, 0.34], [0.38, 0.20]], Color(0.28, 0.62, 0.22))
		"strawberry", "berry":
			_poly(ci, r, [[0.18, 0.30], [0.82, 0.30], [0.66, 0.78], [0.50, 0.94], [0.34, 0.78]], Color(0.92, 0.18, 0.28))
			for s2 in [Vector2(0.36, 0.44), Vector2(0.54, 0.42), Vector2(0.66, 0.50), Vector2(0.44, 0.58), Vector2(0.58, 0.64), Vector2(0.48, 0.76), Vector2(0.30, 0.56)]:
				_ell(ci, r, s2.x, s2.y, 0.022, 0.03, Color(1.0, 0.92, 0.55), false)
			_poly(ci, r, [[0.50, 0.28], [0.64, 0.16], [0.60, 0.30], [0.80, 0.28], [0.60, 0.38], [0.50, 0.40], [0.40, 0.38], [0.20, 0.28], [0.40, 0.30], [0.36, 0.16]], Color(0.30, 0.66, 0.24))
		"corn":
			_ell(ci, r, 0.52, 0.50, 0.17, 0.40, Color(0.98, 0.84, 0.25), true, 0.3)
			for gy in 5:
				for gx in 2:
					_ell(ci, r, 0.44 + gx * 0.10 + gy * 0.025, 0.28 + gy * 0.12, 0.034, 0.04, Color(1.0, 0.95, 0.55), false)
			_poly(ci, r, [[0.50, 0.96], [0.20, 0.52], [0.40, 0.66], [0.50, 0.50]], Color(0.34, 0.68, 0.26))
			_poly(ci, r, [[0.54, 0.96], [0.84, 0.52], [0.64, 0.66], [0.54, 0.50]], Color(0.28, 0.58, 0.22))
		"pumpkin", "ridged":
			_ell(ci, r, 0.50, 0.60, 0.40, 0.31, Color(0.96, 0.55, 0.12))
			_ell(ci, r, 0.50, 0.60, 0.22, 0.31, Color(0.98, 0.62, 0.18), false)
			ci.draw_arc(_p(r, 0.50, 0.60), r.size.x * 0.26, deg_to_rad(100), deg_to_rad(260), 10, Color(0.70, 0.32, 0.05), 2.0, true)
			ci.draw_arc(_p(r, 0.50, 0.60), r.size.x * 0.26, deg_to_rad(-80), deg_to_rad(80), 10, Color(0.70, 0.32, 0.05), 2.0, true)
			_poly(ci, r, [[0.46, 0.32], [0.54, 0.32], [0.56, 0.18], [0.44, 0.18]], Color(0.35, 0.50, 0.18))
		"melon":
			_ell(ci, r, 0.50, 0.56, 0.42, 0.36, Color(0.36, 0.70, 0.30))
			for i in 4:
				var a := -0.9 + i * 0.6
				_line(ci, r, Vector2(0.50 + sin(a) * 0.10, 0.22), Vector2(0.50 + sin(a) * 0.40, 0.56 + cos(a) * 0.1), Color(0.18, 0.46, 0.16), 0.045)
			_shine(ci, r, 0.34, 0.40, 0.09, 0.05)
		# ---- makanan
		"apple":
			_ell(ci, r, 0.38, 0.58, 0.26, 0.30, color)
			_ell(ci, r, 0.62, 0.58, 0.26, 0.30, color)
			_shine(ci, r, 0.34, 0.48, 0.06, 0.05)
			_line(ci, r, Vector2(0.50, 0.30), Vector2(0.54, 0.14), Color(0.40, 0.26, 0.12), 0.05)
			_poly(ci, r, [[0.54, 0.22], [0.76, 0.12], [0.70, 0.30]], Color(0.30, 0.66, 0.24))
		"orange":
			_ell(ci, r, 0.50, 0.58, 0.36, 0.34, Color(1.0, 0.58, 0.12))
			for dp in [Vector2(0.38, 0.52), Vector2(0.58, 0.46), Vector2(0.54, 0.68), Vector2(0.38, 0.70)]:
				_ell(ci, r, dp.x, dp.y, 0.012, 0.012, Color(0.82, 0.40, 0.04), false)
			_shine(ci, r, 0.36, 0.44, 0.08, 0.05)
			_poly(ci, r, [[0.50, 0.26], [0.70, 0.16], [0.66, 0.30]], Color(0.30, 0.66, 0.24))
		"pear":
			_ell(ci, r, 0.50, 0.70, 0.30, 0.26, Color(0.74, 0.82, 0.25))
			_ell(ci, r, 0.50, 0.42, 0.18, 0.24, Color(0.74, 0.82, 0.25))
			_shine(ci, r, 0.40, 0.66, 0.06, 0.05)
			_line(ci, r, Vector2(0.50, 0.20), Vector2(0.56, 0.08), Color(0.40, 0.26, 0.12), 0.05)
		"berries":
			for b in [Vector2(0.34, 0.60), Vector2(0.62, 0.56), Vector2(0.48, 0.38), Vector2(0.50, 0.74)]:
				_ell(ci, r, b.x, b.y, 0.17, 0.17, Color(0.50, 0.20, 0.62))
				_shine(ci, r, b.x - 0.05, b.y - 0.05, 0.04, 0.03)
			_poly(ci, r, [[0.50, 0.22], [0.70, 0.14], [0.64, 0.30]], Color(0.30, 0.66, 0.24))
		"bread":
			_ell(ci, r, 0.50, 0.58, 0.42, 0.26, Color(0.82, 0.58, 0.28))
			for sx in [0.34, 0.50, 0.66]:
				_line(ci, r, Vector2(sx - 0.05, 0.48), Vector2(sx + 0.05, 0.62), Color(0.58, 0.36, 0.14), 0.04)
			_shine(ci, r, 0.36, 0.46, 0.10, 0.04)
		"fish":
			_ell(ci, r, 0.46, 0.52, 0.34, 0.20, Color(0.92, 0.66, 0.34))
			_poly(ci, r, [[0.76, 0.52], [0.96, 0.30], [0.96, 0.74]], Color(0.84, 0.54, 0.24))
			_ell(ci, r, 0.26, 0.48, 0.035, 0.035, Color(0.1, 0.05, 0.02), false)
			for gx in [0.40, 0.50, 0.60]:
				_line(ci, r, Vector2(gx, 0.40), Vector2(gx, 0.64), Color(0.60, 0.36, 0.14), 0.03)
		"bowl":
			_ell(ci, r, 0.50, 0.46, 0.34, 0.10, Color(0.62, 0.32, 0.16))
			_poly(ci, r, [[0.14, 0.46], [0.86, 0.46], [0.72, 0.84], [0.28, 0.84]], Color(0.80, 0.78, 0.74))
			_ell(ci, r, 0.50, 0.46, 0.30, 0.08, Color(0.62, 0.32, 0.16), false)
			for st in [0.40, 0.55]:
				ci.draw_arc(_p(r, st, 0.22), r.size.x * 0.05, PI * 0.5, PI * 2.0, 8, Color(1, 1, 1, 0.55), 2.0, true)
		"feast":
			_ell(ci, r, 0.50, 0.74, 0.44, 0.14, Color(0.78, 0.78, 0.82))
			_ell(ci, r, 0.50, 0.50, 0.28, 0.22, Color(0.80, 0.46, 0.20))
			_ell(ci, r, 0.44, 0.44, 0.10, 0.06, Color(0.95, 0.68, 0.36), false)
			_line(ci, r, Vector2(0.74, 0.34), Vector2(0.92, 0.18), Color(0.92, 0.90, 0.84), 0.07)
			_ell(ci, r, 0.30, 0.66, 0.09, 0.07, Color(0.90, 0.20, 0.15))
			_ell(ci, r, 0.70, 0.68, 0.09, 0.07, Color(0.55, 0.78, 0.25))
		# ---- hasil buruan monster (masing-masing beda)
		"horn":
			_poly(ci, r, [[0.28, 0.94], [0.30, 0.58], [0.46, 0.24], [0.74, 0.06], [0.64, 0.34], [0.64, 0.60], [0.74, 0.94]], Color(0.85, 0.30, 0.25))
			_poly(ci, r, [[0.40, 0.94], [0.42, 0.62], [0.54, 0.34], [0.70, 0.12], [0.62, 0.42], [0.60, 0.70], [0.62, 0.94]], Color(0.95, 0.52, 0.40), false)
			for ry in [0.46, 0.62, 0.78]:
				_line(ci, r, Vector2(0.33, ry), Vector2(0.62, ry - 0.04), Color(0.50, 0.12, 0.10), 0.03)
		"claw":
			_poly(ci, r, [[0.20, 0.94], [0.16, 0.50], [0.34, 0.20], [0.74, 0.06], [0.52, 0.34], [0.48, 0.60], [0.50, 0.94]], Color(0.92, 0.88, 0.78))
			_line(ci, r, Vector2(0.30, 0.86), Vector2(0.28, 0.48), Color(1, 1, 1, 0.55), 0.04)
			_poly(ci, r, [[0.14, 0.82], [0.54, 0.82], [0.56, 0.96], [0.12, 0.96]], Color(0.45, 0.35, 0.28))
		"fur":
			for t in [[0.30, 0.50, 0.0], [0.50, 0.46, 0.15], [0.70, 0.52, 0.3]]:
				_ell(ci, r, t[0], t[1], 0.13, 0.30, Color(0.62, 0.64, 0.70).lightened(t[2] * 0.4), true, t[2])
			_ell(ci, r, 0.50, 0.74, 0.34, 0.14, Color(0.50, 0.52, 0.58))
			_line(ci, r, Vector2(0.18, 0.80), Vector2(0.82, 0.80), Color(0.85, 0.30, 0.25), 0.04)
		"bone":
			_line(ci, r, Vector2(0.26, 0.74), Vector2(0.74, 0.26), OUT, 0.17)
			_line(ci, r, Vector2(0.26, 0.74), Vector2(0.74, 0.26), Color(0.92, 0.90, 0.82), 0.11)
			for e in [Vector2(0.22, 0.60), Vector2(0.40, 0.80), Vector2(0.60, 0.20), Vector2(0.80, 0.40)]:
				_ell(ci, r, e.x, e.y, 0.095, 0.095, Color(0.92, 0.90, 0.82))
			_line(ci, r, Vector2(0.34, 0.64), Vector2(0.60, 0.38), Color(1, 1, 1, 0.55), 0.03)
		"tooth":
			_poly(ci, r, [[0.24, 0.20], [0.76, 0.20], [0.80, 0.50], [0.64, 0.94], [0.52, 0.60], [0.40, 0.94], [0.22, 0.50]], Color(0.90, 0.92, 0.66))
			_line(ci, r, Vector2(0.34, 0.30), Vector2(0.32, 0.52), Color(1, 1, 1, 0.7), 0.05)
			_poly(ci, r, [[0.56, 0.20], [0.76, 0.20], [0.80, 0.50], [0.70, 0.40]], Color(0.74, 0.78, 0.46), false)
		"badge":
			_poly(ci, r, [[0.50, 0.06], [0.88, 0.20], [0.84, 0.62], [0.50, 0.94], [0.16, 0.62], [0.12, 0.20]], Color(0.82, 0.68, 0.30))
			_poly(ci, r, [[0.50, 0.16], [0.78, 0.27], [0.75, 0.58], [0.50, 0.82], [0.25, 0.58], [0.22, 0.27]], Color(0.50, 0.36, 0.14), false)
			_poly(ci, r, [[0.50, 0.28], [0.56, 0.44], [0.72, 0.44], [0.60, 0.54], [0.64, 0.70], [0.50, 0.60], [0.36, 0.70], [0.40, 0.54], [0.28, 0.44], [0.44, 0.44]], Color(0.98, 0.86, 0.40), false)
		"nugget":
			_poly(ci, r, [[0.14, 0.64], [0.28, 0.34], [0.52, 0.24], [0.78, 0.36], [0.88, 0.66], [0.66, 0.84], [0.30, 0.84]], Color(1.0, 0.80, 0.22))
			_poly(ci, r, [[0.28, 0.34], [0.52, 0.24], [0.46, 0.50], [0.30, 0.56]], Color(1.0, 0.94, 0.55), false)
			_line(ci, r, Vector2(0.60, 0.46), Vector2(0.78, 0.64), Color(0.80, 0.55, 0.10), 0.04)
		"herb":
			_line(ci, r, Vector2(0.50, 0.94), Vector2(0.50, 0.30), Color(0.25, 0.50, 0.20), 0.05)
			for lf in [[0.50, 0.14, 0.0], [0.30, 0.34, -0.8], [0.70, 0.34, 0.8], [0.32, 0.58, -0.8], [0.68, 0.58, 0.8]]:
				_ell(ci, r, lf[0], lf[1], 0.10, 0.17, Color(0.36, 0.72, 0.34), true, lf[2])
		# ---- tanpa bentuk khusus: batu permata sederhana
		_:
			_poly(ci, r, [[0.50, 0.10], [0.86, 0.40], [0.50, 0.92], [0.14, 0.40]], color)
			_poly(ci, r, [[0.50, 0.10], [0.62, 0.40], [0.38, 0.40]], lite, false)
			_poly(ci, r, [[0.62, 0.40], [0.86, 0.40], [0.50, 0.92]], dark, false)
