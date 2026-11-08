extends CanvasLayer
## ShopUI - jendela jual-beli (dibuat otomatis oleh HUD). Buka dari mana saja:  HUD.open_shop("general")
##   general    = General Store (Martha): beli benih, jual hasil panen & loot monster
##   blacksmith = Blacksmith (Gordon): upgrade Hoe / Watering Can / Scythe (lebih banyak petak) dan Sword
##   food       = Food Shop (Lily): beli makanan (pulihkan energi, maks 3x makan per hari)
## Harga ada di scripts/shops/shop_data.gd. Esc / tombol X menutup. Game berhenti selama toko terbuka.

const WoodPanel := preload("res://scripts/managers/wood_panel.gd")
const Inv := preload("res://scripts/managers/inventory.gd")
const ItemIcons := preload("res://scripts/managers/item_icons.gd")
const Data := preload("res://scripts/shops/shop_data.gd")
const Icons := preload("res://scripts/managers/hud_icons.gd")

const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"
const CREAM := Color(1.0, 0.94, 0.78)
const GOLD := Color(1.0, 0.84, 0.30)
const MOSS := Color(0.62, 0.86, 0.45)
const MUTED := Color(0.80, 0.72, 0.55)
const RED := Color(1.0, 0.45, 0.38)
const OUTLINE := Color(0.14, 0.07, 0.03)

var _font: Font
var _open := false
var _shop := ""
var _tab := 0
var _root: Control
var _dim: ColorRect
var _card: Control
var _title: Label
var _hello: Label
var _coins: Label
var _tabs_box: HBoxContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _tween: Tween


## Kotak ikon item (digambar lewat kode).
class IconBox extends Control:
	var item_id := ""

	func _init(id: String, px: float = 52.0) -> void:
		item_id = id
		custom_minimum_size = Vector2(px, px)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.10, 0.06, 0.03, 0.95)
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.45, 0.30, 0.16)
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var d: Dictionary = Inv.items.get(item_id, {})
		ItemIcons.draw(self, Rect2(Vector2(6, 6), size - Vector2(12, 12)), d.get("kind", "drop"), d.get("shape", ""), d.get("color", Color.WHITE))


func _ready() -> void:
	layer = 56
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	if _font == null:
		_font = ThemeDB.fallback_font
	_build()
	_root.visible = false
	GameState.coins_changed.connect(func(_c: int) -> void: _update_coins())
	GameState.playing_changed.connect(func(on: bool) -> void:
		if not on and _open:
			_hide_now())


func is_open() -> bool:
	return _open


func _input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ buka / tutup
func open(shop_id: String) -> void:
	if _open or not Data.SHOPS.has(shop_id):
		return
	_open = true
	_shop = shop_id
	_tab = 0
	var d: Dictionary = Data.SHOPS[shop_id]
	_title.text = d["title"]
	_hello.text = "%s: \"%s\"" % [d["keeper"], d["hello"]]
	_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rebuild_tabs()
	_rebuild_list()
	_update_coins()
	if _tween and _tween.is_valid():
		_tween.kill()
	_dim.modulate.a = 0.0
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.92, 0.92)
	_card.pivot_offset = _card.size * 0.5
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_dim, "modulate:a", 1.0, 0.15)
	_tween.tween_property(_card, "modulate:a", 1.0, 0.15)
	_tween.tween_property(_card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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


func _update_coins() -> void:
	if _coins:
		_coins.text = "%s coins" % HUD.fmt(GameState.coins)


# ------------------------------------------------------------------ isi
func _rebuild_tabs() -> void:
	for c in _tabs_box.get_children():
		c.queue_free()
	var tabs: Array = Data.SHOPS[_shop]["tabs"]
	for i in tabs.size():
		var b := _btn(tabs[i], i == _tab, 130.0)
		var idx := i
		b.pressed.connect(func() -> void:
			_tab = idx
			_rebuild_tabs()
			_rebuild_list())
		_tabs_box.add_child(b)


func _rebuild_list() -> void:
	var keep := _scroll.scroll_vertical
	for c in _list.get_children():
		c.queue_free()
	var tab: String = Data.SHOPS[_shop]["tabs"][_tab]
	match tab:
		"Buy":
			for c in Inv.CROPS:
				_add_buy_row(c[0] + "_seed", [["x1", 1], ["x10", 10]])
		"Sell":
			_add_sell_rows()
		"Menu":
			for id in Data.FOOD:
				_add_buy_row(id, [["Buy", 1]])
		"Upgrade":
			for t in Data.TOOL_ORDER:
				_add_upgrade_row(t)
	_scroll.set_deferred("scroll_vertical", keep)


func _add_buy_row(id: String, qtys: Array) -> void:
	var d: Dictionary = Inv.items[id]
	var price := Data.buy_price(id)
	var sub := ""
	if id.ends_with("_seed"):
		var crop := id.trim_suffix("_seed")
		sub = "Ripe in %d days  ·  sells for %s" % [Inv.crop_days(crop), HUD.fmt(Data.sell_price(crop))]
	elif Data.FOOD.has(id):
		sub = "Restores %d energy" % int(Data.FOOD[id][1])
	var buttons: Array = []
	for q in qtys:
		var qty: int = q[1]
		buttons.append([q[0], func() -> void: _buy(id, qty), GameState.coins >= price * qty])
	_add_row(id, d["name"], sub, price, buttons)


func _add_sell_rows() -> void:
	var any := false
	for id in Inv.items:
		var price := Data.sell_price(id)
		var have: int = GameState.inventory.count(id)
		if price <= 0 or have <= 0:
			continue
		any = true
		var d: Dictionary = Inv.items[id]
		_add_row(id, d["name"], "You have %d" % have, price, [
			["x1", func() -> void: _sell(id, 1), true],
			["All", func() -> void: _sell(id, have), true]])
	if not any:
		var l := _label(22, MUTED)
		l.text = "You have nothing to sell yet.\nHarvest crops or hunt monsters!"
		_list.add_child(l)


func _add_upgrade_row(tool: String) -> void:
	var lvl := GameState.tool_level(tool)
	var costs: Dictionary = Data.TOOL_COST[tool]
	var nxt := lvl + 1 if lvl > 0 else 1
	var name_txt: String = Data.tool_display(tool)
	var sub := ""
	var price := 0
	var buttons: Array = []
	if not costs.has(nxt):
		sub = "Level %d (MAX)  ·  %s" % [lvl, Data.tool_effect(tool, lvl)]
		buttons.append(["MAX", func() -> void: pass, false])
	else:
		price = int(costs[nxt])
		if lvl == 0:
			sub = "Not owned  ·  Lv 1: %s" % Data.tool_effect(tool, 1)
			buttons.append(["Buy", func() -> void: _upgrade(tool), GameState.coins >= price])
		else:
			sub = "Level %d  ->  %d  ·  %s" % [lvl, nxt, Data.tool_effect(tool, nxt)]
			buttons.append(["Upgrade", func() -> void: _upgrade(tool), GameState.coins >= price])
	_add_row(tool, name_txt, sub, price, buttons)


func _add_row(id: String, title: String, sub: String, price: int, buttons: Array) -> void:
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.17, 0.09, 0.05, 0.88)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.07, 0.035, 0.02)
	sb.set_content_margin_all(8.0)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(0, 70)
	_list.add_child(pc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(row)
	row.add_child(IconBox.new(id))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var n := _label(24, CREAM)
	n.text = title
	col.add_child(n)
	var s := _label(16, MUTED)
	s.text = sub
	s.clip_text = true
	s.custom_minimum_size = Vector2(250, 0)
	col.add_child(s)
	if price > 0:
		var pr := HBoxContainer.new()
		pr.add_theme_constant_override("separation", 6)
		pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pr)
		var pl := _label(24, GOLD)
		pl.text = HUD.fmt(price)
		pl.custom_minimum_size = Vector2(96, 0)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pr.add_child(pl)
	for b in buttons:
		var btn := _btn(b[0], false, 86.0)
		btn.disabled = not b[2]
		btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(b[1])
		row.add_child(btn)


