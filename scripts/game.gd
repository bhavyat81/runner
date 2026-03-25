# game.gd
# Main 3D game scene controller. v1.01 - All 20 features.
extends Node3D

@onready var truck: CharacterBody3D = $Truck
@onready var road_container: Node3D = $RoadContainer
@onready var building_container: Node3D = $BuildingContainer
@onready var obstacle_container: Node3D = $ObstacleContainer
@onready var marker_container: Node3D = $MarkerContainer
@onready var score_label: Label = $HUD/ScoreLabel
@onready var garbage_label: Label = $HUD/GarbageLabel
@onready var distance_label: Label = $HUD/DistanceLabel
@onready var health_label: Label = $HUD/HealthLabel
@onready var health_bar: ProgressBar = $HUD/HealthBar
@onready var combo_label: Label = $HUD/ComboLabel
@onready var obstacle_timer: Timer = $ObstacleTimer
@onready var garbage_timer: Timer = $GarbageTimer
@onready var boost_timer: Timer = $BoostTimer
@onready var camera: Camera3D = $Truck/Camera3D
@onready var sun: DirectionalLight3D = $Sun
@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var collect_sound: AudioStreamPlayer = $CollectSound
@onready var damage_sound: AudioStreamPlayer = $DamageSound
@onready var lane_switch_sound: AudioStreamPlayer = $LaneSwitchSound
@onready var death_sound: AudioStreamPlayer = $DeathSound
@onready var boost_sound: AudioStreamPlayer = $BoostSound

const ROAD_SEGMENT_SCENE := preload("res://scenes/road_segment.tscn")
const BUILDING_SCENE := preload("res://scenes/building.tscn")
const OBSTACLE_SCENE := preload("res://scenes/obstacle.tscn")
const MARKER_SCENE := preload("res://scenes/garbage_marker.tscn")
const SPEED_BOOST_SCENE := preload("res://scenes/speed_boost.tscn")
const POWERUP_SCENE := preload("res://scenes/powerup.tscn")
const TRAFFIC_CAR_SCENE := preload("res://scenes/traffic_car.tscn")
const COIN_SCENE := preload("res://scenes/coin.tscn")

const SEGMENT_LENGTH: float = 40.0
const NUM_SEGMENTS: int = 8
const SPAWN_Z: float = -90.0
const DESPAWN_Z: float = 25.0
const BUILDING_X_NEAR: float = 9.0
const BUILDING_X_FAR: float = 15.0
const BUILDINGS_PER_SEGMENT: int = 2
const MOON_POSITION := Vector3(0.0, 30.0, -200.0)
const OBSTACLE_TIMER_MIN_RANDOMNESS: float = 0.0
const OBSTACLE_TIMER_MAX_RANDOMNESS: float = 0.8
const HEALTH_GOOD_THRESHOLD: int = 60
const HEALTH_WARNING_THRESHOLD: int = 30
const BASE_FOV: float = 60.0
const MAX_FOV: float = 75.0

var road_segments: Array[Node3D] = []
var left_buildings: Array[Node3D] = []
var right_buildings: Array[Node3D] = []
var left_buildings_far: Array[Node3D] = []
var right_buildings_far: Array[Node3D] = []

var boost_container: Node3D = null
var powerup_container: Node3D = null
var traffic_container: Node3D = null
var flying_container: Node3D = null
var coin_container: Node3D = null
var _coin_timer: float = 8.0

var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var camera_base_position: Vector3

var _style_health_good: StyleBoxFlat = StyleBoxFlat.new()
var _style_health_warning: StyleBoxFlat = StyleBoxFlat.new()
var _style_health_critical: StyleBoxFlat = StyleBoxFlat.new()

var pause_menu_instance: Control = null

var _star_nodes: Array = []
var _star_twinkle_speeds: Array = []
var _star_twinkle_offsets: Array = []
var _star_time: float = 0.0

var _flash_rect: ColorRect = null
const _flash_duration: float = 0.3
var _flash_timer: float = 0.0

var _combo_label: Label = null
var _combo_tween: Tween = null
var _powerup_hud_label: Label = null
var _challenge_hud_label: Label = null
var _coin_hud_label: Label = null
var _toast_label: Label = null
var _toast_tween: Tween = null
var _phase_label: Label = null
var _phase_tween: Tween = null
var _pre_power_hud_label: Label = null
var _ghost_tween: Tween = null
const HEADSTART_FOV: float = 85.0
const GHOST_MODE_ALPHA: float = 0.35

var _moon_nodes: Array[Node3D] = []

# Day/Night: int keys 0=Night 1=Dawn 2=Day 3=Dusk
const DAY_CONFIGS: Dictionary = {
0: {"sun_color": Color(0.3, 0.35, 0.55), "sun_energy": 0.2,
"ambient": Color(0.15, 0.18, 0.35), "ambient_e": 0.35, "sky": Color(0.03, 0.03, 0.12)},
1: {"sun_color": Color(1.0, 0.6, 0.3), "sun_energy": 0.8,
"ambient": Color(0.5, 0.35, 0.25), "ambient_e": 0.5, "sky": Color(0.25, 0.12, 0.06)},
2: {"sun_color": Color(1.0, 0.95, 0.85), "sun_energy": 1.4,
"ambient": Color(0.5, 0.55, 0.7), "ambient_e": 0.7, "sky": Color(0.2, 0.35, 0.6)},
3: {"sun_color": Color(0.9, 0.5, 0.2), "sun_energy": 0.7,
"ambient": Color(0.4, 0.25, 0.3), "ambient_e": 0.45, "sky": Color(0.18, 0.1, 0.15)},
}

enum WeatherType { CLEAR, RAIN, FOG, THUNDERSTORM }
var _current_weather: int = WeatherType.CLEAR
var _weather_timer: float = 60.0
var _thunder_timer: float = 0.0
var _rain_nodes: Array[Node3D] = []

var _fly_timer: float = 15.0
var _traffic_timer: float = 5.0
var _powerup_timer: float = 25.0

