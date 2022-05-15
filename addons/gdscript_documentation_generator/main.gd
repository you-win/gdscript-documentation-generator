extends PanelContainer

const Parser := preload("res://addons/gdscript_documentation_generator/handlers/parser.gd")
const DocGenerator := preload("res://addons/gdscript_documentation_generator/handlers/doc_generator.gd")

const GLOBAL_SETTING_PATH := "user://../GDScriptDocumentationGenerator"
const CONFIG_NAME := "config.gdscript-doc-generator"
const DEFAULT_CONFIG := {
	"scan_dir": "res://",
	"output_dir": "res://"
}
const DOC_NAME := "gd_doc.md"

const TREE_COL: int = 0
const DEFAULT_DISPLAY := "Generator"

var plugin: Node

var config := {}

var tree: Tree

var logs: TextEdit
var status: LineEdit

var pages := {}
var current_page: Control

#-----------------------------------------------------------------------------#
# Builtin functions                                                           #
#-----------------------------------------------------------------------------#

func _ready() -> void:
	logs = $VBoxContainer/HSplitContainer/Pages/Logs as TextEdit
	status = $VBoxContainer/Status as LineEdit
	_read_global_settings()
	
	var h_split := $VBoxContainer/HSplitContainer as HSplitContainer
	h_split.split_offset = h_split.rect_size.x / 6
	
	var pages_list := $VBoxContainer/HSplitContainer/Pages as PanelContainer
	
	tree = $VBoxContainer/HSplitContainer/Tree as Tree
	
	var root: TreeItem = tree.create_item()
	
	for c in pages_list.get_children():
		var item: TreeItem = tree.create_item(root)
		item.set_text(TREE_COL, c.name)
		
		c.visible = false
		pages[c.name] = c
		
		if c.name == DEFAULT_DISPLAY:
			c.visible = true
			item.select(TREE_COL)
			current_page = c
	
	tree.connect("item_selected", self, "_on_tree_item_selected")
	
	#region Generator
	
	var generate := $VBoxContainer/HSplitContainer/Pages/Generator/Generate as Button
	
	var scan_all := $VBoxContainer/HSplitContainer/Pages/Generator/ScanAll as CheckButton
	scan_all.connect("toggled", self, "_on_scan_all_toggled",
			[$VBoxContainer/HSplitContainer/Pages/Generator/ScanDirectory/HBoxContainer, generate])
	scan_all.pressed = true
	
	var scan_line_edit := $VBoxContainer/HSplitContainer/Pages/Generator/ScanDirectory/HBoxContainer/LineEdit as LineEdit
	scan_line_edit.connect("text_changed", self, "_on_scan_text_changed", [scan_line_edit, generate])
	scan_line_edit.connect("tree_entered", self, "_on_scan_text_entered", [scan_line_edit, generate])
	var scan_button := $VBoxContainer/HSplitContainer/Pages/Generator/ScanDirectory/HBoxContainer/Button as Button
	scan_button.connect("pressed", self, "_on_scan_button_pressed", [scan_line_edit, generate])
	
	var output_line_edit := $VBoxContainer/HSplitContainer/Pages/Generator/OutputDirectory/HBoxContainer/LineEdit as LineEdit
	output_line_edit.connect("text_changed", self, "_on_scan_text_changed", [output_line_edit, generate])
	output_line_edit.connect("tree_entered", self, "_on_scan_text_entered", [output_line_edit, generate])
	output_line_edit.text = "."
	var output_button := $VBoxContainer/HSplitContainer/Pages/Generator/OutputDirectory/HBoxContainer/Button as Button
	output_button.connect("pressed", self, "_on_scan_button_pressed", [output_line_edit, generate])
	
	generate.connect("pressed", self, "_on_generate", [scan_line_edit, output_line_edit])
	
	#endregion
	
	_add_log("Ready")

#-----------------------------------------------------------------------------#
# Connections                                                                 #
#-----------------------------------------------------------------------------#

static func _delete(node: Node) -> void:
	node.queue_free()

#region Generator

static func _on_scan_all_toggled(state: bool, element: Control, button: Button) -> void:
	var line_edit: LineEdit
	for c in element.get_children():
		c.set("disabled", state)
		c.set("editable", not state)
		if c is LineEdit:
			line_edit = c
	_on_scan_file_dialog_dir_selected(line_edit.text if not state else ("." if line_edit.text.empty() else line_edit.text), line_edit, button)

static func _on_scan_text_changed(text: String, line_edit: LineEdit, button: Button) -> void:
	button.disabled = not Directory.new().dir_exists(ProjectSettings.globalize_path(text)) if not text.empty() else true

