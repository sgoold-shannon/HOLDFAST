extends RefCounted
## Campaign record: what each finished mission leaves behind for the rest of the campaign.
## GDD v3.1 Section 29: Farm Road records the machine state, feeder state, protocol
## acknowledgement, each group's fate and each soldier's status. Observations are kept
## apart from interpretation. Later missions read this file; nothing here is a moral score.
const PATH := "user://holdfast_campaign_record.save"
const VERSION := 1

static func load_record(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path): return {"version":VERSION,"missions":{}}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return {"version":VERSION,"missions":{}}
	var data = file.get_var()
	if not (data is Dictionary) or not data.has("missions"): return {"version":VERSION,"missions":{}}
	return data

static func save_record(path: String, record: Dictionary) -> String:
	if path == "": return ""
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null: return "Campaign record could not be written."
	file.store_var(record)
	return ""

static func machine_state(board) -> String:
	if board.enemies[0]["hp"] <= 0: return "destroyed"
	if board.disabled(): return "disabled"
	if board.protocol["diverted"]: return "diverted"
	if board.machine["departed"]: return "departed"
	return "active"

## Mission 01 entry built from a finished Farm Road board.
static func farm_road_entry(board) -> Dictionary:
	var squad: Array = []
	for index in range(board.soldiers.size()):
		var soldier: Dictionary = board.soldiers[index]
		squad.append({"name":soldier["name"],"condition":soldier.get("condition","active"),"extracted":soldier["extracted"],"disposition":board.soldier_disposition(index)})
	var groups: Array = []
	for cohort in board.cohorts:
		groups.append({"id":cohort["id"],"status":cohort["status"]})
	return {"mission":1,"retry_required":board.retry_required(),"round":board.phase,"end_reason":board.end_reason,
		"evacuated":board.evacuated_people(),"groups":groups,"squad":squad,
		"machine":machine_state(board),"feeder":board.feeder_result(),"acknowledged":board.protocol["acknowledged"],
		"debrief_response":board.debrief_response}

## Store the latest Farm Road result. Returns true if the file changed.
static func record_farm_road(path: String, board) -> bool:
	var record := load_record(path)
	var entry := farm_road_entry(board)
	var previous: Dictionary = record["missions"].get(1,{})
	var attempts: int = previous.get("attempts",0)
	var comparable: Dictionary = previous.duplicate()
	comparable.erase("attempts")
	if var_to_str(comparable) == var_to_str(entry): return false
	entry["attempts"] = attempts+1 if previous.get("round",-1) != entry["round"] or previous.get("evacuated",-1) != entry["evacuated"] or previous.get("machine","") != entry["machine"] else maxi(attempts,1)
	record["missions"][1] = entry
	save_record(path,record)
	return true

## Mission 02 entry built from a finished River Bridge board.
static func river_bridge_entry(board) -> Dictionary:
	var squad: Array = []
	for index in range(board.soldiers.size()):
		var soldier: Dictionary = board.soldiers[index]
		squad.append({"name":soldier["name"],"condition":soldier.get("condition","active"),"extracted":soldier["extracted"],"disposition":board.soldier_disposition(index)})
	var groups: Array = []
	for cohort in board.cohorts:
		groups.append({"id":cohort["id"],"status":cohort["status"]})
	return {"mission":2,"retry_required":board.retry_required(),"round":board.phase,"end_reason":board.end_reason,
		"evacuated":board.evacuated_people(),"groups":groups,"squad":squad,"lanes":board.lanes,
		"supplies":"kept" if board.lanes == "heavy" else "lost","sensor":board.sensor_recovered,
		"taken":board.greys["taken"].duplicate(),"craft_shield":board.greys["shield_used"],
		"greys":"collector_down" if board.greys["withdraw_reason"].begins_with("Collector") else ("withdrew" if board.greys["withdrawn"] else "present")}

static func record_river_bridge(path: String, board) -> bool:
	var record := load_record(path)
	var entry := river_bridge_entry(board)
	var previous: Dictionary = record["missions"].get(2,{})
	var comparable: Dictionary = previous.duplicate()
	comparable.erase("attempts")
	if var_to_str(comparable) == var_to_str(entry): return false
	entry["attempts"] = previous.get("attempts",0)+1
	record["missions"][2] = entry
	save_record(path,record)
	return true

