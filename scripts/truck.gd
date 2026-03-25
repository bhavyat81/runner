# truck.gd
# Controls the garbage truck player character in 3D.
# Handles lane switching (smooth tween), jumping, death, and skin application.
extends CharacterBody3D

# Lane X positions: left=-3, center=0, right=3
const LANES: Array[float] = [-3.0, 0.0, 3.0]
var current_lane: int = 1  # Start in centre lane

# Movement constants
const JUMP_SPEED: float = 9.0
const GRAVITY: float = 28.0

# Tilt constants (degrees)
const TILT_Z_AMOUNT: float = 8.0   # lean on lane switch
const TILT_X_JUMP: float = -5.0    # forward tilt on ascent
const TILT_X_FALL: float = 5.0     # backward tilt on descent
const TILT_SPEED: float = 8.0
const TILT_RETURN_SPEED: float = 6.0
const TILT_SNAP_THRESHOLD: float = 0.005

var target_x: float = 0.0
var is_dead: bool = false
var invincible: bool = false
var _tween_active: bool = false
var _jump_cooldown: float = 0.0
var _squash_timer: float = 0.0
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
	rotation = Vector3.ZERO
	add_to_group("truck")
	_setup_truck_appearance()
	_apply_skin(GameManager.selected_skin)

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

# Apply a skin (0=default, 1=fire, 2=ice cream, 3=monster, 4=neon)
func _apply_skin(skin_id: int) -> void:
	var body_colors: Array[Color] = [
		Color(0.15, 0.5, 0.2),      # Default green
		Color(0.8, 0.1, 0.1),       # Fire Truck red
		Color(0.95, 0.75, 0.85),    # Ice Cream pastel
		Color(0.1, 0.3, 0.1),       # Monster dark green
		Color(0.05, 0.05, 0.05),    # Neon black base
	]
	var cab_colors: Array[Color] = [
		Color(0.1, 0.35, 0.15),
		Color(0.7, 0.08, 0.08),
		Color(0.9, 0.7, 0.8),
		Color(0.08, 0.25, 0.08),
		Color(0.05, 0.05, 0.05),
	]
	var color := body_colors[skin_id] if skin_id < body_colors.size() else body_colors[0]
	var cab_color := cab_colors[skin_id] if skin_id < cab_colors.size() else cab_colors[0]

	var compactor: MeshInstance3D = get_node_or_null("CompactorBody")
	if compactor:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.metallic = 0.3
		mat.roughness = 0.5
		if skin_id == 4:  # Neon — add glow
			mat.emission_enabled = true
			mat.emission = Color(0.0, 1.0, 0.8)
			mat.emission_energy_multiplier = 1.2
		compactor.set_surface_override_material(0, mat)
	for node_name in ["Cabin", "CabinRoof"]:
		var node: MeshInstance3D = get_node_or_null(node_name)
		if node:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = cab_color
			mat.metallic = 0.3
			mat.roughness = 0.5
			node.set_surface_override_material(0, mat)

	# Monster truck: scale up
	if skin_id == 3:
		scale = Vector3(1.2, 1.2, 1.2)
	else:
		scale = Vector3(1.0, 1.0, 1.0)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if velocity.y < -1.0:
			# Just landed — squash effect
			_squash_timer = 0.15
		velocity.y = 0.0

	# Squash on landing: briefly scale Y down
	if _squash_timer > 0.0:
		_squash_timer -= delta
		var squash := 1.0 - 0.25 * (_squash_timer / 0.15)
		scale.x = 1.0 + 0.12 * (_squash_timer / 0.15)
		scale.y = squash
		scale.z = 1.0 + 0.12 * (_squash_timer / 0.15)
	elif not is_on_floor():
		# No squash while airborne
		pass
	else:
		scale = Vector3(1.0, 1.0, 1.0)

	# Jump cooldown
	if _jump_cooldown > 0.0:
		_jump_cooldown -= delta

	# Smooth X position (instant if tween active — tween handles X)
	if not _tween_active:
		position.x = lerp(position.x, target_x, 10.0 * delta)

	# Z tilt (lane change lean)
	# --- FIX: Tilt logic that properly returns to zero ---
	# First, decay tilt_target toward zero
	tilt_target = lerp(tilt_target, 0.0, TILT_RETURN_SPEED * delta)
	if absf(tilt_target) < TILT_SNAP_THRESHOLD:
		tilt_target = 0.0

	# Then move rotation.z toward the (now-decaying) tilt_target
	rotation.z = lerp(rotation.z, tilt_target, TILT_SPEED * delta)
	if absf(rotation.z) < TILT_SNAP_THRESHOLD:
		rotation.z = 0.0

	# Clamp rotation.z to prevent runaway spinning
	rotation.z = clampf(rotation.z, -deg_to_rad(TILT_Z_AMOUNT) * 2.0, deg_to_rad(TILT_Z_AMOUNT) * 2.0)

	# X tilt (jump lean)
	var tilt_x_target: float = 0.0
	if not is_on_floor():
		tilt_x_target = deg_to_rad(TILT_X_JUMP) if velocity.y > 0 else deg_to_rad(TILT_X_FALL)
	rotation.x = lerp(rotation.x, tilt_x_target, 8.0 * delta)

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
	if _tween_active:
		return  # Prevent stacking tweens
	var new_lane := clampi(current_lane + direction, 0, 2)
	if new_lane == current_lane:
		return
	current_lane = new_lane
	target_x = LANES[current_lane]
	tilt_target = float(-direction) * deg_to_rad(TILT_Z_AMOUNT)
	_tween_active = true
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "position:x", target_x, 0.2)
	tween.tween_callback(func(): _tween_active = false)

func _try_jump() -> void:
	if is_on_floor() and _jump_cooldown <= 0.0:
		velocity.y = JUMP_SPEED
		_jump_cooldown = 1.0

func set_invincible(value: bool) -> void:
	invincible = value

func die() -> void:
	if is_dead or invincible:
		return
	is_dead = true
	rotation.z = 0.0
	died.emit()

func revive() -> void:
	is_dead = false
	velocity = Vector3.ZERO
	rotation = Vector3.ZERO