func _ready() -> void:
	truck.died.connect(_on_truck_died)
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.combo_changed.connect(_on_combo_changed)
	GameManager.garbage_collected_signal.connect(_on_garbage_collected)
	GameManager.speed_boost_activated.connect(_on_speed_boost_activated)
	GameManager.powerup_activated.connect(_on_powerup_activated)
	GameManager.powerup_expired.connect(_on_powerup_expired)
	GameManager.pre_game_power_expired.connect(_on_pre_game_power_expired)
	var am := get_node_or_null("/root/AchievementManager")
	if am:
		am.achievement_unlocked.connect(_on_achievement_unlocked)
	_setup_road()
	_setup_buildings()
	_create_moon()
	_create_stars()
	_setup_screen_flash()
	_setup_combo_announcer()
	_setup_powerup_hud()
	_setup_challenge_hud()
	_setup_phase_label()
	_setup_toast()
	_setup_pre_power_hud()
	obstacle_timer.timeout.connect(_spawn_obstacle)
	garbage_timer.timeout.connect(_spawn_garbage_marker)
	boost_timer.timeout.connect(_spawn_speed_boost)
	obstacle_timer.start(4.0)
	garbage_timer.start(2.0)
	boost_timer.start(randf_range(15.0, 25.0))
	boost_container = Node3D.new()
	boost_container.name = "BoostContainer"
	add_child(boost_container)
	powerup_container = Node3D.new()
	powerup_container.name = "PowerupContainer"
	add_child(powerup_container)
	traffic_container = Node3D.new()
	traffic_container.name = "TrafficContainer"
	add_child(traffic_container)
	flying_container = Node3D.new()
	flying_container.name = "FlyingContainer"
	add_child(flying_container)
	coin_container = Node3D.new()
	coin_container.name = "CoinContainer"
	add_child(coin_container)
	_setup_coin_hud()
	health_bar.max_value = GameManager.MAX_HEALTH
	health_bar.value = GameManager.health
	_style_health_good.bg_color = Color(0.1, 0.8, 0.1)
	_style_health_warning.bg_color = Color(1.0, 0.75, 0.0)
	_style_health_critical.bg_color = Color(0.9, 0.1, 0.1)
	_update_health_bar_color(GameManager.health)
	camera_base_position = camera.position
	camera.fov = BASE_FOV
	combo_label.visible = false
	var pause_menu_scene := load("res://scenes/pause_menu.tscn")
	if pause_menu_scene:
		pause_menu_instance = pause_menu_scene.instantiate()
		$HUD.add_child(pause_menu_instance)
		pause_menu_instance.hide()
	# Activate visual effects for pre-game power
	_activate_pre_game_power_visuals()

func _process(delta: float) -> void:
	if GameManager.current_state == GameManager.GameState.PAUSED:
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	GameManager.update_game(delta)
	var spd: float = GameManager.current_speed
	for seg in road_segments:
		seg.position.z += spd * delta
		if seg.position.z >= DESPAWN_Z:
			seg.position.z -= SEGMENT_LENGTH * NUM_SEGMENTS
	for b in left_buildings:
		b.position.z += spd * delta
		if b.position.z >= DESPAWN_Z:
			b.position.z -= SEGMENT_LENGTH * NUM_SEGMENTS
	for b in right_buildings:
		b.position.z += spd * delta
		if b.position.z >= DESPAWN_Z:
			b.position.z -= SEGMENT_LENGTH * NUM_SEGMENTS
	for b in left_buildings_far:
		b.position.z += spd * delta
		if b.position.z >= DESPAWN_Z:
			b.position.z -= SEGMENT_LENGTH * NUM_SEGMENTS
	for b in right_buildings_far:
		b.position.z += spd * delta
		if b.position.z >= DESPAWN_Z:
			b.position.z -= SEGMENT_LENGTH * NUM_SEGMENTS
	for child in obstacle_container.get_children():
		child.position.z += spd * delta
		if child.position.z >= DESPAWN_Z:
			child.queue_free()
	for child in marker_container.get_children():
		child.position.z += spd * delta
		if child.position.z >= DESPAWN_Z:
			child.queue_free()
	if boost_container:
		for child in boost_container.get_children():
			child.position.z += spd * delta
			if child.position.z >= DESPAWN_Z:
				child.queue_free()
	if powerup_container:
		for child in powerup_container.get_children():
			child.position.z += spd * delta
			if child.position.z >= DESPAWN_Z:
				child.queue_free()
	if traffic_container:
		for child in traffic_container.get_children():
			var speed_offset = child.get("speed_offset")
			var car_spd: float = spd * (1.0 + (speed_offset if speed_offset != null else 0.0))
			child.position.z += car_spd * delta
			if child.position.z >= DESPAWN_Z or child.position.z <= SPAWN_Z * 2.0:
				child.queue_free()
	if coin_container:
		for child in coin_container.get_children():
			child.position.z += spd * delta
			if child.position.z >= DESPAWN_Z:
				child.queue_free()
	if truck and not truck.is_dead:
		truck.invincible = GameManager.speed_boost_active or \
			GameManager.active_powerup == GameManager.PowerupType.SHIELD
	if GameManager.active_powerup == GameManager.PowerupType.MAGNET:
		var truck_pos: Vector3 = truck.global_position
		for child in marker_container.get_children():
			var dist3d: float = child.global_position.distance_to(truck_pos)
			if dist3d < 15.0 and not child.get("collected"):
				var dir3d: Vector3 = (truck_pos - child.global_position).normalized()
				child.position += dir3d * 8.0 * delta
		if coin_container:
			for child in coin_container.get_children():
				var dist3d: float = child.global_position.distance_to(truck_pos)
				if dist3d < 15.0 and not child.get("_collected"):
					var dir3d: Vector3 = (truck_pos - child.global_position).normalized()
					child.position += dir3d * 10.0 * delta
	_powerup_timer -= delta
	if _powerup_timer <= 0.0:
		_spawn_powerup()
		_powerup_timer = randf_range(20.0, 35.0)
	_traffic_timer -= delta
	if _traffic_timer <= 0.0:
		_spawn_traffic_car()
		var wave_f: float = float(GameManager.difficulty_wave)
		_traffic_timer = randf_range(maxf(3.0 - wave_f * 0.3, 1.5), maxf(8.0 - wave_f * 0.5, 3.0))
	_fly_timer -= delta
	if _fly_timer <= 0.0:
		_spawn_flying_object()
		_fly_timer = randf_range(10.0, 20.0)
	_coin_timer -= delta
	if _coin_timer <= 0.0:
		_spawn_coin_line()
		_coin_timer = randf_range(5.0, 12.0)
	_weather_timer -= delta
	if _weather_timer <= 0.0:
		_pick_random_weather()
		_weather_timer = randf_range(60.0, 90.0)
	if _current_weather == WeatherType.THUNDERSTORM:
		_thunder_timer -= delta
		if _thunder_timer <= 0.0:
			_flash_screen(Color(1.0, 1.0, 1.0))
			shake_camera(0.4, 0.3)
			_thunder_timer = randf_range(4.0, 10.0)
	_update_day_night()
	score_label.text = "Score: %d" % GameManager.score
	garbage_label.text = "Bags: %d" % GameManager.garbage_collected
	distance_label.text = "%dm" % int(GameManager.distance)
	health_label.text = "HP: %d" % GameManager.health
	if _coin_hud_label:
		_coin_hud_label.text = "🪙 %d" % GameManager.coins
	_update_fov(delta)
	_update_powerup_hud()
	_update_pre_power_hud()
	_update_challenge_hud_labels()
	if shake_duration > 0.0:
		shake_duration -= delta
		if shake_duration <= 0.0:
			shake_duration = 0.0
			camera.position = camera_base_position
		else:
			camera.position = camera_base_position + Vector3(
				randf_range(-shake_intensity, shake_intensity),
				randf_range(-shake_intensity, shake_intensity),
				0.0
			)
	_star_time += delta
	for i in range(_star_nodes.size()):
		var sn: MeshInstance3D = _star_nodes[i]
		if is_instance_valid(sn):
			var smat: StandardMaterial3D = sn.get_surface_override_material(0)
			if smat:
				smat.emission_energy_multiplier = 0.5 + 0.5 * sin(_star_time * _star_twinkle_speeds[i] + _star_twinkle_offsets[i])
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_rect:
			_flash_rect.color.a = maxf(0.0, (_flash_timer / _flash_duration) * 0.4)

