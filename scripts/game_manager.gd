# game_manager.gd
# Global autoload singleton. Manages game state, score, garbage count, speed, health,
# power-ups, XP/levels, coins, daily challenges, boss tracking, and leaderboard.
extends Node

enum GameState { MENU, PLAYING, PAUSED, GAME_OVER }
enum PowerupType { NONE, SHIELD, MAGNET, SLOW_MO, DOUBLE_POINTS }
enum GameEnvironment { CITY, HIGHWAY, BRIDGE, TUNNEL }

signal score_changed(new_score: int)
signal game_state_changed(new_state: GameState)
signal health_changed(new_health: int)
signal combo_changed(new_combo: int, new_multiplier: float)
signal garbage_collected_signal
signal speed_boost_activated
signal powerup_activated(type: PowerupType)
signal powerup_expired
signal level_up(new_level: int)
signal daily_challenge_completed(index: int)
signal boss_spawned
signal boss_defeated
signal environment_changed(env: GameEnvironment)

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

# Power-up system
var active_powerup: PowerupType = PowerupType.NONE
var powerup_timer: float = 0.0
const POWERUP_DURATIONS: Dictionary = {
	PowerupType.SHIELD: 5.0,
	PowerupType.MAGNET: 8.0,
	PowerupType.SLOW_MO: 3.0,
	PowerupType.DOUBLE_POINTS: 10.0,
}

# Boss encounters
var last_boss_distance: float = -999.0
var boss_encounters: int = 0
var boss_active: bool = false
const BOSS_INTERVAL: float = 500.0

# Day/Night cycle: environment
var current_environment: GameEnvironment = GameEnvironment.CITY

# Coins and skins
var coins: int = 0
var total_bags_lifetime: int = 0
var selected_skin: int = 0
var unlocked_skins: Array[bool] = [true, false, false, false, false]

const SKIN_COSTS: Array[int] = [0, 50, 100, 200, 300]
const SKIN_NAMES: Array[String] = ["Default", "Fire Truck", "Ice Cream Truck", "Monster Truck", "Neon Truck"]

# XP and Level
var xp: int = 0
var level: int = 1
const LEVEL_THRESHOLDS: Array[int] = [0, 100, 300, 600, 1000, 1500, 2200, 3000, 4000, 5500]

# Daily challenges
var daily_challenges: Array[Dictionary] = []
var daily_challenge_progress: Array[int] = [0, 0, 0]
var _daily_challenge_day: int = -1
const CHALLENGE_POOL: Array[Dictionary] = [
	{"desc": "Collect 50 bags in one run", "type": "bags_run", "target": 50, "reward": 25},
	{"desc": "Reach 1000m without boost", "type": "dist_no_boost", "target": 1000, "reward": 25},
	{"desc": "Get 15x combo", "type": "combo", "target": 15, "reward": 25},
	{"desc": "Survive 3 boss encounters", "type": "boss", "target": 3, "reward": 25},
	{"desc": "Collect 200 bags total today", "type": "bags_day", "target": 200, "reward": 25},
	{"desc": "Reach 2000m", "type": "distance", "target": 2000, "reward": 25},
]

# Leaderboard
var leaderboard: Array[Dictionary] = []
const MAX_LEADERBOARD: int = 10

# Run-specific trackers for challenge tracking
var _run_bags: int = 0
var _run_dist_no_boost: float = 0.0
var _boost_used_this_run: bool = false
var _bags_today: int = 0

func _ready() -> void:
	_load_save_data()
	_load_leaderboard()
	_init_daily_challenges()

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
	active_powerup = PowerupType.NONE
	powerup_timer = 0.0
	boss_active = false
	last_boss_distance = -BOSS_INTERVAL
	current_environment = GameEnvironment.CITY
	# Reset run trackers
	_run_bags = 0
	_run_dist_no_boost = 0.0
	_boost_used_this_run = false
	current_state = GameState.PLAYING
	game_state_changed.emit(current_state)
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func end_game() -> void:
	current_state = GameState.GAME_OVER
	if score > high_score:
		high_score = score
	# Earn XP
	var earned_xp: int = int(distance / 10.0) + garbage_collected * 5 + score / 20
	xp += earned_xp
	_check_level_up()
	# Update lifetime stats
	total_bags_lifetime += garbage_collected
	_bags_today += garbage_collected
	# Check run-based daily challenges
	_check_daily_challenges_end_of_run()
	_save_save_data()
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
	var multiplied: int = points
	if active_powerup == PowerupType.DOUBLE_POINTS:
		multiplied *= 2
	score += multiplied
	score_changed.emit(score)

