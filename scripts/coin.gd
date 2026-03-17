# coin.gd
# A small golden spinning coin collectible that spawns on the road.
# Extends Area3D — body_entered signals coin collection.
extends Area3D

const COIN_RADIUS: float = 0.28
const COIN_HEIGHT: float = 0.06
const SPIN_SPEED: float = 3.5

var collected: bool = false
var _bob_time: float = 0.0

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_build_coin_mesh()

func _build_coin_mesh() -> void:
	var coin_mat := StandardMaterial3D.new()
	coin_mat.albedo_color = Color(1.0, 0.85, 0.0, 1.0)
	coin_mat.metallic = 0.8
	coin_mat.roughness = 0.2
	coin_mat.emission_enabled = true
	coin_mat.emission = Color(1.0, 0.75, 0.0, 1.0)
	coin_mat.emission_energy_multiplier = 1.2

	var coin_mesh := CylinderMesh.new()
	coin_mesh.top_radius = COIN_RADIUS
	coin_mesh.bottom_radius = COIN_RADIUS
	coin_mesh.height = COIN_HEIGHT

	var mi := MeshInstance3D.new()
	mi.mesh = coin_mesh
	mi.material_override = coin_mat
	add_child(mi)

	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = Color(0.9, 0.7, 0.0, 1.0)
	edge_mat.metallic = 0.6
	edge_mat.roughness = 0.3
	edge_mat.emission_enabled = true
	edge_mat.emission = Color(0.9, 0.65, 0.0, 1.0)
	edge_mat.emission_energy_multiplier = 0.8

	var col_shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = COIN_RADIUS
	cyl.height = COIN_HEIGHT + 0.2
	col_shape.shape = cyl
	add_child(col_shape)

	_bob_time = randf_range(0.0, TAU)

func _process(delta: float) -> void:
	if collected:
		return
	rotation.y += SPIN_SPEED * delta
	_bob_time += delta * 2.5
	position.y = 0.55 + sin(_bob_time) * 0.12

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("truck") and not collected:
		collected = true
		GameManager.collect_road_coin()
		queue_free()
