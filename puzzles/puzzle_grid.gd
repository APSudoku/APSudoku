class_name PuzzleGrid extends Resource
#TODO create these with threaded generators
enum Difficulty {
	EASY, MEDIUM, HARD, KILLER
}

var difficulty: Difficulty
var solutions: Array[int] = []
var givens: Array[bool] = []

func _init():
	solutions.resize(81)
	givens.resize(81)

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
