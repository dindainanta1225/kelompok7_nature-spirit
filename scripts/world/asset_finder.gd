extends RefCounted
## AssetFinder - cari file GLB di dalam assets/ berdasarkan kata di nama file (tidak peduli huruf besar/kecil),
## supaya nama folder/ejaan file buatan sendiri tidak perlu persis sama.

static var _cache := {}


## Kembalikan path res:// file GLB pertama yang namanya mengandung SEMUA kata di `words`; "" kalau tidak ada.
static func find_glb(words: Array, root := "res://assets", exclude := []) -> String:
	var key := root + "|" + ",".join(words) + "|" + ",".join(exclude)
	if _cache.has(key):
		return _cache[key]
	var found := _search(root, words, 0, exclude)
	_cache[key] = found
	return found


static func _search(path: String, words: Array, depth: int, exclude := []) -> String:
	var d := DirAccess.open(path)
	if d == null or depth > 5:
		return ""
	var files := d.get_files()
	files.sort()
	for f in files:
		var n := f.trim_suffix(".remap").trim_suffix(".import")
		if n.get_extension().to_lower() != "glb":
			continue
		var l := n.to_lower()
		var ok := true
		for ex in exclude:
			if l.ends_with(String(ex).to_lower()):
				ok = false
		for w in words:
			if not l.contains(String(w).to_lower()):
				ok = false
		if ok:
			return path.path_join(n)
	var dirs := d.get_directories()
	dirs.sort()
	for sub in dirs:
		var r := _search(path.path_join(sub), words, depth + 1, exclude)
		if r != "":
			return r
	return ""
