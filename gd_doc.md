# ./addons/gdscript_documentation_generator/handlers/doc_generator.gd

## Methods

### `generate`

_Parameters_

| Name | Type | Description |
| --- | --- | --- |
| data | Dictionary |  |

_Return_

|Type | Description |
| --- | --- |
| int |  |

### `_add_line`

_Parameters_

| Name | Type | Description |
| --- | --- | --- |
| text | String |  |

_Return_

|Type | Description |
| --- | --- |
| void |  |

### `_build_string`

_Parameters_

| Name | Type | Description |
| --- | --- | --- |

_Return_

|Type | Description |
| --- | --- |
| String |  |

# ./addons/gdscript_documentation_generator/handlers/parser.gd


Parses a GDScript file into a Dictionary

Recognized tags:
* author
* version
* since
* example
* see
* param
* return


### Example

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



### Author

Tim Yuen

## Methods

### `scan`


Scan a path and parse it


_Parameters_

| Name | Type | Description |
| --- | --- | --- |
| path | String | Path to directory or file |

_Return_

|Type | Description |
| --- | --- |
| int | The error code |

### `_scan_dir`

	

_Parameters_

| Name | Type | Description |
| --- | --- | --- |
| path | String | The path to a directory |

_Return_

|Type | Description |
| --- | --- |
| int | The error code |

### `_scan_file`


Scans a file for docstrings


_Parameters_

| Name | Type | Description |
| --- | --- | --- |
| path | String | The path to open a file at |

_Return_

|Type | Description |
| --- | --- |
| int | The error code |

### `_tag_data_finished`


Applies parsed tag data to the intermediate `_data` object

_Parameters_

| Name | Type | Description |
| --- | --- | --- |

_Return_

|Type | Description |
| --- | --- |
| void |  |

### `_func_finished`


Applies the intermediate data object to the `result`

Clears and resets all intermediate objects


_Parameters_

| Name | Type | Description |
| --- | --- | --- |
| path | String | The path to the file |

_Return_

|Type | Description |
| --- | --- |
| void |  |

# ./addons/gdscript_documentation_generator/main.gd

## Methods

### `_ready`

_Parameters_

| Name | Type | Description |
| --- | --- | --- |

_Return_

|Type | Description |
| --- | --- |
| void |  |

### `_on_scan_button_pressed`

_Parameters_

| Name | Type | Description |
| --- | --- | --- |
| line_edit | LineEdit |  |
| button | Button |  |

_Return_

|Type | Description |
| --- | --- |
| void |  |

### `_on_generate`

_Parameters_

| Name | Type | Description |
| --- | --- | --- |
| scan_line_edit | LineEdit |  |
| output_line_edit | LineEdit |  |

_Return_

|Type | Description |
| --- | --- |
| void |  |

### `_on_tree_item_selected`

_Parameters_

| Name | Type | Description |
| --- | --- | --- |

_Return_

|Type | Description |
| --- | --- |
| void |  |

### `_read_global_settings`

_Parameters_

| Name | Type | Description |
| --- | --- | --- |

_Return_

|Type | Description |
| --- | --- |
| int |  |

### `_create_new_global_settings`

_Parameters_

| Name | Type | Description |
| --- | --- | --- |

_Return_

|Type | Description |
| --- | --- |
| int |  |

### `_save_global_settings`

_Parameters_

| Name | Type | Description |
| --- | --- | --- |

_Return_

|Type | Description |
| --- | --- |
| int |  |

### `_add_log`

_Parameters_

| Name | Type | Description |
| --- | --- | --- |
| text | String |  |

_Return_

|Type | Description |
| --- | --- |
| void |  |

# ./addons/gdscript_documentation_generator/plugin.gd

## Methods

### `_enter_tree`

_Parameters_

| Name | Type | Description |
| --- | --- | --- |

_Return_

|Type | Description |
| --- | --- |
| Variant |  |

### `_exit_tree`

_Parameters_

| Name | Type | Description |
| --- | --- | --- |

_Return_

|Type | Description |
| --- | --- |
| Variant |  |

### `enable_plugin`

_Parameters_

| Name | Type | Description |
| --- | --- | --- |

_Return_

|Type | Description |
| --- | --- |
| Variant |  |

### `inject_tool`


Inject `tool` at the top of the plugin script

_Parameters_

| Name | Type | Description |
| --- | --- | --- |
| node | Node |  |

_Return_

|Type | Description |
| --- | --- |
| void |  |

# ./runner.gd

## Methods

### `_ready`

_Parameters_

| Name | Type | Description |
| --- | --- | --- |

_Return_

|Type | Description |
| --- | --- |
| void |  |

