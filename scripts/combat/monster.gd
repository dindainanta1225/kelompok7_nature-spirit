extends CharacterBody3D
const Sfx := preload("res://scripts/audio/sfx.gd")
## Monster - Slime, Boar, Wolf, Goblin (model dari bangun dasar, tanpa file gambar).
## Perilaku: berkeliaran -> mengejar kalau pemain dekat -> menyerang (mengurangi ENERGY pemain).
## Mati -> koin + drop ke tas (peluang sesuai GDD) + drop langka (Gold Nugget 3%, Forest Herb 8%).

const ForestState := preload("res://scripts/combat/forest_state.gd")
const MonsterModels := preload("res://scripts/combat/monster_models.gd")
const ModelUtil := preload("res://scripts/world/model_util.gd")
const AutoRig := preload("res://scripts/combat/auto_rig.gd")
const RigSpecs := preload("res://scripts/combat/rig_specs.gd")
const RigAnim := preload("res://scripts/combat/rig_anim.gd")
const FONT_PATH := "res://assets/fonts/Matcha Mint.ttf"

## hp, damage ke energi, koin, id drop, peluang drop, kecepatan, skala, jarak sadar
const TYPES := {
	"slime": {"name": "Imp", "hp": 20, "dmg": 5, "coin": 100, "drop": "imp_horn", "chance": 0.50, "speed": 1.9, "scale": 1.0, "aggro": 6.0},
	"boar": {"name": "Bear", "hp": 45, "dmg": 8, "coin": 250, "drop": "bear_claw", "chance": 0.40, "speed": 3.4, "scale": 1.0, "aggro": 7.0},
	"wolf": {"name": "Werewolf", "hp": 80, "dmg": 12, "coin": 500, "drop": "werewolf_fur", "chance": 0.40, "speed": 4.4, "scale": 1.0, "aggro": 9.0},
	"goblin": {"name": "Goblin", "hp": 35, "dmg": 6, "coin": 150, "drop": "goblin_tooth", "chance": 0.45, "speed": 3.8, "scale": 1.0, "aggro": 7.0},
	"hunter": {"name": "Monster Hunter", "hp": 170, "dmg": 22, "coin": 1500, "drop": "hunter_badge", "chance": 0.35, "speed": 3.6, "scale": 1.0, "aggro": 9.0},
	"skeleton": {"name": "Skeleton", "hp": 130, "dmg": 18, "coin": 1000, "drop": "skeleton_bone", "chance": 0.40, "speed": 3.0, "scale": 1.0, "aggro": 8.0},
}
## Ukuran angka yang muncul di atas monster/pemain (1.0 = normal; ubah supaya lebih besar/kecil).
const NUMBER_SIZE := 1.0
const HIT_COLOR := Color(1.0, 0.9, 0.35)           # angka damage ke monster
const PLAYER_HIT_COLOR := Color(1.0, 0.35, 0.3)    # angka damage ke pemain
const RARE := [["gold_nugget", 0.03], ["forest_herb", 0.08]]

var kind := "slime"
var forest_id := 1
var spawn_index := 0
var home := Vector3.ZERO
var ground_y := 1.5

var hp := 20
var saved_hp := 0                    # sisa HP dari kunjungan sebelumnya (hutan dimasuki lagi hari yang sama)
var _def: Dictionary
var _state := "idle"                 # idle | wander | chase | dead
var _t := 0.0
var _wander_t := 0.0
var _target := Vector3.ZERO
var _attack_cd := 1.0
var _windup := 0.0
var _flash := 0.0
var _knock := Vector3.ZERO
var _visual: Node3D
var _mats: Array = []
var _bar_fill: MeshInstance3D
var _bar_root: Node3D
var _font: Font
var _rng := RandomNumberGenerator.new()
var _anim: AnimationPlayer
var _anim_names := {}
var _anim_cur := ""
var _custom := false
var _bar_y := 1.9
var _pose: Node3D
var _hit_kick := 0.0
var _lunge := 0.0
var _dying := false
var _lie_lift := 0.4
var _rig: RigAnim


