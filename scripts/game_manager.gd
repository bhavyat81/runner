# game_manager.gd
# Global autoload singleton. Manages game state, score, garbage count, speed, and health.
extends Node

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }

signal score_changed(new_score: int)
signal game_state_changed(new_state: GameState)
signal health_changed(new_health: int)
signal combo_changed(new_combo: int, new_multiplier: float)
signal garbage_collected_signal
signal speed_boost_activated

var current_state: GameState = GameState.MENU
var score: int = 0
var high_score: int = 0
var garbage_collected: int = 0
var distance: float = 0.0

const BASE_SPEED: float = 10.0
const MAX_SPEED: float = 30.0
const SPEED_INCREMENT: float = 0.8
const MAX_HEALTH: int = 100
const BOOST_DURATION: float = 3.0
const BOOST_MULTIPLIER: float = 1.5

var current_speed: float = BASE_SPEED
var health: int = MAX_HEALTH

# Combo system
var combo: int = 0
var combo_multiplier: float = 1.0
var max_combo: int = 0

# Speed boost
var speed_boost_active: bool = false
var speed_boost_timer: float = 0.0
var _base_speed_at_boost: float = BASE_SPEED

# Progressive difficulty
var difficulty_wave: int = 0

func _ready() -> void:
	_load_high_score()

func start_game() -> void:
	score = 0
	garbage_collected = 0
	distance = 0.0
	health = MAX_HEALTH
	current_speed = BASE_SPEED
	combo = 0
	combo_multiplier = 1.0
	max_combo = 0
	speed_boost_active = false
	speed_boost_timer = 0.0
	difficulty_wave = 0
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
	combo += 1
	if combo > max_combo:
		max_combo = combo
	_update_combo_multiplier()
	combo_changed.emit(combo, combo_multiplier)
	add_score(int(10 * combo_multiplier))
	garbage_collected_signal.emit()

func break_combo() -> void:
	if combo > 0:
		combo = 0
		combo_multiplier = 1.0
		combo_changed.emit(combo, combo_multiplier)

func _update_combo_multiplier() -> void:
	if combo >= 10:
		combo_multiplier = 4.0
	elif combo >= 6:
		combo_multiplier = 3.0
	elif combo >= 3:
		combo_multiplier = 2.0
	else:
		combo_multiplier = 1.0

func damage_health(amount: int) -> void:
	if speed_boost_active:
		return  # Invincible during boost
	health = max(0, health - amount)
	health_changed.emit(health)
	break_combo()

func activate_speed_boost() -> void:
	_base_speed_at_boost = current_speed
	speed_boost_active = true
	speed_boost_timer = BOOST_DURATION
	current_speed = minf(current_speed * BOOST_MULTIPLIER, MAX_SPEED)
	speed_boost_activated.emit()

func get_difficulty_wave() -> int:
	return int(distance / 200.0)

func update_game(delta: float) -> void:
	if current_state != GameState.PLAYING:
		return
	distance += current_speed * delta
	difficulty_wave = get_difficulty_wave()

	# Update speed boost countdown
	if speed_boost_active:
		speed_boost_timer -= delta
		# Keep base speed progressing naturally during boost
		_base_speed_at_boost = minf(_base_speed_at_boost + SPEED_INCREMENT * delta, MAX_SPEED)
		if speed_boost_timer <= 0.0:
			speed_boost_active = false
			speed_boost_timer = 0.0
			current_speed = _base_speed_at_boost
	else:
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

