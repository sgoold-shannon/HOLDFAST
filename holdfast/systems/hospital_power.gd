extends RefCounted
## Hospital power and the ambulance (County Hospital). The hospital powers a few systems;
## earlier missions add capacity. The ambulance carries one group per trip, and only runs
## while its charger has power. State: board.power and board.ambulance.
const SYSTEMS := ["ambulance","scanner","lights"]
const LABELS := {"ambulance":"Ambulance charger","scanner":"Triage scanner","lights":"Fence lights"}
const SPEED := 5                 # squares per environment phase along the road

static func initial(rail_cells: bool) -> Dictionary:
	return {"base":1,"rail":1 if rail_cells else 0,"coupling":0,"on":{"ambulance":false,"scanner":false,"lights":false},"log":[]}

static func capacity(power: Dictionary) -> int:
	return power["base"]+power["rail"]+power["coupling"]

static func used(power: Dictionary) -> int:
	var count := 0
	for key in SYSTEMS: count += 1 if power["on"][key] else 0
	return count

static func powered(power: Dictionary, system: String) -> bool:
	return power["on"].get(system,false)

## Toggle one system. Returns "" or a reason it can't.
static func toggle(power: Dictionary, system: String) -> String:
	if not SYSTEMS.has(system): return "No such system."
	if not power["on"][system] and used(power) >= capacity(power):
		return "Power is maxed (%d/%d). Switch something off first." % [used(power),capacity(power)]
	power["on"][system] = not power["on"][system]
	power["log"].append("%s:%s" % [system,"on" if power["on"][system] else "off"])
	return ""

static func ambulance_initial(bay: Vector2i) -> Dictionary:
	return {"cell":bay,"bay":bay,"state":"parked","group":-1,"trips":[],"log":[]}

## Environment phase: drive out with a group, unload at the exit, drive back.
static func drive(ambulance: Dictionary, power: Dictionary, board) -> String:
	if ambulance["state"] == "parked": return ""
	if not powered(power,"ambulance"): return "The ambulance sits dead on the road: no charge."
	var outbound: bool = ambulance["state"] == "out"
	# It unloads one square short of the exit so it never parks on the exit itself.
	var goal: Vector2i = board.civilian_exit()+Vector2i(-1,0) if outbound else ambulance["bay"]
	var step := Vector2i(signi(goal.x-ambulance["cell"].x),0)
	# People on the road step aside for it; only the convoy or a trooper stops it, and it never
	# ends its move on top of someone (except unloading at the exit).
	var reach: Vector2i = ambulance["cell"]
	var stopped := ""
	for move in range(SPEED):
		if reach == goal: break
		var next: Vector2i = reach+step
		if board.road_closed(next):
			stopped = "The ambulance waits: the road is blocked at (%d,%d)." % [next.x,next.y]
			break
		reach = next
	while reach != ambulance["cell"] and reach != goal and board.road_occupied(reach): reach -= step
	ambulance["cell"] = reach
	if ambulance["cell"] != goal: return stopped
	if outbound:
		var cohort: Dictionary = board.cohorts[ambulance["group"]]
		cohort["status"] = "extracted"
		cohort["cell"] = board.civilian_exit()
		cohort["note"] = "Out by ambulance"
		ambulance["trips"].append(cohort["id"])
		ambulance["group"] = -1
		ambulance["state"] = "back"
		return "The ambulance unloads group %s at the exit and turns back." % cohort["id"]
	ambulance["state"] = "parked"
	return "The ambulance is back in the bay."