func _physics_process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	_process_flying_objects(delta)
	for rn in _rain_nodes:
		if is_instance_valid(rn):
			rn.position.y -= 12.0 * delta
			rn.position.z += GameManager.current_speed * 0.3 * delta
			if rn.position.y < -0.5:
				rn.position.y = randf_range(8.0, 14.0)
				rn.position.z = randf_range(-20.0, 5.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if GameManager.current_state == GameManager.GameState.PLAYING:
			GameManager.pause_game()
			if pause_menu_instance:
				pause_menu_instance.show()
		elif GameManager.current_state == GameManager.GameState.PAUSED:
			GameManager.resume_game()
			if pause_menu_instance:
				pause_menu_instance.hide()

func shake_camera(intensity: float = 0.3, duration: float = 0.3) -> void:
	shake_intensity = intensity
	shake_duration = duration

func _update_fov(delta: float) -> void:
	var speed_ratio: float = clampf(
		(GameManager.current_speed - GameManager.BASE_SPEED) /
		(GameManager.MAX_SPEED - GameManager.BASE_SPEED), 0.0, 1.0)
	var boost_bonus: float = 10.0 if GameManager.speed_boost_active else 0.0
	var target_fov: float = BASE_FOV + speed_ratio * (MAX_FOV - BASE_FOV) + boost_bonus
	# Headstart power: extra-wide FOV for motion-blur feel
	if GameManager.power_active and GameManager.selected_power == GameManager.PreGamePower.HEADSTART:
		target_fov = HEADSTART_FOV
	if not truck.is_dead:
		camera.fov = lerpf(camera.fov, target_fov, 4.0 * delta)

func _setup_combo_announcer() -> void:
	var ca_layer := CanvasLayer.new()
	ca_layer.layer = 9
	add_child(ca_layer)
	_combo_label = Label.new()
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_combo_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_combo_label.modulate.a = 0.0
	_combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ca_layer.add_child(_combo_label)

func _show_combo_announcement(combo_count: int) -> void:
	if _combo_label == null:
		return
	var text: String = ""
	var color: Color = Color.WHITE
	var font_size: int = 60
	if combo_count >= 15:
		text = "LEGENDARY!!"
		font_size = 90
		color = Color(1.0, 0.3, 1.0)
	elif combo_count >= 10:
		text = "UNSTOPPABLE!"
		font_size = 80
		color = Color(1.0, 0.0, 1.0)
	elif combo_count >= 8:
		text = "INCREDIBLE!"
		font_size = 72
		color = Color(1.0, 0.1, 0.1)
	elif combo_count >= 5:
		text = "AWESOME!"
		font_size = 64
		color = Color(1.0, 0.55, 0.0)
	elif combo_count >= 3:
		text = "NICE!"
		font_size = 54
		color = Color(1.0, 0.9, 0.0)
	else:
		return
	_combo_label.text = text
	_combo_label.add_theme_font_size_override("font_size", font_size)
	_combo_label.add_theme_color_override("font_color", color)
	if _combo_tween:
		_combo_tween.kill()
	_combo_tween = create_tween()
	_combo_label.modulate.a = 0.0
	_combo_label.scale = Vector2(0.0, 0.0)
	_combo_tween.tween_property(_combo_label, "scale", Vector2(1.2, 1.2), 0.2)
	_combo_tween.parallel().tween_property(_combo_label, "modulate:a", 1.0, 0.15)
	_combo_tween.tween_property(_combo_label, "scale", Vector2(1.0, 1.0), 0.1)
	_combo_tween.tween_interval(0.8)
	_combo_tween.tween_property(_combo_label, "modulate:a", 0.0, 0.3)

func _setup_powerup_hud() -> void:
	var pu_layer := CanvasLayer.new()
	pu_layer.layer = 7
	add_child(pu_layer)
	_powerup_hud_label = Label.new()
	_powerup_hud_label.position = Vector2(16, 200)
	_powerup_hud_label.add_theme_font_size_override("font_size", 26)
	_powerup_hud_label.add_theme_color_override("font_color", Color(0.3, 1.0, 1.0))
	_powerup_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pu_layer.add_child(_powerup_hud_label)

func _update_powerup_hud() -> void:
	if _powerup_hud_label == null:
		return
	if GameManager.active_powerup == GameManager.PowerupType.NONE:
		_powerup_hud_label.text = ""
		return
	var pu_names: Dictionary = {
		GameManager.PowerupType.SHIELD: "SHIELD",
		GameManager.PowerupType.MAGNET: "MAGNET",
		GameManager.PowerupType.SLOW_MO: "SLOW-MO",
		GameManager.PowerupType.DOUBLE_POINTS: "2X POINTS",
	}
	var name_str: String = pu_names.get(GameManager.active_powerup, "POWERUP")
	_powerup_hud_label.text = "[%s] %.1fs" % [name_str, GameManager.powerup_timer]

func _setup_pre_power_hud() -> void:
	var pp_layer := CanvasLayer.new()
	pp_layer.layer = 7
	add_child(pp_layer)
	_pre_power_hud_label = Label.new()
	_pre_power_hud_label.position = Vector2(16, 228)
	_pre_power_hud_label.add_theme_font_size_override("font_size", 22)
	_pre_power_hud_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	_pre_power_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pp_layer.add_child(_pre_power_hud_label)

func _update_pre_power_hud() -> void:
	if _pre_power_hud_label == null:
		return
	if not GameManager.power_active:
		_pre_power_hud_label.text = ""
		return
	var power_names: Dictionary = {
		GameManager.PreGamePower.GHOST_MODE: "👻 GHOST",
		GameManager.PreGamePower.COIN_FRENZY: "💰 COIN FRENZY",
		GameManager.PreGamePower.HEADSTART: "🚀 HEADSTART",
	}
	var pname: String = power_names.get(GameManager.selected_power, "POWER")
	_pre_power_hud_label.text = "[%s] %.1fs" % [pname, GameManager.power_timer]

func _setup_challenge_hud() -> void:
	var ch_layer := CanvasLayer.new()
	ch_layer.layer = 6
	add_child(ch_layer)
	_challenge_hud_label = Label.new()
	_challenge_hud_label.position = Vector2(16, 240)
	_challenge_hud_label.add_theme_font_size_override("font_size", 16)
	_challenge_hud_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	_challenge_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch_layer.add_child(_challenge_hud_label)
	_update_challenge_hud_labels()

func _update_challenge_hud_labels() -> void:
	if _challenge_hud_label == null:
		return
	var lines: PackedStringArray = []
	for i in range(GameManager.daily_challenges.size()):
		var c: Dictionary = GameManager.daily_challenges[i]
		var prog: int = GameManager.daily_challenge_progress[i]
		var target: int = c.get("target", 0)
		var done_str: String = "Done!" if prog >= target else "%d/%d" % [prog, target]
		lines.append("* %s [%s]" % [c.get("desc", ""), done_str])
	_challenge_hud_label.text = "\n".join(lines)

func _setup_phase_label() -> void:
	var ph_layer := CanvasLayer.new()
	ph_layer.layer = 11
	add_child(ph_layer)
	_phase_label = Label.new()
	_phase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_phase_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_phase_label.add_theme_font_size_override("font_size", 72)
	_phase_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_phase_label.modulate.a = 0.0
	_phase_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph_layer.add_child(_phase_label)

func _show_phase_announcement(text: String) -> void:
	if _phase_label == null:
		return
	_phase_label.text = text
	if _phase_tween:
		_phase_tween.kill()
	_phase_tween = create_tween()
	_phase_label.modulate.a = 0.0
	_phase_tween.tween_property(_phase_label, "modulate:a", 1.0, 0.4)
	_phase_tween.tween_interval(2.0)
	_phase_tween.tween_property(_phase_label, "modulate:a", 0.0, 0.6)

func _set_lighting(p_sun_color: Color, p_sun_energy: float,
		p_ambient: Color, p_sky: Color) -> void:
	if sun:
		sun.light_color = p_sun_color
		sun.light_energy = p_sun_energy
	if world_env and world_env.environment:
		var env: Environment = world_env.environment
		env.ambient_light_color = p_ambient
		env.background_color = p_sky

func _set_moon_stars_visible(make_visible: bool) -> void:
	for n in _moon_nodes:
		if is_instance_valid(n):
			n.visible = make_visible
	for sn in _star_nodes:
		if is_instance_valid(sn):
			sn.visible = make_visible

func _setup_toast() -> void:
	var toast_layer := CanvasLayer.new()
	toast_layer.layer = 12
	add_child(toast_layer)
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_toast_label.add_theme_font_size_override("font_size", 28)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	_toast_label.modulate.a = 0.0
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_layer.add_child(_toast_label)

func _show_toast(text: String) -> void:
	if _toast_label == null:
		return
	_toast_label.text = "Achievement: " + text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.3)
	_toast_tween.tween_interval(2.5)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)

