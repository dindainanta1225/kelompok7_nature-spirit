extends RefCounted
## RigAnim - animasi prosedural untuk model yang dipasangi AutoRig: kaki melangkah, tangan berayun, tangan
## mengayun saat menyerang, kepala tersentak saat kena pukul, ekor imp mengibas, napas saat diam.
## Semua gerakan berupa putaran tulang (halus, di-lerp tiap frame). Sudut positif pada swing() = ke DEPAN.

var _skel: Skeleton3D
var _idx := {}
var _dir := {}                 # arah istirahat tiap tulang (untuk menentukan sumbu ayunan)
var _cur := {}                 # rotasi terakhir (Quaternion) per tulang
var _kind := "slime"
var _phase := 0.0
var _w := 0.0                  # intensitas berjalan 0..1
var _dress := false            # baju panjang: ayunan kaki dikurangi supaya rok tidak sobek
var _bias := {}                # rotasi diam per tulang (mis. menurunkan tangan T-pose)
var _native := {}              # skeleton bawaan GLB: nama -> {rp_inv, r, s, s_inv} (lihat native_rig.gd)


## profile (opsional): {"dress": bool, "arms_down": derajat} -> tangan yang lurus ke samping diturunkan.
func _init(skeleton: Skeleton3D, bones: Dictionary, bone_specs: Array, kind: String, profile := {}) -> void:
	_skel = skeleton
	_idx = bones
	_kind = kind
	_dress = bool(profile.get("dress", false))
	var ad := float(profile.get("arms_down", 0.0))
	if ad != 0.0:
		_bias["up_R"] = Quaternion(Vector3(0, 0, 1), -deg_to_rad(ad))
		_bias["up_L"] = Quaternion(Vector3(0, 0, 1), deg_to_rad(ad))
	for b in bone_specs:
		var d := ((b["tail"] as Vector3) - (b["head"] as Vector3)).normalized()
		if _bias.has(b["name"]):
			d = (_bias[b["name"]] as Quaternion) * d
		_dir[b["name"]] = d
		_cur[b["name"]] = _bias.get(b["name"], Quaternion.IDENTITY)


## Putar tulang `name` ke depan sebesar `ang` radian (negatif = ke belakang/atas-belakang).
func _swing(name: String, ang: float, extra := Vector3.ZERO) -> void:
	if not _idx.has(name):
		return
	var d: Vector3 = _dir[name]
	var axis := d.cross(Vector3(0, 0, 1))
	if axis.length() < 0.01:
		axis = Vector3(1, 0, 0)
	var q := Quaternion(axis.normalized(), ang)
	if extra != Vector3.ZERO:
		q = q * Quaternion.from_euler(extra)
	_rot(name, q)


func use_native(tbl: Dictionary) -> void:
	_native = tbl


func _rot(name: String, q: Quaternion) -> void:
	if _bias.has(name):
		q = q * (_bias[name] as Quaternion)
	var cur: Quaternion = _cur[name]
	cur = cur.slerp(q, 0.4)
	_cur[name] = cur
	if _native.has(name):                              # putaran di ruang model -> putaran lokal tulang asli
		var nt: Dictionary = _native[name]
		_skel.set_bone_pose_rotation(_idx[name], (nt["rp_inv"] as Quaternion) * (nt["s_inv"] as Quaternion) * cur * (nt["s"] as Quaternion) * (nt["r"] as Quaternion))
	else:
		_skel.set_bone_pose_rotation(_idx[name], cur)


func _pitch(name: String, ang: float) -> void:                  # condong/menunduk ke depan = positif
	if _idx.has(name):
		_rot(name, Quaternion(Vector3(1, 0, 0), ang))


## ctx: speed (0..1 jalan), chase (bool), windup (0..1 saat ancang-ancang, -1 kalau tidak), lunge (0..1), hit (0..1), t, delta
func update(ctx: Dictionary) -> void:
	var dt: float = ctx["delta"]
	var spd: float = ctx["speed"]
	_w = lerpf(_w, spd, 0.15)
	_phase += dt * (5.0 + 7.0 * _w) * (1.0 if _w > 0.05 else 0.0)
	if _kind == "boar" or _kind == "quad":
		_update_quad(ctx)
	elif _kind == "centaur":
		_update_centaur(ctx)
	elif _kind == "chicken":
		_update_chicken(ctx)
	else:
		_update_biped(ctx)


