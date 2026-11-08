extends CanvasLayer
const Sfx := preload("res://scripts/audio/sfx.gd")
## DialogueBox - kotak dialog NPC di bawah layar (dibuat otomatis oleh HUD).
## Pakai:  HUD.say("Martha", ["Hello!", "Welcome."], func(): print("selesai"))
## E / Space / Enter / klik = lanjut. Game berhenti selama dialog.

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"
const CREAM := Color(1.0, 0.94, 0.78)
const GOLD := Color(1.0, 0.84, 0.30)
const OUTLINE := Color(0.14, 0.07, 0.03)

var _font: Font
var _root: Control
var _name: Label
var _text: Label
var _hint: Label
var _reply_box: PanelContainer      # kotak jawaban player (kanan atas, seperti di VN)
var _reply: Label
var _cur: Label                      # label yang sedang diketik (_text atau _reply)
var _arrow: Label
var _bob := 0.0
var _lines: Array = []
var _idx := 0
var _done: Callable
var _open := false
var _tween: Tween
var _choices: VBoxContainer
var _asking := false
var _ask_cb := Callable()
var _ask_n := 0
var _portrait: TextureRect           # potret NPC (model 3D dipotret setengah badan), di kiri kotak dialog
var _pvp: SubViewport
var _pmodel: Node3D


func _ready() -> void:
	layer = 57
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	_build()
	_root.visible = false


func is_open() -> bool:
	return _open


func say(speaker: String, lines: Array, on_done: Callable = Callable(), freeze := true) -> void:
	if lines.is_empty():
		if on_done.is_valid():
			on_done.call()
		return
	_lines = _paginate(lines)
	_idx = 0
	_done = on_done
	_name.text = speaker
	_text.text = ""
	_open = true
	_root.visible = true
	_set_freeze(freeze)
	_show_line()


## Kalimat yang terlalu panjang untuk kotak dipecah jadi beberapa kotak (maks 3 baris per kotak), bukan membesarkan kotak.
func _paginate(lines: Array) -> Array:
	var out: Array = []
	var f: Font = UiStyle.font() if UiStyle.font() != null else ThemeDB.fallback_font
	var fs := 22
	var width := 680.0
	var max_h := f.get_height(fs) * 3.0 + 4.0
	for l in lines:
		var line := String(l)
		if line.begins_with("> ") or f.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, width, fs).y <= max_h:
			out.append(line)
			continue
		var cur := ""
		for w in line.split(" ", false):
			var trial := w if cur == "" else cur + " " + w
			if cur != "" and f.get_multiline_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, width, fs).y > max_h:
				out.append(cur)
				cur = w
			else:
				cur = trial
		if cur != "":
			out.append(cur)
	return out


## freeze=true: game dijeda (toko). freeze=false: dunia & waktu tetap berjalan, player hanya dikunci (ngobrol dengan NPC biasa).
func _set_freeze(freeze: bool) -> void:
	if freeze:
		get_tree().paused = true
	else:
		GameState.chatting = true


func _release() -> void:
	_clear_portrait()
	get_tree().paused = false
	GameState.chatting = false


func _show_line() -> void:
	var line := String(_lines[_idx])
	if line.begins_with("> "):                    # jawaban player: muncul di kotak kanan, kotak NPC tetap menampilkan kalimat terakhir
		_reply.text = line.substr(2)
		_reply_box.visible = true
		_cur = _reply
		if _text.text == "":
			_text.text = "..."
	else:
		_reply_box.visible = false
		_text.text = line
		_cur = _text
	_cur.visible_ratio = 0.0
	_last_chars = 0
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_type_tick, 0.0, 1.0, maxf(0.25, _cur.text.length() * 0.018))
	_hint.text = "[E] Continue" if _idx < _lines.size() - 1 else "[E] Close"


var _last_chars := 0


func _type_tick(r: float) -> void:
	_cur.visible_ratio = r
	var c := int(r * _cur.text.length())
	if c != _last_chars:
		if c % 2 == 0 and c < _cur.text.length() and _cur.text[maxi(c - 1, 0)] != " ":
			Sfx.play("blip", -10.0, randf_range(0.8, 1.4))
		_last_chars = c


