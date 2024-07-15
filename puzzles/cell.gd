class_name Cell extends ColorRect

signal clear_select
signal grid_redraw
signal recheck_focus
signal grid_input
signal grid_focus(cell: Cell)
signal select_alike(cell: Cell)

var index: int = -1
var cage: PuzzleCage

var _skip_focus_recheck := false
var has_mouse := false
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

var _shape_textures: Array[Texture2D] = []
var _small_shape_textures: Array[Texture2D] = []
func _draw_shape(val: int, rect: Rect2) -> void:
	if val < 1 or val > 9: return
	var tex: Texture2D = _shape_textures[val-1]
	if rect.size.x < 30 and rect.size.y < 30:
		tex = _small_shape_textures[val-1]
	draw_texture_rect(tex, rect, false, %Sudoku.sudoku_theme.get_shape_color(val))
func _draw_shapes() -> void:
	var bg_col: Color = %Sudoku.sudoku_theme.SHAPE_BG
	if is_given: bg_col = %Sudoku.sudoku_theme.SHAPE_GIVEN_BG
	elif draw_invalid: bg_col = %Sudoku.sudoku_theme.SHAPE_INVALID_BG
	draw_rect(Rect2(Vector2.ZERO,size), bg_col)
	if value:
		_draw_shape(value, Rect2(Vector2.ZERO,size))
	else:
		for col in 3:
			for row in 3:
				var indx := col + row * 3
				if corner_marks[indx]:
					_draw_shape(1 + indx, Rect2(Vector2(col * size.x/3, row * size.y/3), size/3))
func _draw_numbers() -> void:
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
		
		var pos := Vector2(0,(size.y-font.get_string_size(s, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).y)/2 + font.get_ascent(font_size))
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
			var ind := 0
			var sz := size - Vector2(MARGIN,MARGIN)
			for q in corner_marks.size():
				if not corner_marks[q]: continue
				var s := str(q+1)
				
				var pos := Vector2(col[ind] * sz.x/3,(row[ind] * sz.y/3)+font.get_ascent(font_size))
				
				if ind == 8:
					pos -= Vector2(4,4)
				
				draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_CENTER, size.x/3, font_size, text_color)
				ind += 1
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
const _BORDER_WID := 6
func _draw() -> void:
	if %Sudoku.config.shapes_mode:
		_draw_shapes()
	else: _draw_numbers()
	_draw_selection()
	_draw_cages()
func _draw_selection() -> void:
	if is_selected: # Border
		var COLOR: Color = %Sudoku.sudoku_theme.CELL_SELECT
		var _tl := false
		var _tr := false
		var _bl := false
		var _br := false
		if not (left and left.is_selected):
			draw_rect(Rect2(0,0,_BORDER_WID,size.y), COLOR)
			_tl = true
			_bl = true
		if not (right and right.is_selected):
			draw_rect(Rect2(size.x-_BORDER_WID,0,_BORDER_WID,size.y), COLOR)
			_tr = true
			_br = true
		if not (top and top.is_selected):
			draw_rect(Rect2(0,0,size.x,_BORDER_WID), COLOR)
			_tl = true
			_tr = true
		if not (bottom and bottom.is_selected):
			draw_rect(Rect2(0,size.y-_BORDER_WID,size.x,_BORDER_WID), COLOR)
			_bl = true
			_br = true
		if not _tl and not (topleft and topleft.is_selected):
			draw_rect(Rect2(0,0,_BORDER_WID,_BORDER_WID), COLOR)
		if not _tr and not (topright and topright.is_selected):
			draw_rect(Rect2(size.x-_BORDER_WID,0,_BORDER_WID,_BORDER_WID), COLOR)
		if not _bl and not (bottomleft and bottomleft.is_selected):
			draw_rect(Rect2(0,size.y-_BORDER_WID,_BORDER_WID,_BORDER_WID), COLOR)
		if not _br and not (bottomright and bottomright.is_selected):
			draw_rect(Rect2(size.x-_BORDER_WID,size.y-_BORDER_WID,_BORDER_WID,_BORDER_WID), COLOR)
	if has_focus():
		var COLOR: Color = %Sudoku.sudoku_theme.CELL_FOCUS
		const FOCUS_WID := _BORDER_WID / 2.0
		draw_rect(Rect2(FOCUS_WID/2.0,FOCUS_WID/2.0,size.x - FOCUS_WID, size.y - FOCUS_WID), COLOR, false, FOCUS_WID)
