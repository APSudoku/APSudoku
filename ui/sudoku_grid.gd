class_name SudokuGrid extends MarginContainer

@export var sudoku_theme := SudokuTheme.new()

var active_puzzle: PuzzleGrid
var cells: Array[Cell] = []
var regions = [[],[],[],[],[],[],[],[],[]]
var rows = [[],[],[],[],[],[],[],[],[]]
var columns = [[],[],[],[],[],[],[],[],[]]

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
		cells[q].recheck_focus.connect(recheck_focus)
	clear()

func check_invalid() -> bool:
	for r in regions:
		for c in r:
			if not c.is_valid():
				return false
	return true
func check_solve() -> bool:
	for r in regions:
		for c in r:
			if not c.is_solved():
				return false
	return true

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
	%MainLabel.label_settings.font_color = Color.RED
	var arr = PuzzleGrid.Difficulty.values().duplicate()
	arr.shuffle()
	
	#TODO remove temp
	cells[21].is_selected = true
	cells[22].is_selected = true
	cells[30].is_selected = true
	cells[31].is_selected = true
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
