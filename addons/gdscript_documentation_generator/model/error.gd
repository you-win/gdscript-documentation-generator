extends Reference

enum Code {
	NONE = 0,

	NULL_VALUE,

	#region Parser

	PARSE_ERR,

	DIR_DOES_NOT_EXIST,

	FILE_DOES_NOT_EXIST,
	UNHANDLED_FILE_EXTENSION,

	UNRECOGNIZED_PROP_TYPE,
	UNHANDLED_DOC_PROPERTY,

	FUNC_ERROR,

	GENERIC_DOCSTRING_ERROR,

	#endregion
}

var _error: int
var _description: String

func _init(error: int, description: String = "") -> void:
	_error = error
	_description = description

func _to_string() -> String:
	return "Code: %d\nName: %s\nDescription: %s" % [_error, error_name(), _description]

func error_code() -> int:
	return _error

func error_name() -> int:
	return Code.keys()[_error]

func error_description() -> String:
	return _description