# ------------------------------------------------------------------ transaksi
func _buy(id: String, qty: int) -> void:
	var unit := Data.buy_price(id)
	if unit <= 0 or not GameState.spend_coins(unit * qty):
		return
	var left: int = GameState.inventory.add(id, qty)
	if left > 0:
		GameState.add_coins(left * unit)                 # tas penuh -> uang kembali
		GameState.toast.emit("Your bag is full!")
	_after()


func _sell(id: String, qty: int) -> void:
	qty = mini(qty, GameState.inventory.count(id))
	if qty <= 0 or not GameState.inventory.remove(id, qty):
		return
	GameState.add_coins(Data.sell_price(id) * qty)
	_after()


func _upgrade(tool: String) -> void:
	var lvl := GameState.tool_level(tool)
	var nxt := lvl + 1
	var costs: Dictionary = Data.TOOL_COST[tool]
	if not costs.has(nxt):
		return
	var price: int = costs[nxt]
	if not GameState.spend_coins(price):
		return
	if tool == "sword" and lvl == 0:
		if GameState.inventory.add("sword", 1) > 0:
			GameState.add_coins(price)
			GameState.toast.emit("Your bag is full!")
			return
	GameState.tool_levels[tool] = nxt
	GameState.toast.emit("%s is now level %d!" % [Data.tool_display(tool), nxt])
	_after()


func _after() -> void:
	_update_coins()
	_rebuild_list()


# ------------------------------------------------------------------ bangun UI
func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", maxi(4, size / 5))
	l.add_theme_font_override("font", _font)
	return l


func _btn(text: String, active: bool, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(w, 40)
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.48, 0.38))
	var base := Color(0.30, 0.55, 0.30) if active else Color(0.45, 0.28, 0.14)
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"normal": base, "hover": base.lightened(0.15), "pressed": base.darkened(0.2), "disabled": Color(0.22, 0.15, 0.10)}[st]
		sb.set_corner_radius_all(8)
		sb.set_border_width_all(2)
		sb.border_color = Color(0.07, 0.035, 0.02)
		b.add_theme_stylebox_override(st, sb)
	return b


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
	card.seed_value = 71
	card.margin = 22
	card.corner_radius = 16
	card.leaves = true
	card.custom_minimum_size = Vector2(760, 500)          # ukuran tetap
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(v)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	_title = _label(40, GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	_coins = _label(26, GOLD)
	_coins.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_coins.custom_minimum_size = Vector2(190, 0)
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(_coins)
	var x := _btn("X", false, 40.0)
	x.add_theme_stylebox_override("normal", _red_box(Color(0.55, 0.20, 0.16)))
	x.add_theme_stylebox_override("hover", _red_box(Color(0.72, 0.28, 0.22)))
	x.pressed.connect(close)
	top.add_child(x)

	_hello = _label(18, MUTED)
	_hello.clip_text = true
	_hello.custom_minimum_size = Vector2(300, 0)
	v.add_child(_hello)
	_tabs_box = HBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 8)
	_tabs_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tabs_box.custom_minimum_size = Vector2(0, 42)
	v.add_child(_tabs_box)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size = Vector2(0, 320)
	v.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)


func _red_box(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.07, 0.035, 0.02)
	return sb
