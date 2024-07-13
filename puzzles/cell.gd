class_name Cell extends ColorRect

signal clear_select
signal grid_redraw
signal recheck_focus
signal grid_input

var is_given := false
var draw_invalid := false
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
	if value:
		var text_color: Color = %Sudoku.sudoku_theme.CELL_GIVEN_TEXT if is_given else %Sudoku.sudoku_theme.CELL_ANSWER_TEXT
		if draw_invalid:
			text_color = %Sudoku.sudoku_theme.CELL_INVALID_TEXT
		var s := str(value)
		var font := get_theme_default_font()
		var font_size := 17
		while font.get_height(font_size) + MARGIN*2 <= size.y:
			font_size += 1
		font_size -= 1
		while font_size and font.get_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x + MARGIN*2 >= size.x:
			font_size -= 1
		
		var pos := Vector2(0,MARGIN + font.get_ascent(font_size))
		draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, text_color)
	else:
		var has_center := false
		var has_corner := false
		for c in center_marks:
			if c:
				has_center = true
				break
		for c in corner_marks:
			if c:
				has_corner = true
				break
		if has_corner:
			var font := get_theme_default_font()
			var font_size := 17
			while font.get_height(font_size) + MARGIN*2 <= size.y / 3:
				font_size += 1
			font_size -= 1
			while font_size and font.get_string_size("9", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + MARGIN*2 >= size.x / 3:
				font_size -= 1
			
			var text_color: Color = %Sudoku.sudoku_theme.CELL_CORNER_MARK_TEXT
			var row: Array[int] = [0,0,2,2,0,2,1,1,1]
			var col: Array[int] = [0,2,0,2,1,1,0,2,1]
			var index := 0
			var sz := size - Vector2(MARGIN,MARGIN)
			for q in corner_marks.size():
				if not corner_marks[q]: continue
				var s := str(q+1)
				
				var pos := Vector2(col[index] * sz.x/3,(row[index] * sz.y/3)+font.get_ascent(font_size))
				
				if index == 8:
					pos -= Vector2(4,4)
				
				draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_CENTER, size.x/3, font_size, text_color)
				index += 1
		if has_center:
			var s := ""
			for q in center_marks.size():
				if not center_marks[q]: continue
				s += str(q+1)
			var text_color: Color = %Sudoku.sudoku_theme.CELL_CENTER_MARK_TEXT
			const C_MARGIN := MARGIN*4
			var font := get_theme_default_font()
			var font_size := 13
			while font.get_height(font_size) + C_MARGIN*2 <= size.y:
				font_size += 1
			font_size -= 1
			while font_size and font.get_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x + MARGIN*2 >= size.x:
				font_size -= 1
			
			var pos := Vector2(0,(size.y-font.get_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).y)/2 + font.get_ascent(font_size))
			draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_CENTER, size.x, font_size, text_color)
		pass
	const BORDER_WID := 5
	if is_selected: # Border
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
		const FOCUS_WID = BORDER_WID / 2.0
		draw_rect(Rect2(FOCUS_WID/2,FOCUS_WID/2,size.x - FOCUS_WID, size.y - FOCUS_WID), Color.RED, false, FOCUS_WID)

func _ready():
	focus_next = get_path()
	focus_previous = get_path()

func clear() -> void:
	is_given = false
	draw_invalid = false
	solution = 0
	value = 0
	corner_marks.fill(false)
	center_marks.fill(false)

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

func erase() -> void:
	if is_given: return
	if value:
		value = 0
		return
	for mark in center_marks:
		if mark:
			center_marks.fill(false)
			return
	for mark in corner_marks:
		if mark:
			corner_marks.fill(false)
			return

func enter_val(v: int, mode: SudokuGrid.EntryMode) -> void:
	if is_given: return
	match mode:
		SudokuGrid.EntryMode.ANSWER:
			value = 0 if value == v else v
		SudokuGrid.EntryMode.CENTER:
			center_marks[v-1] = not center_marks[v-1]
		SudokuGrid.EntryMode.CORNER:
			corner_marks[v-1] = not corner_marks[v-1]
	grid_redraw.emit()

func _gui_input(event):
	if event is InputEventMouseMotion:
		if event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT):
			_reselect(self, true)
	elif event is InputEventMouseButton:
		if event.pressed:
			_reselect(self, event.shift_pressed or event.is_command_or_control_pressed())
	elif event is InputEventKey:
		if event.pressed:
			var multi = event.shift_pressed or event.is_command_or_control_pressed()
			match event.keycode:
				KEY_UP:
					_reselect(top, multi)
				KEY_DOWN:
					_reselect(bottom, multi)
				KEY_LEFT:
					_reselect(left, multi)
				KEY_RIGHT:
					_reselect(right, multi)
	grid_input.emit(event)

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
