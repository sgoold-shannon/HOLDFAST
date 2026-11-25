extends RefCounted
## Fallow cutter and coordination node (Main Street). GDD v3.1 §06: readable units,
## killable individually, a node that strengthens nearby units and can't stop the wider
## phenomenon. §20 tells: a marked zone threatens movement (gravity effect) and a visible
## node strengthens nearby units (coordination link). Signaled entry; no invisible spawns.
## State is one dictionary on the board (board.fallow). Balance numbers live here.
const SIGNAL_ROUND := 3        # distortion shown at the end of this round
const ENTRY_ROUND := 4         # cutter and node arrive at the start of this round's Fallow phase
const CUTTER_HP := 12
const CUTTER_MOVE := 2
const STRIP_WITH_NODE := 4     # squares marked per strip while the node is linked
const STRIP_WITHOUT_NODE := 2
const RIFT_DAMAGE := 4
const RIFT_CROWD_DAMAGE := 2    # civilian groups are thrown clear hurt, not wiped out
const SHOT_DAMAGE := 4
const EXIT_MARGIN := 3          # marks stop this many columns short of the east edge
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT]

static func initial(entry: Vector2i, node: Vector2i) -> Dictionary:
	return {"stage":"waiting","entry":entry,"node":node,"cutter":{"cell":entry,"hp":CUTTER_HP},
		"marked":[],"rifts":[],"interrupted":false,"interrupts":0,"log":[]}

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

static func cutter_alive(fallow: Dictionary) -> bool:
	return fallow["stage"] == "active" and fallow["cutter"]["hp"] > 0

static func node_present(fallow: Dictionary) -> bool:
	return fallow["stage"] == "active"

## 0 = cutter, 1 = node, -1 = nothing Fallow at that square.
static func unit_at(fallow: Dictionary, cell: Vector2i) -> int:
	if cutter_alive(fallow) and fallow["cutter"]["cell"] == cell: return 0
	if node_present(fallow) and fallow["node"] == cell: return 1
	return -1

