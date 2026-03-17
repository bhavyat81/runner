# collect_effect.gd
# Mesh-based particle burst effect for mobile compatibility.
# Spawns colored confetti particles on collection or smoke+sparks on obstacle hit.
extends Node3D

var _particles: Array[MeshInstance3D] = []
var _velocities: Array[Vector3] = []
var _lifetimes: Array[float] = []
var _elapsed: float = 0.0
const LIFETIME: float = 0.7

func setup(color: Color) -> void:
	var is_smoke: bool = (color.r > 0.4 and color.g < 0.3)  # red-ish = obstacle hit
	if is_smoke:
		_setup_smoke_sparks()
	else:
		_setup_confetti(color)

func _setup_confetti(base_color: Color) -> void:
	var count: int = 24
	var colors: Array[Color] = [
		Color(0.1, 1.0, 0.2),   # green
		Color(1.0, 1.0, 0.0),   # yellow
		Color(1.0, 1.0, 1.0),   # white
		Color(0.2, 0.8, 1.0),   # cyan
		base_color,
	]
	for i in range(count):
		var mi := MeshInstance3D.new()
		# Mix of tiny boxes and spheres for confetti look
		if i % 3 == 0:
			var box := BoxMesh.new()
			box.size = Vector3(0.15, 0.08, 0.15)
			mi.mesh = box
		else:
			var sph := SphereMesh.new()
			sph.radius = 0.1
			sph.height = 0.2
			mi.mesh = sph

		var c: Color = colors[i % colors.size()]
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 2.5
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		add_child(mi)
		_particles.append(mi)

		var angle: float = (float(i) / float(count)) * TAU
		var horiz_speed := randf_range(2.0, 5.5)
		var up_speed := randf_range(3.0, 7.0)
		_velocities.append(Vector3(cos(angle) * horiz_speed, up_speed, sin(angle) * horiz_speed))
		_lifetimes.append(LIFETIME * randf_range(0.6, 1.0))

func _setup_smoke_sparks() -> void:
	# Gray/brown smoke puffs
	for i in range(15):
		var mi := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = randf_range(0.15, 0.3)
		sph.height = sph.radius * 2.0
		mi.mesh = sph
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.35, 0.3, 0.8)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		add_child(mi)
		_particles.append(mi)
		var angle: float = (float(i) / 15.0) * TAU
		_velocities.append(Vector3(cos(angle) * randf_range(0.5, 2.5), randf_range(1.0, 3.5), sin(angle) * randf_range(0.5, 2.5)))
		_lifetimes.append(LIFETIME * randf_range(0.7, 1.0))

	# Orange sparks
	for i in range(10):
		var mi := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.07
		sph.height = 0.14
		mi.mesh = sph
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.5, 0.0)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.4, 0.0)
		mat.emission_energy_multiplier = 3.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mi.material_override = mat
		add_child(mi)
		_particles.append(mi)
		var angle: float = randf_range(0.0, TAU)
		_velocities.append(Vector3(cos(angle) * randf_range(3.0, 6.0), randf_range(4.0, 8.0), sin(angle) * randf_range(3.0, 6.0)))
		_lifetimes.append(LIFETIME * 0.5 * randf_range(0.5, 1.0))

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
