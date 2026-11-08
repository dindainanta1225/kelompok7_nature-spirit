extends CanvasLayer
## Inventory UI (dibuat otomatis oleh HUD, tidak perlu autoload sendiri).
##  - Hotbar 11 slot di bawah layar (tombol 1-9, 0, -, atau klik). Item terpilih = item yang dipegang.
##  - Tombol I atau Tab membuka tas (33 slot). Klik satu slot lalu slot lain untuk menukar/memindah.
##    Klik kanan atau Esc untuk membatalkan / menutup. Waktu game berhenti selama tas terbuka.
## Tema: papan kayu coklat dengan daun hijau.

const WoodPanel := preload("res://scripts/managers/wood_panel.gd")
const Inv := preload("res://scripts/managers/inventory.gd")
const ItemIcons := preload("res://scripts/managers/item_icons.gd")

const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"
const ICON_DIR := "res://assets/items/"           # opsional: <id>.png menggantikan ikon gambar kode
const CREAM := Color(1.0, 0.94, 0.78)
const GOLD := Color(1.0, 0.84, 0.30)
const MOSS := Color(0.55, 0.85, 0.40)
const OUTLINE := Color(0.14, 0.07, 0.03)
const KIND_COLORS := {"tool": Color(0.70, 0.78, 0.92), "seed": Color(0.92, 0.80, 0.50), "crop": Color(0.55, 0.85, 0.40),
	"food": Color(1.0, 0.65, 0.40), "drop": Color(0.85, 0.65, 1.0)}

var _inv
var _font: Font
var _root: Control
var _hotbar_wrap: Control
var _hotbar_slots: Array = []
var _hotbar_name: Label
var _name_tween: Tween
var _window: Control
var _dim: ColorRect
var _card: Control
var _grid_slots: Array = []
var _info_icon: Control
var _info_name: Label
var _info_kind: Label
var _info_desc: Label
var _info_count: Label
var _coins_label: Label
var _hint: Label
var _open := false
var _picked := -1
var _hover := -1
var _tween: Tween
var _tex_cache := {}


## Satu kotak item (dipakai di hotbar dan di tas).
class Slot extends Control:
	signal clicked(index: int, button: int)
	signal hovered(index: int)
	var index := 0
	var item_id := ""
	var amount := 0
	var key_hint := ""
	var is_selected := false
	var is_picked := false
	var tinted := false
	var font: Font
	var icon_tex: Texture2D
	var _hov := false
	var _bg := StyleBoxFlat.new()

	func _init(i: int, px: float, f: Font) -> void:
		index = i
		font = f
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_STOP
		_bg.set_corner_radius_all(8)
		_bg.set_border_width_all(3)
		mouse_entered.connect(func() -> void:
			_hov = true
			hovered.emit(index)
			queue_redraw())
		mouse_exited.connect(func() -> void:
			_hov = false
			hovered.emit(-1)
			queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			clicked.emit(index, event.button_index)

	func _draw() -> void:
		var base := Color(0.17, 0.09, 0.05, 0.92)
		if tinted:
			base = Color(0.15, 0.20, 0.09, 0.92)
		if _hov:
			base = base.lightened(0.18)
		_bg.bg_color = base
		_bg.border_color = Color(0.07, 0.035, 0.02)
		if is_selected:
			_bg.border_color = Color(0.55, 0.88, 0.38)
		if is_picked:
			_bg.border_color = Color(1.0, 0.84, 0.30)
		_bg.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		if item_id != "":
			var d: Dictionary = Inv.items.get(item_id, {})
			var r := Rect2(Vector2(8, 8), size - Vector2(16, 16))
			if icon_tex:
				draw_texture_rect(icon_tex, r, false)
			else:
				ItemIcons.draw(self, r, d.get("kind", "drop"), d.get("shape", ""), d.get("color", Color.WHITE))
			if amount > 1 and font:
				var txt := str(amount)
				var fs := 20
				var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var pos := Vector2(size.x - w - 6.0, size.y - 6.0)
				draw_string_outline(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.1, 0.05, 0.02))
				draw_string(font, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.94, 0.78))
		if key_hint != "" and font:
			draw_string_outline(font, Vector2(7, 17), key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 5, Color(0.1, 0.05, 0.02))
			draw_string(font, Vector2(7, 17), key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.78, 0.6))
		if is_selected:
			draw_rect(Rect2(Vector2(1.5, 1.5), size - Vector2(3, 3)), Color(0.55, 0.88, 0.38, 0.18), false, 2.0)


func _ready() -> void:
	layer = 52
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font
	_inv = GameState.inventory
	_ensure_actions()
	_build()
	_inv.changed.connect(_refresh)
	_inv.selected_changed.connect(_on_selected)
	_inv.item_added.connect(_on_item_added)
	GameState.playing_changed.connect(_on_playing_changed)
	GameState.coins_changed.connect(func(_c: int) -> void: _update_coins())
	_on_playing_changed(GameState.playing)
	_refresh()


