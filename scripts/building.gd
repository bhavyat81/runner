# building.gd
# A procedural building on the side of the road with windows, ledges, and roof details.
extends Node3D

@onready var mesh_instance: MeshInstance3D = $Mesh

func setup(height: float, width: float, depth: float, color: Color) -> void:
	# Main building body
	var box := BoxMesh.new()
	box.size = Vector3(width, height, depth)
	mesh_instance.mesh = box
	mesh_instance.position.y = height * 0.5

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.05
	mat.roughness = 0.7
	mesh_instance.material_override = mat

	# Add details
	_add_windows(height, width, depth)
	_add_ledges(height, width, depth, color)
	_add_roof(height, width, depth)
	_add_neon_accent(height, width, depth)

func _add_windows(height: float, width: float, depth: float) -> void:
	# Create two window materials — lit and dark
	var lit_mat := StandardMaterial3D.new()
	lit_mat.albedo_color = Color(1.0, 0.85, 0.5, 1.0)
	lit_mat.emission_enabled = true
	lit_mat.emission = Color(1.0, 0.85, 0.5, 1.0)
	lit_mat.emission_energy_multiplier = 1.2

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

	# Rooftop aviation light on tall buildings
	if height > 12.0:
		var light_mat := StandardMaterial3D.new()
		light_mat.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
		light_mat.emission_enabled = true
		light_mat.emission = Color(1.0, 0.0, 0.0, 1.0)
		light_mat.emission_energy_multiplier = 2.0
		light_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var light_sphere := SphereMesh.new()
		light_sphere.radius = 0.18
		light_sphere.height = 0.36
		var avi_light := MeshInstance3D.new()
		avi_light.mesh = light_sphere
		avi_light.material_override = light_mat
		avi_light.position = Vector3(0.0, height + 0.5, 0.0)
		add_child(avi_light)

func _add_neon_accent(height: float, width: float, depth: float) -> void:
	# Thin glowing neon strip at the base of the building
	var neon_colors := [
		Color(0.0, 1.0, 1.0, 1.0),   # cyan
		Color(1.0, 0.0, 1.0, 1.0),   # magenta
		Color(1.0, 0.95, 0.7, 1.0),  # warm white
	]
	var chosen_color := neon_colors[randi() % neon_colors.size()]
	var neon_mat := StandardMaterial3D.new()
	neon_mat.albedo_color = chosen_color
	neon_mat.emission_enabled = true
	neon_mat.emission = chosen_color
	neon_mat.emission_energy_multiplier = 1.5
	neon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(width + 0.32, 0.08, depth + 0.32)
	var strip := MeshInstance3D.new()
	strip.mesh = strip_mesh
	strip.material_override = neon_mat
	strip.position = Vector3(0.0, 0.22, 0.0)
	add_child(strip)
