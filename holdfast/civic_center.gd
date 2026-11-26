extends "res://encounter_controller.gd"
## Mission 09 · Civic Center (spec: docs/missions/civic-center.md). Act III.
## A Reptilian-held civic center: the council in the chambers, civilians in the atrium,
## detainees in a concealed holding facility, a human convoy at the east gate. Reconnaissance
## (Scout, hidden units, last-known markers), alternate access (the service door), cover
## destruction (entrenched troopers and the mortar) and a withdrawal trigger (the alarm, which
## splits the garrison). The Farm Road machine is switched off. Save/load comes later.
const CivicMission = preload("res://missions/civic_center.tres")
const Garrison = preload("res://systems/reptilian_garrison.gd")
const Mortar = preload("res://systems/plasma_mortar.gd")
const CampaignRecord = preload("res://systems/campaign_record.gd")

const TERMINAL := Vector2i(12,3)
const SERVICE_DOOR := Vector2i(5,7)
const HATCH := Vector2i(14,10)
const PEN := Vector2i(17,10)
const PEN_GROUP := 2
const COUNCIL_GROUP := 0
const SPOTTER := Vector2i(18,3)
const CONVOY: Array[Vector2i] = [Vector2i(18,14),Vector2i(19,14)]
const TROOPERS: Array[Vector2i] = [Vector2i(8,8),Vector2i(11,10),Vector2i(12,4),Vector2i(15,9)]
const CONVOY_LEAVES := 6
const RECORD_STEPS := 2
const CUT_AP := 2
const ENGINEER := 2
const SCOUT := 3
const BUILDING_MIN := Vector2i(5,2)
const BUILDING_MAX := Vector2i(19,12)
const REPLACEMENTS := ["Reyes","Okafor","Lindqvist"]

var mission_copy: Resource = null
var record_path := ""
var garrison: Dictionary = {}
var mortar: Dictionary = {}
var records := {"steps":0,"done":false}
var pen := {"cut":0,"open":false}
var hatch_found := false
var door_open := false
var convoy_shield := false
## Carry-ins.
var files := false
var leaked := false
var hospital_taken: Array = []
var aven_charge := false

func mission_definition() -> Resource:
	if mission_override != null: return mission_override
	if mission_copy == null: mission_copy = CivicMission.duplicate(true)
	return mission_copy

func _ready() -> void:
	read_carry_ins()
	initialize_tactical()
	initialize_machine()
	initialize_evacuation()
	initialize_breaker()
	initialize_protocol()
	initialize_rescue()
	initialize_results()
	initialize_story()
	initialize_roster(false)
	report_path = "user://holdfast_m09_result.save"
	completion_path = "user://holdfast_m09_completed.save"
	campaign_path = "user://holdfast_m09_campaign.save"
	garrison = Garrison.initial(TROOPERS,leaked)
	mortar = Mortar.initial(SPOTTER)
	if files:
		open_service_door()
		reveal_hatch()
	cohorts[PEN_GROUP]["penned"] = true
	cohorts[PEN_GROUP]["note"] = "Held in the concealed facility"
	cohorts[0]["origin"] = "The county council"
	cohorts[1]["origin"] = "Civilians held in the atrium"
	cohorts[2]["origin"] = "Detainees" + ("" if hospital_taken.is_empty() else ", including County Hospital group %s" % ", ".join(hospital_taken))
	carry_over_squad()
	status_text = "Civic Center: troopers inside are hidden until you're close or Park scouts. The alarm comes at round %d." % garrison["alarm_round"]
	enemy_message = "No movement at the windows. Two days of silence."
	save_feedback = "Saving isn't available at the civic center yet."
	rebuild_movement()

func read_carry_ins() -> void:
	if record_path == "": return
	var missions: Dictionary = CampaignRecord.load_record(record_path)["missions"]
	var infiltrator: String = missions.get(6,{}).get("infiltrator","")
	files = ["contained","detained_thin"].has(infiltrator)
	leaked = infiltrator == "reached_base"
	hospital_taken = missions.get(6,{}).get("taken",[]).duplicate()
	var field: Dictionary = missions.get(8,{})
	aven_charge = field.get("contact",false) and field.get("charges_left",0) > 0

