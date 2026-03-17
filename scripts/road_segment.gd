# road_segment.gd
# A single chunk of 3D road. Recycled by the game scene to create infinite road.
# Procedurally builds: asphalt surface, dashed lane lines, solid edge lines,
# curb strips, raised concrete footpaths, and street lights.
# Supports environment theming (city, highway, bridge, tunnel).
extends Node3D

const SEGMENT_LENGTH: float = 40.0

# Road layout — must stay in sync with truck.gd / obstacle.gd / garbage_marker.gd
const ROAD_HALF_WIDTH: float = 5.0
const LANE_LINE_X: Array[float] = [-1.5, 1.5]
const EDGE_LINE_X: Array[float] = [-4.5, 4.5]
const CURB_X_SIGN: Array[int] = [-1, 1]
const FOOTPATH_HALF_WIDTH: float = 1.0
const FOOTPATH_CENTER_OFFSET: float = 6.0
const FOOTPATH_HEIGHT: float = 0.25
const DASH_LENGTH: float = 3.0
const DASH_GAP: float = 3.0

func _ready() -> void:
	_build_road()
	_build_dashed_lane_lines()
	_build_edge_lines()
	_build_curbs()
	_build_footpaths()
	_build_street_lights()

# Called by game.gd when the environment changes
func apply_environment(env: GameManager.GameEnvironment) -> void:
	# Tint road surface mesh (first child is road surface)
	var road_node: MeshInstance3D = _find_first_mesh_child()
	if road_node:
		var mat: StandardMaterial3D = road_node.material_override
		if mat:
			match env:
				GameManager.GameEnvironment.CITY:
					mat.albedo_color = Color(0.12, 0.12, 0.14)
				GameManager.GameEnvironment.HIGHWAY:
					mat.albedo_color = Color(0.18, 0.17, 0.15)
				GameManager.GameEnvironment.BRIDGE:
					mat.albedo_color = Color(0.20, 0.19, 0.18)
				GameManager.GameEnvironment.TUNNEL:
					mat.albedo_color = Color(0.08, 0.08, 0.10)

func _find_first_mesh_child() -> MeshInstance3D:
	for child in get_children():
		if child is MeshInstance3D:
			return child
	return null

func _build_road() -> void:
	var road := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(ROAD_HALF_WIDTH * 2.0, 0.1, SEGMENT_LENGTH)
	road.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.14, 1.0)
	road.material_override = mat
	add_child(road)

func _build_dashed_lane_lines() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 1.0, 1.0)
	mat.emission_energy_multiplier = 0.6

	for x: float in LANE_LINE_X:
		var period := DASH_LENGTH + DASH_GAP
		var z := -SEGMENT_LENGTH * 0.5 + DASH_LENGTH * 0.5 + DASH_GAP * 0.5
		while z <= SEGMENT_LENGTH * 0.5:
			var dash := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.2, 0.02, DASH_LENGTH)
			dash.mesh = mesh
			dash.material_override = mat
			dash.position = Vector3(x, 0.06, z)
			add_child(dash)
			z += period

func _build_edge_lines() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 1.0, 1.0)
	mat.emission_energy_multiplier = 0.6

	for x: float in EDGE_LINE_X:
		var line := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.22, 0.02, SEGMENT_LENGTH)
		line.mesh = mesh
		line.material_override = mat
		line.position = Vector3(x, 0.06, 0.0)
		add_child(line)

func _build_curbs() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.60, 0.58, 1.0)

	for s: int in CURB_X_SIGN:
		var curb := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.25, 0.2, SEGMENT_LENGTH)
		curb.mesh = mesh
		curb.material_override = mat
		curb.position = Vector3(s * (ROAD_HALF_WIDTH + 0.125), 0.1, 0.0)
		add_child(curb)

func _build_footpaths() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.76, 0.73, 1.0)

	for s: int in CURB_X_SIGN:
		var fp := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(FOOTPATH_HALF_WIDTH * 2.0, FOOTPATH_HEIGHT, SEGMENT_LENGTH)
		fp.mesh = mesh
		fp.material_override = mat
		fp.position = Vector3(s * FOOTPATH_CENTER_OFFSET, FOOTPATH_HEIGHT * 0.5, 0.0)
		add_child(fp)

func _build_street_lights() -> void:
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.25, 0.25, 0.28)

	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color(1.0, 0.9, 0.7)
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.9, 0.7)
	lamp_mat.emission_energy_multiplier = 2.0
	lamp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var num_lights: int = 3
	var spacing: float = SEGMENT_LENGTH / num_lights
	for i in range(num_lights):
		var z_pos: float = -SEGMENT_LENGTH * 0.5 + (i + 0.5) * spacing
		for s: int in CURB_X_SIGN:
			var pole_x: float = s * (FOOTPATH_CENTER_OFFSET + FOOTPATH_HALF_WIDTH * 0.5)

			var pole := MeshInstance3D.new()
			var pole_mesh := CylinderMesh.new()
			pole_mesh.top_radius = 0.05
			pole_mesh.bottom_radius = 0.05
			pole_mesh.height = 4.5
			pole.mesh = pole_mesh
			pole.set_surface_override_material(0, pole_mat)
			pole.position = Vector3(pole_x, 2.25, z_pos)
			add_child(pole)

			var lamp := MeshInstance3D.new()
			var lamp_mesh := BoxMesh.new()
			lamp_mesh.size = Vector3(0.4, 0.2, 0.4)
			lamp.mesh = lamp_mesh
			lamp.set_surface_override_material(0, lamp_mat)
			lamp.position = Vector3(pole_x, 4.65, z_pos)
			add_child(lamp)

			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.92, 0.75)
			light.light_energy = 0.6
			light.omni_range = 9.0
			light.position = Vector3(pole_x, 4.5, z_pos)
			add_child(light)

