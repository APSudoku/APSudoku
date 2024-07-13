class_name SudokuGrid extends MarginContainer

signal modifier_entry_mode(val: EntryMode)

var config: SudokuConfigManager :
	get: return Archipelago.config
	set(val): Archipelago.config = val
@export var sudoku_theme := SudokuTheme.new()

var show_invalid := false
var mode: EntryMode = EntryMode.ANSWER
var mod_mode: int = -1
enum EntryMode {
	ANSWER, CENTER, CORNER
}
var active_puzzle: PuzzleGrid
#region Cell storage
var cells: Array[Cell] = []
var regions = [[],[],[],[],[],[],[],[],[]]
var rows = [[],[],[],[],[],[],[],[],[]]
var columns = [[],[],[],[],[],[],[],[],[]]
#endregion

var _invalid := false

func _ready():
	var box_index := 0
	for box in %Regions.get_children():
		var box_cells = box.get_children()
		regions[box_index].assign(box_cells)
		for q in range(0,3):
			rows[floor(box_index/3.0)*3].append(box_cells[q])
		for q in range(3,6):
			rows[floor(box_index/3.0)*3+1].append(box_cells[q])
		for q in range(6,9):
			rows[floor(box_index/3.0)*3+2].append(box_cells[q])
		for q in range(0,9,3):
			columns[floor(box_index%3)*3].append(box_cells[q])
		for q in range(1,9,3):
			columns[floor(box_index%3)*3 + 1].append(box_cells[q])
		for q in range(2,9,3):
			columns[floor(box_index%3)*3 + 2].append(box_cells[q])
		box_index += 1
	for r in rows:
		for c in r:
			cells.append(c)
	for r in regions:
		for c in r:
			c.add_neighbors(r)
	for r in rows:
		for c in r:
			c.add_neighbors(r)
	for r in columns:
		for c in r:
			c.add_neighbors(r)
	for q in 81:
		if q % 9 != 8:
			cells[q].right = cells[q+1]
		if q % 9 != 0:
			cells[q].left = cells[q-1]
		if floor(q/9.0) != 0:
			cells[q].top = cells[q-9]
		if floor(q/9.0) != 8:
			cells[q].bottom = cells[q+9]
		cells[q].clear_select.connect(clear_select)
		cells[q].grid_redraw.connect(grid_redraw)
		cells[q].grid_input.connect(grid_input)
		cells[q].recheck_focus.connect(recheck_focus)
		cells[q].grid_focus.connect(grid_focus)
	
	%MainLabel.label_settings = %MainLabel.label_settings.duplicate() # Should be unique at runtime, *more* unique than "per scene"
	clear()

func submit_solution() -> bool:
	_invalid = false
	for c in cells:
		c.draw_invalid = false
	grid_redraw() # Queues the redraw, so no need to call more than once
	if not check_filled():
		#TODO popup mentioning grid is wrong due to having empty cells. NO DEATHLINK.
		return false
	if check_solve():
		#TODO popup the hint reward!
		return true
	
	for c in cells:
		if not c.is_valid():
			c.draw_invalid = true
			_invalid = true
	return false

func check_filled() -> bool:
	for c in cells:
		if c.value == 0:
			return false
	return true
func check_solve() -> bool:
	for r in regions:
		for c in r:
			if not c.is_solved():
				return false
	return true

var _shift: bool = false
var _ctrl: bool = false
func grid_input(event) -> void:
	var update_modifiers := false
	if event is InputEventKey:
		if event.keycode == KEY_SHIFT:
			_shift = event.pressed
			update_modifiers = true
		elif event.keycode == KEY_CTRL:
			_ctrl = event.pressed
			update_modifiers = true
	if update_modifiers:
		if _shift:
			mod_mode = EntryMode.CENTER if config.shift_center else EntryMode.CORNER
			modifier_entry_mode.emit(mod_mode)
		elif _ctrl:
			mod_mode = EntryMode.CORNER if config.shift_center else EntryMode.CENTER
			modifier_entry_mode.emit(mod_mode)
		elif mod_mode > -1:
			mod_mode = -1
			modifier_entry_mode.emit(mod_mode)
	
	if event is InputEventKey:
		if event.pressed and not event.echo:
			var v := 0
			match event.keycode:
				KEY_1, KEY_KP_1: v = 1
				KEY_2, KEY_KP_2: v = 2
				KEY_3, KEY_KP_3: v = 3
				KEY_4, KEY_KP_4: v = 4
				KEY_5, KEY_KP_5: v = 5
				KEY_6, KEY_KP_6: v = 6
				KEY_7, KEY_KP_7: v = 7
				KEY_8, KEY_KP_8: v = 8
				KEY_9, KEY_KP_9: v = 9
				KEY_DELETE, KEY_BACKSPACE:
					for c in cells:
						if c.is_selected:
							c.erase()
					grid_redraw()
					accept_event()
			if v >= 1 and v <= 9:
				for c in cells:
					if c.is_selected:
						c.enter_val(v, mode)
				accept_event()
	#TODO double-click to select similar cells feature
func grid_focus(cell: Cell) -> void:
	if cell.has_focus(): return
	get_viewport().gui_get_focus_owner().release_focus()
	cell.grab_focus()
func recheck_focus() -> void:
	if has_focus(): return
	for c in cells:
		if c.has_focus():
			return
	clear_select()
func grid_redraw() -> void:
	queue_redraw()
	for c in cells:
		c.queue_redraw()
func clear_select() -> void:
	for c in cells:
		c.is_selected = false
func clear() -> void:
	active_puzzle = null
	for c in cells:
		c.clear()
	%MainLabel.text = "No Active Game"
	%MainLabel.label_settings.font_color = sudoku_theme.LABEL_INVALID_TEXT
func load_puzzle(puzzle: PuzzleGrid) -> void:
	clear()
	active_puzzle = puzzle
	%MainLabel.text = "Difficulty: %s" % PuzzleGrid.Difficulty.find_key(puzzle.difficulty).to_pascal_case()
	%MainLabel.label_settings.font_color = Color.WHITE
	var q := 0
	for r in rows:
		for c in r:
			c.solution = puzzle.solutions[q]
			if puzzle.givens[q]:
				c.is_given = true
				c.value = c.solution
			q += 1

func set_shift_center(val: bool) -> void:
	config.shift_center = val

func set_show_invalid(val: bool) -> void:
	config.show_invalid = val

func set_shapes_mode(val: bool) -> void:
	config.shapes_mode = val