func carry_over_squad() -> void:
	if record_path == "": return
	var missions: Dictionary = CampaignRecord.load_record(record_path)["missions"]
	var entry: Dictionary = {}
	for id in [8,7,6,5,4,3,2,1]:
		if missions.get(id,{}).has("squad"):
			entry = missions[id]
			break
	if entry.is_empty(): return
	var count := mini(entry["squad"].size(),soldiers.size())
	for index in range(1,count):
		var previous: Dictionary = entry["squad"][index]
		if previous["condition"] != "dead" and previous.has("name"):
			soldiers[index]["name"] = previous["name"]
			soldiers[index]["mark"] = previous["name"].left(1)
		if previous["condition"] in ["critical","stable"]: soldiers[index]["hp"] = 4
	for index in range(1,count):
		if entry["squad"][index]["condition"] != "dead": continue
		var taken: Array = soldiers.map(func(soldier): return soldier["name"])
		for pick in REPLACEMENTS:
			if taken.has(pick): continue
			soldiers[index]["name"] = pick
			soldiers[index]["mark"] = pick.left(1)
			soldiers[index]["replacement_for"] = entry["squad"][index].get("name","")
			break

# ---------------------------------------------------------------- map rules

func cohort_at(cell: Vector2i) -> int:
	for index in range(cohorts.size()):
		if cohorts[index]["status"] == "active" and cohorts[index]["cell"] == cell: return index
	return -1

func inside(cell: Vector2i) -> bool:
	return cell.x >= BUILDING_MIN.x and cell.x <= BUILDING_MAX.x and cell.y >= BUILDING_MIN.y and cell.y <= BUILDING_MAX.y

func target_at(cell: Vector2i) -> int:
	if not garrison.is_empty():
		var index := Garrison.unit_at(garrison,cell)
		if index >= 0: return 10+index
	if not mortar.is_empty() and not Mortar.silenced(mortar) and mortar["spotter"]["cell"] == cell: return 30
	return -1

func civilian_safe(cell: Vector2i) -> bool:
	if not cell_is_in_bounds(cell) or WALL_CELLS.has(cell) or FIXTURES.has(cell): return false
	return target_at(cell) < 0

func civilian_waypoint(_order: String) -> Vector2i:
	return civilian_exit()

func route_label(_order: String) -> String:
	return "East gate"

func on_civilian_step(_cohort: Dictionary, _cell: Vector2i) -> void:
	pass

func move_cohort(cohort: Dictionary, budget: int) -> void:
	if cohort.get("penned",false): return
	super.move_cohort(cohort,budget)
	# The council boarding at the gate sends the convoy off.
	if cohorts.find(cohort) == COUNCIL_GROUP and cohort["status"] == "extracted" and mortar["convoy"] == "waiting":
		mortar["convoy"] = "departed"
		mortar["log"].append("convoy_departed:%d" % phase)

func resolve_civilian_phase() -> void:
	var held: Array = []
	for cohort in cohorts:
		if cohort.get("penned",false) and cohort["status"] == "active":
			cohort["status"] = "held"
			held.append(cohort)
	super.resolve_civilian_phase()
	for cohort in held: cohort["status"] = "active"

func civilian_threats() -> Array[Vector2i]:
	var threats: Array[Vector2i] = []
	for entry in garrison["units"]:
		if Garrison.visible(entry,self): threats.append(entry["cell"])
		if not entry["aim"].is_empty(): threats.append(entry["aim"]["cell"])
	if mortar["mark"] != NONE: threats.append(mortar["mark"])
	threats.append_array(round_noise)
	return threats

func deadline() -> int:
	return mission_definition().closing_round

func mission_completion_reason(round_number: int) -> String:
	return MissionObjectives.completion_reason(mission_definition(),round_number,0,all_extracted(),remaining_civilians())

func destroy_cover(cell: Vector2i) -> void:
	mission_definition().cover_edges.erase(cell)

func cover_in_sight(from: Vector2i) -> Vector2i:
	for cell in mission_definition().cover_edges.keys():
		if Garrison.distance(cell,from) > Garrison.FIRE_RANGE: continue
		if sight_preview(from,cell)["clear"]: return cell
	return NONE

func mortar_target() -> Vector2i:
	var best := NONE
	var best_gap := 1000
	for index in range(soldiers.size()):
		if not soldier_can_act(index): continue
		var gap := Garrison.distance(soldiers[index]["cell"],SPOTTER)
		if gap < best_gap:
			best_gap = gap
			best = soldiers[index]["cell"]
	return best

