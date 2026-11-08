extends Node3D
## CombatController - pedang. Dipasang otomatis oleh Player.
##   Pegang Sword di hotbar, lalu klik kiri / tekan F untuk menebas ke arah hadap.
##   Biaya 4 energi per ayunan (x1.5 lewat jam 24:00). Damage mengikuti level pedang (10 / 20 / 35).
##   Monster di depan (jarak <= RANGE, di setengah lingkaran depan) kena tebasan di ~0.25 detik.

const ShopData := preload("res://scripts/shops/shop_data.gd")
const HitFx := preload("res://scripts/combat/hit_fx.gd")
const RANGE := 2.2
const COOLDOWN := 0.55
const HIT_DELAY := 0.24

var _player: CharacterBody3D
var _cool := 0.0
var _prompt_on := false


func _ready() -> void:
	top_level = true
	_player = get_parent() as CharacterBody3D
	_ensure_action()


func _exit_tree() -> void:
	HUD.clear_prompt(self)


func _ensure_action() -> void:
	if InputMap.has_action("attack"):
		return
	InputMap.add_action("attack")
	var f := InputEventKey.new()
	f.physical_keycode = KEY_F
	InputMap.action_add_event("attack", f)
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", m)


func _holding_sword() -> bool:
	return GameState.inventory.selected_item() == "sword"


func _physics_process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	var show := false
	if GameState.playing and not GameState.input_locked and not GameState.chatting and not get_tree().paused and _holding_sword():
		var other = HUD.get("_prompt_owner")
		if other == null or other == self or not is_instance_valid(other):
			for m in get_tree().get_nodes_in_group("monster"):
				if (m as Node3D).global_position.distance_to(_player.global_position) < 7.0:
					show = true
					break
	if show:
		HUD.set_prompt(self, "[F / Click] Swing sword")
		_prompt_on = true
	elif _prompt_on:
		HUD.clear_prompt(self)
		_prompt_on = false


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("attack"):
		return
	if not GameState.playing or GameState.input_locked or GameState.chatting or get_tree().paused:
		return
	if not _holding_sword():
		return
	if _cool > 0.0:
		return
	if not GameState.spend_energy(GameState.COST_SWORD):
		GameState.toast.emit("Too tired...")
		return
	_cool = COOLDOWN
	if _player.has_method("play_tool"):
		_player.play_tool("sword")
	get_viewport().set_input_as_handled()
	var fdir: Vector3 = _player.get("facing")
	await get_tree().create_timer(HIT_DELAY * 0.5).timeout
	if is_instance_valid(_player):
		HitFx.slash(_player.get_parent(), _player.global_position, fdir)       # lengkung tebasan putih
	await get_tree().create_timer(HIT_DELAY * 0.5).timeout
	_hit()


func _hit() -> void:
	if not is_instance_valid(_player):
		return
	var f: Vector3 = _player.get("facing")
	var dmg := int(ShopData.SWORD_DAMAGE.get(GameState.tool_level("sword"), 10))
	var hit_any := false
	for m in get_tree().get_nodes_in_group("monster"):
		var to: Vector3 = (m as Node3D).global_position - _player.global_position
		to.y = 0.0
		var d := to.length()
		if d > RANGE or d < 0.001:
			continue
		if to.normalized().dot(f) < 0.15 and d > 0.9:
			continue
		if m.has_method("take_hit"):
			m.take_hit(dmg, to.normalized())
			HitFx.spark(_player.get_parent(), (m as Node3D).global_position + Vector3(0, 0.8, 0) - to.normalized() * 0.3)
			hit_any = true
	if not hit_any:
		_whoosh()


func _whoosh() -> void:
	pass
