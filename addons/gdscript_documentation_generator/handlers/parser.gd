extends Reference

## Parses a GDScript file into a Dictionary
##
## Recognized tags:
## * author
## * version
## * since
## * example
## * see
## * param
## * return
##
## @example:
##	```
##	{
##	    "author": string,
##	    "version": string,
##	    "since": string,
##	    "/abs/path/to/file.gd": {
##	        "my_method": {
##	            "description": string,
##	            "params": {
##	                "my_param": {
##	                    "type": string,
##	                    "description": string
##	                }
##	            },
##	            "return": {
##	                "type": string,
##	                "description": string
##	            }
##	        }
##	    }
##	}
##	```
##
## @author: Tim Yuen

const Result := preload("res://addons/gdscript_documentation_generator/model/result.gd")
const Error := preload("res://addons/gdscript_documentation_generator/model/error.gd")

const DOC_STRING := "##"
const EXPECTED_EXTENSION := "gd"
const Tags := {
	"AUTHOR": "author",
	"VERSION": "version",
	"SINCE": "since",
	"DESC": "desc",
	"DESCRIPTION": "description",
	"PARAM": "param",
	"PARAMETER": "parameter",
	"RETURN": "return",
	"SEE": "see",
	"EXAMPLE": "example"
}

enum PropTypes {
	NONE = 0,

	VAR,
	CONST,
	ENUM
}

var result := {}

## All documentation for the file
class Documentation:
	## Class level doc data
	var file := DocData.new()

	## Array of `InnerClassDocs`
	var classes := []

	## Array of var `DocData`
	var vars := []
	## Array of const `DocData`
	var consts := []
	## Array of enum `DocData`
	var enums := []

	## Array of func `DocData`
	var funcs := []
	## Array of static func `DocData`
	var static_funcs := []

	## Needed for validating properties, otherwise vars declared inside funcs will be processed by accident
	var tab_count := 0

	func _to_string() -> String:
		var r := "%s\n" % file.to_string()

		for i in ["classes", "vars", "consts", "enums", "funcs", "static_funcs"]:
			print(i)
			for j in get(i):
				r += "%s\n" % j.to_string()

		return r

## Documentation for an inner class
class InnerClassDoc extends Documentation:
	pass

## Documentation data for a member
class DocData:
	const Result := preload("res://addons/gdscript_documentation_generator/model/result.gd")
	const Error := preload("res://addons/gdscript_documentation_generator/model/error.gd")

	const IGNORED_PROPS := ["Reference", "script", "Script Variables"]

	## Store unhandled tags here
	var other := {}

	## The name of the thing the `DocData` describes
	## Generally set after parsing the docstring
	var name := ""
	
	## A short description. Should fit on one line
	var short_desc := ""
	## A long description that can span many lines
	var long_desc := ""

	## The author(s)
	var author := []
	## The version
	var version := ""
	## Point in time when the item was added
	var since := ""

	## An array of Strings. Each String is considered a separate `See` tag
	var see := []
	## An array of Strings. Each String is considered a separate `Example` tag
	var example := []

	## Dict of Param dicts
	## Expects the following keys per dict
	## * type (optional)
	## * desc (optional)
	var params := {}

	## The Return value
	## Expects the following keys
	## * type
	## * desc (optional)
	var return_value := {}

	## The type of the member
	## Only applicable for properties
	var type := ""

	func _to_string() -> String:
		return JSON.print(to_dict(), "\t")

	func add_param(param_name: String, data: Dictionary = {}) -> void:
		if not params.has(param_name):
			params[param_name] = {}
		
		for key in data.keys():
			if params[param_name].has(key):
				params[param_name][key] += " %s" % data[key]
			else:
				params[param_name][key] = data[key]

	func add_ret(ret_type: String = "", ret_desc: String = "") -> void:
		if not ret_type.empty():
			return_value["type"] = ret_type
		
		if return_value.has("desc"):
			return_value["desc"] += " %s" % ret_desc
		else:
			return_value["desc"] = ret_desc

	## Iterates over all valid members of the current data structure and constructs a dictionary from each member
	func to_dict() -> Dictionary:
		var r := {}

		for prop in get_property_list():
			if prop.name in IGNORED_PROPS:
				continue

			r[prop.name] = get(prop.name)

		return r