func _ready() -> void:
	_def = TYPES[kind]
	hp = int(_def["hp"])
	if saved_hp > 0:
		hp = mini(saved_hp, hp)
	_rng.randomize()
	add_to_group("monster")
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	collision_layer = 1
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	var custom_path := MonsterModels.path_for(kind)
	sh.radius = float(MonsterModels.RADIUS[kind]) if custom_path != "" else 0.45
	sh.height = maxf(float(MonsterModels.HEIGHT[kind]) if custom_path != "" else (1.0 if kind != "skeleton" else 1.5), sh.radius * 2.0 + 0.05)
	cs.shape = sh
	cs.position.y = sh.height * 0.5 + 0.02
	add_child(cs)
	_visual = Node3D.new()
	add_child(_visual)
	if not _build_custom():                                       # model GLB buatan sendiri; kalau tidak ada -> model kode
		match kind:
			"slime": _build_slime()
			"boar": _build_boar()
			"wolf": _build_wolf()
			_: _build_goblin()
	_build_bar()
	position = Vector3(home.x, ground_y + 0.05, home.z)
	_wander_t = _rng.randf_range(0.5, 2.5)
	_t = _rng.randf() * 6.0


# ------------------------------------------------------------------ model GLB buatan sendiri
func _build_custom() -> bool:
	var path := MonsterModels.path_for(kind)
	if path == "" or not ResourceLoader.exists(path):
		return false
	var ps := load(path) as PackedScene
	if ps == null:
		return false
	var inst := ps.instantiate() as Node3D
	if inst == null:
		return false
	_pose = Node3D.new()                                         # sendi animasi (miring/menyusut/jatuh), pivot di kaki
	_visual.add_child(_pose)
	var holder := Node3D.new()                                   # koreksi arah hadap model
	holder.rotation_degrees.y = float(MonsterModels.YAW[kind])
	_pose.add_child(holder)
	var spec = RigSpecs.spec_for(kind)                          # pasang skeleton + skin otomatis (kaki/tangan/kepala bergerak)
	var rig := AutoRig.build(inst, spec, float(MonsterModels.YAW[kind]), RigSpecs.needs_recenter(kind))
	if not rig.is_empty():
		inst.free()
		inst = rig["root"]
		holder.rotation_degrees.y = 0.0                          # yaw sudah ikut "dipanggang" ke dalam rig
		_rig = RigAnim.new(rig["skeleton"], rig["bones"], rig["spec"]["bones"], kind, {"arms_down": 20.0} if kind == "hunter" else {})
	holder.add_child(inst)
	var b := ModelUtil.bounds(inst)
	var h := maxf(b.size.y, 0.01)
	var sc := float(MonsterModels.HEIGHT[kind]) / h
	inst.scale = Vector3.ONE * sc
	inst.position = Vector3(-b.get_center().x * sc, -b.position.y * sc, -b.get_center().z * sc)
	_bar_y = float(MonsterModels.HEIGHT[kind]) + 0.35
	if _bar_root != null:
		_bar_root.position.y = _bar_y                              # bar dibuat sebelum tinggi model diketahui -> geser ke atas kepala
	_lie_lift = minf(b.size.x, b.size.z) * sc * 0.5 + 0.03
	_custom = true
	_collect_materials(inst)
	_anim = _find_anim(inst)
	if _anim != null:
		for n in _anim.get_animation_list():
			var ln := String(n).to_lower()
			for role in ["idle", "walk", "run", "attack", "hit", "die", "death"]:
				if ln.contains(role) and not _anim_names.has(role):
					_anim_names[role] = n
		if _anim_names.is_empty() and _anim.get_animation_list().size() > 0:
			_anim_names["idle"] = _anim.get_animation_list()[0]
		for role in ["idle", "walk", "run"]:                      # gerakan dasar berulang
			if _anim_names.has(role):
				var a := _anim.get_animation(_anim_names[role])
				if a != null:
					a.loop_mode = Animation.LOOP_LINEAR
		_play("idle")
	return true


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r != null:
			return r
	return null


## Material bawaan model diduplikasi per monster supaya efek kena-pukul (merah) tidak menular ke monster lain.
func _collect_materials(n: Node) -> void:
	if n is MeshInstance3D and n.mesh != null:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			if m is BaseMaterial3D:
				var d := (m as BaseMaterial3D).duplicate() as StandardMaterial3D
				mi.set_surface_override_material(i, d)
				_mats.append(d)
	for c in n.get_children():
		_collect_materials(c)


