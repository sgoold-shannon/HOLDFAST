extends RefCounted
## Grey extraction site (Rail Yard). GDD v3.1 §05/§26: extract selected specimens, archives
## and apparatus on a departure window; escalate when the squad interferes with a shipment.
## §20 tells: beams aim a turn ahead; abduction is a marked, timed load; blackout marks an
## area a turn before it goes dark. A bargain states its object, time and route.
## State is one plain dictionary on the board (board.yard). Balance numbers live here.
const GreyTeam = preload("res://systems/grey_team.gd")
const COLLECTOR_HP := 8
const SENTRY_HP := 6
const DISRUPTOR_HP := 6
const FIRST_LOAD := 3            # Collector marks a pen in odd rounds from here, takes it the next round
const COLLECTOR_MOVE := 3
const SENTRY_RANGE := 8
const BEAM_DAMAGE := 4
const BEAM_CROWD_DAMAGE := 2
const PROVOKE_RANGE := 3         # a soldier this close to the transport provokes the Sentries
const DEPART_ROUND := 8          # transport lifts off at the end of this round
const TRADE_ROUND := 2           # the commander's offer is open during this round
const TRADE_ROUNDS := 3
const BLACKOUT_RADIUS := 1       # 3×3
const SHOT_DAMAGE := 4
const NONE := Vector2i(-1,-1)

static func initial(collector: Vector2i, sentries: Array, disruptor: Vector2i, transport: Array) -> Dictionary:
	var units: Array = [{"kind":"collector","cell":collector,"hp":COLLECTOR_HP,"aim":{}}]
	for cell in sentries: units.append({"kind":"sentry","cell":cell,"hp":SENTRY_HP,"aim":{}})
	units.append({"kind":"disruptor","cell":disruptor,"hp":DISRUPTOR_HP,"aim":{}})
	return {"units":units,"withdrawn":false,"hostile":false,"load":{},"aboard":[],
		"mark":NONE,"dark":NONE,"transport":transport,
		"trade":{"state":"none","until":-1,"broken_by":""},"log":[]}

static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x-b.x)+absi(a.y-b.y)

static func unit(yard: Dictionary, kind: String) -> Dictionary:
	for entry in yard["units"]:
		if entry["kind"] == kind and entry["hp"] > 0: return entry
	return {}

static func unit_at(yard: Dictionary, cell: Vector2i) -> int:
	if yard["withdrawn"]: return -1
	for index in range(yard["units"].size()):
		if yard["units"][index]["hp"] > 0 and yard["units"][index]["cell"] == cell: return index
	return -1

static func near_transport(yard: Dictionary, cell: Vector2i, gap: int) -> bool:
	for part in yard["transport"]:
		if distance(part,cell) <= gap: return true
	return false

static func in_area(center: Vector2i, cell: Vector2i) -> bool:
	return center != NONE and absi(cell.x-center.x) <= BLACKOUT_RADIUS and absi(cell.y-center.y) <= BLACKOUT_RADIUS

static func blacked_out(yard: Dictionary, cell: Vector2i) -> bool:
	return not yard["withdrawn"] and in_area(yard["dark"],cell)

static func trade_active(yard: Dictionary) -> bool:
	return yard["trade"]["state"] == "active"

static func firing(yard: Dictionary) -> bool:
	return yard["hostile"] and not trade_active(yard) and not yard["withdrawn"]