func play_collect_sound() -> void:
	if collect_sound.stream:
		collect_sound.play()

func play_damage_sound() -> void:
	if damage_sound.stream:
		damage_sound.play()

func play_lane_switch_sound() -> void:
	if lane_switch_sound.stream:
		lane_switch_sound.play()

func play_death_sound() -> void:
	if death_sound.stream:
		death_sound.play()

func play_boost_sound() -> void:
	if boost_sound.stream:
		boost_sound.play()

func _on_garbage_collected() -> void:
	play_collect_sound()
	_flash_screen(Color(0.0, 1.0, 0.2))

func _on_speed_boost_activated() -> void:
	play_boost_sound()
	_flash_screen(Color(0.0, 0.4, 1.0))

func _on_powerup_activated(type: GameManager.PowerupType) -> void:
	match type:
		GameManager.PowerupType.SHIELD:
			_flash_screen(Color(0.2, 0.5, 1.0))
		GameManager.PowerupType.MAGNET:
			_flash_screen(Color(1.0, 0.2, 0.6))
		GameManager.PowerupType.SLOW_MO:
			_flash_screen(Color(0.3, 0.9, 1.0))
		GameManager.PowerupType.DOUBLE_POINTS:
			_flash_screen(Color(1.0, 0.85, 0.0))