static func _on_scan_text_entered(text: String, line_edit: LineEdit, button: Button) -> void:
	_on_scan_text_changed(text, line_edit, button)

func _on_scan_button_pressed(line_edit: LineEdit, button: Button) -> void:
	var file_dialog := FileDialog.new()
	file_dialog.name = "ScanButtonFileDialog"
	file_dialog.mode = FileDialog.MODE_OPEN_DIR
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	
	file_dialog.connect("dir_selected", self, "_on_scan_file_dialog_dir_selected", [line_edit, button])
	
	file_dialog.connect("modal_closed", self, "_delete", [file_dialog])
	file_dialog.connect("popup_hide", self, "_delete", [file_dialog])
	
	add_child(file_dialog)
	file_dialog.popup_centered_ratio()

static func _on_scan_file_dialog_dir_selected(dir: String, line_edit: LineEdit, button: Button) -> void:
	line_edit.text = dir
	_on_scan_text_changed(dir, line_edit, button)

func _on_generate(scan_line_edit: LineEdit, output_line_edit: LineEdit) -> void:
	_add_log("Parsing %s" % scan_line_edit.text)
	
	var parser := Parser.new()
	var parser_res := parser.scan(scan_line_edit.text)
	if parser_res.is_err():
		_add_log("Error occurred while parsing\n%s" % str(parser_res))
		return
	
	print(parser.result)
	
	_add_log("Finished parsing")
	
	var doc_generator := DocGenerator.new()
	var err = doc_generator.generate(parser.result)
	if err != OK:
		_add_log("Error occurred while generating %d" % err)
		return
	
	var file := File.new()
	if file.open(ProjectSettings.globalize_path("%s/%s" % [output_line_edit.text, DOC_NAME]), File.WRITE) != OK:
		_add_log("Error occurred while writing doc")
		return
	
	file.store_string(doc_generator.result)
	
	_add_log("Successfully generated gddoc.md")

#endregion

func _on_tree_item_selected() -> void:
	var page_name: String = tree.get_selected().get_text(tree.get_selected_column())
	
	if page_name == current_page.name:
		return
	
	current_page.hide()
	current_page = pages[page_name]
	current_page.show()

#-----------------------------------------------------------------------------#
# Private functions                                                           #
#-----------------------------------------------------------------------------#

func _read_global_settings() -> int:
	var dir := Directory.new()
	if not dir.dir_exists(GLOBAL_SETTING_PATH):
		_add_log("Creating %s" % GLOBAL_SETTING_PATH)
		dir.make_dir(GLOBAL_SETTING_PATH)
	
	var file := File.new()
	if not file.file_exists("%s/%s" % [GLOBAL_SETTING_PATH, CONFIG_NAME]):
		return _create_new_global_settings()
	
	if file.open("%s/%s" % [GLOBAL_SETTING_PATH, CONFIG_NAME], File.READ) != OK:
		return _create_new_global_settings()
	
	var file_text: String = file.get_as_text()
	var parse_result: JSONParseResult = JSON.parse(file_text)
	if parse_result.error != OK:
		_add_log("Error occurred while reading config: %s" % parse_result.error_string)
		return _create_new_global_settings()
	
	var result = parse_result.result
	if not result is Dictionary:
		return _create_new_global_settings()
	
	config = result
	
	return OK

func _create_new_global_settings() -> int:
	_add_log("Creating %s" % CONFIG_NAME)
	
	config = DEFAULT_CONFIG
	
	return _save_global_settings()

func _save_global_settings() -> int:
	_add_log("Saving global settings")
	
	var dir := Directory.new()
	if not dir.dir_exists(GLOBAL_SETTING_PATH):
		_add_log("Creating %s" % GLOBAL_SETTING_PATH)
		dir.make_dir(GLOBAL_SETTING_PATH)
	
	var file := File.new()
	if file.open("%s/%s" % [GLOBAL_SETTING_PATH, CONFIG_NAME], File.WRITE) != OK:
		_add_log("Unable to open %s/%s for writing" % [GLOBAL_SETTING_PATH, CONFIG_NAME])
		return ERR_CANT_OPEN
	
	file.store_string(JSON.print(config, "\t"))
	
	_add_log("Finished saving global settings")
	
	return OK

func _add_log(text: String) -> void:
	logs.text = "%s%s\n" % [logs.text, text]
	status.text = text

#-----------------------------------------------------------------------------#
# Public functions                                                            #
#-----------------------------------------------------------------------------#
