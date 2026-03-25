# diamond.gd
# Rare collectible diamond — a spinning blue/cyan octahedron with bright glow.
# Awards +1 diamond on collection. Can be used to continue after death.
extends Area3D

const SPIN_SPEED: float = 120.0  # degrees per second
const COLLECT_EFFECT_SCENE := preload("res://scenes/collect_effect.tscn")
var _collected: bool = false
var _mesh_instance: MeshInstance3D = null
var _bob_time: float = 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_build_mesh()

func _build_mesh() -> void:
	# Octahedron-like shape: two pyramids joined at their base
	var diamond_root := Node3D.new()
	add_child(diamond_root)
	_mesh_instance = diamond_root

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.8, 1.0, 0.85)
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.9, 1.0)
	mat.emission_energy_multiplier = 3.5
	mat.metallic = 0.8
	mat.roughness = 0.1
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	# Top pyramid (pointing up)
	var top_mesh := CylinderMesh.new()
	top_mesh.top_radius = 0.0
	top_mesh.bottom_radius = 0.42
	top_mesh.height = 0.65
	top_mesh.radial_segments = 6
	var top_mi := MeshInstance3D.new()
	top_mi.mesh = top_mesh
	top_mi.material_override = mat
	top_mi.position.y = 0.32
	diamond_root.add_child(top_mi)

	# Bottom pyramid (pointing down)
	var bot_mesh := CylinderMesh.new()
	bot_mesh.top_radius = 0.42
	bot_mesh.bottom_radius = 0.0
	bot_mesh.height = 0.55
	bot_mesh.radial_segments = 6
	var bot_mi := MeshInstance3D.new()
	bot_mi.mesh = bot_mesh
	bot_mi.material_override = mat
	bot_mi.position.y = -0.27
	diamond_root.add_child(bot_mi)

	# Ground glow disc
	var glow_mesh := CylinderMesh.new()
	glow_mesh.top_radius = 0.7
	glow_mesh.bottom_radius = 0.7
	glow_mesh.height = 0.04
	var glow := MeshInstance3D.new()
	glow.mesh = glow_mesh
	glow.position.y = 0.03
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.1, 0.8, 1.0, 0.4)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.1, 0.9, 1.0)
	glow_mat.emission_energy_multiplier = 2.0
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = glow_mat
	add_child(glow)

	# Diamond label
	var label := Label3D.new()
	label.text = "💎"
	label.font_size = 56
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	label.no_depth_test = true
	label.pixel_size = 0.005
	label.position = Vector3(0.0, 1.0, 0.0)
	add_child(label)

	# Collision shape
	var shape := SphereShape3D.new()
	shape.radius = 0.7
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)

func _process(delta: float) -> void:
	if _collected:
		return
	_bob_time += delta
	rotation_degrees.y += SPIN_SPEED * delta
	# Bob up and down
	position.y = 1.0 + sin(_bob_time * 2.0) * 0.2
	# Pulse glow (handled via emission on mat)

func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if body.is_in_group("truck"):
		_collected = true
		GameManager.diamonds += 1
		GameManager.diamond_collected_signal.emit()
		GameManager._save_save_data()
		# Spawn collect effect (cyan color)
		if COLLECT_EFFECT_SCENE:
			var effect: Node3D = COLLECT_EFFECT_SCENE.instantiate()
			effect.position = global_position
			get_parent().add_child(effect)
			effect.setup(Color(0.1, 0.9, 1.0))
		queue_free()
