# garbage_marker.gd
# Red circle on the road predicting where a garbage bag will land.
# Each marker is randomly either collectible (green ✓) or harmful (red ✗).
# The bag starts falling and tick mark appears when the marker gets close to the truck.
extends Area3D

const LANE_X: Array[float] = [-3.0, 0.0, 3.0]
const GARBAGE_BAG_COLOR := Color(0.15, 0.55, 0.15, 1.0)

# Proximity to truck (Z) at which the bag starts falling and tick mark appears
const PROXIMITY_TRIGGER_Z: float = -27.0
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

const BAG_START_Y: float = 10.0
const BAG_END_Y: float = 0.5
const BAG_FALL_SPEED: float = 5.5
const TICK_MARK_FONT_SIZE: int = 210

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_build_meshes()
	_build_tick_mark()

func _build_meshes() -> void:
	# Bright red glowing disc on road surface - LARGER and more visible
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.6
	cyl.bottom_radius = 1.6
	cyl.height = 0.08
	marker_mesh.mesh = cyl

	var red_mat := StandardMaterial3D.new()
	red_mat.albedo_color = Color(1.0, 0.1, 0.1, 0.9)
	red_mat.emission_enabled = true
	red_mat.emission = Color(1.0, 0.0, 0.0, 1.0)
	red_mat.emission_energy_multiplier = 3.0
	red_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker_mesh.material_override = red_mat

	# Falling item — hidden until the marker gets close to the truck.
	# Actual mesh is built in _build_item_mesh() after is_harmful is known.
	garbage_bag.position.y = BAG_START_Y
	garbage_bag.visible = false

	# Collision zone
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 1.4
	cyl_shape.height = 0.8
	collision_shape.shape = cyl_shape
	collision_shape.position.y = 0.4

# Build the falling item mesh that matches the marker type.
# Called from setup() once is_harmful is known.
func _build_item_mesh() -> void:
	if not is_harmful:
		_build_garbage_bag()
	else:
		var funny_type := randi() % 3
		match funny_type:
			0: _build_piano()
			1: _build_tv()
			2: _build_bed()

func _build_garbage_bag() -> void:
	var bag_mat := StandardMaterial3D.new()
	bag_mat.albedo_color = GARBAGE_BAG_COLOR
	bag_mat.roughness = 0.8
	bag_mat.metallic = 0.0
	bag_mat.emission_enabled = true
	bag_mat.emission = Color(0.1, 0.4, 0.1, 1.0)
	bag_mat.emission_energy_multiplier = 0.5

	# Main bag body — slightly squashed sphere (full, bulging bag)
	var body_sphere := SphereMesh.new()
	body_sphere.radius = 0.65
	body_sphere.height = 1.05
	garbage_bag.mesh = body_sphere
	garbage_bag.material_override = bag_mat

	# Neck / twist at the top of the bag (narrow pinch point)
	var neck_mesh := CylinderMesh.new()
	neck_mesh.top_radius = 0.10
	neck_mesh.bottom_radius = 0.22
	neck_mesh.height = 0.22
	var neck := MeshInstance3D.new()
	neck.mesh = neck_mesh
	neck.material_override = bag_mat
	neck.position = Vector3(0.0, 0.62, 0.0)
	garbage_bag.add_child(neck)

	# Tie knot on top — small dark-green sphere
	var knot_sphere := SphereMesh.new()
	knot_sphere.radius = 0.16
	knot_sphere.height = 0.32
	var knot := MeshInstance3D.new()
	knot.mesh = knot_sphere
	knot.material_override = bag_mat
	knot.position = Vector3(0.0, 0.82, 0.0)
	garbage_bag.add_child(knot)

	# Small ear/tail of the knot (thin horizontal cylinder)
	var ear_mesh := CylinderMesh.new()
	ear_mesh.top_radius = 0.04
	ear_mesh.bottom_radius = 0.04
	ear_mesh.height = 0.3
	var ear := MeshInstance3D.new()
	ear.mesh = ear_mesh
	ear.material_override = bag_mat
	ear.position = Vector3(0.0, 0.85, 0.0)
	ear.rotation_degrees.z = 90.0
	garbage_bag.add_child(ear)