func convoy_shielded() -> bool:
	return convoy_shield

func open_service_door() -> void:
	door_open = true
	mission_definition().fixtures.erase(SERVICE_DOOR)

func reveal_hatch() -> void:
	hatch_found = true
	mission_definition().fixtures.erase(HATCH)

func alarm(cause: String) -> String:
	return Garrison.raise_alarm(garrison,cause,self)

# ---------------------------------------------------------------- actions

func reject(text: String) -> bool:
	status_text = text
	queue_redraw()
	return false

func ready_reason(cost: int = 1) -> String:
	if ended: return "Operation over."
	if not soldier_can_act(active_soldier): return "Select a standing soldier."
	if soldiers[active_soldier].get("carrying",-1) >= 0: return "Put the casualty down first."
	if soldiers[active_soldier]["ap"] < cost: return "Needs %d AP." % cost
	return ""

func next_to(cell: Vector2i) -> bool:
	return soldier_can_act(active_soldier) and Garrison.distance(soldiers[active_soldier]["cell"],cell) == 1

func scout_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if active_soldier != SCOUT: return "%s scouts. Select %s." % [soldiers[SCOUT]["name"],soldiers[SCOUT]["name"]]
	return ""

func scout() -> bool:
	var reason := scout_reason()
	if reason != "": return reject(reason)
	soldiers[SCOUT]["ap"] -= 1
	var found := Garrison.scout(garrison,soldiers[SCOUT]["cell"])
	var hatch_line := ""
	if not hatch_found and Garrison.distance(soldiers[SCOUT]["cell"],HATCH) <= Garrison.SCOUT_RANGE:
		reveal_hatch()
		hatch_line = " A seam in the east-wing wall: a concealed hatch at (%d,%d)." % [HATCH.x,HATCH.y]
	status_text = "%s scouts: %d trooper%s marked.%s" % [soldiers[SCOUT]["name"],found,"" if found == 1 else "s",hatch_line]
	rebuild_movement()
	return true

func door_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if door_open: return "The service door is open."
	if not next_to(SERVICE_DOOR): return "Stand next to the service door (%d,%d)." % [SERVICE_DOOR.x,SERVICE_DOOR.y]
	return ""

func force_door() -> bool:
	var reason := door_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	open_service_door()
	round_noise.append(SERVICE_DOOR)
	status_text = "%s forces the service door. The west corridor is open." % soldiers[active_soldier]["name"]
	rebuild_movement()
	return true

func records_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if records["done"]: return "Records already downloaded."
	if not next_to(TERMINAL): return "Stand next to the chambers terminal (%d,%d)." % [TERMINAL.x,TERMINAL.y]
	return ""

func download_records() -> bool:
	var reason := records_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	records["steps"] += 1
	var line := alarm("records terminal")
	if records["steps"] >= RECORD_STEPS:
		records["done"] = true
		status_text = "Records copied: an infiltration network decades old, and orders showing the garrison split after their extraction facility failed. %s" % line
	else:
		status_text = "Records download %d/%d. %s" % [records["steps"],RECORD_STEPS,line]
	rebuild_movement()
	return true

func pen_next_to() -> bool:
	return not pen["open"] and cohorts[PEN_GROUP]["status"] == "active" and cohorts[PEN_GROUP].get("penned",false) and next_to(PEN)

func free_detainees(how: String) -> void:
	pen["open"] = true
	var cohort: Dictionary = cohorts[PEN_GROUP]
	cohort["penned"] = false
	cohort["order"] = "north"
	cohort["panic"] = maxi(cohort.get("panic",0),1)
	cohort["note"] = "Freed; heading for the east gate"
	garrison["load"] = 0
	var line := alarm("holding pen")
	status_text = "%s %s the holding pen. %s %s" % [soldiers[active_soldier]["name"],how,cohort["origin"],line]

func bypass_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if active_soldier != ENGINEER: return "%s bypasses the lock. Anyone can cut it." % soldiers[ENGINEER]["name"]
	if not pen_next_to(): return "Stand next to the holding pen (%d,%d)." % [PEN.x,PEN.y]
	return ""

func bypass_pen() -> bool:
	var reason := bypass_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	free_detainees("bypasses the lock on")
	rebuild_movement()
	return true

