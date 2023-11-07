@tool
@icon("res://addons/squiggles_fur/types/shell_fur.svg")
extends Node
class_name ShellFur

@export_group("Targeting", "target_")

## the root node for this fur, defaults to parent node
@export var target_root_override : Node

## the mesh instance surfaces to apply fur to. Or all if left empty
@export var target_surfaces : PackedInt32Array = []

## Whether or not to search recursively from the root node
@export var target_search_recursive := true

@export_group("Shells", "shells_")
## Determines the number of shells that produce the fur effect. More is more realistic, but impacts performance
@export_range(0,128,1,"or_greater", "or_less") var shells_layer_count := 16.0
## The total length of the fur/hair strands in meters. I.E. [b]0.1m = 10cm = fairly long fur[/b]
@export var shells_strand_length := 0.1

@export_group("Style", "style_")
@export var style_base_colour := Color.BLACK
@export var style_tip_colour := Color.WHITE
@export var style_shadow :MeshInstance3D.ShadowCastingSetting = MeshInstance3D.SHADOW_CASTING_SETTING_OFF
@export var style_material_override : Material

@export_group("Physics")
## The stiffness of strands over the length of them. 1.0 is fully stiff with no physics, 0.0 is no stiffness or fully physics affected
@export var fur_stiffness_curve : Curve = Curve.new()
@export var delta_force_factor := 0.5
@export var fur_bounce := 2.0

# editor sim
var simulate_in_editor := false
var furry_context : FurTools.FurryModelContext = null
var fur_thread :Thread = Thread.new()

# physics sim
var last_pos := Vector3.ZERO

func _ready() -> void:
	if not target_root_override:
		target_root_override = get_parent()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() and not simulate_in_editor:
		return
	if not furry_context:
		furry_context = FurTools.FurryModelContext.new(self)
		furry_context.load_all_shells(self)
	else:
		furry_context.update_properties(self)
	# _handle_fur_mesh_thread()
	_do_shell_physics_sim(furry_context, delta)


"""
	Currently, this isn't working very well (crashes the editor all of the time.)
	If at some point someone wants to fix this, that would be super awesome. But I can't quite figure it out
"""
# func _handle_fur_mesh_thread() -> void:
# 	if not fur_thread:
# 		fur_thread = Thread.new()
# 	if not fur_thread.is_alive():
# 		fur_thread.wait_to_finish()
# 	if not fur_thread.is_started():
# 		fur_thread.start(Callable(FurTools.update_furry_context_model).bind(furry_context))

func _do_shell_physics_sim(context : FurTools.FurryModelContext, delta : float) -> void:
	if not context:
		return
	var force := Vector3.DOWN
	if not target_root_override:
		target_root_override = get_parent()

	if target_root_override is Node3D:
		var temp := (target_root_override as Node3D).global_position
		var delta_pos := temp - last_pos
		var approx_vel := delta_pos / delta
		last_pos = temp
		force += -approx_vel * delta_force_factor
		force = force.normalized()
	for mesh in context.mesh_shells.keys():
		var shells := context.get_shells_for(mesh)
		for i in range(len(shells)):
			var shell := shells[i]
			if not shell or not is_instance_valid(shell):
				continue
			var stiff := fur_stiffness_curve.sample_baked(float(i) / float(len(shells)))
			var depth := context.shell_layer_depth * float(i)
			var affect :float = clamp(1.0 - stiff, 0.0, 1.0) * 0.99
			var react :float = clamp(affect, .1, .9) * fur_bounce
			shell.position = shell.position.lerp(force * affect * depth, delta * react)