func _ensure_actions() -> void:
	_add_action("inventory", [KEY_I, KEY_TAB, KEY_B])
	for i in Inv.HOTBAR:
		_add_action("hotbar_%d" % (i + 1), [_hotbar_key(i)])


## Tombol hotbar: 1-9, lalu 0, lalu "-".
static func _hotbar_key(i: int) -> int:
	if i < 9:
		return KEY_1 + i
	return KEY_0 if i == 9 else KEY_MINUS


static func _hotbar_label(i: int) -> String:
	return str(i + 1) if i < 9 else ("0" if i == 9 else "-")


func _add_action(name: String, keys: Array) -> void:
	if InputMap.has_action(name):
		return
	InputMap.add_action(name)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(name, ev)


# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if not GameState.playing:
		return
	if _open:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory"):
			if _picked >= 0 and event.is_action_pressed("ui_cancel"):
				_picked = -1
				_refresh()
			else:
				close()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory") and not GameState.input_locked and not GameState.chatting and not get_tree().paused:
		open()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.playing or (get_tree().paused and not _open):
		return
	for i in Inv.HOTBAR:
		if event.is_action_pressed("hotbar_%d" % (i + 1)):
			_inv.select(i)
			get_viewport().set_input_as_handled()
			return
	if OS.is_debug_build() and event is InputEventKey and event.pressed and event.keycode == KEY_F9:
		for id in ["carrot", "potato", "corn", "strawberry", "apple", "bread", "imp_horn", "bear_claw", "gold_nugget", "forest_herb"]:
			_inv.add(id, randi_range(1, 9))


func is_open() -> bool:
	return _open


func open() -> void:
	if _open:
		return
	_open = true
	_picked = -1
	_window.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	if _tween and _tween.is_valid():
		_tween.kill()
	_dim.modulate.a = 0.0
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.9, 0.9)
	_card.pivot_offset = _card.size * 0.5
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 1.0, 0.15)
	_tween.tween_property(_card, "modulate:a", 1.0, 0.15)
	_tween.tween_property(_card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not _open:
		return
	_open = false
	_picked = -1
	get_tree().paused = false
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 0.0, 0.1)
	_tween.tween_property(_card, "modulate:a", 0.0, 0.1)
	_tween.chain().tween_callback(func() -> void: _window.visible = false)
	_refresh()


func _on_playing_changed(on: bool) -> void:
	_root.visible = on
	if not on and _open:
		_open = false
		_window.visible = false
	_refresh()


# ------------------------------------------------------------------ data -> tampilan

func _icon_for(id: String) -> Texture2D:
	if id == "":
		return null
	if _tex_cache.has(id):
		return _tex_cache[id]
	var path := ICON_DIR + id + ".png"
	var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[id] = tex
	return tex


func _apply(slot: Slot, i: int) -> void:
	var s: Dictionary = _inv.slots[i]
	slot.item_id = "" if s.is_empty() else String(s["id"])
	slot.amount = 0 if s.is_empty() else int(s["n"])
	slot.icon_tex = _icon_for(slot.item_id)
	slot.queue_redraw()


func _refresh() -> void:
	if _inv == null or _root == null:
		return
	for i in _hotbar_slots.size():
		var h: Slot = _hotbar_slots[i]
		_apply(h, i)
		h.is_selected = (i == _inv.selected)
	for i in _grid_slots.size():
		var g: Slot = _grid_slots[i]
		_apply(g, i)
		g.is_selected = (i == _inv.selected)
		g.is_picked = (i == _picked)
	_update_info()
	_update_coins()


func _update_coins() -> void:
	if _coins_label:
		_coins_label.text = "%s coins" % HUD.fmt(GameState.coins)


func _update_info() -> void:
	var idx: int = _hover if _hover >= 0 else (_picked if _picked >= 0 else int(_inv.selected))
	var id: String = _inv.slot_item(idx)
	if id == "":
		_info_name.text = "Empty"
		_info_kind.text = ""
		_info_desc.text = "Nothing here."
		_info_count.text = ""
		(_info_icon as Slot).item_id = ""
	else:
		var d: Dictionary = Inv.items[id]
		_info_name.text = d["name"]
		_info_kind.text = String(d["kind"]).capitalize()
		_info_kind.add_theme_color_override("font_color", KIND_COLORS.get(d["kind"], CREAM))
		_info_desc.text = d["desc"]
		var total: int = _inv.count(id)
		_info_count.text = "" if d["kind"] == "tool" else "You have %d" % total
		var ic := _info_icon as Slot
		ic.item_id = id
		ic.icon_tex = _icon_for(id)
	_info_icon.queue_redraw()
	_hint.text = "Pick an item, then click another slot to move or swap it." if _picked < 0 \
		else "Click a slot to place the item. Right click / Esc to cancel."


func _on_selected(_i: int) -> void:
	_refresh()
	var id: String = _inv.selected_item()
	_hotbar_name.text = Inv.items[id]["name"] if id != "" else ""
	_flash_name()


func _flash_name() -> void:
	if _name_tween and _name_tween.is_valid():
		_name_tween.kill()
	_hotbar_name.modulate.a = 1.0
	_name_tween = create_tween()
	_name_tween.tween_interval(1.1)
	_name_tween.tween_property(_hotbar_name, "modulate:a", 0.0, 0.5)


