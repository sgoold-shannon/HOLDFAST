extends RefCounted
## Machine activation rules; the caller owns state, phase guards, rendering and saves.
## Damage callbacks may request mission completion. Finish reporting only after activate returns.
const NONE := Vector2i(-1,-1)
var _next: Callable
var _target: Callable
var _occupied: Callable
var _damage: Callable
var _path: Callable
func _init(next_cell: Callable, target: Callable, occupied: Callable, damage: Callable, path: Callable) -> void:
	_next = next_cell
	_target = target
	_occupied = occupied
	_damage = damage
	_path = path

static func present(machine: Dictionary, unit: Dictionary) -> bool:
	return unit["hp"] > 0 and not machine["departed"]

func activate(machine: Dictionary, unit: Dictionary, soldiers: Array, phase: int, plan: Dictionary) -> Dictionary:
	if not present(machine,unit): return {"message":"Machine: no activation.","rebuild":false}
	if plan["disabled"]:
		machine["pending_shot"] = NONE
		return {"message":"Disabled machine: no movement or defensive shot.","rebuild":false}
	var protocol: Dictionary = plan["protocol"]
	var diversion: Array = plan["diversion"]
	var skid_cell: Vector2i = plan["skid"]
	var message := ""
	if protocol.get("pause_pending",false):
		protocol["pause_pending"] = false
		protocol["pause_used"] = true
		message = "ACK-01 honored: one entire activation skipped."
		return {"message":message,"rebuild":false}
	if protocol.get("diverted",false):
		machine["pending_shot"] = NONE
		if protocol["component_collected"]:
			machine["departed"] = true
			message = "Diverted machine departed. Skid and feeder intact."
			return {"message":message,"rebuild":false}
		var moved := 0
		for step in range(2):
			while protocol["waypoint"] < diversion.size() and unit["cell"] == diversion[protocol["waypoint"]]:
				protocol["waypoint"] += 1
			if protocol["waypoint"] == diversion.size():
				protocol["component_collected"] = true
				break
			var path: Array = _path.call(unit["cell"],diversion[protocol["waypoint"]],true)
			if path.is_empty():
				break
			unit["cell"] = path[0]
			moved += 1
			while protocol["waypoint"] < diversion.size() and unit["cell"] == diversion[protocol["waypoint"]]:
				protocol["waypoint"] += 1
			if protocol["waypoint"] == diversion.size():
				protocol["component_collected"] = true
				break
		message = "Alternate component collected at (%d,%d). Departure next activation." % [diversion[-1].x,diversion[-1].y] if protocol["component_collected"] else ("Safe route held: people block the chosen waypoint." if moved == 0 else "Safe route: moved %d/2 squares; people avoided." % moved)
		return {"message":message,"rebuild":true}
	if protocol.get("betrayed",false) and machine["collected_round"] == 0:
		var shot: Vector2i = machine["pending_shot"]
		machine["pending_shot"] = NONE
		var report := ""
		if shot != NONE:
			report = "Shot %s: %s. " % [shot,_damage.call(shot,4)]
		if unit["cell"] == skid_cell:
			machine["collected_round"] = phase
			machine["stage"] = plan["collect_stage"] + 1
			report += "Skid collected; feeder severed."
		else:
			var next: Vector2i = _next.call()
			if next == NONE:
				report += "Recovery route blocked."
			elif _occupied.call(next):
				report += "Impact at %s: %s; held." % [next,_damage.call(next,4)]
			else:
				unit["cell"] = next
				report += "Recovery moved to %s." % next
		var index: int = _target.call()
		if index >= 0:
			machine["pending_shot"] = soldiers[index]["cell"]
		message = report
		return {"message":message,"rebuild":true}
	var events: Array[String] = []
	var shot: Vector2i = machine["pending_shot"]
	machine["pending_shot"] = NONE
	if shot != NONE:
		events.append("Shot (%d,%d): %s" % [shot.x, shot.y, _damage.call(shot, 4)])
	var next: Vector2i = _next.call()
	if machine["stage"] == plan["collect_stage"]:
		machine["collected_round"] = phase
		machine["stage"] = plan["collect_stage"] + 1
		events.append("Skid collected; feeder severed")
	elif machine["stage"] == plan["depart_stage"]:
		machine["departed"] = true
		events.append("Machine departed")
	elif _occupied.call(next):
		events.append("Impact (%d,%d): %s; held" % [next.x, next.y, _damage.call(next, 4)])
	else:
		unit["cell"] = next
		machine["stage"] += 1
		events.append("Moved (%d,%d)" % [next.x, next.y])
	var index: int = _target.call()
	if index >= 0:
		machine["pending_shot"] = soldiers[index]["cell"]
	return {"message":"; ".join(events),"rebuild":true}

func nearest_target(machine: Dictionary, unit: Dictionary, soldiers: Array, plan: Dictionary, available: Callable, sight: Callable) -> int:
	if not present(machine,unit) or not machine["hostile"] or plan["disabled"] or plan["protocol"].get("diverted",false):
		return -1
	var best := -1
	var nearest := 999
	for index in range(soldiers.size()):
		if not available.call(index):
			continue
		var info: Dictionary = sight.call(unit["cell"], soldiers[index]["cell"])
		if info["clear"] and info["distance"] <= 6 and info["distance"] < nearest:
			nearest = info["distance"]
			best = index
	return best

func next_cell(machine: Dictionary, unit: Dictionary, route: Array, plan: Dictionary) -> Vector2i:
	var protocol: Dictionary = plan["protocol"]
	var diversion: Array = plan["diversion"]
	var skid_cell: Vector2i = plan["skid"]
	if not present(machine,unit) or plan["disabled"]:
		return NONE
	if protocol.get("diverted",false):
		if protocol["component_collected"]:
			return NONE
		var index: int = protocol["waypoint"]
		while index < diversion.size() and unit["cell"] == diversion[index]:
			index += 1
		if index >= diversion.size():
			return NONE
		var path: Array = _path.call(unit["cell"],diversion[index],true)
		return path[0] if not path.is_empty() else NONE
	if protocol.get("betrayed",false) and machine["collected_round"] == 0:
		var path: Array = _path.call(unit["cell"],skid_cell,false)
		return path[0] if not path.is_empty() else NONE
	if machine["stage"] == plan["collect_stage"] or machine["stage"] == plan["depart_stage"]: return NONE
	return route[machine["stage"]+1]
