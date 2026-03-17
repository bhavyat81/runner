# achievement_manager.gd
# Autoload singleton that tracks and saves achievements.
# NOTE: Register as autoload "AchievementManager" in Project Settings → Autoload.
extends Node

signal achievement_unlocked(id: String, title: String)

const ACHIEVEMENTS: Dictionary = {
	"first_haul":   {"title": "First Haul",   "desc": "Collect 100 total bags",           "unlocked": false},
	"iron_truck":   {"title": "Iron Truck",    "desc": "Travel 500m without damage in one run", "unlocked": false},
	"combo_king":   {"title": "Combo King",    "desc": "Reach 10x combo",                 "unlocked": false},
	"speed_demon":  {"title": "Speed Demon",   "desc": "Reach maximum speed",             "unlocked": false},
	"guru":         {"title": "Garbage Guru",  "desc": "Collect 1000 total bags",         "unlocked": false},
	"survivor":     {"title": "Survivor",      "desc": "Complete 5 runs",                 "unlocked": false},
	"boss_slayer":  {"title": "Boss Slayer",   "desc": "Defeat 3 boss tornadoes",         "unlocked": false},
	"untouchable":  {"title": "Untouchable",   "desc": "Complete a run with full health", "unlocked": false},
}

var _run_count: int = 0
var _run_no_damage_distance: float = 0.0
var _run_took_damage: bool = false

func _ready() -> void:
	_load()
	# Connect to GameManager signals once it is ready
	call_deferred("_connect_signals")

func _connect_signals() -> void:
	GameManager.game_state_changed.connect(_on_game_state_changed)
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.combo_changed.connect(_on_combo_changed)
	GameManager.garbage_collected_signal.connect(_on_garbage_collected)
	GameManager.boss_defeated.connect(_on_boss_defeated)

func _process(_delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	# Speed Demon
	if not ACHIEVEMENTS["speed_demon"]["unlocked"] and \
			GameManager.current_speed >= GameManager.MAX_SPEED - 0.5:
		unlock("speed_demon")
	# Iron Truck (no damage 500m)
	if not _run_took_damage:
		_run_no_damage_distance = GameManager.distance
		if not ACHIEVEMENTS["iron_truck"]["unlocked"] and _run_no_damage_distance >= 500.0:
			unlock("iron_truck")

func _on_game_state_changed(state: GameManager.GameState) -> void:
	if state == GameManager.GameState.GAME_OVER:
		_run_count += 1
		# Survivor
		if not ACHIEVEMENTS["survivor"]["unlocked"] and _run_count >= 5:
			unlock("survivor")
		# Untouchable
		if not _run_took_damage and not ACHIEVEMENTS["untouchable"]["unlocked"] and \
				GameManager.health == GameManager.MAX_HEALTH:
			unlock("untouchable")
		_save()
	elif state == GameManager.GameState.PLAYING:
		_run_no_damage_distance = 0.0
		_run_took_damage = false

func _on_health_changed(new_health: int) -> void:
	if new_health < GameManager.MAX_HEALTH:
		_run_took_damage = true

func _on_combo_changed(new_combo: int, _mult: float) -> void:
	if not ACHIEVEMENTS["combo_king"]["unlocked"] and new_combo >= 10:
		unlock("combo_king")

func _on_garbage_collected() -> void:
	var total: int = GameManager.total_bags_lifetime + GameManager.garbage_collected
	if not ACHIEVEMENTS["first_haul"]["unlocked"] and total >= 100:
		unlock("first_haul")
	if not ACHIEVEMENTS["guru"]["unlocked"] and total >= 1000:
		unlock("guru")

func _on_boss_defeated() -> void:
	if not ACHIEVEMENTS["boss_slayer"]["unlocked"] and GameManager.boss_encounters >= 3:
		unlock("boss_slayer")

func unlock(id: String) -> void:
	if not ACHIEVEMENTS.has(id):
		return
	if ACHIEVEMENTS[id]["unlocked"]:
		return
	ACHIEVEMENTS[id]["unlocked"] = true
	achievement_unlocked.emit(id, ACHIEVEMENTS[id]["title"])
	_save()

func get_unlocked_list() -> Array[String]:
	var result: Array[String] = []
	for key in ACHIEVEMENTS:
		if ACHIEVEMENTS[key]["unlocked"]:
			result.append(key)
	return result

func _save() -> void:
	var data: Dictionary = {}
	for key in ACHIEVEMENTS:
		data[key] = ACHIEVEMENTS[key]["unlocked"]
	data["run_count"] = _run_count
	var file := FileAccess.open("user://achievements.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _load() -> void:
	if not FileAccess.file_exists("user://achievements.json"):
		return
	var file := FileAccess.open("user://achievements.json", FileAccess.READ)
	if not file:
		return
	var content := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(content) != OK or not json.data is Dictionary:
		return
	var d: Dictionary = json.data
	for key in ACHIEVEMENTS:
		if d.has(key):
			ACHIEVEMENTS[key]["unlocked"] = bool(d[key])
	_run_count = int(d.get("run_count", 0))
