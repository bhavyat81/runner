# traffic_car.gd
# NPC traffic car that moves in a lane. Colliding with it causes damage.
extends Area3D

const LANE_X: Array[float] = [-3.0, 0.0, 3.0]

var speed_offset: float = 0.0  # relative to player speed (negative = same dir slower, positive = ahead faster)
var collected: bool = false

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

func _ready() -> void:
	collision_layer = 32
	collision_mask = 1
	body_entered.connect(_on_body_entered)

func setup(lane: int, is_fast: bool) -> void:
	position.x = LANE_X[lane]
	# Slow cars scroll with player (appear to move at 60% speed) — net offset makes them drift back
	# Fast cars scroll faster than player (130% speed) — net offset makes them drift forward
	speed_offset = 0.3 if is_fast else -0.4  # fraction of current_speed added per frame
	_build_car(is_fast)

func _build_car(is_fast: bool) -> void:
	var variant := randi() % 3  # 0=sedan, 1=suv, 2=van
	var car_color := Color(randf_range(0.2, 1.0), randf_range(0.2, 1.0), randf_range(0.2, 1.0))

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = car_color
	body_mat.roughness = 0.4
	body_mat.metallic = 0.3

	# Body dimensions per variant
	var body_size: Vector3
	var body_y: float
	match variant:
		0:  # Sedan
			body_size = Vector3(2.0, 0.7, 3.6)
			body_y = 0.55
		1:  # SUV
			body_size = Vector3(2.1, 1.0, 3.8)
			body_y = 0.7
		2:  # Van
			body_size = Vector3(2.0, 1.3, 5.0)
			body_y = 0.85
	var body_mesh := BoxMesh.new()
	body_mesh.size = body_size
	var body_node := MeshInstance3D.new()
	body_node.mesh = body_mesh
	body_node.material_override = body_mat
	body_node.position.y = body_y
	add_child(body_node)

	# Cabin (slightly smaller on top for sedan/suv)
	if variant < 2:
		var cab_mesh := BoxMesh.new()
		cab_mesh.size = Vector3(body_size.x - 0.3, body_size.y * 0.7, body_size.z * 0.55)
		var cab := MeshInstance3D.new()
		cab.mesh = cab_mesh
		var cab_mat := StandardMaterial3D.new()
		cab_mat.albedo_color = car_color.darkened(0.2)
		cab_mat.roughness = 0.4
		cab_mat.metallic = 0.3
		cab.material_override = cab_mat
		cab.position = Vector3(0.0, body_y + body_size.y * 0.85, 0.0)
		add_child(cab)

	# Headlights (emissive white on front — negative Z is forward toward camera)
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(1.0, 1.0, 0.9)
	head_mat.emission_enabled = true
	head_mat.emission = Color(1.0, 1.0, 0.85)
	head_mat.emission_energy_multiplier = 3.0
	head_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for hx in [-0.6, 0.6]:
		var h_mesh := BoxMesh.new()
		h_mesh.size = Vector3(0.3, 0.2, 0.08)
		var h := MeshInstance3D.new()
		h.mesh = h_mesh
		h.material_override = head_mat
		h.position = Vector3(hx, body_y, -body_size.z * 0.5 - 0.04)
		add_child(h)

	# Taillights (red emissive on rear — positive Z)
	var tail_mat := StandardMaterial3D.new()
	tail_mat.albedo_color = Color(1.0, 0.05, 0.05)
	tail_mat.emission_enabled = true
	tail_mat.emission = Color(1.0, 0.0, 0.0)
	tail_mat.emission_energy_multiplier = 2.5
	tail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for tx in [-0.6, 0.6]:
		var t_mesh := BoxMesh.new()
		t_mesh.size = Vector3(0.3, 0.2, 0.08)
		var t := MeshInstance3D.new()
		t.mesh = t_mesh
		t.material_override = tail_mat
		t.position = Vector3(tx, body_y, body_size.z * 0.5 + 0.04)
		add_child(t)

	# Collision shape
	var shape := BoxShape3D.new()
	shape.size = body_size + Vector3(0.1, 0.4, 0.1)
	collision_shape.shape = shape
	collision_shape.position.y = body_y

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("truck") and not collected:
		collected = true
		GameManager.damage_health(15)
		GameManager.break_combo()
