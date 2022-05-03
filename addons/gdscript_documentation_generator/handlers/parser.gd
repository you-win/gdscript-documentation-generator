extends Reference

"""
Parses a GDScript file into a Dictionary

Recognized tags:
* author
* version
* since
* example
* see
* param
* return

@example
```
{
	"author": string,
	"version": string,
	"since": string,
	"/abs/path/to/file.gd": {
		"my_method": {
			"description": string,
			"params": {
				"my_param": {
					"type": string,
					"description": string
				}
			},
			"return": {
				"type": string,
				"description": string
			}
		}
	}
}
```

@author Tim Yuen
"""

const EXPECTED_EXTENSION := "gd"
const VALID_TAGS := [
	"author",
	"version",
	"since",
	"description",
	"param",
	"return",
	"see",
	"example"
]

var result := {}

#region File parsing vars

var _is_func := false
var _is_multiline_func := false

var _is_docstring := false
var _docstring_builder := []
var _current_tag_type := ""
var _current_tag_name := ""
var _tag_data := {}

var _func_builder := []
var _current_func := ""
var _data := {}

#endregion

func scan(path: String) -> int:
	"""
	Scan a path and parse it
	
	@param path: String - Path to directory or file
	@return int - The error code
	"""
	var dir := Directory.new()
	
	var is_dir := true
	var found := dir.dir_exists(path)
	if not found:
		is_dir = false
		found = dir.file_exists(path)
	
	if not found:
		return ERR_DOES_NOT_EXIST
	
	return _scan_dir(path) if is_dir else _scan_file(path)

func _scan_dir(path: String) -> int:
	"""
	@param path: String - The path to a directory
	@return int - The error code
	"""
	var err := OK
	
	var dir := Directory.new()
	
	if dir.open(path) != OK:
		return ERR_DOES_NOT_EXIST
	
	dir.list_dir_begin(true, true)
	
	var file_name: String = dir.get_next()
	while not file_name.empty():
		# Must format the file_name after the while check, otherwise the file_name will never be empty
		file_name = "%s/%s" % [path, file_name]
		if dir.current_is_dir():
			var inner_err := _scan_dir(file_name)
			if inner_err != OK:
				printerr("%d occurred while scanning directory %s" % [err, file_name])
				if err == OK:
					err = inner_err
			file_name = dir.get_next()
			continue
		
		var inner_err := _scan_file(file_name)
		if inner_err != OK and inner_err != ERR_FILE_UNRECOGNIZED:
			printerr("%d occurred while scanning file %s" % [err, file_name])
			if err == OK:
				err = inner_err
		
		file_name = dir.get_next()
	
	return OK

func _scan_file(path: String) -> int:
	"""
	Scans a file for docstrings
	
	@param path: String - The path to open a file at
	@return int - The error code
	"""
	var file := File.new()
	
	if path.get_extension().to_lower() != EXPECTED_EXTENSION:
		return ERR_FILE_UNRECOGNIZED
	
	if file.open(path, File.READ) != OK:
		return ERR_DOES_NOT_EXIST
	
	var code: String = file.get_as_text()
	
	var split_code: PoolStringArray = code.split("\n")
	for line in split_code:
		if line.begins_with("func"):
			_is_func = true
			_is_multiline_func = not line.ends_with(":")
		elif _is_multiline_func and line.ends_with(":"):
			_is_multiline_func = false
		elif line.strip_edges().begins_with("\"\"\"") or line.strip_edges().ends_with("\"\"\""):
			if not _is_docstring:
				_is_docstring = true
				_is_func = false
			else:
				_is_docstring = false
				_tag_data_finished()
		elif _is_func:
			_is_func = false
		
		if not _is_func and not _is_multiline_func and not _is_docstring:
			continue
		
		if _is_func:
			_func_builder.append(line)
			if _is_multiline_func:
				continue
			
			var func_def: String = PoolStringArray(_func_builder).join("")
			_func_builder.clear()
			
			#region Func name
			
			var split_func: PoolStringArray = func_def.split(" ")
			if split_func.size() < 1:
				printerr("Probably encountered syntax error for line %s" % line)
				continue
			_current_func = split_func[1].substr(0, split_func[1].find("("))
			
			_data[_current_func] = {}
			
			#endregion
			
			#region Params
			
			var params: String = func_def.substr(func_def.find("(") + 1).replace(func_def.substr(func_def.find_last(")")), "")
			
			var split_params: PoolStringArray = params.split(",", false)
			var param_data := {}
			for p in split_params:
				var param: PoolStringArray = p.strip_edges().split(":", true)
				match param.size():
					1: # No type annotation
						param_data[param[0].strip_edges()] = {
							"type": "Variant",
							"description": ""
						}
					2: # Has type annotation
						param_data[param[0].strip_edges()] = {
							"type": param[1].strip_edges(),
							"description": ""
						}
					_:
						printerr("Unhandled param %s" % p)
						continue
			
			_data[_current_func]["params"] = param_data
			
			#endregion
			
			#region Return type
			
			var split_return: PoolStringArray = func_def.split("->", false)
			_data[_current_func]["return"] = {
				"type": split_return[1].strip_edges().trim_suffix(":") if split_return.size() == 2 else "Variant",
				"description": ""
			}
			
			#endregion
			
			pass
		elif _is_docstring:
			# Docstring content might start/end on the same line as the triple quotes
			line = line.replace("\"\"\"", "") as String
			
			if line.strip_edges().begins_with("@"):
				line = line.strip_edges()
				# Store the data if we were previously processing a tag
				if not _tag_data.empty():
					_tag_data_finished()
				
				# Given "@param my_param: int - desc", split into ["param", "my_param: int - desc"]
				var split_tag: PoolStringArray = line.lstrip("@").split(" ", false, 1)
				
				_current_tag_type = split_tag[0]
				if not _current_tag_type in VALID_TAGS:
					_tag_data.clear()
					_current_tag_type = ""
					continue
				
				if split_tag.size() != 2:
					_tag_data[_current_tag_type] = ""
					continue
				
				if _current_tag_type in ["param", "return"]:
					# Given "my_param: int - desc", split into ["my_param: int ", " desc"]
					split_tag = split_tag[1].strip_edges().split("-", false, 1)
					
					if split_tag.size() == 2:
						_tag_data["description"] = split_tag[1].strip_edges()
					
					match _current_tag_type:
						"param":
							# Given "my_param: int ", split into ["my_param", " int"]
							split_tag = split_tag[0].strip_edges().split(":", false, 1)
							if split_tag.size() == 2:
								_tag_data["type"] = split_tag[1].strip_edges()
							
							_current_tag_name = split_tag[0].strip_edges()
						"return":
							_tag_data["type"] = split_tag[0].strip_edges()
				else:
					_tag_data[_current_tag_type] = split_tag[1].strip_edges()
			elif not _tag_data.empty(): # Multiline tag description, assume everything on subsequent lines are descriptors
				if _current_tag_type in ["param", "return"]:
					_tag_data["description"] = "%s\n%s" % [_tag_data["description"], line]
				else:
					_tag_data[_current_tag_type] = "%s%s\n" % [_tag_data[_current_tag_type], line]
			elif not _current_func.empty(): # Multiline func description
				_data[_current_func]["description"] = "%s%s\n" % [_data[_current_func].get("description", ""), line]
			else: # Default to assuming it's a class description
				_data["description"] = "%s%s\n" % [_data.get("description", ""), line]
	
	_func_finished(path)
	
	return OK