func cut_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if not pen_next_to(): return "Stand next to the holding pen (%d,%d)." % [PEN.x,PEN.y]
	return ""

func cut_pen() -> bool:
	var reason := cut_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	pen["cut"] += 1
	if pen["cut"] >= CUT_AP: free_detainees("cuts open")
	else: status_text = "%s starts cutting the pen: 1 more AP." % soldiers[active_soldier]["name"]
	rebuild_movement()
	return true

func shield_reason() -> String:
	if not aven_charge: return "No Nordic charge to call on (needs Airfield contact and a charge left)."
	if convoy_shield: return "The convoy is already shielded."
	var reason := ready_reason()
	if reason != "": return reason
	if active_soldier != 0: return "MSG calls Aven. Select MSG."
	return ""

func shield_convoy() -> bool:
	var reason := shield_reason()
	if reason != "": return reject(reason)
	soldiers[0]["ap"] -= 1
	convoy_shield = true
	status_text = "Aven answers: ‘One charge. The convoy.’ A shimmer settles over the vehicles at the gate."
	rebuild_movement()
	return true

func fire_block_reason() -> String:
	if ended: return "Operation ended."
	if not soldier_can_act(active_soldier): return "Select a standing soldier."
	var soldier: Dictionary = soldiers[active_soldier]
	if soldier.get("carrying",-1) >= 0: return "Cannot fire while carrying a casualty."
	if soldier["ap"] < 1: return "No AP left."
	if soldier["attacked"]: return "Already fired this round."
	if soldier["ammo"] < 1: return "Out of ammunition: reload."
	var cell := sight_target()
	var index := Garrison.unit_at(garrison,cell)
	var spotter: bool = not Mortar.silenced(mortar) and cell == mortar["spotter"]["cell"]
	if not spotter and (index < 0 or not Garrison.visible(garrison["units"][index],self)): return "Aim [T], then click a trooper you can see, or the mortar spotter."
	if not sight_preview(soldier["cell"],cell)["can_fire"]: return "No clear shot at that range."
	return ""

func try_fire() -> bool:
	var reason := fire_block_reason()
	if reason != "": return reject(reason)
	var soldier: Dictionary = soldiers[active_soldier]
	var target := sight_target()
	var info := sight_preview(soldier["cell"],target)
	soldier["ap"] -= 1
	soldier["ammo"] -= 1
	soldier["attacked"] = true
	round_noise.append(soldier["cell"])
	var line: String = alarm("shot inside") if inside(soldier["cell"]) or inside(target) else ""
	var roll := shot_rng.randi_range(1,100)
	if roll <= info["chance"]:
		var hit: String = Mortar.take_hit(mortar,4) if target == mortar["spotter"]["cell"] else Garrison.take_hit(garrison,Garrison.unit_at(garrison,target))
		status_text = "%s fires (%d%%): %s %s" % [soldier["name"],info["chance"],hit,line]
	else:
		status_text = "%s fires (%d%%) and misses. %s" % [soldier["name"],info["chance"],line]
	if target_at(target) < 0: pinned_target = NONE
	rebuild_movement()
	return true

# ---------------------------------------------------------------- turn

func resolve_enemy_turn() -> void:
	if last_enemy_phase == phase: return
	last_enemy_phase = phase
	var lines: Array[String] = []
	if mortar["convoy"] == "waiting" and phase >= CONVOY_LEAVES:
		mortar["convoy"] = "departed"
		mortar["log"].append("convoy_departed:%d" % phase)
		lines.append("The convoy can't wait any longer. It pulls out of the east gate%s." % ("" if cohorts[COUNCIL_GROUP]["status"] == "extracted" else " without the council"))
	var reptilian := Garrison.act(garrison,self)
	if reptilian != "": lines.append(reptilian)
	if garrison["alarm"]:
		var shell := Mortar.act(mortar,self)
		if shell != "": lines.append(shell)
	Garrison.update_sightings(garrison,self)
	enemy_message = " ".join(lines) if not lines.is_empty() else "Silence inside. Something is listening."
	rebuild_movement()
	check_recovery_failure()
	finalize_result()

func begin_player_phase() -> void:
	super.begin_player_phase()
	Garrison.update_sightings(garrison,self)
	if not garrison["alarm"]: status_text = "Round %d. Quiet inside. The alarm comes at round %d unless you trip it first." % [phase,garrison["alarm_round"]]
	else: status_text = "Round %d. %s" % [phase,enemy_message.left(150)]

