extends Node
## Bgm - musik latar saat bermain (looping). Otomatis mencari file bernama "Nature-Spirit Soundtrack"
## (mp3 / ogg / wav, di folder mana pun di res://). Mulai saat permainan jalan, berhenti saat kembali ke menu.
## Volume ikut bus "Music" kalau ada. Mau ganti lagu: ganti nama file jadi "Nature-Spirit Soundtrack.xxx".

const WANT := ["nature", "soundtrack"]
const EXTS := ["mp3", "ogg", "wav"]
const VOLUME_DB := -8.0
const FADE := 1.5

var _player: AudioStreamPlayer
var _tween: Tween
var _stream: AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "Music" if AudioServer.get_bus_index("Music") >= 0 else "Master"
	_player.volume_db = -60.0
	add_child(_player)
	var path := _find("res://")
	if path == "":
		push_warning("Bgm: file 'Nature-Spirit Soundtrack' tidak ditemukan di res://")
		return
	_stream = load(path)
	if _stream is AudioStreamMP3:
		_stream.loop = true
	elif _stream is AudioStreamOggVorbis:
		_stream.loop = true
	elif _stream is AudioStreamWAV:
		_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_stream.loop_end = _stream.data.size() / (4 if _stream.stereo else 2)
	_player.stream = _stream
	GameState.playing_changed.connect(_on_playing)
	if GameState.playing:
		_on_playing(true)


func _on_playing(on: bool) -> void:
	if _stream == null:
		return
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if on:
		if not _player.playing:
			_player.play()
		_tween.tween_property(_player, "volume_db", VOLUME_DB, FADE)
	else:
		_tween.tween_property(_player, "volume_db", -60.0, 0.6)
		_tween.tween_callback(_player.stop)


static func _norm(s: String) -> String:
	return s.to_lower().replace("-", " ").replace("_", " ")


func _find(dir_path: String, depth := 0) -> String:
	if depth > 4:
		return ""
	var d := DirAccess.open(dir_path)
	if d == null:
		return ""
	d.list_dir_begin()
	var subdirs: Array = []
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			if not f.begins_with(".") and f != "addons":
				subdirs.append(f)
		else:
			var name := f.trim_suffix(".import")
			if name.get_extension().to_lower() in EXTS:
				var n := _norm(name)
				var ok := true
				for w in WANT:
					if not n.contains(w):
						ok = false
				if ok:
					d.list_dir_end()
					return dir_path.path_join(name)
		f = d.get_next()
	d.list_dir_end()
	for s in subdirs:
		var r := _find(dir_path.path_join(s), depth + 1)
		if r != "":
			return r
	return ""
