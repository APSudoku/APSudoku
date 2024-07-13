class_name PuzzleGrid extends Resource
#TODO create these with threaded generators
enum Difficulty {
	EASY, MEDIUM, HARD, KILLER
}

var difficulty: Difficulty
var solutions: Array[int] = []
var givens: Array[bool] = []