static func threat_cells(yard: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if yard["withdrawn"]: return cells
	for entry in yard["units"]:
		if entry["hp"] <= 0: continue
		cells.append(entry["cell"])
		if not entry["aim"].is_empty(): cells.append(entry["aim"]["cell"])
	return cells

## The squad interfered with a shipment. During a trade only its stated terms count.
static func provoke(yard: Dictionary, why: String, breaks_trade: bool) -> String:
	if yard["withdrawn"]: return ""
	if trade_active(yard):
		if not breaks_trade: return ""
		yard["trade"]["state"] = "broken"
		yard["trade"]["broken_by"] = why
		yard["log"].append("trade_broken:%s" % why)
		yard["hostile"] = true
		return "That breaks the agreed terms. The Sentries turn."
	if yard["hostile"]: return ""
	yard["hostile"] = true
	yard["log"].append("provoked:%s" % why)
	return "The Sentries turn on the squad."

static func accept_trade(yard: Dictionary, phase: int) -> String:
	if yard["withdrawn"] or yard["trade"]["state"] != "none" or phase != TRADE_ROUND: return "There's no offer on the channel."
	yard["trade"]["state"] = "active"
	yard["trade"]["until"] = phase+TRADE_ROUNDS
	yard["hostile"] = false
	for entry in yard["units"]: entry["aim"] = {}
	yard["log"].append("trade_accepted:%d" % phase)
	return "Accepted. Object: the survey section of the archive. Time: through round %d. Route: the transport, its ramp and the terminal stay untouched. The pens aren't covered." % yard["trade"]["until"]

static func take_hit(yard: Dictionary, index: int, damage: int) -> String:
	var target: Dictionary = yard["units"][index]
	target["hp"] = maxi(0,target["hp"]-damage)
	var name: String = {"collector":"Collector","sentry":"Sentry","disruptor":"Disruptor"}[target["kind"]]
	var text := "%s hit for %d (%d HP left)." % [name,damage,target["hp"]]
	if target["kind"] == "collector" and not yard["load"].is_empty():
		yard["load"] = {}
		text += " The load breaks off."
	if target["hp"] == 0:
		target["aim"] = {}
		text += " %s down." % name
		yard["log"].append("down:%s" % target["kind"])
		if target["kind"] == "disruptor":
			yard["mark"] = NONE
			yard["dark"] = NONE
			text += " The blackouts stop."
	var reaction := provoke(yard,"shot",true)
	return text + ("" if reaction == "" else " " + reaction)

## The Grey phase. Returns a line for the enemy message.
static func act(yard: Dictionary, board) -> String:
	if yard["withdrawn"]: return ""
	var phase: int = board.phase
	var report: Array[String] = []
	if trade_active(yard) and phase >= yard["trade"]["until"]:
		yard["trade"]["state"] = "honored"
		yard["log"].append("trade_honored")
		report.append("The agreed window closes. The Greys kept exactly what they promised.")
	# 1. Soldiers crowding the transport.
	for index in range(board.soldiers.size()):
		if board.soldier_can_act(index) and near_transport(yard,board.soldiers[index]["cell"],PROVOKE_RANGE):
			var line := provoke(yard,"transport",true)
			if line != "": report.append("%s is at the transport. %s" % [board.soldiers[index]["name"],line])
			break
	# 2. Sentries fire what they aimed, then aim again.
	for entry in yard["units"]:
		if entry["kind"] != "sentry" or entry["hp"] <= 0: continue
		if not entry["aim"].is_empty() and firing(yard): report.append(fire(entry,board))
		entry["aim"] = {}
		if firing(yard):
			var target := GreyTeam.aim_target(entry,board)
			if target >= 0:
				entry["aim"] = {"cell":board.soldiers[target]["cell"],"soldier":target}
				report.append("Sentry aims at %s." % board.soldiers[target]["name"])
	# 3. Collector loads a pen: marked in odd rounds, taken the round after.
	var collector := unit(yard,"collector")
	if not collector.is_empty(): report.append(load_step(yard,collector,board))
	# 4. Disruptor: the marked area goes dark, and a new one is marked.
	var disruptor := unit(yard,"disruptor")
	if not disruptor.is_empty():
		yard["dark"] = yard["mark"]
		yard["mark"] = blackout_center(disruptor,board)
		if yard["mark"] != NONE: report.append("Violet light marks a blackout at (%d,%d) for next round." % [yard["mark"].x,yard["mark"].y])
	# 5. Departure.
	if phase >= DEPART_ROUND:
		yard["withdrawn"] = true
		yard["load"] = {}
		yard["mark"] = NONE
		yard["dark"] = NONE
		for entry in yard["units"]: entry["aim"] = {}
		yard["log"].append("departed")
		report.append("The transport lifts off%s." % (" with group " + ", ".join(yard["aboard"]) + " aboard" if not yard["aboard"].is_empty() else ", empty of people"))
	return " ".join(report).strip_edges()

static func load_step(yard: Dictionary, collector: Dictionary, board) -> String:
	var phase: int = board.phase
	var load: Dictionary = yard["load"]
	if not load.is_empty():
		var cohort: Dictionary = board.cohorts[load["group"]]
		yard["load"] = {}
		if cohort["status"] != "active" or not cohort.get("penned",false):
			return "The Collector reaches an empty pen."
		cohort["status"] = "taken"
		cohort["penned"] = false
		cohort["note"] = "Aboard the Grey transport. Names on record; in custody."
		yard["aboard"].append(cohort["id"])
		yard["log"].append("aboard:%s" % cohort["id"])
		collector["cell"] = board.TRANSPORT_RAMP
		return "The Collector walks group %s up the ramp. Four people aboard." % cohort["id"]
	if phase < FIRST_LOAD or (phase-FIRST_LOAD) % 2 != 0: return "The Collector checks its manifest."
	var best := -1
	var best_gap := 1000
	for index in range(board.cohorts.size()):
		var cohort: Dictionary = board.cohorts[index]
		if cohort["status"] != "active" or not cohort.get("penned",false): continue
		var gap := distance(cohort["cell"],board.TRANSPORT_RAMP)
		if gap < best_gap:
			best_gap = gap
			best = index
	if best < 0: return "The Collector finds the pens empty."
	yard["load"] = {"group":best}
	GreyTeam.step_toward(yard,collector,board.cohorts[best]["cell"],COLLECTOR_MOVE*2,board)
	return "The Collector marks group %s for loading. It takes them next Grey phase unless it's hit or the pen is opened." % board.cohorts[best]["id"]

static func blackout_center(disruptor: Dictionary, board) -> Vector2i:
	var best := NONE
	var best_gap := 1000
	for index in range(board.soldiers.size()):
		if not board.soldier_can_act(index): continue
		var gap := distance(board.soldiers[index]["cell"],disruptor["cell"])
		if gap < best_gap:
			best_gap = gap
			best = board.soldiers[index]["cell"]
	return best

static func fire(entry: Dictionary, board) -> String:
	var aim_cell: Vector2i = entry["aim"]["cell"]
	var info: Dictionary = board.sight_preview(entry["cell"],aim_cell)
	board.round_noise.append(entry["cell"])
	if not info["clear"]: return "A beam scorches a boxcar."
	for cell in info["cells"]:
		if cell == entry["cell"]: continue
		if board.soldier_at(cell) >= 0 or board.cohort_at(cell) >= 0:
			var amount := BEAM_DAMAGE if board.soldier_at(cell) >= 0 else BEAM_CROWD_DAMAGE
			return "Beam hits at (%d,%d): %s." % [cell.x,cell.y,board.apply_casualty_damage(cell,amount)]
		if cell == aim_cell: break
	return "A beam cuts empty track."
