tool
extends EditorPlugin

const Main := preload("res://addons/gdscript_documentation_generator/main.tscn")

const TOOLBAR_NAME := "Doc Generator"

var main

func _enter_tree():
	main = Main.instance()
	inject_tool(main)

func _exit_tree():
	if main != null:
		remove_control_from_bottom_panel(main)

func enable_plugin():
	make_bottom_panel_item_visible(main)

func inject_tool(node: Node) -> void:
	"""
	Inject `tool` at the top of the plugin script
	"""
	var script: Script = node.get_script().duplicate()
	script.source_code = "tool\n%s" % script.source_code
	script.reload(false)
	node.set_script(script)
	
	add_control_to_bottom_panel(main, TOOLBAR_NAME)
