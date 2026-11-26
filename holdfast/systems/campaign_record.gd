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

## Mission 03 entry built from a finished Main Street board.
static func main_street_entry(board) -> Dictionary:
	var squad: Array = []
	for index in range(board.soldiers.size()):
		var soldier: Dictionary = board.soldiers[index]
		squad.append({"name":soldier["name"],"condition":soldier.get("condition","active"),"extracted":soldier["extracted"],"disposition":board.soldier_disposition(index)})
	var groups: Array = []
	for cohort in board.cohorts:
		groups.append({"id":cohort["id"],"status":cohort["status"]})
	return {"mission":3,"retry_required":board.retry_required(),"round":board.phase,"end_reason":board.end_reason,
		"evacuated":board.evacuated_people(),"groups":groups,"squad":squad,"platform":board.platform_state(),
		"component":board.drover["recovered"],"rifts":board.fallow["rifts"].size(),
		"interrupts":board.fallow["interrupts"],"cutter_down":board.fallow["log"].has("cutter_down")}

static func record_main_street(path: String, board) -> bool:
	var record := load_record(path)
	var entry := main_street_entry(board)
	var previous: Dictionary = record["missions"].get(3,{})
	var comparable: Dictionary = previous.duplicate()
	comparable.erase("attempts")
	if var_to_str(comparable) == var_to_str(entry): return false
	entry["attempts"] = previous.get("attempts",0)+1
	record["missions"][3] = entry
	save_record(path,record)
	return true

## Mission 04 entry built from a finished Interchange board.
static func interchange_entry(board) -> Dictionary:
	var squad: Array = []
	for index in range(board.soldiers.size()):
		var soldier: Dictionary = board.soldiers[index]
		squad.append({"name":soldier["name"],"condition":soldier.get("condition","active"),"extracted":soldier["extracted"],"disposition":board.soldier_disposition(index)})
	var groups: Array = []
	for cohort in board.cohorts:
		groups.append({"id":cohort["id"],"status":cohort["status"]})
	var tally: Dictionary = board.security_tally()
	return {"mission":4,"retry_required":board.retry_required(),"round":board.phase,"end_reason":board.end_reason,
		"evacuated":board.evacuated_people(),"groups":groups,"squad":squad,"agreement":board.agreement(),
		"breach":board.crew["breach"],"component_returned":board.crew["log"].has("component_returned"),
		"drone":board.drone["outcome"],"security":tally,"cargo":board.crew["cargo"],
		"supplies":"gained" if board.crew["cargo"] == "seized" else "none"}

static func record_interchange(path: String, board) -> bool:
	var record := load_record(path)
	var entry := interchange_entry(board)
	var previous: Dictionary = record["missions"].get(4,{})
	var comparable: Dictionary = previous.duplicate()
	comparable.erase("attempts")
	if var_to_str(comparable) == var_to_str(entry): return false
	entry["attempts"] = previous.get("attempts",0)+1
	record["missions"][4] = entry
	save_record(path,record)
	return true

static func field_contact(entry: Dictionary) -> bool:
	return not entry.is_empty() and not entry["retry_required"] and ["honored","honored_greys_attributed","greys_attributed","expired"].has(entry["agreement"])

