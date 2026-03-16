# game_manager.gd
# Global autoload singleton. Manages game state, score, garbage count, speed, and health.
extends Node

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

signal score_changed(new_score: int)
signal game_state_changed(new_state: GameState)
signal health_changed(new_health: int)

var current_state: GameState = GameState.MENU
var score: int = 0
var high_score: int = 0
var garbage_collected: int = 0
var distance: float = 0.0

const BASE_SPEED: float = 10.0
const MAX_SPEED: float = 30.0
const SPEED_INCREMENT: float = 0.8
const MAX_HEALTH: int = 100

var current_speed: float = BASE_SPEED
var health: int = MAX_HEALTH

func _ready() -> void:
	_load_high_score()

func start_game() -> void:
	score = 0
	garbage_collected = 0
	distance = 0.0
	health = MAX_HEALTH
	current_speed = BASE_SPEED
	current_state = GameState.PLAYING
	game_state_changed.emit(current_state)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func end_game() -> void:
	current_state = GameState.GAME_OVER
	if score > high_score:
		high_score = score
		_save_high_score()
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

func collect_garbage() -> void:
	garbage_collected += 1
	add_score(10)

func damage_health(amount: int) -> void:
	health = max(0, health - amount)
	health_changed.emit(health)

func update_game(delta: float) -> void:
	if current_state != GameState.PLAYING:
		return
	distance += current_speed * delta
	current_speed = minf(current_speed + SPEED_INCREMENT * delta, MAX_SPEED)

func _save_high_score() -> void:
	var data := {"high_score": high_score}
	var file := FileAccess.open("user://save_data.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _load_high_score() -> void:
	if FileAccess.file_exists("user://save_data.json"):
		var file := FileAccess.open("user://save_data.json", FileAccess.READ)
		if file:
			var content := file.get_as_text()
			file.close()
			var json := JSON.new()
			if json.parse(content) == OK and json.data is Dictionary:
				high_score = int(json.data.get("high_score", 0))