const _BUILDER := []

var _whitespace_regex := RegEx.new()

## The working docstring before it's applied to either the file or a member
var _working_doc: DocData

#-----------------------------------------------------------------------------#
# Builtin functions                                                           #
#-----------------------------------------------------------------------------#

func _init() -> void:
	_whitespace_regex.compile("\\B(\\s+)\\b")

#-----------------------------------------------------------------------------#
# Connections                                                                 #
#-----------------------------------------------------------------------------#

#-----------------------------------------------------------------------------#
# Private functions                                                           #
#-----------------------------------------------------------------------------#

## Wrapper for safely handling handler errors
##
## @param: res: Result - The `Result` to return
## @param: param: Variant - The error message
##
## @return: Result - The forwarded `Result`
static func _handler_error(res: Result, param = null) -> Reference:
	return res if res else Result.err(Error.Code.GENERIC_DOCSTRING_ERROR, str(param) if param else "")

#region String builder

## Adds a line to the string builder
##
## @param: text: String - The line to be added
static func _add_line(text: String) -> void:
	_BUILDER.append(text)

## Builds the String stored in the String builder and then clears the builder
## Each element in the builder is assumed to be a separate line
##
## @return: String - The String from the String builder, joined with newlines
static func _build_string() -> String:
	var r := PoolStringArray(_BUILDER).join("\n")
	_BUILDER.clear()

	return r

#endregion

#region Utils

## Checks if the indentation of the given line matches the expected amount
##
## @param: line: String - The line to check
## @param: indents: int - The expected amount of tabs
##
## @return: bool - Whether the indent amount is the same or not
func _same_indent_amount(line: String, indents: int) -> bool:
	var regex_match := _whitespace_regex.search(line)
	if regex_match == null:
		return true if indents == 0 else false

	var prefix: String = regex_match.get_string()

	return true if prefix.count("\t") == indents else false

## Wrapper for checking for `var`, `const`, and `enum`
##
## @param: text: String - The text to check. Assumes the text is pre-stripped
##
## @return: bool
static func _line_is_property(text: String) -> bool:
	return text.begins_with("var") or text.begins_with("const") or text.begins_with("enum")

## Checks if the current line is a valid code snippet
## Docstrings are not valid code snippets
##
## @param: text: String - The line to check. Should be pre-stripped
static func _is_valid_code(text: String) -> bool:
	# Completely empty lines are valid code
	if text.length() < 1:
		return true
	if _line_is_property(text):
		return true
	if not text.begins_with(DOC_STRING):
		return true

	return false

#endregion

## @param: path: String - The path to a directory
##
## @return: int - The Error code
func _scan_dir(path: String) -> Reference:
	var err: Result = Result.ok()
	
	var dir := Directory.new()
	
	if dir.open(path) != OK:
		return Result.err(Error.Code.DIR_DOES_NOT_EXIST)
	
	dir.list_dir_begin(true, true)
	
	var file_name: String = dir.get_next()
	while not file_name.empty():
		# Must format the file_name after the while check, otherwise the file_name will never be empty
		file_name = "%s/%s" % [path, file_name]
		if dir.current_is_dir():
			var inner_err := _scan_dir(file_name)
			if inner_err.is_err():
				if err.is_ok():
					err = inner_err
			file_name = dir.get_next()
			continue
		
		var inner_err := _scan_file(file_name)
		if inner_err.is_err():
			if inner_err.unwrap_err().error_code() != Error.Code.UNHANDLED_FILE_EXTENSION:
				# Only override the return Result if there was no error previously
				if err.is_ok():
					err = inner_err
		else:
			var doc: Documentation = inner_err.unwrap()
			if doc.file.name.empty():
				doc.file.name = file_name.get_basename().get_file()
			result[file_name] = doc
			_working_doc = null
		
		file_name = dir.get_next()
	
	return Result.ok() if err.is_ok() else err

