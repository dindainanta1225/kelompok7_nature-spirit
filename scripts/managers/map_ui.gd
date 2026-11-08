extends CanvasLayer
## MapUI - peta dunia besar yang saling tersambung: Home -> Farm -> Village (masuk dari kiri) -> Forest 1 / Forest 2 (ke kanan).
## Roda mouse / tombol +/- = zoom, tarik dengan klik kiri = geser, M / Esc / tombol X = tutup.
## Marker merah = posisi player di area sekarang. API: open(), close(), is_open().

const UiStyle := preload("res://scripts/ui/ui_style.gd")

const WORLD := Vector2(3000, 1650)
const ZMIN := 0.3
const ZMAX := 3.0

# Susunan sama dengan hubungan scene asli: Village di atas, Farm di selatannya (gerbang selatan desa),
# rumah player terhubung ke Farm, Forest 1 di timur Village, Forest 2 di timur Forest 1.
const AREAS := {
	"village": {"rect": Rect2(1000, 100, 700, 700), "name": "Village", "b": Rect2(-28.0, -28.0, 56.0, 56.0)},
	"farm": {"rect": Rect2(1050, 980, 600, 520), "name": "Farm", "b": Rect2(-17.5, -17.0, 35.0, 33.0)},
	"home": {"rect": Rect2(560, 1110, 300, 260), "name": "Your House", "b": Rect2(-6, -6, 12, 12)},
	"forest1": {"rect": Rect2(1850, 300, 420, 360), "name": "Forest 1", "b": Rect2(-26.0, -18.0, 52.0, 36.0)},
	"forest2": {"rect": Rect2(2420, 300, 420, 360), "name": "Forest 2", "b": Rect2(-26.0, -18.0, 52.0, 36.0)},
}
const ROADS := [
	[Vector2(1350, 780), Vector2(1350, 1000)],          # Village (selatan) <-> Farm
	[Vector2(1070, 1240), Vector2(840, 1240)],          # Farm <-> rumah player
	[Vector2(1680, 506), Vector2(1870, 506)],           # Village (timur) <-> Forest 1
	[Vector2(2250, 480), Vector2(2440, 480)],           # Forest 1 <-> Forest 2
]
const RIVERS := [
	[Vector2(0, 40), Vector2(900, 30), Vector2(1800, 50), Vector2(3000, 30)],
	[Vector2(0, 1620), Vector2(1000, 1590), Vector2(2000, 1620), Vector2(3000, 1600)],
]

var _open := false
var _view
var _zoom := 0.6
var _pan := Vector2.ZERO            # posisi dunia yang berada di tengah layar
var _drag := false
var _cur_area := ""
var _player_world := Vector2.ZERO
var _trees: Array = []
var _bushes: Array = []


func _ready() -> void:
	layer = 85
	process_mode = Node.PROCESS_MODE_ALWAYS
	_gen_scenery()
	_view = MapView.new()
	_view.map = self
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.visible = false
	add_child(_view)
	_build_chrome()


func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_open = true
	_locate_player()
	_zoom = 0.6
	_pan = _player_world if _cur_area != "" else WORLD * 0.5
	_view.visible = true
	get_tree().paused = true
	_view.queue_redraw()


func close() -> void:
	if not _open:
		return
	_open = false
	_view.visible = false
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_M:
			get_viewport().set_input_as_handled()
			close()
		elif event.keycode == KEY_EQUAL or event.keycode == KEY_KP_ADD:
			_set_zoom(_zoom * 1.25)
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			_set_zoom(_zoom / 1.25)


func _set_zoom(z: float) -> void:
	_zoom = clampf(z, ZMIN, ZMAX)
	_view.queue_redraw()