func _build_piano() -> void:
	# Grand piano body — large glossy black box
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.8, 0.8, 1.6)
	garbage_bag.mesh = body_mesh

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.12, 0.12, 0.15, 1.0)
	body_mat.metallic = 0.5
	body_mat.roughness = 0.2
	body_mat.emission_enabled = true
	body_mat.emission = Color(0.15, 0.15, 0.2, 1.0)
	body_mat.emission_energy_multiplier = 0.6
	garbage_bag.material_override = body_mat

	# White keys strip along front
	var keys_mesh := BoxMesh.new()
	keys_mesh.size = Vector3(1.6, 0.07, 0.35)
	var keys := MeshInstance3D.new()
	keys.mesh = keys_mesh
	var keys_mat := StandardMaterial3D.new()
	keys_mat.albedo_color = Color(0.95, 0.95, 0.92, 1.0)
	keys_mat.emission_enabled = true
	keys_mat.emission = Color(0.9, 0.9, 0.85, 1.0)
	keys_mat.emission_energy_multiplier = 0.5
	keys.material_override = keys_mat
	keys.position = Vector3(0.0, 0.44, -0.6)
	garbage_bag.add_child(keys)

	# 3 legs
	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.05, 0.05, 0.05, 1.0)
	for lp in [Vector3(-0.7, 0.0, -0.65), Vector3(0.7, 0.0, -0.65), Vector3(0.0, 0.0, 0.65)]:
		var leg_cyl := CylinderMesh.new()
		leg_cyl.top_radius = 0.06
		leg_cyl.bottom_radius = 0.06
		leg_cyl.height = 0.8
		var leg := MeshInstance3D.new()
		leg.mesh = leg_cyl
		leg.material_override = leg_mat
		leg.position = lp + Vector3(0.0, -0.8, 0.0)
		garbage_bag.add_child(leg)

	# Rotate so the keys face the player (toward positive Z / camera)
	garbage_bag.rotation_degrees.y = 180.0

func _build_tv() -> void:
	# CRT television body
	var tv_mesh := BoxMesh.new()
	tv_mesh.size = Vector3(2.0, 1.5, 1.0)
	garbage_bag.mesh = tv_mesh

	var tv_mat := StandardMaterial3D.new()
	tv_mat.albedo_color = Color(0.25, 0.24, 0.23, 1.0)
	tv_mat.roughness = 0.6
	tv_mat.emission_enabled = true
	tv_mat.emission = Color(0.2, 0.2, 0.2, 1.0)
	tv_mat.emission_energy_multiplier = 0.4
	garbage_bag.material_override = tv_mat

	# Glowing blue screen
	var screen_mesh := BoxMesh.new()
	screen_mesh.size = Vector3(1.6, 1.1, 0.05)
	var screen := MeshInstance3D.new()
	screen.mesh = screen_mesh
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = Color(0.35, 0.55, 1.0, 1.0)
	screen_mat.emission_enabled = true
	screen_mat.emission = Color(0.2, 0.4, 1.0, 1.0)
	screen_mat.emission_energy_multiplier = 2.0
	screen_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	screen.material_override = screen_mat
	screen.position = Vector3(0.0, 0.0, -0.53)
	garbage_bag.add_child(screen)

	# Two antennas in a V shape
	var ant_mat := StandardMaterial3D.new()
	ant_mat.albedo_color = Color(0.5, 0.5, 0.5, 1.0)
	ant_mat.metallic = 0.7
	for i in range(2):
		var ant_cyl := CylinderMesh.new()
		ant_cyl.top_radius = 0.03
		ant_cyl.bottom_radius = 0.05
		ant_cyl.height = 1.2
		var ant := MeshInstance3D.new()
		ant.mesh = ant_cyl
		ant.material_override = ant_mat
		ant.position = Vector3((-0.35 if i == 0 else 0.35), 1.35, 0.25)
		ant.rotation_degrees = Vector3(0.0, 0.0, (-22.0 if i == 0 else 22.0))
		garbage_bag.add_child(ant)

	# Stubby legs
	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.15, 0.14, 0.13, 1.0)
	for lx in [-0.65, 0.65]:
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.25, 0.22, 0.35)
		var leg := MeshInstance3D.new()
		leg.mesh = leg_mesh
		leg.material_override = leg_mat
		leg.position = Vector3(lx, -0.86, 0.1)
		garbage_bag.add_child(leg)

	# Rotate so the screen faces the player (toward positive Z / camera)
	garbage_bag.rotation_degrees.y = 180.0

