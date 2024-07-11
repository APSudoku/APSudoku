class_name SudokuGrid extends MarginContainer

var active_puzzle: PuzzleGrid
var regions = [[],[],[],[],[],[],[],[],[]]
var rows = [[],[],[],[],[],[],[],[],[]]
var columns = [[],[],[],[],[],[],[],[],[]]

func _ready():
	var box_index := 0
	for box in %Regions.get_children():
		var cells = box.get_children()
		regions[box_index].assign(cells)
		for q in range(0,3):
			rows[floor(box_index/3.0)*3].append(cells[q])
		for q in range(3,6):
			rows[floor(box_index/3.0)*3+1].append(cells[q])
		for q in range(6,9):
			rows[floor(box_index/3.0)*3+2].append(cells[q])
		for q in range(0,9,3):
			columns[floor(box_index%3)*3].append(cells[q])
		for q in range(1,9,3):
			columns[floor(box_index%3)*3 + 1].append(cells[q])
		for q in range(2,9,3):
			columns[floor(box_index%3)*3 + 2].append(cells[q])
		box_index += 1
	for r in regions:
		for c in r:
			c.add_neighbors(r)
	for r in rows:
		for c in r:
			c.add_neighbors(r)
	for r in columns:
		for c in r:
			c.add_neighbors(r)
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

func clear() -> void:
	active_puzzle = null
	for r in rows:
		for c in r:
			c.clear()
	%MainLabel.text = "No Active Game"
	%MainLabel.label_settings.font_color = Color.RED
	var arr = PuzzleGrid.Difficulty.values().duplicate()
	arr.shuffle()
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