static func carry_forward_river(entry: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if entry.is_empty(): return lines
	if entry["retry_required"]:
		lines.append("River Bridge: MSG lost. Retry the mission.")
		return lines
	lines.append("River Bridge: %d of 12 civilians across. They corroborate it: machines went around people, Greys went for them." % entry["evacuated"])
	lines.append("Supplies %s (%s)." % ["kept: the heavy lane got the trucks across" if entry["supplies"] == "kept" else "lost: the trucks turned back so people could cross", "lanes: " + (entry["lanes"] if entry["lanes"] != "" else "never set")])
	lines.append("Damaged sensor %s." % ("recovered: better intel confidence for Main Street (Mission 03)" if entry["sensor"] else "left in the reeds"))
	if not entry["taken"].is_empty():
		lines.append("Taken by the Greys: group %s. Named and unresolved; a rescue opportunity at Rail Yard (Mission 05)." % ", ".join(entry["taken"]))
	if entry["craft_shield"]:
		lines.append("An unidentified craft spent its shield and left damaged. Verified later at the Regional Airfield (Mission 08).")
	return lines

## What carries into later missions, in plain language. Effects past Mission 01 are
## planned in the GDD and will apply as those missions are built.
static func carry_forward(entry: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if entry.is_empty():
		lines.append("Nothing recorded yet. Finish Mission 01 and the results carry forward here.")
		return lines
	if entry["retry_required"]:
		lines.append("MSG lost: this attempt can't continue the campaign. Retry Farm Road.")
		return lines
	match entry["machine"]:
		"destroyed": lines.append("Machine destroyed. The fast route opened, but its cooling unit is gone: no cooling-assisted route when the squad returns to Farm Road, and no preserved rig to call on later.")
		"disabled": lines.append("Drive isolated. The machine is intact but dead; two repairs on the return wake its cooling route. The Drive Rig can come back at Quarry (Mission 07).")
		"diverted": lines.append("Machine diverted through the console. The feeder stayed up for the people below, and its cooling route is ready on the return. The Drive Rig can come back at Quarry (Mission 07).")
		"departed": lines.append("The machine left with nothing resolved. No benefit on the return; its purpose stays unconfirmed.")
		_: lines.append("The machine was still working when the squad withdrew.")
	if entry["acknowledged"]:
		lines.append("ACK-01: the machine answered a bounded signal. That repeatable test is why Ward authorizes an assessment patrol, and it's the first thread to the warning's sender (Interchange, Mission 04).")
	else:
		lines.append("No acknowledgement recorded. The warning's sender is still unverified, and Ward has less to justify a patrol.")
	var stranded: int = 12-entry["evacuated"]
	lines.append("%d of 12 civilians evacuated. They're witnesses for the River Bridge crossing (Mission 02)%s." % [entry["evacuated"],"" if stranded == 0 else "; %d stranded stay on the record as unconfirmed, not erased" % stranded])
	var lost: Array[String] = []
	var hurt: Array[String] = []
	for soldier in entry["squad"]:
		if soldier["condition"] == "dead": lost.append(soldier["name"])
		elif soldier["condition"] in ["critical","stable"]: hurt.append(soldier["name"])
	if not lost.is_empty(): lines.append("Lost: %s. Permadeath; their absence carries into every later scene." % ", ".join(lost))
	if not hurt.is_empty(): lines.append("Wounded: %s. Injuries carry into the next deployment." % ", ".join(hurt))
	return lines

## What the task force knows after Mission 01, separating observation from assessment.
static func knowledge(entry: Dictionary) -> Array[String]:
	var lines: Array[String] = ["OBSERVED: 09:17, a vertical distortion crossed the northern ridge. Power tripped; radio recordings lost eleven seconds.",
		"OBSERVED: a machine came through the old service gate beneath Farm Road and went for the pump skid, bypassing soldiers on the way."]
	if entry.get("acknowledged",false):
		lines.append("OBSERVED: the machine paused on a bounded signal (ACK-01). That proves limited protocol access, not an alliance.")
	lines.append("ASSESSMENT, unconfirmed: the machines may be recovering equipment, not attacking.")
	lines.append("OPEN: who sent the warning? 'Clear the service lane. Do not cut the buried feeder. People below need that power.'")
	lines.append("OFFICIAL LINE: one coordinated invasion. Act I ends when the squad has the evidence to reject it.")
	return lines