func _on_powerup_expired() -> void:
	pass

func _activate_pre_game_power_visuals() -> void:
	if not GameManager.power_active:
		return
	match GameManager.selected_power:
		GameManager.PreGamePower.GHOST_MODE:
			_apply_ghost_mode(true)
		GameManager.PreGamePower.HEADSTART:
			camera.fov = HEADSTART_FOV

func _apply_ghost_mode(enable: bool) -> void:
	# Find all MeshInstance3D children of the truck and set transparency
	for child in truck.get_children():
		if child is MeshInstance3D:
			var mats_count: int = child.get_surface_override_material_count()
			if mats_count == 0:
				mats_count = child.mesh.get_surface_count() if child.mesh else 0
			for i in range(mats_count):
				var mat: StandardMaterial3D = child.get_surface_override_material(i)
				if mat == null:
					mat = child.mesh.surface_get_material(i) as StandardMaterial3D if child.mesh else null
				if mat == null:
					continue
				var new_mat: StandardMaterial3D = mat.duplicate()
				if enable:
					new_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					new_mat.albedo_color.a = GHOST_MODE_ALPHA
					new_mat.emission_enabled = true
					new_mat.emission = Color(0.4, 0.8, 1.0)
					new_mat.emission_energy_multiplier = 0.8
				else:
					new_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					new_mat.albedo_color.a = 1.0
				child.set_surface_override_material(i, new_mat)

func _fade_ghost_mode_out() -> void:
	# Tween alpha back to 1.0 over 1 second
	if _ghost_tween:
		_ghost_tween.kill()
	_ghost_tween = create_tween()
	for child in truck.get_children():
		if child is MeshInstance3D:
			var mats_count: int = child.get_surface_override_material_count()
			if mats_count == 0:
				mats_count = child.mesh.get_surface_count() if child.mesh else 0
			for i in range(mats_count):
				var mat: StandardMaterial3D = child.get_surface_override_material(i)
				if mat == null:
					continue
				_ghost_tween.parallel().tween_method(
					func(a: float): mat.albedo_color.a = a,
					GHOST_MODE_ALPHA, 1.0, 1.0)
	_ghost_tween.tween_callback(func(): _apply_ghost_mode(false))

func _on_pre_game_power_expired() -> void:
	match GameManager.selected_power:
		GameManager.PreGamePower.GHOST_MODE:
			_fade_ghost_mode_out()
		GameManager.PreGamePower.HEADSTART:
			pass  # FOV returns to normal naturally via _update_fov

func _on_achievement_unlocked(_id: String, title: String) -> void:
	_show_toast(title)

func _setup_screen_flash() -> void:
	var flash_layer := CanvasLayer.new()
	flash_layer.layer = 10
	add_child(flash_layer)
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_layer.add_child(_flash_rect)

func _flash_screen(color: Color) -> void:
	if _flash_rect:
		_flash_rect.color = Color(color.r, color.g, color.b, 0.4)
		_flash_timer = _flash_duration

func _setup_road() -> void:
	for i in range(NUM_SEGMENTS):
		var seg: Node3D = ROAD_SEGMENT_SCENE.instantiate()
		road_container.add_child(seg)
		seg.position.z = -SEGMENT_LENGTH * i
		road_segments.append(seg)

func _setup_buildings() -> void:
	for i in range(NUM_SEGMENTS):
		for j in range(BUILDINGS_PER_SEGMENT):
			var z_pos: float = -SEGMENT_LENGTH * i - j * (SEGMENT_LENGTH / BUILDINGS_PER_SEGMENT)
			var depth: float = randf_range(8.0, 11.0)
			var width: float = randf_range(3.5, 5.0)
			var height_l: float = randf_range(5.0, 16.0)
			var height_r: float = randf_range(5.0, 16.0)
			var lb: Node3D = BUILDING_SCENE.instantiate()
			building_container.add_child(lb)
			lb.position = Vector3(-BUILDING_X_NEAR, 0.0, z_pos)
			lb.setup(height_l, width, depth, _random_building_color())
			left_buildings.append(lb)
			var rb: Node3D = BUILDING_SCENE.instantiate()
			building_container.add_child(rb)
			rb.position = Vector3(BUILDING_X_NEAR, 0.0, z_pos)
			rb.setup(height_r, width, depth, _random_building_color())
			right_buildings.append(rb)
	for i in range(NUM_SEGMENTS):
		for j in range(2):
			var z_pos: float = -SEGMENT_LENGTH * i - j * (SEGMENT_LENGTH / 2.0)
			var height_l: float = randf_range(12.0, 22.0)
			var height_r: float = randf_range(12.0, 22.0)
			var lb2: Node3D = BUILDING_SCENE.instantiate()
			building_container.add_child(lb2)
			lb2.position = Vector3(-BUILDING_X_FAR, 0.0, z_pos)
			lb2.setup(height_l, 5.0, 15.0, _random_building_color().darkened(0.2))
			left_buildings_far.append(lb2)
			var rb2: Node3D = BUILDING_SCENE.instantiate()
			building_container.add_child(rb2)
			rb2.position = Vector3(BUILDING_X_FAR, 0.0, z_pos)
			rb2.setup(height_r, 5.0, 15.0, _random_building_color().darkened(0.2))
			right_buildings_far.append(rb2)

