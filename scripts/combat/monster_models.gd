extends RefCounted
## MonsterModels - mencari model monster buatan sendiri (GLB) di folder "Char and Cre..." di dalam assets/
## (nama folder dicocokkan tanpa peduli huruf besar/kecil: harus mengandung "char" dan "cre").
## Cara cocok file -> monster: dari kata di nama file (slime/boar/wolf/goblin dan sinonimnya); (imp/bear/werewolf/goblin/skeleton).
## Ubah KEYWORDS / OVERRIDE di bawah kalau nama file kamu lain.

const ROOT := "res://assets"
const KINDS := ["slime", "boar", "wolf", "goblin", "skeleton", "hunter"]
const KEYWORDS := {
	"slime": ["imp", "slime", "jelly", "blob"],
	"boar": ["bear", "boar", "pig", "hog"],
	"wolf": ["werewolf", "wolf"],
	"goblin": ["goblin"],
	"skeleton": ["skeleton", "skull"],
	"hunter": ["hunter"],
}
## Isi kalau mau menentukan manual, contoh: {"slime": "res://assets/Char and Cre/imp_character.glb"}
const OVERRIDE := {}
## Tinggi model di dunia (m), jari-jari tabrakan, dan putaran tambahan (derajat) kalau modelnya menghadap arah lain
## (0 = menghadap +Z). Imp kecil, beruang & manusia serigala besar.
const HEIGHT := {"slime": 1.0, "boar": 1.55, "wolf": 2.1, "goblin": 1.15, "skeleton": 1.8, "hunter": 1.95}
const RADIUS := {"slime": 0.38, "boar": 0.8, "wolf": 0.55, "goblin": 0.4, "skeleton": 0.42, "hunter": 0.5}
const YAW := {"slime": 0.0, "boar": 90.0, "wolf": 0.0, "goblin": 90.0, "skeleton": 0.0, "hunter": 0.0}

static var _map := {}
static var _ready_scan := false


static func path_for(kind: String) -> String:
	if not _ready_scan:
		_scan()
	return String(_map.get(kind, ""))


static func _scan() -> void:
	_ready_scan = true
	for k in OVERRIDE:
		_map[k] = OVERRIDE[k]
	var files: Array = []
	_collect(ROOT, files)                       # cari di SEMUA folder assets (nama folder tidak penting)
	files.sort()
	for k in KINDS:
		if _map.has(k):
			continue
		var best := ""
		for f in files:
			var tokens := _tokens(String(f).get_file())
			for w in KEYWORDS[k]:
				if tokens.has(w):                # cocok per KATA di nama file (imp_character -> "imp"), bukan potongan huruf
					if best == "" or String(f).to_lower().contains("char") and String(f).to_lower().contains("cre"):
						best = f
					break
		if best != "":
			_map[k] = best


static func _tokens(file: String) -> PackedStringArray:
	var n := file.get_basename().to_lower()
	for c in ["-", ".", " ", "(", ")"]:
		n = n.replace(c, "_")
	return n.split("_", false)


static func _collect(path: String, out: Array) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		var n := f.trim_suffix(".remap").trim_suffix(".import")
		if n.get_extension().to_lower() in ["glb", "gltf"]:
			var full := path.path_join(n)
			if not out.has(full):
				out.append(full)
	for sub in d.get_directories():
		_collect(path.path_join(sub), out)
