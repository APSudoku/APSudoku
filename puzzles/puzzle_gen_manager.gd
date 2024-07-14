extends Node
#Autoload 'PuzzleGenManager'

const PUZZLES_TO_KEEP := 10

var running: bool = true
class PuzzleData:
	var diff: PuzzleGrid.Difficulty
	var puzzles: Array[PuzzleGrid] = []
	var threads: Array[Thread] = []
	var gen_semaphore := Semaphore.new()
	var mutex := Mutex.new()
	signal puzzle_added
	
	func _init(d: PuzzleGrid.Difficulty, count := 1):
		diff = d
		for q in count:
			threads.append(Thread.new())
		setup_puzzle_limit()
	func setup_puzzle_limit() -> void:
		for q in PuzzleGenManager.PUZZLES_TO_KEEP:
			gen_semaphore.post() # Ask for that many puzzles
			await PuzzleGenManager.get_tree().create_timer(5).timeout # Delay so all difficulties build up evenly at the start
	func start() -> void:
		var prio := Thread.PRIORITY_LOW
		match diff:
			PuzzleGrid.Difficulty.HARD, PuzzleGrid.Difficulty.KILLER:
				prio = Thread.PRIORITY_HIGH
		for q in threads.size():
			threads[q].start(thread_proc, prio)
	func thread_proc() -> void:
		gen_semaphore.wait()
		while PuzzleGenManager.running:
			add_puzzle(PuzzleGrid.new(diff))
			gen_semaphore.wait()
	func add_puzzle(puz: PuzzleGrid) -> void:
		if not PuzzleGenManager.running: return
		mutex.lock()
		puzzles.append(puz)
		#print(PuzzleGrid.Difficulty.find_key(diff), ": ", puzzles.size())
		mutex.unlock()
		_on_add_puzzle.call_deferred()
	func _on_add_puzzle() -> void:
		puzzle_added.emit()
var puzzle_datas: Array[PuzzleData] = []

func _cleanup_threads() -> void:
	running = false
	# Queue all the threads to run, so they can exit after detecting `running == false`
	for data in puzzle_datas:
		for q in data.threads.size():
			data.gen_semaphore.post()
	# Actually wait for them all to exit (should be instant for any that were waiting prior)
	for data in puzzle_datas:
		for t in data.threads:
			t.wait_to_finish()

func _ready():
	var thread_counts: Array[int] = [1,1,3,3]
	for d in PuzzleGrid.Difficulty.values():
		puzzle_datas.append(PuzzleData.new(d, thread_counts[d]))
		puzzle_datas.back().start()

func get_puzzle(diff: PuzzleGrid.Difficulty) -> PuzzleGrid:
	var data := puzzle_datas[diff]
	data.gen_semaphore.post() # request replacement puzzle
	data.mutex.lock()
	while data.puzzles.is_empty():
		data.mutex.unlock()
		await data.puzzle_added
		data.mutex.lock()
	var ret: PuzzleGrid = data.puzzles.pop_front()
	#print(PuzzleGrid.Difficulty.find_key(data.diff), ": ", data.puzzles.size())
	data.mutex.unlock()
	return ret

func _exit_tree():
	_cleanup_threads()
