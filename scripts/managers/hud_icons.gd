extends RefCounted
## Ikon kecil (gulungan quest, bendera target) yang digambar lewat kode. Dipakai kalender & HUD.

const FLAG_RED := Color(0.90, 0.26, 0.22)


static func draw_scroll(ci: CanvasItem, p: Vector2, s: float, col: Color) -> void:
	var o := Color(0.14, 0.07, 0.03)
	ci.draw_rect(Rect2(p + Vector2(1, 3) * s / 17.0, Vector2(15, 11) * s / 17.0), col)
	ci.draw_rect(Rect2(p + Vector2(1, 3) * s / 17.0, Vector2(15, 11) * s / 17.0), o, false, 1.5)
	ci.draw_circle(p + Vector2(2, 8.5) * s / 17.0, 3.2 * s / 17.0, col.lightened(0.15))
	ci.draw_circle(p + Vector2(15, 8.5) * s / 17.0, 3.2 * s / 17.0, col.lightened(0.15))
	for i in 3:
		var y := (6.0 + i * 3.0) * s / 17.0
		ci.draw_line(p + Vector2(4.5 * s / 17.0, y), p + Vector2(12.5 * s / 17.0, y), o, 1.2)


static func draw_flag(ci: CanvasItem, p: Vector2, s: float) -> void:
	var o := Color(0.14, 0.07, 0.03)
	ci.draw_line(p + Vector2(2, 1) * s / 19.0, p + Vector2(2, 18) * s / 19.0, o, 2.5)
	var pts := PackedVector2Array([p + Vector2(2, 2) * s / 19.0, p + Vector2(17, 6) * s / 19.0, p + Vector2(2, 11) * s / 19.0])
	ci.draw_colored_polygon(pts, FLAG_RED)
	ci.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), o, 1.3, true)