static func carry_forward_interchange(entry: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if entry.is_empty(): return lines
	if entry["retry_required"]:
		lines.append("Interchange: MSG lost. Retry the mission.")
		return lines
	lines.append("Interchange: %d of 12 civilians through the junction." % entry["evacuated"])
	if field_contact(entry):
		lines.append("The local agreement held. Ward designates MSG field contact for limited Drover agreements; Kesh is on the channel. County Hospital (Mission 06) offers a monitored Drover passage.")
	elif entry["agreement"] == "breached_greys":
		lines.append("Unseen Grey fire broke the pause and the Drovers blamed the squad. No field contact yet; at County Hospital (Mission 06) the Drover convoy contests the road.")
	else:
		lines.append("No agreement (%s). No field contact yet; at County Hospital (Mission 06) the Drover convoy contests the road." % str(entry["agreement"]).replace("_"," "))
	var tally: Dictionary = entry["security"]
	if tally["restrained"] > 0: lines.append("%d Drover security held alive. Returning them later is a gesture the stewards will notice." % tally["restrained"])
	if tally["killed"] > 0: lines.append("%d Drover security killed. That can't be returned." % tally["killed"])
	if entry["cargo"] == "seized": lines.append("Cargo seized: supplies for Ward, and a missing ark component the Drovers will need repaired at Quarry (Mission 07).")
	if entry["component_returned"]: lines.append("Main Street component returned: a returned-goods gesture on the record.")
	if ["observed","shot","shot_after","downed_by_drovers"].has(entry["drone"]):
		lines.append("Grey drone %s: first verified evidence that the Greys monitor the other factions. It feeds the Rail Yard (Mission 05) records." % {"observed":"observed","shot":"shot down","shot_after":"shot down","downed_by_drovers":"downed by the Drovers"}[entry["drone"]])
	return lines

## Mission 05 entry built from a finished Rail Yard board.
static func rail_yard_entry(board) -> Dictionary:
	var squad: Array = []
	for index in range(board.soldiers.size()):
		var soldier: Dictionary = board.soldiers[index]
		squad.append({"name":soldier["name"],"condition":soldier.get("condition","active"),"extracted":soldier["extracted"],"disposition":board.soldier_disposition(index)})
	var groups: Array = []
	for cohort in board.cohorts:
		groups.append({"id":cohort["id"],"status":cohort["status"],"origin":cohort.get("origin","")})
	return {"mission":5,"retry_required":board.retry_required(),"round":board.phase,"end_reason":board.end_reason,
		"evacuated":board.evacuated_people(),"groups":groups,"squad":squad,"aboard":board.yard["aboard"].duplicate(),
		"archive":board.archive["state"],"supplies":"generator cells" if board.handcar["out"] else "none",
		"trade":board.trade_result(),"trade_broken_by":board.yard["trade"]["broken_by"],"greys_down":board.greys_down()}

static func record_rail_yard(path: String, board) -> bool:
	var record := load_record(path)
	var entry := rail_yard_entry(board)
	var previous: Dictionary = record["missions"].get(5,{})
	var comparable: Dictionary = previous.duplicate()
	comparable.erase("attempts")
	if var_to_str(comparable) == var_to_str(entry): return false
	entry["attempts"] = previous.get("attempts",0)+1
	record["missions"][5] = entry
	save_record(path,record)
	return true

static func carry_forward_rail(entry: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if entry.is_empty(): return lines
	if entry["retry_required"]:
		lines.append("Rail Yard: MSG lost. Retry the mission.")
		return lines
	lines.append("Rail Yard: %d of 12 captives freed and out." % entry["evacuated"])
	for group in entry["groups"]:
		if group["status"] == "extracted" and str(group["origin"]).begins_with("River Bridge"):
			lines.append("%s is back. The River Bridge thread is closed." % group["origin"])
	if not entry["aboard"].is_empty():
		lines.append("Aboard the Grey transport: group %s. Named and in custody; a rescue option at the Regional Airfield (Mission 08)." % ", ".join(entry["aboard"]))
	match entry["archive"]:
		"full": lines.append("Full Grey archive: resource accounting and files on every faction. Ward accepts the separate-threats assessment, and the Grey intel line opens at the Airfield (Mission 08).")
		"partial": lines.append("Survey records from the trade: useful for Quarry (Mission 07) planning, no faction evidence.")
	if entry["supplies"] != "none": lines.append("Generator cells recovered: one extra powered system at County Hospital (Mission 06).")
	if entry["trade"] == "broken": lines.append("The squad broke the Grey trade (%s). The record names it." % entry["trade_broken_by"])
	elif entry["trade"] == "honored": lines.append("The Grey trade was honored on both sides: exactly what was promised, and nothing about the pens.")
	return lines

## Mission 06 entry built from a finished County Hospital board.
static func county_hospital_entry(board) -> Dictionary:
	var squad: Array = []
	for index in range(board.soldiers.size()):
		var soldier: Dictionary = board.soldiers[index]
		squad.append({"name":soldier["name"],"condition":soldier.get("condition","active"),"extracted":soldier["extracted"],"disposition":board.soldier_disposition(index)})
	var groups: Array = []
	for cohort in board.cohorts:
		groups.append({"id":cohort["id"],"status":cohort["status"],"origin":cohort.get("origin","")})
	var Screening = load("res://systems/screening.gd")
	var on: Array = []
	for key in ["ambulance","scanner","lights"]:
		if board.power["on"][key]: on.append(key)
	return {"mission":6,"retry_required":board.retry_required(),"round":board.phase,"end_reason":board.end_reason,
		"evacuated":board.evacuated_people(),"groups":groups,"squad":squad,"ambulance":board.ambulance["trips"].duplicate(),
		"power":on,"capacity":board.power["base"]+board.power["rail"]+board.power["coupling"],
		"infiltrator":Screening.result(board.screening,board),"false_detentions":board.screening["false_detentions"].duplicate(),
		"convoy":board.convoy["choice"],"taken":board.reptilians["taken"].duplicate(),"team_dead":board.team_dead(),
		"critical_out":board.cohorts[board.GURNEY_GROUP]["status"] == "extracted"}

static func record_county_hospital(path: String, board) -> bool:
	var record := load_record(path)
	var entry := county_hospital_entry(board)
	var previous: Dictionary = record["missions"].get(6,{})
	var comparable: Dictionary = previous.duplicate()
	comparable.erase("attempts")
	if var_to_str(comparable) == var_to_str(entry): return false
	entry["attempts"] = previous.get("attempts",0)+1
	record["missions"][6] = entry
	save_record(path,record)
	return true

static func carry_forward_hospital(entry: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if entry.is_empty(): return lines
	if entry["retry_required"]:
		lines.append("County Hospital: MSG lost. Retry the mission.")
		return lines
	lines.append("County Hospital: %d of 12 out%s." % [entry["evacuated"],"" if entry["ambulance"].is_empty() else ", group %s by ambulance" % ", ".join(entry["ambulance"])])
	lines.append("Critical patients out: the base keeps its medical capacity." if entry["critical_out"] else "Critical patients lost or left: medical capacity at the base is degraded.")
	match entry["infiltrator"]:
		"contained": lines.append("Infiltrator contained on corroborated evidence. The harvest files open the Civic Center network (Mission 09).")
		"detained_thin": lines.append("Infiltrator held on thin evidence. The harvest files open the Civic Center network (Mission 09), and the method is on the record.")
		"reached_base": lines.append("An undetected infiltrator reached the base with their group. Later base scenes and the Civic Center briefing change.")
		_: lines.append("The infiltrator was never identified.")
	if not entry["false_detentions"].is_empty(): lines.append("Falsely detained: %s. Their names are on the record." % ", ".join(entry["false_detentions"]))
	match entry["convoy"]:
		"monitored": lines.append("Drover convoy passed under watch: a kept route the stewards will remember at Quarry (Mission 07).")
		"reserved": lines.append("Road reserved for people. Kesh noted the refusal.")
		"contested": lines.append("The convoy forced the road: a grievance on both sides.")
	if not entry["taken"].is_empty(): lines.append("Taken by the Reptilians: group %s. Named, unresolved." % ", ".join(entry["taken"]))
	if not entry["team_dead"].is_empty(): lines.append("Guard Team Marsh lost %s." % ", ".join(entry["team_dead"]))
	return lines

## Mission 07 entry built from a finished Quarry board.
static func quarry_entry(board) -> Dictionary:
	var squad: Array = []
	for index in range(board.soldiers.size()):
		var soldier: Dictionary = board.soldiers[index]
		squad.append({"name":soldier["name"],"condition":soldier.get("condition","active"),"extracted":soldier["extracted"],"disposition":board.soldier_disposition(index)})
	var groups: Array = []
	for cohort in board.cohorts:
		groups.append({"id":cohort["id"],"status":cohort["status"],"origin":cohort.get("origin","")})
	var Works = load("res://systems/quarry_works.gd")
	return {"mission":7,"retry_required":board.retry_required(),"round":board.phase,"end_reason":board.end_reason,
		"evacuated":board.evacuated_people(),"groups":groups,"squad":squad,"platform":Works.platform_state(board.works),
		"habitat":Works.habitat(board.works),"controller":board.works["controller"],"lost_in_collapse":board.works["lost"].duplicate(),
		"rig":"absent" if not board.rig["present"] else ("dug" if board.rig["dug"] > 0 else "present"),
		"rifts":board.fallow["rifts"].size(),"plan":board.plan_name()}

static func record_quarry(path: String, board) -> bool:
	var record := load_record(path)
	var entry := quarry_entry(board)
	var previous: Dictionary = record["missions"].get(7,{})
	var comparable: Dictionary = previous.duplicate()
	comparable.erase("attempts")
	if var_to_str(comparable) == var_to_str(entry): return false
	entry["attempts"] = previous.get("attempts",0)+1
	record["missions"][7] = entry
	save_record(path,record)
	return true

static func act_two_complete(record: Dictionary) -> bool:
	var entry: Dictionary = record["missions"].get(7,{})
	return not entry.is_empty() and not entry["retry_required"]

static func carry_forward_quarry(entry: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if entry.is_empty(): return lines
	if entry["retry_required"]:
		lines.append("Quarry: MSG lost. Retry the mission.")
		return lines
	lines.append("Quarry: %d of 12 out%s." % [entry["evacuated"],"" if entry["lost_in_collapse"].is_empty() else "; group %s lost in the tunnel collapse" % ", ".join(entry["lost_in_collapse"])])
	match entry["habitat"]:
		"lost": lines.append("The platform was demolished and the habitat it powered is gone, with its ecological reserve. That's permanent: the Dam (Mission 10) and the ark remember it, and Kesh's terms harden.")
		"strained": lines.append("Platform isolated: the habitat survives on reserve. The Dam (Mission 10) opens with a repair objective.")
		"powered": lines.append("The habitat kept its power%s. The best terms at the Dam (Mission 10)." % (", and the controller authenticates a partial channel there" if entry["controller"] else ""))
	lines.append("ACT II COMPLETE: separate threats, separate objectives. Act III, The Enemy of My Enemy, starts at the Regional Airfield (Mission 08).")
	return lines

## Mission 08 entry built from a finished Regional Airfield board.
static func airfield_entry(board) -> Dictionary:
	var squad: Array = []
	for index in range(board.soldiers.size()):
		var soldier: Dictionary = board.soldiers[index]
		squad.append({"name":soldier["name"],"condition":soldier.get("condition","active"),"extracted":soldier["extracted"],"disposition":board.soldier_disposition(index)})
	var groups: Array = []
	for cohort in board.cohorts:
		groups.append({"id":cohort["id"],"status":cohort["status"],"origin":cohort.get("origin","")})
	return {"mission":8,"retry_required":board.retry_required(),"round":board.phase,"end_reason":board.end_reason,
		"evacuated":board.evacuated_people(),"groups":groups,"squad":squad,"contact":board.craft["contact"],
		"craft_verified":board.craft["contact"] and board.craft["river_shield"],"charges_left":board.craft["charges"],
		"sensor_data":board.craft["data"],"aircraft":board.aircraft_state(),"runway":"ruined" if board.runway_ruined() else "clear",
		"bargain":board.strip["bargain"]["state"],"captives_freed":board.pod["active"] and board.pod["open"],
		"captives":board.pod["origin"],"rifts":board.fallow["rifts"].size(),"team":board.team["name"],"team_dead":board.team_dead()}

static func record_airfield(path: String, board) -> bool:
	var record := load_record(path)
	var entry := airfield_entry(board)
	var previous: Dictionary = record["missions"].get(8,{})
	var comparable: Dictionary = previous.duplicate()
	comparable.erase("attempts")
	if var_to_str(comparable) == var_to_str(entry): return false
	entry["attempts"] = previous.get("attempts",0)+1
	record["missions"][8] = entry
	save_record(path,record)
	return true

static func carry_forward_airfield(entry: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if entry.is_empty(): return lines
	if entry["retry_required"]:
		lines.append("Regional Airfield: MSG lost. Retry the mission.")
		return lines
	lines.append("Regional Airfield: %d of 12 out by the north-west ground route." % entry["evacuated"])
	if entry["aircraft"] == "intact" and entry["runway"] == "clear": lines.append("Transport plane and runway preserved: air support later at the Mountain Pass and the Valley.")
	else: lines.append("No air support later (plane %s, runway %s). The ground route remains." % [entry["aircraft"],entry["runway"]])
	if entry["contact"]: lines.append("Nordic contact made%s: Custodian Aven's line is open for the ark parley (Mission 11)." % (", and the River Bridge craft verified" if entry["craft_verified"] else ""))
	else: lines.append("The Nordic contact window closed unanswered.")
	if entry["sensor_data"]: lines.append("Nordic sensor data: the scale of the Fallow, and how few rescue ships exist. The turn toward evacuation starts here.")
	if entry["captives_freed"]: lines.append("%s freed. The Rail Yard custody thread is closed." % str(entry["captives"]).replace(" (in Grey custody)",""))
	if not entry["team_dead"].is_empty(): lines.append("%s lost %s." % [entry["team"],", ".join(entry["team_dead"])])
	return lines

## Mission 09 entry built from a finished Civic Center board.
static func civic_center_entry(board) -> Dictionary:
	var squad: Array = []
	for index in range(board.soldiers.size()):
		var soldier: Dictionary = board.soldiers[index]
		squad.append({"name":soldier["name"],"condition":soldier.get("condition","active"),"extracted":soldier["extracted"],"disposition":board.soldier_disposition(index)})
	var groups: Array = []
	for cohort in board.cohorts:
		groups.append({"id":cohort["id"],"status":cohort["status"],"origin":cohort.get("origin","")})
	return {"mission":9,"retry_required":board.retry_required(),"round":board.phase,"end_reason":board.end_reason,
		"evacuated":board.evacuated_people(),"groups":groups,"squad":squad,"records":board.records["done"],
		"detainees":board.detainee_state(),"council_out":board.cohorts[board.COUNCIL_GROUP]["status"] == "extracted",
		"vehicles":board.mortar["vehicles"],"alarm_round":board.alarm_round(),"alarm_cause":board.garrison["alarm_cause"],
		"troopers_down":board.troopers_down(),"cover_lost":board.garrison["cover_lost"],"taken":board.garrison["taken"].duplicate()}

static func record_civic_center(path: String, board) -> bool:
	var record := load_record(path)
	var entry := civic_center_entry(board)
	var previous: Dictionary = record["missions"].get(9,{})
	var comparable: Dictionary = previous.duplicate()
	comparable.erase("attempts")
	if var_to_str(comparable) == var_to_str(entry): return false
	entry["attempts"] = previous.get("attempts",0)+1
	record["missions"][9] = entry
	save_record(path,record)
	return true

static func carry_forward_civic(entry: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if entry.is_empty(): return lines
	if entry["retry_required"]:
		lines.append("Civic Center: MSG lost. Retry the mission.")
		return lines
	lines.append("Civic Center: %d of 12 out." % entry["evacuated"])
	if entry["records"]: lines.append("Infiltration records recovered: an old network exposed and purged, and proof of the Reptilian split. Ward's credibility rises; it strengthens the human representatives at the ark parley (Mission 11).")
	else: lines.append("No records: surviving institutions are weaker, and there are fewer human seats at the parley.")
	if entry["council_out"] and entry["vehicles"] >= 2: lines.append("The council got out with the convoy (%d of 3 vehicles): civilian leadership survives to approve evacuation terms at the ark." % entry["vehicles"])
	elif entry["council_out"]: lines.append("The council got out, but the convoy was mauled (%d of 3 vehicles)." % entry["vehicles"])
	else: lines.append("The council didn't make the convoy. Civilian leadership is thin.")
	match entry["detainees"]:
		"freed": lines.append("Detainees freed and out, by name.")
		"moved out": lines.append("The extraction faction moved the detainees out through the tunnel. Named; unresolved.")
		_: lines.append("Detainees left in the facility: %s." % entry["detainees"])
	return lines

static func act_one_complete(record: Dictionary) -> bool:
	var entry: Dictionary = record["missions"].get(3,{})
	return not entry.is_empty() and not entry["retry_required"]

static func carry_forward_main(entry: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	if entry.is_empty(): return lines
	if entry["retry_required"]:
		lines.append("Main Street: MSG lost. Retry the mission.")
		return lines
	lines.append("Main Street: %d of 12 civilians out of town." % entry["evacuated"])
	match entry["platform"]:
		"demolished": lines.append("Platform demolished. The street opened fast; nothing was preserved, and the Drovers will remember that at Interchange (Mission 04).")
		"isolated": lines.append("Platform isolated at the junction box, intact. Better footing with the Drovers at Interchange (Mission 04).")
		"redirected": lines.append("Platform redirected and parked across the alley. Its work order (substation coolant maintenance) is on record. Best footing with the Drovers at Interchange (Mission 04).")
		"substation": lines.append("Platform reached the substation and the corridor lost power.")
		_: lines.append("Platform still moving when the squad withdrew.")
	if entry["component"]: lines.append("Drover component recovered: evidence, and leverage or a returned-goods gesture at Interchange (Mission 04).")
	lines.append("Fallow: %d squares of rift ground%s%s." % [entry["rifts"],", node interrupted %d time%s" % [entry["interrupts"],"" if entry["interrupts"] == 1 else "s"] if entry["interrupts"] > 0 else "",", cutter killed" if entry["cutter_down"] else ""])
	lines.append("ACT I COMPLETE: the single-command hypothesis is rejected. Ward accepts the local assessment and asks for independent corroboration.")
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
