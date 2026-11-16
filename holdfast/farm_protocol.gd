extends "res://farm_options.gd"
## B4 communication actions are deterministic; the pause is single-use.
const PROTOCOL_SLOT := "user://holdfast_b4.save"
var CONSOLE_CELL: Vector2i:
	get: return mission_definition().console_cell
var SKID_CELL: Vector2i:
	get: return mission_definition().skid_cell
var DIVERSION: Array[Vector2i]:
	get: return mission_definition().diversion
const OBSERVE_RECT := Rect2(40,1136,180,40)
const TRANSMIT_RECT := Rect2(230,1136,180,40)
const AUTH_RECT := Rect2(420,1136,190,40)
const DIVERT_RECT := Rect2(620,1136,204,40)
var protocol := {"observed": false, "acknowledged": false, "pause_pending": false,
	"pause_used": false, "authenticated": false, "route_set": false,
	"diverted": false, "waypoint": 0, "component_collected": false, "betrayed": false}

func _ready() -> void:
	super._ready()
	status_text = "MSG: O observe, P transmit. Console: Bell uses A authenticate, D divert."
	save_feedback = "B4 save slot. Protocol: HOLD / ONE CYCLE. Acknowledgement token: ACK-01."

func protocol_reason(action: String) -> String:
	if ended or not machine_present() or disabled():
		return "Protocol unavailable: encounter ended or machine stopped/departed."
	if machine["collected_round"] > 0:
		return "Too late: the skid has already been collected."
	if not soldier_can_act(active_soldier) or soldiers[active_soldier]["ap"] < 1:
		return "Select an active soldier with 1 AP."
	if action == "observe" or action == "transmit":
		if active_soldier != 0:
			return "Only MSG may observe and transmit the pause protocol."
		if action == "observe":
			if protocol["observed"]:
				return "Machine already observed."
			var info := sight_preview(soldiers[0]["cell"],enemies[0]["cell"])
			if not info["clear"] or info["distance"] > 8:
				return "Observation needs sight and Manhattan distance 8 or less."
		else:
			if not protocol["observed"]:
				return "Observe the machine before transmitting."
			if protocol["acknowledged"]:
				return "Pause already acknowledged; it can be requested only once."
	else:
		if not protocol["acknowledged"]:
			return "Console requires the returned acknowledgement token."
		var eligible := active_soldier == 2 or (active_soldier == 0 and not soldier_can_act(2))
		if not eligible:
			return "%s operates the console. MSG substitutes if unavailable." % soldiers[2]["name"]
		var delta: Vector2i = soldiers[active_soldier]["cell"] - CONSOLE_CELL
		if absi(delta.x) + absi(delta.y) != 1:
			return "Stand adjacent to the console at (11,12)."
		if action == "authenticate" and protocol["authenticated"]:
			return "Token already authenticated."
		if action == "divert":
			if not protocol["authenticated"]:
				return "Authenticate ACK-01 before setting the route."
			if protocol["route_set"]:
				return "Diversion already used; firing on it cancels safe routing."
	return ""

func protocol_action(action: String) -> bool:
	if not ["observe","transmit","authenticate","divert"].has(action):
		return false
	var reason := protocol_reason(action)
	if reason != "":
		status_text = reason
		queue_redraw()
		return false
	close_pending = false
	soldiers[active_soldier]["ap"] -= 1
	match action:
		"observe":
			protocol["observed"] = true
			status_text = "Observed machine. Pause protocol displayed: HOLD / ONE CYCLE."
		"transmit":
			protocol["acknowledged"] = true
			protocol["pause_pending"] = true
			status_text = "ACK-01 received. The next machine activation will be skipped once."
		"authenticate":
			protocol["authenticated"] = true
			status_text = "ACK-01 authenticated. Set alternate route for 1 AP before skid collection."
		"divert":
			protocol["route_set"] = true
			protocol["diverted"] = true
			machine["pending_shot"] = NONE
			machine["hostile"] = false
			status_text = "Diverted: (10,10) → (14,10) → component (14,8). Avoids people."
	rebuild_movement()
	return true

