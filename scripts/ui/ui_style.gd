extends RefCounted
## UiStyle - gaya UI bersama (kotak krem berbingkai cokelat, tombol krem, tombol keyboard).
## Dipakai: main menu, menu ESC, pengaturan, kotak dialog. Panggil lewat preload:
##   const UiStyle := preload("res://scripts/ui/ui_style.gd")

const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"
const BG := Color(1.0, 0.90, 0.66)           # krem
const BG_LIGHT := Color(1.0, 0.95, 0.79)
const BG_DARK := Color(0.96, 0.80, 0.52)
const BORDER := Color(0.62, 0.36, 0.20)      # cokelat bingkai
const BORDER_DARK := Color(0.40, 0.21, 0.11)
const TEXT := Color(0.40, 0.17, 0.09)
const CYAN := Color(0.45, 0.92, 1.0)         # pilihan aktif
const CYAN_BORDER := Color(0.20, 0.38, 0.75)
const YELLOW := Color(1.0, 0.78, 0.18)
const YELLOW_BORDER := Color(0.78, 0.48, 0.08)
const DIM := Color(0.04, 0.03, 0.08, 0.62)

static var _font: Font
static var _font_tried := false


static func font() -> Font:
	if not _font_tried:
		_font_tried = true
		if ResourceLoader.exists(FONT_PATH):
			_font = load(FONT_PATH)
	return _font


static func box(bg := BG, border := BORDER, bw := 5, radius := 5, shadow := true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(bw)
	sb.border_color = border
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.32)
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


## Bingkai ganda ala buku (panel besar): luar cokelat, dalam krem terang bergaris.
static func frame() -> StyleBoxFlat:
	var sb := box(BG, BORDER, 8, 6, true)
	sb.shadow_size = 12
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	return sb


static func label(text := "", size := 26, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	var f := font()
	if f:
		l.add_theme_font_override("font", f)
	return l


## Tombol krem berbingkai cokelat. selected=true -> biru muda (kategori terpilih), accent=true -> kuning (tombol aksi kecil).
static func style_button(b: Button, size := 28, accent := false) -> void:
	var f := font()
	if f:
		b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_pressed_color", TEXT)
	b.add_theme_color_override("font_focus_color", TEXT)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.42, 0.30))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0))
	b.add_theme_constant_override("outline_size", 0)
	b.focus_mode = Control.FOCUS_NONE
	var base := YELLOW if accent else BG
	var edge := YELLOW_BORDER if accent else BORDER
	b.add_theme_stylebox_override("normal", box(base, edge, 4, 4))
	b.add_theme_stylebox_override("hover", box(base.lightened(0.18), edge, 4, 4))
	b.add_theme_stylebox_override("pressed", box(base.darkened(0.12), edge, 4, 4, false))
	b.add_theme_stylebox_override("focus", box(base.lightened(0.18), edge, 4, 4))
	b.add_theme_stylebox_override("disabled", box(base.darkened(0.18), edge.darkened(0.2), 4, 4, false))


static func select_style(b: Button, on: bool) -> void:
	if on:
		b.add_theme_stylebox_override("normal", box(CYAN, CYAN_BORDER, 4, 4))
		b.add_theme_stylebox_override("hover", box(CYAN, CYAN_BORDER, 4, 4))
	else:
		b.add_theme_stylebox_override("normal", box(BG, BORDER, 4, 4))
		b.add_theme_stylebox_override("hover", box(BG.lightened(0.18), BORDER, 4, 4))


## Tombol keyboard kecil (huruf F, E, ...).
static func keycap(key: String, size := 28) -> PanelContainer:
	var cap := PanelContainer.new()
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(0.27, 0.31, 0.50)
	csb.set_corner_radius_all(7)
	csb.set_border_width_all(3)
	csb.border_color = Color(0.13, 0.15, 0.27)
	csb.border_width_bottom = 6
	csb.content_margin_left = 12
	csb.content_margin_right = 12
	csb.content_margin_top = 2
	csb.content_margin_bottom = 2
	cap.add_theme_stylebox_override("panel", csb)
	cap.custom_minimum_size = Vector2(size + 18, size + 18)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := label(key, size, Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_child(l)
	return cap
