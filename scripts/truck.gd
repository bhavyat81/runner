# truck.gd
# Controls the garbage truck player character in 3D.
# Handles lane switching (smooth tween), jumping, death, and skin application.
extends CharacterBody3D

# Lane X positions: left=-3, center=0, right=3
const LANES: Array[float] = [-3.0, 0.0, 3.0]
var current_lane: int = 1  # Start in centre lane

# GLB model path per skin (matches GameManager.SKIN_NAMES order)
const SKIN_MODELS: Array[String] = [
	"res://assets/models/garbage-truck.glb",  # 0 Default
	"res://assets/models/firetruck.glb",       # 1 Fire Truck
	"res://assets/models/delivery.glb",        # 2 Ice Cream Truck
	"res://assets/models/truck.glb",           # 3 Monster Truck
	"res://assets/models/race-future.glb",     # 4 Neon Truck
]

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
	_build_mesh()

func _build_mesh() -> void:
	var skin_id := GameManager.selected_skin
	var model_path: String = SKIN_MODELS[skin_id] if skin_id < SKIN_MODELS.size() else SKIN_MODELS[0]
	var scene = load(model_path)
	if scene == null:
		push_warning("Truck: failed to load model: " + model_path)
		return
	var model := scene.instantiate()
	# Kenney models face +Z; rotate 180° so the truck faces -Z (forward/toward camera)
	model.rotation_degrees.y = 180.0
	# Monster truck skin gets a slightly larger scale for presence
	var model_scale := 1.8 if skin_id == 3 else 1.5
	model.scale = Vector3(model_scale, model_scale, model_scale)
	add_child(model)

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
	# Ghost Mode: truck passes through obstacles without dying
	if GameManager.power_active and GameManager.selected_power == GameManager.PreGamePower.GHOST_MODE:
		return
	is_dead = true
	rotation.z = 0.0
	died.emit()

