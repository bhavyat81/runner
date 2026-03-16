# game.gd
# Main 3D game scene controller.
# Manages road recycling, building placement, obstacle/garbage spawning, and HUD.
extends Node3D

@onready var truck: CharacterBody3D = $Truck
@onready var road_container: Node3D = $RoadContainer
@onready var building_container: Node3D = $BuildingContainer
@onready var obstacle_container: Node3D = $ObstacleContainer
@onready var marker_container: Node3D = $MarkerContainer
@onready var score_label: Label = $HUD/ScoreLabel
@onready var garbage_label: Label = $HUD/GarbageLabel
@onready var distance_label: Label = $HUD/DistanceLabel
@onready var obstacle_timer: Timer = $ObstacleTimer
@onready var garbage_timer: Timer = $GarbageTimer

const ROAD_SEGMENT_SCENE := preload("res://scenes/road_segment.tscn")
const BUILDING_SCENE := preload("res://scenes/building.tscn")
const OBSTACLE_SCENE := preload("res://scenes/obstacle.tscn")
const MARKER_SCENE := preload("res://scenes/garbage_marker.tscn")

const SEGMENT_LENGTH: float = 40.0
const NUM_SEGMENTS: int = 8
const SPAWN_Z: float = -90.0
const DESPAWN_Z: float = 25.0
const BUILDING_X_NEAR: float = 9.0    # First row — inner edge meets footpath at ±6.5
const BUILDING_X_FAR: float = 15.0    # Second row (behind first)
const BUILDINGS_PER_SEGMENT: int = 2  # Buildings per segment per side
const MOON_POSITION := Vector3(25.0, 45.0, -120.0)

var road_segments: Array[Node3D] = []
var left_buildings: Array[Node3D] = []
var right_buildings: Array[Node3D] = []
var left_buildings_far: Array[Node3D] = []
var right_buildings_far: Array[Node3D] = []

func _ready() -> void:
	truck.died.connect(_on_truck_died)
	_setup_road()
	_setup_buildings()
	_create_moon()
	obstacle_timer.timeout.connect(_spawn_obstacle)
	garbage_timer.timeout.connect(_spawn_garbage_marker)
	obstacle_timer.start(2.5)
	garbage_timer.start(2.0)

func _process(delta: float) -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	GameManager.update_game(delta)
	var spd: float = GameManager.current_speed

	# Scroll road segments (recycle when they pass the camera)
	for seg in road_segments:
		seg.position.z += spd * delta
		if seg.position.z >= DESPAWN_Z:
			seg.position.z -= SEGMENT_LENGTH * NUM_SEGMENTS

	# Scroll buildings (same recycling logic)
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

	# Scroll and despawn obstacles and markers
	for child in obstacle_container.get_children():
		child.position.z += spd * delta
		if child.position.z >= DESPAWN_Z:
			child.queue_free()
	for child in marker_container.get_children():
		child.position.z += spd * delta
		if child.position.z >= DESPAWN_Z:
			child.queue_free()

	# Update HUD
	score_label.text = "Score: %d" % GameManager.score
	garbage_label.text = "Bags: %d" % GameManager.garbage_collected
	distance_label.text = "%dm" % int(GameManager.distance)

func _setup_road() -> void:
	for i in range(NUM_SEGMENTS):
		var seg: Node3D = ROAD_SEGMENT_SCENE.instantiate()
		road_container.add_child(seg)
		seg.position.z = -SEGMENT_LENGTH * i
		road_segments.append(seg)

func _setup_buildings() -> void:
	# First row — close to road, varied heights, tightly packed
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

	# Second row — taller buildings behind for skyline depth
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
	# Moon sphere — added directly to Game node so it stays fixed (does not scroll)
	var moon := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 3.0
	sphere.height = 6.0
	moon.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.98, 0.9, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.95, 0.85, 1.0)
	mat.emission_energy_multiplier = 2.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon.set_surface_override_material(0, mat)

	moon.position = MOON_POSITION
	add_child(moon)

	# Faint glow halo ring around the moon
	var halo := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.2
	torus.outer_radius = 4.0
	halo.mesh = torus

	var halo_mat := StandardMaterial3D.new()
	halo_mat.albedo_color = Color(1.0, 0.95, 0.8, 0.3)
	halo_mat.emission_enabled = true
	halo_mat.emission = Color(1.0, 0.95, 0.8, 1.0)
	halo_mat.emission_energy_multiplier = 1.0
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.set_surface_override_material(0, halo_mat)

	halo.position = MOON_POSITION
	add_child(halo)

func _random_building_color() -> Color:
	var palette := [
		Color(0.55, 0.53, 0.58, 1),   # Cool gray
		Color(0.6, 0.5, 0.4, 1),      # Warm brown
		Color(0.7, 0.65, 0.55, 1),    # Sandstone
		Color(0.45, 0.48, 0.55, 1),   # Blue-gray
		Color(0.5, 0.55, 0.5, 1),     # Sage green
		Color(0.62, 0.58, 0.52, 1),   # Tan
		Color(0.48, 0.42, 0.38, 1),   # Dark brown
		Color(0.58, 0.6, 0.65, 1),    # Steel blue
		Color(0.72, 0.68, 0.62, 1),   # Cream
		Color(0.42, 0.4, 0.45, 1),    # Charcoal
	]
	return palette[randi() % palette.size()]

func _spawn_obstacle() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	var obs: Area3D = OBSTACLE_SCENE.instantiate()
	obstacle_container.add_child(obs)
	obs.position.z = SPAWN_Z

	# BRIGHT, high-contrast colors
	var colors := [
		Color(1.0, 0.0, 0.0, 1),    # Bright red
		Color(1.0, 0.5, 0.0, 1),    # Bright orange
		Color(1.0, 1.0, 0.0, 1),    # Bright yellow
	]
	obs.setup(randi() % 3, colors[randi() % colors.size()])

	var ratio: float = (GameManager.current_speed - GameManager.BASE_SPEED) / \
		(GameManager.MAX_SPEED - GameManager.BASE_SPEED)
	obstacle_timer.start(lerpf(3.5, 1.5, clampf(ratio, 0.0, 1.0)))

func _spawn_garbage_marker() -> void:
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return

	var marker: Area3D = MARKER_SCENE.instantiate()
	marker_container.add_child(marker)
	marker.position.z = SPAWN_Z - randf_range(0.0, 15.0)
	marker.position.y = 0.05
	marker.setup(randi() % 3)

	garbage_timer.start(randf_range(2.5, 4.0))

func _on_truck_died() -> void:
	obstacle_timer.stop()
	garbage_timer.stop()
	GameManager.end_game()
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file("res://scenes/game_over.tscn")