# ------------------------------------------------------------------ posisi player
func _locate_player() -> void:
	_cur_area = ""
	var cs := get_tree().current_scene
	if cs == null:
		return
	var path := cs.scene_file_path
	var id := ""
	if "home" in path:
		id = "home"
	elif "farm" in path:
		id = "farm"
	elif "village" in path:
		id = "village"
	elif "forest" in path:
		id = "forest2" if "2" in path.get_file() else "forest1"
	if id == "":
		return
	_cur_area = id
	var a: Dictionary = AREAS[id]
	var rect: Rect2 = a["rect"]
	var b: Rect2 = a["b"]
	var pl := get_tree().get_first_node_in_group("player") as Node3D
	var t := Vector2(0.5, 0.5)
	if pl != null:
		t = Vector2((pl.global_position.x - b.position.x) / b.size.x, (pl.global_position.z - b.position.y) / b.size.y)
		t = Vector2(clampf(t.x, 0.03, 0.97), clampf(t.y, 0.03, 0.97))
	_player_world = rect.position + rect.size * t


# ------------------------------------------------------------------ dekorasi acak (tetap sama tiap dibuka)
func _gen_scenery() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8181
	for i in 1500:
		var p := Vector2(rng.randf_range(10, WORLD.x - 10), rng.randf_range(10, WORLD.y - 10))
		if _blocked(p, 26.0):
			continue
		_trees.append({"p": p, "s": rng.randf_range(0.8, 1.35), "t": rng.randi() % 3})
	for i in 500:
		var p2 := Vector2(rng.randf_range(10, WORLD.x - 10), rng.randf_range(10, WORLD.y - 10))
		if not _blocked(p2, 14.0):
			_bushes.append({"p": p2, "c": rng.randi() % 3})


func _blocked(p: Vector2, pad: float) -> bool:
	for id in AREAS:
		if (AREAS[id]["rect"] as Rect2).grow(pad + 8.0).has_point(p):
			return true
	for road in ROADS:
		for i in road.size() - 1:
			if Geometry2D.get_closest_point_to_segment(p, road[i], road[i + 1]).distance_to(p) < 30.0 + pad:
				return true
	for rv in RIVERS:
		for i in rv.size() - 1:
			if Geometry2D.get_closest_point_to_segment(p, rv[i], rv[i + 1]).distance_to(p) < 34.0 + pad:
				return true
	return false


# ------------------------------------------------------------------ tombol (judul, zoom, tutup)
func _build_chrome() -> void:
	var title := PanelContainer.new()
	title.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.BG, UiStyle.BORDER, 5, 6, true))
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.offset_top = 16.0
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl := UiStyle.label("World Map", 30)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.custom_minimum_size = Vector2(260, 0)
	title.add_child(tl)
	_view.add_child(title)
	var minus := _round_btn("-", Color(0.60, 0.60, 0.64), Vector2(24, 24))
	minus.pressed.connect(func() -> void: _set_zoom(_zoom / 1.3))
	_view.add_child(minus)
	var plus := _round_btn("+", Color(1.0, 0.78, 0.18), Vector2(98, 24))
	plus.pressed.connect(func() -> void: _set_zoom(_zoom * 1.3))
	_view.add_child(plus)
	var x := _round_btn("X", Color(0.86, 0.16, 0.20), Vector2(0, 24))
	x.anchor_left = 1.0
	x.anchor_right = 1.0
	x.offset_left = -88.0
	x.offset_right = -24.0
	x.pressed.connect(close)
	_view.add_child(x)
	var hint := UiStyle.label("Scroll = zoom     Drag = move     M / Esc = close", 18, Color(1, 1, 1, 0.9))
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 20.0
	hint.offset_top = -40.0
	hint.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	hint.add_theme_constant_override("outline_size", 6)
	_view.add_child(hint)


