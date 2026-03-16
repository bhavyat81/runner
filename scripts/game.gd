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
const BUILDING_X: float = 6.5

var road_segments: Array[Node3D] = []
var left_buildings: Array[Node3D] = []
var right_buildings: Array[Node3D] = []

func _ready() -> void:
truck.died.connect(_on_truck_died)
_setup_road()
_setup_buildings()
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
for i in range(NUM_SEGMENTS):
var z_pos: float = -SEGMENT_LENGTH * i

var lb: Node3D = BUILDING_SCENE.instantiate()
building_container.add_child(lb)
lb.position = Vector3(-BUILDING_X, 0.0, z_pos)
lb.setup(randf_range(4.0, 14.0), _random_building_color())
left_buildings.append(lb)

var rb: Node3D = BUILDING_SCENE.instantiate()
building_container.add_child(rb)
rb.position = Vector3(BUILDING_X, 0.0, z_pos)
rb.setup(randf_range(4.0, 14.0), _random_building_color())
right_buildings.append(rb)

func _random_building_color() -> Color:
var palette := [
Color(0.5, 0.5, 0.55, 1),   # Gray
Color(0.55, 0.45, 0.35, 1), # Brown
Color(0.65, 0.6, 0.5, 1),   # Beige
Color(0.4, 0.45, 0.5, 1),   # Blue-gray
Color(0.45, 0.5, 0.45, 1),  # Muted green
]
return palette[randi() % palette.size()]

func _spawn_obstacle() -> void:
if GameManager.current_state != GameManager.GameState.PLAYING:
return

var obs: Area3D = OBSTACLE_SCENE.instantiate()
obstacle_container.add_child(obs)
obs.position.z = SPAWN_Z

var colors := [
Color(1.0, 0.25, 0.25, 1), # Red car
Color(1.0, 0.55, 0.05, 1), # Orange barrier
Color(1.0, 0.9, 0.1, 1),   # Yellow cone
]
obs.setup(randi() % 3, colors[randi() % colors.size()])

# Dynamically adjust spawn interval as speed increases
var ratio: float = (GameManager.current_speed - GameManager.BASE_SPEED) / \
(GameManager.MAX_SPEED - GameManager.BASE_SPEED)
obstacle_timer.start(lerpf(3.5, 1.2, clampf(ratio, 0.0, 1.0)))

func _spawn_garbage_marker() -> void:
if GameManager.current_state != GameManager.GameState.PLAYING:
return

var marker: Area3D = MARKER_SCENE.instantiate()
marker_container.add_child(marker)
marker.position.z = SPAWN_Z
marker.position.y = 0.03
marker.setup(randi() % 3)

garbage_timer.start(randf_range(1.8, 3.5))

func _on_truck_died() -> void:
obstacle_timer.stop()
garbage_timer.stop()
GameManager.end_game()
await get_tree().create_timer(1.2).timeout
get_tree().change_scene_to_file("res://scenes/game_over.tscn")
