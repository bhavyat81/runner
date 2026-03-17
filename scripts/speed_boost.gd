# speed_boost.gd
# Blue lightning bolt pickup. When collected, grants 3 seconds of speed boost
# (1.5x current speed) and temporary invincibility. Has a pulsing blue glow.
extends Area3D

@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const LANE_X: Array[float] = [-3.0, 0.0, 3.0]

var pulse_time: float = 0.0
var collected: bool = false

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_build_boost()

func _build_boost() -> void:
	# Lightning bolt: tall thin prism shape using a box
	var bolt_mesh := BoxMesh.new()
	bolt_mesh.size = Vector3(0.4, 1.4, 0.4)
	mesh_instance.mesh = bolt_mesh
	mesh_instance.position.y = 0.9

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.4, 1.0, 1.0)
	mat.emission_energy_multiplier = 3.0
	mat.metallic = 0.3
	mat.roughness = 0.2
	mesh_instance.material_override = mat

	# Diagonal slash for lightning look (top angled piece)
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(0.35, 0.7, 0.35)
	var top_part := MeshInstance3D.new()
	top_part.mesh = top_mesh
	top_part.position = Vector3(0.15, 1.7, 0.0)
	top_part.rotation_degrees.z = -20.0
	top_part.material_override = mat
	add_child(top_part)

	# Bottom angled piece
	var bot_mesh := BoxMesh.new()
	bot_mesh.size = Vector3(0.35, 0.7, 0.35)
	var bot_part := MeshInstance3D.new()
	bot_part.mesh = bot_mesh
	bot_part.position = Vector3(-0.15, 0.2, 0.0)
	bot_part.rotation_degrees.z = -20.0
	bot_part.material_override = mat
	add_child(bot_part)

	# Glow halo (slightly larger cylinder)
	var glow_mesh := CylinderMesh.new()
	glow_mesh.top_radius = 0.9
	glow_mesh.bottom_radius = 0.9
	glow_mesh.height = 0.06
	var glow := MeshInstance3D.new()
	glow.mesh = glow_mesh
	glow.position.y = 0.04
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.2, 0.6, 1.0, 0.5)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.1, 0.5, 1.0, 1.0)
	glow_mat.emission_energy_multiplier = 2.0
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = glow_mat
	add_child(glow)

	# Collision shape
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 2.0, 1.4)
	collision_shape.shape = shape
	collision_shape.position.y = 1.0

func setup(lane: int) -> void:
	position.x = LANE_X[lane]

func _process(delta: float) -> void:
	if collected:
		return
	pulse_time += delta * 3.0
	var pulse := (sin(pulse_time) + 1.0) * 0.5
	var mat: StandardMaterial3D = mesh_instance.material_override
	if mat:
		mat.emission_energy_multiplier = lerpf(2.0, 5.0, pulse)
	# Slow spin
	rotation_degrees.y += 90.0 * delta

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("truck") and not collected:
		collected = true
		GameManager.activate_speed_boost()
		if body.has_method("set_invincible"):
			body.set_invincible(true)
		queue_free()