func _update_biped(c: Dictionary) -> void:
	var s := sin(_phase)
	var co := cos(_phase)
	var w := _w
	var t: float = c["t"]
	var wind: float = c["windup"]
	var lunge: float = c["lunge"]
	var hit: float = c["hit"] * c["hit"]
	var leg_a := 1.0 * w * (0.4 if _dress else 1.0)
	var knee := 1.1 * w * (0.3 if _dress else 1.0)
	_swing("th_R", leg_a * s)
	_swing("th_L", -leg_a * s)
	_swing("sh_R", -knee * maxf(0.0, co) - 0.05)
	_swing("sh_L", -knee * maxf(0.0, -co) - 0.05)
	# tangan: berayun berlawanan dengan kaki; saat menyerang diangkat ke belakang lalu diayun ke depan
	var arm_a := 0.6 * w
	var breathe := sin(t * 2.2) * 0.04
	var ar := -arm_a * s + breathe
	var al := arm_a * s + breathe
	var lr := 0.35 * w
	var ll := 0.35 * w
	if wind >= 0.0:
		var e := 1.0 - pow(1.0 - wind, 2.0)
		ar = -2.3 * e
		al = -1.6 * e
		lr = -0.4 * e
		ll = -0.3 * e
	elif lunge > 0.01:
		ar = 1.5 * lunge - 0.2
		al = 1.0 * lunge
		lr = 0.7 * lunge
		ll = 0.5 * lunge
	if _kind == "skeleton":               # skeleton: pedang terarah ke depan -> angkat tinggi lalu tebas ke bawah
		if wind >= 0.0:
			ar = 2.0 * (1.0 - pow(1.0 - wind, 2.0))
			lr = 0.0
		elif lunge > 0.01:
			ar = -0.55 * lunge
			lr = 0.0
	var talk: float = c.get("talk", 0.0)
	if talk > 0.01:                                             # bicara: tangan kanan menggerakkan isyarat, kepala mengangguk
		ar = lerpf(ar, 0.45 + 0.25 * sin(t * 3.2), talk)
		lr = lerpf(lr, 1.1 + 0.3 * sin(t * 4.7), talk)
	var tool: float = c.get("tool", -1.0)
	var spine_extra := 0.0
	if tool >= 0.0:                                             # aksi pemain (cangkul, siram, tebas, makan, ...)
		var a := _tool_arms(String(c.get("tool_kind", "hoe")), tool)
		ar = a[0]
		al = a[1]
		lr = a[2]
		ll = a[3]
		spine_extra = a[4]
	ar -= 1.0 * hit
	al -= 1.0 * hit
	_swing("up_R", ar)
	_swing("up_L", al)
	_swing("low_R", lr)
	_swing("low_L", ll)
	# badan & kepala
	var lean := 0.08 * w + 0.35 * lunge - 0.2 * (maxf(wind, 0.0)) - 0.45 * hit + spine_extra
	_pitch("spine", lean + sin(t * 2.2) * 0.015)
	_pitch("head", -0.12 * lunge + 0.12 * hit * -1.0 + sin(t * 1.3) * 0.03 + sin(t * 4.0) * 0.08 * talk)
	_pitch("hips", 0.04 * sin(_phase * 2.0) * w)
	# ekor (imp)
	if _idx.has("tail1"):
		var f := 4.0 + 6.0 * w
		_rot("tail1", Quaternion(Vector3(0, 1, 0), sin(t * f) * 0.5))
		_rot("tail2", Quaternion(Vector3(0, 1, 0), sin(t * f + 1.2) * 0.7))


func _update_quad(c: Dictionary) -> void:
	var s := sin(_phase)
	var co := cos(_phase)
	var w := _w
	var t: float = c["t"]
	var wind: float = c["windup"]
	var lunge: float = c["lunge"]
	var hit: float = c["hit"] * c["hit"]
	var a := 0.9 * w
	# jalan diagonal: kaki depan kanan + belakang kiri sefase
	var fr := a * s
	var fl := -a * s
	var rr := -a * s
	var rl := a * s
	_swing("fup_R", fr)
	_swing("fup_L", fl)
	_swing("rup_R", rr)
	_swing("rup_L", rl)
	_swing("flo_R", -0.7 * w * maxf(0.0, co))
	_swing("flo_L", -0.7 * w * maxf(0.0, -co))
	_swing("rlo_R", -0.7 * w * maxf(0.0, -co))
	_swing("rlo_L", -0.7 * w * maxf(0.0, co))
	if wind >= 0.0:                                         # angkat kedua cakar depan lalu hantam
		var e := 1.0 - pow(1.0 - wind, 2.0)
		_swing("fup_R", 1.5 * e)
		_swing("fup_L", 1.3 * e)
		_swing("flo_R", 0.4 * e)
		_swing("flo_L", 0.4 * e)
	elif lunge > 0.01:
		_swing("fup_R", -0.5 * lunge)
		_swing("fup_L", -0.4 * lunge)
	var peck: float = c.get("peck", 0.0)                    # hewan ternak merumput: kepala menunduk
	_pitch("spine", 0.03 * sin(_phase * 2.0) * w - 0.2 * maxf(wind, 0.0) + 0.1 * lunge - 0.2 * hit + 0.1 * peck)
	_pitch("head", 0.35 * lunge - 0.25 * hit + 0.05 * sin(t * 1.5) + 0.05 * sin(_phase * 2.0) * w + 0.9 * peck)
	if _idx.has("tail"):
		_rot("tail", Quaternion(Vector3(0, 1, 0), sin(t * 3.0 + _phase) * (0.25 + 0.3 * w)))


