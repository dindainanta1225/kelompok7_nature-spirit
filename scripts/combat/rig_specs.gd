extends RefCounted
## RigSpecs - letak tulang tiap monster (koordinat model setelah dihadapkan ke +Z; satuan = ukuran asli model).
## Kalau mau menyetel: head/tail = dua ujung ruas tulang, r = "ketebalan" (area yang pasti ikut tulang itu).
## Nama tulang dipakai rig_anim.gd.


static func _m(v: Vector3) -> Vector3:
	return Vector3(-v.x, v.y, v.z)


## Tulang dua kaki + dua tangan + tulang belakang + kepala (imp, skeleton, werewolf).
static func _biped(hip: Vector3, chest: Vector3, neck: Vector3, top: Vector3, sh: Vector3, el: Vector3, hand: Vector3, th: Vector3, kn: Vector3, ft: Vector3, trunk_r: float, limb_r: float, head_r: float) -> Array:
	return [
		{"name": "hips", "parent": "", "head": hip, "tail": hip.lerp(chest, 0.5), "r": trunk_r},
		{"name": "spine", "parent": "hips", "head": hip.lerp(chest, 0.5), "tail": neck, "r": trunk_r},
		{"name": "head", "parent": "spine", "head": neck, "tail": top, "r": head_r},
		{"name": "up_R", "parent": "spine", "head": sh, "tail": el, "r": limb_r},
		{"name": "low_R", "parent": "up_R", "head": el, "tail": hand, "r": limb_r},
		{"name": "up_L", "parent": "spine", "head": _m(sh), "tail": _m(el), "r": limb_r},
		{"name": "low_L", "parent": "up_L", "head": _m(el), "tail": _m(hand), "r": limb_r},
		{"name": "th_R", "parent": "hips", "head": th, "tail": kn, "r": limb_r},
		{"name": "sh_R", "parent": "th_R", "head": kn, "tail": ft, "r": limb_r},
		{"name": "th_L", "parent": "hips", "head": _m(th), "tail": _m(kn), "r": limb_r},
		{"name": "sh_L", "parent": "th_L", "head": _m(kn), "tail": _m(ft), "r": limb_r},
	]


## Spesifikasi untuk monster: Dictionary tetap, atau Callable(tinggi_model) kalau tulang dihitung dari ukuran model.
static func spec_for(kind: String) -> Variant:
	if kind == "hunter":
		return func(h: float, _sz: Vector3) -> Dictionary: return humanoid(h, "apose", 0.4, 0.2)
	if kind == "goblin":
		return func(h: float, _sz: Vector3) -> Dictionary: return humanoid(h, "down", 0.42, 0.2)
	return get_spec(kind)


static func needs_recenter(kind: String) -> bool:
	return kind == "goblin" or kind == "hunter"


## Tulang manusia/humanoid dari proporsi tinggi H (kaki di y=0, titik tengah di x=z=0, menghadap +Z).
## arm: "down" (tangan turun), "apose" (miring ke bawah), "tpose" (lurus ke samping).
static func humanoid(h: float, arm := "down", hip := 0.5, knee := 0.27) -> Dictionary:
	var sh := Vector3(0.115, 0.80, 0.0) * h
	var el: Vector3
	var hand: Vector3
	match arm:
		"apose":
			el = Vector3(0.28, 0.69, 0.0) * h
			hand = Vector3(0.46, 0.55, 0.01) * h
		"tpose":
			sh = Vector3(0.13, 0.64, 0.0) * h
			el = Vector3(0.38, 0.63, 0.0) * h
			hand = Vector3(0.66, 0.61, 0.0) * h
		_:
			el = Vector3(0.15, 0.62, 0.0) * h
			hand = Vector3(0.16, 0.45, 0.02) * h
	var b := _biped(Vector3(0, hip, 0) * h, Vector3(0, hip + 0.2, 0) * h, Vector3(0, 0.82, 0.01) * h, Vector3(0, 1.0, 0.01) * h,
		sh, el, hand, Vector3(0.045, hip, 0) * h, Vector3(0.045, knee, 0.0) * h, Vector3(0.045, 0.01, 0.03) * h,
		0.07 * h, 0.03 * h, 0.085 * h)
	return {"bones": b}


