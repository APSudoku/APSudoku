class_name SudokuGrid extends MarginContainer

signal modifier_entry_mode(val: EntryMode)
signal cycle_entry_mode

var config: SudokuConfigManager :
	get: return Archipelago.config
	set(val): Archipelago.config = val
@export var sudoku_theme := SudokuTheme.new()

var show_invalid := false
var mode: EntryMode = EntryMode.ANSWER
var mod_mode: int = -1
var difficulty: PuzzleGrid.Difficulty
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
	
	config.config_changed.connect(update_config)
	set_difficulty(PuzzleGrid.Difficulty.MEDIUM)

func update_config() -> void:
	%ControlInfo.format_args[0] = "Shift: Center, Ctrl: Corner" if \
		config.shift_center else "Shift: Corner, Ctrl: Center"

func submit_solution() -> bool:
	_invalid = false
	for c in cells:
		c.draw_invalid = false
	grid_redraw() # Queues the redraw, so no need to call more than once
	var s: String
	if not check_filled():
		s = "Grid contains unfilled cells! Please fill before submitting!"
		Util.freeze_popup(get_tree(), "Error", s, false).popup_centered()
		return false
	if check_solve():
		s = "(TODO: HINTS)" #TODO popup the hint reward!
		Util.freeze_popup(get_tree(), "Correct!", s, false).popup_centered()
		return true
	s = "Grid contains incorrect values!"
	
	Util.freeze_popup(get_tree(), "Correct!", s, false).popup_centered()
	#TODO popup mentioning wrong solution, DEATHLINK
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

func type_number(v: int) -> void:
	if v < 1 or v > 9: return
	for c in cells:
		if c.is_selected:
			c.enter_val(v, mode)

var _shift: bool = false
var _ctrl: bool = false
func _gui_input(event):
	if _has_mouse_directly and event is InputEventMouseButton:
		accept_event()
	grid_input(event)
func grid_input(event) -> void:
	if get_tree().paused: return
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
				KEY_TAB:
					cycle_entry_mode.emit()
					accept_event()
			if v >= 1 and v <= 9:
				type_number(v)
				accept_event()
	#TODO double-click to select similar cells feature
func grid_focus(cell: Cell) -> void:
	if cell.has_focus(): return
	var foc_owner = get_viewport().gui_get_focus_owner()
	if foc_owner: foc_owner.release_focus()
	cell.grab_focus()
func recheck_focus() -> void:
	for c in cells:
		if c.has_focus():
			return
	clear_select()
func grid_redraw() -> void:
	queue_redraw()
	for c in cells:
		c.queue_redraw()
func clear_selected():
	for c in cells:
		if c.is_selected:
			c.erase()
func clear_select() -> void:
	for c in cells:
		c.is_selected = false
	grid_redraw()
func clear() -> void:
	active_puzzle = null
	%StartButton.disabled = false
	%ForfeitButton.disabled = true
	%CheckButton.disabled = true
	for c in cells:
		c.clear()
	%MainLabel.text = "No Active Game"
	%MainLabel.label_settings.font_color = sudoku_theme.LABEL_INVALID_TEXT
	grid_redraw()
func start_puzzle() -> void:
	if active_puzzle: return
	%StartButton.disabled = true
	%GeneratingLabel.visible = true
	var puz := await PuzzleGenManager.get_puzzle(%Sudoku.difficulty)
	%GeneratingLabel.visible = false
	load_puzzle(puz)
func load_puzzle(puzzle: PuzzleGrid) -> void:
	clear()
	active_puzzle = puzzle
	%StartButton.disabled = true
	%ForfeitButton.disabled = false
	%CheckButton.disabled = false
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
	grid_redraw()

func set_shift_center(val: bool) -> void:
	config.shift_center = val

func set_show_invalid(val: bool) -> void:
	config.show_invalid = val

func set_shapes_mode(val: bool) -> void:
	config.shapes_mode = val

var _has_mouse_directly := false
func _notification(what):
	match what:
		NOTIFICATION_MOUSE_ENTER_SELF:
			_has_mouse_directly = true
		NOTIFICATION_MOUSE_EXIT_SELF:
			_has_mouse_directly = false

func set_difficulty(diff: int):
	[%RadioEasy,%RadioMedium,%RadioHard][diff].button_pressed = true
	difficulty = diff as PuzzleGrid.Difficulty

func _forfeited() -> void:
	clear()
	if Archipelago.is_ap_connected() and Archipelago.is_deathlink():
		Archipelago.conn.send_deathlink("%s failed at %s Sudoku" % [Archipelago.conn.get_player_name(-1), PuzzleGrid.Difficulty.find_key(difficulty).to_pascal_case()])
func forfeit_puzzle() -> bool:
	if not active_puzzle: return false
	var s := "Are you sure you wish to forfeit the current puzzle?"
	if Archipelago.is_ap_connected() and Archipelago.is_deathlink():
		s += "\nForfeiting counts as a death towards DeathLink!"
	var popup := Util.freeze_popup(get_tree(), "Forfeit?", s, true)
	var lbl := popup.get_label()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	popup.confirmed.connect(_forfeited)
	popup.popup_centered()
	return active_puzzle == null
