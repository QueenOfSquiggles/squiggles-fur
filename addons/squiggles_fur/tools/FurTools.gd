@tool
class_name FurTools

"""
A big pile of variables and functions that are useful for generating fur layers. You can totally use these functions to build your own system as you see fit, but the basic implementation targets ShellFur instances directly
"""

const SHELL_FUR_GROUP_ID = "shell_fur_instance_mesh"
const FUR_MATERIAL := preload("res://addons/squiggles_fur/assets/furry_material.tres")
static var fur_thread : Thread

class FurryModelContext:
	var mesh_shells := {
		# mesh -> [shells]
	}
	var shell_layer_depth := 0.1
	var shell_count := 1.0
	var shell_length := 1.0
	var style_base_colour := Color.BLACK
	var style_tip_colour := Color.WHITE
	var style_shadow :MeshInstance3D.ShadowCastingSetting = MeshInstance3D.SHADOW_CASTING_SETTING_OFF
	var target_layer_filter : PackedInt32Array = []
	var material : Material

	func _init(fur : ShellFur = null) -> void:
		if not fur:
			# you must initialize all of the properties on your own
			return
		update_properties(fur)

	func update_properties(fur : ShellFur) -> void:
		shell_count = fur.shells_layer_count
		shell_length = fur.shells_strand_length
		shell_layer_depth = shell_length / shell_count
		style_base_colour = fur.style_base_colour
		style_tip_colour = fur.style_tip_colour
		style_shadow = fur.style_shadow
		target_layer_filter = fur.target_surfaces
		if fur.style_material_override:
			material = fur.style_material_override
		else:
			material = FUR_MATERIAL

	func load_all_shells(fur : ShellFur) -> void:
		var targets := FurTools.get_target_meshes(fur)
		for target in targets:
			var shells := FurTools.get_instanced_shells_for(target)
			add(target, shells)

	func add(mesh: MeshInstance3D, shells: Array[MeshInstance3D]) -> void:
		mesh_shells[mesh] = shells

	func get_shells_for(mesh : MeshInstance3D) -> Array[MeshInstance3D]:
		return mesh_shells[mesh]
	
	func clean_data() -> void:
		for mesh in mesh_shells.keys():
			var shells := mesh_shells[mesh] as Array[MeshInstance3D]
			var buffer := []
			for shell in shells:
				if not is_instance_valid(shell):
					buffer.append(shell)
			for b in buffer:
				shells.erase(b)
			mesh_shells[mesh] = shells




#	- - - - - - - -
#	Synchronous
#	- - - - - - - -

"""
	Performs a rudimentary mesh extrusion on the targeted surfaces.
"""
static func generate_shell_layer(mesh: ArrayMesh, layer_index : int, fur: ShellFur) -> ArrayMesh:
	if not mesh:
		printerr("Generating a shell layer for a mesh that is not an ArrayMesh!!!!")
		return
	var shell := ArrayMesh.new()
	var mdt := MeshDataTool.new()
	var depth := (fur.shells_strand_length / fur.shells_layer_count) * float(layer_index)
	for s in range(mesh.get_surface_count()):
		if len(fur.target_surfaces) > 0 and not s in fur.target_surfaces:
			continue
		mdt.create_from_surface(mesh, s)
		for v in range(mdt.get_vertex_count()):
			var faces = mdt.get_vertex_faces(v)
			var sum_normal :Vector3= Vector3.ZERO
			for f in faces:
				sum_normal += mdt.get_face_normal(f)
			sum_normal /= float(len(faces))
			var pos = mdt.get_vertex(v)
			pos += sum_normal.normalized() * depth
			mdt.set_vertex(v, pos)
		mdt.commit_to_surface(shell)
	return shell

"""
	Finds all of the target MeshInstance3D's for the given ShellFur node
"""
static func get_target_meshes(fur : ShellFur) -> Array[MeshInstance3D]:
	var buffer :Array[MeshInstance3D] = []
	var node :Node = fur.target_root_override
	if not node:
		node = fur.get_parent()
	if node is MeshInstance3D:
		buffer.append(node as MeshInstance3D)
	var targets = node.find_children("*", "MeshInstance3D", fur.target_search_recursive)
	for entry in targets:
		if entry.is_in_group(SHELL_FUR_GROUP_ID):
			continue # omit existing fur shell layers
		buffer.append(entry as MeshInstance3D)
	return buffer

"""
	Finds all of the instanced shell layer MeshInstance3D's for the given MeshInstance3D
"""
static func get_instanced_shells_for(mesh : MeshInstance3D) -> Array[MeshInstance3D]:
	var targets = mesh.find_children("*ShellFur???", "MeshInstance3D", false)
	var buffer :Array[MeshInstance3D]= []
	for entry in targets:
		if entry.is_in_group(SHELL_FUR_GROUP_ID):
			buffer.append(entry as MeshInstance3D)
	return buffer

"""
	Updates the shell data for all shells attached to a given MeshInstance3D
"""
static func update_shells_for(mesh : MeshInstance3D, fur : ShellFur) -> void:
	if Engine.is_editor_hint():
		EditorInterface.mark_scene_as_unsaved()

	var old_shell_buffer := get_instanced_shells_for(mesh)
	var layer_count := int(fur.shells_layer_count)
	var layer_height_delta := fur.shells_strand_length / fur.shells_layer_count
	var current_shell : MeshInstance3D
	var mat := FUR_MATERIAL
	if fur.style_material_override:
		mat = fur.style_material_override
	for i in range(max(len(old_shell_buffer), layer_count)):
		if i > layer_count:
			current_shell = old_shell_buffer[i]
			print("Purging shell: %s [%s]" % [str(current_shell), current_shell.name])
			current_shell.queue_free()
			continue

		if i >= len(old_shell_buffer):
			# generate a new mesh instance shell
			current_shell = MeshInstance3D.new()
			current_shell.name = "ShellFur" + str(i).pad_zeros(3)
			mesh.add_child(current_shell)
			current_shell.add_to_group(SHELL_FUR_GROUP_ID, true)
			current_shell.owner = mesh.owner
			print("Creating shell: %s [%s]" % [str(current_shell), current_shell.name])
			# technically supports only up to 999 layers, but holy hell whose PC can handle that many!!!!
		else:
			current_shell = old_shell_buffer[i]
			print("Updating existing shell: %s [%s]" % [str(current_shell), current_shell.name])

		current_shell.mesh = generate_shell_layer(mesh.mesh, i, fur)
		current_shell.material_override = mat
		current_shell.cast_shadow = fur.style_shadow
		current_shell.set_instance_shader_parameter("shell_depth", float(i) / fur.shells_layer_count)
		current_shell.set_instance_shader_parameter("base_col", fur.style_base_colour)
		current_shell.set_instance_shader_parameter("tip_col", fur.style_tip_colour)
		current_shell.position = Vector3.ZERO # reset position in case of physics sim

static func update_all_shells_on(fur : ShellFur) -> void:
	var targets := get_target_meshes(fur)
	for t in targets:
		update_shells_for(t, fur)