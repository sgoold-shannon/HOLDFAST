extends RefCounted
## A bounded test manifest, deliberately separate from campaign civilians.
const STORE := preload("res://encounter_save.gd")
const SLOT := "user://holdfast_d2_ending.save"
const PRESETS := {
	"strong":{"primary":true,"reserve":true,"connector":true,"berths":6,"life":6,"deadline":6,"arrivals":[1,2,3,4,5,6]},
	"strained":{"primary":false,"reserve":true,"connector":true,"berths":4,"life":4,"deadline":4,"arrivals":[1,2,3,4,4,6]},
	"minimum":{"primary":false,"reserve":true,"connector":true,"berths":6,"life":2,"deadline":4,"arrivals":[1,2,6,7,8,9]},
	"no_power":{"primary":false,"reserve":false,"connector":false,"berths":6,"life":6,"deadline":4,"arrivals":[1,2,3,4,4,6]}}
static func new_state(preset: String, source: Dictionary = {}) -> Dictionary:
	var config: Dictionary = PRESETS[preset].duplicate(true)
	var cohorts: Array = []
	for index in range(6):
		var id: String = ["A","B","C","D","E","F"][index]
		var people: Array = []
		for person in range(1,5): people.append("TEST-%s-%02d" % [id,person])
		cohorts.append({"id":id,"arrival":config["arrivals"][index],"people":people})
	return {"preset":preset,"config":config,"source":source.duplicate(true),"round":1,"ap":2,
		"core":true,"tunnel":true,"cohorts":cohorts,"events":{},"agreement":"offered","checks":0,
		"agreement_reason":"","decision_maker":"","bonus_used":false,"selected":0,
		"finished":false,"launched":false,"reserve_used":false,"finish_reason":"","feedback":"Six test cohorts. Campaign rescue totals are unchanged."}

static func power_path(state: Dictionary) -> String:
	if state["config"]["primary"]: return "primary"
	if state["config"]["reserve"] and state["config"]["connector"] and not state["reserve_used"]: return "reserve"
	return "none"

static func launch_problem(state: Dictionary) -> String:
	if not state["core"]: return "Core unavailable. No launch is possible."
	if power_path(state) == "none": return "Both established power paths are unavailable. Retry required."
	if state["config"]["life"] < 1: return "Minimum life support is unavailable."
	if not state["tunnel"]: return "The surface boarding tunnel is unavailable."
	return ""

static func counts(state: Dictionary) -> Dictionary:
	var boarded := 0
	var staging := 0
	var not_arrived := 0
	for cohort in state["cohorts"]:
		if state["events"].has("board:"+cohort["id"]): boarded += 4
		elif cohort["arrival"] <= state["round"]: staging += 4
		else: not_arrived += 4
	return {"boarded":boarded,"staging":staging,"not_arrived":not_arrived}

static func accept(state: Dictionary) -> bool:
	if state["finished"] or state["agreement"] != "offered" or state["round"] > 2: return false
	state["agreement"] = "accepted"
	state["decision_maker"] = "Test field lead"
	state["feedback"] = "Accepted: two checks by the end of round 2; honor the service-lane allocation through launch."
	return true

static func service_check(state: Dictionary) -> bool:
	if state["finished"] or state["agreement"] != "accepted" or state["round"] > 2 or state["ap"] < 1: return false
	state["ap"] -= 1
	state["checks"] += 1
	if state["checks"] == 2:
		state["agreement"] = "ready"
		state["feedback"] = "Checks verified. One boarding action is free; the lane commitment remains active through launch."
	else: state["feedback"] = "Coupling inspected: 1/2 checks. One more 1-AP action is required."
	return true