## Scans a file for docstrings
## 
## @param: path: String - The path to open a file at
## 
## @return: int - The error code
func _scan_file(path: String) -> Reference:
	var file := File.new()
	
	if path.get_extension().to_lower() != EXPECTED_EXTENSION:
		return Result.err(Error.Code.UNHANDLED_FILE_EXTENSION, path)
	
	if file.open(path, File.READ) != OK:
		return Result.err(Error.Code.FILE_DOES_NOT_EXIST, path)
	
	var code: PoolStringArray = file.get_as_text().split("\n", true)
	
	return _handle_code(file.get_as_text())

## Meta-handler for code. Uses other `_handle` functions to actually process code
##
## @param: text: String - The unaccosted code
## @param: stack: Array - The stack of inner classes. Needed since inner classes can be nested
##
## @return: Result<Documentation> - The `Result` of the operation
func _handle_code(text: String, stack: Array = []) -> Reference:
	var doc: Documentation
	if stack.size() > 0:
		doc = stack.back()
	else:
		doc = Documentation.new()

	var res: Result

	var code: PoolStringArray = text.split("\n", true)

	var count: int = 0
	while count < code.size():
		var line: String = code[count]

		var stripped := line.strip_edges()
		
		# Write the working doc to the appropriate doctype when we encounter a completely empty line
		if stripped.length() < 1:
			if _working_doc != null:
				res = _consolidate_docs(doc.file, _working_doc)
				if not res or res.is_err():
					return _handler_error(res, count)

				# Nothing to set since consolidation happens directly on the Documentation object
				
				_working_doc = null
			count += 1
			continue

		if line.count("\t") != doc.tab_count:
			count += 1
			continue
		
		var bundled_text := []

		# Process in inner loop until block is complete
		if stripped.begins_with(DOC_STRING):
			while stripped.begins_with(DOC_STRING):
				# Strip ## and a space if it exists
				bundled_text.append(stripped.trim_prefix(DOC_STRING).trim_prefix(" "))
				
				count += 1
				if count >= code.size():
					break
				stripped = code[count].strip_edges()
			
			res = _handle_docstring(bundled_text)
			if not res or res.is_err():
				return _handler_error(res, count)

			_working_doc = res.unwrap()
		elif _line_is_property(stripped):
			var prop_type: int = PropTypes.NONE
			if stripped.begins_with("var"):
				prop_type = PropTypes.VAR
			elif stripped.begins_with("const"):
				prop_type = PropTypes.CONST
			elif stripped.begins_with("enum"):
				prop_type = PropTypes.ENUM

			if prop_type == PropTypes.NONE:
				return Result.err(Error.Code.UNRECOGNIZED_PROP_TYPE, stripped)

			bundled_text.append(stripped)
			count += 1
			
			# TODO for now, just take the current line
			# This will 100% break if the var name is on a different line for whatever reason
			# var \
			#	my_name <- this is valid
			# TODO it's very difficult to parse the entire var/const/enum
			# as these can be multi-line arrays, dicts, or strings
			# while stripped.length() > 1:
			# 	count += 1
			# 	if count >= code.size():
			# 		break
			# 	stripped = code[count].strip_edges()
				
			# 	if not _line_is_property(stripped):
			# 		bundled_text.append(stripped)
			# 	else:
			# 		count -= 1
			# 		break

			res = _handle_prop(prop_type, bundled_text)
			if not res or res.is_err():
				return _handler_error(res, count)
			
			res = _consolidate_docs(res.unwrap(), _working_doc)
			if not res or res.is_err():
				return _handler_error(res, count)

			match prop_type:
				PropTypes.VAR:
					doc.vars.append(res.unwrap())
				PropTypes.CONST:
					doc.consts.append(res.unwrap())
				PropTypes.ENUM:
					doc.enums.append(res.unwrap())
			
			_working_doc = null
		elif stripped.begins_with("func"):
			bundled_text.append(stripped)
			if stripped.ends_with(":"):
				count += 1
			while not stripped.ends_with(":"):
				count += 1
				if count >= code.size():
					break
				stripped = code[count].strip_edges()
				bundled_text.append(stripped)
			
			res = _handle_func(bundled_text)
			if not res or res.is_err():
				return _handler_error(res, count)
			
			res = _consolidate_docs(res.unwrap(), _working_doc)
			if not res or res.is_err():
				return _handler_error(res, count)

			doc.funcs.append(res.unwrap())

			_working_doc = null
		elif stripped.begins_with("static"):
			bundled_text.append(stripped)
			if stripped.ends_with(":"):
				count += 1
			while not stripped.ends_with(":"):
				count += 1
				if count >= code.size():
					break
				stripped = code[count].strip_edges()
				bundled_text.append(stripped)

			res = _handle_static_func(bundled_text)
			if not res or res.is_err():
				return _handler_error(res, count)
			
			res = _consolidate_docs(res.unwrap(), _working_doc)
			if not res or res.is_err():
				return _handler_error(res, count)

			doc.static_funcs.append(res.unwrap())

			_working_doc = null
		elif stripped.begins_with("class"):
			# Classes can be nested, so consider the class "completely-parsed"
			# once we encounter a valid piece of code at a lower indent level
			var tab_count := line.count("\t") + 1

			# Find the class name
			var class_split: PoolStringArray = line.split(" ")
			if class_split.size() < 2:
				return Result.err(Error.Code.PARSE_ERR, "Malformed Class declaration")

			# Cannot be called class_name since that is a reserved keyword
			var name_of_class: String = class_split[1].replace(":", "").strip_edges()
			
			count += 1
			if count >= code.size():
				return Result.err(Error.Code.PARSE_ERR, "Malformed Class at end of file")
			
			line = code[count]
			
			# Use the unstripped lines to simplify processing, as we can resuse
			# this same logic to process the inner class
			while line.strip_edges().length() < 1 or line.count("\t") >= tab_count:
				_add_line(line)

				count += 1
				if count >= code.size():
					break
				line = code[count]

			var inner_class_doc := InnerClassDoc.new()
			inner_class_doc.file.name = name_of_class
			inner_class_doc.tab_count = tab_count

			if _working_doc != null:
				res = _consolidate_docs(inner_class_doc.file, _working_doc)
				if not res or res.is_err():
					return _handler_error(res, count)

				_working_doc = null

			stack.append(inner_class_doc)
			
			res = _handle_code(_build_string(), stack)
			if not res or res.is_err():
				return _handler_error(res, count)

			stack.pop_back()

			doc.classes.append(inner_class_doc)

			_working_doc = null
		elif stripped.begins_with("class_name"):
			var split: PoolStringArray = stripped.split(" ")
			if split.size() < 2:
				return Result.err(Error.Code.PARSE_ERR, "Malformed class_name")

			doc.file.name = split[1].strip_edges()

			count += 1
		else:
			count += 1

	return Result.ok(doc)

