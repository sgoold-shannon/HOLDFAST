extends RefCounted
## Grey crew stripping the airfield (Regional Airfield). A Collector strips the transport
## plane's engines one at a time; two Sentries guard it (passive until provoked). The Grey intel
## line allows one stated bargain. Greys step off ground the Fallow mark. State: board.strip.
const GreyTeam = preload("res://systems/grey_team.gd")
const COLLECTOR_HP := 8
const SENTRY_HP := 6
const STRIP_PHASES := 2          # Grey phases next to the plane per engine
const ENGINES := 2
const MOVE := 3
const WORK_RANGE := 2            # close enough to the plane to work on it
const PROVOKE_RANGE := 3         # a soldier this close to the Collector interferes with the shipment
const DEPART_ROUND := 8
const BARGAIN_ROUND := 3
const BARGAIN_ROUNDS := 3
const BEAM_DAMAGE := 4
const BEAM_CROWD_DAMAGE := 2
const NONE := Vector2i(-1,-1)
const DIRECTIONS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT]

static func initial(collector: Vector2i, sentries: Array) -> Dictionary:
	var units: Array = [{"kind":"collector","cell":collector,"hp":COLLECTOR_HP,"aim":{}}]
	for cell in sentries: units.append({"kind":"sentry","cell":cell,"hp":SENTRY_HP,"aim":{}})
	return {"units":units,"withdrawn":false,"hostile":false,"progress":0,"engines":ENGINES,
		"bargain":{"state":"none","until":-1,"broken_by":"","engine_taken":false},"log":[]}

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

static func unit(strip: Dictionary, kind: String) -> Dictionary:
	for entry in strip["units"]:
		if entry["kind"] == kind and entry["hp"] > 0: return entry
	return {}

static func unit_at(strip: Dictionary, cell: Vector2i) -> int:
	if strip["withdrawn"]: return -1
	for index in range(strip["units"].size()):
		if strip["units"][index]["hp"] > 0 and strip["units"][index]["cell"] == cell: return index
	return -1

static func bargain_active(strip: Dictionary) -> bool:
	return strip["bargain"]["state"] == "active"

static func firing(strip: Dictionary) -> bool:
	return strip["hostile"] and not bargain_active(strip) and not strip["withdrawn"]

static func provoke(strip: Dictionary, why: String) -> String:
	if strip["withdrawn"]: return ""
	if bargain_active(strip):
		strip["bargain"]["state"] = "broken"
		strip["bargain"]["broken_by"] = why
		strip["log"].append("bargain_broken:%s" % why)
		strip["hostile"] = true
		return "That breaks the stated terms. The Sentries turn."
	if strip["hostile"]: return ""
	strip["hostile"] = true
	strip["log"].append("provoked:%s" % why)
	return "The Sentries turn on the squad."

static func accept_bargain(strip: Dictionary, phase: int) -> String:
	strip["bargain"]["state"] = "active"
	strip["bargain"]["until"] = phase+BARGAIN_ROUNDS
	strip["hostile"] = false
	for entry in strip["units"]: entry["aim"] = {}
	strip["log"].append("bargain:%d" % phase)
	return "Accepted. Object: one engine. Time: through round %d. Route: the apron. The people aren't part of it, and they aren't to be touched." % strip["bargain"]["until"]

static func take_hit(strip: Dictionary, index: int, damage: int) -> String:
	var target: Dictionary = strip["units"][index]
	target["hp"] = maxi(0,target["hp"]-damage)
	var name: String = "Collector" if target["kind"] == "collector" else "Sentry"
	var text := "Grey %s hit for %d (%d HP left)." % [name,damage,target["hp"]]
	if target["kind"] == "collector" and strip["progress"] > 0:
		strip["progress"] = 0
		text += " The strip breaks off."
	if target["hp"] == 0:
		target["aim"] = {}
		text += " %s down." % name
		strip["log"].append("down:%s" % target["kind"])
	var reaction := provoke(strip,"shot")
	return text + ("" if reaction == "" else " " + reaction)

