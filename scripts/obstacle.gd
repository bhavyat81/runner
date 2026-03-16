# obstacle.gd
# Controls individual obstacles that move left and despawn off-screen.
extends Area2D

@export var move_speed: float = 300.0  # Speed set by spawner

@onready var body_rect: ColorRect = $BodyRect
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# Off-screen despawn threshold
const DESPAWN_X: float = -150.0

func _ready() -> void:
	# Connect body entered signal to detect player collision
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	# Move left at current game speed
	position.x -= move_speed * delta
	
	# Despawn when off the left side of the screen
	if position.x < DESPAWN_X:
		queue_free()

func set_size(new_size: Vector2) -> void:
	# Resize the visual rect and collision shape
	if body_rect:
		body_rect.size = new_size
		body_rect.position = -new_size / 2.0
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = new_size

func _on_body_entered(body: Node2D) -> void:
	# If the player touches this obstacle, trigger game over
	if body.is_in_group("player"):
		body.die()
