# player.gd
# Controls the player character with gravity-based physics and jumping.
extends CharacterBody2D

# Physics constants
const GRAVITY: float = 1800.0
const JUMP_VELOCITY: float = -750.0
const DOUBLE_JUMP_VELOCITY: float = -650.0

# State tracking
var is_dead: bool = false
var jump_count: int = 0

# Signals
signal died

# Visual references
@onready var body_rect: ColorRect = $BodyRect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Colors for visual feedback
const COLOR_NORMAL := Color(0.918, 0.271, 0.376, 1.0)
const COLOR_JUMP := Color(1.0, 0.84, 0.0, 1.0)
const COLOR_DOUBLE_JUMP := Color(0.2, 0.8, 1.0, 1.0)
const COLOR_DEAD := Color(1.0, 0.2, 0.2, 1.0)

func _ready() -> void:
	is_dead = false
	jump_count = 0

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	# Apply gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		# Reset jump count and color when back on ground
		if jump_count > 0:
			body_rect.color = COLOR_NORMAL
			body_rect.rotation = 0.0
		jump_count = 0
	
	# Check for jump input
	if Input.is_action_just_pressed("jump"):
		_try_jump()
	
	# Move and slide
	move_and_slide()
	
	# Spin effect while in the air
	if not is_on_floor():
		body_rect.rotation += 3.0 * delta

func _try_jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_count = 1
		body_rect.color = COLOR_JUMP
	elif jump_count < 2:
		velocity.y = DOUBLE_JUMP_VELOCITY
		jump_count = 2
		body_rect.color = COLOR_DOUBLE_JUMP

func die() -> void:
	if is_dead:
		return
	is_dead = true
	body_rect.color = COLOR_DEAD
	died.emit()

func reset() -> void:
	is_dead = false
	jump_count = 0
	velocity = Vector2.ZERO
	body_rect.color = COLOR_NORMAL
	body_rect.rotation = 0.0