## Handles docstrings. Expects the entire block for a docstring
##
## @param: list: Array - The split, stripped docstring
##
## @return: Result - The `Result` of the operation
func _handle_docstring(list: Array) -> Reference:
	var doc := DocData.new()

	# Everything is a description until we hit a tag
	var current_tag := ""
	var current_param := ""

	for line in list:
		var stripped: String = line.strip_edges()

		if stripped.begins_with("@"):
			# Switch to new tag, clear the current builder
			if not current_tag.empty():
				match current_tag:
					Tags.PARAM, Tags.PARAMETER, Tags.RETURN:
						# Do nothing, these are handled differently
						pass
					Tags.DESC, Tags.DESCRIPTION:
						doc.long_desc = _build_string()
					Tags.AUTHOR:
						doc.author.append(_build_string())
					Tags.VERSION:
						doc.version = _build_string()
					Tags.SINCE:
						doc.version = _build_string()
					Tags.SEE:
						doc.see.append(_build_string())
					Tags.EXAMPLE:
						doc.example.append(_build_string())
					_:
						doc.other[current_tag] = _build_string()
			else:
				doc.short_desc = _build_string()

			var split: PoolStringArray = stripped.split(":", false, 1)
			# e.g. "@param: thing: String - Hello"
			# splits into -> ["@param", "thing: String - Hello"]
			# If the size is not exactly 2, skip the tag
			if split.size() != 2:
				continue
			
			current_tag = split[0].trim_prefix("@")

			match current_tag:
				Tags.PARAM, Tags.PARAMETER:
					# e.g. given "thing: String - Hello"
					# splits into -> ["thing: String, "Hello]
					split = split[1].split("-", false, 1)
					for i in split.size():
						split[i] = split[i].strip_edges()

					var variable: PoolStringArray = split[0].split(":", false, 1)
					for i in variable.size():
						variable[i] = variable[i].strip_edges()

					var data := {}
					current_param = variable[0]
					if variable.size() > 1:
						data["type"] = variable[1]
					if split.size() > 1:
						data["desc"] = split[1]
					
					doc.add_param(current_param, data)
				Tags.RETURN:
					# e.g. given "String - Hello"
					# splits into -> ["String", "hello"]
					split = split[1].split("-", false, 1)
					for i in split.size():
						split[i] = split[i].strip_edges()

					doc.add_ret(split[0], split[1] if split.size() > 1 else "")
				_:
					_add_line(split[1])
		elif not current_tag.empty():
			# Continue processing tag description
			match current_tag:
				Tags.PARAM, Tags.PARAMETER:
					doc.add_param(current_param, {"desc": line})
				Tags.RETURN:
					doc.add_ret("", line)
				_:
					_add_line(line)
		else:
			# It's a general description
			_add_line(line)
	
	if not current_tag.empty():
		match current_tag:
			Tags.PARAM, Tags.PARAMETER, Tags.RETURN:
				# Do nothing, these are handled differently
				pass
			Tags.DESC, Tags.DESCRIPTION:
				doc.long_desc = _build_string()
			Tags.AUTHOR:
				doc.author.append(_build_string())
			Tags.VERSION:
				doc.version = _build_string()
			Tags.SINCE:
				doc.version = _build_string()
			Tags.SEE:
				doc.see.append(_build_string())
			Tags.EXAMPLE:
				doc.example.append(_build_string())
			_:
				doc.other[current_tag] = _build_string()
	else:
		doc.short_desc = _build_string()

	return Result.ok(doc)