func _tag_data_finished() -> void:
	"""
	Applies parsed tag data to the intermediate `_data` object
	"""
	var existing_data: Dictionary
	match _current_tag_type:
		"param":
			existing_data = _data.get(_current_func, {}).get("params", {}).get(_current_tag_name, {})
			
			# Params are initially discovered while parsing the function definition
			# So error out to prevent doc-to-code mismatch
			if existing_data.empty():
				printerr("Param does not exist: %s - %s" % [_current_func, JSON.print(_tag_data, "\t")])
				return
			
			# Only error if an exact type was given and it does not match the function signature
			# This is to ensure that docs stay up-to-date with the code
			#
			# It is acceptable to provide "my_arg_name: Dictionary or Array" as a docstring param
			if existing_data["type"] != _tag_data["type"] and existing_data["type"] != "Variant" and _tag_data["type"].split(" ").size() == 1:
				printerr("Param type does not match %s vs %s" % [existing_data["type"], _tag_data["type"]])
				return
			
			existing_data["type"] = _tag_data.get("type", existing_data["type"])
			existing_data["description"] = _tag_data.get("description", existing_data["description"])
		"return":
			existing_data = _data.get(_current_func, {}).get("return", {})
			
			# The return value is initially discovered while parsing the function definition
			# So error out to prevent doc-to-code mismatch
			if existing_data.empty():
				printerr("Param does not exist: %s - %s" % [_current_func, JSON.print(_tag_data, "\t")])
				return
			
			# Only error if an exact type was given and it does not match the function signature
			# This is to ensure that docs stay up-to-date with the code
			#
			# It is acceptable to provide "Dictionary or Array" as a docstring return type
			if existing_data["type"] != _tag_data.get("type", "void") and existing_data["type"] != "Variant" and _tag_data.get("type", "void").split(" ").size() == 1:
				printerr("Param type does not match %s vs %s" % [existing_data["type"], _tag_data.get("type", "")])
				return
			
			existing_data["type"] = _tag_data.get("type", existing_data["type"])
			existing_data["description"] = _tag_data.get("description", existing_data["description"])
		_: # Everything else is extra information
			existing_data = _data.get(_current_func, _data)
			for key in _tag_data.keys():
				existing_data[key] = _tag_data[key]
	
	_tag_data.clear()

func _func_finished(path: String) -> void:
	"""
	Applies the intermediate data object to the `result`
	
	Clears and resets all intermediate objects
	
	@param path: String - The path to the file
	"""
	if not result.has(path):
		result[path] = {}
	
	if not result[path].has("methods"):
		result[path]["methods"] = {}
	for key in _data.keys():
		var val = _data[key]
		
		if val is Dictionary:
			result[path]["methods"][key] = val.duplicate(true)
		else:
			result[path][key] = val
	
	_is_func = false
	_is_multiline_func = false
	
	_is_docstring = false
	_docstring_builder.clear()
	_current_tag_type = ""
	_current_tag_name = ""
	_tag_data.clear()
	
	_func_builder.clear()
	_current_func = ""
	
	_data.clear()
