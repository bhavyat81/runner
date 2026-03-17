# obstacle.gd
# A 3D obstacle on the road. Kills the truck on collision.
# Spawns as different obstacle types: car, barrier, or cone.
extends Area3D

@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const LANE_X: Array[float] = [-3.0, 0.0, 3.0]

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	body_entered.connect(_on_body_entered)

func setup(lane: int, color: Color) -> void:
	position.x = LANE_X[lane]

	var obstacle_type := randi() % 3
	match obstacle_type:
		0:
			_build_piano(color)
		1:
			_build_tv(color)
		2:
			_build_bed(color)

	# Collision shape covers all types
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 1.8, 2.5)
	collision_shape.shape = shape
	collision_shape.position.y = 0.9

func _build_piano(color: Color) -> void:
	# Grand piano body — large glossy black box
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(2.4, 1.0, 2.2)
	mesh_instance.mesh = body_mesh
	mesh_instance.position.y = 0.5

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.05, 0.05, 0.05, 1.0)
	body_mat.metallic = 0.6
	body_mat.roughness = 0.2
	body_mat.emission_enabled = true
	body_mat.emission = color * 0.3
	body_mat.emission_energy_multiplier = 0.4
	mesh_instance.material_override = body_mat

	# Lid (raised at slight angle on top)
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(2.4, 0.06, 2.2)
	var lid := MeshInstance3D.new()
	lid.mesh = lid_mesh
	lid.material_override = body_mat
	lid.position = Vector3(0.0, 1.05, 0.0)
	lid.rotation_degrees.x = -12.0
	add_child(lid)

	# White piano keys strip (front of top surface)
	var keys_white_mesh := BoxMesh.new()
	keys_white_mesh.size = Vector3(2.2, 0.07, 0.45)
	var keys_white := MeshInstance3D.new()
	keys_white.mesh = keys_white_mesh
	var keys_white_mat := StandardMaterial3D.new()
	keys_white_mat.albedo_color = Color(0.95, 0.95, 0.92, 1.0)
	keys_white_mat.emission_enabled = true
	keys_white_mat.emission = Color(1.0, 1.0, 0.9, 1.0)
	keys_white_mat.emission_energy_multiplier = 0.3
	keys_white.material_override = keys_white_mat
	keys_white.position = Vector3(0.0, 1.03, -0.75)
	add_child(keys_white)

	# Black piano keys on top of white strip (5 raised thin black bars)
	var black_key_mat := StandardMaterial3D.new()
	black_key_mat.albedo_color = Color(0.05, 0.05, 0.05, 1.0)
	for i in range(5):
		var bk_mesh := BoxMesh.new()
		bk_mesh.size = Vector3(0.12, 0.09, 0.27)
		var bk := MeshInstance3D.new()
		bk.mesh = bk_mesh
		bk.material_override = black_key_mat
		bk.position = Vector3(-1.0 + i * 0.5, 1.07, -0.70)
		add_child(bk)

	# 3 legs (thin cylinders at front-left, front-right, back-centre)
	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.05, 0.05, 0.05, 1.0)
	leg_mat.metallic = 0.5
	for leg_pos in [Vector3(-0.9, 0.0, -0.85), Vector3(0.9, 0.0, -0.85), Vector3(0.0, 0.0, 0.85)]:
		var leg_cyl := CylinderMesh.new()
		leg_cyl.top_radius = 0.07
		leg_cyl.bottom_radius = 0.07
		leg_cyl.height = 1.0
		var leg := MeshInstance3D.new()
		leg.mesh = leg_cyl
		leg.material_override = leg_mat
		leg.position = leg_pos + Vector3(0.0, 0.5, 0.0)
		add_child(leg)