## Ayam: badan, kepala (mematuk), ekor, dua sayap, dua kaki.
static func chicken(h: float) -> Dictionary:
	var k := h / 0.38
	var q := [
		{"name": "body", "parent": "", "head": Vector3(0, 0.2, -0.02) * k, "tail": Vector3(0, 0.22, 0.06) * k, "r": 0.07 * k},
		{"name": "head", "parent": "body", "head": Vector3(0, 0.27, 0.1) * k, "tail": Vector3(0, 0.35, 0.17) * k, "r": 0.04 * k},
		{"name": "tail", "parent": "body", "head": Vector3(0, 0.24, -0.1) * k, "tail": Vector3(0, 0.33, -0.18) * k, "r": 0.0},
	]
	for sd in [1.0, -1.0]:
		var n := "R" if sd > 0 else "L"
		q.append({"name": "wing_" + n, "parent": "body", "head": Vector3(0.045 * sd, 0.26, 0.02) * k, "tail": Vector3(0.06 * sd, 0.2, -0.1) * k, "r": 0.0})
		q.append({"name": "leg_" + n, "parent": "body", "head": Vector3(0.025 * sd, 0.13, 0.0) * k, "tail": Vector3(0.025 * sd, 0.0, 0.02) * k, "r": 0.0})
	return {"bones": q}


static func get_spec(kind: String) -> Dictionary:
	match kind:
		"slime":      # IMP (kecil, ekor)
			var b := _biped(Vector3(0, 0.21, 0), Vector3(0, 0.44, 0.0), Vector3(0, 0.45, 0.02), Vector3(0, 0.69, 0.02),
				Vector3(0.09, 0.42, 0.0), Vector3(0.2, 0.35, 0.01), Vector3(0.33, 0.28, 0.04),
				Vector3(0.06, 0.2, 0.0), Vector3(0.06, 0.1, 0.01), Vector3(0.06, 0.0, 0.04), 0.05, 0.025, 0.1)
			b.append({"name": "tail1", "parent": "hips", "head": Vector3(0, 0.14, -0.05), "tail": Vector3(0, 0.1, -0.22), "r": 0.0})
			b.append({"name": "tail2", "parent": "tail1", "head": Vector3(0, 0.1, -0.22), "tail": Vector3(0, 0.09, -0.4), "r": 0.0})
			return {"bones": b}
		"skeleton":   # SKELETON (pedang di tangan kanan)
			return {"bones": _biped(Vector3(0, 0.6, -0.02), Vector3(0, 1.15, -0.03), Vector3(0, 1.32, -0.03), Vector3(0, 1.9, 0.0),
				Vector3(0.27, 1.22, -0.03), Vector3(0.3, 0.9, -0.02), Vector3(0.3, 0.58, 0.05),
				Vector3(0.11, 0.6, -0.02), Vector3(0.11, 0.32, -0.01), Vector3(0.11, 0.0, 0.05), 0.12, 0.05, 0.2),
				"rigid": {"sword": "low_R"}}
		"wolf":       # WEREWOLF (tangan kanan terangkat)
			return {"bones": _biped(Vector3(0, 0.78, 0.1), Vector3(0, 1.4, 0.15), Vector3(0, 1.45, 0.2), Vector3(0, 1.92, 0.3),
				Vector3(0.3, 1.38, 0.12), Vector3(0.62, 1.45, 0.2), Vector3(1.15, 1.75, 0.3),
				Vector3(0.2, 0.75, 0.1), Vector3(0.22, 0.38, 0.2), Vector3(0.25, 0.02, 0.3), 0.2, 0.08, 0.2)}
		_:            # BEAR (4 kaki)
			var q := [
				{"name": "hips", "parent": "", "head": Vector3(0, 1.2, -0.7), "tail": Vector3(0, 1.35, -0.1), "r": 0.35},
				{"name": "spine", "parent": "hips", "head": Vector3(0, 1.35, -0.1), "tail": Vector3(0, 1.55, 0.6), "r": 0.35},
				{"name": "head", "parent": "spine", "head": Vector3(0, 1.65, 0.85), "tail": Vector3(0, 1.6, 1.95), "r": 0.25},
			]
			for side in [1.0, -1.0]:
				var s := "R" if side > 0 else "L"
				q.append({"name": "fup_" + s, "parent": "spine", "head": Vector3(0.4 * side, 1.25, 0.7), "tail": Vector3(0.4 * side, 0.65, 0.72), "r": 0.1})
				q.append({"name": "flo_" + s, "parent": "fup_" + s, "head": Vector3(0.4 * side, 0.65, 0.72), "tail": Vector3(0.4 * side, 0.0, 0.78), "r": 0.1})
				q.append({"name": "rup_" + s, "parent": "hips", "head": Vector3(0.42 * side, 1.2, -0.72), "tail": Vector3(0.42 * side, 0.65, -0.66), "r": 0.1})
				q.append({"name": "rlo_" + s, "parent": "rup_" + s, "head": Vector3(0.42 * side, 0.65, -0.66), "tail": Vector3(0.42 * side, 0.0, -0.6), "r": 0.1})
			return {"bones": q}


