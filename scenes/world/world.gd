extends Node3D

@export var world_size : float = 256
@onready var terrain_mesh = $MeshInstance3D

@export_range(4, 256, 4) var terrain_resolution := 32:
	set(new_resolution):
		terrain_resolution = new_resolution
		update_mesh()

@export var noise : FastNoiseLite:
	set(new_noise):
		noise = new_noise
		update_mesh()
		if noise:
			noise.changed.connect(update_mesh)

@export_range(4.0, 128.0, 4.0) var height : float = 64.0:
	set(new_height):
		height = new_height
		update_mesh()

func get_noise_height(x : float, y : float) -> float:
	return noise.get_noise_2d(x, y) * height

func get_noise_normal(x : float, y : float) -> Vector3:
	var epsilon := world_size / terrain_resolution
	var normal := Vector3(
		(get_noise_height(x+epsilon, y) - get_noise_height(x-epsilon, y)) / (2.0 * epsilon),
		1.0,
		(get_noise_height(x, y+epsilon) - get_noise_height(x, y-epsilon)) / (2.0 * epsilon)
	)
	return normal.normalized()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	update_mesh()

func update_mesh() -> void:
	if !is_node_ready(): return
	
	for child in terrain_mesh.get_children():
		if child: child.queue_free()
	
	var plane := PlaneMesh.new()
	plane.subdivide_depth = terrain_resolution
	plane.subdivide_width = terrain_resolution
	plane.size = Vector2(world_size, world_size)
	
	var plane_arrays := plane.get_mesh_arrays()
	var vertex_array : PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_VERTEX]
	var normal_array : PackedVector3Array = plane_arrays[ArrayMesh.ARRAY_NORMAL]
	var tangent_array : PackedFloat32Array = plane_arrays[ArrayMesh.ARRAY_TANGENT]
	
	for i : int in vertex_array.size():
		var vertex := vertex_array[i]
		var normal := Vector3.UP
		var tangent = Vector3.RIGHT
		if noise:
			vertex.y = get_noise_height(vertex.x, vertex.z)
			normal 	 = get_noise_normal(vertex.x, vertex.z)
			tangent  = normal.cross(Vector3.UP)
		vertex_array[i] = vertex
		normal_array[i] = normal
		tangent_array[4*i] 	 = tangent.x
		tangent_array[4*i+1] = tangent.y
		tangent_array[4*i+2] = tangent.z
		tangent_array[4*i+3] = 1.0
	
	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane_arrays)
	terrain_mesh.mesh = array_mesh
	terrain_mesh.create_trimesh_collision()
