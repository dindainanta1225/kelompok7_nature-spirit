extends Node
## SwaySystem - bunga, rumput, tanaman, dan jamur bergetar/bergoyang saat player melewatinya.
## Dipasang oleh Player. Benda dicari dari nama node (flowers, grass, plant, mushrooms, bush, cactus ...).

const WORDS := ["flower", "grass", "plant", "mushroom", "bush", "cactus", "sprout", "wheat", "reed", "fern"]
const RADIUS := 1.1
const LEAN := 0.32                 # kemiringan awal (radian) menjauhi player
const WOBBLE := 0.16
const FREQ := 15.0
const DECAY := 3.2

var _items: Array = []             # {n, p (xz), base (Basis)}
var _state := {}                   # Node3D -> {t, dir}
var _scan_in := 1.2


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE


func _match(n: Node) -> bool:
	if not (n is Node3D):
		return false
	var nm := String(n.name).to_lower()
	for w in WORDS:
		if nm.contains(w):
			return true
	return false


func _scan() -> void:
	_items.clear()
	var root := get_tree().current_scene
	if root == null:
		return
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n != root and n is Node3D and not (n is CharacterBody3D) and not n.is_in_group("npc") and _match(n):
			var n3 := n as Node3D
			if not n3.has_meta("sway_base"):
				n3.set_meta("sway_base", n3.transform.basis)
			_items.append({"n": n3, "p": Vector2(n3.global_position.x, n3.global_position.z), "base": n3.get_meta("sway_base")})
			continue                                   # tidak turun ke anak-anaknya
		for c in n.get_children():
			stack.append(c)


func _process(delta: float) -> void:
	_scan_in -= delta
	if _scan_in <= 0.0:
		_scan_in = 8.0
		_scan()
	var pl := get_parent() as CharacterBody3D
	if pl == null:
		return
	var pp := Vector2(pl.global_position.x, pl.global_position.z)
	var moving := Vector2(pl.velocity.x, pl.velocity.z).length() > 0.4
	if moving:
		for it in _items:
			var n: Node3D = it["n"]
			if not is_instance_valid(n):
				continue
			var d: float = (it["p"] as Vector2).distance_to(pp)
			if d < RADIUS:
				var away: Vector2 = ((it["p"] as Vector2) - pp)
				if away.length() < 0.01:
					away = Vector2(randf() - 0.5, randf() - 0.5)
				var st: Dictionary = _state.get(n, {})
				if st.is_empty() or float(st["t"]) > 0.25:            # picu ulang kalau goyangan sebelumnya sudah mereda
					_state[n] = {"t": 0.0, "dir": away.normalized()}
	var done := []
	for n in _state:
		if not is_instance_valid(n):
			done.append(n)
			continue
		var st: Dictionary = _state[n]
		st["t"] = float(st["t"]) + delta
		var t: float = st["t"]
		var amp := exp(-DECAY * t)
		var dir: Vector2 = st["dir"]
		var axis := Vector3(dir.y, 0.0, -dir.x).normalized()     # sumbu tegak lurus arah dorongan
		var ang := amp * (LEAN * exp(-5.0 * t) + WOBBLE * sin(FREQ * t))
		var base: Basis = (n as Node3D).get_meta("sway_base") if (n as Node3D).has_meta("sway_base") else Basis.IDENTITY
		(n as Node3D).transform.basis = Basis(axis, ang) * base
		if amp < 0.03:
			(n as Node3D).transform.basis = base
			done.append(n)
	for n in done:
		_state.erase(n)