## Hewan berkaki empat (kuda, domba): badan memanjang sepanjang +Z. h = tinggi total, sz = ukuran kotak model (x, y, z).
## leg = tinggi kaki (pecahan dari h), neck = pangkal leher (pecahan dari h), nama tulang sama dengan beruang (fup/flo/rup/rlo).
static func quadruped(h: float, sz: Vector3, leg := 0.5, neck := 0.7, head_len := 0.22) -> Dictionary:
	var l := sz.z
	var hw := maxf(sz.x * 0.28, 0.02)
	var hy := h * leg
	var ty := h * (leg + 0.1)
	var front_z := l * 0.28
	var rear_z := -l * 0.28
	var q := [
		{"name": "hips", "parent": "", "head": Vector3(0, ty, rear_z), "tail": Vector3(0, ty, 0), "r": h * 0.18},
		{"name": "spine", "parent": "hips", "head": Vector3(0, ty, 0), "tail": Vector3(0, h * neck, l * 0.36), "r": h * 0.18},
		{"name": "head", "parent": "spine", "head": Vector3(0, h * neck, l * 0.36), "tail": Vector3(0, h * 0.9, l * (0.36 + head_len)), "r": h * 0.1},
		{"name": "tail", "parent": "hips", "head": Vector3(0, ty, rear_z - l * 0.08), "tail": Vector3(0, ty * 0.7, rear_z - l * 0.3), "r": 0.0},
	]
	for sd in [1.0, -1.0]:
		var n := "R" if sd > 0 else "L"
		q.append({"name": "fup_" + n, "parent": "spine", "head": Vector3(hw * sd, hy, front_z), "tail": Vector3(hw * sd, hy * 0.5, front_z + 0.01), "r": h * 0.04})
		q.append({"name": "flo_" + n, "parent": "fup_" + n, "head": Vector3(hw * sd, hy * 0.5, front_z + 0.01), "tail": Vector3(hw * sd, 0.0, front_z + 0.02), "r": h * 0.04})
		q.append({"name": "rup_" + n, "parent": "hips", "head": Vector3(hw * sd, hy, rear_z), "tail": Vector3(hw * sd, hy * 0.5, rear_z - 0.01), "r": h * 0.04})
		q.append({"name": "rlo_" + n, "parent": "rup_" + n, "head": Vector3(hw * sd, hy * 0.5, rear_z - 0.01), "tail": Vector3(hw * sd, 0.0, rear_z - 0.02), "r": h * 0.04})
	return {"bones": q}


## Centaur (Centorea): badan kuda di bawah + tubuh manusia di depan atas. Tulang kaki sama dengan quadruped,
## ditambah torso/head/up_/low_ (tangan) di bagian manusia.
static func centaur(h: float, sz: Vector3) -> Dictionary:
	var l := sz.z
	var base := quadruped(h, sz, 0.3, 0.52, 0.0)
	var q: Array = []
	for b in base["bones"]:
		if b["name"] == "head" or b["name"] == "spine":
			continue
		q.append(b)
	var hip_y := h * 0.34
	var fz := l * 0.3
	q.insert(1, {"name": "spine", "parent": "hips", "head": Vector3(0, hip_y, 0), "tail": Vector3(0, hip_y + h * 0.04, fz), "r": h * 0.14})
	var tz := fz
	q.append({"name": "torso", "parent": "spine", "head": Vector3(0, h * 0.5, tz), "tail": Vector3(0, h * 0.8, tz), "r": h * 0.07})
	q.append({"name": "head", "parent": "torso", "head": Vector3(0, h * 0.8, tz), "tail": Vector3(0, h * 0.97, tz), "r": h * 0.07})
	for sd in [1.0, -1.0]:
		var n := "R" if sd > 0 else "L"
		q.append({"name": "up_" + n, "parent": "torso", "head": Vector3(0.1 * h * sd, h * 0.76, tz), "tail": Vector3(0.12 * h * sd, h * 0.6, tz), "r": h * 0.025})
		q.append({"name": "low_" + n, "parent": "up_" + n, "head": Vector3(0.12 * h * sd, h * 0.6, tz), "tail": Vector3(0.13 * h * sd, h * 0.45, tz + 0.02), "r": h * 0.025})
	return {"bones": q}
