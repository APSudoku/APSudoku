class_name PuzzleGrid extends Resource
enum Difficulty {
	EASY, MEDIUM, HARD, KILLER
}

var difficulty: Difficulty
var solutions: Array[int] = []
var givens: Array[bool] = []
var cages: Array[PuzzleCage] = []

func _init(diff: Difficulty, priority: bool = false):
	solutions.resize(81)
	givens.resize(81)
	difficulty = diff
	var grid := GenGrid.new(diff)
	grid._priority_gen = priority
	if not (grid.generate() and PuzzleGenManager.running):
		return
	var q := 0
	for c in grid.cells:
		givens[q] = c.given
		solutions[q] = c.sol
		q += 1
	cages.assign(grid.cages)

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
	class GenCell:
		var parent_grid: GenGrid
		var index: int = -1

		var sol: int = 0
		var val: int = 0
		var given: bool = false
		var options: Array[int]
		var cage: PuzzleCage
		func _init(parent: GenGrid, ind: int):
			parent_grid = parent
			index = ind
			clear()
		func clear():
			sol = 0
			val = 0
			given = false
			reset_options()
		func reset_options() -> void:
			options = [1,2,3,4,5,6,7,8,9]
		func duplicate(parent: GenGrid) -> GenCell:
			var other := GenCell.new(parent, index)
			other.sol = sol
			other.val = val
			other.given = given
			other.options.assign(options)
			return other
		func _to_string():
			return "%d [%d]%s %s" % [val,sol," Given" if given else "",options]
		func top() -> GenCell:
			if index - 9 < 0: return null
			return parent_grid.cells[index-9]
		func bottom() -> GenCell:
			if index + 9 >= 81: return null
			return parent_grid.cells[index+9]
		func left() -> GenCell:
			if index % 9 == 0: return null
			return parent_grid.cells[index-1]
		func right() -> GenCell:
			if index % 9 == 8: return null
			return parent_grid.cells[index+1]
	class GridFillHistory:
		var ind := 0
		var checked: Dictionary ## of Array[int]
		func _to_string():
			return "%d,%s" % [ind,checked]
	class GridGivenHistory:
		var ind := 0
		var built_cages := 0
		var checked: Array[int] = []

	var _priority_gen: bool = false
	var diff: Difficulty
	var cells: Array[GenCell] = []
	var cages: Array[PuzzleCage] = []
	func _init(d: Difficulty):
		diff = d
		for q in 81:
			cells.append(GenCell.new(self, q))
	func clear() -> void:
		for c in cells:
			c.clear()
	func generate() -> bool:
		if not populate(): return false
		return build()
	func duplicate() -> GenGrid:
		var other = GenGrid.new(diff)
		for q in 81:
			other.cells[q] = cells[q].duplicate(other)
		return other

	func is_unique() -> bool:
		var copy := duplicate()
		for c in copy.cells:
			if not c.given:
				c.val = 0
		throttle()
		return copy.solve(true)

	class GenOptions:
		var cells: Array[int]
		var entropy: int
	func trim_opts(banned: Dictionary) -> GenOptions:
		# banned[cell index] -> Array[int] of banned values for that index
		var killer := false
		for ind in 81:
			if not (PuzzleGenManager and PuzzleGenManager.check_running()): return null
			if cells[ind].val:
				cells[ind].options.clear()
				continue # Skip filled cells
			# Start by assuming all valid digits are options
			cells[ind].reset_options()
			# Remove options that failed trial-and-error
			for val in banned.get(ind, []):
				cells[ind].options.erase(val)

			# Build a list of 'neighbors', the cells that 'see' this cell
			var col: int = ind%9;
			var row: int = floor(ind/9.0);
			var box: int = 3*floor(row/3.0)+floor(col/3.0)
			var neighbors := {}
			for q in 9:
				neighbors[9*q + col] = true # same column
				neighbors[9*row + q] = true # same row
				neighbors[9*(3*floor(box/3.0) + floor(q/3.0)) + (3*(box%3) + (q%3))] = true # same box
			if cells[ind].cage:
				for c in cells[ind].cage.cells:
					neighbors[c] = true

			# values placed in neighbor cells cannot be duplicated
			for q in neighbors.keys():
				cells[ind].options.erase(cells[q].val)
		if killer:
			var didsomething := true
			while didsomething:
				didsomething = false
				for q in 81:
					var cell_q := cells[q]
					if cell_q.val: continue # filled
					var cage := cell_q.cage
					if not cage: continue # uncaged
					var target := cage.sum
					if cage.cells.size() == 1:
						# single-cell, force value as optimization
						cell_q.options.assign([target])
						continue
					var lowest := 0 # Sum of lowest possibilities, excluding [q]
					var highest := 0 # Sum of highest possibilities, excluding [q]
					for ind in cage.cells:
						if ind == q: continue
						var cell := cells[ind]
						if cell.val:
							lowest += cell.val
							highest += cell.val
						elif not cell.options.is_empty():
							lowest += cell.options.front()
							highest += cell.options.back()
					# Now use sums to eliminate possibilities
					for opt in cell_q.options.duplicate():
						if (lowest + opt > target or # Too high
							highest + opt < target): # Too low
							cell_q.options.erase(opt)
							didsomething = true
		var least_opts := {}
		var least_count := 9
		for ind in 81:
			if cells[ind].val: continue # Skip filled cells
			var sz := cells[ind].options.size()
			if sz < least_count:
				least_opts.clear()
				least_count = sz
			if sz == least_count:
				least_opts[ind] = true
			if least_count == 0:
				break # can early-return, as a 0 count indicates failure regardless
		var ret := GenOptions.new()
		ret.cells.assign(least_opts.keys())
		ret.entropy = least_count
		return ret
	## If `check_unique` is true, the puzzle will be mangled, but the return
	##   value will represent if the puzzle had a unique solution.
	##   Else, will solve the puzzle with the first valid solution it finds, returning if it found one.
	func solve(check_unique: bool) -> bool:
		for c in cells:
			c.reset_options()
		var solved := false
		var history: Array[GridFillHistory] = [GridFillHistory.new()]
		while true:
			if not PuzzleGenManager.running: return false # Program exiting, quick exit thread
			var option_info := trim_opts(history.back().checked)
			if not option_info: return false
			var goback := option_info.entropy == 0
			if option_info.cells.is_empty(): # All cells filled
				if check_unique:
					if solved: return false
					for c in cells:
						if c.val != c.sol: # Wrong solution, we already know of another
							return false
					solved = true
					goback = true
				else: return true # Solved
			if goback: # Dead end, no solution (or found expected solution in check_unique)
				history.pop_back()
				if history.is_empty():
					break # Ran out of ALL possible moves, failed solving
				cells[history.back().ind].clear() # Undo last move
				continue
			# Wave-function collapse; pick a random lowest-entropy cell, and randomly fill it
			history.back().ind = option_info.cells.pick_random()
			var cell := cells[history.back().ind]
			cell.val = cell.options.pick_random()
			if not history.back().checked.has(history.back().ind):
				history.back().checked[history.back().ind] = [cell.val]
			else: history.back().checked[history.back().ind].append(cell.val)
			history.append(GridFillHistory.new())
		return solved
	## Fills the grid with a random valid solution
	func populate() -> bool:
		clear()
		if not solve(false): return false
		for c in cells:
			c.sol = c.val
			c.given = true
		return true
	## Trims away givens for the specified difficulty (from a populated grid)
	func build() -> bool:
		if not PuzzleGenManager.running: return false # Program exiting, quick exit thread
		var givens: Array[int] = []
		for q in 81:
			if cells[q].given:
				givens.append(q)
		var target_givens := 81
		var givens_for_cages := 0
		var killer_mode := false
		match diff:
			Difficulty.EASY:
				target_givens = 46
			Difficulty.MEDIUM:
				target_givens = 35
			Difficulty.HARD:
				target_givens = 26
			Difficulty.KILLER:
				target_givens = 26
				givens_for_cages = 26
				killer_mode = true
		if givens_for_cages < target_givens:
			givens_for_cages = target_givens

		var killer_singles: Array[int] = []
		if not target_givens: # 0-target, only possible with variant rules
			for c in cells:
				c.given = false
			if is_unique():
				return true
		else:
			var history: Array[GridGivenHistory] = [GridGivenHistory.new()]
			var backtrack := false
			while true:
				if not PuzzleGenManager.running: return false  # Program exiting, quick exit thread
				if backtrack:
					#if history.back().built_cages:
						#clear_cages()
					history.pop_back()
					if history.is_empty():
						break # Out of possibilities, no solution
					var prev: GridGivenHistory = history.back()
					if not prev.built_cages: # undo the given
						cells[prev.ind].given = true
						givens.append(prev.ind)
					backtrack = false
				var step: GridGivenHistory = history.back()
				if step.built_cages:
					if step.built_cages >= 50: # Can't find a configuration that works
						backtrack = true
						continue
					killer_singles.clear()
					if not killer_fill(): return false
					if givens.size() == target_givens:
						return true
					for cage in cages:
						if cage.cells.size() == 1:
							killer_singles.append(cage.cells.front())
					if killer_singles.size() > target_givens: # Too many givens forced by cages
						continue
					history.append(GridGivenHistory.new())
					continue
				var possible: Array[int] = []
				possible.assign(givens)
				for q in step.checked:
					possible.erase(q)
				for q in killer_singles:
					possible.erase(q)
				if possible.is_empty(): # No moves!
					backtrack = true
					continue
				step.ind = possible.pick_random()
				cells[step.ind].given =	false
				step.checked.append(step.ind)
				if not is_unique(): # Fail, retry
					cells[step.ind].given = true
					throttle()
					continue
				givens.erase(step.ind)
				history.append(GridGivenHistory.new())
				if killer_mode and givens.size() == givens_for_cages:
					history.back().built_cages += 1
				elif givens.size() == target_givens:
					return true # Success
		if killer_mode: # Killer mode just retries infinitely instead of failing
			return build()
		assert(false, "Non-variant grid found no solution") # Should be unreachable; a non-variant grid should always find a solution
		return false
	##Fills the (populated) grid with random killer cages
	func killer_fill() -> bool:
		if not PuzzleGenManager.running: return false # Program exiting, quick exit thread
		cages.clear()
		for cell in cells:
			cell.cage = null
		const LOWSZ := 2
		const HIGHSZ := 7
		var remaining: Array[int] = []
		for q in 81: remaining.append(q)
		while not remaining.is_empty():
			var cage := PuzzleCage.new()
			cages.append(cage)
			var target := randi_range(LOWSZ,HIGHSZ)
			var core: int = remaining.pick_random()
			remaining.erase(core)
			cage.cells.append(core)
			var cage_cells: Array[GenCell] = [cells[core]]
			while cage.cells.size() < target:
				var neighbors: Array[GenCell] = []
				for c in cage_cells:
					for sub_c in [c.top(),c.bottom(),c.left(),c.right()]:
						if not sub_c: continue
						if not (sub_c.index in remaining): continue
						if cage_cells.any(func(ccell): return ccell.sol == sub_c.sol):
							continue
						neighbors.append(sub_c)
				if neighbors.is_empty():
					break # Dead-end before target size
				var next: GenCell = neighbors.pick_random()
				remaining.erase(next.index)
				cage.cells.append(next.index)
				cage_cells.append(next)
			cage.sum = cage_cells.reduce(func(accum,c): return accum + c.sol, 0)
			cage.cells.sort()

		assert(cages.reduce(func(ac, cage): return ac + cage.cells.size(), 0) == 81
			and cages.reduce(func(ac, cage): return ac + cage.sum, 0) == 45*9)
		return true

	func throttle() -> void:
		assert(OS.get_thread_caller_id() != 1) # Not main thread
		var delay: int
		match diff:
			Difficulty.EASY, Difficulty.MEDIUM:
				delay = 0 if _priority_gen else 100
			Difficulty.HARD:
				delay = 0 if _priority_gen else 500
			Difficulty.KILLER:
				delay = 50 if _priority_gen else 500
		if delay:
			OS.delay_msec(delay) # Reduce CPU usage
