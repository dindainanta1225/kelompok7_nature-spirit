class_name Bed
extends Interactable
## Bed - kasur di rumah player. Interaksi E memanggil GameState.try_sleep()
## (terkunci sebelum 21:00, bangun 06:00 / 10:00 sesuai aturan tidur).
## Taruh Marker3D bernama "bed" (grup "spawn") di dekat kasur sebagai titik bangun.


func _init() -> void:
	prompt = "Sleep"


func _on_interact(_player: Node3D) -> void:
	GameState.try_sleep()