func machine_path(start: Vector2i, goal: Vector2i, avoid_people: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var frontier: Array[Vector2i] = [start]
	var previous: Dictionary = {start: NONE}
	var cursor := 0
	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		if current == goal:
			while current != start:
				result.push_front(current)
				current = previous[current]
			return result
		for direction in DIRECTIONS:
			var next := current + direction
			if previous.has(next) or not cell_is_in_bounds(next) or WALL_CELLS.has(next) or FIXTURES.has(next):
				continue
			if avoid_people and cell_occupied_by_people(next):
				continue
			previous[next] = current
			frontier.append(next)
	return result



func enemy_intent() -> String:
	if not machine_present() or disabled():
		return "DIVERTED: alternate component collected; machine departed." if machine["departed"] and protocol["diverted"] else super.enemy_intent()
	if protocol["pause_pending"]:
		return "ACK-01: next machine activation PAUSED (once)."
	if protocol["diverted"]:
		return "DIVERTED: component collected; departs next activation." if protocol["component_collected"] else "DIVERTED: 2 squares/phase; avoids people; no defensive shots."
	if protocol["betrayed"] and machine["collected_round"] == 0:
		return "HOSTILE: safe route canceled; replanning toward skid (7,8)."
	return super.enemy_intent()


func try_fire() -> bool:
	var was_diverted: bool = protocol["diverted"]
	var fired := super.try_fire()
	if fired and was_diverted:
		protocol["diverted"] = false
		protocol["betrayed"] = true
		machine["hostile"] = true
		if machine_present():
			status_text += " Safe routing canceled; returning to skid."
	return fired

func machine_outcome() -> String:
	if enemies[0]["hp"] > 0 and not disabled() and protocol["diverted"]:
		return "Diverted | cooling preserved | skid and feeder intact"
	return super.machine_outcome()

func encounter_snapshot() -> Dictionary:
	var result := super.encounter_snapshot()
	result["layout"] = "gdd3.1-b4-protocol"
	result["protocol"] = protocol.duplicate(true)
	return result

func save_encounter(path: String = PROTOCOL_SLOT) -> bool:
	if [SaveStore.SAVE_PATH,FARM_SLOT,EVAC_SLOT,OPTIONS_SLOT].has(path):
		path = PROTOCOL_SLOT
	var error := SaveStore.save(encounter_snapshot(),path)
	save_feedback = "B4 saved: acknowledgement, pause, authentication and route progress." if error == "" else error
	queue_redraw()
	return error == ""

func load_encounter(path: String = PROTOCOL_SLOT) -> bool:
	if [SaveStore.SAVE_PATH,FARM_SLOT,EVAC_SLOT,OPTIONS_SLOT].has(path):
		path = PROTOCOL_SLOT
	var result := SaveStore.load_snapshot(path)
	if result["error"] != "" or result.get("snapshot",{}).get("layout") != "gdd3.1-b4-protocol":
		save_feedback = result["error"] if result["error"] != "" else "Save belongs to another encounter."
		queue_redraw()
		return false
	var snapshot: Dictionary = result["snapshot"]
	protocol = snapshot["protocol"].duplicate(true)
	breaker_progress = snapshot["breaker"]
	isolate_pending = false
	var evac: Dictionary = snapshot["evac"]
	cohorts.assign(evac["cohorts"].duplicate(true))
	cohort_selected = evac["selected"]
	order_used = evac["order_used"]
	ended = evac["ended"]
	end_reason = evac["reason"]
	last_civilian_phase = evac["last_phase"]
	close_pending = false
	machine = snapshot["machine"].duplicate(true)
	var ui: Dictionary = snapshot["ui"]
	active_soldier = ui["active"]
	restore_combat(snapshot["combat"])
	selected_cell = ui["selected"]
	pinned_target = ui["pinned"]
	sight_mode = ui["sight"]
	status_text = ui["status"]
	hovered_cell = NONE
	save_feedback = "B4 loaded: protocol and machine route restored exactly."
	queue_redraw()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if isolate_pending:
		super._unhandled_input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var actions := {KEY_O:"observe",KEY_P:"transmit",KEY_A:"authenticate",KEY_D:"divert"}
		if actions.has(event.keycode):
			protocol_action(actions[event.keycode])
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		for item in [[OBSERVE_RECT,"observe"],[TRANSMIT_RECT,"transmit"],[AUTH_RECT,"authenticate"],[DIVERT_RECT,"divert"]]:
			if item[0].has_point(point):
				protocol_action(item[1])
				return
	super._unhandled_input(event)

func _draw() -> void:
	super._draw()
	draw_rect(Rect2(35,10,790,34),Color("0e1412"))
	draw_string(font,Vector2(40,36),"HOLDFAST / B4 COMMUNICATE & DIVERT",HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color.WHITE)
	if protocol["route_set"] and not protocol["betrayed"]:
		for waypoint in DIVERSION:
			draw_rect(Rect2(cell_to_local(waypoint)+Vector2(1,1),Vector2(34,34)),Color("8be6de"),false,2)
	for item in [[OBSERVE_RECT,"Observe [O] · 1 AP","observe"],[TRANSMIT_RECT,"Transmit [P] · 1 AP","transmit"],[AUTH_RECT,"Authenticate [A] · 1 AP","authenticate"],[DIVERT_RECT,"Divert [D] · 1 AP","divert"]]:
		draw_rect(item[0],Color("304965") if protocol_reason(item[2]) == "" else Color("343b38"))
		draw_string(font,item[0].position+Vector2(0,26),item[1],HORIZONTAL_ALIGNMENT_CENTER,item[0].size.x,14,Color.WHITE)
	var progress := "Observed: %s | ACK-01: %s | Authenticated: %s" % ["yes" if protocol["observed"] else "no","received" if protocol["acknowledged"] else "not received","yes" if protocol["authenticated"] else "no"]
	draw_string(font,Vector2(40,1127),progress,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("8be6de"))
	draw_string(font,Vector2(40,1201),"Pause: HOLD / ONE CYCLE. Console: (11,12), adjacent %s (MSG if unavailable)." % soldiers[2]["name"],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("aebbb6"))
	# Keep the forecast honest while paused or safely redirected.
	var forecast := "none"
	if machine["collected_round"] > 0:
		forecast = str(machine["collected_round"] + 1)
	elif machine_present() and not disabled() and not protocol["diverted"]:
		var path := machine_path(enemies[0]["cell"],SKID_CELL,false)
		forecast = str(phase + path.size() + 1 + (1 if protocol["pause_pending"] else 0))
	draw_rect(Rect2(35,1070,800,25),Color("0e1412"))
	draw_string(font,Vector2(40,1088),"Machine closure forecast %s | External 10 | Deadline %d | %s" % [forecast,deadline(),"Safe route canceled" if protocol["betrayed"] else ("Diverted" if protocol["diverted"] else "Default recovery")],HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("aebbb6"))

func machine_plan() -> Dictionary:
	var plan := super.machine_plan()
	plan["protocol"] = protocol
	plan["skid"] = SKID_CELL
	plan["diversion"] = DIVERSION
	return plan
