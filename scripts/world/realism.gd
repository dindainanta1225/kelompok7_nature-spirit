extends RefCounted
## Realism - tampilan lebih realistis & modern (bukan flat low-poly): material PBR bertekstur (rumput, tanah, kayu, batu)
## dengan normal map, cahaya matahari lembut + SSAO + glow + kabut volumetrik + tonemap sinematik, dan rumput 3D
## yang bergoyang tertiup angin (MultiMesh + shader). Semua dibuat lewat kode, tanpa file gambar.
## (Efek lanjutan butuh renderer Forward+ / Mobile; di Compatibility otomatis tampil sederhana.)

static var _cache := {}


# ------------------------------------------------------------------ tekstur
static func _noise(seed_v: int, freq: float, kind: int, octaves := 4) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = kind
	n.seed = seed_v
	n.frequency = freq
	n.fractal_octaves = octaves
	return n


static func _noise_tex(key: String, seed_v: int, freq: float, ramp: Array, normal := false, bump := 4.0, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH, size := 512) -> NoiseTexture2D:
	if _cache.has(key):
		return _cache[key]
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = _noise(seed_v, freq, kind)
	if normal:
		t.as_normal_map = true
		t.bump_strength = bump
	else:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array(ramp[0])
		g.colors = PackedColorArray(ramp[1])
		t.color_ramp = g
	_cache[key] = t
	return t


## MODE LOW-POLY: material polos tanpa tekstur/normal map, tanpa rumput helai & daun bershader. Dipasang farm/desa/hutan; rumah player (home.gd) tetap realistis.
static var flat := false


static func _flat(c: Color, rough := 0.95) -> StandardMaterial3D:
	var k := "flat" + c.to_html()
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic_specular = 0.2
	_cache[k] = m
	return m


static func _flat_glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.6
	return m


