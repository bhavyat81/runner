# game.gd
# Main 3D game scene controller.
# Manages road recycling, building placement, obstacle/garbage/boost spawning, and HUD.
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

# Audio players (sound placeholder hooks — assign streams in editor)
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

var road_segments: Array[Node3D] = []
var left_buildings: Array[Node3D] = []
var right_buildings: Array[Node3D] = []
var left_buildings_far: Array[Node3D] = []
var right_buildings_far: Array[Node3D] = []

# Boost pickups container
var boost_container: Node3D = null

# Camera shake state
var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var camera_base_position: Vector3

# Cached StyleBoxFlat instances for health bar colour changes
var _style_health_good: StyleBoxFlat = StyleBoxFlat.new()
var _style_health_warning: StyleBoxFlat = StyleBoxFlat.new()
var _style_health_critical: StyleBoxFlat = StyleBoxFlat.new()

# Pause menu
var pause_menu_instance: Control = null

func _ready() -> void:
	truck.died.connect(_on_truck_died)
	GameManager.health_changed.connect(_on_health_changed)
	GameManager.combo_changed.connect(_on_combo_changed)
	GameManager.garbage_collected_signal.connect(play_collect_sound)
	GameManager.speed_boost_activated.connect(play_boost_sound)
	_setup_road()
	_setup_buildings()
	_create_moon()
	obstacle_timer.timeout.connect(_spawn_obstacle)
	garbage_timer.timeout.connect(_spawn_garbage_marker)
	boost_timer.timeout.connect(_spawn_speed_boost)
	obstacle_timer.start(4.0)
	garbage_timer.start(2.0)
	boost_timer.start(randf_range(15.0, 25.0))

	# Create boost container
	boost_container = Node3D.new()
	boost_container.name = "BoostContainer"
	add_child(boost_container)

	# Initialise health bar display
	health_bar.max_value = GameManager.MAX_HEALTH
	health_bar.value = GameManager.health
	_style_health_good.bg_color = Color(0.1, 0.8, 0.1)
	_style_health_warning.bg_color = Color(1.0, 0.75, 0.0)
	_style_health_critical.bg_color = Color(0.9, 0.1, 0.1)
	_update_health_bar_color(GameManager.health)

	# Camera base position for shake
	camera_base_position = camera.position

	# Initialise combo label
	combo_label.visible = false

	# Setup and hide pause menu
	var pause_menu_scene := load("res://scenes/pause_menu.tscn")
	if pause_menu_scene:
		pause_menu_instance = pause_menu_scene.instantiate()
		$HUD.add_child(pause_menu_instance)
		pause_menu_instance.hide()

func _process(delta: float) -> void:
	if GameManager.current_state == GameManager.GameState.PAUSED:
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	GameManager.update_game(delta)
	var spd: float = GameManager.current_speed

	# Scroll road segments
	for seg in road_segments:
		seg.position.z += spd * delta
		if seg.position.z >= DESPAWN_Z:
			seg.position.z -= SEGMENT_LENGTH * NUM_SEGMENTS

	# Scroll buildings
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

	# Scroll and despawn obstacles, markers, and boost pickups
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

	# Sync truck invincibility with speed boost state
	if truck and not truck.is_dead:
		truck.invincible = GameManager.speed_boost_active

	# Update HUD
	score_label.text = "Score: %d" % GameManager.score
	garbage_label.text = "Bags: %d" % GameManager.garbage_collected
	distance_label.text = "%dm" % int(GameManager.distance)
	health_label.text = "HP: %d" % GameManager.health

	# Camera shake
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

func _unhandled_input(event: InputEvent) -> void:
	# "pause" action is mapped to P key in project.godot Input Map
	if event.is_action_pressed("pause"):
		if GameManager.current_state == GameManager.GameState.PLAYING:
			GameManager.pause_game()
			if pause_menu_instance:
				pause_menu_instance.show()
		elif GameManager.current_state == GameManager.GameState.PAUSED:
			GameManager.resume_game()
			if pause_menu_instance:
				pause_menu_instance.hide()

# --- Camera shake ---
func shake_camera(intensity: float = 0.3, duration: float = 0.3) -> void:
	shake_intensity = intensity
	shake_duration = duration