static func threat_cells(fallow: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if fallow["stage"] == "waiting": return cells
	if cutter_alive(fallow): cells.append(fallow["cutter"]["cell"])
	for cell in fallow["marked"]: cells.append(cell)
	return cells

## A soldier next to the node (or any hit on it) interrupts it: the cutter skips its next transform.
static func interrupt(fallow: Dictionary) -> String:
	if not node_present(fallow): return "No node to interrupt."
	if fallow["interrupted"]: return "The node is already interrupted this turn."
	fallow["interrupted"] = true
	fallow["interrupts"] += 1
	return "Node interrupted: the cutter loses its link and skips its next transform. It's buying one turn, not a win."

static func take_hit(fallow: Dictionary, index: int, damage: int) -> String:
	if index == 1: return "Hit on the node. " + interrupt(fallow)
	var cutter: Dictionary = fallow["cutter"]
	cutter["hp"] = maxi(0,cutter["hp"]-damage)
	if cutter["hp"] == 0:
		fallow["marked"] = []
		fallow["log"].append("cutter_down")
		return "Cutter hit for %d. It folds and goes still. The rift ground stays." % damage
	return "Cutter hit for %d (%d HP left)." % [damage,cutter["hp"]]

## The Fallow phase. `board` supplies people, bounds, walls and damage.
static func act(fallow: Dictionary, board) -> String:
	var phase: int = board.phase
	if fallow["stage"] == "waiting":
		if phase >= SIGNAL_ROUND:
			fallow["stage"] = "signaled"
			return "A vertical distortion opens at the north-east end of the alley (%d,%d). Something is coming through." % [fallow["entry"].x,fallow["entry"].y]
		return ""
	if fallow["stage"] == "signaled":
		if phase < ENTRY_ROUND: return "The distortion at (%d,%d) is widening." % [fallow["entry"].x,fallow["entry"].y]
		fallow["stage"] = "active"
		fallow["log"].append("arrived:%d" % phase)
		var line := "A Fallow cutter steps out of the distortion. A coordination node anchors beside it."
		return line+" "+mark(fallow,board)
	var report: Array[String] = []
	if not cutter_alive(fallow): return "The cutter is still. The node hums at (%d,%d); the rift ground stays." % [fallow["node"].x,fallow["node"].y]
	# 1. Transform what was marked last time, unless the node was interrupted.
	if fallow["interrupted"]:
		fallow["interrupted"] = false
		report.append("The cutter hesitates without its link; the marked strip holds for now.")
	elif not fallow["marked"].is_empty():
		report.append(transform(fallow,board))
	# 2. Advance and mark again (an interrupted turn keeps the old strip marked).
	if fallow["marked"].is_empty():
		advance(fallow,board)
		report.append(mark(fallow,board))
	return " ".join(report)

static func transform(fallow: Dictionary, board) -> String:
	var hurt: Array[String] = []
	for cell in fallow["marked"]:
		if not fallow["rifts"].has(cell): fallow["rifts"].append(cell)
		board.add_rift(cell)
		if board.soldier_at(cell) >= 0 or board.cohort_at(cell) >= 0:
			hurt.append(board.apply_casualty_damage(cell,RIFT_DAMAGE if board.soldier_at(cell) >= 0 else RIFT_CROWD_DAMAGE))
			board.throw_clear(cell)
	var count: int = fallow["marked"].size()
	fallow["marked"] = []
	board.rebuild_movement()
	return "The marked ground folds into rift (%d squares)%s." % [count,"" if hurt.is_empty() else ": " + "; ".join(hurt)]

## Mark a straight strip across the path of the civilian group nearest the exit.
static func mark(fallow: Dictionary, board) -> String:
	var length := STRIP_WITH_NODE if node_present(fallow) else STRIP_WITHOUT_NODE
	var leader := -1
	var best := 1000
	var exit_cell: Vector2i = board.civilian_exit()
	for index in range(board.cohorts.size()):
		var cohort: Dictionary = board.cohorts[index]
		if cohort["status"] != "active": continue
		var gap := distance(cohort["cell"],exit_cell)
		if gap < best:
			best = gap
			leader = index
	if leader < 0: return "The cutter turns slowly, finding nothing to cut."
	var origin: Vector2i = board.cohorts[leader]["cell"]
	# Two columns ahead of the group, toward its exit, never on the last columns by the exit.
	var ahead := 1 if exit_cell.x >= origin.x else -1
	var column := mini(origin.x+2,board.GRID_SIZE.x-EXIT_MARGIN) if ahead > 0 else maxi(origin.x-2,1+EXIT_MARGIN)
	var cells: Array = []
	for offset in [0,-1,1,-2,2,-3,3]:
		if cells.size() >= length: break
		var cell := Vector2i(column,origin.y+offset)
		if not board.cell_is_in_bounds(cell) or board.WALL_CELLS.has(cell) or board.FIXTURES.has(cell) or board.sheltered_from_fallow(cell): continue
		cells.append(cell)
	fallow["marked"] = cells
	if cells.is_empty(): return "The cutter can't find open ground ahead of group %s." % board.cohorts[leader]["id"]
	return "The cutter marks %d squares across group %s's path. They turn to rift next Fallow turn." % [cells.size(),board.cohorts[leader]["id"]]

static func advance(fallow: Dictionary, board) -> void:
	var cutter: Dictionary = fallow["cutter"]
	var goal := Vector2i(-1,-1)
	var best := 1000
	for cohort in board.cohorts:
		if cohort["status"] != "active": continue
		var gap := distance(cohort["cell"],cutter["cell"])
		if gap < best:
			best = gap
			goal = cohort["cell"]
	if goal == Vector2i(-1,-1): return
	for step in range(CUTTER_MOVE):
		var next: Vector2i = cutter["cell"]
		var next_gap := distance(next,goal)
		for direction in DIRECTIONS:
			var candidate: Vector2i = cutter["cell"]+direction
			if not board.cell_is_in_bounds(candidate) or board.WALL_CELLS.has(candidate) or board.FIXTURES.has(candidate): continue
			if board.soldier_at(candidate) >= 0 or board.cohort_at(candidate) >= 0 or candidate == fallow["node"] or board.target_at(candidate) >= 0: continue
			if distance(candidate,goal) < next_gap:
				next = candidate
				next_gap = distance(candidate,goal)
		if next == cutter["cell"] or next_gap <= 1:
			cutter["cell"] = next
			break
		cutter["cell"] = next