func _advance() -> void:
	if _cur.visible_ratio < 1.0:
		if _tween and _tween.is_valid():
			_tween.kill()
		_cur.visible_ratio = 1.0
		return
	_idx += 1
	if _idx >= _lines.size():
		_open = false
		_root.visible = false
		_release()
		if _done.is_valid():
			_done.call_deferred()
		return
	_show_line()


## Pertanyaan berpilihan: tampilkan `prompt`, lalu tombol pilihan. Klik / tekan angka 1-9. Esc = pilihan terakhir.
## on_pick dipanggil dengan indeks pilihan (0, 1, ...).
func ask(speaker: String, prompt: String, options: Array, on_pick: Callable, freeze := true) -> void:
	_lines = [prompt]
	_idx = 0
	_done = Callable()
	_name.text = speaker
	_text.text = ""
	_open = true
	_asking = true
	_ask_cb = on_pick
	_ask_n = options.size()
	_root.visible = true
	_set_freeze(freeze)
	for c in _choices.get_children():
		c.queue_free()
	for i in options.size():
		var b := Button.new()
		b.text = "%d.  %s" % [i + 1, options[i]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 40)
		UiStyle.style_button(b, 22)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var idx := i
		b.pressed.connect(func() -> void: _pick(idx))
		b.mouse_entered.connect(func() -> void: Sfx.play("hotbar", -8.0))
		_choices.add_child(b)
	_choices.visible = true
	_show_line()
	_hint.text = "[1-%d] or click to choose" % _ask_n


func _pick(i: int) -> void:
	if not _asking:
		return
	_asking = false
	_choices.visible = false
	_open = false
	_root.visible = false
	_release()
	Sfx.play("select")
	if _ask_cb.is_valid():
		_ask_cb.call_deferred(i)


func _input(event: InputEvent) -> void:
	if not _open:
		return
	if _asking:
		if event is InputEventKey and event.pressed and not event.echo:
			var n: int = event.keycode - KEY_1
			if n >= 0 and n < _ask_n:
				get_viewport().set_input_as_handled()
				_pick(n)
			elif event.keycode == KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_pick(_ask_n - 1)
			elif event.keycode == KEY_SPACE or event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				if _cur.visible_ratio < 1.0:
					if _tween and _tween.is_valid():
						_tween.kill()
					_cur.visible_ratio = 1.0
		return
	var go: bool = event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		go = true
	if go:
		get_viewport().set_input_as_handled()
		_advance()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_idx = _lines.size() - 1
		_cur.visible_ratio = 1.0
		_advance()


func _process(delta: float) -> void:
	if _open and _arrow != null:
		_bob += delta * 6.0
		_arrow.position.y = _arrow_y + sin(_bob) * 3.0
		_arrow.visible = _cur != null and _cur.visible_ratio >= 1.0 and not _asking


var _arrow_y := 0.0


## Potret NPC: SubViewport berdunia sendiri berisi salinan model NPC, kamera menyorot setengah badan atas.
func _build_portrait() -> void:
	_pvp = SubViewport.new()
	_pvp.size = Vector2i(420, 560)
	_pvp.transparent_bg = true
	_pvp.own_world_3d = true
	_pvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_pvp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 0.96, 0.9)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	_pvp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-25), deg_to_rad(25), 0)
	sun.light_energy = 1.1
	_pvp.add_child(sun)
	var cam := Camera3D.new()
	cam.name = "PCam"
	cam.fov = 28.0
	_pvp.add_child(cam)
	_portrait = TextureRect.new()
	_portrait.texture = _pvp.get_texture()
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.anchor_left = 0.5
	_portrait.anchor_right = 0.5
	_portrait.anchor_top = 1.0
	_portrait.anchor_bottom = 1.0
	_portrait.offset_left = -575.0
	_portrait.offset_right = -255.0
	_portrait.offset_top = -527.0
	_portrait.offset_bottom = -100.0
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.visible = false
	_root.add_child(_portrait)