func _play(role: String) -> void:
	if _anim == null or not _anim_names.has(role) or _anim_cur == role:
		return
	_anim_cur = role
	_anim.play(_anim_names[role], 0.15)


# ------------------------------------------------------------------ model
const BioMat := preload("res://scripts/world/bio_mat.gd")


## Material PBR menurut jenis monster & peran warna: gel (slime), bulu (babi hutan/serigala), kulit hijau (goblin),
## mata basah/menyala, taring tulang, kain & kayu. Selalu material baru (emission dipakai efek kena pukul).
func _mat(c: Color, alpha := 1.0) -> StandardMaterial3D:
	var m: StandardMaterial3D
	if alpha < 1.0:
		m = BioMat.gel(c, alpha)
	elif c == Color.WHITE or c.v < 0.16:
		m = BioMat.eye(c)
	elif c.s > 0.7 and c.v > 0.8:                      # mata menyala (kuning serigala, merah goblin)
		m = BioMat.eye(c, 0.9)
	elif c.v > 0.88 and c.s < 0.3:                      # taring / gading
		m = BioMat.bone(c)
	elif kind == "slime":
		m = BioMat.gel(c, 1.0)
	elif kind == "goblin" or kind == "skeleton":
		if c.g > c.r and c.g > c.b:
			m = BioMat.skin(c, 0.7)
		elif c.r > c.g and c.v < 0.5:
			m = BioMat.wood(c) if c.v < 0.45 and c.r - c.b > 0.25 and c.s > 0.5 else BioMat.leather(c)
		else:
			m = BioMat.cloth(c)
	elif c.r > 0.8 and c.g < 0.7:                       # moncong merah muda
		m = BioMat.skin(c, 0.65)
	else:
		m = BioMat.fur(c)
	_mats.append(m)
	return m


func _part(mesh: Mesh, c: Color, pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO, alpha := 1.0, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c, alpha)
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot
	(parent if parent else _visual).add_child(mi)
	return mi


