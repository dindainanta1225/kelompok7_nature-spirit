extends RefCounted
## BioMat - material PBR realistis untuk makhluk hidup (karakter, NPC, monster): kulit dengan subsurface scattering
## dan pori halus, rambut berkilau (rim/anisotropi), kain bertenun, kulit samak, logam, bulu berserat, gel licin, mata basah.
## Tekstur dibuat lewat kode (NoiseTexture2D) dan di-cache; tiap pemanggilan mengembalikan material BARU
## (monster mengubah emission saat kena pukul, jadi tidak boleh dibagi antar-makhluk).

static var _tex := {}


static func _noise_tex(key: String, seed_v: int, freq: float, kind: int, normal: bool, bump: float, ramp_lo := 0.8, ramp_hi := 1.1) -> NoiseTexture2D:
	if _tex.has(key):
		return _tex[key]
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	var n := FastNoiseLite.new()
	n.noise_type = kind
	n.seed = seed_v
	n.frequency = freq
	n.fractal_octaves = 3
	t.noise = n
	if normal:
		t.as_normal_map = true
		t.bump_strength = bump
	else:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(ramp_lo, ramp_lo, ramp_lo), Color(ramp_hi, ramp_hi, ramp_hi)])
		t.color_ramp = g
	_tex[key] = t
	return t


static func _base(c: Color, rough: float, normal_key: String, freq: float, kind: int, bump: float, uv: float, nscale := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.normal_enabled = true
	m.normal_texture = _noise_tex(normal_key, hash(normal_key), freq, kind, true, bump)
	m.normal_scale = nscale
	m.albedo_texture = _noise_tex(normal_key + "_a", hash(normal_key) + 7, freq * 0.5, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, false, 0.0, 0.95, 1.05)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * uv
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Kulit: subsurface scattering hangat, pori halus, sedikit rim.
static func skin(c: Color, rough := 0.52) -> StandardMaterial3D:
	var m := _base(c, rough, "skin_n", 0.9, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1.0, 5.0, 0.15)
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.3
	m.subsurf_scatter_skin_mode = false
	m.rim_enabled = true
	m.rim = 0.25
	m.rim_tint = 0.6
	return m


## Rambut: kilau halus anisotropi, rim lembut.
static func hair(c: Color) -> StandardMaterial3D:
	var m := _base(c, 0.34, "hair_n", 1.6, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 3.0, 5.0, 0.7)
	m.anisotropy_enabled = true
	m.anisotropy = 0.7
	m.metallic = 0.12
	m.metallic_specular = 0.7
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.5
	return m


## Kain: tenunan halus, sheen rim.
static func cloth(c: Color) -> StandardMaterial3D:
	var m := _base(c, 0.92, "cloth_n", 2.4, FastNoiseLite.TYPE_CELLULAR, 1.6, 7.0, 0.55)
	m.rim_enabled = true
	m.rim = 0.15
	m.rim_tint = 0.8
	return m


static func leather(c: Color) -> StandardMaterial3D:
	var m := _base(c, 0.55, "leather_n", 0.35, FastNoiseLite.TYPE_CELLULAR, 4.0, 5.0, 0.8)
	m.clearcoat_enabled = true
	m.clearcoat = 0.25
	m.clearcoat_roughness = 0.45
	return m


static func wood(c: Color) -> StandardMaterial3D:
	var m := _base(c, 0.7, "bwood_n", 0.5, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 5.0, 3.0, 0.9)
	m.uv1_scale = Vector3(0.6, 3.0, 0.6)
	return m


static func metal(c: Color) -> StandardMaterial3D:
	var m := _base(c, 0.28, "metal_n", 0.6, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1.2, 4.0, 0.3)
	m.metallic = 0.92
	m.metallic_specular = 0.9
	return m


## Bulu: normal berserat kasar, rim tebal supaya siluet terlihat berbulu.
static func fur(c: Color) -> StandardMaterial3D:
	var m := _base(c, 0.96, "fur_n", 2.8, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 6.0, 9.0, 1.0)
	m.rim_enabled = true
	m.rim = 0.22
	m.rim_tint = 0.5
	return m


## Gel/lendir: licin, tembus cahaya, kilap basah.
static func gel(c: Color, alpha := 0.88) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.06
	m.metallic_specular = 0.9
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.05
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.9
	m.rim_enabled = true
	m.rim = 0.6
	m.rim_tint = 0.3
	m.emission_enabled = true
	m.emission = Color(c.r, c.g, c.b) * 0.18
	return m


## Mata basah mengilap (kornea).
static func eye(c: Color, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.06
	m.metallic_specular = 1.0
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.03
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


## Taring, gading, tulang: halus sedikit tembus.
static func bone(c: Color) -> StandardMaterial3D:
	var m := _base(c, 0.4, "bone_n", 1.2, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 2.0, 5.0, 0.4)
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.3
	m.clearcoat_enabled = true
	m.clearcoat = 0.3
	return m