func _round_btn(txt: String, col: Color, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = txt
	b.position = pos
	b.custom_minimum_size = Vector2(64, 64)
	b.size = Vector2(64, 64)
	b.add_theme_font_size_override("font_size", 40)
	if UiStyle.font() != null:
		b.add_theme_font_override("font", UiStyle.font())
	var sb := UiStyle.box(col, Color(0.2, 0.1, 0.05), 4, 6, true)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", UiStyle.box(col.lightened(0.15), Color(0.2, 0.1, 0.05), 4, 6, true))
	b.add_theme_stylebox_override("pressed", UiStyle.box(col.darkened(0.15), Color(0.2, 0.1, 0.05), 4, 6, true))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	return b


# ------------------------------------------------------------------ kanvas peta
class MapView extends Control:
	var map

	func _w2s(p: Vector2) -> Vector2:
		return (p - map._pan) * map._zoom + size * 0.5

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton:
			if e.button_index == MOUSE_BUTTON_WHEEL_UP and e.pressed:
				map._set_zoom(map._zoom * 1.12)
			elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN and e.pressed:
				map._set_zoom(map._zoom / 1.12)
			elif e.button_index == MOUSE_BUTTON_LEFT:
				map._drag = e.pressed
		elif e is InputEventMouseMotion and map._drag:
			map._pan -= e.relative / map._zoom
			queue_redraw()

	func _draw() -> void:
		var z: float = map._zoom
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.78, 0.38))
		# sungai
		for rv in map.RIVERS:
			var pts := PackedVector2Array()
			for q in rv:
				pts.append(_w2s(q))
			draw_polyline(pts, Color(0.12, 0.50, 0.80), 46.0 * z, true)
			draw_polyline(pts, Color(0.35, 0.74, 0.95), 30.0 * z, true)
		# jalan
		for road in map.ROADS:
			var rp := PackedVector2Array()
			for q in road:
				rp.append(_w2s(q))
			draw_polyline(rp, Color(0.55, 0.36, 0.18), 38.0 * z, true)
			draw_polyline(rp, Color(0.82, 0.60, 0.34), 28.0 * z, true)
		# semak & pohon (hanya yang terlihat)
		var vis := Rect2(Vector2(-40, -40), size + Vector2(80, 80))
		for b in map._bushes:
			var bp := _w2s(b["p"])
			if vis.has_point(bp):
				draw_circle(bp, 9.0 * z, [Color(0.30, 0.62, 0.28), Color(0.78, 0.30, 0.30), Color(0.55, 0.40, 0.75)][b["c"]])
		for t in map._trees:
			var tp := _w2s(t["p"])
			if not vis.has_point(tp):
				continue
			var s: float = t["s"] * z
			draw_rect(Rect2(tp + Vector2(-3, 8) * s, Vector2(6, 12) * s), Color(0.45, 0.28, 0.14))
			var col := Color(0.12, 0.45, 0.30) if t["t"] != 1 else Color(0.18, 0.55, 0.28)
			var tri := PackedVector2Array([tp + Vector2(0, -26) * s, tp + Vector2(15, 12) * s, tp + Vector2(-15, 12) * s])
			draw_colored_polygon(tri, col)
			draw_colored_polygon(PackedVector2Array([tp + Vector2(0, -26) * s, tp + Vector2(8, -2) * s, tp + Vector2(-8, -2) * s]), col.lightened(0.18))
		# area
		for id in map.AREAS:
			_draw_area(id, z)
		# marker player
		if map._cur_area != "":
			var pp := _w2s(map._player_world)
			var bob := sin(Time.get_ticks_msec() * 0.006) * 4.0
			var tip := pp + Vector2(0, -6.0 + bob)
			draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-14, -30), tip + Vector2(14, -30)]), Color(0.9, 0.12, 0.15))
			draw_circle(tip + Vector2(0, -34), 15.0, Color(0.9, 0.12, 0.15))
			draw_circle(tip + Vector2(0, -34), 6.0, Color.WHITE)
			draw_arc(pp, 16.0, 0.0, TAU, 20, Color(1, 1, 1, 0.8), 3.0, true)
			queue_redraw()

	func _draw_area(id: String, z: float) -> void:
		var a: Dictionary = map.AREAS[id]
		var rr: Rect2 = a["rect"]
		var r := Rect2(_w2s(rr.position), rr.size * z)
		var forest: bool = id.begins_with("forest")
		var ground := Color(0.50, 0.74, 0.34) if not forest else Color(0.30, 0.55, 0.30)
		draw_rect(r.grow(10.0 * z), Color(0.50, 0.32, 0.16))                   # pagar / tebing
		draw_rect(r, ground)
		match id:
			"home":
				_house(r.position + r.size * Vector2(0.5, 0.45), 1.7 * z, Color(0.82, 0.30, 0.25))
				_dots(r, z, Color(0.95, 0.85, 0.30), 6, 11)
			"farm":
				for i in 2:
					var pr := Rect2(r.position + r.size * Vector2(0.12 + i * 0.46, 0.18), r.size * Vector2(0.34, 0.32))
					draw_rect(pr, Color(0.45, 0.28, 0.14))
					for gy in 5:
						draw_line(pr.position + Vector2(0, (gy + 0.5) * pr.size.y / 5.0), pr.position + Vector2(pr.size.x, (gy + 0.5) * pr.size.y / 5.0), Color(0.34, 0.20, 0.10), 2.0 * z)
				_house(r.position + r.size * Vector2(0.28, 0.80), 1.5 * z, Color(0.82, 0.30, 0.25))
				_house(r.position + r.size * Vector2(0.74, 0.80), 1.0 * z, Color(0.62, 0.45, 0.25))
			"village":
				var spots := [Vector2(0.2, 0.2), Vector2(0.5, 0.18), Vector2(0.8, 0.22), Vector2(0.18, 0.55), Vector2(0.82, 0.55), Vector2(0.3, 0.85), Vector2(0.7, 0.85)]
				var cols := [Color(0.82, 0.30, 0.25), Color(0.30, 0.50, 0.75), Color(0.85, 0.65, 0.25), Color(0.62, 0.40, 0.65), Color(0.45, 0.65, 0.45), Color(0.80, 0.45, 0.30), Color(0.35, 0.55, 0.60)]
				for i in spots.size():
					_house(r.position + r.size * spots[i], 1.35 * z, cols[i])
				draw_circle(r.position + r.size * Vector2(0.5, 0.52), 34.0 * z, Color(0.70, 0.62, 0.50))     # alun-alun
				draw_circle(r.position + r.size * Vector2(0.5, 0.52), 20.0 * z, Color(0.20, 0.55, 0.85))
			_:
				_dots(r, z, Color(0.20, 0.45, 0.22), 14, 7)
				_dots(r, z, Color(0.90, 0.40, 0.35), 5, 3)
		# nama area (tab krem)
		var f: Font = UiStyle.font() if UiStyle.font() != null else ThemeDB.fallback_font
		var fs := int(clampf(30.0 * z, 16.0, 44.0))
		var txt: String = a["name"]
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tab := Rect2(Vector2(r.position.x + r.size.x * 0.5 - tw * 0.5 - 16.0, r.position.y - fs - 26.0), Vector2(tw + 32.0, fs + 16.0))
		draw_style_box(UiStyle.box(UiStyle.BG, UiStyle.BORDER, 3, 5, true), tab)
		draw_string(f, tab.position + Vector2(16.0, fs + 3.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UiStyle.TEXT)

	func _house(c: Vector2, s: float, roof: Color) -> void:
		draw_rect(Rect2(c + Vector2(-22, -4) * s, Vector2(44, 30) * s), Color(0.90, 0.80, 0.60))
		draw_rect(Rect2(c + Vector2(-6, 8) * s, Vector2(12, 18) * s), Color(0.45, 0.28, 0.14))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-28, -2) * s, c + Vector2(0, -28) * s, c + Vector2(28, -2) * s]), roof)

	func _dots(r: Rect2, z: float, col: Color, n: int, seed_v: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_v * 977
		for i in n:
			var p := r.position + Vector2(rng.randf_range(0.08, 0.92), rng.randf_range(0.1, 0.9)) * r.size
			draw_circle(p, rng.randf_range(7.0, 13.0) * z, col)
