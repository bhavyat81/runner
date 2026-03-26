# traffic_car.gd
# NPC traffic car that moves in a lane. Colliding with it causes damage.
extends Area3D

const LANE_X: Array[float] = [-3.0, 0.0, 3.0]

# Random traffic car models from the Kenney Car Kit
const CAR_MODELS: Array[String] = [
	"res://assets/models/sedan.glb",
	"res://assets/models/suv.glb",
	"res://assets/models/taxi.glb",
	"res://assets/models/hatchback-sports.glb",
	"res://assets/models/police.glb",
	"res://assets/models/van.glb",
]

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

func _build_car(_is_fast: bool) -> void:
	var model_path: String = CAR_MODELS[randi() % CAR_MODELS.size()]
	var scene = load(model_path)
	if scene == null:
		push_warning("TrafficCar: failed to load model: " + model_path)
	else:
		var model := scene.instantiate()
		# Kenney models face +Z; rotate 180° so cars face the same direction as the player
		model.rotation_degrees.y = 180.0
		model.scale = Vector3(1.5, 1.5, 1.5)
		add_child(model)

	# Collision shape sized to fit scaled Kenney car models
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 1.2, 3.8)
	collision_shape.shape = shape
	collision_shape.position.y = 0.6

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("truck") and not collected:
		collected = true
		GameManager.damage_health(15)
		GameManager.break_combo()
