# obstacle.gd
# A 3D obstacle on the road. Kills the truck on collision.
extends Area3D

@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const LANE_X: Array[float] = [-2.0, 0.0, 2.0]

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	body_entered.connect(_on_body_entered)

func setup(lane: int, color: Color) -> void:
	position.x = LANE_X[lane]

	var box := BoxMesh.new()
	box.size = Vector3(1.8, 2.0, 2.5)
	mesh_instance.mesh = box
	mesh_instance.position.y = 1.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.5
	mesh_instance.material_override = mat

	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 2.0, 2.5)
	collision_shape.shape = shape
	collision_shape.position.y = 1.0

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("truck"):
		body.die()
