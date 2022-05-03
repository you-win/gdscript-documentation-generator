extends Reference

const FILE_NAME_MARKDOWN := "# %s"
const SECTION_MARKDOWN := "## %s"
const METHOD_MARKDOWN := "### `%s`"
const MEMBER_MARKDOWN := "### %s"
const LIST_MARKDOWN := "* %s"

const PARAM_TABLE_MARKDOWN := "| %s | %s | %s |"
const RETURN_TABLE_MARKDOWN := "| %s | %s |"

var result := ""

var _builder := []

func generate(data: Dictionary) -> int:
	for file_name in data.keys():
		_add_line(FILE_NAME_MARKDOWN % file_name)
		
		var file_data: Dictionary = data[file_name]
		
		#region Description
		
		var description: String = file_data.get("description", "")
		if not description.empty():
			var split := description.split("\n")
			
			var split_word := ""
			var counter: int = 0
			while counter < split.size() - 1:
				if not split[counter].empty():
					split_word = split[counter]
					break
				
				counter += 1
			
			var tab_count: int = split_word.strip_edges(false, true).count("\t")
			var strip_prefix_chars := ""
			for i in tab_count:
				strip_prefix_chars += "\t"
			
			for i in split:
				_builder.append(i.trim_prefix(strip_prefix_chars))
		
		#endregion
		
		for key in file_data.keys():
			if key in ["description", "methods"]:
				continue
			
			_add_line(MEMBER_MARKDOWN % key.capitalize())
			_add_line(file_data[key])
		
		_add_line(SECTION_MARKDOWN % "Methods")
		
		var methods: Dictionary = file_data["methods"]
		for method_name in methods.keys():
			_add_line(METHOD_MARKDOWN % method_name)
			
			var m_data: Dictionary = methods[method_name]
			
			var m_desc: String = m_data.get("description", "")
			if not m_desc.empty():
				var split := m_desc.split("\n")
			
				var split_word := ""
				var counter: int = 0
				while counter < split.size() - 1:
					if not split[counter].strip_edges().empty():
						split_word = split[counter]
						break
					
					counter += 1
				
				var tab_count: int = split_word.strip_edges(false, true).count("\t")
				var strip_prefix_chars := ""
				for i in tab_count:
					strip_prefix_chars += "\t"
				
				for i in split:
					_builder.append(i.trim_prefix(strip_prefix_chars))
			
			for key in m_data.keys():
				if key in ["description", "params", "return"]:
					continue
				_add_line(key)
				_add_line(LIST_MARKDOWN % m_data[key])
			
			_add_line("_Parameters_")
			_builder.append("| Name | Type | Description |")
			_builder.append("| --- | --- | --- |")
			
			var m_params: Dictionary = m_data["params"]
			for param_name in m_params.keys():
				var param_data: Dictionary = m_params[param_name]
				_builder.append(PARAM_TABLE_MARKDOWN % [param_name, param_data["type"], param_data["description"]])
			
			_builder.append("")
			
			_add_line("_Return_")
			_builder.append("|Type | Description |")
			_builder.append("| --- | --- |")
			_builder.append(RETURN_TABLE_MARKDOWN % [m_data["return"]["type"], m_data["return"]["description"]])
			
			_builder.append("")
		result = "%s%s\n" % [result, _build_string()]
	
	return OK

func _add_line(text: String) -> void:
	_builder.append(text)
	_builder.append("")

func _build_string() -> String:
	var result := PoolStringArray(_builder).join("\n")
	_builder.clear()
	return result
