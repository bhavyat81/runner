# building.gd
# A procedural building on the side of the road.
extends Node3D

@onready var mesh_instance: MeshInstance3D = $Mesh

func setup(height: float, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(4.0, height, 6.0)
	mesh_instance.mesh = box
	mesh_instance.position.y = height * 0.5

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_instance.material_override = mat

	# Add window lights for visual polish
	_add_windows(height)

func _add_windows(height: float) -> void:
	var window_mat := StandardMaterial3D.new()
	window_mat.albedo_color = Color(1.0, 0.95, 0.7, 1.0)
	window_mat.emission_enabled = true
	window_mat.emission = Color(1.0, 0.9, 0.6, 1.0)
	window_mat.emission_energy_multiplier = 0.4

	var win_mesh := BoxMesh.new()
	win_mesh.size = Vector3(0.5, 0.5, 0.05)

	var floors := int(height / 2.0)
	for f in range(floors):
		for w in range(2):
			var win := MeshInstance3D.new()
			win.mesh = win_mesh
			win.material_override = window_mat
			var x_offset := -0.8 + w * 1.6
			var y_pos := 1.5 + f * 2.0
			if y_pos < height - 0.5:
				win.position = Vector3(x_offset, y_pos, 3.02)
				add_child(win)
