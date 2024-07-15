class_name SudokuGrid extends MarginContainer

const CHEAT_MODE := true

signal modifier_entry_mode(val: EntryMode)
signal cycle_entry_mode
signal grant_hint(prog_percent: int)

var config: SudokuConfigManager :
	get: return Archipelago.config
	set(val): Archipelago.config = val
@export var sudoku_theme := SudokuTheme.new()

var deaths_towards_amnesty := 0
var death_amnesty := 0
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
var cages: Array[PuzzleCage] = []

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
		cells[q].index = q
		cells[q].clear_select.connect(clear_select)
		cells[q].grid_redraw.connect(grid_redraw)
		cells[q].grid_input.connect(grid_input)
		cells[q].recheck_focus.connect(recheck_focus)
		cells[q].grid_focus.connect(grid_focus)
		cells[q].select_alike.connect(select_alike)
	
	%MainLabel.label_settings = %MainLabel.label_settings.duplicate() # Should be unique at runtime, *more* unique than "per scene"
	clear()
	
	config.config_changed.connect(update_config)
	set_difficulty(PuzzleGrid.Difficulty.MEDIUM)

func update_config() -> void:
	%ControlInfo.format_args[0] = "Shift: Center, Ctrl: Corner" if \
		config.shift_center else "Shift: Corner, Ctrl: Center"

func set_invalid() -> void:
	if not %Sudoku.config.show_invalid: return
	_invalid = false
	for c in cells:
		c.draw_invalid = not c.is_valid()
		if c.draw_invalid:
			_invalid = true
	%ClearInvalid.visible = _invalid
	grid_redraw()
func clear_invalid() -> void:
	_invalid = false
	for c in cells:
		c.draw_invalid = false
	%ClearInvalid.visible = false
	grid_redraw()

func submit_solution() -> bool:
	grid_redraw() # Queues the redraw, so no need to call more than once
	clear_invalid()
	var s: String
	if not check_filled():
		s = "Grid contains unfilled cells! Please fill before submitting!"
		await PopupManager.popup_dlg(s, "Error", false)
		return false
	if check_solve():
		if Archipelago.is_ap_connected():
			var prog_percent: int
			match difficulty:
				PuzzleGrid.Difficulty.EASY:
					prog_percent = 10
				PuzzleGrid.Difficulty.MEDIUM:
					prog_percent = 40
				PuzzleGrid.Difficulty.HARD:
					prog_percent = 80
				PuzzleGrid.Difficulty.KILLER:
					prog_percent = 60
			grant_hint.emit(prog_percent)
		else: await PopupManager.popup_dlg("Not connected, so no hint granted.", "Correct!", false)
		clear_active()
		return true
	s = "Grid contains incorrect values!"
	if Archipelago.is_deathlink():
		if _lost_puzzle(false):
			s += "\nYou ran out of lives! (DeathLink sent)"
	
	set_invalid()
	await PopupManager.popup_dlg(s, "Wrong!", false)
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
func grid_focus(cell: Cell) -> void:
	if cell.has_focus(): return
	var foc_owner = get_viewport().gui_get_focus_owner()
	if foc_owner: foc_owner.release_focus()
	cell.grab_focus()
func select_alike(cell: Cell) -> void:
	var _bool: Callable = func(b: bool) -> bool: return b
	for c in cells:
		if cell.value != c.value:
			continue
		if not cell.value:
			if cell.center_marks.any(_bool):
				if c.center_marks != cell.center_marks:
					continue
			elif cell.corner_marks.any(_bool):
				if c.corner_marks != cell.corner_marks:
					continue
			elif c.center_marks.any(_bool) or c.corner_marks.any(_bool):
				continue
		c.is_selected = true
	grid_redraw()
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
func clear_active() -> void:
	active_puzzle = null
	for node in %DiffContainer.get_children():
		if node is CheckBox:
			node.disabled = false
	%StartButton.disabled = false
	%ForfeitButton.disabled = true
	%CheckButton.disabled = true
	%MainLabel.text = "No Active Game"
	%MainLabel.label_settings.font_color = sudoku_theme.LABEL_INVALID_TEXT
	grid_redraw()
