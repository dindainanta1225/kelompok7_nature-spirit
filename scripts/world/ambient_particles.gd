extends Node3D
## AmbientParticles - suasana hidup di area terbuka: daun berguguran + kunang-kunang/serbuk cahaya.
## Mengikuti Player supaya selalu ada di sekitar kamera. Tambahkan sebagai child scene (Farm, Village).
## Ubah leaf_amount / mote_amount untuk mengatur kepadatan.

@export var leaf_amount := 36
@export var mote_amount := 34
@export var area := 22.0                 # lebar/lebar kotak partikel (m) di sekitar Player

var _player: Node3D


func _ready() -> void:
	top_level = true
	_build_leaves()
	_build_motes()


func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
	if _player:
		global_position = _player.global_position


func _leaf_texture() -> ImageTexture:
	var w := 32
	var h := 18
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for x in w:
		var t := (x + 0.5) / w
		var hw := 7.5 * sin(PI * t)
		for y in h:
			var d := absf(y + 0.5 - h * 0.5)
			if d < hw:
				img.set_pixel(x, y, Color(0.25, 0.5, 0.22) if d < 0.9 else Color(1, 1, 1))
	return ImageTexture.create_from_image(img)


func _build_leaves() -> void:
	var p := CPUParticles3D.new()
	p.amount = leaf_amount
	p.lifetime = 11.0
	p.preprocess = 11.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(area * 0.5, 0.3, area * 0.5)
	p.position = Vector3(0, 8.0, 0)
	p.direction = Vector3(0.4, -1.0, 0.2)
	p.spread = 20.0
	p.gravity = Vector3(0.35, -0.45, 0.2)
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.7
	p.angle_min = -180.0
	p.angle_max = 180.0
	p.angular_velocity_min = -90.0
	p.angular_velocity_max = 90.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.5
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.45, 0.82, 0.30), Color(0.96, 0.78, 0.30)])
	p.color_initial_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(0.34, 0.19)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _leaf_texture()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.particles_anim_h_frames = 1
	m.particles_anim_v_frames = 1
	q.material = m
	p.mesh = q
	add_child(p)


func _build_motes() -> void:
	var p := CPUParticles3D.new()
	p.amount = mote_amount
	p.lifetime = 7.0
	p.preprocess = 7.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(area * 0.4, 1.2, area * 0.4)
	p.position = Vector3(0, 2.0, 0)
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.45
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(1.0, 0.95, 0.6, 0.0), Color(1.0, 0.95, 0.6, 0.9), Color(1.0, 0.95, 0.6, 0.0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	p.color_ramp = ramp
	var s := SphereMesh.new()
	s.radius = 0.045
	s.height = 0.09
	s.radial_segments = 6
	s.rings = 3
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1, 1, 1, 1)
	s.material = m
	p.mesh = s
	add_child(p)