func _create_moon() -> void:
	var moon := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 6.0
	sphere.height = 12.0
	moon.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.92, 0.82, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.95, 0.82, 1.0)
	mat.emission_energy_multiplier = 2.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon.set_surface_override_material(0, mat)
	moon.position = MOON_POSITION
	add_child(moon)
	_moon_nodes.append(moon)
	var halo := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 6.4
	torus.outer_radius = 8.0
	halo.mesh = torus
	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = Color(1.0, 0.95, 0.8, 0.25)
	halo_mat.emission_enabled = true
	halo_mat.emission = Color(1.0, 0.95, 0.8, 1.0)
	halo_mat.emission_energy_multiplier = 0.8
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.set_surface_override_material(0, halo_mat)
	halo.position = MOON_POSITION
	add_child(halo)
	_moon_nodes.append(halo)
	var crater_mat := StandardMaterial3D.new()
	crater_mat.albedo_color = Color(0.68, 0.65, 0.58, 1.0)
	crater_mat.emission_enabled = true
	crater_mat.emission = Color(0.5, 0.48, 0.42, 1.0)
	crater_mat.emission_energy_multiplier = 0.4
	crater_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for cd in [
		[Vector3(-2.2, 1.5, -5.5), 1.1], [Vector3(2.8, -1.0, -5.3), 0.75],
		[Vector3(-0.5, -3.0, -4.8), 0.55], [Vector3(1.5, 2.8, -5.1), 0.9],
		[Vector3(-3.5, -1.8, -4.6), 0.6], [Vector3(0.8, -1.5, -5.8), 0.45],
		[Vector3(-1.8, 3.2, -4.9), 0.7], [Vector3(3.0, 1.5, -4.7), 0.5],
	]:
		var crater := MeshInstance3D.new()
		var c_sphere := SphereMesh.new()
		c_sphere.radius = cd[1]
		c_sphere.height = cd[1] * 2.0
		crater.mesh = c_sphere
		crater.set_surface_override_material(0, crater_mat)
		crater.position = MOON_POSITION + cd[0]
		add_child(crater)
		_moon_nodes.append(crater)
	var moon_light := OmniLight3D.new()
	moon_light.light_color = Color(0.9, 0.88, 0.75)
	moon_light.light_energy = 0.3
	moon_light.omni_range = 220.0
	moon_light.position = MOON_POSITION
	add_child(moon_light)
	_moon_nodes.append(moon_light)

func _random_building_color() -> Color:
	var palette := [
		Color(0.55, 0.53, 0.58, 1), Color(0.6, 0.5, 0.4, 1), Color(0.7, 0.65, 0.55, 1),
		Color(0.45, 0.48, 0.55, 1), Color(0.5, 0.55, 0.5, 1), Color(0.62, 0.58, 0.52, 1),
		Color(0.48, 0.42, 0.38, 1), Color(0.58, 0.6, 0.65, 1), Color(0.72, 0.68, 0.62, 1),
		Color(0.42, 0.4, 0.45, 1),
	]
	return palette[randi() % palette.size()]

func _create_stars() -> void:
	for _i in range(60):
		var star := MeshInstance3D.new()
		var s_mesh := SphereMesh.new()
		var radius: float = randf_range(0.3, 0.8)
		s_mesh.radius = radius
		s_mesh.height = radius * 2.0
		star.mesh = s_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 1.0, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 1.0, 0.95)
		mat.emission_energy_multiplier = 1.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		star.set_surface_override_material(0, mat)
		var theta: float = randf_range(0.0, TAU)
		var dist: float = randf_range(80.0, 200.0)
		var height: float = randf_range(15.0, 80.0)
		star.position = Vector3(cos(theta) * dist, height, sin(theta) * dist - 100.0)
		add_child(star)
		_star_nodes.append(star)
		_star_twinkle_speeds.append(randf_range(1.0, 3.0))
		_star_twinkle_offsets.append(randf_range(0.0, TAU))

	# Add a cluster of smaller, brighter stars near the moon for a constellation effect
	for _i in range(18):
		var star := MeshInstance3D.new()
		var s_mesh := SphereMesh.new()
		var radius: float = randf_range(0.15, 0.4)
		s_mesh.radius = radius
		s_mesh.height = radius * 2.0
		star.mesh = s_mesh
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 1.0, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.98, 0.85)
		mat.emission_energy_multiplier = 2.5
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		star.set_surface_override_material(0, mat)
		# Scatter within a 15-25 unit sphere around the moon
		var offset := Vector3(
			randf_range(-20.0, 20.0),
			randf_range(-15.0, 15.0),
			randf_range(-15.0, 15.0)
		)
		# Ensure minimum distance from moon centre so they don't overlap the moon disc
		if offset.length() < 8.0:
			offset = offset.normalized() * randf_range(8.0, 20.0)
		star.position = MOON_POSITION + offset
		add_child(star)
		_star_nodes.append(star)
		_star_twinkle_speeds.append(randf_range(2.0, 5.0))
		_star_twinkle_offsets.append(randf_range(0.0, TAU))

func _update_day_night() -> void:
	# City is the only environment — always run the day/night cycle
	var cycle_pos: float = fmod(GameManager.distance, 1200.0)
	var phase_f: float = cycle_pos / 300.0
	var phase_int: int = int(phase_f) % 4
	var phase_t: float = fmod(phase_f, 1.0)
	var next_phase_int: int = (phase_int + 1) % 4
	var from_cfg: Dictionary = DAY_CONFIGS[phase_int]
	var to_cfg: Dictionary = DAY_CONFIGS[next_phase_int]
	var t: float = smoothstep(0.0, 1.0, phase_t)
	if sun:
		sun.light_color = from_cfg["sun_color"].lerp(to_cfg["sun_color"], t)
		sun.light_energy = lerpf(from_cfg["sun_energy"], to_cfg["sun_energy"], t)
	if world_env and world_env.environment:
		var env: Environment = world_env.environment
		env.background_color = from_cfg["sky"].lerp(to_cfg["sky"], t)
		env.ambient_light_color = from_cfg["ambient"].lerp(to_cfg["ambient"], t)
		env.ambient_light_energy = lerpf(from_cfg["ambient_e"], to_cfg["ambient_e"], t)