## Handles properties. Expects the entire block for a property
## Properties include:
## * `var`
## * `const`
## * `enum`
##
## TODO This is only passed the first line for now, since parsing dicts is hard
##
## @param: type: PropType - The type of the property
## * var
## * const
## * enum
## @param: list: Array - The split, stripped property
##
## @return: Result<DocData> - The `Result` of the operation
func _handle_prop(type: int, list: Array) -> Reference:
	var doc := DocData.new()

	# TODO This assumes the entire declaration is on the first line
	var split: PoolStringArray = list[0].split(" ", false, 1)

	if split.size() < 2:
		return Result.err(Error.Code.PARSE_ERR, "Unable to split property declaration")

	var prop_declaration: String = split[1]
	split = prop_declaration.split("=", false, 1)

	var prop_name_and_type := ""

	# Strip out initial value
	match split.size():
		1: # No initial value
			prop_name_and_type = split[0]
		2:
			prop_name_and_type = split[0]

	split = prop_name_and_type.split(":", false, 1)

	var prop_name := ""
	var prop_type := ""

	# Find type if it exists
	match split.size():
		1: # No type
			prop_name = split[0].strip_edges()
		2:
			prop_name = split[0].strip_edges()
			prop_type = split[1].strip_edges()

	if type == PropTypes.ENUM:
		prop_name.replace(" ", "")
		
		var open_bracket: int = prop_name.find("{")
		if open_bracket > 0:
			prop_name = prop_name.substr(0, open_bracket).strip_edges()

	doc.name = prop_name
	doc.type = prop_type

	return Result.ok(doc)

