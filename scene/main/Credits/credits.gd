extends Control

@onready var animation_player = $AnimationPlayer
@onready var button_sound: AudioStreamPlayer = $ButtonSound


func _ready():
	animation_player.play("credit_scroll")


func play_button_sound() -> void:
	button_sound.play()


func _on_button_pressed() -> void:
	play_button_sound()
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_file("res://scene/main/mainmenu/main_menu.tscn")