func collect_garbage() -> void:
	garbage_collected += 1
	_run_bags += 1
	combo += 1
	if combo > max_combo:
		max_combo = combo
	_update_combo_multiplier()
	combo_changed.emit(combo, combo_multiplier)
	coins += 1
	add_score(int(10 * combo_multiplier))
	garbage_collected_signal.emit()
	# Check daily challenge progress for combo
	_update_daily_challenge_progress("combo", combo)
	_update_daily_challenge_progress("bags_day", _bags_today + garbage_collected)

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
	if speed_boost_active or active_powerup == PowerupType.SHIELD:
		return  # Invincible during boost or shield
	health = max(0, health - amount)
	health_changed.emit(health)
	break_combo()

func activate_speed_boost() -> void:
	_base_speed_at_boost = current_speed
	speed_boost_active = true
	speed_boost_timer = BOOST_DURATION
	current_speed = minf(current_speed * BOOST_MULTIPLIER, MAX_SPEED)
	_boost_used_this_run = true
	speed_boost_activated.emit()

func activate_powerup(type: PowerupType) -> void:
	active_powerup = type
	powerup_timer = POWERUP_DURATIONS.get(type, 5.0)
	if type == PowerupType.SLOW_MO:
		current_speed = current_speed * 0.6
	powerup_activated.emit(type)

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
		_base_speed_at_boost = minf(_base_speed_at_boost + SPEED_INCREMENT * delta, MAX_SPEED)
		if speed_boost_timer <= 0.0:
			speed_boost_active = false
			speed_boost_timer = 0.0
			current_speed = _base_speed_at_boost
	else:
		current_speed = minf(current_speed + SPEED_INCREMENT * delta, MAX_SPEED)

	# Update power-up countdown
	if active_powerup != PowerupType.NONE:
		powerup_timer -= delta
		if powerup_timer <= 0.0:
			if active_powerup == PowerupType.SLOW_MO:
				# Restore speed to natural progression speed
				current_speed = minf(current_speed / 0.6, MAX_SPEED)
			active_powerup = PowerupType.NONE
			powerup_timer = 0.0
			powerup_expired.emit()

	# Track no-boost distance for daily challenge
	if not _boost_used_this_run:
		_run_dist_no_boost = distance

	# Check boss spawn
	if not boss_active and (distance - last_boss_distance) >= BOSS_INTERVAL:
		last_boss_distance = distance
		boss_spawned.emit()

	# Update environment
	var new_env: GameEnvironment = _get_environment_for_distance(distance)
	if new_env != current_environment:
		current_environment = new_env
		environment_changed.emit(current_environment)

func _get_environment_for_distance(d: float) -> GameEnvironment:
	var cycle_pos: int = int(d / 400.0) % 4
	match cycle_pos:
		0: return GameEnvironment.CITY
		1: return GameEnvironment.HIGHWAY
		2: return GameEnvironment.BRIDGE
		3: return GameEnvironment.TUNNEL
	return GameEnvironment.CITY

# --- XP / Level ---
func _check_level_up() -> void:
	var new_level: int = 1
	for i in range(LEVEL_THRESHOLDS.size()):
		if xp >= LEVEL_THRESHOLDS[i]:
			new_level = i + 1
	if new_level > level:
		level = new_level
		level_up.emit(level)

func get_xp_for_level(lvl: int) -> int:
	if lvl - 1 < LEVEL_THRESHOLDS.size():
		return LEVEL_THRESHOLDS[lvl - 1]
	return LEVEL_THRESHOLDS[-1] + (lvl - LEVEL_THRESHOLDS.size()) * 2000

func get_next_level_xp() -> int:
	return get_xp_for_level(level + 1)

# --- Skins ---
func buy_skin(skin_id: int) -> bool:
	if skin_id < 0 or skin_id >= SKIN_COSTS.size():
		return false
	if unlocked_skins[skin_id]:
		return false
	if coins < SKIN_COSTS[skin_id]:
		return false
	coins -= SKIN_COSTS[skin_id]
	unlocked_skins[skin_id] = true
	_save_save_data()
	return true

func select_skin(skin_id: int) -> void:
	if skin_id >= 0 and skin_id < SKIN_COSTS.size() and unlocked_skins[skin_id]:
		selected_skin = skin_id
		_save_save_data()

