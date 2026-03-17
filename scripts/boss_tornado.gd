# boss_tornado.gd
# Garbage tornado boss event. Moves side-to-side across lanes, damages the truck on contact.
# Spawned by game.gd; lasts 15 seconds then emits boss_finished.
extends Area3D

signal boss_finished

const LANE_X: Array[float] = [-3.0, 0.0, 3.0]

@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var event_timer: float = 15.0
var alive: bool = true
var side_speed: float = 4.0
var side_dir: float = 1.0
var spin_time: float = 0.0
var _mesh_root: Node3D = null

func _ready() -> void:
	collision_layer = 64
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_build_visual()
	position.x = 0.0
	position.y = 0.0

func _build_visual() -> void:
	_mesh_root = Node3D.new()
	add_child(_mesh_root)

	# Main spinning cylinder (tornado body)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.35, 0.25, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.45, 0.3)
	mat.emission_energy_multiplier = 1.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Stack of tapered cylinders to simulate tornado shape
	var heights := [3.0, 2.0, 1.5, 1.0, 0.8]
	var radii   := [0.4, 0.7, 1.0, 1.3, 1.6]
	var y_base: float = 0.0
	for i in range(heights.size()):
		var cyl_mesh := CylinderMesh.new()
		cyl_mesh.top_radius = radii[i] * 0.4
		cyl_mesh.bottom_radius = radii[i]
		cyl_mesh.height = heights[i]
		var cyl := MeshInstance3D.new()
		cyl.mesh = cyl_mesh
		cyl.set_surface_override_material(0, mat)
		cyl.position.y = y_base + heights[i] * 0.5
		_mesh_root.add_child(cyl)
		y_base += heights[i]

	# Debris particles: small boxes orbiting the base
	var debris_mat := StandardMaterial3D.new()
	debris_mat.albedo_color = Color(0.3, 0.25, 0.2)
	debris_mat.emission_enabled = true
	debris_mat.emission = Color(0.35, 0.28, 0.22)
	debris_mat.emission_energy_multiplier = 0.8
	for i in range(8):
		var angle: float = (float(i) / 8.0) * TAU
		var d_mesh := BoxMesh.new()
		d_mesh.size = Vector3(0.25, 0.25, 0.25)
		var d := MeshInstance3D.new()
		d.mesh = d_mesh
		d.material_override = debris_mat
		d.position = Vector3(cos(angle) * 1.8, 0.5 + randf() * 2.0, sin(angle) * 1.8)
		_mesh_root.add_child(d)

	# Collision capsule
	var shape := CylinderShape3D.new()
	shape.radius = 1.5
	shape.height = 8.0
	collision_shape.shape = shape
	collision_shape.position.y = 4.0

func _process(delta: float) -> void:
	if not alive:
		return

	event_timer -= delta
	if event_timer <= 0.0:
		_finish()
		return

	# Spin the mesh
	spin_time += delta
	if _mesh_root:
		_mesh_root.rotation_degrees.y = spin_time * 180.0

	# Side-to-side movement
	position.x += side_dir * side_speed * delta
	if position.x >= 4.5:
		position.x = 4.5
		side_dir = -1.0
	elif position.x <= -4.5:
		position.x = -4.5
		side_dir = 1.0

func _finish() -> void:
	alive = false
	GameManager.boss_encounters += 1
	GameManager.add_score(500)
	GameManager.boss_defeated.emit()
	boss_finished.emit()
	queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("truck"):
		GameManager.damage_health(30)
