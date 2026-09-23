extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var options: Panel = $Options
@onready var button_sound: AudioStreamPlayer = $Buttonsound

@onready var master_volume: HSlider = $Options/MasterVolume
@onready var music_volume: HSlider = $Options/MusicVolume
@onready var sfx_volume: HSlider = $Options/SFXVolume
@onready var fullscreen_control: CheckButton = $Options/FullscreenControl


func _ready() -> void:
	main_buttons.visible = true
	options.visible = false

	# Ambil volume yang sedang digunakan
	master_volume.value = db_to_linear(
		AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index("Master")
		)
	) * 100

	music_volume.value = db_to_linear(
		AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index("Music")
		)
	) * 80

	sfx_volume.value = db_to_linear(
		AudioServer.get_bus_volume_db(
			AudioServer.get_bus_index("SFX")
		)
	) * 80

	# Cek kondisi fullscreen
	fullscreen_control.button_pressed = (
		DisplayServer.window_get_mode()
		== DisplayServer.WINDOW_MODE_FULLSCREEN
	)

func play_button_sound() -> void:
	button_sound.play()


# =========================
# MAIN MENU
# =========================

func _on_start_pressed() -> void:
	play_button_sound()
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_file("res://scene/world/farm/farm.tscn")


func _on_options_pressed() -> void:
	play_button_sound()
	main_buttons.visible = false
	options.visible = true


func _on_credit_pressed() -> void:
	play_button_sound()
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_file("res://scene/main/Credits/credits.tscn")


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
	var bus = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(value / 100.0))


func _on_music_volume_value_changed(value: float) -> void:
	var bus = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(bus, linear_to_db(value / 100.0))


func _on_sfx_volume_value_changed(value: float) -> void:
	var bus = AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_volume_db(bus, linear_to_db(value / 100.0))


func _on_fullscreen_control_toggled(button_pressed: bool) -> void:
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