func _ball(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 36
	s.rings = 18
	return s


func _cone(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 20
	return c


func _cylm(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 20
	return c


func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func _eyes(y: float, z: float, spread: float, r: float, iris := Color(0.08, 0.06, 0.06)) -> void:
	for sx in [-1.0, 1.0]:
		_part(_ball(r), Color.WHITE, Vector3(sx * spread, y, z))
		_part(_ball(r * 0.55), iris, Vector3(sx * spread, y, z + r * 0.55))


func _build_slime() -> void:
	var g := Color(0.36, 0.80, 0.42)
	_part(_ball(0.55), g, Vector3(0, 0.40, 0), Vector3(1.15, 0.85, 1.15), Vector3.ZERO, 0.88)
	_part(_ball(0.30), g.lightened(0.25), Vector3(-0.15, 0.62, 0.1), Vector3(1, 0.6, 1), Vector3.ZERO, 0.7)
	_eyes(0.46, 0.46, 0.2, 0.10)
	_part(_box(0.14, 0.03, 0.02), Color(0.12, 0.3, 0.14), Vector3(0, 0.30, 0.56))


func _build_boar() -> void:
	var br := Color(0.46, 0.30, 0.20)
	_part(_ball(0.5), br, Vector3(0, 0.62, 0), Vector3(0.95, 0.85, 1.35))
	_part(_ball(0.30), br.darkened(0.1), Vector3(0, 0.62, 0.62), Vector3(1, 0.95, 1))
	_part(_cylm(0.13, 0.18), Color(0.85, 0.62, 0.58), Vector3(0, 0.56, 0.9), Vector3.ONE, Vector3(90, 0, 0))
	for sx in [-1.0, 1.0]:
		_part(_cone(0.05, 0.22), Color(0.96, 0.92, 0.80), Vector3(sx * 0.16, 0.48, 0.86), Vector3.ONE, Vector3(-40, 0, sx * 20))
		_part(_cone(0.09, 0.2), br.darkened(0.2), Vector3(sx * 0.2, 0.9, 0.52), Vector3.ONE, Vector3(0, 0, sx * -25))
		for sz in [-0.4, 0.4]:
			_part(_cylm(0.07, 0.34), br.darkened(0.25), Vector3(sx * 0.25, 0.17, sz))
	_part(_box(0.05, 0.1, 0.5), br.darkened(0.3), Vector3(0, 0.95, -0.05))
	_eyes(0.72, 0.8, 0.14, 0.05)


func _build_wolf() -> void:
	var gr := Color(0.50, 0.52, 0.58)
	_part(_ball(0.45), gr, Vector3(0, 0.72, 0), Vector3(0.8, 0.8, 1.6))
	_part(_ball(0.28), gr.lightened(0.05), Vector3(0, 0.95, 0.62))
	_part(_cone(0.12, 0.34), gr.darkened(0.1), Vector3(0, 0.88, 0.98), Vector3.ONE, Vector3(90, 0, 0))
	_part(_ball(0.05), Color(0.1, 0.08, 0.08), Vector3(0, 0.92, 1.16))
	for sx in [-1.0, 1.0]:
		_part(_cone(0.09, 0.24), gr.darkened(0.2), Vector3(sx * 0.14, 1.22, 0.58))
		for sz in [-0.5, 0.45]:
			_part(_cylm(0.065, 0.55), gr.darkened(0.2), Vector3(sx * 0.2, 0.27, sz))
	_part(_cone(0.12, 0.6), gr.darkened(0.05), Vector3(0, 0.82, -0.82), Vector3.ONE, Vector3(-120, 0, 0))
	for sx in [-1.0, 1.0]:
		_part(_ball(0.045), Color(1.0, 0.85, 0.25), Vector3(sx * 0.12, 1.02, 0.84))


func _build_goblin() -> void:
	var gn := Color(0.50, 0.70, 0.30)
	var cloth := Color(0.45, 0.30, 0.18)
	_part(_cylm(0.26, 0.7), cloth, Vector3(0, 0.70, 0), Vector3(1, 1, 0.8))
	_part(_ball(0.34), gn, Vector3(0, 1.30, 0), Vector3(1.1, 0.95, 1))
	for sx in [-1.0, 1.0]:
		_part(_cone(0.09, 0.42), gn, Vector3(sx * 0.46, 1.36, 0), Vector3.ONE, Vector3(0, 0, sx * -88))
		_part(_cylm(0.07, 0.5), gn, Vector3(sx * 0.32, 0.72, 0.03))
		_part(_cylm(0.08, 0.4), gn.darkened(0.2), Vector3(sx * 0.13, 0.2, 0))
		_part(_ball(0.06), Color(1.0, 0.25, 0.2), Vector3(sx * 0.13, 1.34, 0.31))
	_part(_cone(0.04, 0.12), Color.WHITE, Vector3(0, 1.17, 0.33), Vector3.ONE, Vector3(180, 0, 0))
	var club := Node3D.new()
	club.position = Vector3(0.42, 0.55, 0.28)
	club.rotation_degrees = Vector3(-60, 0, 0)
	_visual.add_child(club)
	_part(_cylm(0.04, 0.7), Color(0.42, 0.28, 0.14), Vector3(0, 0.2, 0), Vector3.ONE, Vector3.ZERO, 1.0, club)
	_part(_ball(0.13), Color(0.36, 0.24, 0.12), Vector3(0, 0.62, 0), Vector3.ONE, Vector3.ZERO, 1.0, club)


func _build_bar() -> void:
	_bar_root = Node3D.new()
	_bar_root.position = Vector3(0, _bar_y, 0)
	add_child(_bar_root)
	var bg := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.12)
	bg.mesh = q
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.08, 0.04, 0.02, 0.9)
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.no_depth_test = true
	bm.render_priority = 0
	bg.material_override = bm
	_bar_root.add_child(bg)
	_bar_fill = MeshInstance3D.new()
	var q2 := QuadMesh.new()
	q2.size = Vector2(0.84, 0.07)
	_bar_fill.mesh = q2
	_bar_fill.position.z = 0.002
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.9, 0.2, 0.2)
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA          # sama-sama transparan supaya urutan gambar mengikuti render_priority
	fm.no_depth_test = true
	fm.render_priority = 2
	_bar_fill.material_override = fm
	_bar_root.add_child(_bar_fill)
	_bar_root.visible = false
	_update_bar()


