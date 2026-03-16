# game_manager.gd
# Global autoload script that manages game state, score, and scene transitions.
extends Node

# Game states
enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

# Signals
signal score_changed(new_score: int)
signal game_state_changed(new_state: GameState)
signal game_over(final_score: int)

# Current state
var current_state: GameState = GameState.MENU
var score: int = 0
var high_score: int = 0

# Speed settings
const BASE_SPEED: float = 300.0
const MAX_SPEED: float = 700.0
const SPEED_INCREMENT: float = 10.0  # Speed added per second
var current_speed: float = BASE_SPEED

func _ready() -> void:
	# Load high score from save data
	_load_high_score()

func start_game() -> void:
	score = 0
	current_speed = BASE_SPEED
	current_state = GameState.PLAYING
	game_state_changed.emit(current_state)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func end_game() -> void:
	current_state = GameState.GAME_OVER
	if score > high_score:
		high_score = score
		_save_high_score()
	game_over.emit(score)
	game_state_changed.emit(current_state)

func go_to_main_menu() -> void:
	current_state = GameState.MENU
	game_state_changed.emit(current_state)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func pause_game() -> void:
	if current_state == GameState.PLAYING:
		current_state = GameState.PAUSED
		get_tree().paused = true
		game_state_changed.emit(current_state)

func resume_game() -> void:
	if current_state == GameState.PAUSED:
		current_state = GameState.PLAYING
		get_tree().paused = false
		game_state_changed.emit(current_state)

func add_score(points: int) -> void:
	score += points
	score_changed.emit(score)

func update_speed(delta: float) -> void:
	# Gradually increase speed over time
	current_speed = min(current_speed + SPEED_INCREMENT * delta, MAX_SPEED)

func _save_high_score() -> void:
	var save_data = {"high_score": high_score}
	var file = FileAccess.open("user://save_data.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func _load_high_score() -> void:
	if FileAccess.file_exists("user://save_data.json"):
		var file = FileAccess.open("user://save_data.json", FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			if parse_result == OK:
				var data = json.data
				if data is Dictionary and data.has("high_score"):
					high_score = data["high_score"]
