extends RefCounted
## NpcModels - model 3D (GLB) buatan sendiri untuk NPC desa + ayam, lengkap dengan skeleton otomatis (AutoRig) dan animasi
## (napas, goyang kepala, isyarat tangan saat bicara, kaki melangkah). Dicari lewat NAMA FILE di folder assets/ (AssetFinder),
## jadi folder boleh diberi nama apa saja. Kalau file tidak ada -> pemanggil memakai karakter chibi bawaan.
##
## Tiap entri:  words = kata kunci nama file | height = tinggi di dunia (m) | arm = pose tangan model asli ("down", "apose", "tpose")
##              arms_down = derajat tangan diturunkan (untuk model T-pose) | dress = baju panjang (ayunan kaki dikurangi) | yaw = putaran

const AssetFinder := preload("res://scripts/world/asset_finder.gd")
const AutoRig := preload("res://scripts/combat/auto_rig.gd")
const RigSpecs := preload("res://scripts/combat/rig_specs.gd")
const RigAnim := preload("res://scripts/combat/rig_anim.gd")
const HeroModels := preload("res://scripts/characters/hero_models.gd")

const MODELS := {
	# --- perempuan
	"martha": {"words": ["damsel"], "height": 1.62, "arm": "apose", "arms_down": 38.0, "dress": false},
	"lily": {"words": ["fem_1", "challenge_1"], "height": 1.58, "arm": "down", "dress": true},
	"anna": {"words": ["guest_fem_4"], "height": 1.6, "arm": "down", "dress": true},
	"mia": {"words": ["guest_fem_3"], "height": 1.42, "arm": "down", "dress": true},
	"rose": {"words": ["guest_fem_1"], "height": 1.45, "arm": "down", "dress": true, "exclude": ["_1.glb"]},
	# --- laki-laki
	"gordon": {"words": ["blacksmith"], "height": 1.78, "arm": "down", "dress": false},
	"harold": {"words": ["king"], "height": 1.9, "arm": "tpose", "arms_down": 68.0, "dress": true},
	"tom": {"words": ["guest_male_1"], "height": 1.55, "arm": "down", "dress": false},
	"joe": {"words": ["guest_male_4"], "height": 1.8, "arm": "down", "dress": false},
	"finn": {"words": ["archer"], "height": 1.72, "arm": "down", "dress": false},
}


static func has(key: String) -> bool:
	return MODELS.has(key) and _path(MODELS[key]) != ""


static func _path(def: Dictionary) -> String:
	var p := AssetFinder.find_glb(def["words"])
	if p != "" and def.has("exclude"):
		for ex in def["exclude"]:
			if p.ends_with(ex):
				return AssetFinder.find_glb(def["words"], "res://assets", def["exclude"])
	return p


## Hasil: {"node": Node3D (sudah diskala ke tinggi dunia), "anim": RigAnim, "height": m} atau {} kalau gagal.
static func build(key: String) -> Dictionary:
	if key == "centorea":                                # centaur: skeleton bawaan file (HeroModels)
		return HeroModels.build_centorea()
	if not MODELS.has(key):
		return {}
	var def: Dictionary = MODELS[key]
	var path := _path(def)
	if path == "" or not ResourceLoader.exists(path):
		return {}
	var ps := load(path) as PackedScene
	if ps == null:
		return {}
	var inst := ps.instantiate() as Node3D
	var arm: String = def.get("arm", "down")
	var rig := AutoRig.build(inst, func(h: float, _sz: Vector3) -> Dictionary: return RigSpecs.humanoid(h, arm), float(def.get("yaw", 0.0)), true)
	inst.free()
	if rig.is_empty():
		return {}
	var root: Node3D = rig["root"]
	root.scale = Vector3.ONE * (float(def["height"]) / maxf(float(rig["height"]), 0.01))
	var anim := RigAnim.new(rig["skeleton"], rig["bones"], rig["spec"]["bones"], "npc",
		{"dress": def.get("dress", false), "arms_down": def.get("arms_down", 0.0)})
	return {"node": root, "anim": anim, "height": float(def["height"])}


## Ayam (chicken.glb) dengan skeleton: kaki, kepala mematuk, sayap, ekor.
static func build_chicken(height := 0.42) -> Dictionary:
	var path := AssetFinder.find_glb(["chicken"])
	if path == "" or not ResourceLoader.exists(path):
		return {}
	var ps := load(path) as PackedScene
	if ps == null:
		return {}
	var inst := ps.instantiate() as Node3D
	var rig := AutoRig.build(inst, func(h: float, _sz: Vector3) -> Dictionary: return RigSpecs.chicken(h), -90.0, true)
	inst.free()
	if rig.is_empty():
		return {}
	var root: Node3D = rig["root"]
	root.scale = Vector3.ONE * (height / maxf(float(rig["height"]), 0.01))
	var anim := RigAnim.new(rig["skeleton"], rig["bones"], rig["spec"]["bones"], "chicken")
	return {"node": root, "anim": anim, "height": height}


## Hewan (kuda / domba) dan Centorea (centaur) -> {"node", "anim", "height"}; {} kalau file tidak ada.
const ANIMALS := {
	"horse": {"words": ["horse"], "height": 1.7, "yaw": 0.0, "leg": 0.5, "neck": 0.72, "head": 0.22},
	"sheep": {"words": ["sheep"], "height": 0.95, "yaw": 0.0, "leg": 0.34, "neck": 0.62, "head": 0.16},
	"centorea": {"words": ["centorea"], "height": 2.2, "yaw": 0.0, "centaur": true},
}


static func build_animal(kind: String) -> Dictionary:
	if not ANIMALS.has(kind):
		return {}
	var def: Dictionary = ANIMALS[kind]
	var path := AssetFinder.find_glb(def["words"])
	if path == "" or not ResourceLoader.exists(path):
		return {}
	var ps := load(path) as PackedScene
	if ps == null:
		return {}
	var inst := ps.instantiate() as Node3D
	var spec_fn: Callable
	if def.get("centaur", false):
		spec_fn = func(h: float, sz: Vector3) -> Dictionary: return RigSpecs.centaur(h, sz)
	else:
		var leg: float = def["leg"]
		var neck: float = def["neck"]
		var hl: float = def["head"]
		spec_fn = func(h: float, sz: Vector3) -> Dictionary: return RigSpecs.quadruped(h, sz, leg, neck, hl)
	var rig := AutoRig.build(inst, spec_fn, float(def["yaw"]), true)
	inst.free()
	if rig.is_empty():
		return {}
	var root: Node3D = rig["root"]
	root.scale = Vector3.ONE * (float(def["height"]) / maxf(float(rig["height"]), 0.01))
	var kind_anim := "centaur" if def.get("centaur", false) else "quad"
	var anim := RigAnim.new(rig["skeleton"], rig["bones"], rig["spec"]["bones"], kind_anim)
	return {"node": root, "anim": anim, "height": float(def["height"])}