func _on_item_added(id: String, amount: int) -> void:
	if GameState.playing:
		GameState.toast.emit("+%d %s" % [amount, Inv.items[id]["name"]])


# ------------------------------------------------------------------ klik

func _on_hotbar_clicked(i: int, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT and not get_tree().paused:
		_inv.select(i)


func _on_grid_clicked(i: int, button: int) -> void:
	if button == MOUSE_BUTTON_RIGHT:
		_picked = -1
	elif button == MOUSE_BUTTON_LEFT:
		if _picked < 0:
			if _inv.slot_item(i) != "":
				_picked = i
		elif _picked == i:
			_picked = -1
		else:
			_inv.swap(_picked, i)
			_picked = -1
	_refresh()


func _on_grid_hover(i: int) -> void:
	_hover = i
	_update_info()


# ------------------------------------------------------------------ bangun UI

func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	if _font:
		l.add_theme_font_override("font", _font)
	return l


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# ---- hotbar (bawah-tengah)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 4)
	hv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hv.anchor_left = 0.5
	hv.anchor_right = 0.5
	hv.anchor_top = 1.0
	hv.anchor_bottom = 1.0
	hv.offset_bottom = -14.0
	hv.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hv.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(hv)
	_hotbar_wrap = hv
	_hotbar_name = _label(24, GOLD)
	_hotbar_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hotbar_name.modulate.a = 0.0
	hv.add_child(_hotbar_name)
	var hp := WoodPanel.new()
	hp.wood = Color(0.40, 0.25, 0.13)
	hp.seed_value = 11
	hp.margin = 12
	hp.corner_radius = 12
	hv.add_child(hp)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.add_child(row)
	for i in Inv.HOTBAR:
		var s := Slot.new(i, 54.0, _font)
		s.key_hint = _hotbar_label(i)
		s.clicked.connect(_on_hotbar_clicked)
		row.add_child(s)
		_hotbar_slots.append(s)

	# ---- jendela tas
	_window = Control.new()
	_window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.visible = false
	_root.add_child(_window)
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.03, 0.02, 0.55)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_window.add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(center)
	var card := WoodPanel.new()
	_card = card
	card.wood = Color(0.40, 0.25, 0.13)
	card.seed_value = 21
	card.margin = 24
	card.corner_radius = 16
	card.leaves = true
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)

	var title := _label(44, GOLD)
	title.text = "Backpack"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 20)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(body)

	# grid 8 x 3
	var gv := VBoxContainer.new()
	gv.add_theme_constant_override("separation", 4)
	gv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(gv)
	var grid := GridContainer.new()
	grid.columns = Inv.HOTBAR
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gv.add_child(grid)
	for i in Inv.SLOTS:
		var s := Slot.new(i, 56.0, _font)
		s.tinted = i < Inv.HOTBAR
		if i < Inv.HOTBAR:
			s.key_hint = _hotbar_label(i)
		s.clicked.connect(_on_grid_clicked)
		s.hovered.connect(_on_grid_hover)
		grid.add_child(s)
		_grid_slots.append(s)
	# panel info
	var info := PanelContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.custom_minimum_size = Vector2(250, 340)      # ukuran tetap: hover tidak mengubah ukuran jendela (anti-geter)
	var isb := StyleBoxFlat.new()
	isb.bg_color = Color(0.17, 0.09, 0.05, 0.85)
	isb.set_corner_radius_all(10)
	isb.set_border_width_all(3)
	isb.border_color = Color(0.07, 0.035, 0.02)
	isb.set_content_margin_all(14.0)
	info.add_theme_stylebox_override("panel", isb)
	body.add_child(info)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 6)
	iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(iv)
	var icon_row := CenterContainer.new()
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	iv.add_child(icon_row)
	var big := Slot.new(-1, 84.0, null)
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_icon = big
	icon_row.add_child(big)
	_info_name = _label(26, CREAM)
	_info_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART      # nama panjang turun ke baris ke-2, tidak terpotong
	_info_name.custom_minimum_size = Vector2(210, 64)
	_info_name.max_lines_visible = 2
	_info_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iv.add_child(_info_name)
	_info_kind = _label(18, MOSS)
	_info_kind.clip_text = true
	_info_kind.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iv.add_child(_info_kind)
	_info_desc = _label(18, Color(0.90, 0.84, 0.68))
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_desc.custom_minimum_size = Vector2(210, 130)
	_info_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_info_desc.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_info_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_desc.max_lines_visible = 6
	_info_desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_info_desc.add_theme_constant_override("outline_size", 3)
	iv.add_child(_info_desc)
	_info_count = _label(20, GOLD)
	_info_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iv.add_child(_info_count)

	# footer
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(foot)
	_hint = _label(16, Color(0.85, 0.78, 0.60))
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.clip_text = true
	_hint.custom_minimum_size = Vector2(200, 0)
	foot.add_child(_hint)
	_coins_label = _label(22, GOLD)
	foot.add_child(_coins_label)
