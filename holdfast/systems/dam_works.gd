extends RefCounted
## The Dam (Mission 10): pressure and spillways, power allocation, the habitat, cargo, Kesh's
## guidance, and the Fallow working along the crest. GDD v3.1 §11: a cooperative objective with
## an authenticated partial channel; every valve release floods someone. State: board.dam.
const FallowCutter = preload("res://systems/fallow_cutter.gd")
const START_PRESSURE := 2
const BREACH := 8
const VALVE_DROP := 3
const FLOOD_ROUNDS := 2
const FLOOD_DAMAGE := 4
const FLOOD_CROWD_DAMAGE := 2
const POWER := 3
const STABILIZE_STEPS := 2
const REPAIR_STEPS := 2
const FALLOW_START := 3
const CREST_ROW := 2
const NONE := Vector2i(-1,-1)

static func initial(channel: String, needs_repair: bool) -> Dictionary:
	return {"pressure":START_PRESSURE,"breached":false,"floods":{"west":-1,"east":-1},"valves":{"west":0,"east":0},
		"power":{"bridge":false,"life":false,"trunk":0},"stabilize":0,"stabilized":false,
		"repair":0,"needs_repair":needs_repair,"channel":channel,"delivered":0,"crates_lost":0,"log":[]}

static func power_used(dam: Dictionary) -> int:
	return (1 if dam["power"]["bridge"] else 0)+(1 if dam["power"]["life"] else 0)+int(dam["power"]["trunk"])

static func flooding(dam: Dictionary, side: String, phase: int) -> bool:
	return dam["breached"] or phase <= dam["floods"][side]

## Kesh's guidance this round: "" means silence.
static func guidance(dam: Dictionary, board) -> String:
	var phase: int = board.phase
	match dam["channel"]:
		"hardened":
			if not dam["stabilized"]: return "Kesh: ‘Stabilize the families. Then we talk.’"
		"partial":
			if phase % 2 == 0: return ""
	var west: bool = board.zone_clear("west")
	var east: bool = board.zone_clear("east")
	var line := "Kesh: ‘West spillway channel is %s. East channel is %s.’" % ["clear" if west else "occupied","clear" if east else "occupied"]
	if dam["channel"] == "authenticated": line += " Pressure %d of %d; authenticated: MSG can open valves remotely." % [dam["pressure"],BREACH]
	return line

## Open a spillway: pressure drops, and that side floods for two rounds.
static func open_valve(dam: Dictionary, side: String, board) -> String:
	dam["pressure"] = maxi(0,dam["pressure"]-VALVE_DROP)
	dam["floods"][side] = board.phase+FLOOD_ROUNDS-1
	dam["valves"][side] += 1
	dam["log"].append("valve:%s:%d" % [side,board.phase])
	var hurt: Array[String] = board.flood_zone(side)
	return "The %s spillway roars open. Pressure %d of %d. %s" % [side,dam["pressure"],BREACH,"Nobody was in the channel." if hurt.is_empty() else "Caught in the water: " + "; ".join(hurt) + "."]

## The Fallow along the crest: transform last phase's marks, then mark further west.
static func fallow_act(dam: Dictionary, fallow: Dictionary, board) -> String:
	var phase: int = board.phase
	if fallow["stage"] == "waiting":
		if phase < FALLOW_START: return ""
		fallow["stage"] = "active"
		mark_crest(fallow,board)
		return "A Fallow cutter climbs onto the dam crest from the east, a node anchored behind it. It marks the crest."
	if not FallowCutter.cutter_alive(fallow): return ""
	var line := ""
	if fallow["interrupted"]:
		fallow["interrupted"] = false
		line = "The cutter hesitates without its link; the marked crest holds."
	elif not fallow["marked"].is_empty():
		var count := 0
		for cell in fallow["marked"]:
			if fallow["rifts"].has(cell): continue
			fallow["rifts"].append(cell)
			board.add_rift(cell)
			count += 1
			if board.soldier_at(cell) >= 0: board.apply_casualty_damage(cell,FallowCutter.RIFT_DAMAGE)
			board.throw_clear(cell)
		fallow["marked"] = []
		if count > 0: dam["pressure"] += 1
		line = "The crest folds into rift (%d squares). The dam face groans: pressure +1." % count
	elif fallow["marked"].is_empty():
		mark_crest(fallow,board)
		line = "The cutter marks the crest again."
	return line

static func mark_crest(fallow: Dictionary, board) -> void:
	var length := FallowCutter.STRIP_WITH_NODE if FallowCutter.node_present(fallow) else FallowCutter.STRIP_WITHOUT_NODE
	var x: int = fallow["cutter"]["cell"].x-1
	var cells: Array = []
	while cells.size() < length and x >= 3:
		var cell := Vector2i(x,CREST_ROW)
		if not fallow["rifts"].has(cell) and not board.FIXTURES.has(cell): cells.append(cell)
		x -= 1
	fallow["marked"] = cells

## Environment phase: pressure rises, floods recede, breach check.
static func environment(dam: Dictionary, board) -> String:
	if dam["breached"]: return ""
	dam["pressure"] += 1
	if dam["pressure"] >= BREACH:
		dam["breached"] = true
		dam["log"].append("breach:%d" % board.phase)
		return board.breach()
	return "Pressure %d of %d." % [dam["pressure"],BREACH]
