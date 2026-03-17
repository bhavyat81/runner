# road_segment.gd
# A single chunk of 3D road. Recycled by the game scene to create infinite road.
# Procedurally builds: asphalt surface, dashed lane lines, solid edge lines,
# curb strips, and raised concrete footpaths on both sides.
extends Node3D

const SEGMENT_LENGTH: float = 40.0

# Road layout — must stay in sync with truck.gd / obstacle.gd / garbage_marker.gd
const ROAD_HALF_WIDTH: float = 5.0       # Road spans X = -5 to +5 (10 units wide)
const LANE_LINE_X: Array[float] = [-1.5, 1.5]   # Dashed dividers between the 3 lanes
const EDGE_LINE_X: Array[float] = [-4.5, 4.5]   # Solid white edge lines
const CURB_X_SIGN: Array[int] = [-1, 1]          # Curb side sign multipliers
const FOOTPATH_HALF_WIDTH: float = 1.0            # Half of 2.0-unit footpath width
const FOOTPATH_CENTER_OFFSET: float = 6.0         # |X| of footpath centre (5.0 + 1.0)
const FOOTPATH_HEIGHT: float = 0.25               # How high the footpath sits above Y = 0

# Dashed lane line parameters
const DASH_LENGTH: float = 3.0
const DASH_GAP: float = 3.0  # gap between dashes (dash + gap = one period)

func _ready() -> void:
	_build_road()
	_build_dashed_lane_lines()
	_build_edge_lines()
	_build_curbs()
	_build_footpaths()

# --- Road surface (dark asphalt) ---
func _build_road() -> void:
	var road := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(ROAD_HALF_WIDTH * 2.0, 0.1, SEGMENT_LENGTH)
	road.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.12, 0.14, 1.0)
	road.material_override = mat
	add_child(road)

# --- Dashed white lane dividers at X = ±1.5 ---
# Each dash is 3 units long with a 3-unit gap (6-unit repeat period).
func _build_dashed_lane_lines() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 1.0, 1.0, 1.0)
	mat.emission_energy_multiplier = 0.6

	for x: float in LANE_LINE_X:
		var period := DASH_LENGTH + DASH_GAP
		# First dash centre starts half a period in from the segment start edge
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

# --- Solid white edge lines at X = ±4.5 ---
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

# --- Curb strips at road-to-footpath boundary (X = ±5.0) ---
func _build_curbs() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.60, 0.58, 1.0)

	for s: int in CURB_X_SIGN:
		var curb := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.25, 0.2, SEGMENT_LENGTH)
		curb.mesh = mesh
		curb.material_override = mat
		# Centre the curb at X = ±5.125 so its inner edge meets the road at ±5.0
		curb.position = Vector3(s * (ROAD_HALF_WIDTH + 0.125), 0.1, 0.0)
		add_child(curb)

# --- Raised concrete footpaths (X = ±5.0 to ±7.0) ---
func _build_footpaths() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.78, 0.76, 0.73, 1.0)

	for s: int in CURB_X_SIGN:
		var fp := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(FOOTPATH_HALF_WIDTH * 2.0, FOOTPATH_HEIGHT, SEGMENT_LENGTH)
		fp.mesh = mesh
		fp.material_override = mat
		# Centre at ±6.0; top of footpath sits at Y = FOOTPATH_HEIGHT (raised above road)
		fp.position = Vector3(s * FOOTPATH_CENTER_OFFSET, FOOTPATH_HEIGHT * 0.5, 0.0)
		add_child(fp)

