extends Reference

const FILE_NAME_MARKDOWN := "# %s"
const SECTION_MARKDOWN := "## %s"
const METHOD_MARKDOWN := "### `%s`"
const MEMBER_MARKDOWN := "### %s"
const LIST_MARKDOWN := "* %s"

const PARAM_TABLE_MARKDOWN := "| %s | %s | %s |"
const RETURN_TABLE_MARKDOWN := "| %s | %s |"

var result := ""

## The String builder
const _BUILDER := []

## Generates documentation based on an input Dictionary
##
## @param: data: Dictionary - The input data
##
## @return: int - The error code
# func generate(data: Dictionary) -> int:
# 	for file_name in data.keys():
# 		_add_line(FILE_NAME_MARKDOWN % file_name)
		
# 		var file_data: Dictionary = data[file_name]
		
# 		#region Description
		
# 		var description: String = file_data.get("description", "")
# 		if not description.empty():
# 			var split := description.split("\n")
			
# 			var split_word := ""
# 			var counter: int = 0
# 			while counter < split.size() - 1:
# 				if not split[counter].empty():
# 					split_word = split[counter]
# 					break
				
# 				counter += 1
			
# 			var tab_count: int = split_word.strip_edges(false, true).count("\t")
# 			var strip_prefix_chars := ""
# 			for i in tab_count:
# 				strip_prefix_chars += "\t"
			
# 			for i in split:
# 				_BUILDER.append(i.trim_prefix(strip_prefix_chars))
		
# 		#endregion
		
# 		for key in file_data.keys():
# 			if key in ["description", "methods"]:
# 				continue
			
# 			_add_line(MEMBER_MARKDOWN % key.capitalize())
# 			_add_line(file_data[key])
		
# 		_add_line(SECTION_MARKDOWN % "Methods")
		
# 		var methods: Dictionary = file_data["methods"]
# 		for method_name in methods.keys():
# 			_add_line(METHOD_MARKDOWN % method_name)
			
# 			var m_data: Dictionary = methods[method_name]
			
# 			var m_desc: String = m_data.get("description", "")
# 			if not m_desc.empty():
# 				var split := m_desc.split("\n")
			
# 				var split_word := ""
# 				var counter: int = 0
# 				while counter < split.size() - 1:
# 					if not split[counter].strip_edges().empty():
# 						split_word = split[counter]
# 						break
					
# 					counter += 1
				
# 				var tab_count: int = split_word.strip_edges(false, true).count("\t")
# 				var strip_prefix_chars := ""
# 				for i in tab_count:
# 					strip_prefix_chars += "\t"
				
# 				for i in split:
# 					_BUILDER.append(i.trim_prefix(strip_prefix_chars))
			
# 			for key in m_data.keys():
# 				if key in ["description", "params", "return"]:
# 					continue
# 				_add_line(key)
# 				_add_line(LIST_MARKDOWN % m_data[key])
			
# 			_add_line("_Parameters_")
# 			_BUILDER.append("| Name | Type | Description |")
# 			_BUILDER.append("| --- | --- | --- |")
			
# 			var m_params: Dictionary = m_data["params"]
# 			for param_name in m_params.keys():
# 				var param_data: Dictionary = m_params[param_name]
# 				_BUILDER.append(PARAM_TABLE_MARKDOWN % [param_name, param_data["type"], param_data["description"]])
			
# 			_BUILDER.append("")
			
# 			_add_line("_Return_")
# 			_BUILDER.append("|Type | Description |")
# 			_BUILDER.append("| --- | --- |")
# 			_BUILDER.append(RETURN_TABLE_MARKDOWN % [m_data["return"]["type"], m_data["return"]["description"]])
			
# 			_BUILDER.append("")
# 		result = "%s%s\n" % [result, _build_string()]
	
# 	return OK

## Generates documentation based on an input Dictionary
##
## @param: data: Dictionary<Documentation> - The input docstrings
##
## @return: int - The error code
func generate(data: Dictionary) -> int:
	for file_path in data.keys():
		var file_name: String = file_path.get_file()

		if _create_containing_dir(file_path) != OK:
			printerr("Unable to create directory for %s" % file_path)
			return ERR_BUG

		_process_doc(data[file_path])

		_create_file("%s.md" % file_path.get_basename(), _build_string())

	return OK

#region Filesystem

## Creates the containing directory for a file
##
## @param: file_path: String - The path to a file
##
## @return: int - The error code
static func _create_containing_dir(file_path: String) -> int:
	var dir := Directory.new()

	var path: String = file_path.get_basename()

	return dir.make_dir_recursive(path) if not dir.dir_exists(path) else OK

## Creates a file and stores text in that file
## Always truncates
##
## @param: file_path: String - The path to create the file at
## @param: text: String - The contents of the file
##
## @return: int - The error code
static func _create_file(file_path: String, text: String) -> int:
	var file := File.new()

	if file.open(file_path, File.WRITE) != OK:
		return ERR_BUG

	file.store_string(text)

	file.close()

	return OK

#endregion

## @param: data: Documentation
static func _process_doc(data: Reference) -> void:
	_process_doc_item(data.file)

	_add_separator()

	for i in data.classes:
		_process_doc(i)

		_add_separator()

	for prop in ["vars", "consts", "enums", "funcs", "static_funcs"]:
		for i in data.get(prop):
			_add_line("## %s" % i)

			_process_doc_item(i)

		_add_separator()

## Runs through a `DocData` item and generates markdown
##
## @param: data: DocData - The docstring to process
static func _process_doc_item(data: Reference) -> void:
	if not data.has("name"):
		return
	
	_add_line("### %s" % data.name)
	
	if not data.short_desc.empty():
		_add_line(data.short_desc)

	_add_doc_item("Description", data.long_desc)

	_add_doc_item("Authors", data.author)

	_add_doc_item("Version", data.version)

	_add_doc_item("Since", data.since)

	_add_doc_item("See", data.see)

	_add_doc_item("Example", data.example)

	_add_doc_item("Parameters", data.params)

	_add_doc_item("Return value", data.return_value)

	_add_doc_item("Type", data.type)

static func _add_doc_item(item_name: String, item) -> void:
	if item.empty():
		return
	_add_line("#### %s" % item_name)

	match typeof(item):
		TYPE_ARRAY:
			for i in item:
				_add_line(i)
		TYPE_DICTIONARY:
			for key in item.keys():
				var val = item[key]
				match typeof(val):
					TYPE_ARRAY:
						for i in val:
							_add_line(i)
					TYPE_DICTIONARY:
						for i_key in val.keys():
							var i_val = val[i_key]
							_add_line("%s - %s" % [i_key, i_val])
					TYPE_STRING:
						_add_line(val)
		TYPE_STRING:
			_add_line(item)

static func _add_separator() -> void:
	_BUILDER.append("---")

static func _add_line(text: String) -> void:
	_BUILDER.append(text)
	_BUILDER.append("\n")

static func _build_string() -> String:
	var result := PoolStringArray(_BUILDER).join("\n")
	_BUILDER.clear()
	return result
