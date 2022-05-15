extends Reference

const Error := preload("res://addons/gdscript_documentation_generator/model/error.gd")

var _value
var _error: Error

func _init(v) -> void:
	if not v is Error:
		_value = v
	else:
		_error = v

func _to_string() -> String:
	if is_err():
		return "ERR: %s" % str(_error)
	else:
		return "OK: %s" % str(_value)

func is_ok() -> bool:
	return not is_err()

func is_err() -> bool:
	return _error != null

func unwrap():
	return _value

func unwrap_err() -> Error:
	return _error

func expect(text: String):
	if is_err():
		return null
	return _value

func or_else(val):
	return _value if is_ok() else val

static func ok(v = null) -> Reference:
	return load("res://addons/gdscript_documentation_generator/model/result.gd").new(v if v != null else OK)

static func err(error_code: int, description: String = "") -> Reference:
	return load("res://addons/gdscript_documentation_generator/model/result.gd").new(Error.new(error_code, description))
