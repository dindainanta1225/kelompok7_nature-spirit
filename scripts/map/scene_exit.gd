class_name SceneExit
extends Interactable
## SceneExit - pintu atau jalan keluar peta yang memindahkan player ke scene lain.
##
## Isi di Inspector:
##   Target Scene : scene tujuan (.tscn)
##   Target Spawn : nama Marker3D di scene tujuan tempat player muncul
##   Mode         : AUTO untuk batas peta (jalan keluar), PRESS untuk pintu rumah
##
## PENTING: letakkan Marker3D tujuan sekitar 2-3 unit DI DALAM area, jangan tepat di dalam
## SceneExit pasangannya, supaya player tidak langsung terpental kembali.

@export_file("*.tscn") var target_scene := ""
@export var target_spawn := "default"


func _init() -> void:
	prompt = "Enter"


func _on_interact(_player: Node3D) -> void:
	GameState.change_area(target_scene, target_spawn)