## Bar HP selalu sesuai HP asli (termasuk HP sisa dari kunjungan sebelumnya); menghadap kamera supaya sisi kiri-kanan benar.
func _update_bar() -> void:
	var frac := clampf(float(hp) / float(_def["hp"]), 0.0, 1.0)
	_bar_fill.scale.x = maxf(frac, 0.001)
	_bar_fill.position.x = -0.42 * (1.0 - frac)
	var fm := _bar_fill.material_override as StandardMaterial3D
	if fm != null:
		fm.albedo_color = Color(0.9, 0.2, 0.2) if frac < 0.35 else (Color(0.95, 0.75, 0.2) if frac < 0.65 else Color(0.35, 0.8, 0.3))


func _face_bar() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null and _bar_root != null:
		_bar_root.global_transform.basis = cam.global_transform.basis


# ------------------------------------------------------------------ perilaku
func _physics_process(delta: float) -> void:
	if _state == "dead":
		return
	_t += delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not is_on_floor():
		velocity.y -= 18.0 * delta
	else:
		velocity.y = 0.0
	_flash = maxf(_flash - delta, 0.0)
	_hit_kick = maxf(_hit_kick - delta * 3.5, 0.0)
	_lunge = maxf(_lunge - delta * 5.0, 0.0)
	_set_flash(_flash > 0.0)
	var move := Vector3.ZERO
	var active: bool = GameState.playing and not GameState.input_locked and not get_tree().paused
	var dist := 99.0
	if player != null:
		dist = player.global_position.distance_to(global_position)
	_attack_cd -= delta
	if active and player != null and dist < float(_def["aggro"]):
		if _state != "chase" and _state != "dead" and kind != "slime":
			Sfx.play_at("monster_growl", global_position, 14.0, -6.0, randf_range(0.8, 1.3))
		_state = "chase"
	elif _state == "chase" and (dist > float(_def["aggro"]) * 1.6 or not active):
		_state = "idle"
		home = Vector3(global_position.x, home.y, global_position.z)       # berhenti di tempatnya, tidak kembali ke titik awal
	match _state:
		"chase":
			var to := player.global_position - global_position
			to.y = 0.0
			if to.length() > 1.25:
				move = to.normalized() * float(_def["speed"])
			if to.length() <= 1.5 and _windup <= 0.0 and _attack_cd <= 0.0:
				_windup = 0.35                                   # aba-aba sebelum menyerang
			if _windup > 0.0:
				_windup -= delta
				move = Vector3.ZERO
				if not _custom:
					_visual.scale = Vector3.ONE * (1.0 + 0.18 * sin((0.35 - _windup) / 0.35 * PI))
				if _windup <= 0.0:
					_visual.scale = Vector3.ONE
					_strike(player)
			if to.length() > 0.01:
				_face(to)
		"wander":
			_wander_t -= delta
			var to2 := _target - global_position
			to2.y = 0.0
			if to2.length() < 0.4 or _wander_t <= 0.0:
				_state = "idle"
				_wander_t = _rng.randf_range(1.0, 3.0)
			else:
				move = to2.normalized() * float(_def["speed"]) * 0.35
				_face(to2)
		_:
			_wander_t -= delta
			if _wander_t <= 0.0:
				var a := _rng.randf() * TAU
				_target = home + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(1.0, 3.5)
				_state = "wander"
				_wander_t = _rng.randf_range(1.5, 3.5)
	_knock = _knock.move_toward(Vector3.ZERO, 14.0 * delta)
	velocity.x = move.x + _knock.x
	velocity.z = move.z + _knock.z
	move_and_slide()
	_animate(move.length() > 0.1 or _knock.length() > 0.5)
	if player != null and _state != "dead":
		_bar_root.visible = dist < 11.0 or hp < int(_def["hp"])        # bar tampil begitu pemain dekat, bukan menunggu pukulan pertama
		_face_bar()


func _exit_tree() -> void:                                  # simpan posisi & HP supaya tidak "reset" saat pemain keluar-masuk hutan
	if _state != "dead" and is_inside_tree():
		ForestState.save_monster(forest_id, GameState.day, spawn_index, global_position, hp)


func _face(dir: Vector3) -> void:
	var yaw := atan2(dir.x, dir.z)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, yaw, 0.2)


func _animate(moving: bool) -> void:
	if _custom:
		_animate_custom(moving)
		return
	if _windup > 0.0:
		return
	match kind:
		"slime":
			var s := 1.0 + 0.10 * sin(_t * (9.0 if moving else 3.0))
			_visual.scale = Vector3(1.0 / sqrt(s), s, 1.0 / sqrt(s))
		_:
			var b := absf(sin(_t * (11.0 if moving else 2.0))) * (0.07 if moving else 0.015)
			_visual.position.y = b