func detainee_state() -> String:
	var cohort: Dictionary = cohorts[PEN_GROUP]
	if cohort["status"] == "extracted": return "freed"
	if garrison["moved_out"].has(cohort["id"]): return "moved out"
	if pen["open"]: return "freed, not out"
	return "left in the pen"

func enemy_intent() -> String:
	var parts: Array[String] = []
	parts.append("ALARM (%s)" % garrison["alarm_cause"] if garrison["alarm"] else "No alarm yet (round %d)" % garrison["alarm_round"])
	var seen := 0
	for entry in garrison["units"]: seen += 1 if Garrison.visible(entry,self) else 0
	parts.append("%d trooper%s in sight" % [seen,"" if seen == 1 else "s"])
	if not Mortar.silenced(mortar): parts.append("Mortar " + ("marked (%d,%d)" % [mortar["mark"].x,mortar["mark"].y] if mortar["mark"] != NONE else ("ON THE CONVOY" if mortar["convoy_mark"] else "quiet")))
	else: parts.append("Mortar silenced")
	parts.append("Convoy %s (%d/3)" % [mortar["convoy"],mortar["vehicles"]])
	return " · ".join(parts)

func danger_summary() -> String:
	return "A shot inside, the holding pen or the records terminal trips the alarm early. After it, entrenched troopers shoot cover away and the mortar marks a 3×3 impact a phase ahead."

func machine_outcome() -> String:
	return "Records: %s. Detainees: %s. Convoy: %d of 3 vehicles%s." % ["downloaded" if records["done"] else "not taken",detainee_state(),mortar["vehicles"]," (left without the council)" if cohorts[COUNCIL_GROUP]["status"] != "extracted" else ""]

func feeder_result() -> String:
	var down := {"extraction":0,"territorial":0,"patrol":0}
	for entry in garrison["log"]:
		if entry.begins_with("down:"): down[entry.split(":")[1]] += 1
	return "Alarm: round %s (%s). Troopers down: %d extraction, %d territorial%s. Cover destroyed: %d. Mortar %s." % [str(alarm_round()) if garrison["alarm"] else "never","" if not garrison["alarm"] else garrison["alarm_cause"],down["extraction"],down["territorial"],", %d before the split" % down["patrol"] if down["patrol"] > 0 else "",garrison["cover_lost"],"silenced" if Mortar.silenced(mortar) else "still firing"]

func alarm_round() -> int:
	for entry in garrison["log"]:
		if entry.begins_with("alarm:"): return int(entry.split(":")[1])
	return -1

func troopers_down() -> Dictionary:
	var down := {"extraction":0,"territorial":0,"patrol":0}
	for entry in garrison["log"]:
		if entry.begins_with("down:"): down[entry.split(":")[1]] += 1
	return down

func result_title() -> String:
	if retry_required(): return "ATTEMPT ENDED / RETRY REQUIRED"
	var everyone := evacuated_people() == 12
	for soldier in soldiers:
		everyone = everyone and soldier["extracted"] and soldier["condition"] != "dead"
	return "CIVIC CENTER / CLEARED" if everyone else "CIVIC CENTER / PARTIAL"

# ---------------------------------------------------------------- story

func opening_pages() -> Array:
	return [
		{"speaker":"ACT III · MISSION 09: CIVIC CENTER","text":"The county civic center has been silent for two days. The council is inside, and so is a crowd that came looking for them.\n\nThe building isn't empty. Whatever holds it looks like county staff until it doesn't.","tag":"Council, civilians, detainees · records or convoy"},
		{"speaker":"PARK","text":"‘I can't see them through the glass. Give me a minute up close and I'll mark what's in there.’\n\nBell: ‘There's a service corridor on the west side. Locked, but it's a door.’","tag":"Reconnaissance and alternate access"},
		{"speaker":"WARD / RADIO","text":"‘A convoy's waiting at the east gate for the council. It leaves at round %d whether they're on it or not.’" % CONVOY_LEAVES,"tag":"Protect the departing convoy"}]

func current_pages() -> Array:
	if scene_view == "opening": return opening_pages()
	if scene_view == "debrief": return debrief_pages()
	return log_pages()

