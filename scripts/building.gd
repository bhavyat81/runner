# building.gd
# A procedural building on the side of the road with windows, ledges, and roof details.
extends Node3D

@onready var mesh_instance: MeshInstance3D = $Mesh

func setup(height: float, width: float, depth: float, color: Color) -> void:
\t# Main building body
\tvar box := BoxMesh.new()
\tbox.size = Vector3(width, height, depth)
\tmesh_instance.mesh = box
\tmesh_instance.position.y = height * 0.5

\tvar mat := StandardMaterial3D.new()
\tmat.albedo_color = color
\tmat.metallic = 0.05
\tmat.roughness = 0.7
\tmesh_instance.material_override = mat

\t# Add details
\t_add_windows(height, width, depth)
\t_add_ledges(height, width, depth, color)
\t_add_roof(height, width, depth)
\t_add_neon_accent(height, width, depth)

func _add_windows(height: float, width: float, depth: float) -> void:
\t# Create two window materials — lit and dark
\tvar lit_mat := StandardMaterial3D.new()
\tlit_mat.albedo_color = Color(1.0, 0.85, 0.5, 1.0)
\tlit_mat.emission_enabled = true
\tlit_mat.emission = Color(1.0, 0.85, 0.5, 1.0)
\tlit_mat.emission_energy_multiplier = 1.2

\tvar dark_mat := StandardMaterial3D.new()
\tdark_mat.albedo_color = Color(0.15, 0.2, 0.3, 1.0)

\tvar win_mesh := BoxMesh.new()
\twin_mesh.size = Vector3(0.45, 0.55, 0.06)

\tvar floors := int(height / 2.2)
\tvar cols := maxi(int(width / 1.2), 1)
\tvar start_x := -(cols - 1) * 0.6

\t# Front face windows
\tfor f in range(floors):
\t\tvar y_pos := 1.5 + f * 2.2
\t\tif y_pos >= height - 0.8:
\t\t\tbreak
\t\tfor c in range(cols):
\t\t\tvar win := MeshInstance3D.new()
\t\t\twin.mesh = win_mesh
\t\t\t# 70% chance of lit window
\t\t\twin.material_override = lit_mat if randf() < 0.7 else dark_mat
\t\t\tvar x_offset := start_x + c * 1.2
\t\t\twin.position = Vector3(x_offset, y_pos, depth * 0.5 + 0.03)
\t\t\tadd_child(win)

\t# Side face windows (visible from camera angle)
\tvar side_win_mesh := BoxMesh.new()
\t.side_win_mesh.size = Vector3(0.06, 0.55, 0.45)

\tvar side_cols := maxi(int(depth / 2.5), 1)
\tfor f in range(floors):
\t\tvar y_pos := 1.5 + f * 2.2
\t\tif y_pos >= height - 0.8:
\t\t\tbreak
\t\tfor c in range(side_cols):
\t\t\t# Left side of building
\t\t\tvar win_l := MeshInstance3D.new()
\t\t\twin_l.mesh = side_win_mesh
\t\t\twin_l.material_override = lit_mat if randf() < 0.5 else dark_mat
\t\t\tvar z_offset := -depth * 0.3 + c * 2.5
\t\t\twin_l.position = Vector3(-width * 0.5 - 0.03, y_pos, z_offset)
\t\t\tadd_child(win_l)

\t\t\t# Right side of building
\t\t\tvar win_r := MeshInstance3D.new()
\t\t\twin_r.mesh = side_win_mesh
\t\t\twin_r.material_override = lit_mat if randf() < 0.5 else dark_mat
\t\t\ twin_r.position = Vector3(width * 0.5 + 0.03, y_pos, z_offset)
\t\t\tadd_child(win_r)

func _add_ledges(height: float, width: float, depth: float, color: Color) -> void:
\tvar ledge_mat := StandardMaterial3D.new()
\tledge_mat.albedo_color = color.darkened(0.15)

