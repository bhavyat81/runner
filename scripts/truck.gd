# truck.gd
# Controls the garbage truck player character in 3D.
# Handles lane switching, jumping, and death detection.
extends CharacterBody3D

# Lane X positions: left=-3, center=0, right=3
const LANES: Array[float] = [-3.0, 0.0, 3.0]
var current_lane: int = 1  # Start in centre lane

# Movement constants
const LANE_SWITCH_SPEED: float = 10.0
const JUMP_SPEED: float = 9.0
const GRAVITY: float = 28.0

# Tilt constants
const TILT_AMOUNT: float = 0.15
const TILT_SPEED: float = 8.0

var target_x: float = 0.0
var is_dead: bool = false
var invincible: bool = false
var tilt_target: float = 0.0

# Touch swipe detection
var touch_start: Vector2 = Vector2.ZERO
const SWIPE_THRESHOLD: float = 60.0

signal died

func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	current_lane = 1
	target_x = LANES[current_lane]
	position = Vector3(0.0, 0.0, 0.0)
	add_to_group("truck")
	_setup_truck_appearance()

func _setup_truck_appearance() -> void:
	# Update cab (Cabin node) to dark green
	var cabin: MeshInstance3D = get_node_or_null("Cabin")
	if cabin:
		var cab_mat := StandardMaterial3D.new()
		cab_mat.albedo_color = Color(0.1, 0.35, 0.15)
		cab_mat.metallic = 0.3
		cab_mat.roughness = 0.5
		cabin.set_surface_override_material(0, cab_mat)
	var cabin_roof: MeshInstance3D = get_node_or_null("CabinRoof")
	if cabin_roof:
		var roof_mat := StandardMaterial3D.new()
		roof_mat.albedo_color = Color(0.1, 0.35, 0.15)
		roof_mat.metallic = 0.3
		roof_mat.roughness = 0.5
		cabin_roof.set_surface_override_material(0, roof_mat)

	# Update compactor body color
	var compactor: MeshInstance3D = get_node_or_null("CompactorBody")
	if compactor:
		var comp_mat := StandardMaterial3D.new()
		comp_mat.albedo_color = Color(0.15, 0.5, 0.2)
		comp_mat.metallic = 0.3
		comp_mat.roughness = 0.5
		compactor.set_surface_override_material(0, comp_mat)

	# Make side stripes bright yellow/green emissive
	for stripe_name in ["LeftStripe", "RightStripe"]:
		var stripe: MeshInstance3D = get_node_or_null(stripe_name)
		if stripe:
			var stripe_mat := StandardMaterial3D.new()
			stripe_mat.albedo_color = Color(0.8, 1.0, 0.0)
			stripe_mat.emission_enabled = true
			stripe_mat.emission = Color(0.6, 1.0, 0.0)
			stripe_mat.emission_energy_multiplier = 1.5
			stripe_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			stripe.set_surface_override_material(0, stripe_mat)

	# Add underglow OmniLight3D beneath the truck
	var underglow_light := OmniLight3D.new()
	underglow_light.light_color = Color(0.2, 1.0, 0.3)
	underglow_light.light_energy = 0.8
	underglow_light.omni_range = 4.0
	underglow_light.position = Vector3(0.0, -0.2, 0.0)
	add_child(underglow_light)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	# Smooth X lane transition
	position.x = lerp(position.x, target_x, LANE_SWITCH_SPEED * delta)

	# Apply tilt and ease back to upright
	rotation.z = lerp(rotation.z, tilt_target, TILT_SPEED * delta)
	tilt_target = lerp(tilt_target, 0.0, TILT_SPEED * 0.5 * delta)

	move_and_slide()

func _input(event: InputEvent) -> void:
	if is_dead:
		return

	# Keyboard / gamepad controls
	if event.is_action_pressed("move_left"):
		_change_lane(-1)
	elif event.is_action_pressed("move_right"):
		_change_lane(1)
	elif event.is_action_pressed("jump"):
		_try_jump()

	# Touch swipe controls
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
		else:
			var delta_vec: Vector2 = event.position - touch_start
			if delta_vec.length() > SWIPE_THRESHOLD:
				if abs(delta_vec.x) > abs(delta_vec.y):
					_change_lane(1 if delta_vec.x > 0 else -1)
				elif delta_vec.y < 0:
					_try_jump()

func _change_lane(direction: int) -> void:
	var new_lane := clampi(current_lane + direction, 0, 2)
	if new_lane != current_lane:
		current_lane = new_lane
		target_x = LANES[current_lane]
		tilt_target = -TILT_AMOUNT * direction

func _try_jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_SPEED

func set_invincible(value: bool) -> void:
	invincible = value

func die() -> void:
	if is_dead or invincible:
		return
	is_dead = true
	died.emit()

