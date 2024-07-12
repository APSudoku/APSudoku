class_name Cell extends ColorRect

signal clear_select
signal grid_redraw
signal recheck_focus

var is_given := false
var is_selected := false
var solution := 0
var value := 0
var corner_marks: Array[bool] = [false,false,false,false,false,false,false,false,false]
var center_marks: Array[bool] = [false,false,false,false,false,false,false,false,false]
const MARGIN = 4
var neighbors: Array[Cell] = []

var top: Cell
var bottom: Cell
var left: Cell
var right: Cell

var topleft: Cell :
	get:
		return top.left if top else (left.top if left else null)
var topright: Cell :
	get:
		return top.right if top else (right.top if right else null)
var bottomleft: Cell :
	get:
		return bottom.left if bottom else (left.bottom if left else null)
var bottomright: Cell :
	get:
		return bottom.right if bottom else (right.bottom if right else null)

func _draw():
	if value or true:
		var s := str(value)
		var font := get_theme_default_font()
		var font_size := 17
		while font.get_height(font_size) + MARGIN*2 <= size.y:
			font_size += 1
		font_size -= 1
		
		s = name
		font_size = 8
		var color: Color = %Sudoku.sudoku_theme.CELL_GIVEN_TEXT if is_given else %Sudoku.sudoku_theme.CELL_MARK_TEXT
		var center_pos := size / 2
		center_pos.y += font.get_ascent(font_size) / 2
		draw_string(font, center_pos, s, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
	else:
		#TODO draw markings
		pass
	if is_selected: # Border
		const BORDER_WID := 10
		var COLOR: Color = %Sudoku.sudoku_theme.CELL_SELECT
		var _tl := false
		var _tr := false
		var _bl := false
		var _br := false
		if not (left and left.is_selected):
			draw_rect(Rect2(0,0,BORDER_WID,size.y), COLOR)
			_tl = true
			_bl = true
		if not (right and right.is_selected):
			draw_rect(Rect2(size.x-BORDER_WID,0,BORDER_WID,size.y), COLOR)
			_tr = true
			_br = true
		if not (top and top.is_selected):
			draw_rect(Rect2(0,0,size.x,BORDER_WID), COLOR)
			_tl = true
			_tr = true
		if not (bottom and bottom.is_selected):
			draw_rect(Rect2(0,size.y-BORDER_WID,size.x,BORDER_WID), COLOR)
			_bl = true
			_br = true
		if not _tl and not (topleft and topleft.is_selected):
			draw_rect(Rect2(0,0,BORDER_WID,BORDER_WID), COLOR)
		if not _tr and not (topright and topright.is_selected):
			draw_rect(Rect2(size.x-BORDER_WID,0,BORDER_WID,BORDER_WID), COLOR)
		if not _bl and not (bottomleft and bottomleft.is_selected):
			draw_rect(Rect2(0,size.y-BORDER_WID,BORDER_WID,BORDER_WID), COLOR)
		if not _br and not (bottomright and bottomright.is_selected):
			draw_rect(Rect2(size.x-BORDER_WID,size.y-BORDER_WID,BORDER_WID,BORDER_WID), COLOR)
	if has_focus():
		draw_rect(Rect2(Vector2.ZERO,size), Color.RED)
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

func _gui_input(event):
	if event is InputEventMouseMotion:
		if event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE):
			_reselect(self, true)
	elif event is InputEventMouseButton:
		if event.pressed:
			_reselect(self, event.shift_pressed or event.ctrl_pressed)
	elif event is InputEventKey:
		if event.pressed:
			var multi = event.shift_pressed or event.ctrl_pressed
			match event.keycode:
				KEY_UP:
					_reselect(top, multi)
				KEY_DOWN:
					_reselect(bottom, multi)
				KEY_LEFT:
					_reselect(left, multi)
				KEY_RIGHT:
					_reselect(right, multi)

func _reselect(c: Cell, multi: bool) -> void:
	if not c: return
	if not multi:
		clear_select.emit()
	c.is_selected = true
	release_focus()
	c.grab_focus()
	await get_tree().process_frame
	grid_redraw.emit()

func _notification(what):
	match what:
		NOTIFICATION_FOCUS_EXIT:
			await get_tree().process_frame
			recheck_focus.emit()
