extends RefCounted
## Supporting fire team (County Hospital, first use). GDD v3.1 §14: named members share one
## order (hold, protect, withdraw), one free order update per turn, resolved in the allied
## phase; individual casualties are recorded. State: board.team.
const MEMBERS := ["Sgt. Marsh","Cpl. Ruiz","Spc. Daniels","Pfc. Kowalski"]
const MEMBER_HP := 8
const MOVE := 4
const RANGE := 6
const SHOTS := 2
const AIM := 65
const NONE := Vector2i(-1,-1)
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT]

static func initial(cell: Vector2i) -> Dictionary:
	var members: Array = []
	for who in MEMBERS: members.append({"name":who,"hp":MEMBER_HP,"status":"active"})
	return {"cell":cell,"order":"hold","hold":cell,"group":-1,"out":false,"ordered_phase":-1,"members":members,"log":[]}

static func standing(team: Dictionary) -> int:
	var count := 0
	for member in team["members"]: count += 1 if member["status"] == "active" else 0
	return count

static func present(team: Dictionary) -> bool:
	return not team["out"] and standing(team) > 0

## One free order update per player turn.
static func order(team: Dictionary, phase: int, kind: String, cell: Vector2i, group: int) -> String:
	if not present(team): return "Guard Team Marsh isn't on the field."
	if team["ordered_phase"] == phase: return "Guard Team Marsh already has its order this turn."
	team["ordered_phase"] = phase
	team["order"] = kind
	match kind:
		"hold":
			team["hold"] = cell
			return "Guard Team Marsh: hold at (%d,%d), engage within %d." % [cell.x,cell.y,RANGE]
		"protect":
			team["group"] = group
			return "Guard Team Marsh: protect the group, follow at one square."
	return "Guard Team Marsh: withdraw to the exit."

static func damage(team: Dictionary, amount: int) -> String:
	for member in team["members"]:
		if member["status"] != "active": continue
		member["hp"] = maxi(0,member["hp"]-amount)
		if member["hp"] == 0:
			member["status"] = "dead"
			team["log"].append("dead:%s" % member["name"])
			return "%s is killed" % member["name"]
		return "%s -%d HP" % [member["name"],amount]
	return "nobody left standing"

## The allied phase: move per order, then fire on Reptilians in sight.
static func act(team: Dictionary, board) -> String:
	if not present(team): return ""
	var goal: Vector2i = team["hold"]
	match team["order"]:
		"protect":
			var cohort: Dictionary = board.cohorts[team["group"]] if team["group"] >= 0 else {}
			goal = cohort["cell"] if not cohort.is_empty() and cohort["status"] == "active" else team["cell"]
		"withdraw":
			goal = board.civilian_exit()
	var report: Array[String] = []
	var path: Array[Vector2i] = path_to(team["cell"],goal,board)
	if team["order"] != "withdraw" and not path.is_empty() and path.back() == goal and (board.cohort_at(goal) >= 0 or board.soldier_at(goal) >= 0): path.pop_back()
	if team["order"] != "hold" or team["cell"] != goal:
		if path.is_empty() and team["cell"] != goal and distance(team["cell"],goal) > 1: report.append("Guard Team Marsh reports the route blocked and holds.")
		for index in range(mini(MOVE,path.size())): team["cell"] = path[index]
	if team["order"] == "withdraw" and team["cell"] == board.civilian_exit():
		team["out"] = true
		return "Guard Team Marsh withdraws through the exit, %d standing." % standing(team)
	var shots := 0
	for entry in board.reptilian_targets():
		while shots < mini(SHOTS,standing(team)) and entry["hp"] > 0:
			var info: Dictionary = board.sight_preview(team["cell"],entry["cell"])
			if not info["clear"] or info["distance"] > RANGE: break
			shots += 1
			if board.shot_rng.randi_range(1,100) <= AIM: report.append("Guard Team Marsh: " + board.hit_reptilian(entry))
			else: report.append("Guard Team Marsh fires and misses.")
	return " ".join(report)

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

static func path_to(start: Vector2i, goal: Vector2i, board) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if start == goal: return result
	var frontier: Array[Vector2i] = [start]
	var previous := {start:start}
	var cursor := 0
	while cursor < frontier.size():
		var current: Vector2i = frontier[cursor]
		cursor += 1
		if current == goal:
			while current != start:
				result.push_front(current)
				current = previous[current]
			return result
		for direction in DIRECTIONS:
			var next: Vector2i = current+direction
			if previous.has(next) or not board.cell_is_in_bounds(next) or board.WALL_CELLS.has(next) or board.FIXTURES.has(next): continue
			if next != goal and (board.soldier_at(next) >= 0 or board.cohort_at(next) >= 0 or board.blocked_for_team(next)): continue
			previous[next] = current
			frontier.append(next)
	return result
