# collect_effect.gd
# Simple mesh-based particle burst effect for mobile compatibility.
# Spawns several small colored mesh instances that fly outward and fade,
# then frees itself after ~0.5 seconds.
extends Node3D

var _particles: Array[MeshInstance3D] = []
var _velocities: Array[Vector3] = []
var _lifetimes: Array[float] = []
var _ring: MeshInstance3D = null
var _ring_mat: StandardMaterial3D = null
var _elapsed: float = 0.0
const LIFETIME: float = 0.5
const PARTICLE_COUNT: int = 8

func setup(color: Color) -> void:
	for i in range(PARTICLE_COUNT):
		var mi := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.18
		sphere.height = 0.36
		mi.mesh = sphere

		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 4.0
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat

		add_child(mi)
		_particles.append(mi)

		# Random outward velocity
		var angle := (float(i) / float(PARTICLE_COUNT)) * TAU
		var speed := randf_range(2.5, 5.0)
		_velocities.append(Vector3(cos(angle) * speed, randf_range(2.0, 4.5), sin(angle) * speed))
		_lifetimes.append(LIFETIME * randf_range(0.7, 1.0))

	# Ring burst — expanding torus that fades out
	var torus := TorusMesh.new()
	torus.inner_radius = 0.1
	torus.outer_radius = 0.5
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = color
	_ring_mat.emission_enabled = true
	_ring_mat.emission = color
	_ring_mat.emission_energy_multiplier = 4.0
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = _ring_mat
	_ring.rotation_degrees.x = 90.0
	add_child(_ring)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= LIFETIME:
		queue_free()
		return

	for i in range(_particles.size()):
		if _elapsed > _lifetimes[i]:
			_particles[i].visible = false
			continue
		var t := _elapsed / _lifetimes[i]
		_particles[i].position += _velocities[i] * delta
		_velocities[i].y -= 9.8 * delta
		var mat: StandardMaterial3D = _particles[i].material_override
		if mat:
			mat.albedo_color.a = 1.0 - t

	# Expand ring outward and fade
	if _ring and _ring_mat:
		var rt := _elapsed / LIFETIME
		var ring_scale := lerpf(0.5, 4.0, rt)
		_ring.scale = Vector3(ring_scale, ring_scale, ring_scale)
		_ring_mat.albedo_color.a = 1.0 - rt