func clear() -> void:
	for btn in %NumPad.get_children():
		btn.disabled = false
	for c in cells:
		c.clear()
	clear_active()
	clear_invalid()
	grid_redraw()
func start_puzzle() -> void:
	if active_puzzle: return
	if Archipelago.is_not_connected():
		_invalid = true
		var popup := PopupManager.create_popup("No hints can be earned while not connected. Start anyway?", "No Connection", true)
		if not await popup.pop_open():
			return
	%StartButton.disabled = true
	for node in %DiffContainer.get_children():
		if node is CheckBox:
			node.disabled = true
	%GeneratingLabel.visible = true
	var puz := await PuzzleGenManager.get_puzzle(%Sudoku.difficulty)
	%GeneratingLabel.visible = false
	load_puzzle(puz)
func load_puzzle(puzzle: PuzzleGrid) -> void:
	clear()
	active_puzzle = puzzle
	for node in %DiffContainer.get_children():
		if node is CheckBox:
			node.disabled = true
	%StartButton.disabled = true
	%ForfeitButton.disabled = false
	%CheckButton.disabled = false
	%MainLabel.text = "Difficulty: %s" % PuzzleGrid.Difficulty.find_key(puzzle.difficulty).to_pascal_case()
	if death_amnesty:
		%MainLabel.text += " (%d/%d Lives)" % [death_amnesty-deaths_towards_amnesty,death_amnesty]
	%MainLabel.label_settings.font_color = Color.WHITE
	var q := 0
	for c in cells:
		c.solution = puzzle.solutions[q]
		if puzzle.givens[q]:
			c.is_given = true
			c.value = c.solution
		if OS.is_debug_build() and CHEAT_MODE:
			c.value = c.solution
		q += 1
	cages = puzzle.cages.duplicate(true)
	for cage in cages:
		for ind in cage.cells:
			cells[ind].cage = cage
	grid_redraw()

var _has_mouse_directly := false
func _notification(what):
	match what:
		NOTIFICATION_MOUSE_ENTER_SELF:
			_has_mouse_directly = true
		NOTIFICATION_MOUSE_EXIT_SELF:
			_has_mouse_directly = false

func set_difficulty(diff: int):
	[%RadioEasy,%RadioMedium,%RadioHard,%RadioKiller][diff].button_pressed = true
	difficulty = diff as PuzzleGrid.Difficulty

func _lost_puzzle(force_clear := true) -> bool:
	if deaths_towards_amnesty == death_amnesty:
		deaths_towards_amnesty = 0
		if Archipelago.is_ap_connected():
			Archipelago.conn.send_deathlink("%s failed at %s Sudoku" % [Archipelago.conn.get_player_name(-1), PuzzleGrid.Difficulty.find_key(difficulty).to_pascal_case()])
		clear()
		return true
	deaths_towards_amnesty += 1
	%MainLabel.text = "Difficulty: %s" % PuzzleGrid.Difficulty.find_key(difficulty).to_pascal_case()
	if death_amnesty:
		%MainLabel.text += " (%d/%d Lives)" % [death_amnesty-deaths_towards_amnesty,death_amnesty]
	if force_clear:
		clear()
	return false
func forfeit_puzzle() -> bool:
	if not active_puzzle: return false
	var s := "Are you sure you wish to forfeit the current puzzle?"
	if Archipelago.is_ap_connected() and Archipelago.is_deathlink():
		s += "\nForfeiting counts as a death towards DeathLink!"
	var popup := PopupManager.create_popup(s, "Forfeit?", true)
	var lbl := popup.get_label()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if await popup.pop_open():
		_lost_puzzle(true)
		return true
	return false

func deathlink_recv(source: String, cause: String, _json: Dictionary) -> void:
	var s: String = cause
	if s.is_empty():
		s = "%s died, taking you with them." % source
	await PopupManager.popup_dlg(s, "DeathLink", false)
	clear()
