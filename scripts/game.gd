# game.gd
# Main game scene controller. Manages spawning, scoring, HUD, and game over.
extends Node2D

# References to scene nodes
@onready var player: CharacterBody2D = $Player
@onready var score_label: Label = $HUD/ScoreLabel
@onready var pause_button: Button = $HUD/PauseButton
@onready var obstacle_spawner: Timer = $ObstacleSpawner
@onready var score_timer: Timer = $ScoreTimer
@onready var ground: StaticBody2D = $Ground
@onready var obstacle_container: Node2D = $Obstacles
@onready var game_over_overlay: Control = $HUD/GameOverOverlay

# Obstacle scene to instantiate
const OBSTACLE_SCENE = preload("res://scenes/obstacle.tscn")

func _ready() -> void:
	# Connect player death signal
	player.died.connect(_on_player_died)
	
	# Connect timer signals
	obstacle_spawner.timeout.connect(_on_obstacle_spawner_timeout)
	score_timer.timeout.connect(_on_score_timer_timeout)
	
	# Connect pause button
	pause_button.pressed.connect(_on_pause_button_pressed)
	
	# Connect game over overlay buttons
	game_over_overlay.get_node("Panel/VBoxContainer/ButtonRow/RestartButton").pressed.connect(_on_restart_pressed)
	game_over_overlay.get_node("Panel/VBoxContainer/ButtonRow/MenuButton").pressed.connect(_on_menu_pressed)
	
	# Hide game over overlay at start
	game_over_overlay.visible = false
	
	# Start timers
	obstacle_spawner.start()
	score_timer.start()
	
	# Update score display
	_update_score_display()

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	# Update game speed over time
	GameManager.update_speed(delta)
	
	# Sync current speed to all active obstacles
	for obstacle in obstacle_container.get_children():
		obstacle.move_speed = GameManager.current_speed

func _on_obstacle_spawner_timeout() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	_spawn_obstacle()
	# Dynamic spawn interval: decreases as speed increases
	var base_interval = 1.8
	var min_interval = 0.7
	var speed_ratio = (GameManager.current_speed - GameManager.BASE_SPEED) / (GameManager.MAX_SPEED - GameManager.BASE_SPEED)
	var interval = lerp(base_interval, min_interval, speed_ratio)
	obstacle_spawner.wait_time = interval + randf_range(-0.2, 0.2)
	obstacle_spawner.start()

func _spawn_obstacle() -> void:
	var obstacle = OBSTACLE_SCENE.instantiate()
	obstacle_container.add_child(obstacle)
	
	# Randomise obstacle dimensions
	var width = randf_range(30, 60)
	var height = randf_range(40, 90)
	obstacle.set_size(Vector2(width, height))
	
	# Place obstacle at the right edge, sitting on the ground surface (y = 648)
	obstacle.position = Vector2(1380.0, 648.0 - height / 2.0)
	obstacle.move_speed = GameManager.current_speed
	
	# Random colour for variety
	var colors = [
		Color(0.96, 0.26, 0.21),  # Red
		Color(1.0, 0.60, 0.00),   # Orange
		Color(0.93, 0.12, 0.39),  # Pink
	]
	obstacle.get_node("BodyRect").color = colors[randi() % colors.size()]

func _on_score_timer_timeout() -> void:
	if GameManager.current_state == GameManager.GameState.PLAYING:
		GameManager.add_score(1)
		_update_score_display()

func _update_score_display() -> void:
	score_label.text = "Score: " + str(GameManager.score)

func _on_player_died() -> void:
	obstacle_spawner.stop()
	score_timer.stop()
	GameManager.end_game()
	game_over_overlay.get_node("Panel/VBoxContainer/FinalScoreLabel").text = "Score: " + str(GameManager.score)
	game_over_overlay.get_node("Panel/VBoxContainer/HighScoreLabel").text = "Best: " + str(GameManager.high_score)
	game_over_overlay.visible = true

func _on_pause_button_pressed() -> void:
	if GameManager.current_state == GameManager.GameState.PLAYING:
		GameManager.pause_game()
		pause_button.text = "▶"
	elif GameManager.current_state == GameManager.GameState.PAUSED:
		GameManager.resume_game()
		pause_button.text = "⏸"

func _on_restart_pressed() -> void:
	GameManager.start_game()

func _on_menu_pressed() -> void:
	GameManager.go_to_main_menu()