## Centaur: empat kaki seperti kuda (walk), tubuh manusia: kepala/tangan bergerak, isyarat saat bicara.
func _update_centaur(c: Dictionary) -> void:
	_update_quad(c)
	var t: float = c["t"]
	var talk: float = c.get("talk", 0.0)
	var w := _w
	_swing("up_R", -0.35 * w * sin(_phase) + sin(t * 2.0) * 0.04 + talk * (0.5 + 0.25 * sin(t * 3.2)))
	_swing("up_L", 0.35 * w * sin(_phase) + sin(t * 2.0) * 0.04)
	_swing("low_R", 0.2 * w + talk * (1.0 + 0.3 * sin(t * 4.7)))
	_swing("low_L", 0.2 * w)
	_pitch("torso", -0.03 + 0.03 * sin(t * 1.4))
	_pitch("head", 0.05 * sin(t * 1.1) + 0.08 * sin(t * 4.0) * talk)


## Ayam: berjalan (kaki bergantian), mematuk (kepala menunduk), sayap mengepak, ekor bergoyang.
func _update_chicken(c: Dictionary) -> void:
	var w := _w
	var t: float = c["t"]
	var s := sin(_phase * 1.5)
	var peck: float = c.get("peck", 0.0)
	var flap: float = c.get("flap", 0.0)
	_swing("leg_R", 0.9 * w * s)
	_swing("leg_L", -0.9 * w * s)
	_pitch("head", 1.0 * peck + 0.18 * sin(_phase * 3.0) * w + sin(t * 1.7) * 0.05)
	_pitch("body", 0.12 * peck - 0.04 * w)
	_pitch("tail", 0.12 * sin(t * 2.3) + 0.1 * w)
	var f := sin(t * 32.0) * flap
	if _idx.has("wing_R"):
		_rot("wing_R", Quaternion(Vector3(0, 0, 1), 0.12 + 0.7 * flap + 0.4 * f))
		_rot("wing_L", Quaternion(Vector3(0, 0, 1), -(0.12 + 0.7 * flap + 0.4 * f)))


## Sudut tangan (kanan, kiri, siku kanan, siku kiri, condong badan) untuk aksi pemain; p = 0..1 progres aksi.
func _tool_arms(kind: String, p: float) -> Array:
	var raise := clampf(p / 0.45, 0.0, 1.0)
	var slam := clampf((p - 0.45) / 0.22, 0.0, 1.0)
	var back := clampf((p - 0.7) / 0.3, 0.0, 1.0)
	match kind:
		"hoe", "tool":                                                  # angkat cangkul tinggi, hantam ke tanah
			var a := lerpf(0.2, 2.6, raise)
			a = lerpf(a, 1.0, slam)
			a = lerpf(a, 0.2, back)
			return [a, a * 0.85, lerpf(0.4, 0.9, raise) * (1.0 - back), 0.5 * (1.0 - back), 0.45 * slam * (1.0 - back) - 0.1 * raise]
		"scythe":
			var a := lerpf(0.3, -0.9, raise)
			a = lerpf(a, 1.7, slam)
			a = lerpf(a, 0.2, back)
			return [a, 0.4 * a, 0.3, 0.3, 0.3 * slam * (1.0 - back)]
		"sword":
			var a := lerpf(0.0, -1.9, raise)
			a = lerpf(a, 1.7, slam)
			a = lerpf(a, 0.1, back)
			return [a, 0.2, 0.2 * slam, 0.2, 0.3 * slam * (1.0 - back) - 0.15 * raise]
		"water":                                                        # lengan lurus ke depan, miring menuang
			var hold := sin(clampf(p, 0.0, 1.0) * PI)
			return [1.35 * hold, 0.3 * hold, 0.3 * hold, 0.2, 0.12 * hold]
		"plant":
			var d := sin(clampf(p, 0.0, 1.0) * PI)
			return [0.9 * d, 0.2, 0.5 * d, 0.2, 0.35 * d]
		"harvest":
			var d := sin(clampf(p, 0.0, 1.0) * PI)
			return [0.7 * d, 0.7 * d, 0.5 * d, 0.5 * d, 0.4 * d]
		"eat":
			var d := sin(clampf(p, 0.0, 1.0) * PI)
			var bite := 0.12 * sin(p * 28.0) * d
			return [1.0 * d, 0.2, 2.1 * d + bite, 0.2, 0.0]
		"celebrate":
			var j := 0.15 * sin(p * 24.0)
			return [3.0 + j, 3.0 - j, 0.3, 0.3, -0.1]
	return [1.2 * sin(p * PI), 0.2, 0.3, 0.2, 0.2 * sin(p * PI)]