## Animasi prosedural (model GLB tanpa animasi bawaan): napas, langkah berayun, ancang-ancang + terkam, tersentak saat kena pukul.
func _animate_custom(moving: bool) -> void:
	if _dying or _pose == null:
		return
	var pitch := 0.0
	var roll := 0.0
	var lift := 0.0
	var sq := Vector3.ONE
	if _windup > 0.0:
		var p := 1.0 - _windup / 0.35
		pitch = -0.3 * sin(p * PI * 0.5)                          # condong ke belakang (ancang-ancang)
		sq = Vector3(1.0 + 0.07 * p, 1.0 - 0.1 * p, 1.0 + 0.07 * p)
	elif moving:
		var f := _t * (10.0 if _state == "chase" else 6.0)
		var rk := 0.3 if _rig != null else 1.0                    # kalau sudah ada tulang, goyang badan dikurangi
		lift = absf(sin(f)) * (0.1 if _state == "chase" else 0.05) * rk
		roll = sin(f) * (0.09 if _state == "chase" else 0.05) * rk
		pitch = (0.1 if _state == "chase" else 0.03) * rk
	else:
		sq.y = 1.0 + sin(_t * 2.2) * 0.02                         # bernapas
		sq.x = 1.0 - sin(_t * 2.2) * 0.008
		roll = sin(_t * 1.1) * 0.02
	if _rig != null:
		var hv := Vector2(velocity.x, velocity.z).length()
		_rig.update({
			"speed": clampf(hv / maxf(float(_def["speed"]), 0.1), 0.0, 1.0) if moving else 0.0,
			"windup": (1.0 - _windup / 0.35) if _windup > 0.0 else -1.0,
			"lunge": _lunge, "hit": _hit_kick, "t": _t, "delta": get_physics_process_delta_time(),
		})
	var k := _hit_kick * _hit_kick
	pitch -= 0.5 * k                                              # tersentak ke belakang
	roll += sin(_t * 55.0) * 0.1 * k                              # bergetar sesaat
	sq *= Vector3(1.0 + 0.16 * k, 1.0 - 0.2 * k, 1.0 + 0.16 * k)
	pitch += 0.35 * _lunge                                        # terkam ke depan
	_pose.rotation.x = lerpf(_pose.rotation.x, pitch, 0.3)
	_pose.rotation.z = lerpf(_pose.rotation.z, roll, 0.3)
	_pose.scale = _pose.scale.lerp(sq, 0.35)
	_pose.position.y = lerpf(_pose.position.y, lift, 0.35)
	_pose.position.z = 0.6 * _lunge * _lunge


func _strike(player: Node3D) -> void:
	_attack_cd = 1.3
	if player.global_position.distance_to(global_position) > 1.9:
		return                                                    # pemain sempat menjauh
	_lunge = 1.0
	Sfx.play("monster_attack", -4.0)
	GameState.damage_energy(float(_def["dmg"]))
	_float_number(str(int(_def["dmg"])), PLAYER_HIT_COLOR, player.global_position + Vector3(0, 1.9, 0), 0.0, 1.15)
	var away := player.global_position - global_position
	away.y = 0.0
	if away.length() > 0.01:
		var tw := create_tween()
		tw.tween_property(player, "global_position", player.global_position + away.normalized() * 0.9, 0.12)


func _set_flash(on: bool) -> void:
	for m in _mats:
		var sm := m as StandardMaterial3D
		sm.emission_enabled = on
		if on:
			sm.emission = Color(1.0, 1.0, 1.0)
			sm.emission_energy_multiplier = 2.2


# ------------------------------------------------------------------ kena pukul & mati
func take_hit(dmg: int, dir: Vector3) -> void:
	if _state == "dead":
		return
	hp -= dmg
	Sfx.play("hit", -2.0)
	Sfx.play("slime" if kind == "slime" else "monster_hurt", -6.0, randf_range(0.9, 1.15))
	_flash = 0.18
	_knock = dir * 5.5
	_windup = 0.0
	_state = "chase"
	_bar_root.visible = true
	_update_bar()
	_hit_kick = 1.0
	_float_number(str(dmg), HIT_COLOR, global_position + Vector3(randf_range(-0.25, 0.25), _bar_y + 0.1, 0), 0.0, 1.0)
	if hp <= 0:
		_die()


