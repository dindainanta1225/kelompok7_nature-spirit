extends RefCounted
## Cinematic - alat bantu cutscene: bar sinematik, kunci input, dialog yang bisa di-await.
##   var cin := Cinematic.new(get_tree())
##   cin.begin()                      # kunci input, sembunyikan HUD, bar hitam muncul
##   await cin.say("Centorea", [...]) # tunggu dialog selesai
##   await cin.wait(1.0)
##   await cin.end()                  # bar hilang, input aktif lagi

const Sfx := preload("res://scripts/audio/sfx.gd")

var _tree: SceneTree
var _layer: CanvasLayer
var _top: ColorRect
var _bot: ColorRect
var _hud_was := true


func _init(tree: SceneTree) -> void:
	_tree = tree


func begin(bars := true) -> void:
	GameState.cutscene = true
	_hud_was = HUD.visible or not GameState.guide_met          # selama cerita pembuka belum selesai, HUD dipulihkan di akhir
	HUD.visible = false
	_set_hotbar(false)
	if bars:
		_layer = CanvasLayer.new()
		_layer.layer = 55
		_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		_tree.root.add_child(_layer)
		_top = _bar(true)
		_bot = _bar(false)
		var t := _layer.create_tween().set_parallel(true)
		t.tween_property(_top, "custom_minimum_size:y", 70.0, 0.8)
		t.tween_property(_bot, "custom_minimum_size:y", 70.0, 0.8)
		Sfx.play("whoosh", -10.0)
		await t.finished


func _bar(top: bool) -> ColorRect:
	var b := ColorRect.new()
	b.color = Color.BLACK
	b.anchor_left = 0.0
	b.anchor_right = 1.0
	b.anchor_top = 0.0 if top else 1.0
	b.anchor_bottom = 0.0 if top else 1.0
	b.offset_bottom = 70.0 if top else 0.0
	b.offset_top = 0.0 if top else -70.0
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(b)
	return b


## Dialog sinematik: HUD disembunyikan, tapi kotak dialog tetap tampil. Selesai saat baris terakhir ditutup.
func say(speaker: String, lines: Array) -> void:
	var st := {"done": false}
	HUD.say(speaker, lines, func() -> void: st["done"] = true)
	while not st["done"]:
		await _tree.process_frame


## Pertanyaan berpilihan yang bisa di-await -> indeks pilihan.
func ask(speaker: String, prompt: String, options: Array) -> int:
	var st := {"done": false, "i": -1}
	HUD.ask(speaker, prompt, options, func(i: int) -> void:
		st["i"] = i
		st["done"] = true)
	while not st["done"]:
		await _tree.process_frame
	return int(st["i"])


func wait(sec: float) -> void:
	await _tree.create_timer(sec, true, false, true).timeout


func _set_hotbar(on: bool) -> void:
	var ui = HUD.get("_inventory_ui")                         # hotbar bawah layar ada di CanvasLayer terpisah
	if ui != null:
		ui.visible = on


## Hentikan paksa (dipakai sebelum pindah scene dari tengah cutscene, mis. ending -> credits): bar hitam langsung dibuang
## supaya tidak ikut terbawa ke scene berikutnya (layer ini menempel di root, bukan di scene).
func abort() -> void:
	if _layer != null:
		_layer.queue_free()
		_layer = null
	GameState.cutscene = false


func end(keep_hidden := false) -> void:
	if _layer != null:
		var t := _layer.create_tween().set_parallel(true)
		t.tween_property(_top, "custom_minimum_size:y", 0.0, 0.6)
		t.tween_property(_bot, "custom_minimum_size:y", 0.0, 0.6)
		await t.finished
		_layer.queue_free()
		_layer = null
	if keep_hidden:                                           # masih lanjut ke scene berikutnya (cerita pembuka)
		return
	HUD.visible = _hud_was
	_set_hotbar(GameState.playing)
	GameState.cutscene = false
