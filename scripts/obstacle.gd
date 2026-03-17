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
			_build_car(color)
		1:
			_build_barrier(color)
		2:
			_build_cone(color)

	# Collision shape covers all types
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 1.8, 2.5)
	collision_shape.shape = shape
	collision_shape.position.y = 0.9

func _build_car(color: Color) -> void:
	# Car body — low wide box
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(2.2, 0.8, 4.0)
	mesh_instance.mesh = body_mesh
	mesh_instance.position.y = 0.6

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = color
	body_mat.roughness = 0.4
	body_mat.metallic = 0.3
	body_mat.emission_enabled = true
	body_mat.emission = color
	body_mat.emission_energy_multiplier = 0.5
	mesh_instance.material_override = body_mat

	# Car cabin/roof on top
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(1.8, 0.6, 2.0)
	var roof := MeshInstance3D.new()
	roof.mesh = roof_mesh
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = color.darkened(0.2)
	roof_mat.roughness = 0.4
	roof_mat.metallic = 0.3
	roof_mat.emission_enabled = true
	roof_mat.emission = color.darkened(0.2)
	roof_mat.emission_energy_multiplier = 0.3
	roof.material_override = roof_mat
	roof.position = Vector3(0.0, 1.1, 0.0)
	add_child(roof)

	# Windows (dark tinted glass on sides)
	var win_mat := StandardMaterial3D.new()
	win_mat.albedo_color = Color(0.2, 0.3, 0.4, 0.7)
	win_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	win_mat.roughness = 0.1
	win_mat.metallic = 0.5
	for wx in [-0.91, 0.91]:
		var win_mesh := BoxMesh.new()
		win_mesh.size = Vector3(0.05, 0.45, 1.7)
		var win := MeshInstance3D.new()
		win.mesh = win_mesh
		win.material_override = win_mat
		win.position = Vector3(wx, 1.08, 0.0)
		add_child(win)

	# 4 wheels (dark cylinders lying on their side)
	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color(0.1, 0.1, 0.1, 1.0)
	wheel_mat.roughness = 0.9
	for wpos in [Vector3(-1.2, 0.3, -1.4), Vector3(1.2, 0.3, -1.4), Vector3(-1.2, 0.3, 1.4), Vector3(1.2, 0.3, 1.4)]:
		var w_mesh := CylinderMesh.new()
		w_mesh.top_radius = 0.3
		w_mesh.bottom_radius = 0.3
		w_mesh.height = 0.22
		var w := MeshInstance3D.new()
		w.mesh = w_mesh
		w.material_override = wheel_mat
		w.position = wpos
		w.rotation_degrees.z = 90.0
		add_child(w)

func _build_barrier(color: Color) -> void:
	# Jersey barrier — tall concrete block, narrow at top, wide at base
	var barrier_mesh := BoxMesh.new()
	barrier_mesh.size = Vector3(0.8, 1.2, 3.0)
	mesh_instance.mesh = barrier_mesh
	mesh_instance.position.y = 0.6

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.73, 0.70, 1.0)
	mat.roughness = 0.9
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.58, 0.55, 1.0)
	mat.emission_energy_multiplier = 0.4
	mesh_instance.material_override = mat

	# Reflective stripe near the top
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(0.82, 0.1, 3.02)
	var stripe := MeshInstance3D.new()
	stripe.mesh = stripe_mesh
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = color
	stripe_mat.emission_enabled = true
	stripe_mat.emission = color
	stripe_mat.emission_energy_multiplier = 0.8
	stripe.material_override = stripe_mat
	stripe.position = Vector3(0.0, 0.95, 0.0)
	add_child(stripe)

func _build_cone(color: Color) -> void:
	# Traffic cone — orange cylinder tapering to point
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.05
	cone_mesh.bottom_radius = 0.35
	cone_mesh.height = 1.0
	mesh_instance.mesh = cone_mesh
	mesh_instance.position.y = 0.5

	var cone_mat := StandardMaterial3D.new()
	cone_mat.albedo_color = Color(0.95, 0.4, 0.05, 1.0)
	cone_mat.roughness = 0.7
	cone_mat.emission_enabled = true
	cone_mat.emission = Color(1.0, 0.4, 0.0, 1.0)
	cone_mat.emission_energy_multiplier = 0.6
	mesh_instance.material_override = cone_mat

	# White reflective band around lower portion
	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.25
	band_mesh.bottom_radius = 0.32
	band_mesh.height = 0.18
	var band := MeshInstance3D.new()
	band.mesh = band_mesh
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	band_mat.emission_enabled = true
	band_mat.emission = color
	band_mat.emission_energy_multiplier = 0.5
	band.material_override = band_mat
	band.position = Vector3(0.0, 0.18, 0.0)
	add_child(band)

	# Flat base plate
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.45
	base_mesh.bottom_radius = 0.45
	base_mesh.height = 0.08
	var base := MeshInstance3D.new()
	base.mesh = base_mesh
	base.material_override = cone_mat
	base.position = Vector3(0.0, 0.04, 0.0)
	add_child(base)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("truck"):
		GameManager.break_combo()
		GameManager.damage_health(25)
