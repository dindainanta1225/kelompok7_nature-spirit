extends Node
## Sfx - efek suara game. SEMUA suara dibuat lewat kode (sintesis), jadi tidak perlu file audio tambahan.
## Dibuat otomatis oleh GameState (tidak perlu autoload baru). Pakai dari script mana pun:
##     const Sfx := preload("res://scripts/audio/sfx.gd")
##     Sfx.play("coin")                    # nama suara (lihat daftar SOUNDS di bawah)
##     Sfx.play("hit", -3.0, 1.1)          # volume dB, pitch
##     Sfx.play_at("cluck", global_position, 12.0)   # suara hewan: hanya terdengar kalau player dekat
##     Sfx.ambient("Morning", false)       # suara latar (burung / jangkrik / angin) -> dipanggil DayCycle
## Mau ganti suara dengan file sendiri: taruh .ogg/.wav bernama sama (mis. "coin.ogg") di res://audio/sfx_custom/.

const RATE := 22050
const CUSTOM_DIR := "res://audio/sfx_custom/"

static var _inst: Node

var _cache := {}
var _pool: Array = []
var _amb: Array = []                 # dua pemutar untuk crossfade suara latar
var _amb_kind := ""
var _amb_tween: Tween
var _steps := 0.0
var master_on := true


func _ready() -> void:
	_inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bus := "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	for i in 12:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_pool.append(p)
	for i in 2:
		var a := AudioStreamPlayer.new()
		a.bus = bus
		a.volume_db = -80.0
		add_child(a)
		_amb.append(a)


static func play(sound: String, vol_db := 0.0, pitch := 1.0) -> void:
	if _inst != null:
		_inst._play(sound, vol_db, pitch)


## Suara 3D sederhana: makin jauh dari player makin pelan; di luar `radius` tidak diputar.
static func play_at(sound: String, pos: Vector3, radius := 14.0, vol_db := 0.0, pitch := 1.0) -> void:
	if _inst == null:
		return
	var pl := _inst.get_tree().get_first_node_in_group("player") as Node3D
	if pl == null:
		return
	var d := pl.global_position.distance_to(pos)
	if d > radius:
		return
	_inst._play(sound, vol_db - 14.0 * (d / radius), pitch)


static func ambient(phase: String, interior := false) -> void:
	if _inst != null:
		_inst._set_ambient("home" if interior else phase)


## Langkah kaki (dipanggil player saat berjalan).
static func step(running := false) -> void:
	if _inst != null:
		_inst._play("step", -9.0, randf_range(0.85, 1.2))


func _play(sound: String, vol_db: float, pitch: float) -> void:
	if not master_on:
		return
	var s := _stream_for(sound)
	if s == null:
		return
	var best: AudioStreamPlayer = null
	for p in _pool:
		if not p.playing:
			best = p
			break
	if best == null:
		best = _pool[0]
	best.stream = s
	best.volume_db = vol_db
	best.pitch_scale = pitch * randf_range(0.97, 1.03)
	best.play()


