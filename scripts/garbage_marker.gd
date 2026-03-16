# garbage_marker.gd
# Red circle on the road predicting where a garbage bag will land.
# Each marker is randomly either collectible (green ✓) or harmful (red ✗).
# The bag starts falling and tick mark appears when the marker gets close to the truck.
extends Area3D

const LANE_X: Array[float] = [-3.0, 0.0, 3.0]

# Proximity to truck (Z) at which the bag starts falling and tick mark appears
const PROXIMITY_TRIGGER_Z: float = -15.0
# Chance (~45%) that this garbage is harmful (red ✗)
const HARMFUL_CHANCE: float = 0.45

@onready var marker_mesh: MeshInstance3D = $MarkerMesh
@onready var garbage_bag: MeshInstance3D = $GarbageBag
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var lane: int = 1
var collected: bool = false
var bag_falling: bool = false
var close_triggered: bool = false
var is_harmful: bool = false
var pulse_time: float = 0.0
var tick_label: Label3D = null

const BAG_START_Y: float = 12.0
const BAG_END_Y: float = 0.5
const BAG_FALL_SPEED: float = 8.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_build_meshes()
	_build_tick_mark()

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

	# Garbage bag — hidden until the marker gets close to the truck
	var sphere := SphereMesh.new()
	sphere.radius = 0.45
	sphere.height = 0.9
	garbage_bag.mesh = sphere
	garbage_bag.position.y = BAG_START_Y
	garbage_bag.visible = false

	var bag_mat := StandardMaterial3D.new()
	bag_mat.albedo_color = Color(0.1, 0.6, 0.1, 1.0)
	bag_mat.emission_enabled = true
	bag_mat.emission = Color(0.0, 0.4, 0.0, 1.0)
	bag_mat.emission_energy_multiplier = 0.3
	garbage_bag.material_override = bag_mat

	# Collision zone
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 1.0
	cyl_shape.height = 0.8
	collision_shape.shape = cyl_shape
	collision_shape.position.y = 0.4

func _build_tick_mark() -> void:
	tick_label = Label3D.new()
	tick_label.font_size = 96
	tick_label.position = Vector3(0.0, 1.8, 0.0)
	tick_label.visible = false
	tick_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tick_label.no_depth_test = true
	add_child(tick_label)

func setup(p_lane: int) -> void:
	lane = p_lane
	position.x = LANE_X[lane]
	# Decide randomly whether this garbage is harmful
	is_harmful = randf() < HARMFUL_CHANCE
	# Configure tick mark appearance now that is_harmful is known
	if tick_label:
		if is_harmful:
			tick_label.text = "✗"
			tick_label.modulate = Color(1.0, 0.15, 0.15, 1.0)
		else:
			tick_label.text = "✓"
			tick_label.modulate = Color(0.1, 1.0, 0.1, 1.0)

func _process(delta: float) -> void:
	if collected:
		return

	# Reveal bag and tick mark when the marker is a few steps from the truck (truck at Z≈0)
	if not close_triggered and position.z >= PROXIMITY_TRIGGER_Z:
		close_triggered = true
		bag_falling = true
		garbage_bag.visible = true
		if tick_label:
			tick_label.visible = true

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
		if is_harmful:
			GameManager.damage_health(20)
		else:
			GameManager.collect_garbage()
		queue_free()
