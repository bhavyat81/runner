# obstacle.gd
# A 3D obstacle on the road. Kills the truck on collision.
# Spawns as one of the Kenney prop models: cone, box, or debris-tire.
extends Area3D

@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const LANE_X: Array[float] = [-3.0, 0.0, 3.0]

# Kenney prop models used for obstacles
const OBSTACLE_MODELS: Array[String] = [
	"res://assets/models/cone.glb",
	"res://assets/models/box.glb",
	"res://assets/models/debris-tire.glb",
]

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	body_entered.connect(_on_body_entered)

func setup(lane: int, _color: Color) -> void:
	position.x = LANE_X[lane]
	_build_mesh()

	# Collision shape covers all obstacle types
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 1.8, 2.5)
	collision_shape.shape = shape
	collision_shape.position.y = 0.9

func _build_mesh() -> void:
	var model_path: String = OBSTACLE_MODELS[randi() % OBSTACLE_MODELS.size()]
	var scene = load(model_path)
	if scene == null:
		push_warning("Obstacle: failed to load model: " + model_path)
		return
	var model := scene.instantiate()
	model.scale = Vector3(1.5, 1.5, 1.5)
	add_child(model)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("truck"):
		GameManager.break_combo()
		GameManager.damage_health(25)
