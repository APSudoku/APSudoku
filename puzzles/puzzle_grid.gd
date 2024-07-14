class_name PuzzleGrid extends Resource
enum Difficulty {
	EASY, MEDIUM, HARD, KILLER
}

var difficulty: Difficulty
var solutions: Array[int] = []
var givens: Array[bool] = []

func _init(diff: Difficulty):
	solutions.resize(81)
	givens.resize(81)
	var grid := GenGrid.new(diff)
	grid.generate()
	var q := 0
	for c in grid.cells:
		givens[q] = c.given
		solutions[q] = c.sol
		q += 1

func _to_string():
	var s: String = "---PUZZLEGRID %s---\n" % Difficulty.find_key(difficulty)
	for row in 9:
		for col in 9:
			s += str(solutions[row*9+col])
			if col % 3 == 2:
				s += " "
		s += "    "
		for col in 9:
			s += str(solutions[row*9+col]) if givens[row*9+col] else "_"
			if col % 3 == 2:
				s += " "
		s += "\n"
		if row % 3 == 2:
			s += "\n"
	s += "--- ---\n"
	return s

class GenGrid:
	var diff: Difficulty
	class GenCell:
		var sol: int = 0
		var val: int = 0
		var given: bool = false
		var options: Dictionary
		#TODO cages
		func _init():
			clear()
		func clear():
			sol = 0
			val = 0
			given = false
			reset_options()
		func reset_options() -> void:
			options = {1:true,2:true,3:true,4:true,5:true,6:true,7:true,8:true,9:true}
		func duplicate() -> GenCell:
			var other := GenCell.new()
			other.sol = sol
			other.val = val
			other.given = given
			other.options = options.duplicate(true)
			return other
		func _to_string():
			return "%d [%d]%s %s" % [val,sol," Given" if given else "",options.keys()]
	var cells: Array[GenCell] = []
	func _init(d: Difficulty):
		diff = d
		for q in 81:
			cells.append(GenCell.new())
	func generate():
		populate()
		build()
	func duplicate() -> GenGrid:
		var other = GenGrid.new(diff)
		for q in 81:
			other.cells[q] = cells[q].duplicate()
		return other
	##TODO Fills the grid with a random valid solution
	func populate() -> void:
		pass
	##TODO Trims away givens for the specified difficulty (from a populated grid)
	func build():
		pass
	##TODO Fills the (populated) grid with random killer cages
	func killer_fill() -> void:
		pass
