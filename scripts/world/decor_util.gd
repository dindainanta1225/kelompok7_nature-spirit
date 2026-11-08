extends RefCounted
## DecorUtil - bikin dekor kecil (bunga, rumput, tanaman, jamur) bisa ditembus player.
## Item-item itu dipindah ke GridMap kedua yang tabrakannya dimatikan; pohon, batu, pagar tetap padat.

const SOFT := ["flowers", "flowers-tall", "grass", "plant", "mushrooms"]


## Return jumlah item yang dipindah.
static func make_walkable(decor: GridMap, soft_names := SOFT) -> int:
	if decor == null or decor.mesh_library == null:
		return 0
	var lib: MeshLibrary = decor.mesh_library
	var soft_ids: Array = []
	for nm in soft_names:
		var id := lib.find_item_by_name(nm)
		if id >= 0:
			soft_ids.append(id)
	if soft_ids.is_empty():
		return 0
	var lib2: MeshLibrary = lib.duplicate(true)
	for id in soft_ids:
		lib2.set_item_shapes(id, [])
	var soft := GridMap.new()
	soft.name = decor.name + "Soft"
	soft.mesh_library = lib2
	soft.cell_size = decor.cell_size
	soft.cell_center_x = decor.cell_center_x
	soft.cell_center_y = decor.cell_center_y
	soft.cell_center_z = decor.cell_center_z
	soft.cell_scale = decor.cell_scale
	soft.transform = decor.transform
	decor.get_parent().add_child.call_deferred(soft)
	var moved := 0
	for c in decor.get_used_cells():
		var it := decor.get_cell_item(c)
		if soft_ids.has(it):
			soft.set_cell_item(c, it, decor.get_cell_item_orientation(c))
			decor.set_cell_item(c, GridMap.INVALID_CELL_ITEM)
			moved += 1
	return moved
