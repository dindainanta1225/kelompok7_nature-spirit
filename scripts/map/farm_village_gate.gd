extends Node
## FarmVillageGate - membuka celah di pagar selatan Farm dan memasang pintu keluar ke Village.
## Dipasang sebagai child scene Farm (node "VillageGate"). Pasangan spawn: "from_village" di node Area.

const ExitScript := preload("res://scripts/map/scene_exit.gd")
const InteractScript := preload("res://scripts/map/interactable.gd")
const VILLAGE_SCENE := "res://scene/world/village/village.tscn"
const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"
const GATE_Z := 18.4


func _ready() -> void:
	var decor := get_parent().get_node_or_null("Decor") as GridMap
	if decor:
		for x in range(-3, 3):
			for z in range(15, 21):
				for y in range(0, 4):
					decor.set_cell_item(Vector3i(x, y, z), GridMap.INVALID_CELL_ITEM)
	var ex := ExitScript.new()
	ex.mode = InteractScript.Mode.AUTO
	ex.target_scene = VILLAGE_SCENE
	ex.target_spawn = "from_farm"
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 4.0, 1.4)
	cs.shape = box
	ex.add_child(cs)
	ex.position = Vector3(-0.5, 3.0, GATE_Z)
	get_parent().add_child.call_deferred(ex)
