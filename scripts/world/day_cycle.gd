extends Node
const Sfx := preload("res://scripts/audio/sfx.gd")
## DayCycle - siklus Pagi / Siang / Sore / Malam: cahaya matahari/bulan, warna langit, bayangan & kabut mengikuti jam game.
##   Pagi 06:00-10:59 | Siang 11:00-14:59 | Sore 15:00-18:59 | Malam 19:00-05:59
## Pasang di tiap scene dunia:  DayCycle.attach(self, env, sun)  (interior: interior = true -> hanya cahaya jendela yang berubah).

const Realism := preload("res://scripts/world/realism.gd")
const KEYS := [
	# jam, tinggi matahari (derajat), warna matahari, kekuatan (x dasar), langit atas, langit horizon, ambient (x dasar), kabut (x terang)
	[0.0, 28.0, Color(0.50, 0.62, 1.00), 0.34, Color(0.05, 0.08, 0.20), Color(0.12, 0.16, 0.32), 0.90, 0.30],
	[5.0, 28.0, Color(0.50, 0.62, 1.00), 0.34, Color(0.05, 0.08, 0.20), Color(0.12, 0.16, 0.32), 0.90, 0.30],
	[6.2, 9.0, Color(1.00, 0.62, 0.40), 0.50, Color(0.25, 0.34, 0.60), Color(0.95, 0.60, 0.44), 0.65, 0.60],
	[8.5, 34.0, Color(1.00, 0.92, 0.78), 0.85, Color(0.34, 0.54, 0.86), Color(0.80, 0.88, 0.94), 0.95, 0.90],
	[12.5, 62.0, Color(1.00, 0.97, 0.90), 1.00, Color(0.27, 0.49, 0.85), Color(0.72, 0.82, 0.92), 1.00, 1.00],
	[15.5, 40.0, Color(1.00, 0.90, 0.74), 0.88, Color(0.30, 0.48, 0.80), Color(0.86, 0.80, 0.70), 0.92, 0.92],
	[17.8, 12.0, Color(1.00, 0.55, 0.28), 0.62, Color(0.32, 0.30, 0.58), Color(1.00, 0.52, 0.28), 0.72, 0.70],
	[19.3, 4.0, Color(0.75, 0.42, 0.55), 0.30, Color(0.10, 0.10, 0.28), Color(0.50, 0.28, 0.38), 0.65, 0.40],
	[21.0, 28.0, Color(0.50, 0.62, 1.00), 0.34, Color(0.05, 0.08, 0.20), Color(0.12, 0.16, 0.32), 0.90, 0.30],
	[24.0, 28.0, Color(0.50, 0.62, 1.00), 0.34, Color(0.05, 0.08, 0.20), Color(0.12, 0.16, 0.32), 0.90, 0.30],
]

var env: Environment
var sun: DirectionalLight3D
var interior := false
var _sun_energy := 1.0
var _amb_energy := 1.0
var _fog_light := Color.WHITE
var _vfog_albedo := Color.WHITE
var _azimuth := -35.0
var _acc := 1.0


static func attach(parent: Node, e: Environment, s: DirectionalLight3D, is_interior := false) -> void:
	var d = load("res://scripts/world/day_cycle.gd").new()
	d.env = e
	d.sun = s
	d.interior = is_interior
	parent.add_child(d)


static func phase_name(hour: int) -> String:
	if hour >= 19 or hour < 6:
		return "Night"
	if hour < 11:
		return "Morning"
	if hour < 15:
		return "Noon"
	return "Evening"


func _ready() -> void:
	Realism.apply_quality(get_viewport())
	if sun != null:
		_sun_energy = sun.light_energy
		_azimuth = sun.rotation_degrees.y
	if env != null:
		_amb_energy = env.ambient_light_energy
		_fog_light = env.fog_light_color
		_vfog_albedo = env.volumetric_fog_albedo
	_apply()


func _process(delta: float) -> void:
	_acc += delta
	if _acc >= 0.25:
		_acc = 0.0
		_apply()


static func _sample(h: float) -> Array:
	h = fposmod(h, 24.0)
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if h >= a[0] and h <= b[0]:
			var k := (h - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
			k = k * k * (3.0 - 2.0 * k)
			return [lerpf(a[1], b[1], k), (a[2] as Color).lerp(b[2], k), lerpf(a[3], b[3], k), (a[4] as Color).lerp(b[4], k),
				(a[5] as Color).lerp(b[5], k), lerpf(a[6], b[6], k), lerpf(a[7], b[7], k)]
	return KEYS[0].slice(1)


func _apply() -> void:
	Sfx.ambient(phase_name(GameState.hour()), interior)
	var v := _sample(GameState.clock / 60.0)
	if sun != null:
		sun.rotation_degrees = Vector3(-float(v[0]), _azimuth, 0.0)
		sun.light_color = v[1]
		sun.light_energy = _sun_energy * float(v[2])
	if env == null or interior:
		return
	var sky_mat: Material = null
	if env.sky != null:
		sky_mat = env.sky.sky_material
	if sky_mat is ProceduralSkyMaterial:
		var m := sky_mat as ProceduralSkyMaterial
		m.sky_top_color = v[3]
		m.sky_horizon_color = v[4]
		m.ground_horizon_color = (v[4] as Color).darkened(0.25)
		m.ground_bottom_color = (v[3] as Color).darkened(0.4)
		m.sun_angle_max = 30.0
	env.ambient_light_energy = _amb_energy * float(v[5])
	var br := float(v[6])
	env.fog_light_color = _fog_light * Color(br, br, br).lerp(Color(1, 1, 1), 0.1) if env.fog_enabled else env.fog_light_color
	env.volumetric_fog_albedo = _vfog_albedo * Color(br, br, br).lerp(Color(1, 1, 1), 0.1)
