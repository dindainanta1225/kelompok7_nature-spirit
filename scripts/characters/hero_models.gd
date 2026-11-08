extends RefCounted
## HeroModels - pemain (Judy) & Centorea dari GLB buatan sendiri, memakai skeleton bawaan file (NativeRig) + RigAnim.
## Dicari lewat nama file di folder assets/ (AssetFinder). Hasil: {"node","anim","height","rig"} atau {} kalau file tidak ada.

const AssetFinder := preload("res://scripts/world/asset_finder.gd")
const NativeRig := preload("res://scripts/combat/native_rig.gd")
const RigAnim := preload("res://scripts/combat/rig_anim.gd")

const PLAYER_WORDS := ["judy"]
const PLAYER_HEIGHT := 1.45
const CENTOREA_WORDS := ["centorea"]
const CENTOREA_HEIGHT := 2.25

const JUDY_MAP := [
	["hips", "bip_pelvis", "bip_spine_0"],
	["spine", "bip_spine_1", "bip_neck"],
	["head", "bip_head", "H2_"],
	["up_R", "bip_upperArm_{S}", "bip_lowerArm_{S}"],
	["low_R", "bip_lowerArm_{S}", "bip_hand_{S}"],
	["up_L", "bip_upperArm_{S}", "bip_lowerArm_{S}"],
	["low_L", "bip_lowerArm_{S}", "bip_hand_{S}"],
	["th_R", "bip_hip_{S}", "bip_knee_{S}"],
	["sh_R", "bip_knee_{S}", "bip_foot_{S}"],
	["th_L", "bip_hip_{S}", "bip_knee_{S}"],
	["sh_L", "bip_knee_{S}", "bip_foot_{S}"],
	["hand_R", "bip_hand_{S}", "bip_index_0_{S}"],
	["tail", "TailRoot", "Tail.001"],
]

const CENTOREA_MAP := [
	["hips", "Pelvis_", "Tail1_"],
	["spine", "Spine3_", "Spine4_"],
	["torso", "Torso1_", "Torso2_"],
	["head", "Head_", "Head_END"],
	["up_R", "Shoulder_{S}", "Clavicle_{S}_END"],
	["up_L", "Shoulder_{S}", "Clavicle_{S}_END"],
	["fup_R", "LegFront_{S}", "KneeFront_{S}"],
	["flo_R", "KneeFront_{S}", "FetlockFront_{S}"],
	["fup_L", "LegFront_{S}", "KneeFront_{S}"],
	["flo_L", "KneeFront_{S}", "FetlockFront_{S}"],
	["rup_R", "LegRear_{S}", "KneeRear_{S}"],
	["rlo_R", "KneeRear_{S}", "AnkleRear_{S}"],
	["rup_L", "LegRear_{S}", "KneeRear_{S}"],
	["rlo_L", "KneeRear_{S}", "AnkleRear_{S}"],
	["tail", "Tail1_", "Tail2_"],
]


static func _load(words: Array) -> Node3D:
	var path := AssetFinder.find_glb(words)
	if path == "" or not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	return ps.instantiate() as Node3D


static func _finish(inst: Node3D, map: Array, opts: Dictionary, height: float, kind: String, profile := {}) -> Dictionary:
	var rig := NativeRig.build(inst, map, opts)
	if rig.is_empty():
		inst.free()
		return {}
	var root: Node3D = rig["root"]
	root.scale = Vector3.ONE * (height / maxf(float(rig["height"]), 0.001))
	var pf := profile.duplicate()
	if float(rig["arm_bias"]) > 0.0 and kind == "npc":
		pf["arms_down"] = rig["arm_bias"]
	var anim := RigAnim.new(rig["skeleton"], rig["bones"], rig["specs"], kind, pf)
	anim.use_native(rig["native"])
	return {"node": root, "anim": anim, "height": height, "rig": rig}


static func build_player() -> Dictionary:
	var inst := _load(PLAYER_WORDS)
	if inst == null:
		return {}
	return _finish(inst, JUDY_MAP, {"front": ["bip_head", "nose1"]}, PLAYER_HEIGHT, "npc")


static func build_centorea() -> Dictionary:
	var inst := _load(CENTOREA_WORDS)
	if inst == null:
		return {}
	return _finish(inst, CENTOREA_MAP, {"front": ["Pelvis_", "Head_"]}, CENTOREA_HEIGHT, "centaur")
