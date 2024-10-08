@tool class_name SudokuTheme extends Resource

signal on_update

@export var CELL_BG := Color.WHITE
@export var CELL_GIVEN_TEXT := Color.BLACK
@export var CELL_ANSWER_TEXT := Color.from_string("1E6BE5", Color.DODGER_BLUE)
@export var CELL_CENTER_MARK_TEXT := Color.from_string("1E6BE5", Color.DODGER_BLUE)
@export var CELL_CORNER_MARK_TEXT := Color.from_string("1E6BE5", Color.DODGER_BLUE)
@export var CELL_INVALID_TEXT := Color.from_string("AA0000", Color.RED)
@export var CELL_SELECT := Color.from_string('4CA4FF', Color.STEEL_BLUE)
@export var CELL_FOCUS := Color.INDIAN_RED
@export var GRID_BG := Color.BLACK

@export var KILLER_BORDER := Color.from_string("FF00FF", Color.MAGENTA)
@export var KILLER_SUM := Color.from_string("AA00FF", Color.PURPLE)

@export var SHAPE_1 := Color.from_string("FF0000", Color.RED)
@export var SHAPE_2 := Color.from_string("00AA00", Color.GREEN)
@export var SHAPE_3 := Color.from_string("0000FF", Color.BLUE)
@export var SHAPE_4 := Color.from_string("FFFF00", Color.YELLOW)
@export var SHAPE_5 := Color.from_string("FF00FF", Color.MAGENTA)
@export var SHAPE_6 := Color.from_string("00FFFF", Color.CYAN)
@export var SHAPE_7 := Color.from_string("B400FF", Color.PURPLE)
@export var SHAPE_8 := Color.from_string("FFA000", Color.ORANGE)
@export var SHAPE_9 := Color.from_string("BEFF00", Color.YELLOW_GREEN)
@export var SHAPE_INVALID_BG := Color.from_string("AA0000", Color.RED)
@export var SHAPE_BG := Color.WHITE
@export var SHAPE_GIVEN_BG := Color.from_string("C0C0C0", Color.WEB_GRAY)

func get_shape_color(val: int) -> Color:
	match val:
		1: return SHAPE_1
		2: return SHAPE_2
		3: return SHAPE_3
		4: return SHAPE_4
		5: return SHAPE_5
		6: return SHAPE_6
		7: return SHAPE_7
		8: return SHAPE_8
		9: return SHAPE_9
		_: return Color.WHITE

func _get_members() -> Array[String]:
	var arr: Array[String] = []
	for prop in self.get_property_list():
		if prop.get("hint_string") == "Color":
			var name = prop.get("name")
			if name is String:
				arr.append(name)
	return arr
	
func _to_dict() -> Dictionary:
	var dict := {}
	for name in _get_members():
		dict[name] = get(name)
	return dict

func _from_dict(dict: Dictionary) -> void:
	for name in _get_members():
		var val = dict.get(name)
		if val is Color:
			set(name, val)

func update_color(key: String, color: Color) -> void:
	set(key, color)
	on_update.emit()

func update_from_copy(other: SudokuTheme) -> void:
	for name in _get_members():
		set(name, other.get(name))
	on_update.emit()