func _set_portrait(speaker: String) -> void:
	if _portrait == null:
		return
	if _pmodel != null and is_instance_valid(_pmodel):
		_pmodel.queue_free()
	_pmodel = null
	_portrait.visible = false
	_pvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var src: Node3D = null
	for n in get_tree().get_nodes_in_group("npc"):
		if String(n.get("display_name")) == speaker and n.get("_char") != null:
			src = n.get("_char") as Node3D
			break
	if src == null or not is_instance_valid(src):
		return
	var m := src.duplicate() as Node3D
	if m == null:
		return
	m.position = Vector3.ZERO
	m.rotation = Vector3.ZERO
	_pvp.add_child(m)
	_pmodel = m
	var box := AABB()
	var first := true
	var stack: Array = [m]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c in n.get_children():
			stack.append(c)
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var a: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
			box = a if first else box.merge(a)
			first = false
	if first or box.size.y < 0.2:
		m.queue_free()
		_pmodel = null
		return
	var top := box.end.y
	var span := minf(box.size.y, 1.35)                   # setengah badan atas (kepala sampai dada/pinggang)
	var focus := Vector3((box.position.x + box.end.x) * 0.5, top - span * 0.5, (box.position.z + box.end.z) * 0.5)
	var cam := _pvp.get_node("PCam") as Camera3D
	var dist := span * 0.5 / tan(deg_to_rad(cam.fov * 0.5)) * 1.25
	cam.position = focus + Vector3(0, 0.05 * span, dist)
	cam.look_at(focus, Vector3.UP)
	_pvp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_portrait.visible = true


func _clear_portrait() -> void:
	if _portrait != null:
		_portrait.visible = false
	if _pvp != null:
		_pvp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _pmodel != null and is_instance_valid(_pmodel):
		_pmodel.queue_free()
	_pmodel = null


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	# kotak utama (krem, bingkai cokelat) + tab nama di kiri atas
	var box := Control.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -400.0
	box.offset_right = 400.0
	box.offset_top = -270.0
	box.offset_bottom = -104.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.frame())
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_top = 36.0
	var psb := UiStyle.frame()
	psb.content_margin_left = 36
	psb.content_margin_right = 60
	panel.add_theme_stylebox_override("panel", psb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(panel)
	_text = UiStyle.label("", 22)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER       # teks di tengah kotak
	panel.add_child(_text)
	var tab := PanelContainer.new()
	tab.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.BG_LIGHT, UiStyle.BORDER, 4, 5, true))
	tab.position = Vector2(40, 0)
	tab.custom_minimum_size = Vector2(150, 44)
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name = UiStyle.label("", 26)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab.add_child(_name)
	box.add_child(tab)
	_arrow = UiStyle.label("v", 30, UiStyle.BORDER)           # panah lanjut (naik-turun)
	_arrow.position = Vector2(760, 122)
	_arrow_y = 122.0
	box.add_child(_arrow)
	_hint = UiStyle.label("", 16, Color(0.55, 0.30, 0.15))
	_hint.position = Vector2(620, 136)
	_hint.visible = false
	box.add_child(_hint)
	# kotak jawaban player (kanan atas kotak utama)
	_reply_box = PanelContainer.new()
	_reply_box.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.BG, UiStyle.BORDER, 5, 5, true))
	_reply_box.anchor_left = 1.0
	_reply_box.anchor_right = 1.0
	_reply_box.anchor_top = 1.0
	_reply_box.anchor_bottom = 1.0
	_reply_box.offset_right = -190.0
	_reply_box.offset_bottom = -280.0
	_reply_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_reply_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_reply_box.custom_minimum_size = Vector2(300, 0)
	_reply_box.visible = false
	_reply_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reply = UiStyle.label("", 24)
	_reply.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reply.custom_minimum_size = Vector2(300, 0)
	_reply_box.add_child(_reply)
	_root.add_child(_reply_box)
	_root.move_child(_portrait, _root.get_child_count() - 1)       # potret di depan kotak (menimpa sisi kiri)
	_cur = _text
	_choices = VBoxContainer.new()                # tombol pilihan (di atas kotak dialog)
	_choices.add_theme_constant_override("separation", 6)
	_choices.custom_minimum_size = Vector2(620, 0)
	_choices.anchor_left = 0.5
	_choices.anchor_right = 0.5
	_choices.anchor_top = 1.0
	_choices.anchor_bottom = 1.0
	_choices.offset_left = -310.0
	_choices.offset_right = 310.0
	_choices.offset_bottom = -208.0
	_choices.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_choices.visible = false
	_root.add_child(_choices)