func _pick_random_weather() -> void:
	var types := [WeatherType.CLEAR, WeatherType.RAIN, WeatherType.FOG, WeatherType.THUNDERSTORM]
	_apply_weather(types[randi() % types.size()])

func _apply_weather(w_type: int) -> void:
	_current_weather = w_type
	for n in _rain_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_rain_nodes.clear()
	if world_env and world_env.environment:
		var env: Environment = world_env.environment
		match w_type:
			WeatherType.CLEAR:
				env.fog_enabled = true
				env.fog_density = 0.008
			WeatherType.FOG:
				env.fog_enabled = true
				env.fog_density = 0.04
			WeatherType.RAIN:
				env.fog_enabled = true
				env.fog_density = 0.015
				_create_rain()
			WeatherType.THUNDERSTORM:
				env.fog_enabled = true
				env.fog_density = 0.015
				_create_rain()
				_thunder_timer = randf_range(3.0, 7.0)

func _create_rain() -> void:
	for _i in range(30):
		var rain := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.04, randf_range(0.5, 1.2), 0.04)
		rain.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.7, 0.8, 1.0, 0.6)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rain.material_override = mat
		rain.position = Vector3(randf_range(-8.0, 8.0), randf_range(1.0, 12.0), randf_range(-20.0, 5.0))
		add_child(rain)
		_rain_nodes.append(rain)

func _spawn_flying_object() -> void:
	var fly_type: int = randi() % 3
	var fly_obj := Node3D.new()
	var from_left: bool = randf() > 0.5
	var start_x: float = -25.0 if from_left else 25.0
	var end_x: float = 25.0 if from_left else -25.0
	match fly_type:
		0:
			_build_bird(fly_obj)
			fly_obj.position = Vector3(start_x, randf_range(8.0, 15.0), randf_range(-30.0, 0.0))
		1:
			_build_plane(fly_obj)
			fly_obj.position = Vector3(start_x * 1.5, randf_range(25.0, 35.0), randf_range(-50.0, -10.0))
		2:
			_build_drone(fly_obj)
			fly_obj.position = Vector3(start_x, randf_range(6.0, 10.0), randf_range(-20.0, 5.0))
	flying_container.add_child(fly_obj)
	var speeds := [randf_range(8.0, 14.0), randf_range(4.0, 7.0), randf_range(5.0, 9.0)]
	var fly_spd: float = speeds[fly_type]
	fly_obj.set_meta("speed_x", fly_spd * (1.0 if end_x > start_x else -1.0))
	fly_obj.set_meta("end_x", end_x)
	fly_obj.set_meta("bob_time", randf_range(0.0, TAU))
	fly_obj.set_meta("fly_type", fly_type)
	fly_obj.set_meta("active", true)

func _process_flying_objects(delta: float) -> void:
	for child in flying_container.get_children():
		if not child.has_meta("active"):
			continue
		var spd_x: float = child.get_meta("speed_x", 8.0)
		var end_x: float = child.get_meta("end_x", 25.0)
		var bob_t: float = child.get_meta("bob_time", 0.0)
		var fly_type: int = child.get_meta("fly_type", 0)
		bob_t += delta * 2.0
		child.set_meta("bob_time", bob_t)
		child.position.x += spd_x * delta
		if fly_type != 1:
			child.position.y += sin(bob_t) * 0.8 * delta
		if (spd_x > 0.0 and child.position.x >= end_x) or (spd_x < 0.0 and child.position.x <= end_x):
			child.queue_free()

func _build_bird(root: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.12, 0.1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.4, 0.2, 0.6)
	body.mesh = bm
	body.material_override = mat
	root.add_child(body)
	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.8, 0.06, 0.35)
		wing.mesh = wm
		wing.material_override = mat
		wing.position = Vector3(side * 0.55, 0.0, 0.0)
		root.add_child(wing)

func _build_plane(root: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.85, 0.9)
	mat.metallic = 0.6
	mat.roughness = 0.3
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.5, 3.0)
	body.mesh = bm
	body.material_override = mat
	root.add_child(body)
	var wings := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(3.0, 0.1, 0.8)
	wings.mesh = wm
	wings.material_override = mat
	root.add_child(wings)
	var tail := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(1.2, 0.6, 0.25)
	tail.mesh = tm
	tail.material_override = mat
	tail.position = Vector3(0.0, 0.35, 1.3)
	root.add_child(tail)
	var lmat := StandardMaterial3D.new()
	lmat.albedo_color = Color(1.0, 0.0, 0.0)
	lmat.emission_enabled = true
	lmat.emission = Color(1.0, 0.0, 0.0)
	lmat.emission_energy_multiplier = 3.0
	lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ln := MeshInstance3D.new()
	var lsph := SphereMesh.new()
	lsph.radius = 0.12
	lsph.height = 0.24
	ln.mesh = lsph
	ln.material_override = lmat
	ln.position = Vector3(0.0, 0.4, 0.0)
	root.add_child(ln)

func _build_drone(root: Node3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.2, 0.25)
	mat.metallic = 0.5
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.2, 0.5)
	body.mesh = bm
	body.material_override = mat
	root.add_child(body)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.3, 0.3, 0.35, 0.7)
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for ap in [Vector3(-0.45, 0.05, -0.45), Vector3(0.45, 0.05, -0.45),
			   Vector3(-0.45, 0.05, 0.45), Vector3(0.45, 0.05, 0.45)]:
		var arm := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(0.06, 0.04, 0.06)
		arm.mesh = am
		arm.material_override = mat
		arm.position = ap
		root.add_child(arm)
		var disc := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = 0.2
		dm.bottom_radius = 0.2
		dm.height = 0.02
		disc.mesh = dm
		disc.material_override = pmat
		disc.position = ap + Vector3(0.0, 0.06, 0.0)
		root.add_child(disc)