# --- Daily challenges ---
func _init_daily_challenges() -> void:
	var date := Time.get_date_dict_from_system()
	var today: int = date["month"] * 31 + date["day"]
	var loaded_day: int = _daily_challenge_day
	if loaded_day != today:
		# New day — pick 3 challenges based on day-of-year seed
		_daily_challenge_day = today
		daily_challenges.clear()
		daily_challenge_progress = [0, 0, 0]
		_bags_today = 0
		var seed_val: int = today * 31337
		for i in range(3):
			var idx: int = (seed_val + i * 7) % CHALLENGE_POOL.size()
			daily_challenges.append(CHALLENGE_POOL[idx].duplicate())
		_save_save_data()

func _update_daily_challenge_progress(type: String, value: int) -> void:
	for i in range(daily_challenges.size()):
		if daily_challenges[i].get("type", "") == type:
			if daily_challenge_progress[i] < daily_challenges[i]["target"]:
				daily_challenge_progress[i] = maxi(daily_challenge_progress[i], value)
				if daily_challenge_progress[i] >= daily_challenges[i]["target"]:
					coins += daily_challenges[i].get("reward", 25)
					daily_challenge_completed.emit(i)

func _check_daily_challenges_end_of_run() -> void:
	_update_daily_challenge_progress("bags_run", _run_bags)
	_update_daily_challenge_progress("dist_no_boost", int(_run_dist_no_boost))
	_update_daily_challenge_progress("boss", boss_encounters)
	_update_daily_challenge_progress("distance", int(distance))

# --- Leaderboard ---
func try_add_leaderboard(initials: String, p_score: int, p_distance: float, p_bags: int) -> int:
	# Returns the rank (1-based) or -1 if not qualified
	var entry := {"initials": initials.to_upper().left(3), "score": p_score,
		"distance": int(p_distance), "bags": p_bags}
	leaderboard.append(entry)
	leaderboard.sort_custom(func(a, b): return a["score"] > b["score"])
	if leaderboard.size() > MAX_LEADERBOARD:
		leaderboard.resize(MAX_LEADERBOARD)
	var rank: int = -1
	for i in range(leaderboard.size()):
		if leaderboard[i]["initials"] == entry["initials"] and leaderboard[i]["score"] == entry["score"]:
			rank = i + 1
			break
	_save_leaderboard()
	return rank

func qualifies_for_leaderboard(p_score: int) -> bool:
	if leaderboard.size() < MAX_LEADERBOARD:
		return true
	return p_score > leaderboard[-1]["score"]

# --- Save / Load ---
func _save_save_data() -> void:
	var data: Dictionary = {
		"high_score": high_score,
		"coins": coins,
		"total_bags_lifetime": total_bags_lifetime,
		"selected_skin": selected_skin,
		"unlocked_skins": unlocked_skins,
		"xp": xp,
		"level": level,
		"daily_challenge_day": _daily_challenge_day,
		"daily_challenge_progress": daily_challenge_progress,
		"bags_today": _bags_today,
		"boss_encounters": boss_encounters,
	}
	var file := FileAccess.open("user://save_data.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _load_save_data() -> void:
	if not FileAccess.file_exists("user://save_data.json"):
		return
	var file := FileAccess.open("user://save_data.json", FileAccess.READ)
	if not file:
		return
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK or not json.data is Dictionary:
		return
	var d: Dictionary = json.data
	high_score = int(d.get("high_score", 0))
	coins = int(d.get("coins", 0))
	total_bags_lifetime = int(d.get("total_bags_lifetime", 0))
	selected_skin = int(d.get("selected_skin", 0))
	var us = d.get("unlocked_skins", [true, false, false, false, false])
	for i in range(minf(us.size(), unlocked_skins.size())):
		unlocked_skins[i] = bool(us[i])
	xp = int(d.get("xp", 0))
	level = int(d.get("level", 1))
	_daily_challenge_day = int(d.get("daily_challenge_day", -1))
	var prog = d.get("daily_challenge_progress", [0, 0, 0])
	for i in range(minf(prog.size(), daily_challenge_progress.size())):
		daily_challenge_progress[i] = int(prog[i])
	_bags_today = int(d.get("bags_today", 0))
	boss_encounters = int(d.get("boss_encounters", 0))

func _save_leaderboard() -> void:
	var file := FileAccess.open("user://leaderboard.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(leaderboard))
		file.close()

func _load_leaderboard() -> void:
	if not FileAccess.file_exists("user://leaderboard.json"):
		return
	var file := FileAccess.open("user://leaderboard.json", FileAccess.READ)
	if not file:
		return
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK:
		return
	if json.data is Array:
		leaderboard.clear()
		for entry in json.data:
			if entry is Dictionary:
				leaderboard.append(entry)

# Legacy save helper kept for compatibility
func _save_high_score() -> void:
	_save_save_data()

func _load_high_score() -> void:
	_load_save_data()