# --- Sound helpers (safe no-ops if stream not assigned) ---
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
	sphere.radius = 8.0
	sphere.height = 16.0
	moon.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.98, 0.96, 0.88, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.95, 0.82, 1.0)
	mat.emission_energy_multiplier = 2.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon.set_surface_override_material(0, mat)
	moon.position = MOON_POSITION
	add_child(moon)

	# Soft halo glow ring around the moon — larger and brighter
	var halo := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 8.6
	torus.outer_radius = 11.0
	halo.mesh = torus

	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = Color(1.0, 0.95, 0.8, 0.35)
	halo_mat.emission_enabled = true
	halo_mat.emission = Color(1.0, 0.95, 0.8, 1.0)
	halo_mat.emission_energy_multiplier = 1.2
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.set_surface_override_material(0, halo_mat)
	halo.position = MOON_POSITION
	add_child(halo)

	# Moon craters — small dark flat discs on the moon surface
	var crater_mat := StandardMaterial3D.new()
	crater_mat.albedo_color = Color(0.68, 0.65, 0.58, 1.0)
	crater_mat.emission_enabled = true
	crater_mat.emission = Color(0.5, 0.48, 0.42, 1.0)
	crater_mat.emission_energy_multiplier = 0.4
	crater_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var crater_data := [
		# [offset_from_center, radius]
		[Vector3(-2.9, 2.0, -7.3), 1.4],
		[Vector3(3.7, -1.3, -7.1), 1.0],
		[Vector3(-0.7, -4.0, -6.4), 0.75],
		[Vector3(1.8, 3.5, -6.8), 0.6],
		[Vector3(-4.5, -0.5, -6.6), 0.85],
		[Vector3(2.5, -3.2, -7.0), 0.5],
	]
	for cd in crater_data:
		var crater := MeshInstance3D.new()
		var c_sphere := SphereMesh.new()
		c_sphere.radius = cd[1]
		c_sphere.height = cd[1] * 2.0
		crater.mesh = c_sphere
		crater.set_surface_override_material(0, crater_mat)
		crater.position = MOON_POSITION + cd[0]
		add_child(crater)

	# Stars — small white spheres scattered in the sky
	var star_mat := StandardMaterial3D.new()
	star_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	star_mat.emission_enabled = true
	star_mat.emission = Color(1.0, 1.0, 1.0, 1.0)
	star_mat.emission_energy_multiplier = 2.0
	star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # Fixed seed for consistent star placement
	for i in range(40):
		var star := MeshInstance3D.new()
		var star_sphere := SphereMesh.new()
		var star_size := rng.randf_range(0.1, 0.35)
		star_sphere.radius = star_size
		star_sphere.height = star_size * 2.0
		star.mesh = star_sphere
		# Some stars have slight emission variation for twinkling effect
		if rng.randf() < 0.4:
			var twinkle_mat := StandardMaterial3D.new()
			twinkle_mat.albedo_color = Color(0.9, 0.95, 1.0, 1.0)
			twinkle_mat.emission_enabled = true
			twinkle_mat.emission = Color(0.9, 0.95, 1.0, 1.0)
			twinkle_mat.emission_energy_multiplier = 3.5
			twinkle_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			star.set_surface_override_material(0, twinkle_mat)
		else:
			star.set_surface_override_material(0, star_mat)
		star.position = Vector3(
			rng.randf_range(-120.0, 120.0),
			rng.randf_range(25.0, 70.0),
			rng.randf_range(-250.0, -80.0)
		)
		add_child(star)

func _random_building_color() -> Color:
	var palette := [
		Color(0.55, 0.53, 0.58, 1),
		Color(0.6, 0.5, 0.4, 1),
		Color(0.7, 0.65, 0.55, 1),
		Color(0.45, 0.48, 0.55, 1),
		Color(0.5, 0.55, 0.5, 1),
		Color(0.62, 0.58, 0.52, 1),
		Color(0.48, 0.42, 0.38, 1),
		Color(0.58, 0.6, 0.65, 1),
		Color(0.72, 0.68, 0.62, 1),
		Color(0.42, 0.4, 0.45, 1),
	]
	return palette[randi() % palette.size()]

func _spawn_obstacle() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	var wave: int = GameManager.difficulty_wave
	var obs: Area3D = OBSTACLE_SCENE.instantiate()
	obstacle_container.add_child(obs)
	obs.position.z = SPAWN_Z

	var colors := [
		Color(1.0, 0.0, 0.0, 1),
		Color(1.0, 0.5, 0.0, 1),
		Color(1.0, 1.0, 0.0, 1),
	]
	obs.setup(randi() % 3, colors[randi() % colors.size()])

	# Progressive difficulty: interval shrinks with waves
	var ratio: float = (GameManager.current_speed - GameManager.BASE_SPEED) / \
		(GameManager.MAX_SPEED - GameManager.BASE_SPEED)
	var wave_factor: float = clampf(float(wave) * 0.08, 0.0, 0.4)
	var interval: float = lerpf(5.0, 2.0, clampf(ratio + wave_factor, 0.0, 1.0)) + \
		randf_range(OBSTACLE_TIMER_MIN_RANDOMNESS, OBSTACLE_TIMER_MAX_RANDOMNESS)
	obstacle_timer.start(interval)

	# At higher waves, occasionally spawn a second obstacle in another lane
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

	# Decrease interval at higher waves
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

func _on_truck_died() -> void:
	play_death_sound()
	shake_camera(0.5, 0.4)
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
	# Only trigger damage feedback when health decreases
	if new_health < prev_health:
		play_damage_sound()
		shake_camera(0.25, 0.2)
	if new_health <= 0:
		truck.die()

func _on_combo_changed(new_combo: int, new_multiplier: float) -> void:
	if new_multiplier > 1.0:
		combo_label.visible = true
		combo_label.text = "x%.0f COMBO! (%d)" % [new_multiplier, new_combo]
	else:
		combo_label.visible = false

func _update_health_bar_color(hp: int) -> void:
	if hp > HEALTH_GOOD_THRESHOLD:
		health_bar.add_theme_stylebox_override("fill", _style_health_good)
	elif hp > HEALTH_WARNING_THRESHOLD:
		health_bar.add_theme_stylebox_override("fill", _style_health_warning)
	else:
		health_bar.add_theme_stylebox_override("fill", _style_health_critical)