func _draw_cages() -> void:
	if not cage: return # Nothing to draw here
	const CAGE_BWID := _BORDER_WID / 2.0
	var border_col: Color = %Sudoku.sudoku_theme.KILLER_BORDER
	var sum_col: Color = %Sudoku.sudoku_theme.KILLER_SUM
	var x0: float = 1
	var y0: float = 1
	var x1: float = CAGE_BWID
	var y1: float = CAGE_BWID
	var x2: float = size.x-CAGE_BWID
	var y2: float = size.y-CAGE_BWID
	var x3: float = size.x-1
	var y3: float = size.y-1
	#region BORDER
	var t := not top or top.cage != cage
	var b := not bottom or bottom.cage != cage
	var l := not left or left.cage != cage
	var r := not right or right.cage != cage
	var lx = x1 if l else x0
	var rx = x2 if r else x3
	var ty = y1 if t else y0
	var by = y2 if b else y3
	if t:
		draw_dashed_line(Vector2(lx,y1), Vector2(rx,y1), border_col, 2)
	if b:
		draw_dashed_line(Vector2(lx,y2), Vector2(rx,y2), border_col, 2)
	if l:
		draw_dashed_line(Vector2(x1,ty), Vector2(x1,by), border_col, 2)
	if r:
		draw_dashed_line(Vector2(x2,ty), Vector2(x2,by), border_col, 2)
	if topleft and topleft.cage != cage:
		if not (t or l):
			draw_line(Vector2(x1,y1), Vector2(x1,y0), border_col, 2)
			draw_line(Vector2(x1,y1), Vector2(x0,y1), border_col, 2)
	if topright and topright.cage != cage:
		if not (t or r):
			draw_line(Vector2(x2,y1), Vector2(x2,y0), border_col, 2)
			draw_line(Vector2(x2,y1), Vector2(x3,y1), border_col, 2)
	if bottomleft and bottomleft.cage != cage:
		if not (b or l):
			draw_line(Vector2(x1,y2), Vector2(x1,y3), border_col, 2)
			draw_line(Vector2(x1,y2), Vector2(x0,y2), border_col, 2)
	if bottomright and bottomright.cage != cage:
		if not (b or r):
			draw_line(Vector2(x2,y2), Vector2(x2,y3), border_col, 2)
			draw_line(Vector2(x2,y2), Vector2(x3,y2), border_col, 2)
	#endregion BORDER
	if index == cage.cells.front(): #region SUM
		const TXT_BWID := 3
		var WID := size.x - CAGE_BWID*2
		var HEI := (size.y - CAGE_BWID*2) / 3
		var s := str(cage.sum)
		var font := get_theme_default_font()
		var font_size := 1
		while font.get_height(font_size) <= HEI:
			font_size += 1
		font_size -= 1
		while font_size and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x >= WID:
			font_size -= 1
		var pos := Vector2(x1+TXT_BWID,y1+TXT_BWID+font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).y/2)
		draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, WID, font_size, sum_col)
	#endregion SUM
	pass
func _ready():
	focus_next = get_path()
	focus_previous = get_path()
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)
	_shape_textures.append(preload("res://graphics/shapes/1.png"))
	_shape_textures.append(preload("res://graphics/shapes/2.png"))
	_shape_textures.append(preload("res://graphics/shapes/3.png"))
	_shape_textures.append(preload("res://graphics/shapes/4.png"))
	_shape_textures.append(preload("res://graphics/shapes/5.png"))
	_shape_textures.append(preload("res://graphics/shapes/6.png"))
	_shape_textures.append(preload("res://graphics/shapes/7.png"))
	_shape_textures.append(preload("res://graphics/shapes/8.png"))
	_shape_textures.append(preload("res://graphics/shapes/9.png"))
	_small_shape_textures.append(preload("res://graphics/shapes/1small.png"))
	_small_shape_textures.append(preload("res://graphics/shapes/2small.png"))
	_small_shape_textures.append(preload("res://graphics/shapes/3small.png"))
	_small_shape_textures.append(preload("res://graphics/shapes/4small.png"))
	_small_shape_textures.append(preload("res://graphics/shapes/5small.png"))
	_small_shape_textures.append(preload("res://graphics/shapes/6small.png"))
	_small_shape_textures.append(preload("res://graphics/shapes/7small.png"))
	_small_shape_textures.append(preload("res://graphics/shapes/8small.png"))
	_small_shape_textures.append(preload("res://graphics/shapes/9small.png"))

func clear() -> void:
	is_given = false
	draw_invalid = false
	is_selected = has_focus()
	solution = 0
	value = 0
	corner_marks.fill(false)
	center_marks.fill(false)
	cage = null

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
		grid_redraw.emit()
		return
	for mark in center_marks:
		if mark:
			center_marks.fill(false)
			grid_redraw.emit()
			return
	for mark in corner_marks:
		if mark:
			corner_marks.fill(false)
			grid_redraw.emit()
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

func _on_mouse_enter():
	has_mouse = true
	if get_tree().paused: return
	if not %Regions.allow_grid_sel: return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_reselect(self, true)
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if %Sudoku._shift or %Sudoku._ctrl:
			is_selected = false
			if has_focus():
				_skip_focus_recheck = true
				release_focus()
				%Sudoku.grab_focus()
			grid_redraw.emit()
		else: _reselect(self, true)
func _on_mouse_exit():
	has_mouse = false
func _gui_input(event):
	if get_tree().paused:
		accept_event()
		return
	var multi = %Sudoku._shift or %Sudoku._ctrl
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			accept_event()
			return
		if event.pressed and has_mouse:
			if event.button_index == MOUSE_BUTTON_RIGHT and multi:
				is_selected = false
				if has_focus():
					_skip_focus_recheck = true
					release_focus()
					%Sudoku.grab_focus()
				grid_redraw.emit()
			else: _reselect(self, multi)
			if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
				select_alike.emit(self)
			return
	elif event is InputEventKey:
		if event.pressed:
			match event.keycode:
				KEY_UP, KEY_W:
					_reselect(top, multi)
					accept_event()
				KEY_DOWN, KEY_S:
					_reselect(bottom, multi)
					accept_event()
				KEY_LEFT, KEY_A:
					_reselect(left, multi)
					accept_event()
				KEY_RIGHT, KEY_D:
					_reselect(right, multi)
					accept_event()
	grid_input.emit(event)

func _reselect(c: Cell, multi: bool) -> void:
	if not c: return
	if not multi:
		clear_select.emit()
	c.is_selected = true
	grid_focus.emit(c)
	await get_tree().process_frame
	grid_redraw.emit()

func _notification(what):
	match what:
		NOTIFICATION_FOCUS_EXIT:
			if _skip_focus_recheck:
				_skip_focus_recheck = false
				return
			await get_tree().process_frame
			recheck_focus.emit()