## The Grey phase.
static func act(strip: Dictionary, board) -> String:
	if strip["withdrawn"]: return ""
	var phase: int = board.phase
	var report: Array[String] = []
	if bargain_active(strip) and phase >= strip["bargain"]["until"]:
		strip["bargain"]["state"] = "honored"
		report.append("The stated window closes. The Greys took exactly what was agreed.")
	# Interference with the shipment.
	var collector := unit(strip,"collector")
	if not collector.is_empty():
		for index in range(board.soldiers.size()):
			if board.soldier_can_act(index) and distance(board.soldiers[index]["cell"],collector["cell"]) <= PROVOKE_RANGE:
				var line := provoke(strip,"shipment")
				if line != "": report.append("%s is on the shipment. %s" % [board.soldiers[index]["name"],line])
				break
	# Greys step off ground the Fallow have marked: they don't fight over it.
	for entry in strip["units"]:
		if entry["hp"] > 0 and board.fallow_marked(entry["cell"]):
			for direction in DIRECTIONS:
				var cell: Vector2i = entry["cell"]+direction*2
				if board.cell_is_in_bounds(cell) and board.civilian_safe(cell) and not board.fallow_marked(cell):
					entry["cell"] = cell
					report.append("A Grey steps off Fallow-marked ground.")
					break
	# Sentries fire, then aim.
	for entry in strip["units"]:
		if entry["kind"] != "sentry" or entry["hp"] <= 0: continue
		if not entry["aim"].is_empty() and firing(strip): report.append(fire(entry,board))
		entry["aim"] = {}
		if firing(strip):
			var target := GreyTeam.aim_target(entry,board)
			if target >= 0:
				entry["aim"] = {"cell":board.soldiers[target]["cell"],"soldier":target}
				report.append("Sentry aims at %s." % board.soldiers[target]["name"])
	# Collector works the plane.
	if not collector.is_empty() and strip["engines"] > 0 and board.plane_present():
		if distance(collector["cell"],board.PLANE) > WORK_RANGE:
			GreyTeam.step_toward(strip,collector,board.PLANE+Vector2i(1,0),MOVE,board)
			report.append("The Grey Collector heads for the transport plane.")
		else:
			strip["progress"] += 1
			if strip["progress"] >= STRIP_PHASES:
				strip["progress"] = 0
				strip["engines"] -= 1
				if bargain_active(strip): strip["bargain"]["engine_taken"] = true
				strip["log"].append("engine")
				report.append("The Collector lifts an engine off the plane (%d left)." % strip["engines"])
			else:
				report.append("The Collector is unbolting an engine. Hit it to break the strip.")
	if phase >= DEPART_ROUND:
		strip["withdrawn"] = true
		for entry in strip["units"]: entry["aim"] = {}
		strip["log"].append("departed")
		report.append("The Grey crew lifts out with what it took.")
	return " ".join(report).strip_edges()

static func fire(entry: Dictionary, board) -> String:
	var aim_cell: Vector2i = entry["aim"]["cell"]
	var info: Dictionary = board.sight_preview(entry["cell"],aim_cell)
	board.round_noise.append(entry["cell"])
	if not info["clear"]: return "A beam scorches a hangar wall."
	for cell in info["cells"]:
		if cell == entry["cell"]: continue
		if board.protected_cell(cell): return "A beam splashes off a Nordic shield."
		if board.soldier_at(cell) >= 0 or board.cohort_at(cell) >= 0:
			var amount := BEAM_DAMAGE if board.soldier_at(cell) >= 0 else BEAM_CROWD_DAMAGE
			return "Beam hits at (%d,%d): %s." % [cell.x,cell.y,board.apply_casualty_damage(cell,amount)]
		if cell == aim_cell: break
	return "A beam cuts empty tarmac."
