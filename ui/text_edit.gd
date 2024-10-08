@tool class_name CustomLineEdit extends LineEdit

enum FieldType {
	STRING, INT, FLOAT
}
@export var type: FieldType

var font: Font :
	get:
		return get_theme_font("font") as Font
	set(val):
		add_theme_font_override("font", val)
		update_font()
var font_size: int :
	get:
		return get_theme_font_size("font_size")
	set(val):
		add_theme_font_size_override("font_size", val)
		update_font()

func _init():
	update_font()

func update_font() -> void:
	custom_minimum_size.x = font.get_string_size("archipelago.gg").x * 1.5
	custom_minimum_size.y = font.get_height(font_size) + get_theme_constant("line_spacing") * 3
	reset_size()

func get_val() -> Variant:
	var txt: String = placeholder_text if text.is_empty() else text
	if type == FieldType.INT:
		return txt.to_int()
	elif type == FieldType.FLOAT:
		return txt.to_float()
	return txt
