extends RefCounted
## The Farm Road Drive Rig, back as industrial machinery (Quarry). One free order a turn
## from MSG within range: move toward a soldier, dig adjacent debris, or brace (the squares
## next to it are safe from Fallow marks). State: board.rig.
const MOVE := 2
const VOICE := 6
const NONE := Vector2i(-1,-1)
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT]

static func initial(present: bool, cell: Vector2i) -> Dictionary:
	return {"present":present,"cell":cell,"braced":false,"ordered_phase":-1,"dug":0,"log":[]}

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

static func shelters(rig: Dictionary, cell: Vector2i) -> bool:
	return rig["present"] and rig["braced"] and distance(cell,rig["cell"]) <= 1

static func move_toward(rig: Dictionary, goal: Vector2i, board) -> int:
	rig["braced"] = false
	var moved := 0
	for step in range(MOVE):
		if distance(rig["cell"],goal) <= 1: break
		var next: Vector2i = rig["cell"]
		for direction in DIRECTIONS:
			var candidate: Vector2i = rig["cell"]+direction
			if not board.cell_is_in_bounds(candidate) or board.WALL_CELLS.has(candidate) or board.FIXTURES.has(candidate): continue
			if board.soldier_at(candidate) >= 0 or board.cohort_at(candidate) >= 0 or board.target_at(candidate) >= 0: continue
			if distance(candidate,goal) < distance(next,goal): next = candidate
		if next == rig["cell"]: break
		rig["cell"] = next
		moved += 1
	return moved
