extends RefCounted
## ForestState - mencatat monster hutan yang sudah dikalahkan hari ini (supaya tidak muncul lagi kalau
## pemain keluar-masuk hutan). Monster baru muncul tiap pagi (hari berganti) dan tiap game baru.
## Disimpan di memori selama game berjalan.

static var _killed := {}
static var _coins := {}
static var _stamp := -1
static var _saved := {}


static func _key(forest_id: int, day: int) -> String:
	return "%d:%d" % [forest_id, day]


static func _sync() -> void:
	var st: int = int(GameState.get("run_stamp"))
	if st != _stamp:
		_stamp = st
		_killed.clear()
		_coins.clear()
		_saved.clear()


static func is_killed(forest_id: int, day: int, idx: int) -> bool:
	_sync()
	return (_killed.get(_key(forest_id, day), []) as Array).has(idx)


static func mark_killed(forest_id: int, day: int, idx: int) -> void:
	_sync()
	var k := _key(forest_id, day)
	if not _killed.has(k):
		_killed[k] = []
	(_killed[k] as Array).append(idx)


static func is_coin_taken(forest_id: int, day: int, idx: int) -> bool:
	_sync()
	return (_coins.get(_key(forest_id, day), []) as Array).has(idx)


static func mark_coin(forest_id: int, day: int, idx: int) -> void:
	_sync()
	var k := _key(forest_id, day)
	if not _coins.has(k):
		_coins[k] = []
	(_coins[k] as Array).append(idx)


## Posisi & HP monster yang masih hidup saat pemain meninggalkan hutan (dipulihkan kalau masuk lagi di hari yang sama).
static func save_monster(forest_id: int, day: int, idx: int, pos: Vector3, hp: int) -> void:
	_sync()
	_saved["%s:%d" % [_key(forest_id, day), idx]] = {"pos": pos, "hp": hp}


static func saved_monster(forest_id: int, day: int, idx: int) -> Dictionary:
	_sync()
	return _saved.get("%s:%d" % [_key(forest_id, day), idx], {})
