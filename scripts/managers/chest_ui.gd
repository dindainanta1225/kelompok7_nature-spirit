extends CanvasLayer
## ChestUI - jendela peti: atas = isi peti, bawah = backpack. Klik kiri = pindahkan semua, klik kanan = pindahkan 1.
## Dibuka lewat HUD.open_chest() (dipanggil peti di depan rumah). Esc / E / tombol X menutup.

const WoodPanel := preload("res://scripts/managers/wood_panel.gd")
const IUI := preload("res://scripts/managers/inventory_ui.gd")
const Inv := preload("res://scripts/managers/inventory.gd")
const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"
const CREAM := Color(1.0, 0.94, 0.78)
const GOLD := Color(1.0, 0.84, 0.30)
const MOSS := Color(0.62, 0.86, 0.45)
const OUTLINE := Color(0.14, 0.07, 0.03)

var _font: Font
var _open := false
var _root: Control
var _dim: ColorRect
var _card: Control
var _chest_slots: Array = []
var _bag_slots: Array = []
var _info: Label
var _tween: Tween


func _ready() -> void:
	layer = 53
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font
	_build()
	_root.visible = false
	GameState.chest.changed.connect(_refresh)
	GameState.inventory.changed.connect(_refresh)
	GameState.playing_changed.connect(func(on: bool) -> void:
		if not on and _open:
			_hide_now())


func is_open() -> bool:
	return _open


func open() -> void:
	if _open or not GameState.playing or get_tree().paused:
		return
	_open = true
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	if _tween and _tween.is_valid():
		_tween.kill()
	_dim.modulate.a = 0.0
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.92, 0.92)
	_card.pivot_offset = _card.size * 0.5
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 1.0, 0.15)
	_tween.tween_property(_card, "modulate:a", 1.0, 0.15)
	_tween.tween_property(_card, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not _open:
		return
	_open = false
	get_tree().paused = false
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 0.0, 0.1)
	_tween.tween_property(_card, "modulate:a", 0.0, 0.1)
	_tween.chain().tween_callback(func() -> void: _root.visible = false)


func _hide_now() -> void:
	_open = false
	_root.visible = false


func _input(event: InputEvent) -> void:
	if _open and GameState.playing and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact")):
		close()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ pindah item
func _move(from: Inv, i: int, to: Inv, one: bool) -> void:
	var s: Dictionary = from.slots[i]
	if s.is_empty():
		return
	var id: String = s["id"]
	var n: int = 1 if one else int(s["n"])
	var left := to.add(id, n)
	var moved := n - left
	if moved <= 0:
		GameState.toast.emit("No room!")
		return
	s["n"] = int(s["n"]) - moved
	if s["n"] <= 0:
		from.slots[i] = {}
	from.changed.emit()


func _on_chest_clicked(i: int, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT:
		_move(GameState.chest, i, GameState.inventory, button == MOUSE_BUTTON_RIGHT)


func _on_bag_clicked(i: int, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT:
		_move(GameState.inventory, i, GameState.chest, button == MOUSE_BUTTON_RIGHT)


func _hover(inv: Inv, i: int) -> void:
	if i < 0:
		_info.text = "Left click: move all    Right click: move one"
		return
	var id: String = inv.slot_item(i)
	_info.text = "Empty slot" if id == "" else "%s  x%d" % [Inv.items[id]["name"], inv.count(id)]


# ------------------------------------------------------------------ tampilan
func _apply(slot, inv: Inv, i: int) -> void:
	var s: Dictionary = inv.slots[i]
	slot.item_id = "" if s.is_empty() else String(s["id"])
	slot.amount = 0 if s.is_empty() else int(s["n"])
	slot.queue_redraw()


func _refresh() -> void:
	if _root == null or _chest_slots.is_empty():
		return
	for i in _chest_slots.size():
		_apply(_chest_slots[i], GameState.chest, i)
	for i in _bag_slots.size():
		_apply(_bag_slots[i], GameState.inventory, i)
		_bag_slots[i].is_selected = i == GameState.inventory.selected


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	l.add_theme_font_override("font", _font)
	return l


func _grid(parent: Control, slots: Array, inv: Inv, hotbar_tint: bool, on_click: Callable) -> void:
	var grid := GridContainer.new()
	grid.columns = Inv.HOTBAR
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(grid)
	for i in Inv.SLOTS:
		var s = IUI.Slot.new(i, 54.0, _font)
		s.tinted = hotbar_tint and i < Inv.HOTBAR
		if hotbar_tint and i < Inv.HOTBAR:
			s.key_hint = str(i + 1)
		s.clicked.connect(on_click)
		s.hovered.connect(func(idx: int) -> void: _hover(inv, idx))
		grid.add_child(s)
		slots.append(s)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_dim = ColorRect.new()
	_dim.color = Color(0.02, 0.03, 0.02, 0.6)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var card := WoodPanel.new()
	_card = card
	card.wood = Color(0.40, 0.25, 0.13)
	card.seed_value = 57
	card.margin = 22
	card.corner_radius = 16
	card.leaves = true
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var title := _label(36, GOLD)
	title.text = "Chest"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(38, 38)
	close_btn.add_theme_font_override("font", _font)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_color_override("font_color", CREAM)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": Color(0.55, 0.20, 0.16), "hover": Color(0.72, 0.28, 0.22), "pressed": Color(0.42, 0.14, 0.11)}[st]
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.07, 0.035, 0.02)
		close_btn.add_theme_stylebox_override(st, sb)
	close_btn.pressed.connect(close)
	top.add_child(close_btn)

	_grid(v, _chest_slots, GameState.chest, false, _on_chest_clicked)
	var bt := _label(26, MOSS)
	bt.text = "Backpack  (first row = hotbar)"
	v.add_child(bt)
	_grid(v, _bag_slots, GameState.inventory, true, _on_bag_clicked)
	_info = _label(18, Color(0.90, 0.84, 0.68))
	_info.text = "Left click: move all    Right click: move one"
	_info.custom_minimum_size = Vector2(300, 26)
	v.add_child(_info)
