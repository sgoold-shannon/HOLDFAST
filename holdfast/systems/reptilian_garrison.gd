extends RefCounted
## Reptilian garrison (Civic Center). GDD v3.1 §05: after their extraction facility fails they
## split: an extraction faction moves captives out, a territorial faction entrenches. Before the
## alarm they patrol, hidden until seen or scouted. After it, territorial troopers hold, aim a
## turn ahead and shoot cover away; extraction troopers load detainees out through a tunnel.
## State: board.garrison.
const TROOPER_HP := 10
const ARMOR_DAMAGE := 3
const SPOT_RANGE := 3            # hidden until a soldier is this close (or scouted)
const SCOUT_RANGE := 6
const FIRE_RANGE := 5
const AIM := 65
const DAMAGE := 4
const MOVE := 3
const LOAD_PHASES := 3
const ALARM_ROUND := 5
const ALARM_ROUND_LEAKED := 3
const NONE := Vector2i(-1,-1)
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT]

static func initial(cells: Array, leaked: bool) -> Dictionary:
	var units: Array = []
	for cell in cells: units.append({"cell":cell,"hp":TROOPER_HP,"faction":"","seen":false,"last_seen":NONE,"aim":{}})
	return {"units":units,"alarm":false,"alarm_round":ALARM_ROUND_LEAKED if leaked else ALARM_ROUND,"alarm_cause":"",
		"load":0,"moved_out":[],"taken":[],"cover_lost":0,"log":[]}

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

static func unit_at(garrison: Dictionary, cell: Vector2i) -> int:
	for index in range(garrison["units"].size()):
		if garrison["units"][index]["hp"] > 0 and garrison["units"][index]["cell"] == cell: return index
	return -1

static func visible(entry: Dictionary, board) -> bool:
	if entry["hp"] <= 0: return false
	if entry["seen"]: return true
	for index in range(board.soldiers.size()):
		if board.soldier_can_act(index) and distance(board.soldiers[index]["cell"],entry["cell"]) <= SPOT_RANGE: return true
	return false

## Refresh sightings: what's visible now is seen; last-known markers stay where they were seen.
static func update_sightings(garrison: Dictionary, board) -> void:
	for entry in garrison["units"]:
		if visible(entry,board): entry["last_seen"] = entry["cell"]

static func scout(garrison: Dictionary, from: Vector2i) -> int:
	var found := 0
	for entry in garrison["units"]:
		if entry["hp"] > 0 and distance(entry["cell"],from) <= SCOUT_RANGE:
			if not entry["seen"]: found += 1
			entry["seen"] = true
			entry["last_seen"] = entry["cell"]
	return found

static func raise_alarm(garrison: Dictionary, cause: String, board) -> String:
	if garrison["alarm"]: return ""
	garrison["alarm"] = true
	garrison["alarm_cause"] = cause
	garrison["log"].append("alarm:%d:%s" % [board.phase,cause])
	# The split: the two nearest the holding facility become the extraction faction.
	var order: Array = []
	for index in range(garrison["units"].size()):
		if garrison["units"][index]["hp"] > 0: order.append(index)
	order.sort_custom(func(a,b): return distance(garrison["units"][a]["cell"],board.PEN) < distance(garrison["units"][b]["cell"],board.PEN))
	for rank in range(order.size()):
		var entry: Dictionary = garrison["units"][order[rank]]
		entry["faction"] = "extraction" if rank < 2 else "territorial"
		entry["seen"] = true
		entry["last_seen"] = entry["cell"]
	return "ALARM (%s). The garrison splits: two troopers make for the holding facility to move the detainees out; the rest dig in." % cause

static func take_hit(garrison: Dictionary, index: int) -> String:
	var entry: Dictionary = garrison["units"][index]
	entry["hp"] = maxi(0,entry["hp"]-ARMOR_DAMAGE)
	entry["seen"] = true
	if entry["faction"] == "extraction": garrison["load"] = 0
	if entry["hp"] == 0:
		entry["aim"] = {}
		garrison["log"].append("down:%s" % (entry["faction"] if entry["faction"] != "" else "patrol"))
		return "Reptilian trooper hit for %d through the armor. It drops." % ARMOR_DAMAGE
	return "Reptilian trooper hit for %d through the armor (%d HP left)%s." % [ARMOR_DAMAGE,entry["hp"]," and its load breaks off" if entry["faction"] == "extraction" else ""]