func _spawn_obstacle() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var wave: int = GameManager.difficulty_wave
	var obs: Area3D = OBSTACLE_SCENE.instantiate()
	obstacle_container.add_child(obs)
	obs.position.z = SPAWN_Z
	var colors := [Color(1.0, 0.0, 0.0, 1), Color(1.0, 0.5, 0.0, 1), Color(1.0, 1.0, 0.0, 1)]
	obs.setup(randi() % 3, colors[randi() % colors.size()])
	var ratio: float = (GameManager.current_speed - GameManager.BASE_SPEED) / \
		(GameManager.MAX_SPEED - GameManager.BASE_SPEED)
	var wave_factor: float = clampf(float(wave) * 0.08, 0.0, 0.4)
	var interval: float = lerpf(5.0, 2.0, clampf(ratio + wave_factor, 0.0, 1.0)) + \
		randf_range(OBSTACLE_TIMER_MIN_RANDOMNESS, OBSTACLE_TIMER_MAX_RANDOMNESS)
	obstacle_timer.start(interval)
	if wave >= 3 and randf() < 0.3:
		var obs2: Area3D = OBSTACLE_SCENE.instantiate()
		obstacle_container.add_child(obs2)
		obs2.position.z = SPAWN_Z - randf_range(5.0, 15.0)
		obs2.setup(randi() % 3, colors[randi() % colors.size()])

func _spawn_garbage_marker() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var wave: int = GameManager.difficulty_wave
	var marker: Area3D = MARKER_SCENE.instantiate()
	marker_container.add_child(marker)
	marker.position.z = SPAWN_Z - randf_range(0.0, 15.0)
	marker.position.y = 0.05
	marker.setup(randi() % 3)
	var base_interval: float = lerpf(2.5, 1.5, clampf(float(wave) * 0.1, 0.0, 1.0))
	garbage_timer.start(randf_range(base_interval, base_interval + 1.5))

func _spawn_speed_boost() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if GameManager.speed_boost_active:
		boost_timer.start(randf_range(15.0, 25.0))
		return
	var boost: Area3D = SPEED_BOOST_SCENE.instantiate()
	if boost_container:
		boost_container.add_child(boost)
	else:
		add_child(boost)
	boost.position.z = SPAWN_Z
	boost.position.y = 0.1
	boost.setup(randi() % 3)
	boost_timer.start(randf_range(15.0, 25.0))

func _spawn_powerup() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if GameManager.active_powerup != GameManager.PowerupType.NONE:
		return
	var types := [
		GameManager.PowerupType.SHIELD, GameManager.PowerupType.MAGNET,
		GameManager.PowerupType.SLOW_MO, GameManager.PowerupType.DOUBLE_POINTS,
	]
	var pu: Area3D = POWERUP_SCENE.instantiate()
	powerup_container.add_child(pu)
	pu.position.z = SPAWN_Z
	pu.position.y = 0.1
	pu.setup(randi() % 3, types[randi() % types.size()])

func _spawn_traffic_car() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	var car: Area3D = TRAFFIC_CAR_SCENE.instantiate()
	traffic_container.add_child(car)
	car.position.z = SPAWN_Z
	car.position.y = 0.0
	car.setup(randi() % 3, randf() < 0.4)

func _setup_coin_hud() -> void:
	var coin_layer := CanvasLayer.new()
	coin_layer.layer = 7
	add_child(coin_layer)
	_coin_hud_label = Label.new()
	_coin_hud_label.position = Vector2(16, 256)
	_coin_hud_label.add_theme_font_size_override("font_size", 22)
	_coin_hud_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	_coin_hud_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin_layer.add_child(_coin_hud_label)

func _spawn_coin_line() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	if coin_container == null:
		return
	# Spawn a line of 3–6 coins in a random lane
	var lane_xs: Array[float] = [-3.0, 0.0, 3.0]
	var chosen_lane: int = randi() % 3
	var x: float = lane_xs[chosen_lane]
	var count: int = randi() % 4 + 3  # 3 to 6 coins
	var spacing: float = 3.0
	for i in range(count):
		var coin: Area3D = COIN_SCENE.instantiate()
		coin_container.add_child(coin)
		coin.position = Vector3(x, 1.0, SPAWN_Z - i * spacing)

func _on_truck_died() -> void:
	play_death_sound()
	shake_camera(0.5, 0.4)
	var death_tween := create_tween()
	death_tween.tween_property(camera, "fov", 45.0, 0.5)
	obstacle_timer.stop()
	garbage_timer.stop()
	boost_timer.stop()
	GameManager.end_game()
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")

func _on_health_changed(new_health: int) -> void:
	var prev_health: int = int(health_bar.value)
	health_bar.value = new_health
	_update_health_bar_color(new_health)
	if new_health < prev_health:
		play_damage_sound()
		shake_camera(0.25, 0.2)
		_flash_screen(Color(1.0, 0.0, 0.0))
	if new_health <= 0:
		truck.die()

func _on_combo_changed(new_combo: int, new_multiplier: float) -> void:
	if new_multiplier > 1.0:
		combo_label.visible = true
		combo_label.text = "x%.0f COMBO! (%d)" % [new_multiplier, new_combo]
	else:
		combo_label.visible = false
	if new_combo in [3, 5, 8, 10, 15]:
		_show_combo_announcement(new_combo)

func _update_health_bar_color(hp: int) -> void:
	if hp > HEALTH_GOOD_THRESHOLD:
		health_bar.add_theme_stylebox_override("fill", _style_health_good)
	elif hp > HEALTH_WARNING_THRESHOLD:
		health_bar.add_theme_stylebox_override("fill", _style_health_warning)
	else:
		health_bar.add_theme_stylebox_override("fill", _style_health_critical)
