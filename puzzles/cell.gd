class_name Cell extends ColorRect

var is_given := false
var is_selected := false
var solution := 0
var value := 0
var corner_marks: Array[bool] = [false,false,false,false,false,false,false,false,false]
var center_marks: Array[bool] = [false,false,false,false,false,false,false,false,false]
const MARGIN = 4
var neighbors: Array[Cell] = []

func _draw():
	if value:
		var font := get_theme_default_font()
		var font_size := 17
		while font.get_height(font_size) + MARGIN*2 <= size.y:
			font_size += 1
		font_size -= 1
		var center_pos := size / 2
		size.y -= font.get_ascent(font_size)
		draw_string(font, center_pos, str(value), HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)

func clear() -> void:
	is_given = false
	solution = 0
	value = 0
	corner_marks.fill(false)
	center_marks.fill(false)

func mark(num: int) -> void:
	if is_given: return
	value = num
func mark_corner(num: int) -> void:
	if is_given: return
	corner_marks[num] = not corner_marks[num]
func mark_center(num: int) -> void:
	if is_given: return
	center_marks[num] = not center_marks[num]

func add_neighbors(arr: Array) -> void:
	for n in arr:
		if n == self or n in neighbors:
			continue
		neighbors.append(n)

func is_valid() -> bool:
	if not value: # Unfilled cells are 'valid'
		return true
	for c in neighbors:
		if c.value == value: # Conflicting cells are 'invalid'
			return false
	return true

func is_solved() -> bool:
	return value == solution