## The Reptilian phase.
static func act(garrison: Dictionary, board) -> String:
	var phase: int = board.phase
	var report: Array[String] = []
	if not garrison["alarm"] and phase >= garrison["alarm_round"]-1:
		report.append(raise_alarm(garrison,"schedule" if phase >= ALARM_ROUND-1 else "leak",board))
	for entry in garrison["units"]:
		if entry["hp"] <= 0: continue
		var grabbed := adjacent_group(entry,board)
		if grabbed >= 0:
			var cohort: Dictionary = board.cohorts[grabbed]
			cohort["status"] = "taken"
			cohort["note"] = "Taken by the Reptilian garrison. Names on record."
			garrison["taken"].append(cohort["id"])
			report.append("A trooper drags group %s off. Four people taken." % cohort["id"])
			continue
		if not garrison["alarm"]: continue
		if entry["faction"] == "territorial":
			if not entry["aim"].is_empty(): report.append(fire(entry,board))
			entry["aim"] = {}
			var target := aim_target(entry,board)
			if target >= 0:
				entry["aim"] = {"cell":board.soldiers[target]["cell"],"soldier":target}
				report.append("An entrenched trooper aims at %s." % board.soldiers[target]["name"])
			var edge: Vector2i = board.cover_in_sight(entry["cell"])
			if edge != NONE:
				board.destroy_cover(edge)
				garrison["cover_lost"] += 1
				report.append("A trooper blasts the cover at (%d,%d) away." % [edge.x,edge.y])
		else:
			report.append(extraction_step(garrison,entry,board))
	return " ".join(report).strip_edges()

static func extraction_step(garrison: Dictionary, entry: Dictionary, board) -> String:
	var cohort: Dictionary = board.cohorts[board.PEN_GROUP]
	if cohort["status"] != "active" or not cohort.get("penned",false): return ""
	if distance(entry["cell"],board.PEN) > 1:
		step_toward(entry,board.PEN,board)
		return "Extraction troopers move on the holding facility."
	if garrison.get("load_phase",-1) == board.phase: return ""
	garrison["load_phase"] = board.phase
	garrison["load"] += 1
	if garrison["load"] < LOAD_PHASES: return "Troopers are moving the detainees toward the tunnel. Hit one to break it."
	garrison["load"] = 0
	cohort["status"] = "taken"
	cohort["penned"] = false
	cohort["note"] = "Moved out through the tunnel by the extraction faction. Named; unresolved."
	garrison["moved_out"].append(cohort["id"])
	garrison["log"].append("moved_out:%s" % cohort["id"])
	return "The detainees are gone down the tunnel. Group %s moved out." % cohort["id"]

static func adjacent_group(entry: Dictionary, board) -> int:
	for index in range(board.cohorts.size()):
		var cohort: Dictionary = board.cohorts[index]
		if cohort["status"] == "active" and not cohort.get("penned",false) and distance(cohort["cell"],entry["cell"]) == 1: return index
	return -1

static func aim_target(entry: Dictionary, board) -> int:
	var best := -1
	var nearest := 1000
	for index in range(board.soldiers.size()):
		if not board.soldier_can_act(index): continue
		var info: Dictionary = board.sight_preview(entry["cell"],board.soldiers[index]["cell"])
		if info["clear"] and info["distance"] <= FIRE_RANGE and info["distance"] < nearest:
			nearest = info["distance"]
			best = index
	return best

static func fire(entry: Dictionary, board) -> String:
	var aim_cell: Vector2i = entry["aim"]["cell"]
	board.round_noise.append(entry["cell"])
	if board.soldier_at(aim_cell) < 0: return "A trooper fires at (%d,%d): nobody there now." % [aim_cell.x,aim_cell.y]
	var info: Dictionary = board.sight_preview(entry["cell"],aim_cell)
	if not info["can_fire"]: return "A trooper loses the shot."
	var chance := clampi(int(info["chance"])-(75-AIM),5,95)
	if board.shot_rng.randi_range(1,100) > chance: return "A trooper fires (%d%%) and misses." % chance
	return "A trooper fires (%d%%): %s." % [chance,board.apply_casualty_damage(aim_cell,DAMAGE)]

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
