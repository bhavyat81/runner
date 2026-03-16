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