static func _std(albedo_tex: Texture2D, normal_tex: Texture2D, tint: Color, rough: float, uv_scale: float, normal_scale := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	if albedo_tex:
		m.albedo_texture = albedo_tex
	if normal_tex:
		m.normal_enabled = true
		m.normal_texture = normal_tex
		m.normal_scale = normal_scale
	m.roughness = rough
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * uv_scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Rumput tanah: variasi hijau + normal halus.
static func ground(tint := Color.WHITE) -> StandardMaterial3D:
	if flat:
		return _flat(Color(0.42, 0.62, 0.30) * tint)
	var k := "ground" + tint.to_html()
	if _cache.has(k):
		return _cache[k]
	var a := _noise_tex("g_a", 3, 0.012, [[0.0, 0.5, 1.0], [Color(0.30, 0.48, 0.20), Color(0.40, 0.58, 0.26), Color(0.52, 0.66, 0.30)]], false, 0.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1024)
	var d := _noise_tex("g_d", 9, 0.09, [[0.0, 1.0], [Color(0.8, 0.8, 0.8), Color(1.12, 1.12, 1.05)]])
	var n := _noise_tex("g_n", 5, 0.12, [], true, 5.0, FastNoiseLite.TYPE_PERLIN)
	var m := _std(a, n, tint, 0.96, 0.06, 0.7)
	m.detail_enabled = true
	m.detail_mask = null
	m.detail_albedo = d
	m.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	m.uv2_triplanar = true
	m.uv2_scale = Vector3.ONE * 0.5
	_cache[k] = m
	return m


## Tanah gembur (petak tanam).
static func soil(tint := Color.WHITE) -> StandardMaterial3D:
	if flat:
		return _flat(Color(0.36, 0.23, 0.13) * tint)
	var k := "soil" + tint.to_html()
	if _cache.has(k):
		return _cache[k]
	var a := _noise_tex("s_a", 21, 0.06, [[0.0, 0.5, 1.0], [Color(0.24, 0.15, 0.09), Color(0.36, 0.23, 0.13), Color(0.46, 0.31, 0.18)]], false, 0.0, FastNoiseLite.TYPE_CELLULAR)
	var n := _noise_tex("s_n", 22, 0.22, [], true, 9.0, FastNoiseLite.TYPE_CELLULAR)
	var m := _std(a, n, tint, 0.98, 0.35, 1.2)
	_cache[k] = m
	return m


## Jalan tanah / kerikil.
static func gravel(tint := Color.WHITE) -> StandardMaterial3D:
	if flat:
		return _flat(Color(0.46, 0.38, 0.27) * tint)
	var k := "gravel" + tint.to_html()
	if _cache.has(k):
		return _cache[k]
	var a := _noise_tex("v_a", 33, 0.10, [[0.0, 0.5, 1.0], [Color(0.34, 0.28, 0.20), Color(0.46, 0.38, 0.27), Color(0.56, 0.47, 0.34)]], false, 0.0, FastNoiseLite.TYPE_CELLULAR)
	var n := _noise_tex("v_n", 34, 0.30, [], true, 8.0, FastNoiseLite.TYPE_CELLULAR)
	var m := _std(a, n, tint, 0.92, 0.5, 1.0)
	_cache[k] = m
	return m


## Kayu bergaris (serat memanjang). Cocok untuk pagar, papan, perabot.
static func wood(tint: Color) -> StandardMaterial3D:
	if flat:
		return _flat(tint, 0.9)
	var k := "wood" + tint.to_html()
	if _cache.has(k):
		return _cache[k]
	var tex := _noise_tex("w_a", 41, 0.004, [[0.0, 0.5, 1.0], [Color(0.70, 0.70, 0.70), Color(0.92, 0.92, 0.92), Color(1.1, 1.1, 1.1)]], false, 0.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 512)
	var n := _noise_tex("w_n", 42, 0.02, [], true, 6.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
	var m := _std(tex, n, tint, 0.72, 0.9, 0.9)
	m.uv1_scale = Vector3(0.25, 3.2, 0.25)                     # diregangkan -> serat panjang
	m.uv1_triplanar = true
	_cache[k] = m
	return m


## Batu / plester.
static func stone(tint: Color) -> StandardMaterial3D:
	if flat:
		return _flat(tint, 0.9)
	var k := "stone" + tint.to_html()
	if _cache.has(k):
		return _cache[k]
	var tex := _noise_tex("t_a", 51, 0.05, [[0.0, 1.0], [Color(0.66, 0.66, 0.66), Color(1.1, 1.1, 1.1)]], false, 0.0, FastNoiseLite.TYPE_CELLULAR)
	var n := _noise_tex("t_n", 52, 0.07, [], true, 7.0, FastNoiseLite.TYPE_CELLULAR)
	var m := _std(tex, n, tint, 0.9, 0.6, 1.0)
	_cache[k] = m
	return m


## Tambah detail normal + kekasaran ke material polos (dipakai PropBuilder untuk semua dekorasi).
static func detail(c: Color, glow := false) -> StandardMaterial3D:
	if flat:
		return _flat(c, 0.85) if not glow else _flat_glow(c)
	var hsv_h := c.h
	var woody := c.s > 0.28 and hsv_h > 0.04 and hsv_h < 0.12 and c.v < 0.8
	if woody and not glow:
		return wood(c.lerp(Color.WHITE, 0.15))
	var k := "det" + c.to_html() + ("g" if glow else "")
	if _cache.has(k):
		return _cache[k]
	var n := _noise_tex("d_n", 61, 0.2, [], true, 3.0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH)
	var d := _noise_tex("d_a", 62, 0.07, [[0.0, 1.0], [Color(0.86, 0.86, 0.86), Color(1.08, 1.08, 1.08)]])
	var m := _std(d, n, c, 0.82, 0.8, 0.6)
	if glow:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.6
	_cache[k] = m
	return m


# ------------------------------------------------------------------ cahaya & efek layar
## Efek layar modern: tonemap ACES, SSAO, glow lembut, kabut volumetrik tipis. mood: 0 siang cerah, 1 hutan teduh, 2 interior hangat.
## Kualitas grafik: 0 = rendah, 1 = sedang (DEFAULT, sedikit lebih ringan dari sebelumnya), 2 = tinggi (seperti versi awal).
## Ubah angka ini (atau lewat Dev Mode) kalau komputer terlalu berat / mau lebih cantik.
static var quality := 1
const GRASS_SCALE := [0.45, 0.72, 1.0]
const RENDER_SCALE := [0.75, 0.92, 1.0]


## Pengaturan tingkat viewport (resolusi render & anti-aliasing). Dipanggil DayCycle di tiap scene.
static func apply_quality(vp: Viewport) -> void:
	if vp == null:
		return
	vp.scaling_3d_scale = RENDER_SCALE[quality]
	vp.msaa_3d = Viewport.MSAA_2X if quality >= 1 else Viewport.MSAA_DISABLED


static func environment(env: Environment, mood := 0) -> void:
	if env == null:
		return
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.88 if mood != 2 else 0.95
	env.tonemap_white = 6.0
	env.ssao_enabled = quality >= 2
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.ssao_power = 1.6
	env.ssao_detail = 0.6
	env.ssil_enabled = mood == 2 and quality >= 2
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 0.9
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.08
	env.adjustment_brightness = 1.0
	if mood != 2:
		env.volumetric_fog_enabled = quality >= 2
		env.volumetric_fog_density = 0.006 if mood == 0 else 0.018
		env.volumetric_fog_albedo = Color(0.86, 0.92, 0.95) if mood == 0 else Color(0.62, 0.74, 0.66)
		env.volumetric_fog_length = 90.0
		env.volumetric_fog_anisotropy = 0.55
		env.fog_enabled = true
		env.fog_light_color = Color(0.72, 0.82, 0.90) if mood == 0 else Color(0.55, 0.68, 0.58)
		env.fog_density = (0.0035 if quality >= 2 else 0.0065) if mood == 0 else (0.012 if quality >= 2 else 0.016)
		env.fog_aerial_perspective = 0.5
		env.fog_sky_affect = 0.35


## Matahari lembut: bayangan halus berlapis (PSSM), warna hangat.
static func sun(l: DirectionalLight3D, energy := 1.0) -> void:
	if l == null:
		return
	l.light_color = Color(1.0, 0.95, 0.86)
	l.light_energy = energy
	l.shadow_enabled = true
	l.shadow_blur = 0.8 if quality >= 2 else 0.5
	l.light_angular_distance = 0.2
	l.shadow_bias = 0.12
	l.shadow_normal_bias = 3.5
	l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if quality >= 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	l.directional_shadow_max_distance = 90.0 if quality >= 2 else 60.0
	l.light_volumetric_fog_energy = 1.0


# ------------------------------------------------------------------ rumput 3D bergoyang
const GRASS_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform vec3 root_color : source_color = vec3(0.16, 0.30, 0.09);
uniform vec3 tip_color : source_color = vec3(0.50, 0.68, 0.22);
uniform float sway = 0.10;
varying float v_h;
varying float v_tone;
void vertex() {
	v_h = clamp(VERTEX.y / 0.5, 0.0, 1.0);
	v_tone = INSTANCE_CUSTOM.x;
	vec3 w = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float wave = sin(TIME * 1.7 + w.x * 0.8 + w.z * 0.6) + 0.5 * sin(TIME * 3.1 + w.x * 1.7);
	VERTEX.x += wave * sway * v_h * v_h;
	VERTEX.z += cos(TIME * 1.3 + w.z * 0.7) * sway * 0.5 * v_h * v_h;
	NORMAL = vec3(0.0, 1.0, 0.0);
}
void fragment() {
	vec3 c = mix(root_color, tip_color, v_h);
	c *= 0.82 + 0.36 * v_tone;
	ALBEDO = c;
	ROUGHNESS = 0.85;
	BACKLIGHT = c * 0.25;
}
"""


static func _blade_mesh() -> ArrayMesh:
	if _cache.has("blade"):
		return _cache["blade"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 3
	var hgt := 0.5
	for i in segs:
		var y0 := hgt * float(i) / segs
		var y1 := hgt * float(i + 1) / segs
		var w0 := 0.045 * (1.0 - float(i) / segs)
		var w1 := 0.045 * (1.0 - float(i + 1) / segs)
		var b0 := 0.02 * float(i * i)
		var b1 := 0.02 * float((i + 1) * (i + 1))
		var a := Vector3(-w0, y0, b0)
		var b := Vector3(w0, y0, b0)
		var c := Vector3(-w1, y1, b1)
		var d := Vector3(w1, y1, b1)
		for v in [a, b, c, b, d, c]:
			st.add_vertex(v)
	var mesh := st.commit()
	_cache["blade"] = mesh
	return mesh


## Taburkan rumput di rect. `ok` = Callable(x, z) -> bool (true = boleh tumbuh di sana).
static func grass(parent: Node, rect: Rect2, count: int, ground_y: float, seed_v: int, ok: Callable, root := Color(0.10, 0.22, 0.06), tip := Color(0.34, 0.52, 0.16)) -> MultiMeshInstance3D:
	if flat:
		return null
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var xf: Array = []
	var tones: Array = []
	count = int(count * GRASS_SCALE[quality])
	for i in count * 2:
		if xf.size() >= count:
			break
		var x := rng.randf_range(rect.position.x, rect.end.x)
		var z := rng.randf_range(rect.position.y, rect.end.y)
		if ok.is_valid() and not ok.call(x, z):
			continue
		var s := rng.randf_range(0.7, 1.6)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.4), s))
		xf.append(Transform3D(b, Vector3(x, ground_y, z)))
		tones.append(rng.randf())
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _blade_mesh()
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_custom_data(i, Color(tones[i], 0, 0, 0))
	var sh := Shader.new()
	sh.code = GRASS_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = sh
	sm.set_shader_parameter("root_color", Vector3(root.r, root.g, root.b))
	sm.set_shader_parameter("tip_color", Vector3(tip.r, tip.g, tip.b))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Tanah datar bertekstur (pengganti lawn_base). rect = Rect2(x, z, w, h).
static func ground_plane(rect: Rect2, y: float, tint := Color.WHITE) -> MeshInstance3D:
	if flat:
		return MeshInstance3D.new()                 # low-poly: tanah dari tile bawaan saja
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = rect.size
	pm.subdivide_width = 1
	pm.subdivide_depth = 1
	mi.mesh = pm
	mi.material_override = ground(tint)
	mi.position = Vector3(rect.position.x + rect.size.x * 0.5, y + 0.006, rect.position.y + rect.size.y * 0.5)
	return mi


## Daun pastel Kenney (hijau-mint) -> hijau hutan bervariasi; batang/bunga tetap berwarna aslinya, hanya sedikit lebih pekat.
const FOLIAGE_SHADER := """
shader_type spatial;
uniform sampler2D tex : source_color, filter_nearest;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec4 c = texture(tex, UV);
	float leaf = smoothstep(0.0, 0.10, c.g - c.r) * step(c.b - 0.12, c.g);
	float v = fract(sin(dot(floor(wpos.xz * 0.5), vec2(12.9898, 78.233))) * 43758.5453);
	vec3 forest = mix(vec3(0.10, 0.24, 0.07), vec3(0.20, 0.34, 0.09), v) * (0.55 + 0.9 * c.g);
	vec3 other = c.rgb * vec3(0.80, 0.74, 0.68);
	ALBEDO = mix(other, forest, leaf);
	ROUGHNESS = 0.92;
	SPECULAR = 0.15;
}
"""
static var _foliage_shader: Shader
static var _foliage_cache := {}


static func foliage(old: BaseMaterial3D) -> Material:
	if flat:
		return old
	if old == null or old.albedo_texture == null:
		return old
	var tex := old.albedo_texture
	if _foliage_cache.has(tex):
		return _foliage_cache[tex]
	if _foliage_shader == null:
		_foliage_shader = Shader.new()
		_foliage_shader.code = FOLIAGE_SHADER
	var sm := ShaderMaterial.new()
	sm.shader = _foliage_shader
	sm.set_shader_parameter("tex", tex)
	_foliage_cache[tex] = sm
	return sm


## Pasang foliage() ke semua mesh di bawah `root` (model GLB bawaan Kenney).
static func restyle_tree(root: Node) -> void:
	if flat:
		return
	if root is MeshInstance3D and root.mesh != null:
		var mi := root as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as BaseMaterial3D
			if m != null and m.albedo_texture != null:
				mi.set_surface_override_material(i, foliage(m))
	for c in root.get_children():
		restyle_tree(c)