func log_pages() -> Array:
	var pages := opening_pages()
	pages.append({"speaker":"INTELLIGENCE / CIVIC CENTER","text":enemy_intent()+"\n\n"+danger_summary(),"tag":"Observation, not doctrine"})
	if result_ready and not retry_required(): pages.append_array(debrief_pages())
	return pages

func debrief_pages() -> Array:
	var out: Array[String] = []
	var left: Array[String] = []
	for cohort in cohorts:
		if cohort["status"] == "extracted": out.append("%s (%s)" % [cohort["id"],cohort["origin"]])
		else: left.append("%s (%s)" % [cohort["id"],cohort["origin"]])
	var pages: Array = [{"speaker":"CIVIC CENTER / VERIFIED FIELD REPORT","text":"Out: %s.\nNot out: %s.\n\n%s\n%s" % [", ".join(out) if not out.is_empty() else "none",", ".join(left) if not left.is_empty() else "none",machine_outcome(),feeder_result()],"tag":"Read to the available survivors"}]
	if records["done"]:
		pages.append({"speaker":"BELL / RECORDS","text":"‘Payroll going back forty years. Names in the county office, the water board, the hospital. And this, from last week: their extraction facility failed, and the garrison split over what to do about it.’","tag":"An old network exposed; the Reptilian split"})
	else:
		pages.append({"speaker":"WARD","text":"‘We don't know who in the county answered to them. So we'll be careful with all of them.’","tag":"Surviving institutions weakened"})
	return pages

func advance_scene() -> void:
	var pages := current_pages()
	if scene_page+1 < pages.size():
		scene_page += 1
		if scene_view == "opening": opening_step = scene_page
	elif scene_view == "opening": finish_opening()
	elif scene_view == "log": toggle_log()
	else: scene_view = ""
	queue_redraw()

func scene_options() -> Array:
	return []

func choose_scene_option(_index: int) -> void:
	pass

# ---------------------------------------------------------------- saves and retry

func save_encounter(_path: String = RETURN_SLOT) -> bool:
	save_feedback = "Saving isn't available at the civic center yet."
	status_text = save_feedback
	queue_redraw()
	return false

func load_encounter(_path: String = RETURN_SLOT) -> bool:
	save_feedback = "Loading isn't available at the civic center yet."
	status_text = save_feedback
	queue_redraw()
	return false

func save_mission_result() -> void:
	result_feedback = "Mission recorded in the campaign record."

func persist_campaign_result() -> void:
	pass

func commit_roster() -> void:
	pass

func persist_story_report() -> void:
	pass

func restart_attempt() -> void:
	var fresh = load("res://civic_center.tscn").instantiate()
	fresh.auto_resume = false
	fresh.record_path = record_path
	get_parent().add_child(fresh)
	queue_free()

# ---------------------------------------------------------------- drawing (HUD map layer)

func tag(center: Vector2, text: String, color: Color, font: Font) -> void:
	draw_rect(Rect2(center+Vector2(-52,-31),Vector2(104,13)),Color(0.04,0.05,0.07,0.85))
	draw_string(font,center+Vector2(-52,-21),text,HORIZONTAL_ALIGNMENT_CENTER,104,9,color)

