extends RefCounted
## Grey extraction team (River Bridge). GDD v3.1 §28: extract selected specimens; escalate
## only when the squad interferes; the extraction clock beats territory. §20 tells:
## abduction shows a LIFT countdown, beam fire shows an aim line before it fires.
## State is one plain dictionary on the board (board.greys) so it saves and tests easily.
const COLLECTOR_HP := 8
const SENTRY_HP := 6
const LIFT_RANGE := 6        # Collector marks a civilian group this close
const LIFT_ROUNDS := 2       # Grey phases from mark to lift
const COLLECTOR_MOVE := 3
const SENTRY_RANGE := 8
const BEAM_DAMAGE := 4       # soldiers
const BEAM_CROWD_DAMAGE := 2 # civilian groups caught in the line
const PROVOKE_RANGE := 3     # a soldier this close to the Collector makes the Sentry hostile
const WITHDRAW_ROUND := 8    # Greys leave at the end of this round
const SHOT_DAMAGE := 4
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT]

static func initial(collector: Vector2i, sentry: Vector2i) -> Dictionary:
	return {"units":[{"kind":"collector","cell":collector,"hp":COLLECTOR_HP},{"kind":"sentry","cell":sentry,"hp":SENTRY_HP}],
		"lift":{},"aim":{},"hostile":false,"withdrawn":false,"withdraw_reason":"","shield_used":false,
		"shielded":"","taken":[],"log":[],"hardware":Vector2i(-1,-1)}

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

static func unit(greys: Dictionary, kind: String) -> Dictionary:
	for entry in greys["units"]:
		if entry["kind"] == kind and entry["hp"] > 0: return entry
	return {}

static func unit_at(greys: Dictionary, cell: Vector2i) -> int:
	if greys["withdrawn"]: return -1
	for index in range(greys["units"].size()):
		if greys["units"][index]["hp"] > 0 and greys["units"][index]["cell"] == cell: return index
	return -1

static func active(greys: Dictionary) -> bool:
	return not greys["withdrawn"] and not unit(greys,"collector").is_empty()