func _build_tv(color: Color) -> void:
	# CRT television body — large boxy shape
	var tv_mesh := BoxMesh.new()
	tv_mesh.size = Vector3(2.6, 1.8, 1.2)
	mesh_instance.mesh = tv_mesh
	mesh_instance.position.y = 0.9

	var tv_mat := StandardMaterial3D.new()
	tv_mat.albedo_color = Color(0.18, 0.17, 0.16, 1.0)
	tv_mat.roughness = 0.6
	mesh_instance.material_override = tv_mat

	# Glowing screen face — tinted with the accent color
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(2.1, 1.4, 0.05)
	var screen := MeshInstance3D.new()
	screen.mesh = screen_mesh
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.35, 0.55, 1.0, 1.0).lerp(color, 0.35)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.2, 0.4, 1.0, 1.0).lerp(color, 0.3)
	screen_mat.emission_energy_multiplier = 2.0
	screen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen.material_override = screen_mat
	screen.position = Vector3(0.0, 0.9, -0.63)
	add_child(screen)

	# Two antennas in a V shape at the top
	var ant_mat := StandardMaterial3D.new()
	ant_mat.albedo_color = Color(0.5, 0.5, 0.5, 1.0)
	ant_mat.metallic = 0.7
	var ant_angles := [Vector3(0.0, 0.0, -25.0), Vector3(0.0, 0.0, 25.0)]
	var ant_offsets := [Vector3(-0.4, 0.0, 0.0), Vector3(0.4, 0.0, 0.0)]
	for i in range(2):
		var ant_cyl := CylinderMesh.new()
		ant_cyl.top_radius = 0.03
		ant_cyl.bottom_radius = 0.05
		ant_cyl.height = 1.4
		var ant := MeshInstance3D.new()
		ant.mesh = ant_cyl
		ant.material_override = ant_mat
		ant.position = ant_offsets[i] + Vector3(0.0, 1.8 + 0.7, 0.3)
		ant.rotation_degrees = ant_angles[i]
		add_child(ant)

	# Stubby legs (2 small boxes at bottom)
	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.15, 0.14, 0.13, 1.0)
	for lx in [-0.8, 0.8]:
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.3, 0.25, 0.4)
		var leg := MeshInstance3D.new()
		leg.mesh = leg_mesh
		leg.material_override = leg_mat
		leg.position = Vector3(lx, 0.12, 0.2)
		add_child(leg)

func _build_bed(color: Color) -> void:
	# Mattress — wide flat box
	var mattress_mesh := BoxMesh.new()
	mattress_mesh.size = Vector3(2.4, 0.45, 2.8)
	mesh_instance.mesh = mattress_mesh
	mesh_instance.position.y = 0.45

	var mattress_mat := StandardMaterial3D.new()
	mattress_mat.albedo_color = Color(0.82, 0.88, 0.98, 1.0).lerp(color, 0.2)
	mattress_mat.roughness = 0.9
	mesh_instance.material_override = mattress_mat

	# Headboard — tall thin box at the back end
	var hb_mesh := BoxMesh.new()
	hb_mesh.size = Vector3(2.4, 1.4, 0.2)
	var headboard := MeshInstance3D.new()
	headboard.mesh = hb_mesh
	var hb_mat := StandardMaterial3D.new()
	hb_mat.albedo_color = Color(0.38, 0.22, 0.08, 1.0)
	hb_mat.roughness = 0.7
	headboard.material_override = hb_mat
	headboard.position = Vector3(0.0, 0.85, 1.4)
	add_child(headboard)

	# Footboard — shorter thin box at the front end
	var fb_mesh := BoxMesh.new()
	fb_mesh.size = Vector3(2.4, 0.6, 0.2)
	var footboard := MeshInstance3D.new()
	footboard.mesh = fb_mesh
	footboard.material_override = hb_mat
	footboard.position = Vector3(0.0, 0.5, -1.4)
	add_child(footboard)

	# Pillow — small rounded box near headboard
	var pillow_mesh := BoxMesh.new()
	pillow_mesh.size = Vector3(0.9, 0.18, 0.55)
	var pillow := MeshInstance3D.new()
	pillow.mesh = pillow_mesh
	var pillow_mat := StandardMaterial3D.new()
	pillow_mat.albedo_color = Color(1.0, 0.97, 0.90, 1.0)
	pillow_mat.roughness = 0.95
	pillow.material_override = pillow_mat
	pillow.position = Vector3(0.0, 0.72, 1.05)
	add_child(pillow)

	# 4 short legs at corners
	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.3, 0.18, 0.06, 1.0)
	for lp in [Vector3(-1.05, 0.0, -1.25), Vector3(1.05, 0.0, -1.25), Vector3(-1.05, 0.0, 1.25), Vector3(1.05, 0.0, 1.25)]:
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.22, 0.45, 0.22)
		var leg := MeshInstance3D.new()
		leg.mesh = leg_mesh
		leg.material_override = leg_mat
		leg.position = lp + Vector3(0.0, 0.22, 0.0)
		add_child(leg)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("truck"):
		GameManager.break_combo()
		body.die()