static func withdraw(state: Dictionary) -> bool:
	if state["finished"]: return false
	if state["agreement"] == "offered":
		state["agreement"] = "declined"
		state["feedback"] = "Agreement declined. Normal boarding remains available."
		return true
	if not ["accepted","ready"].has(state["agreement"]): return false
	state["agreement"] = "broken"
	state["decision_maker"] = "Test field lead"
	state["agreement_reason"] = "Explicitly withdrew the promised service-lane allocation."
	state["feedback"] = "Commitment withdrawn. Unused free boarding is lost; already boarded people remain aboard."
	return true

static func board(state: Dictionary, index: int) -> bool:
	if state["finished"] or index < 0 or index >= 6: return false
	var cohort: Dictionary = state["cohorts"][index]
	var id: String = "board:"+cohort["id"]
	if state["events"].has(id):
		state["feedback"] = "This group is already aboard. No duplicate event or AP cost."
		return false
	if cohort["arrival"] > state["round"] or state["round"] > state["config"]["deadline"]:
		state["feedback"] = "This group has not reached staging before closure."
		return false
	var problem := launch_problem(state)
	if problem != "":
		state["feedback"] = problem
		return false
	if state["events"].size() >= state["config"]["berths"]:
		state["feedback"] = "No safe berth remains. Cargo space cannot substitute for a berth."
		return false
	if state["events"].size() >= state["config"]["life"]:
		state["feedback"] = "Remaining life support cannot support another cohort."
		return false
	var free: bool = state["agreement"] == "ready" and not state["bonus_used"]
	if not free and state["ap"] < 1:
		state["feedback"] = "Boarding needs 1 AP. End the round to replenish actions."
		return false
	if free: state["bonus_used"] = true
	else: state["ap"] -= 1
	state["events"][id] = {"round":state["round"],"people":cohort["people"].duplicate(),"free":free}
	state["feedback"] = "Group %s boarded once: 4 people. %s" % [cohort["id"],"Service team handled the action." if free else "1 AP spent."]
	return true

static func launch(state: Dictionary, reason: String = "Player confirmed launch") -> bool:
	if state["finished"]: return false
	var problem := launch_problem(state)
	state["finished"] = true
	state["finish_reason"] = reason if problem == "" else problem
	state["launched"] = problem == ""
	if state["agreement"] == "ready" and state["launched"]:
		state["agreement"] = "fulfilled"
	elif state["agreement"] == "accepted":
		state["agreement"] = "broken"
		state["agreement_reason"] = "Attempt closed before the promised checks were completed."
	if state["launched"] and power_path(state) == "reserve": state["reserve_used"] = true
	state["feedback"] = "Manifest finalized before the ending report." if state["launched"] else "No completed ending. Retry a test; no third power source appears."
	return state["launched"]

static func end_round(state: Dictionary) -> void:
	if state["finished"]: return
	if state["round"] >= 2 and state["agreement"] == "accepted":
		state["agreement"] = "broken"
		state["agreement_reason"] = "The field lead did not complete two checks by the end of round 2."
		state["feedback"] = "Agreement deadline missed. Normal boarding continues; no free action was earned."
	if state["round"] >= state["config"]["deadline"]:
		launch(state,"Boarding window closed")
		return
	state["round"] += 1
	state["ap"] = 2

static func agreement_report(state: Dictionary) -> String:
	match state["agreement"]:
		"fulfilled": return "Service team: ‘You completed the checks and kept the lane available. The agreement is fulfilled.’"
		"broken": return "Service team: ‘The commitment was not kept.’\nRecorded decision-maker: %s. %s" % [state["decision_maker"],state["agreement_reason"]]
		"declined": return "No commitment was made. No breach is attributed to the field lead."
		"ready": return "Checks completed. Launch was unavailable; no breach is invented." if state["finished"] else "Checks completed; the lane commitment remains active."
		"accepted": return "Commitment active: checks still required."
	return "No agreement accepted. No breach is recorded."

