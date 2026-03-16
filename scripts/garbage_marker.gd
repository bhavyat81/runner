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
var pulse_time: float = 0.0

const BAG_START_Y: float = 12.0
const BAG_END_Y: float = 0.5
const BAG_FALL_SPEED: float = 6.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_build_meshes()

func _build_meshes() -> void:
	# Bright red glowing disc on road surface - LARGER and more visible
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.1
	cyl.bottom_radius = 1.1
	cyl.height = 0.08
	marker_mesh.mesh = cyl

	var red_mat := StandardMaterial3D.new()
	red_mat.albedo_color = Color(1.0, 0.1, 0.1, 0.9)
	red_mat.emission_enabled = true
	red_mat.emission = Color(1.0, 0.0, 0.0, 1.0)
	red_mat.emission_energy_multiplier = 1.5
	red_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_mesh.material_override = red_mat

	# Garbage bag - BRIGHT GREEN so it's visible, larger
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	garbage_bag.mesh = sphere
	garbage_bag.position.y = BAG_START_Y

	var bag_mat := StandardMaterial3D.new()
	bag_mat.albedo_color = Color(0.1, 0.6, 0.1, 1.0)
	bag_mat.emission_enabled = true
	bag_mat.emission = Color(0.0, 0.4, 0.0, 1.0)
	bag_mat.emission_energy_multiplier = 0.3
	garbage_bag.material_override = bag_mat

	# Smaller collision zone - won't overlap with truck as easily
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 1.0
	cyl_shape.height = 0.8
	collision_shape.shape = cyl_shape
	collision_shape.position.y = 0.4

func setup(p_lane: int) -> void:
	lane = p_lane
	position.x = LANE_X[lane]

func _process(delta: float) -> void:
	if collected:
		return

	# Falling bag animation
	if bag_falling:
		garbage_bag.position.y = maxf(
			garbage_bag.position.y - BAG_FALL_SPEED * delta,
			BAG_END_Y
		)
		if garbage_bag.position.y <= BAG_END_Y:
			bag_falling = false

	# Pulsing glow effect on the red circle
	pulse_time += delta * 4.0
	var pulse := (sin(pulse_time) + 1.0) * 0.5
	var mat: StandardMaterial3D = marker_mesh.material_override
	if mat:
		mat.emission_energy_multiplier = lerpf(0.8, 2.5, pulse)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("truck") and not collected:
		collected = true
		GameManager.collect_garbage()
		queue_free()
