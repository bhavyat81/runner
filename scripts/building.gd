# building.gd
# A procedural building on the side of the road with windows, ledges, roof details,
# and a 30% chance of an animated neon billboard on the front face.
extends Node3D

@onready var mesh_instance: MeshInstance3D = $Mesh

# Billboard cycling: neon colors to animate the sign
const BILLBOARD_COLORS: Array[Color] = [
	Color(0.0, 1.0, 1.0),    # Cyan
	Color(1.0, 0.0, 1.0),    # Magenta
	Color(1.0, 1.0, 0.0),    # Yellow
	Color(0.0, 1.0, 0.2),    # Green
	Color(1.0, 0.3, 0.0),    # Orange
]
const SIGN_TEXTS: Array[String] = [
	"NEON", "RUSH", "24/7", "OPEN", "CAFE", "PIZZA",
	"BAR", "TAXI", "HOTEL", "SHOP", "EXIT", "DANCE",
	"CLUB", "NEWS", "SALE",
]
const SIGN_FONT_SCALE: float = 55.0   # pixels per unit of billboard height
const SIGN_FONT_MIN: int = 32
const SIGN_FONT_MAX: int = 128
const SIGN_OUTLINE_SIZE: int = 4
var _billboard_mat: StandardMaterial3D = null
var _billboard_color_idx: int = 0
var _billboard_timer: float = 0.0
const BILLBOARD_CYCLE_TIME: float = 2.5

func setup(height: float, width: float, depth: float, color: Color) -> void:
	# Main building body
	var box := BoxMesh.new()
	box.size = Vector3(width, height, depth)
	mesh_instance.mesh = box
	mesh_instance.position.y = height * 0.5

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.material_override = mat

	# Add details
	_add_windows(height, width, depth)
	_add_ledges(height, width, depth, color)
	_add_roof(height, width, depth)

	# 30% chance of billboard
	if randf() < 0.3:
		_add_billboard(height, width, depth)

func _process(delta: float) -> void:
	if _billboard_mat == null:
		return
	_billboard_timer += delta
	if _billboard_timer >= BILLBOARD_CYCLE_TIME:
		_billboard_timer = 0.0
		_billboard_color_idx = (_billboard_color_idx + 1) % BILLBOARD_COLORS.size()
		var c: Color = BILLBOARD_COLORS[_billboard_color_idx]
		_billboard_mat.albedo_color = c
		_billboard_mat.emission = c

func _add_billboard(height: float, width: float, depth: float) -> void:
	var b_width: float = minf(width * 0.8, 3.0)
	var b_height: float = minf(height * 0.25, 2.0)
	var b_y: float = height * 0.75

	# Dark frame behind the glowing part
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(b_width + 0.2, b_height + 0.2, 0.12)
	var frame := MeshInstance3D.new()
	frame.mesh = frame_mesh
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.05, 0.05, 0.08)
	frame.material_override = frame_mat
	frame.position = Vector3(0.0, b_y, depth * 0.5 + 0.06)
	add_child(frame)

	# Glowing sign panel
	var sign_mesh := BoxMesh.new()
	sign_mesh.size = Vector3(b_width, b_height, 0.08)
	var sign_node := MeshInstance3D.new()
	sign_node.mesh = sign_mesh
	_billboard_mat = StandardMaterial3D.new()
	var c0: Color = BILLBOARD_COLORS[0]
	_billboard_mat.albedo_color = c0
	_billboard_mat.emission_enabled = true
	_billboard_mat.emission = c0
	_billboard_mat.emission_energy_multiplier = 2.5
	_billboard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sign_node.material_override = _billboard_mat
	sign_node.position = Vector3(0.0, b_y, depth * 0.5 + 0.16)
	add_child(sign_node)

	# Text label on the billboard
	var label := Label3D.new()
	label.text = SIGN_TEXTS[randi() % SIGN_TEXTS.size()]
	label.font_size = int(clampf(b_height * SIGN_FONT_SCALE, SIGN_FONT_MIN, SIGN_FONT_MAX))
	label.modulate = Color.WHITE
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	label.outline_size = SIGN_OUTLINE_SIZE
	label.position = Vector3(0.0, b_y, depth * 0.5 + 0.21)
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = false
	add_child(label)