\tvar ledge_mesh := BoxMesh.new()
\tledge_mesh.size = Vector3(width + 0.3, 0.15, depth + 0.3)

\t# Base ledge
\tvar base := MeshInstance3D.new()
\tbase.mesh = ledge_mesh
\tbase.material_override = ledge_mat
\tbase.position.y = 0.08
\tadd_child(base)

\t# Middle ledge (if tall enough)
\tif height > 8.0:
\t\tvar mid := MeshInstance3D.new()
\t\tmid.mesh = ledge_mesh
\t\tmid.material_override = ledge_mat
\t\tmid.position.y = height * 0.5
\t\tadd_child(mid)

func _add_roof(height: float, width: float, depth: float) -> void:
\t# Flat roof cap with slightly different shade
\tvar roof_mat := StandardMaterial3D.new()
\troof_mat.albedo_color = Color(0.35, 0.33, 0.3, 1.0)

\tvar roof_mesh := BoxMesh.new()
\troof_mesh.size = Vector3(width + 0.1, 0.2, depth + 0.1)

\tvar roof := MeshInstance3D.new()
\troof.mesh = roof_mesh
\troof.material_override = roof_mat
\troof.position.y = height + 0.1
\tadd_child(roof)

\t# Random chance of rooftop structure (AC unit / water tank)
\tif randf() < 0.4:
\t\tvar structure_mat := StandardMaterial3D.new()
\t\tstructure_mat.albedo_color = Color(0.4, 0.4, 0.42, 1.0)
\t\tvar struct_mesh := BoxMesh.new()
\t\tstruct_mesh.size = Vector3(1.0, 1.2, 1.0)
\t\tvar structure := MeshInstance3D.new()
\t\tstructure.mesh = struct_mesh
\t\tstructure.material_override = structure_mat
\t\tstructure.position = Vector3(randf_range(-1.0, 1.0), height + 0.8, 0.0)
\t\tadd_child(structure)

\t# Rooftop aviation light on tall buildings
\tif height > 12.0:
\t\tvar light_mat := StandardMaterial3D.new()
\t\tlight_mat.albedo_color = Color(1.0, 0.0, 0.0, 1.0)
\t\tlight_mat.emission_enabled = true
\t\tlight_mat.emission = Color(1.0, 0.0, 0.0, 1.0)
\t\tlight_mat.emission_energy_multiplier = 2.0
\t\tlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
\t\tvar light_sphere := SphereMesh.new()
\t\tlight_sphere.radius = 0.18
\t\tlight_sphere.height = 0.36
\t\tvar avi_light := MeshInstance3D.new()
\t\tavi_light.mesh = light_sphere
\t\tavi_light.material_override = light_mat
\t\tavi_light.position = Vector3(0.0, height + 0.5, 0.0)
\t\tadd_child(avi_light)

func _add_neon_accent(height: float, width: float, depth: float) -> void:
\t# Thin glowing neon strip at the base of the building
\tvar neon_colors: Array = [
\t\tColor(0.0, 1.0, 1.0, 1.0),
\t\tColor(1.0, 0.0, 1.0, 1.0),
\t\tColor(1.0, 0.95, 0.7, 1.0),
\t]
\tvar chosen_color: Color = neon_colors[randi() % neon_colors.size()]
\tvar neon_mat := StandardMaterial3D.new()
\tneon_mat.albedo_color = chosen_color
\tneon_mat.emission_enabled = true
\tneon_mat.emission = chosen_color
\tneon_mat.emission_energy_multiplier = 1.5
\tneon_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

\tvar strip_mesh := BoxMesh.new()
\tstrip_mesh.size = Vector3(width + 0.32, 0.08, depth + 0.32)
\tvar strip := MeshInstance3D.new()
\tstrip.mesh = strip_mesh
\tstrip.material_override = neon_mat
\tstrip.position = Vector3(0.0, 0.22, 0.0)
\tadd_child(strip)