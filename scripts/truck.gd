# truck.gd
# Controls the garbage truck player character in 3D.
# Handles lane switching, jumping, and death detection.
extends CharacterBody3D

# Lane X positions: left=-2, center=0, right=2
const LANES: Array[float] = [-2.0, 0.0, 2.0]
var current_lane: int = 1  # Start in centre lane

# Movement constants
const LANE_SWITCH_SPEED: float = 10.0
const JUMP_SPEED: float = 9.0
const GRAVITY: float = 28.0

var target_x: float = 0.0
var is_dead: bool = false

# Touch swipe detection
var touch_start: Vector2 = Vector2.ZERO
const SWIPE_THRESHOLD: float = 60.0

signal died

func _ready() -> void:
current_lane = 1
target_x = LANES[current_lane]
position = Vector3(0.0, 0.0, 0.0)
add_to_group("truck")

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

func _try_jump() -> void:
if is_on_floor():
velocity.y = JUMP_SPEED

func die() -> void:
if is_dead:
return
is_dead = true
died.emit()
