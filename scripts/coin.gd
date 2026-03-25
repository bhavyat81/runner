# coin.gd
# Collectible gold coin — a spinning disc that awards +1 coin on collection.
# Spawned by game.gd and recycled as the road scrolls.
extends Area3D

const SPIN_SPEED: float = 3.0
const COIN_FRENZY_MULTIPLIER: int = 3
const COLLECT_EFFECT_SCENE := preload("res://scenes/collect_effect.tscn")
var _collected: bool = false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	_build_mesh()

func _build_mesh() -> void:
	# Gold coin: flat cylinder / disc
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.55
	cyl.bottom_radius = 0.55
	cyl.height = 0.18

	var mi := MeshInstance3D.new()
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.82, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.0)
	mat.emission_energy_multiplier = 1.8
	mat.metallic = 0.7
	mat.roughness = 0.3
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mi.material_override = mat
	add_child(mi)

	# Collision shape matching the disc
	var shape := CylinderShape3D.new()
	shape.radius = 0.55
	shape.height = 0.4
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)

func _process(delta: float) -> void:
	if _collected:
		return
	rotation.y += SPIN_SPEED * delta

func _on_body_entered(body: Node3D) -> void:
	if _collected:
		return
	if body.is_in_group("truck"):
		_collected = true
		# Award coin
		var coin_gain: int = COIN_FRENZY_MULTIPLIER if (GameManager.power_active and GameManager.selected_power == GameManager.PreGamePower.COIN_FRENZY) else 1
		GameManager.coins += coin_gain
		# Spawn collect effect
		if COLLECT_EFFECT_SCENE:
			var effect: Node3D = COLLECT_EFFECT_SCENE.instantiate()
			effect.position = global_position
			get_parent().add_child(effect)
			effect.setup(Color(1.0, 0.82, 0.1))
		queue_free()
