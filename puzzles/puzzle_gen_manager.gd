extends Node
#Autoload 'PuzzleGenManager'

signal puzzle_added

var running: bool = true
var puz_mutex := Mutex.new()
var puzzles_by_diff: Array[Array] = []

func _init():
	puzzles_by_diff.resize(PuzzleGrid.Difficulty.size())
	for q in 10:
		for d in PuzzleGrid.Difficulty.values():
			launch_puzzle_gen(d)

func generate_puzzle(diff: PuzzleGrid.Difficulty) -> void:
	add_puzzle(PuzzleGrid.new(diff))

func launch_puzzle_gen(diff: PuzzleGrid.Difficulty) -> void:
	WorkerThreadPool.add_task(generate_puzzle.bind(diff))

func get_puzzle(diff: PuzzleGrid.Difficulty) -> PuzzleGrid:
	var ret: PuzzleGrid
	puz_mutex.lock()
	if puzzles_by_diff[diff].is_empty():
		puz_mutex.unlock()
		while not ret:
			await puzzle_added
			puz_mutex.lock()
			if not puzzles_by_diff[diff].is_empty():
				break # Found a puzzle to return, break out of the waiting loop
			puz_mutex.unlock()
	ret = puzzles_by_diff[diff].pop_front()
	puz_mutex.unlock()
	launch_puzzle_gen(diff) # Replace the taken puzzle
	return ret

func add_puzzle(puz: PuzzleGrid) -> void:
	puz_mutex.lock()
	puzzles_by_diff[puz.difficulty].append(puz)
	puz_mutex.unlock()
	puzzle_added.emit()