func draw_mission_layer(projection, font: Font) -> void:
	var size := CELL_SIZE
	for x in range(6,14):
		for y in range(3,12):
			draw_rect(Rect2(projection.cell_anchor(Vector2i(x,y)),Vector2.ONE*size),Color(0.6,0.6,0.55,0.1))
	draw_string(font,projection.cell_anchor(Vector2i(6,3))+Vector2(2,-3),"CHAMBERS",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e8e0c8"))
	draw_string(font,projection.cell_anchor(Vector2i(6,7))+Vector2(2,-3),"ATRIUM",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e8e0c8"))
	draw_string(font,projection.cell_anchor(Vector2i(16,2))+Vector2(0,-3),"ANNEX (mortar)",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("ffb75a"))
	var term: Vector2 = projection.cell_anchor(TERMINAL)
	draw_rect(Rect2(term+Vector2(3,3),Vector2.ONE*(size-6)),Color("2b3a4a"))
	draw_rect(Rect2(term+Vector2(3,3),Vector2.ONE*(size-6)),Color("8be6de"),false,2)
	draw_string(font,term+Vector2(-20,-4),"RECORDS %s" % ("✓" if records["done"] else "%d/%d" % [records["steps"],RECORD_STEPS]),HORIZONTAL_ALIGNMENT_CENTER,76,9,Color("8be6de"))
	var door: Vector2 = projection.cell_anchor(SERVICE_DOOR)
	draw_rect(Rect2(door+Vector2(2,2),Vector2.ONE*(size-4)),Color("6b6b6b") if not door_open else Color(0.4,0.8,0.5,0.4),not door_open,2 if not door_open else -1)
	draw_string(font,door+Vector2(-24,-4),"SERVICE DOOR" + (" open" if door_open else ""),HORIZONTAL_ALIGNMENT_CENTER,84,9,Color("c9d3e0"))
	if hatch_found:
		draw_string(font,projection.cell_anchor(HATCH)+Vector2(-10,-4),"HATCH",HORIZONTAL_ALIGNMENT_CENTER,56,9,Color("d9b8ff"))
		for x in range(15,19):
			for y in range(9,12):
				draw_rect(Rect2(projection.cell_anchor(Vector2i(x,y)),Vector2.ONE*size),Color(0.4,0.2,0.5,0.15))
		if not pen["open"]:
			draw_rect(Rect2(projection.cell_anchor(PEN)+Vector2(-3,-3),Vector2.ONE*(size+6)),Color("b98cff"),false,3)
	for cell in mission_definition().cover_edges.keys():
		draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(10,10),Vector2(size-20,size-20)),Color(0.55,0.8,0.55,0.3))
	# Convoy.
	if mortar["convoy"] == "waiting":
		for cell in CONVOY: draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(2,6),Vector2(size-4,24)),Color("5a6b7a"))
		tag(projection.cell_anchor(CONVOY[0])+Vector2(36,18),"CONVOY · leaves round %d" % CONVOY_LEAVES,Color("e6e9f0"),font)
	if convoy_shield:
		draw_rect(Rect2(projection.cell_anchor(CONVOY[0])+Vector2(-4,0),Vector2(size*2+8,size)),Color("bfe3ff"),false,2)
	# Mortar.
	if not Mortar.silenced(mortar):
		var spot: Vector2 = projection.cell_anchor(SPOTTER)+Vector2(18,18)
		draw_circle(spot,9,Color("6b8a5a"))
		tag(spot,"REPTILIAN SPOTTER %d HP" % mortar["spotter"]["hp"],Color("ffb75a"),font)
		if mortar["mark"] != NONE:
			var at: Vector2 = projection.cell_anchor(mortar["mark"]-Vector2i.ONE)
			draw_rect(Rect2(at,Vector2.ONE*size*3),Color(1,0.55,0.15,0.22))
			draw_rect(Rect2(at,Vector2.ONE*size*3),Color("ffb75a"),false,2)
	# Troopers: visible ones solid, unseen ones as last-known markers.
	for entry in garrison["units"]:
		if entry["hp"] <= 0: continue
		if Garrison.visible(entry,self):
			var center: Vector2 = projection.cell_anchor(entry["cell"])+Vector2(18,18)
			draw_colored_polygon(PackedVector2Array([center+Vector2(-12,-12),center+Vector2(12,-12),center+Vector2(14,12),center+Vector2(-14,12)]),Color("3d5a3a"))
			tag(center,"REPTILIAN %s %d HP" % [entry["faction"].to_upper() if entry["faction"] != "" else "PATROL",entry["hp"]],Color("ff8a80") if garrison["alarm"] else Color("c9e0b8"),font)
			if not entry["aim"].is_empty():
				draw_line(center,projection.cell_anchor(entry["aim"]["cell"])+Vector2(18,18),Color(1,0.3,0.35,0.85),3)
			if sight_mode and pinned_target == entry["cell"]:
				draw_rect(Rect2(projection.cell_anchor(entry["cell"])+Vector2(1,1),Vector2.ONE*(size-2)),Color("e6a2c7"),false,2)
		elif entry["last_seen"] != NONE:
			var at: Vector2 = projection.cell_anchor(entry["last_seen"])
			draw_rect(Rect2(at+Vector2(6,6),Vector2.ONE*(size-12)),Color("ff8a80"),false,1)
			draw_string(font,at+Vector2(0,22),"?",HORIZONTAL_ALIGNMENT_CENTER,size,12,Color("ff8a80"))
