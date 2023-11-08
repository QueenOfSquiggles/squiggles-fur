@tool
extends EditorPlugin

var editor_inspector := preload("res://addons/squiggles_fur/inspector/ShellFurInspector.gd").new()

var shell_fur_script :Script = preload("res://addons/squiggles_fur/types/ShellFur.gd")

func _enter_tree():
	add_custom_type("ShellFur", "Node", shell_fur_script, null)
	
	editor_inspector.interface_ref = get_editor_interface()
	add_inspector_plugin(editor_inspector)


func _exit_tree():
	remove_custom_type("ShellFur")
	remove_inspector_plugin(editor_inspector)
