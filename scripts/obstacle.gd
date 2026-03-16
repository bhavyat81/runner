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
	# Car body (lower box)
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.7, 0.7, 2.8)
	mesh_instance.mesh = body_mesh
	mesh_instance.position.y = 0.35

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = color
	body_mat.emission_enabled = true
	body_mat.emission = color
	body_mat.emission_energy_multiplier = 0.4
	body_mat.metallic = 0.3
	body_mat.roughness = 0.4
	mesh_instance.material_override = body_mat

	# Car cabin (upper box)
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.5, 0.6, 1.4)
	var cabin := MeshInstance3D.new()
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(0.0, 0.95, -0.2)
	var cabin_mat := StandardMaterial3D.new()
	cabin_mat.albedo_color = color.darkened(0.15)
	cabin_mat.metallic = 0.3
	cabin_mat.roughness = 0.3
	cabin.material_override = cabin_mat
	add_child(cabin)

	# Windshield
	var wind_mesh := BoxMesh.new()
	wind_mesh.size = Vector3(1.3, 0.45, 0.08)
	var windshield := MeshInstance3D.new()
	windshield.mesh = wind_mesh
	windshield.position = Vector3(0.0, 0.95, -0.92)
	var wind_mat := StandardMaterial3D.new()
	wind_mat.albedo_color = Color(0.5, 0.7, 0.9, 0.8)
	wind_mat.metallic = 0.5
	wind_mat.roughness = 0.1
	wind_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	windshield.material_override = wind_mat
	add_child(windshield)

	# Tail lights (2 small red boxes at back)
	var light_mesh := BoxMesh.new()
	light_mesh.size = Vector3(0.3, 0.2, 0.08)
	var light_mat := StandardMaterial3D.new()
	light_mat.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
	light_mat.emission_enabled = true
	light_mat.emission = Color(1.0, 0.0, 0.0, 1.0)
	light_mat.emission_energy_multiplier = 1.5

	for x_off in [-0.6, 0.6]:
		var light := MeshInstance3D.new()
		light.mesh = light_mesh
		light.material_override = light_mat
		light.position = Vector3(x_off, 0.35, 1.42)
		add_child(light)

	# Wheels (4 dark cylinders)
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.25
	wheel_mesh.bottom_radius = 0.25
	wheel_mesh.height = 0.15
	var wheel_mat := StandardMaterial3D.new()
	wheel_mat.albedo_color = Color(0.1, 0.1, 0.1, 1.0)

	for pos in [Vector3(-0.85, 0.2, -0.8), Vector3(0.85, 0.2, -0.8), Vector3(-0.85, 0.2, 0.8), Vector3(0.85, 0.2, 0.8)]:
		var wheel := MeshInstance3D.new()
		wheel.mesh = wheel_mesh
		wheel.material_override = wheel_mat
		wheel.position = pos
		wheel.rotation_degrees.z = 90.0
		add_child(wheel)

func _build_barrier(color: Color) -> void:
	# Orange/white striped road barrier
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(1.8, 1.0, 0.3)
	mesh_instance.mesh = bar_mesh
	mesh_instance.position.y = 1.0

	var bar_mat := StandardMaterial3D.new()
	bar_mat.albedo_color = Color(1.0, 0.5, 0.0, 1.0)
	bar_mat.emission_enabled = true
	bar_mat.emission = Color(1.0, 0.4, 0.0, 1.0)
	bar_mat.emission_energy_multiplier = 0.6
	mesh_instance.material_override = bar_mat

	# White stripe
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(1.82, 0.25, 0.32)
	var stripe := MeshInstance3D.new()
	stripe.mesh = stripe_mesh
	stripe.position = Vector3(0.0, 1.0, 0.0)
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	stripe_mat.emission_enabled = true
	stripe_mat.emission = Color(1.0, 1.0, 1.0, 1.0)
	stripe_mat.emission_energy_multiplier = 0.3
	stripe.material_override = stripe_mat
	add_child(stripe)

	# Support legs (2 vertical poles)
	var leg_mesh := BoxMesh.new()
	leg_mesh.size = Vector3(0.1, 1.0, 0.1)
	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.3, 0.3, 0.3, 1.0)
	for x_off in [-0.7, 0.7]:
		var leg := MeshInstance3D.new()
		leg.mesh = leg_mesh
		leg.material_override = leg_mat
		leg.position = Vector3(x_off, 0.5, 0.0)
		add_child(leg)

	# Flashing light on top
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.12
	flash_mesh.height = 0.24
	var flash := MeshInstance3D.new()
	flash.mesh = flash_mesh
	flash.position = Vector3(0.0, 1.65, 0.0)
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.0, 0.8, 0.0, 1.0)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.8, 0.0, 1.0)
	flash_mat.emission_energy_multiplier = 2.0
	flash.material_override = flash_mat
	add_child(flash)

func _build_cone(color: Color) -> void:
	# Orange traffic cone
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.05
	cone_mesh.bottom_radius = 0.35
	cone_mesh.height = 1.2
	mesh_instance.mesh = cone_mesh
	mesh_instance.position.y = 0.6

	var cone_mat := StandardMaterial3D.new()
	cone_mat.albedo_color = Color(1.0, 0.4, 0.0, 1.0)
	cone_mat.emission_enabled = true
	cone_mat.emission = Color(1.0, 0.3, 0.0, 1.0)
	cone_mat.emission_energy_multiplier = 0.5
	mesh_instance.material_override = cone_mat

	# White reflective stripes
	var stripe_mesh := CylinderMesh.new()
	stripe_mesh.top_radius = 0.18
	stripe_mesh.bottom_radius = 0.22
	stripe_mesh.height = 0.12
	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	stripe_mat.emission_enabled = true
	stripe_mat.emission = Color(1.0, 1.0, 1.0, 1.0)
	stripe_mat.emission_energy_multiplier = 0.4

	for y in [0.35, 0.55]:
		var stripe := MeshInstance3D.new()
		stripe.mesh = stripe_mesh
		stripe.material_override = stripe_mat
		stripe.position.y = y
		add_child(stripe)

	# Square base
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(0.7, 0.08, 0.7)
	var base := MeshInstance3D.new()
	base.mesh = base_mesh
	base.position.y = 0.04
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.2, 0.2, 0.2, 1.0)
	base.material_override = base_mat
	add_child(base)

	# Spawn 3 cones in a cluster for visibility
	for offset in [Vector3(-0.5, 0.0, -0.3), Vector3(0.5, 0.0, 0.2)]:
		var extra_cone_mesh := CylinderMesh.new()
		extra_cone_mesh.top_radius = 0.04
		extra_cone_mesh.bottom_radius = 0.3
		extra_cone_mesh.height = 1.0
		var extra := MeshInstance3D.new()
		extra.mesh = extra_cone_mesh
		extra.material_override = cone_mat
		extra.position = offset + Vector3(0.0, 0.5, 0.0)
		add_child(extra)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("truck"):
		body.die()
