class_name Interactable
extends Area3D
## Interactable - area yang bereaksi saat player masuk atau menekan E.
## Dasar untuk pintu, kasur, dan konter toko. Tambahkan CollisionShape3D sebagai child.
##
## mode PRESS : muncul petunjuk "[E] <prompt>", aksi saat E ditekan (pintu rumah, kasur, toko)
## mode AUTO  : aksi langsung saat player masuk (jalan keluar peta ke area lain)
##
## Untuk toko: sambungkan sinyal "interacted" ke fungsi yang membuka menu toko.

signal interacted(player: Node3D)

enum Mode { PRESS, AUTO }

@export var mode: Mode = Mode.PRESS
@export var prompt := "Interact"
@export var arm_delay := 0.6                # abaikan trigger AUTO sesaat setelah scene dimuat

var _player_inside: Node3D = null
var _armed := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	await get_tree().create_timer(arm_delay).timeout
	_armed = true


func _exit_tree() -> void:
	if is_instance_valid(HUD):
		HUD.clear_prompt(self)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	_player_inside = body
	if mode == Mode.AUTO:
		if _armed:
			_activate(body)
	else:
		HUD.set_prompt(self, "[E] %s" % prompt)


func _on_body_exited(body: Node3D) -> void:
	if body == _player_inside:
		_player_inside = null
		HUD.clear_prompt(self)


func _unhandled_input(event: InputEvent) -> void:
	if mode == Mode.PRESS and _player_inside != null and event.is_action_pressed("interact") \
			and not GameState.input_locked:
		get_viewport().set_input_as_handled()
		_activate(_player_inside)


func _activate(player: Node3D) -> void:
	if GameState.input_locked:
		return
	interacted.emit(player)
	_on_interact(player)


## Ditimpa oleh turunan (SceneExit, Bed).
func _on_interact(_player: Node3D) -> void:
	pass
