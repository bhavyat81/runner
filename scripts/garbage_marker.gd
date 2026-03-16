# garbage_marker.gd
# Red circle on the road predicting where a garbage bag will land.
# When the truck reaches this marker it collects the garbage (+10 score).
extends Area3D

const LANE_X: Array[float] = [-2.0, 0.0, 2.0]

@onready var marker_mesh: MeshInstance3D = $MarkerMesh
@onready var garbage_bag: MeshInstance3D = $GarbageBag
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var lane: int = 1
var collected: bool = false
var bag_falling: bool = true

const BAG_START_Y: float = 10.0
const BAG_END_Y: float = 0.35
const BAG_FALL_SPEED: float = 8.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_meshes()

func _build_meshes() -> void:
	# Red glowing disc on road surface
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.85
	cyl.bottom_radius = 0.85
	cyl.height = 0.06
	marker_mesh.mesh = cyl

	var red_mat := StandardMaterial3D.new()
	red_mat.albedo_color = Color(1.0, 0.05, 0.05, 1.0)
	red_mat.emission_enabled = true
	red_mat.emission = Color(1.0, 0.0, 0.0, 1.0)
	red_mat.emission_energy_multiplier = 0.6
	marker_mesh.material_override = red_mat

	# Dark garbage bag falling from building roof
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	garbage_bag.mesh = sphere
	garbage_bag.position.y = BAG_START_Y

	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.15, 0.15, 0.15, 1.0)
	garbage_bag.material_override = dark_mat

	# Cylindrical collision zone covering the disc area
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 0.85
	cyl_shape.height = 1.5
	collision_shape.shape = cyl_shape
	collision_shape.position.y = 0.75

func setup(p_lane: int) -> void:
	lane = p_lane
	position.x = LANE_X[lane]

func _process(delta: float) -> void:
	if bag_falling and not collected:
		garbage_bag.position.y = maxf(
			garbage_bag.position.y - BAG_FALL_SPEED * delta,
			BAG_END_Y
		)
		if garbage_bag.position.y <= BAG_END_Y:
			bag_falling = false

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("truck") and not collected:
		collected = true
		GameManager.collect_garbage()
		queue_free()
