extends Control

@onready var main_buttons: Control = $MainButtons
@onready var options: Panel = $Options
@onready var button_sound: AudioStreamPlayer = $Buttonsound

@onready var master_volume: HSlider = $Options/MasterVolume
@onready var music_volume: HSlider = $Options/MusicVolume
@onready var sfx_volume: HSlider = $Options/SFXVolume
@onready var fullscreen_control: CheckButton = $Options/FullscreenControl

const UiStyle := preload("res://scripts/ui/ui_style.gd")
const SettingsMenu := preload("res://scripts/ui/settings_menu.gd")
const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"
const CREAM := Color(1.0, 0.94, 0.78)
const GOLD := Color(1.0, 0.84, 0.30)
const INK := Color(0.12, 0.06, 0.03)


var _settings: Node


func _ready() -> void:
	_restyle()
	if GameState.playing:
		GameState.quit_to_menu()       # pastikan HUD hilang di main menu
	get_tree().paused = false
	main_buttons.visible = true
	options.visible = false

	# Ambil volume yang sedang digunakan
	master_volume.value = db_to_linear(
		AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index("Master")
		)
	) * 100.0

	music_volume.value = db_to_linear(
		AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index("Music")
		)
	) * 100.0

	sfx_volume.value = db_to_linear(
		AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index("SFX")
		)
	) * 100.0

	# Cek kondisi fullscreen
	fullscreen_control.button_pressed = (
		DisplayServer.window_get_mode()
		== DisplayServer.WINDOW_MODE_FULLSCREEN
	)


## Tampilan menu: tombol krem berbingkai cokelat (gaya sama dengan HUD/dialog), judul besar jauh di atas, tanpa tulisan lain.
## Tata letak: kiri Settings (atas) + Exit (bawah), tengah Play, kanan Credit (atas) + Continue (bawah).
func _restyle() -> void:
	for b in main_buttons.get_children():
		if b is Button:
			UiStyle.style_button(b as Button, 30)
			if b.name == "Start":
				UiStyle.style_button(b as Button, 36)
	options.visible = false
	var title := get_node_or_null("Title") as Label
	if title != null:
		title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.30))
		title.add_theme_color_override("font_outline_color", Color(0.36, 0.17, 0.06))
		title.add_theme_constant_override("outline_size", 24)
		title.add_theme_color_override("font_shadow_color", Color(0.05, 0.02, 0.0, 0.55))
		title.add_theme_constant_override("shadow_offset_x", 4)
		title.add_theme_constant_override("shadow_offset_y", 8)
		title.add_theme_font_size_override("font_size", 96)
		_fit_title(title)
		get_viewport().size_changed.connect(func() -> void: _fit_title(title))     # mode jendela kecil: judul turun mengikuti tinggi layar


## Judul diletakkan relatif terhadap tinggi layar supaya tidak keluar atas saat tidak fullscreen.
func _fit_title(title: Label) -> void:
	var h := float(get_viewport_rect().size.y)
	var up := minf(320.0, h * 0.34)                      # 1080 -> 320 (sama seperti sebelumnya), 720 -> 245
	title.offset_top = -up
	title.offset_bottom = -up + 135.0


func play_button_sound() -> void:
	button_sound.play()


# =========================
# MAIN MENU
# =========================

func _on_start_pressed() -> void:
	play_button_sound()
	await get_tree().create_timer(0.15).timeout
	for intro in ["res://scene/cutscene/story_intro.tscn"]:
		if ResourceLoader.exists(intro):
			get_tree().change_scene_to_file(intro)      # langsung ke cerita pembuka; game dimulai di akhir cerita
			return
	GameState.new_game()          # mulai hari 1, HUD & waktu aktif
	get_tree().change_scene_to_file(
		"res://scene/world/farm/farm.tscn"
	)


func _on_options_pressed() -> void:
	play_button_sound()
	if _settings == null:
		_settings = SettingsMenu.new()
		add_child(_settings)
	_settings.open(false)


func _on_continue_pressed() -> void:
	play_button_sound()
	# Mekanik save belum ada: tampilkan pesan singkat.
	var l := UiStyle.label("No saved game yet.", 26, Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.02))
	l.add_theme_constant_override("outline_size", 8)
	l.anchor_left = 0.5
	l.anchor_right = 0.5
	l.anchor_top = 1.0
	l.anchor_bottom = 1.0
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.offset_top = -230.0
	add_child(l)
	var t := create_tween()
	t.tween_interval(1.4)
	t.tween_property(l, "modulate:a", 0.0, 0.5)
	t.tween_callback(l.queue_free)


func _on_credit_pressed() -> void:
	play_button_sound()
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_file(
		"res://scene/main/Credits/credits.tscn"
	)


func _on_exit_pressed() -> void:
	play_button_sound()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit()


func _on_back_options_pressed() -> void:
	play_button_sound()
	main_buttons.visible = true
	options.visible = false


# =========================
# SETTINGS
# =========================

func _on_master_volume_value_changed(value: float) -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(
		bus,
		linear_to_db(value / 100.0)
	)


func _on_music_volume_value_changed(value: float) -> void:
	var bus := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(
		bus,
		linear_to_db(value / 100.0)
	)


func _on_sfx_volume_value_changed(value: float) -> void:
	var bus := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(
		bus,
		linear_to_db(value / 100.0)
	)


func _on_fullscreen_control_toggled(button_pressed: bool) -> void:
	if button_pressed:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_FULLSCREEN
		)
	else:
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED
		)
