extends RefCounted
## AppSettings - pengaturan pemain (disimpan di user://settings.cfg). Statis, tidak perlu autoload.
## Dimuat sekali oleh GameState._ready(); dipakai SettingsMenu, kamera, dan jam game.

const PATH := "user://settings.cfg"
const TIME_RATES := [1.0, 2.0, 3.0]                 # menit game per detik nyata: Slow / Normal / Fast
const TIME_NAMES := ["Slow", "Normal", "Fast"]
const PERCENTS := [25, 50, 75, 100]
const ACTIONS := [
	["move_forward", "Move Up"], ["move_backward", "Move Down"], ["move_left", "Move Left"], ["move_right", "Move Right"],
	["jump", "Jump"], ["interact", "Interact / Talk"], ["inventory", "Backpack"], ["map", "Map"],
	["calendar", "Calendar"], ["camera_toggle", "Camera View"],
]

static var time_speed := 1
static var applied_speed := -1                        # kecepatan yang benar-benar jalan; -1 = ikut time_speed (perubahan baru berlaku besok)
static var ui_scale := 1.0
static var cam_scale := 1.0
static var fullscreen := false
static var master := 1.0
static var music := 1.0
static var sfx := 1.0
static var keys := {}                                 # action -> physical keycode (hanya yang diubah pemain)
static var loaded := false


static func minutes_per_second() -> float:
	return TIME_RATES[clampi(applied_speed if applied_speed >= 0 else time_speed, 0, 2)]


static func load_and_apply(tree: SceneTree) -> void:
	if loaded:
		return
	loaded = true
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		time_speed = int(cf.get_value("game", "time_speed", 1))
		ui_scale = float(cf.get_value("game", "ui_scale", 1.0))
		cam_scale = float(cf.get_value("game", "cam_scale", 1.0))
		fullscreen = bool(cf.get_value("game", "fullscreen", false))
		master = float(cf.get_value("audio", "master", 1.0))
		music = float(cf.get_value("audio", "music", 1.0))
		sfx = float(cf.get_value("audio", "sfx", 1.0))
		keys = cf.get_value("controls", "keys", {})
	apply_all(tree)


static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "time_speed", time_speed)
	cf.set_value("game", "ui_scale", ui_scale)
	cf.set_value("game", "cam_scale", cam_scale)
	cf.set_value("game", "fullscreen", fullscreen)
	cf.set_value("audio", "master", master)
	cf.set_value("audio", "music", music)
	cf.set_value("audio", "sfx", sfx)
	cf.set_value("controls", "keys", keys)
	cf.save(PATH)


static func apply_all(tree: SceneTree) -> void:
	apply_ui_scale(tree)
	apply_audio()
	apply_fullscreen()
	for a in keys:
		_bind(String(a), int(keys[a]))


static func apply_ui_scale(tree: SceneTree) -> void:
	if tree != null and tree.root != null:
		tree.root.content_scale_factor = clampf(ui_scale, 0.25, 1.0)


static func apply_audio() -> void:
	_bus("Master", master)
	_bus("Music", music)
	_bus("SFX", sfx)


static func _bus(name: String, v: float) -> void:
	var i := AudioServer.get_bus_index(name)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001)


static func apply_fullscreen() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


static func rebind(action: String, keycode: int) -> void:
	keys[action] = keycode
	_bind(action, keycode)
	save()


static func _bind(action: String, keycode: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			InputMap.action_erase_event(action, ev)
	var e := InputEventKey.new()
	e.physical_keycode = keycode as Key
	InputMap.action_add_event(action, e)


static func key_name(action: String) -> String:
	if not InputMap.has_action(action):
		return "-"
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var k: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			return OS.get_keycode_string(k as Key)
	return "-"