func _add_windows(height: float, width: float, depth: float) -> void:
	# Create two window materials — lit and dark
	var lit_mat := StandardMaterial3D.new()
	lit_mat.albedo_color = Color(1.0, 0.95, 0.7, 1.0)
	lit_mat.emission_enabled = true
	lit_mat.emission = Color(1.0, 0.9, 0.6, 1.0)
	lit_mat.emission_energy_multiplier = 0.5

	var dark_mat := StandardMaterial3D.new()
	dark_mat.albedo_color = Color(0.15, 0.2, 0.3, 1.0)

	var win_mesh := BoxMesh.new()
	win_mesh.size = Vector3(0.45, 0.55, 0.06)

	var floors := int(height / 2.2)
	var cols := maxi(int(width / 1.2), 1)
	var start_x := -(cols - 1) * 0.6

	# Front face windows
	for f in range(floors):
		var y_pos := 1.5 + f * 2.2
		if y_pos >= height - 0.8:
			break
		for c in range(cols):
			var win := MeshInstance3D.new()
			win.mesh = win_mesh
			# 70% chance of lit window
			win.material_override = lit_mat if randf() < 0.7 else dark_mat
			var x_offset := start_x + c * 1.2
			win.position = Vector3(x_offset, y_pos, depth * 0.5 + 0.03)
			add_child(win)

	# Side face windows (visible from camera angle)
	var side_win_mesh := BoxMesh.new()
	side_win_mesh.size = Vector3(0.06, 0.55, 0.45)

	var side_cols := maxi(int(depth / 2.5), 1)
	for f in range(floors):
		var y_pos := 1.5 + f * 2.2
		if y_pos >= height - 0.8:
			break
		for c in range(side_cols):
			# Left side of building
			var win_l := MeshInstance3D.new()
			win_l.mesh = side_win_mesh
			win_l.material_override = lit_mat if randf() < 0.5 else dark_mat
			var z_offset := -depth * 0.3 + c * 2.5
			win_l.position = Vector3(-width * 0.5 - 0.03, y_pos, z_offset)
			add_child(win_l)

			# Right side of building
			var win_r := MeshInstance3D.new()
			win_r.mesh = side_win_mesh
			win_r.material_override = lit_mat if randf() < 0.5 else dark_mat
			win_r.position = Vector3(width * 0.5 + 0.03, y_pos, z_offset)
			add_child(win_r)

func _add_ledges(height: float, width: float, depth: float, color: Color) -> void:
	var ledge_mat := StandardMaterial3D.new()
	ledge_mat.albedo_color = color.darkened(0.15)

	var ledge_mesh := BoxMesh.new()
	ledge_mesh.size = Vector3(width + 0.3, 0.15, depth + 0.3)

	# Base ledge
	var base := MeshInstance3D.new()
	base.mesh = ledge_mesh
	base.material_override = ledge_mat
	base.position.y = 0.08
	add_child(base)

	# Middle ledge (if tall enough)
	if height > 8.0:
		var mid := MeshInstance3D.new()
		mid.mesh = ledge_mesh
		mid.material_override = ledge_mat
		mid.position.y = height * 0.5
		add_child(mid)

func _add_roof(height: float, width: float, depth: float) -> void:
	# Flat roof cap with slightly different shade
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.35, 0.33, 0.3, 1.0)

	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(width + 0.1, 0.2, depth + 0.1)

	var roof := MeshInstance3D.new()
	roof.mesh = roof_mesh
	roof.material_override = roof_mat
	roof.position.y = height + 0.1
	add_child(roof)

	# Random chance of rooftop structure (AC unit / water tank)
	if randf() < 0.4:
		var structure_mat := StandardMaterial3D.new()
		structure_mat.albedo_color = Color(0.4, 0.4, 0.42, 1.0)
		var struct_mesh := BoxMesh.new()
		struct_mesh.size = Vector3(1.0, 1.2, 1.0)
		var structure := MeshInstance3D.new()
		structure.mesh = struct_mesh
		structure.material_override = structure_mat
		structure.position = Vector3(randf_range(-1.0, 1.0), height + 0.8, 0.0)
		add_child(structure)