static func validate(state: Variant) -> String:
	if not state is Dictionary or not PRESETS.has(state.get("preset")): return "invalid ending fixture."
	if state.get("config") != PRESETS[state["preset"]]: return "fixture conditions changed."
	if not state.get("source") is Dictionary: return "invalid source record."
	if not state["source"].is_empty():
		var source: Dictionary = state["source"]
		if not source.get("machine") is String or not STORE.integer(source.get("records"),1,3) or not source.get("losses") is Array or source["losses"].size() > 7: return "invalid campaign reference."
		for loss in source["losses"]:
			if not loss is String: return "invalid retained casualty record."
	for key in ["core","tunnel","bonus_used","finished","launched","reserve_used"]:
		if not state.get(key) is bool: return "invalid launch flags."
	for spec in [["round",1,state["config"]["deadline"]],["ap",0,2],["checks",0,2],["selected",0,5]]:
		if not STORE.integer(state.get(spec[0]),spec[1],spec[2]): return "invalid test counters."
	for key in ["feedback","finish_reason","agreement_reason","decision_maker"]:
		if not state.get(key) is String: return "invalid test report."
	if not ["offered","accepted","ready","fulfilled","broken","declined"].has(state.get("agreement")): return "invalid agreement state."
	if not state.get("cohorts") is Array or state["cohorts"] != new_state(state["preset"])["cohorts"]: return "test manifest changed."
	if not state.get("events") is Dictionary or state["events"].size() > mini(state["config"]["berths"],state["config"]["life"]): return "boarding exceeds capacity."
	var free_count := 0
	for id in state["events"]:
		if not id is String or not ["board:A","board:B","board:C","board:D","board:E","board:F"].has(id): return "unknown boarding event."
		var index: int = ["board:A","board:B","board:C","board:D","board:E","board:F"].find(id)
		var event: Variant = state["events"][id]
		if not event is Dictionary or event.get("people") != state["cohorts"][index]["people"] or not STORE.integer(event.get("round"),state["cohorts"][index]["arrival"],state["round"]) or not event.get("free") is bool: return "invalid boarding record."
		free_count += 1 if event["free"] else 0
	if free_count > 1 or state["bonus_used"] != (free_count == 1): return "duplicate or missing service bonus."
	if free_count > 0 and state["checks"] != 2: return "unearned service bonus."
	if ["ready","fulfilled"].has(state["agreement"]) and state["checks"] != 2: return "agreement checks missing."
	if state["agreement"] == "fulfilled" and (not state["finished"] or not state["launched"]): return "agreement fulfilled before launch."
	if state["launched"] and (not state["finished"] or not state["core"] or not state["tunnel"] or (not state["config"]["primary"] and not (state["config"]["reserve"] and state["config"]["connector"]))): return "invalid completed ending."
	if state["reserve_used"] != (state["launched"] and not state["config"]["primary"]): return "reserve consumption mismatch."
	return ""

static func save(state: Dictionary, path: String = SLOT) -> String:
	var error := validate(state)
	if error != "": return error
	var payload := var_to_bytes(state)
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return "Could not write the ending-test save."
	file.store_var({"format":"HOLDFAST_D2","version":1,"payload":payload,"checksum":STORE.checksum(payload)},false)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK: return "Ending-test write failed. Previous save retained."
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path)) != OK: return "Could not replace ending-test save."
	return ""

static func load_state(path: String = SLOT) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {"error":"No ending-test save yet."}
	if file.get_length() > 1048576: return {"error":"Invalid ending-test save size."}
	var envelope: Variant = file.get_var(false)
	file.close()
	if not envelope is Dictionary or envelope.get("format") != "HOLDFAST_D2" or envelope.get("version") != 1 or not envelope.get("payload") is PackedByteArray or not envelope.get("checksum") is String: return {"error":"Invalid ending-test save."}
	if STORE.checksum(envelope["payload"]) != envelope["checksum"]: return {"error":"Ending-test integrity check failed."}
	var state: Variant = bytes_to_var(envelope["payload"])
	var error := validate(state)
	return {"error":error,"state":state} if error == "" else {"error":error}
