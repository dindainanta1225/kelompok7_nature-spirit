extends Node
## WorldArea - pasang di NODE ROOT tiap scene area (Farm, Village, Forest1, Forest2, rumah).
##
## Tugasnya: saat scene dimuat, letakkan player di spawn point yang dituju,
## dan tampilkan nama area. Spawn point = node Marker3D yang MASUK GRUP "spawn";
## NAMA node-nya adalah nama spawn (misal "from_village", "bed", "default").
## Player harus masuk grup "player" (tab Node > Groups pada node player).

@export var area_name := ""
@export var default_spawn := "default"      # dipakai kalau scene dibuka langsung (bukan lewat pintu)
@export var announce := true                # tampilkan nama area di layar saat masuk


func _ready() -> void:
	var spawn := GameState.next_spawn if GameState.next_spawn != "" else default_spawn
	GameState.next_spawn = ""
	place_player(spawn)
	if announce and area_name != "" and GameState.playing:
		HUD.show_toast(area_name)


## Dipanggil juga oleh GameState saat bangun tidur. Return true kalau spawn ditemukan.
func place_player(spawn_name: String) -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return false
	for m in get_tree().get_nodes_in_group("spawn"):
		if m.name == spawn_name and m is Node3D and is_ancestor_of(m):
			player.global_position = (m as Node3D).global_position
			if player is CharacterBody3D:
				(player as CharacterBody3D).velocity = Vector3.ZERO
			return true
	return false