## Cells that scare civilians this round.
static func threat_cells(greys: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if greys["withdrawn"]: return cells
	for entry in greys["units"]:
		if entry["hp"] > 0: cells.append(entry["cell"])
	if not greys["aim"].is_empty(): cells.append(greys["aim"]["cell"])
	return cells

## A shot from the squad. Returns a status line. Any hit on the Collector breaks its lift.
static func take_hit(greys: Dictionary, index: int, damage: int) -> String:
	var target: Dictionary = greys["units"][index]
	greys["hostile"] = true
	target["hp"] = maxi(0,target["hp"]-damage)
	var name := "Collector" if target["kind"] == "collector" else "Sentry"
	var text := "%s hit for %d (%d HP left)." % [name,damage,target["hp"]]
	if target["kind"] == "collector" and not greys["lift"].is_empty():
		greys["lift"] = {}
		text += " The lift breaks off."
	if target["hp"] == 0:
		text += " %s down." % name
		if target["kind"] == "collector": withdraw(greys,"Collector down: the team abandons the site",target["cell"])
	return text

static func withdraw(greys: Dictionary, reason: String, hardware: Vector2i) -> void:
	if greys["withdrawn"]: return
	greys["withdrawn"] = true
	greys["withdraw_reason"] = reason
	greys["lift"] = {}
	greys["aim"] = {}
	greys["hardware"] = hardware
	greys["log"].append(reason)

## The Grey phase. `board` supplies people, sight, walkability and damage.
## Returns a one-line report for the enemy message.
static func act(greys: Dictionary, board) -> String:
	if greys["withdrawn"]: return "Grey team gone. They left cheap hardware behind."
	var report: Array[String] = []
	var collector := unit(greys,"collector")
	var sentry := unit(greys,"sentry")
	if board.phase > greys.get("shielded_until",0): greys["shielded"] = ""
	# Escalation: a soldier crowding the Collector.
	if not collector.is_empty():
		for index in range(board.soldiers.size()):
			if board.soldier_can_act(index) and distance(board.soldiers[index]["cell"],collector["cell"]) <= PROVOKE_RANGE:
				if not greys["hostile"]: report.append("The Sentry turns on the squad.")
				greys["hostile"] = true
	# 1. Sentry fires a beam it aimed last phase.
	if not sentry.is_empty() and not greys["aim"].is_empty():
		report.append(fire_beam(greys,sentry,board))
	greys["aim"] = {}
	# 2. Collector: continue or start a lift, otherwise close in.
	if not collector.is_empty():
		report.append(lift_step(greys,collector,board))
	# 3. Sentry keeps near the Collector and, once hostile, aims at a soldier.
	if not sentry.is_empty():
		if not collector.is_empty() and distance(sentry["cell"],collector["cell"]) > 2:
			step_toward(greys,sentry,collector["cell"],1,board)
		if greys["hostile"]:
			var target := aim_target(sentry,board)
			if target >= 0:
				greys["aim"] = {"cell":board.soldiers[target]["cell"],"soldier":target}
				report.append("Sentry aims at %s: move off the line." % board.soldiers[target]["name"])
	# 4. Extraction clock.
	if board.phase >= WITHDRAW_ROUND:
		withdraw(greys,"Extraction window closed: the Grey team lifts out",collector.get("cell",Vector2i(-1,-1)))
		report.append("The Grey team lifts out with its tagged cargo.")
	var line := " ".join(report).strip_edges()
	return line if line != "" else "Grey team working the far bank."

static func fire_beam(greys: Dictionary, sentry: Dictionary, board) -> String:
	var aim_cell: Vector2i = greys["aim"]["cell"]
	var info: Dictionary = board.sight_preview(sentry["cell"],aim_cell)
	if not info["clear"]: return "The beam scorches the wall."
	for cell in info["cells"]:
		if cell == sentry["cell"]: continue
		if board.soldier_at(cell) >= 0 or board.cohort_at(cell) >= 0:
			var amount := BEAM_DAMAGE if board.soldier_at(cell) >= 0 else BEAM_CROWD_DAMAGE
			return "Beam hits at (%d,%d): %s." % [cell.x,cell.y,board.apply_casualty_damage(cell,amount)]
		if cell == aim_cell: break
	return "The beam cuts empty ground."

static func lift_step(greys: Dictionary, collector: Dictionary, board) -> String:
	var lift: Dictionary = greys["lift"]
	if not lift.is_empty():
		var group: int = lift["group"]
		var cohort: Dictionary = board.cohorts[group]
		# GDD §20: interrupt the emitter or reach shelter. Distance alone doesn't break a lock.
		if cohort["status"] != "active" or board.sheltered(cohort["cell"]):
			greys["lift"] = {}
			return "Lift on group %s broken: they reached shelter." % cohort["id"]
		lift["count"] -= 1
		if lift["count"] > 0:
			return "LIFT on group %s: %d more Grey phase." % [cohort["id"],lift["count"]]
		greys["lift"] = {}
		if not greys["shield_used"]:
			greys["shield_used"] = true
			greys["shielded"] = cohort["id"]
			greys["shielded_until"] = board.phase+1
			greys["log"].append("craft_shield:%s" % cohort["id"])
			return "An unidentified craft drops over group %s and spends its shield. The lift fails; the craft limps east, trailing smoke." % cohort["id"]
		cohort["status"] = "taken"
		cohort["note"] = "Taken by the Grey team. Names on record; fate unresolved."
		greys["taken"].append(cohort["id"])
		greys["log"].append("taken:%s" % cohort["id"])
		return "Group %s is lifted. Four people taken." % cohort["id"]
	# Pick the nearest civilian group in reach; captives come first.
	var best := -1
	var best_distance := 1000
	for index in range(board.cohorts.size()):
		var cohort: Dictionary = board.cohorts[index]
		if cohort["status"] != "active" or board.sheltered(cohort["cell"]) or cohort["id"] == greys["shielded"]: continue
		var gap := distance(cohort["cell"],collector["cell"])
		if gap < best_distance:
			best = index
			best_distance = gap
	if best >= 0 and best_distance <= LIFT_RANGE:
		greys["lift"] = {"group":best,"count":LIFT_ROUNDS}
		return "Collector marks group %s: LIFT %d." % [board.cohorts[best]["id"],LIFT_ROUNDS]
	if best >= 0:
		step_toward(greys,collector,board.cohorts[best]["cell"],COLLECTOR_MOVE,board)
		return "Collector moves toward group %s." % board.cohorts[best]["id"]
	return "Collector holds."

static func aim_target(sentry: Dictionary, board) -> int:
	var best := -1
	var best_distance := 1000
	for index in range(board.soldiers.size()):
		if not board.soldier_can_act(index): continue
		var cell: Vector2i = board.soldiers[index]["cell"]
		var gap := distance(cell,sentry["cell"])
		if gap > SENTRY_RANGE or gap >= best_distance: continue
		if board.sight_preview(sentry["cell"],cell)["clear"]:
			best = index
			best_distance = gap
	return best

## Move up to `steps` squares toward `goal`, stopping next to it.
static func step_toward(greys: Dictionary, entry: Dictionary, goal: Vector2i, steps: int, board) -> void:
	var path := grey_path(greys,entry["cell"],goal,board)
	for index in range(mini(steps,path.size())):
		if path[index] == goal: break
		entry["cell"] = path[index]

static func grey_path(greys: Dictionary, start: Vector2i, goal: Vector2i, board) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
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
			if previous.has(next) or not board.cell_is_in_bounds(next): continue
			if board.WALL_CELLS.has(next) or board.FIXTURES.has(next): continue
			if next != goal and (board.soldier_at(next) >= 0 or board.cohort_at(next) >= 0 or unit_at(greys,next) >= 0): continue
			previous[next] = current
			frontier.append(next)
	return result
