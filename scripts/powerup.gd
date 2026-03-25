# powerup.gd
# Collectible power-up pickup (Area3D). Types: Shield, Magnet, Slow-Mo, Double Points.
extends Area3D

@onready var mesh_instance: MeshInstance3D = $Mesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

const LANE_X: Array[float] = [-3.0, 0.0, 3.0]

var pulse_time: float = 0.0
var collected: bool = false
var powerup_type: GameManager.PowerupType = GameManager.PowerupType.SHIELD

# Color per type
const TYPE_COLORS: Dictionary = {
	GameManager.PowerupType.SHIELD:        Color(0.2, 0.5, 1.0),
	GameManager.PowerupType.MAGNET:        Color(1.0, 0.2, 0.6),
	GameManager.PowerupType.SLOW_MO:       Color(0.3, 0.9, 0.9),
	GameManager.PowerupType.DOUBLE_POINTS: Color(1.0, 0.85, 0.0),
	GameManager.PowerupType.GHOST:         Color(0.55, 0.2, 1.0),
}

func _ready() -> void:
	collision_layer = 16
	collision_mask = 1
	body_entered.connect(_on_body_entered)

func setup(lane: int, type: GameManager.PowerupType) -> void:
	position.x = LANE_X[lane]
	powerup_type = type
	_build_visual()

func _build_visual() -> void:
	var color: Color = TYPE_COLORS.get(powerup_type, Color(1, 1, 1))

	# Main sphere
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 0.55
	sphere_mesh.height = 1.1
	mesh_instance.mesh = sphere_mesh
	mesh_instance.position.y = 1.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	mat.metallic = 0.4
	mat.roughness = 0.2
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = mat

	# Inner ring / detail mesh per type
	match powerup_type:
		GameManager.PowerupType.SHIELD:
			# Outer ring (torus)
			var torus := TorusMesh.new()
			torus.inner_radius = 0.6
			torus.outer_radius = 0.75
			var ring := MeshInstance3D.new()
			ring.mesh = torus
			ring.material_override = mat
			ring.position.y = 1.0
			add_child(ring)
		GameManager.PowerupType.MAGNET:
			# U-shape made of two cylinders
			var cyl_mat := StandardMaterial3D.new()
			cyl_mat.albedo_color = color
			cyl_mat.emission_enabled = true
			cyl_mat.emission = color
			cyl_mat.emission_energy_multiplier = 2.0
			for dx in [-0.3, 0.3]:
				var cyl_mesh := CylinderMesh.new()
				cyl_mesh.top_radius = 0.1
				cyl_mesh.bottom_radius = 0.1
				cyl_mesh.height = 0.5
				var cyl := MeshInstance3D.new()
				cyl.mesh = cyl_mesh
				cyl.material_override = cyl_mat
				cyl.position = Vector3(dx, 1.2, 0.0)
				add_child(cyl)
		GameManager.PowerupType.SLOW_MO:
			# Clock face: flat disc
			var disc := CylinderMesh.new()
			disc.top_radius = 0.55
			disc.bottom_radius = 0.55
			disc.height = 0.08
			var disc_node := MeshInstance3D.new()
			disc_node.mesh = disc
			disc_node.material_override = mat
			disc_node.position = Vector3(0.0, 1.0, 0.0)
			disc_node.rotation_degrees.x = 90.0
			add_child(disc_node)
		GameManager.PowerupType.DOUBLE_POINTS:
			# Star shape: two overlapping boxes
			for angle in [0.0, 45.0]:
				var box_mesh := BoxMesh.new()
				box_mesh.size = Vector3(0.25, 0.7, 0.25)
				var box_node := MeshInstance3D.new()
				box_node.mesh = box_mesh
				box_node.material_override = mat
				box_node.position = Vector3(0.0, 1.0, 0.0)
				box_node.rotation_degrees.y = angle
				add_child(box_node)
		GameManager.PowerupType.GHOST:
			# Ghost: translucent outer sphere shell + ghost-face label
			var ghost_mat := StandardMaterial3D.new()
			ghost_mat.albedo_color = Color(0.55, 0.2, 1.0, 0.35)
			ghost_mat.emission_enabled = true
			ghost_mat.emission = Color(0.4, 0.9, 1.0)
			ghost_mat.emission_energy_multiplier = 3.0
			ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var outer_sphere_mesh := SphereMesh.new()
			outer_sphere_mesh.radius = 0.72
			outer_sphere_mesh.height = 1.44
			var outer_sphere := MeshInstance3D.new()
			outer_sphere.mesh = outer_sphere_mesh
			outer_sphere.material_override = ghost_mat
			outer_sphere.position.y = 1.0
			add_child(outer_sphere)
			var ghost_label := Label3D.new()
			ghost_label.text = "👻"
			ghost_label.font_size = 64
			ghost_label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			ghost_label.no_depth_test = true
			ghost_label.pixel_size = 0.006
			ghost_label.position = Vector3(0.0, 1.0, 0.0)
			add_child(ghost_label)

	# Glow disc on ground
	var glow_mesh := CylinderMesh.new()
	glow_mesh.top_radius = 0.9
	glow_mesh.bottom_radius = 0.9
	glow_mesh.height = 0.04
	var glow := MeshInstance3D.new()
	glow.mesh = glow_mesh
	glow.position.y = 0.03
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(color.r, color.g, color.b, 0.5)
	glow_mat.emission_enabled = true
	glow_mat.emission = color
	glow_mat.emission_energy_multiplier = 1.5
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = glow_mat
	add_child(glow)

	# Collision shape
	var shape := SphereShape3D.new()
	shape.radius = 1.0
	collision_shape.shape = shape
	collision_shape.position.y = 1.0

func _process(delta: float) -> void:
	if collected:
		return
	pulse_time += delta * 2.5
	var pulse := (sin(pulse_time) + 1.0) * 0.5
	var mat: StandardMaterial3D = mesh_instance.material_override
	if mat:
		mat.emission_energy_multiplier = lerpf(1.5, 4.0, pulse)
	rotation_degrees.y += 60.0 * delta
	# Bob up and down
	mesh_instance.position.y = 1.0 + sin(pulse_time) * 0.15

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("truck") and not collected:
		collected = true
		GameManager.activate_powerup(powerup_type)
		queue_free()
