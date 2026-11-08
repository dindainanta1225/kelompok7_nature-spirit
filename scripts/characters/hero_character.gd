extends Node3D
## HeroCharacter - pemain dengan model 3D buatan sendiri (Judy) + skeleton + animasi prosedural.
## API sama dengan character_female.gd: play_anim("idle"/"walk"), play_tool(kind), play_faint() (await), stand_up().
## Alat di tangan (cangkul, penyiram, sabit, pedang, benih, hasil panen) diambil dari chibi lama lalu dipasang ke tulang tangan.

const HeroModels := preload("res://scripts/characters/hero_models.gd")
const CharacterScript := preload("res://scripts/characters/character_female.gd")

const TOOL_TIME := {"hoe": 0.85, "tool": 0.85, "scythe": 0.8, "sword": 0.5, "water": 1.1, "plant": 0.6, "harvest": 0.6, "eat": 1.0, "celebrate": 1.6}
const PROP_OF := {"hoe": "PropHoe", "tool": "PropHoe", "water": "PropCan", "plant": "PropSeed", "scythe": "PropScythe", "sword": "PropSword", "harvest": "PropProduce", "eat": "PropProduce"}

var ok := false
var height := 1.45
var _anim: RefCounted
var _model: Node3D
var _skel: Skeleton3D
var _props := {}
var _water: CPUParticles3D
var _walking := false
var _tool := ""
var _tool_t := 0.0
var _fainted := false
var _faint_t := 0.0
var _t := 0.0


func _ready() -> void:
	var m := HeroModels.build_player()
	if m.is_empty():
		return
	ok = true
	_model = m["node"]
	_anim = m["anim"]
	height = m["height"]
	add_child(_model)
	_skel = m["rig"]["skeleton"]
	_attach_props(m["rig"])


func _attach_props(rig: Dictionary) -> void:
	var hand: int = rig["bones"].get("hand_R", -1)
	if hand < 0:
		return
	var att := BoneAttachment3D.new()
	att.bone_idx = hand
	_skel.add_child(att)
	var chibi := CharacterScript.new()                    # sumber model alat (dibuat sekali lalu dibuang)
	add_child(chibi)
	chibi.visible = false
	var sc: float = _model.scale.x
	# putaran tulang tangan (ruang root) -> alat dipasang supaya sejajar sumbu model saat tangan lurus ke bawah
	var rest := Basis(((rig["s_q"] as Quaternion) * (rig["native"]["hand_R"]["r"] as Quaternion)).normalized())
	for n in chibi._props:
		var p: Node3D = chibi._props[n]
		p.get_parent().remove_child(p)
		att.add_child(p)
		p.basis = rest.inverse().scaled(Vector3.ONE * 0.7 / sc)
		p.position = Vector3.ZERO
		p.visible = false
		_props[n] = p
		if n == "PropCan":
			_water = p.get_node_or_null("Water")
	chibi.queue_free()


func play_anim(n: String, _speed := 1.0) -> void:
	if _fainted:
		return
	_walking = n == "walk"
	if n == "celebrate":
		play_tool("celebrate")


func play_tool(kind := "tool") -> void:
	if _fainted:
		return
	_tool = kind
	_tool_t = 0.0
	for k in _props:
		(_props[k] as Node3D).visible = (k == PROP_OF.get(kind, ""))
	if kind == "water" and _water != null:
		get_tree().create_timer(0.35).timeout.connect(func() -> void:
			if _water: _water.emitting = true)
		get_tree().create_timer(0.95).timeout.connect(func() -> void:
			if _water: _water.emitting = false)


## Roboh ke belakang. Selesai setelah ~1.6 detik.
func play_faint() -> void:
	_fainted = true
	_faint_t = 0.0
	_tool = ""
	for k in _props:
		(_props[k] as Node3D).visible = false
	await get_tree().create_timer(1.6).timeout


func stand_up() -> void:
	_fainted = false
	_faint_t = 0.0
	if _model:
		_model.rotation = Vector3.ZERO
		_model.position = Vector3.ZERO


func _process(delta: float) -> void:
	if not ok:
		return
	_t += delta
	var ctx := {"speed": 1.0 if _walking and _tool == "" else 0.0, "windup": -1.0, "lunge": 0.0, "hit": 0.0, "t": _t, "delta": delta}
	if _tool != "":
		_tool_t += delta
		var dur: float = TOOL_TIME.get(_tool, 0.8)
		ctx["tool"] = clampf(_tool_t / dur, 0.0, 1.0)
		ctx["tool_kind"] = _tool
		ctx["speed"] = 0.0
		if _tool_t >= dur:
			_tool = ""
			for k in _props:
				(_props[k] as Node3D).visible = false
	if _fainted:
		_faint_t += delta
		var f := clampf(_faint_t / 0.8, 0.0, 1.0)
		f = f * f * (3.0 - 2.0 * f)
		_model.rotation.x = -f * PI * 0.5                    # roboh telentang
		_model.position.y = 0.1 * f
		ctx["speed"] = 0.0
		ctx["hit"] = 0.0
	_anim.update(ctx)