func _die() -> void:
	Sfx.play("monster_die", -3.0, 1.2 if kind == "slime" else 1.0)
	_state = "dead"
	remove_from_group("monster")
	ForestState.mark_killed(forest_id, GameState.day, spawn_index)
	var coin := int(_def["coin"])
	GameState.add_coins(coin)
	var lines: Array = ["+%d coins" % coin]
	var inv = GameState.inventory
	if _rng.randf() < float(_def["chance"]):
		lines.append(_give(String(_def["drop"])))
	for r in RARE:
		if _rng.randf() < float(r[1]):
			lines.append(_give(String(r[0])))
	GameState.toast.emit("%s defeated!  %s" % [_def["name"], "  ".join(lines)])
	_bar_root.visible = false
	collision_layer = 0
	collision_mask = 0
	_set_flash(false)
	if _custom and _pose != null:
		_faint()
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_visual, "scale", Vector3(1.4, 0.05, 1.4), 0.35).set_ease(Tween.EASE_IN)
	tw.tween_property(_visual, "position:y", -0.1, 0.35)
	tw.chain().tween_callback(queue_free)


## Pingsan: tersentak, terhuyung, roboh ke samping (memantul sekali), terkapar sebentar, lalu perlahan memudar. Tanpa partikel.
func _faint() -> void:
	_dying = true
	var side := 1.0 if _rng.randf() < 0.5 else -1.0
	var tw := create_tween()
	tw.set_parallel(false)
	# 1) tersentak ke belakang & terhuyung
	tw.tween_property(_pose, "rotation:x", -0.35, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_pose, "scale", Vector3(1.12, 0.9, 1.12), 0.12)
	tw.tween_property(_pose, "rotation:z", side * 0.28, 0.16).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_pose, "rotation:x", 0.1, 0.16)
	tw.parallel().tween_property(_pose, "scale", Vector3.ONE, 0.16)
	# 2) roboh ke samping
	tw.tween_property(_pose, "rotation:z", side * PI * 0.5, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_pose, "rotation:x", 0.0, 0.38)
	tw.parallel().tween_property(_pose, "position:y", _lie_lift, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 3) membentur tanah, memantul kecil
	tw.tween_property(_pose, "position:y", _lie_lift + 0.12, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_pose, "rotation:z", side * (PI * 0.5 - 0.12), 0.09)
	tw.tween_property(_pose, "position:y", _lie_lift, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_pose, "rotation:z", side * PI * 0.5, 0.1)
	tw.tween_interval(0.7)                                                 # terkapar
	tw.tween_callback(_start_fade)
	tw.tween_interval(0.75)
	tw.tween_callback(queue_free)


func _start_fade() -> void:
	for m in _mats:
		var sm := m as StandardMaterial3D
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		var tw := create_tween()
		tw.tween_property(sm, "albedo_color:a", 0.0, 0.7).set_trans(Tween.TRANS_SINE)
	var t2 := create_tween()
	t2.tween_property(_pose, "position:y", _lie_lift - 0.35, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _give(id: String) -> String:
	var inv = GameState.inventory
	var nm: String = inv.items[id]["name"] if inv.items.has(id) else id
	if inv.add(id, 1) > 0:
		return "(bag full: %s lost)" % nm
	return "+1 %s" % nm


## Angka melayang (tanpa teks lain). Ukuran diatur lewat NUMBER_SIZE di atas (dan `mult` per jenis angka).
func _float_number(text: String, col: Color, at: Vector3, delay: float, mult: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.pixel_size = 0.0055 * NUMBER_SIZE * mult
	l.modulate = col
	l.outline_size = 14
	l.outline_modulate = Color(0.10, 0.05, 0.03)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 5
	if _font:
		l.font = _font
	l.top_level = true
	l.scale = Vector3.ONE * 0.4
	get_parent().add_child(l)
	l.global_position = at
	var tw := l.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(l, "scale", Vector3.ONE * 1.25, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)   # membesar sekejap
	tw.tween_property(l, "scale", Vector3.ONE, 0.1)
	tw.tween_property(l, "global_position:y", at.y + 0.9, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tw.tween_callback(l.queue_free)