func _stream_for(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var s: AudioStream = null
	for ext in ["ogg", "wav", "mp3"]:                      # file buatan sendiri menimpa suara sintesis
		var path := "%s%s.%s" % [CUSTOM_DIR, sound, ext]
		if ResourceLoader.exists(path):
			s = load(path)
			break
	if s == null and SOUNDS.has(sound):
		var def: Dictionary = SOUNDS[sound]
		s = _render(def["layers"], float(def["len"]), bool(def.get("loop", false)))
	_cache[sound] = s
	return s


# ------------------------------------------------------------------ suara latar
func _set_ambient(phase: String) -> void:
	var kind := "wind"
	match phase:
		"Morning", "Noon", "Evening":
			kind = "day"
		"Night":
			kind = "night"
		"home":
			kind = "home"
	if kind == _amb_kind:
		return
	_amb_kind = kind
	var next: AudioStreamPlayer = _amb[1] if _amb[0].playing and _amb[0].volume_db > -60.0 else _amb[0]
	var prev: AudioStreamPlayer = _amb[0] if next == _amb[1] else _amb[1]
	var stream := _stream_for("amb_" + kind)
	if stream == null:
		return
	next.stream = stream
	next.volume_db = -80.0
	next.play()
	if _amb_tween and _amb_tween.is_valid():
		_amb_tween.kill()
	_amb_tween = create_tween().set_parallel(true)
	_amb_tween.tween_property(next, "volume_db", -22.0 if kind != "home" else -30.0, 2.5)
	_amb_tween.tween_property(prev, "volume_db", -80.0, 2.5)
	_amb_tween.chain().tween_callback(prev.stop)


# ------------------------------------------------------------------ sintesis
## Satu lapisan = {w: sine|tri|square|saw|noise, f0, f1, t0, d, v, a (attack), p (pangkat peluruhan), lp (noise 0..1), vib:[hz, dalam], am:[hz, dalam]}
func _render(layers: Array, total: float, loop := false) -> AudioStreamWAV:
	var n := int(total * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for L in layers:
		var w: String = L.get("w", "sine")
		var f0: float = L.get("f0", 440.0)
		var f1: float = L.get("f1", f0)
		var s0 := int(float(L.get("t0", 0.0)) * RATE)
		var nn := int(float(L["d"]) * RATE)
		var v: float = L.get("v", 0.5)
		var atk: float = maxf(float(L.get("a", 0.005)), 0.0005) * RATE
		var pw: float = L.get("p", 2.0)
		var lp: float = L.get("lp", 1.0)
		var vib: Array = L.get("vib", [])
		var am: Array = L.get("am", [])
		var ph := 0.0
		var lpv := 0.0
		for i in nn:
			var idx := s0 + i
			if idx >= n:
				break
			var k := float(i) / float(nn)
			var f := lerpf(f0, f1, k)
			if not vib.is_empty():
				f *= 1.0 + float(vib[1]) * sin(TAU * float(vib[0]) * float(i) / RATE)
			ph += f / RATE
			var x := 0.0
			match w:
				"sine":
					x = sin(TAU * ph)
				"tri":
					x = 4.0 * absf(fposmod(ph, 1.0) - 0.5) - 1.0
				"square":
					x = 1.0 if fposmod(ph, 1.0) < 0.5 else -1.0
				"saw":
					x = 2.0 * fposmod(ph, 1.0) - 1.0
				_:
					x = rng.randf_range(-1.0, 1.0)
			if lp < 1.0:
				lpv += (x - lpv) * lp
				x = lpv
			var env := minf(1.0, float(i) / atk) * pow(1.0 - k, pw)
			if not am.is_empty():
				env *= 1.0 - float(am[1]) * (0.5 + 0.5 * sin(TAU * float(am[0]) * float(i) / RATE))
			buf[idx] += x * env * v
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var s := int(clampf(buf[i], -1.0, 1.0) * 32000.0)
		data.encode_s16(i * 2, s)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = n
	return wav


static func _note(f: float, t0: float, d: float, v := 0.35, w := "tri") -> Dictionary:
	return {"w": w, "f0": f, "t0": t0, "d": d, "v": v, "p": 2.2, "a": 0.004}


static func _chirps(count: int, seed_v: int, lo: float, hi: float, total: float, v: float) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var out: Array = []
	for i in count:
		var t0 := r.randf() * (total - 0.5)
		var f := r.randf_range(lo, hi)
		var n := r.randi_range(1, 4)
		for j in n:
			out.append({"w": "sine", "f0": f * r.randf_range(0.9, 1.15), "f1": f * r.randf_range(1.1, 1.5), "t0": t0 + j * 0.09, "d": 0.07, "v": v, "p": 1.4, "a": 0.004})
	return out


# ------------------------------------------------------------------ daftar suara
static var SOUNDS := {
	# --- UI
	"click": {"len": 0.08, "layers": [{"w": "sine", "f0": 900.0, "f1": 640.0, "d": 0.07, "v": 0.35, "p": 2.0}]},
	"open": {"len": 0.22, "layers": [{"w": "noise", "d": 0.2, "v": 0.18, "lp": 0.25, "a": 0.08, "p": 1.2}, {"w": "sine", "f0": 380.0, "f1": 620.0, "d": 0.18, "v": 0.2, "p": 1.5}]},
	"close": {"len": 0.2, "layers": [{"w": "noise", "d": 0.18, "v": 0.16, "lp": 0.2, "a": 0.02, "p": 1.8}, {"w": "sine", "f0": 600.0, "f1": 330.0, "d": 0.16, "v": 0.2, "p": 1.5}]},
	"toast": {"len": 0.35, "layers": [{"w": "sine", "f0": 880.0, "d": 0.14, "v": 0.22, "p": 2.0}, {"w": "sine", "f0": 1320.0, "t0": 0.08, "d": 0.24, "v": 0.2, "p": 2.0}]},
	"select": {"len": 0.12, "layers": [{"w": "tri", "f0": 660.0, "f1": 990.0, "d": 0.1, "v": 0.3, "p": 1.6}]},
	"error": {"len": 0.28, "layers": [{"w": "square", "f0": 170.0, "f1": 120.0, "d": 0.24, "v": 0.22, "p": 1.2, "lp": 0.35}]},
	"blip": {"len": 0.04, "layers": [{"w": "square", "f0": 520.0, "f1": 480.0, "d": 0.035, "v": 0.09, "p": 1.5, "lp": 0.4}]},
	"hotbar": {"len": 0.06, "layers": [{"w": "sine", "f0": 1100.0, "d": 0.05, "v": 0.18, "p": 2.0}]},
	# --- uang
	"coin": {"len": 0.4, "layers": [{"w": "square", "f0": 988.0, "d": 0.07, "v": 0.18, "p": 0.6, "lp": 0.5}, {"w": "square", "f0": 1319.0, "t0": 0.07, "d": 0.3, "v": 0.18, "p": 1.8, "lp": 0.5}]},
	"coins_big": {"len": 0.8, "layers": [_note(784.0, 0.0, 0.1, 0.25, "square"), _note(988.0, 0.07, 0.1, 0.25, "square"), _note(1175.0, 0.14, 0.1, 0.25, "square"), _note(1568.0, 0.21, 0.5, 0.25, "square"), {"w": "noise", "t0": 0.0, "d": 0.5, "v": 0.05, "lp": 0.9, "p": 3.0}]},
	"buy": {"len": 0.5, "layers": [{"w": "noise", "d": 0.05, "v": 0.3, "lp": 0.7, "p": 3.0}, {"w": "sine", "f0": 1760.0, "t0": 0.06, "d": 0.4, "v": 0.2, "p": 2.6}, {"w": "sine", "f0": 2349.0, "t0": 0.06, "d": 0.4, "v": 0.1, "p": 3.0}]},
	"sell": {"len": 0.45, "layers": [{"w": "sine", "f0": 1318.0, "d": 0.12, "v": 0.22, "p": 1.6}, {"w": "sine", "f0": 1760.0, "t0": 0.1, "d": 0.34, "v": 0.22, "p": 2.0}]},
	# --- bertani
	"hoe": {"len": 0.35, "layers": [{"w": "noise", "d": 0.25, "v": 0.45, "lp": 0.18, "p": 2.5}, {"w": "sine", "f0": 110.0, "f1": 50.0, "d": 0.22, "v": 0.5, "p": 2.0}]},
	"water": {"len": 0.7, "layers": [{"w": "noise", "d": 0.65, "v": 0.22, "lp": 0.45, "a": 0.08, "p": 1.0, "am": [18.0, 0.5]}]},
	"scythe": {"len": 0.3, "layers": [{"w": "noise", "d": 0.26, "v": 0.3, "lp": 0.6, "a": 0.08, "p": 1.6}, {"w": "noise", "t0": 0.14, "d": 0.12, "v": 0.18, "lp": 0.9, "p": 2.0}]},
	"plant": {"len": 0.3, "layers": [{"w": "sine", "f0": 300.0, "f1": 520.0, "d": 0.12, "v": 0.3, "p": 1.8}, {"w": "noise", "t0": 0.05, "d": 0.18, "v": 0.14, "lp": 0.3, "p": 2.0}]},
	"harvest": {"len": 0.4, "layers": [{"w": "noise", "d": 0.12, "v": 0.3, "lp": 0.5, "p": 2.0}, {"w": "sine", "f0": 440.0, "f1": 880.0, "t0": 0.08, "d": 0.25, "v": 0.3, "p": 1.8}, {"w": "sine", "f0": 1320.0, "t0": 0.18, "d": 0.2, "v": 0.15, "p": 2.0}]},
	"eat": {"len": 0.6, "layers": [{"w": "noise", "d": 0.07, "v": 0.5, "lp": 0.4, "p": 2.0}, {"w": "noise", "t0": 0.16, "d": 0.07, "v": 0.45, "lp": 0.4, "p": 2.0}, {"w": "noise", "t0": 0.32, "d": 0.07, "v": 0.4, "lp": 0.4, "p": 2.0}, {"w": "sine", "f0": 520.0, "f1": 740.0, "t0": 0.44, "d": 0.14, "v": 0.18, "p": 2.0}]},
	"step": {"len": 0.08, "layers": [{"w": "noise", "d": 0.07, "v": 0.22, "lp": 0.16, "p": 2.0}]},
	"pickup": {"len": 0.2, "layers": [{"w": "sine", "f0": 520.0, "f1": 980.0, "d": 0.16, "v": 0.3, "p": 1.8}]},
	# --- pertarungan
	"swing": {"len": 0.28, "layers": [{"w": "noise", "d": 0.24, "v": 0.38, "lp": 0.7, "a": 0.1, "p": 1.4}, {"w": "sine", "f0": 700.0, "f1": 300.0, "d": 0.2, "v": 0.08, "p": 1.5}]},
	"hit": {"len": 0.25, "layers": [{"w": "noise", "d": 0.1, "v": 0.5, "lp": 0.5, "p": 2.5}, {"w": "sine", "f0": 190.0, "f1": 70.0, "d": 0.2, "v": 0.55, "p": 1.8}]},
	"crit": {"len": 0.35, "layers": [{"w": "noise", "d": 0.12, "v": 0.4, "lp": 0.8, "p": 2.0}, {"w": "sine", "f0": 240.0, "f1": 60.0, "d": 0.25, "v": 0.45, "p": 1.8}, {"w": "sine", "f0": 1400.0, "f1": 900.0, "d": 0.2, "v": 0.2, "p": 2.0}]},
	"monster_hurt": {"len": 0.25, "layers": [{"w": "saw", "f0": 340.0, "f1": 150.0, "d": 0.22, "v": 0.22, "p": 1.4, "lp": 0.3}]},
	"monster_die": {"len": 0.7, "layers": [{"w": "saw", "f0": 300.0, "f1": 60.0, "d": 0.6, "v": 0.25, "p": 1.2, "lp": 0.25, "vib": [14.0, 0.06]}, {"w": "noise", "t0": 0.35, "d": 0.2, "v": 0.2, "lp": 0.2, "p": 2.0}]},
	"monster_attack": {"len": 0.3, "layers": [{"w": "saw", "f0": 200.0, "f1": 420.0, "d": 0.18, "v": 0.2, "p": 1.0, "lp": 0.3}, {"w": "noise", "t0": 0.1, "d": 0.14, "v": 0.2, "lp": 0.5, "p": 1.6}]},
	"monster_growl": {"len": 0.7, "layers": [{"w": "saw", "f0": 90.0, "f1": 70.0, "d": 0.65, "v": 0.3, "p": 1.0, "lp": 0.12, "vib": [28.0, 0.12], "a": 0.12}]},
	"slime": {"len": 0.25, "layers": [{"w": "sine", "f0": 180.0, "f1": 520.0, "d": 0.2, "v": 0.35, "p": 1.4, "vib": [30.0, 0.05]}]},
	"player_hurt": {"len": 0.4, "layers": [{"w": "noise", "d": 0.1, "v": 0.4, "lp": 0.4, "p": 2.2}, {"w": "tri", "f0": 330.0, "f1": 130.0, "d": 0.32, "v": 0.4, "p": 1.4}]},
	# --- dunia
	"door": {"len": 0.5, "layers": [{"w": "saw", "f0": 120.0, "f1": 200.0, "d": 0.3, "v": 0.12, "p": 1.0, "lp": 0.1, "a": 0.05}, {"w": "noise", "t0": 0.3, "d": 0.12, "v": 0.4, "lp": 0.2, "p": 2.5}]},
	"chest": {"len": 0.7, "layers": [{"w": "saw", "f0": 90.0, "f1": 170.0, "d": 0.3, "v": 0.14, "p": 1.0, "lp": 0.1, "a": 0.05}, _note(1568.0, 0.3, 0.3, 0.2, "sine"), _note(2093.0, 0.38, 0.3, 0.18, "sine")]},
	"bed": {"len": 0.6, "layers": [{"w": "noise", "d": 0.3, "v": 0.2, "lp": 0.1, "a": 0.1, "p": 1.5}, _note(392.0, 0.15, 0.4, 0.15, "sine")]},
	"sleep": {"len": 2.4, "layers": [_note(523.0, 0.0, 0.8, 0.22, "sine"), _note(392.0, 0.5, 0.8, 0.22, "sine"), _note(330.0, 1.0, 0.8, 0.22, "sine"), _note(262.0, 1.5, 0.9, 0.22, "sine")]},
	"morning": {"len": 2.2, "layers": [_note(523.0, 0.0, 0.6, 0.22, "sine"), _note(659.0, 0.25, 0.6, 0.22, "sine"), _note(784.0, 0.5, 0.7, 0.22, "sine"), _note(1047.0, 0.8, 1.2, 0.22, "sine"), {"w": "sine", "f0": 2093.0, "t0": 0.8, "d": 1.2, "v": 0.07, "p": 3.0}]},
	"faint": {"len": 1.2, "layers": [{"w": "tri", "f0": 400.0, "f1": 70.0, "d": 1.0, "v": 0.35, "p": 1.0, "vib": [9.0, 0.05]}, {"w": "noise", "t0": 0.9, "d": 0.2, "v": 0.4, "lp": 0.12, "p": 2.0}]},
	"quest": {"len": 1.1, "layers": [_note(523.0, 0.0, 0.18, 0.3, "square"), _note(659.0, 0.12, 0.18, 0.3, "square"), _note(784.0, 0.24, 0.18, 0.3, "square"), _note(1047.0, 0.36, 0.6, 0.3, "square")]},
	"upgrade": {"len": 0.9, "layers": [_note(440.0, 0.0, 0.14, 0.3), _note(554.0, 0.1, 0.14, 0.3), _note(659.0, 0.2, 0.14, 0.3), _note(880.0, 0.3, 0.55, 0.3)]},
	"npc_hi": {"len": 0.2, "layers": [{"w": "sine", "f0": 520.0, "f1": 780.0, "d": 0.15, "v": 0.2, "p": 1.6}]},
	"whoosh": {"len": 0.9, "layers": [{"w": "noise", "d": 0.85, "v": 0.3, "lp": 0.3, "a": 0.4, "p": 1.2}]},
	"stinger": {"len": 1.6, "layers": [{"w": "saw", "f0": 110.0, "d": 1.5, "v": 0.18, "p": 1.2, "lp": 0.1, "a": 0.2}, _note(220.0, 0.0, 1.4, 0.2, "sine"), _note(329.0, 0.3, 1.2, 0.18, "sine")]},
	# --- ending
	"ending_good": {"len": 4.2, "layers": [_note(523.0, 0.0, 0.3, 0.3), _note(659.0, 0.25, 0.3, 0.3), _note(784.0, 0.5, 0.3, 0.3), _note(1047.0, 0.75, 0.9, 0.3), _note(784.0, 1.7, 0.3, 0.3), _note(880.0, 1.95, 0.3, 0.3), _note(1047.0, 2.2, 0.3, 0.3), _note(1319.0, 2.45, 1.6, 0.3), {"w": "sine", "f0": 262.0, "t0": 0.75, "d": 3.2, "v": 0.12, "p": 1.0}]},
	"ending_bad": {"len": 4.0, "layers": [_note(392.0, 0.0, 0.8, 0.3, "sine"), _note(370.0, 0.7, 0.8, 0.3, "sine"), _note(330.0, 1.4, 0.8, 0.3, "sine"), _note(262.0, 2.1, 1.8, 0.3, "sine"), {"w": "sine", "f0": 131.0, "t0": 0.0, "d": 3.8, "v": 0.14, "p": 0.8}]},
	"firework": {"len": 1.1, "layers": [{"w": "sine", "f0": 300.0, "f1": 900.0, "d": 0.4, "v": 0.12, "p": 1.0}, {"w": "noise", "t0": 0.4, "d": 0.6, "v": 0.4, "lp": 0.3, "p": 2.2}]},
	"cheer": {"len": 1.4, "layers": [{"w": "noise", "d": 1.3, "v": 0.2, "lp": 0.28, "a": 0.2, "p": 1.2, "am": [7.0, 0.4]}]},
	# --- hewan
	"cluck": {"len": 0.3, "layers": [{"w": "square", "f0": 520.0, "f1": 380.0, "d": 0.06, "v": 0.16, "p": 1.2, "lp": 0.3}, {"w": "square", "f0": 600.0, "f1": 420.0, "t0": 0.1, "d": 0.07, "v": 0.16, "p": 1.2, "lp": 0.3}, {"w": "square", "f0": 560.0, "f1": 400.0, "t0": 0.2, "d": 0.06, "v": 0.14, "p": 1.2, "lp": 0.3}]},
	"baa": {"len": 0.8, "layers": [{"w": "saw", "f0": 330.0, "f1": 280.0, "d": 0.7, "v": 0.22, "p": 0.9, "lp": 0.2, "vib": [28.0, 0.08], "a": 0.06}]},
	"neigh": {"len": 1.0, "layers": [{"w": "saw", "f0": 520.0, "f1": 640.0, "d": 0.25, "v": 0.2, "p": 0.6, "lp": 0.25, "vib": [20.0, 0.07]}, {"w": "saw", "f0": 640.0, "f1": 260.0, "t0": 0.25, "d": 0.7, "v": 0.2, "p": 1.2, "lp": 0.22, "vib": [22.0, 0.08]}]},
	# --- suara latar (loop)
	"amb_day": {"len": 6.0, "loop": true, "layers": _chirps(9, 11, 2400.0, 3600.0, 6.0, 0.045) + [{"w": "noise", "d": 6.0, "v": 0.035, "lp": 0.05, "p": 0.0}]},
	"amb_night": {"len": 4.0, "loop": true, "layers": [{"w": "sine", "f0": 4300.0, "d": 4.0, "v": 0.035, "p": 0.0, "am": [22.0, 0.95]}, {"w": "sine", "f0": 3900.0, "d": 4.0, "v": 0.03, "p": 0.0, "am": [17.0, 0.95]}, {"w": "noise", "d": 4.0, "v": 0.03, "lp": 0.03, "p": 0.0}]},
	"amb_wind": {"len": 5.0, "loop": true, "layers": [{"w": "noise", "d": 5.0, "v": 0.08, "lp": 0.04, "p": 0.0, "am": [0.35, 0.5]}]},
	"amb_home": {"len": 4.0, "loop": true, "layers": [{"w": "noise", "d": 4.0, "v": 0.03, "lp": 0.02, "p": 0.0}, {"w": "sine", "f0": 60.0, "d": 4.0, "v": 0.03, "p": 0.0}]},
}
