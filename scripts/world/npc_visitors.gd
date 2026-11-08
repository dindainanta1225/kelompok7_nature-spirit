extends Node3D
## NpcVisitors - warga desa yang kadang berjalan-jalan di Hutan 1 (sesuai NpcSchedule). Farm player tidak dikunjungi warga
## (hanya Centorea yang tinggal di sana). Pasang di scene Forest 1: set `place` ("forest"), `entrance` (tempat masuk/keluar), `spots` (titik singgah).
## Tiap pergantian jam: yang jadwalnya ke sini berjalan masuk dari pintu; yang sudah pergi berjalan keluar lalu hilang.

const NPCActor := preload("res://scripts/world/npc_actor.gd")
const NpcRoster := preload("res://scripts/world/npc_roster.gd")
const NpcSchedule := preload("res://scripts/world/npc_schedule.gd")

var place := "farm"
var entrance := Vector3.ZERO
var spots: Array = []
var _nodes := {}


func _ready() -> void:
	GameState.hour_changed.connect(func(_h: int) -> void: _refresh(false))
	GameState.day_changed.connect(func(_d: int) -> void: _refresh(false))
	_refresh(true)


func _spot_for(id: String) -> Vector3:
	var i := NpcSchedule._h(id, GameState.day, NpcSchedule.block_of(GameState.hour()) + 77) % maxi(spots.size(), 1)
	return spots[i]


func _refresh(initial: bool) -> void:
	if spots.is_empty():
		return
	for id in NpcRoster.IDS:
		var d: Dictionary = NpcRoster.DATA[id]
		var w := NpcSchedule.where(id, GameState.day, GameState.hour(), (d["spots"] as Array).size())
		var here: bool = w["where"] == place
		if here and not _nodes.has(id):
			var n := NPCActor.new()
			n.npc_id = id
			n.display_name = d["name"]
			n.shop_id = d["shop"]
			n.greetings = d["greet"]
			n.look = d["look"]
			n.spot_name = "Exploring the forest"
			var dest := _spot_for(id)
			add_child(n)
			n.add_to_group("npc_visitor")
			_nodes[id] = n
			n.wander_center = dest
			n.wander_radius = 2.2
			if initial:
				n.position = dest
			else:
				n.position = entrance
				n.walk_along([dest])
		elif not here and _nodes.has(id):
			var n: Node3D = _nodes[id]
			_nodes.erase(id)
			n.wander_radius = 0.0
			n.walk_along([entrance], func() -> void: n.queue_free())
