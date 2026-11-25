extends RefCounted
## Reptilian breach team (County Hospital). GDD v3.1 §05/§20: predatory, harvest people;
## sonic attack marks a cone before it disrupts. They go for the slowest civilians first.
## State is one plain dictionary on the board (board.reptilians).
const TROOPER_HP := 10
const ARMOR_DAMAGE := 3          # rifle hits on armor
const MOVE := 3
const STRIKE := 4                # a soldier or team member standing in their way
const CONE_LENGTH := 4
const EARLY_BREACH := 5          # gate opened by the infiltrator
const LATE_BREACH := 7           # cut in the hard way
const NONE := Vector2i(-1,-1)
const DIRECTIONS: Array[Vector2i] = [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP]

static func initial() -> Dictionary:
	return {"arrival":LATE_BREACH,"arrived":false,"units":[],"cone":[],"stunned":[],"taken":[],"log":[]}

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

static func unit_at(team: Dictionary, cell: Vector2i) -> int:
	for index in range(team["units"].size()):
		if team["units"][index]["hp"] > 0 and team["units"][index]["cell"] == cell: return index
	return -1

static func active(team: Dictionary) -> bool:
	for entry in team["units"]:
		if entry["hp"] > 0: return true
	return false

static func threat_cells(team: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for entry in team["units"]:
		if entry["hp"] > 0: cells.append(entry["cell"])
	cells.append_array(team["cone"])
	return cells

static func take_hit(team: Dictionary, index: int) -> String:
	var entry: Dictionary = team["units"][index]
	entry["hp"] = maxi(0,entry["hp"]-ARMOR_DAMAGE)
	if entry["hp"] == 0:
		team["log"].append("trooper_down")
		if not active(team): team["cone"] = []
		return "Reptilian trooper hit for %d through the armor. It drops." % ARMOR_DAMAGE
	return "Reptilian trooper hit for %d through the armor (%d HP left)." % [ARMOR_DAMAGE,entry["hp"]]

## The Reptilian phase.
static func act(team: Dictionary, board) -> String:
	var phase: int = board.phase
	if not team["arrived"]:
		if phase < team["arrival"]-1: return ""
		team["arrived"] = true
		for cell in [board.GATE+Vector2i(0,1),board.GATE+Vector2i(1,1)]:
			team["units"].append({"cell":cell,"hp":TROOPER_HP})
		team["log"].append("arrived:%d" % (phase+1))
		return "Armored figures come through the north fence gate. Two Reptilian troopers."
	if not active(team): return ""
	var report: Array[String] = []
	# 1. The cone marked last phase goes off.
	team["stunned"] = []
	if not team["cone"].is_empty():
		var hit: Array[String] = []
		for index in range(board.soldiers.size()):
			if board.soldier_can_act(index) and team["cone"].has(board.soldiers[index]["cell"]):
				team["stunned"].append(index)
				hit.append(board.soldiers[index]["name"])
		for cohort in board.cohorts:
			if cohort["status"] == "active" and team["cone"].has(cohort["cell"]):
				cohort["panic"] = 2
				hit.append("group " + cohort["id"])
		report.append("Sonic burst: %s." % (", ".join(hit) + " disrupted" if not hit.is_empty() else "nobody in it"))
		team["cone"] = []
	# 2. Harvest an adjacent group, otherwise close on the slowest one.
	for entry in team["units"]:
		if entry["hp"] <= 0: continue
		var grabbed := adjacent_group(entry,board)
		if grabbed >= 0:
			var cohort: Dictionary = board.cohorts[grabbed]
			cohort["status"] = "taken"
			cohort["note"] = "Taken by the Reptilian team. Names on record."
			team["taken"].append(cohort["id"])
			team["log"].append("taken:%s" % cohort["id"])
			report.append("A trooper drags group %s toward the fence. Four people taken." % cohort["id"])
			continue
		var goal := prey(entry,board)
		if goal == NONE: continue
		step_toward(entry,goal,board)
		var blocker := blocking_soldier(entry,board)
		if blocker != "": report.append(blocker)
	# 3. Mark the next cone from the first standing trooper.
	for entry in team["units"]:
		if entry["hp"] <= 0: continue
		team["cone"] = cone(entry,board)
		if not team["cone"].is_empty(): report.append("A trooper's throat-plates flare: sonic cone marked for next phase.")
		break
	return " ".join(report).strip_edges()

static func adjacent_group(entry: Dictionary, board) -> int:
	for index in range(board.cohorts.size()):
		var cohort: Dictionary = board.cohorts[index]
		if cohort["status"] == "active" and distance(cohort["cell"],entry["cell"]) == 1: return index
	return -1

## Slowest first: gurneys, then whoever is nearest.
static func prey(entry: Dictionary, board) -> Vector2i:
	var best := NONE
	var best_score := 100000
	for cohort in board.cohorts:
		if cohort["status"] != "active": continue
		var score := distance(cohort["cell"],entry["cell"]) - (20 if cohort.get("gurneys",false) else 0)
		if score < best_score:
			best_score = score
			best = cohort["cell"]
	return best

static func step_toward(entry: Dictionary, goal: Vector2i, board) -> void:
	for step in range(MOVE):
		if distance(entry["cell"],goal) <= 1: return
		var next: Vector2i = entry["cell"]
		for direction in DIRECTIONS:
			var candidate: Vector2i = entry["cell"]+direction
			if not board.cell_is_in_bounds(candidate) or board.WALL_CELLS.has(candidate) or board.FIXTURES.has(candidate): continue
			if board.soldier_at(candidate) >= 0 or board.cohort_at(candidate) >= 0 or board.target_at(candidate) >= 0: continue
			if distance(candidate,goal) < distance(next,goal): next = candidate
		if next == entry["cell"]: return
		entry["cell"] = next

## A soldier or the fire team standing right in a trooper's way takes a blow.
static func blocking_soldier(entry: Dictionary, board) -> String:
	for direction in DIRECTIONS:
		var cell: Vector2i = entry["cell"]+direction
		if board.soldier_at(cell) >= 0:
			return "A trooper shoves through: %s." % board.apply_casualty_damage(cell,STRIKE)
		if board.team_at(cell):
			return "A trooper slams into Guard Team Marsh: %s." % board.damage_team(STRIKE)
	return ""

## 4 long, 3 wide, pointed at the nearest person.
static func cone(entry: Dictionary, board) -> Array:
	var target := NONE
	var best := 1000
	for soldier in board.soldiers:
		if soldier["extracted"] or soldier["hp"] <= 0: continue
		var gap := distance(soldier["cell"],entry["cell"])
		if gap < best:
			best = gap
			target = soldier["cell"]
	for cohort in board.cohorts:
		if cohort["status"] != "active": continue
		var gap := distance(cohort["cell"],entry["cell"])
		if gap < best:
			best = gap
			target = cohort["cell"]
	if target == NONE: return []
	var delta: Vector2i = target-entry["cell"]
	var forward := Vector2i(signi(delta.x),0) if absi(delta.x) >= absi(delta.y) else Vector2i(0,signi(delta.y))
	if forward == Vector2i.ZERO: forward = Vector2i.DOWN
	var side := Vector2i(forward.y,forward.x)
	var cells: Array = []
	for step in range(1,CONE_LENGTH+1):
		for offset in [-1,0,1]:
			var cell: Vector2i = entry["cell"]+forward*step+side*offset
			if board.cell_is_in_bounds(cell) and not board.WALL_CELLS.has(cell): cells.append(cell)
	return cells