## Handles functions. Expects the function header
##
## @param: list: Array - The split, stripped function header
##
## @return: Result<DocData> - The `Result` of the operation
func _handle_func(list: Array) -> Reference:
	var doc := DocData.new()

	var func_header: String = PoolStringArray(list).join("").strip_edges()
	func_header = func_header.trim_prefix("func").strip_edges()

	var params_start: int = func_header.find("(")
	var params_end: int = func_header.rfind(")")
	if params_start < 0 or params_end < 0:
		return Result.err(Error.Code.FUNC_ERROR, "Missing param declaration")

	doc.name = func_header.substr(0, params_start)

	# Don't include the beginning/ending parens
	var params: String = func_header.substr(params_start + 1, params_end - params_start - 1)
	var split_params: PoolStringArray = params.split(",")
	for i in split_params:
		var split_param: PoolStringArray = i.split(":")
		match split_param.size():
			1:
				doc.params[split_param[0].strip_edges()] = {}
			2:
				doc.params[split_param[0].strip_edges()] = {"type": split_param[1].strip_edges()}

	var ret_type_idx: int = func_header.find("->")
	if ret_type_idx > 0:
		doc.return_value["type"] = func_header.substr(ret_type_idx + 2, func_header.length() - ret_type_idx - 3)
	
	return Result.ok(doc)

## Handles static functions. Expects the function header. Just strips off `static` and forwards
## the data onto `_handle_func(...)
##
## @param: list: Array - The split, stripped function header
##
## @return: Result<DocData> - The `Result` of the operation
func _handle_static_func(list: Array) -> Reference:
	var doc := DocData.new()

	list[0] = list[0].replace("static", "").strip_edges(true, false)
	
	return _handle_func(list)

## Add all data from the docstring to the member data
##
## @param: member: DocData - The `DocData` for the given member
## @param: docstring: DocData - The `DocData` for the docstring above a member
##
## @return: Result<DocData> - The consolidated `DocData`
func _consolidate_docs(member: DocData, docstring: DocData) -> Reference:
	# This gets cleaned up after consolidation
	# TODO this is kind of gross
	if docstring == null:
		docstring = DocData.new()
	
	for prop in member.get_property_list():
		if prop.name in member.IGNORED_PROPS:
			continue

		var member_val = member.get(prop.name)
		var docstring_val = docstring.get(prop.name)
		
		match typeof(member_val):
			TYPE_ARRAY:
				# Members can never have implicit array properties
				member.set(prop.name, docstring_val)
			TYPE_DICTIONARY:
				if not docstring_val.empty():
					var res = _consolidate_dicts(member_val, docstring_val)
					if not res or res.is_err():
						return res if res else Result.err(Error.Code.UNHANDLED_DOC_PROPERTY, prop.name)

					member.set(prop.name, res.unwrap())
			TYPE_STRING:
				member.set(prop.name, docstring_val if member_val.empty() else member_val)
			_:
				return Result.err(Error.Code.UNHANDLED_DOC_PROPERTY, prop.name)
	
	return Result.ok(member)

## Consolidates two Dictionaries
##
## @param: member: Dictionary - The member Dictionary
## @param: docstring: Dictionary - The docstring's Dictionary
##
## @return: Result<Dictionary> - The consolidated Dictionary
func _consolidate_dicts(member: Dictionary, docstring: Dictionary) -> Reference:
	for d_key in docstring.keys():
		var d_val = docstring[d_key]

		match typeof(d_val):
			TYPE_ARRAY:
				var m_val = member.get(d_key, [])

				m_val.append_array(d_val)

				member[d_key] = m_val
			TYPE_DICTIONARY:
				var m_val = member.get(d_key, {})

				var res = _consolidate_dicts(m_val, d_val)
				if not res or res.is_err():
					return res if res else Result.err(Error.Code.UNHANDLED_DOC_PROPERTY, d_key)

				member[d_key] = m_val
			TYPE_STRING:
				var m_val = member.get(d_key, "")

				member[d_key] = d_val if m_val.empty() else d_val
			_:
				return Result.err(Error.Code.UNHANDLED_DOC_PROPERTY, d_key)

	return Result.ok(member)

#-----------------------------------------------------------------------------#
# Public functions                                                            #
#-----------------------------------------------------------------------------#

## Scan a path and parse it
##
## @param: path: String - Path to directory or file
##
## @return: int - The error code
func scan(path: String) -> Reference:
	return _scan_dir(path) if Directory.new().dir_exists(path) else _scan_file(path)