func _build_bed() -> void:
	# Mattress
	var mattress_mesh := BoxMesh.new()
	mattress_mesh.size = Vector3(1.8, 0.38, 2.2)
	garbage_bag.mesh = mattress_mesh

	var mattress_mat := StandardMaterial3D.new()
	mattress_mat.albedo_color = Color(0.82, 0.88, 0.98, 1.0)
	mattress_mat.roughness = 0.9
	mattress_mat.emission_enabled = true
	mattress_mat.emission = Color(0.6, 0.65, 0.75, 1.0)
	mattress_mat.emission_energy_multiplier = 0.4
	garbage_bag.material_override = mattress_mat

	# Headboard
	var hb_mesh := BoxMesh.new()
	hb_mesh.size = Vector3(1.8, 1.1, 0.18)
	var headboard := MeshInstance3D.new()
	headboard.mesh = hb_mesh
	var hb_mat := StandardMaterial3D.new()
	hb_mat.albedo_color = Color(0.38, 0.22, 0.08, 1.0)
	hb_mat.roughness = 0.7
	hb_mat.emission_enabled = true
	hb_mat.emission = Color(0.3, 0.18, 0.06, 1.0)
	hb_mat.emission_energy_multiplier = 0.3
	headboard.material_override = hb_mat
	headboard.position = Vector3(0.0, 0.65, 1.1)
	garbage_bag.add_child(headboard)

	# Pillow
	var pillow_mesh := BoxMesh.new()
	pillow_mesh.size = Vector3(0.75, 0.16, 0.45)
	var pillow := MeshInstance3D.new()
	pillow.mesh = pillow_mesh
	var pillow_mat := StandardMaterial3D.new()
	pillow_mat.albedo_color = Color(1.0, 0.97, 0.90, 1.0)
	pillow_mat.roughness = 0.95
	pillow_mat.emission_enabled = true
	pillow_mat.emission = Color(0.8, 0.78, 0.7, 1.0)
	pillow_mat.emission_energy_multiplier = 0.3
	pillow.material_override = pillow_mat
	pillow.position = Vector3(0.0, 0.28, 0.82)
	garbage_bag.add_child(pillow)

	# 4 short legs
	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = Color(0.3, 0.18, 0.06, 1.0)
	for lp in [Vector3(-0.8, 0.0, -1.0), Vector3(0.8, 0.0, -1.0), Vector3(-0.8, 0.0, 1.0), Vector3(0.8, 0.0, 1.0)]:
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.18, 0.38, 0.18)
		var leg := MeshInstance3D.new()
		leg.mesh = leg_mesh
		leg.material_override = leg_mat
		leg.position = lp + Vector3(0.0, -0.38, 0.0)
		garbage_bag.add_child(leg)

	# Rotate so the headboard faces the player (toward positive Z / camera)
	garbage_bag.rotation_degrees.y = 180.0

func _build_tick_mark() -> void:
	tick_label = Label3D.new()
	tick_label.font_size = TICK_MARK_FONT_SIZE
	tick_label.position = Vector3(0.0, 2.4, 0.0)
	tick_label.visible = false
	tick_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tick_label.no_depth_test = true
	add_child(tick_label)

func setup(p_lane: int) -> void:
	lane = p_lane
	position.x = LANE_X[lane]
	# Decide randomly whether this garbage is harmful
	is_harmful = randf() < HARMFUL_CHANCE
	# Build the falling item mesh now that is_harmful is known
	_build_item_mesh()
	# Configure tick mark appearance
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
		# Spawn visual effect
		var effect_scene := load("res://scenes/collect_effect.tscn")
		if effect_scene:
			var effect: Node3D = effect_scene.instantiate()
			effect.position = global_position
			get_parent().add_child(effect)
			var effect_color := Color(0.1, 1.0, 0.2, 1.0) if not is_harmful else Color(1.0, 0.15, 0.15, 1.0)
			effect.setup(effect_color)
		if is_harmful:
			GameManager.damage_health(20)
		else:
			GameManager.collect_garbage()
		queue_free()
