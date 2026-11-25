extends "res://encounter_controller.gd"
## Mission 06 · County Hospital (spec: docs/missions/county-hospital.md). Act II.
## One road out, power for a few systems, an ambulance for one group a trip, a disguised
## Reptilian infiltrator found only by corroborating evidence, a Reptilian breach team,
## a Drover convoy that wants the same road, and the first supporting fire team.
## The Farm Road machine is switched off. Save/load for this mission comes later.
const HospitalMission = preload("res://missions/county_hospital.tres")
const Power = preload("res://systems/hospital_power.gd")
const Screening = preload("res://systems/screening.gd")
const Reptilians = preload("res://systems/reptilian_team.gd")
const Convoy = preload("res://systems/drover_convoy.gd")
const FireTeam = preload("res://systems/fire_team.gd")
const CampaignRecord = preload("res://systems/campaign_record.gd")

const GENERATOR := Vector2i(2,8)
const CHECKPOINT := Vector2i(12,6)
const GATE := Vector2i(12,2)
const BAY := Vector2i(9,8)
const ROAD_ROW := 8
const CONVOY_FROM := 10
const CONVOY_TO := 18
const CONVOY_WAIT: Array[Vector2i] = [Vector2i(18,12),Vector2i(19,12)]
const TEAM_START := Vector2i(10,10)
const GURNEY_GROUP := 2
const SCREEN_REACH := 3          # a group this close to the checking soldier
const CONVOY_VOICE := 6
const SPOT_RANGE := 8
const REPLACEMENTS := ["Reyes","Okafor","Lindqvist"]

var record_path := ""
var power: Dictionary = {}
var ambulance: Dictionary = {}
var screening: Dictionary = {}
var reptilians: Dictionary = {}
var convoy: Dictionary = {}
var team: Dictionary = {}
## Carry-ins.
var rail_cells := false
var field_contact := false

func mission_definition() -> Resource:
	if mission_override != null: return mission_override
	return HospitalMission

func _ready() -> void:
	initialize_tactical()
	initialize_machine()
	initialize_evacuation()
	initialize_breaker()
	initialize_protocol()
	initialize_rescue()
	initialize_results()
	initialize_story()
	initialize_roster(false)
	report_path = "user://holdfast_m06_result.save"
	completion_path = "user://holdfast_m06_completed.save"
	campaign_path = "user://holdfast_m06_campaign.save"
	read_carry_ins()
	power = Power.initial(rail_cells)
	ambulance = Power.ambulance_initial(BAY)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	screening = Screening.initial(rng.randi_range(0,2))
	reptilians = Reptilians.initial()
	convoy = Convoy.initial(field_contact)
	team = FireTeam.initial(TEAM_START)
	cohorts[GURNEY_GROUP]["gurneys"] = true
	for index in range(cohorts.size()):
		cohorts[index]["origin"] = ["Walking patients","Hospital staff","Critical patients on gurneys"][index]
	carry_over_squad()
	status_text = "County Hospital: one road out. Assign power at the generator room (2,8) first."
	enemy_message = "The perimeter is holding, for now."
	save_feedback = "Saving isn't available at the hospital yet."
	rebuild_movement()

func read_carry_ins() -> void:
	if record_path == "": return
	var missions: Dictionary = CampaignRecord.load_record(record_path)["missions"]
	rail_cells = missions.get(5,{}).get("supplies","none") != "none"
	field_contact = CampaignRecord.field_contact(missions.get(4,{}))

func carry_over_squad() -> void:
	if record_path == "": return
	var missions: Dictionary = CampaignRecord.load_record(record_path)["missions"]
	var entry: Dictionary = {}
	for id in [5,4,3,2,1]:
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

func convoy_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not convoy.is_empty() and Convoy.passing(convoy):
		for x in range(CONVOY_FROM,CONVOY_TO+1): cells.append(Vector2i(x,ROAD_ROW))
	elif not convoy.is_empty() and convoy["stage"] == "arrived":
		cells.append_array(CONVOY_WAIT)
	return cells

func team_at(cell: Vector2i) -> bool:
	return not team.is_empty() and FireTeam.present(team) and team["cell"] == cell

func target_at(cell: Vector2i) -> int:
	if not reptilians.is_empty():
		var index := Reptilians.unit_at(reptilians,cell)
		if index >= 0: return 10+index
	if not ambulance.is_empty() and ambulance["cell"] == cell and ambulance["state"] != "gone": return 30
	if team_at(cell): return 40
	if convoy_cells().has(cell): return 50
	return -1

func blocked_for_team(cell: Vector2i) -> bool:
	var code := target_at(cell)
	return code >= 0 and code != 40

func road_closed(cell: Vector2i) -> bool:
	return convoy_cells().has(cell) or Reptilians.unit_at(reptilians,cell) >= 0

func road_occupied(cell: Vector2i) -> bool:
	return soldier_at(cell) >= 0 or cohort_at(cell) >= 0 or team_at(cell)

func road_blocked(cell: Vector2i) -> bool:
	return road_closed(cell) or road_occupied(cell)

func civilian_safe(cell: Vector2i) -> bool:
	if not cell_is_in_bounds(cell) or WALL_CELLS.has(cell) or FIXTURES.has(cell): return false
	return target_at(cell) < 0

func civilian_waypoint(order: String) -> Vector2i:
	return mission_definition().civilian_routes["north" if order == "north" else "south"]

func route_label(order: String) -> String:
	return "North side of the lot" if order == "north" else "South side of the lot"

func on_civilian_step(cohort: Dictionary, cell: Vector2i) -> void:
	if cell.x >= 14: cohort["passed"] = true

## Gurneys move one square a turn on foot.
func move_cohort(cohort: Dictionary, budget: int) -> void:
	if cohort.get("gurneys",false): budget = mini(budget,1)
	super.move_cohort(cohort,budget)

func civilian_threats() -> Array[Vector2i]:
	var threats: Array[Vector2i] = []
	for entry in reptilian_targets(): threats.append(entry["cell"])
	threats.append_array(reptilians["cone"])
	threats.append_array(round_noise)
	return threats

func deadline() -> int:
	return mission_definition().closing_round

func mission_completion_reason(round_number: int) -> String:
	var mission := mission_definition()
	if round_number >= deadline(): return mission.closure_reason
	if all_extracted() and remaining_civilians() == 0 and ambulance["state"] != "out": return mission.evacuation_reason
	return ""

func reptilian_visible(entry: Dictionary) -> bool:
	if entry["hp"] <= 0: return false
	if Power.powered(power,"lights"): return true
	for index in range(soldiers.size()):
		if soldier_can_act(index) and Reptilians.distance(soldiers[index]["cell"],entry["cell"]) <= SPOT_RANGE: return true
	return FireTeam.present(team) and Reptilians.distance(team["cell"],entry["cell"]) <= SPOT_RANGE

func reptilian_targets() -> Array:
	var out: Array = []
	if reptilians.is_empty(): return out
	for entry in reptilians["units"]:
		if reptilian_visible(entry): out.append(entry)
	return out

func hit_reptilian(entry: Dictionary) -> String:
	return Reptilians.take_hit(reptilians,reptilians["units"].find(entry))

func damage_team(amount: int) -> String:
	return FireTeam.damage(team,amount)

func shove_off_road(amount: int) -> String:
	var hurt: Array[String] = []
	for x in range(CONVOY_FROM,CONVOY_TO+1):
		var cell := Vector2i(x,ROAD_ROW)
		if soldier_at(cell) < 0 and cohort_at(cell) < 0: continue
		hurt.append(apply_casualty_damage(cell,amount))
		for side in [Vector2i(0,1),Vector2i(0,-1),Vector2i(0,2),Vector2i(0,-2)]:
			var landing: Vector2i = cell+side
			if cell_is_in_bounds(landing) and not WALL_CELLS.has(landing) and not FIXTURES.has(landing) and soldier_at(landing) < 0 and cohort_at(landing) < 0 and target_at(landing) < 0:
				var soldier := soldier_at(cell)
				if soldier >= 0: soldiers[soldier]["cell"] = landing
				var group := cohort_at(cell)
				if group >= 0: cohorts[group]["cell"] = landing
				break
	return "" if hurt.is_empty() else "Shoved off the road: " + "; ".join(hurt) + "."

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

func power_reason(system: String) -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if active_soldier != 0: return "MSG assigns power. Select MSG."
	if Reptilians.distance(soldiers[0]["cell"],GENERATOR) != 1: return "MSG has to stand next to the generator room (%d,%d)." % [GENERATOR.x,GENERATOR.y]
	if not Power.powered(power,system) and Power.used(power) >= Power.capacity(power): return "Power is maxed (%d/%d). Switch something off first." % [Power.used(power),Power.capacity(power)]
	return ""

func toggle_power(system: String) -> bool:
	var reason := power_reason(system)
	if reason != "": return reject(reason)
	Power.toggle(power,system)
	soldiers[0]["ap"] -= 1
	status_text = "%s %s. Power %d/%d." % [Power.LABELS[system],"on" if Power.powered(power,system) else "off",Power.used(power),Power.capacity(power)]
	rebuild_movement()
	return true

func load_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if ambulance["state"] != "parked": return "The ambulance is out on a run."
	if not Power.powered(power,"ambulance"): return "The ambulance charger has no power."
	if Reptilians.distance(soldiers[active_soldier]["cell"],ambulance["cell"]) != 1: return "Stand next to the ambulance in the bay (%d,%d)." % [BAY.x,BAY.y]
	var cohort: Dictionary = cohorts[cohort_selected]
	if cohort["status"] != "active" or Reptilians.distance(cohort["cell"],ambulance["cell"]) != 1: return "Select a group standing next to the ambulance."
	return ""

func load_ambulance() -> bool:
	var reason := load_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	var cohort: Dictionary = cohorts[cohort_selected]
	cohort["status"] = "riding"
	cohort["note"] = "In the ambulance"
	ambulance["group"] = cohort_selected
	ambulance["state"] = "out"
	status_text = "Group %s is in the ambulance. It leaves in the next environment phase." % cohort["id"]
	rebuild_movement()
	return true

func screen_reason(kind: String) -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if Reptilians.distance(soldiers[active_soldier]["cell"],CHECKPOINT) != 1: return "Stand next to the triage checkpoint (%d,%d)." % [CHECKPOINT.x,CHECKPOINT.y]
	var cohort: Dictionary = cohorts[cohort_selected]
	if cohort["status"] != "active" or Reptilians.distance(cohort["cell"],soldiers[active_soldier]["cell"]) > SCREEN_REACH: return "Select a group within %d squares of the checkpoint soldier." % SCREEN_REACH
	var person: Dictionary = screening["people"][cohort_selected]
	if person["status"] != "with group": return "%s isn't with the group any more." % person["name"]
	if kind == "scan" and not Power.powered(power,"scanner"): return "The triage scanner has no power."
	if kind == "scan" and person["scanner"] != "unscanned": return "Already scanned."
	if kind == "credentials" and person["credentials"] != "unchecked": return "Already checked."
	return ""

func check_credentials() -> bool:
	var reason := screen_reason("credentials")
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	status_text = Screening.check_credentials(screening,cohort_selected)
	rebuild_movement()
	return true

func scan_person() -> bool:
	var reason := screen_reason("scan")
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	status_text = Screening.scan(screening,cohort_selected)
	rebuild_movement()
	return true

func detain_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	var cohort: Dictionary = cohorts[cohort_selected]
	if cohort["status"] != "active" or Reptilians.distance(cohort["cell"],soldiers[active_soldier]["cell"]) > 1: return "Stand next to the selected group."
	if screening["people"][cohort_selected]["status"] != "with group": return "Already held."
	return ""

func detain_person() -> bool:
	var reason := detain_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	status_text = Screening.detain(screening,cohort_selected)
	if screening["people"][cohort_selected]["status"] == "falsely_detained": cohorts[cohort_selected]["panic"] = 2
	rebuild_movement()
	return true

func convoy_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if active_soldier != 0: return "MSG answers Kesh. Select MSG."
	if convoy["stage"] != "arrived": return "The convoy isn't waiting for an answer."
	if not convoy["contact"]: return "No field contact from the Interchange: nobody on their side to agree with."
	if convoy["choice"] != "none": return "Already answered."
	if Reptilians.distance(soldiers[0]["cell"],CONVOY_WAIT[0]) > CONVOY_VOICE: return "MSG needs to be within %d squares of the convoy (east end)." % CONVOY_VOICE
	return ""

func answer_convoy(choice: String) -> bool:
	var reason := convoy_reason()
	if reason != "": return reject(reason)
	soldiers[0]["ap"] -= 1
	status_text = Convoy.choose(convoy,choice)
	rebuild_movement()
	return true

func team_reason() -> String:
	if ended: return "Operation over."
	if not FireTeam.present(team): return "Guard Team Marsh isn't on the field."
	if team["ordered_phase"] == phase: return "One order a turn: Guard Team Marsh already has theirs."
	return ""

func order_team(kind: String) -> bool:
	var reason := team_reason()
	if reason != "": return reject(reason)
	var cell: Vector2i = team["cell"]
	if kind == "hold" and soldier_can_act(active_soldier): cell = soldiers[active_soldier]["cell"]+Vector2i(1,0)
	if kind == "hold" and (not cell_is_in_bounds(cell) or WALL_CELLS.has(cell) or FIXTURES.has(cell)):
		return reject("That square won't hold a team. Pick another soldier to form up on.")
	status_text = FireTeam.order(team,phase,kind,cell,cohort_selected)
	queue_redraw()
	return true

func fire_block_reason() -> String:
	if ended: return "Operation ended."
	if not soldier_can_act(active_soldier): return "Select a standing soldier."
	var soldier: Dictionary = soldiers[active_soldier]
	if soldier.get("carrying",-1) >= 0: return "Cannot fire while carrying a casualty."
	if soldier["ap"] < 1: return "No AP left."
	if soldier["attacked"]: return "Already fired this round."
	if soldier["ammo"] < 1: return "Out of ammunition: reload."
	var index := Reptilians.unit_at(reptilians,sight_target())
	if index < 0 or not reptilian_visible(reptilians["units"][index]): return "Aim [T], then click a Reptilian trooper. People in the groups are never targets."
	if not sight_preview(soldier["cell"],sight_target())["can_fire"]: return "No clear shot at that range."
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
	var roll := shot_rng.randi_range(1,100)
	if roll <= info["chance"]:
		status_text = "%s fires (%d%%): %s" % [soldier["name"],info["chance"],Reptilians.take_hit(reptilians,Reptilians.unit_at(reptilians,target))]
	else:
		status_text = "%s fires (%d%%) and misses." % [soldier["name"],info["chance"]]
	if Reptilians.unit_at(reptilians,target) < 0: pinned_target = NONE
	rebuild_movement()
	return true

# ---------------------------------------------------------------- turn

## Round order: player, allied team, Drovers, infiltrator, Reptilians, ambulance, civilians.
func resolve_enemy_turn() -> void:
	if last_enemy_phase == phase: return
	last_enemy_phase = phase
	var lines: Array[String] = []
	for line in [FireTeam.act(team,self),Convoy.act(convoy,self),infiltrator_phase(),Reptilians.act(reptilians,self),Power.drive(ambulance,power,self)]:
		if line != "": lines.append(line)
	enemy_message = " ".join(lines) if not lines.is_empty() else "The hospital is quiet. For now."
	rebuild_movement()
	check_recovery_failure()
	finalize_result()

func infiltrator_phase() -> String:
	var line := Screening.act(screening,self)
	if screening["acted"] and reptilians["arrival"] != Reptilians.EARLY_BREACH and not reptilians["arrived"]:
		reptilians["arrival"] = Reptilians.EARLY_BREACH
	return line

func begin_player_phase() -> void:
	super.begin_player_phase()
	for index in reptilians.get("stunned",[]):
		if index < soldiers.size(): soldiers[index]["ap"] = maxi(0,soldiers[index]["ap"]-1)
	if not reptilians.get("stunned",[]).is_empty():
		status_text = "Round %d. The sonic burst rattled %d soldier%s: 1 AP less this turn." % [phase,reptilians["stunned"].size(),"" if reptilians["stunned"].size() == 1 else "s"]
	else:
		status_text = "Round %d. %s" % [phase,enemy_message.left(150)]

func enemy_intent() -> String:
	var parts: Array[String] = ["Power %d/%d" % [Power.used(power),Power.capacity(power)]]
	parts.append("Ambulance " + ambulance["state"])
	if not reptilians["arrived"]: parts.append("Reptilian team expected round %d" % reptilians["arrival"] if screening["acted"] else "Reptilians somewhere north of the fence")
	elif Reptilians.active(reptilians): parts.append("REPTILIANS INSIDE (%d)" % reptilian_targets().size())
	parts.append({"waiting":"Convoy due round %d" % Convoy.ARRIVE_ROUND,"arrived":"Convoy waiting at the east end","passing":"CONVOY ON THE ROAD","diverted":"Convoy diverted","gone":"Convoy gone"}[convoy["stage"]])
	return " · ".join(parts)

func danger_summary() -> String:
	return "Two discrepancies confirm a person; detaining on less risks a false detention. Reptilians take any group they end their move next to. Violet cones go off next phase."

func screening_summary() -> String:
	var lines: Array[String] = []
	for index in range(screening["people"].size()):
		var person: Dictionary = screening["people"][index]
		var evidence: Array[String] = []
		if person["credentials"] != "unchecked": evidence.append("badge: " + person["credentials"])
		if person["behavior"]: evidence.append("seen at the gate")
		if person["scanner"] != "unscanned": evidence.append("scan: " + person["scanner"])
		var state: String = "" if person["status"] == "with group" else " · " + str(person["status"]).replace("_"," ").to_upper()
		lines.append("Group %s: %s (%s) — %s%s" % [cohorts[index]["id"],person["name"],person["role"],", ".join(evidence) if not evidence.is_empty() else "no evidence yet",state])
	return "SCREENING (two discrepancies confirm):\n" + "\n".join(lines)

func machine_outcome() -> String:
	match Screening.result(screening,self):
		"contained": return "Infiltrator contained on corroborated evidence."
		"detained_thin": return "Infiltrator held, on thin evidence."
		"reached_base": return "The infiltrator walked out with their group and reached the base."
	return "The infiltrator is still inside the hospital."

func feeder_result() -> String:
	var parts: Array[String] = []
	parts.append("Ambulance carried: %s." % (", ".join(ambulance["trips"]) if not ambulance["trips"].is_empty() else "nobody"))
	if not screening["false_detentions"].is_empty(): parts.append("Falsely detained: %s." % ", ".join(screening["false_detentions"]))
	parts.append({"monitored":"Drover convoy passed under watch; coupling spliced in.","reserved":"Road reserved; the convoy diverted.","contested":"The convoy forced the road.","none":"The convoy never came."}[convoy["choice"]])
	if not reptilians["taken"].is_empty(): parts.append("Taken by the Reptilians: group %s." % ", ".join(reptilians["taken"]))
	var dead := team_dead()
	parts.append("Guard Team Marsh: %d of 4 standing%s." % [FireTeam.standing(team),"" if dead.is_empty() else "; killed: " + ", ".join(dead)])
	return " ".join(parts)

func team_dead() -> Array:
	var dead: Array = []
	for member in team["members"]:
		if member["status"] == "dead": dead.append(member["name"])
	return dead

func result_title() -> String:
	if retry_required(): return "ATTEMPT ENDED / RETRY REQUIRED"
	var everyone := evacuated_people() == 12
	for soldier in soldiers:
		everyone = everyone and soldier["extracted"] and soldier["condition"] != "dead"
	return "COUNTY HOSPITAL / EVACUATED" if everyone else "COUNTY HOSPITAL / PARTIAL"

# ---------------------------------------------------------------- story

func opening_pages() -> Array:
	return [
		{"speaker":"ACT II · MISSION 06: COUNTY HOSPITAL","text":"County Hospital is emptying through one road east. Most patients can walk. Ward 3 can't: critical patients on gurneys.\n\nThe building has power for %d system%s. The ambulance needs one of them." % [Power.capacity(power),"" if Power.capacity(power) == 1 else "s"],"tag":"Evacuate the hospital · get the squad out"},
		{"speaker":"ORTIZ","text":"‘Somebody in here isn't who their badge says. The charge nurse swears a doctor she's never met signed half the transfers this week.’\n\nMSG: ‘Then we check. We don't guess, and we don't point a rifle at a crowd.’","tag":"Evidence, not appearance: two discrepancies confirm"},
		{"speaker":"SGT. MARSH / GUARD TEAM","text":"‘Four of us, Sergeant. Tell us where to stand and who to cover, and we'll do it. One order at a time.’","tag":"First supporting fire team: Hold, Protect, Withdraw"}]

func current_pages() -> Array:
	if scene_view == "opening": return opening_pages()
	if scene_view == "debrief": return debrief_pages()
	return log_pages()

func log_pages() -> Array:
	var pages := opening_pages()
	pages.append({"speaker":"INTELLIGENCE / COUNTY HOSPITAL","text":enemy_intent()+"\n\n"+screening_summary(),"tag":"Observation, not doctrine"})
	if result_ready and not retry_required(): pages.append_array(debrief_pages())
	return pages

func debrief_pages() -> Array:
	var out: Array[String] = []
	var left: Array[String] = []
	for cohort in cohorts:
		if cohort["status"] == "extracted": out.append("%s (%s)" % [cohort["id"],cohort["origin"]])
		elif cohort["status"] != "taken": left.append("%s (%s)" % [cohort["id"],cohort["origin"]])
	var pages: Array = [{"speaker":"COUNTY HOSPITAL / VERIFIED FIELD REPORT","text":"Out: %s.\nLeft behind: %s.\n\n%s\n%s" % [", ".join(out) if not out.is_empty() else "none",", ".join(left) if not left.is_empty() else "none",machine_outcome(),feeder_result()],"tag":"Who was held, and on what evidence, is on the record"}]
	var verdict := Screening.result(screening,self)
	if verdict in ["contained","detained_thin"]:
		pages.append({"speaker":"BELL","text":"‘Transfer sheets. Every patient a line item: weight, blood type, “viable”. They weren't moving people out. They were stocktaking.’","tag":"Reptilian logistics: people as harvestable stock"})
	elif verdict == "reached_base":
		pages.append({"speaker":"PARK","text":"‘One of the people we brought out isn't who they said. We just don't know which one yet.’","tag":"Someone at the base isn't who they seem"})
	for who in screening["false_detentions"]:
		pages.append({"speaker":"MSG","text":"‘We held %s on a bad read. That's on me. It goes in the report with their name on it.’" % who,"tag":"A false detention, recorded"})
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
	save_feedback = "Saving isn't available at the hospital yet."
	status_text = save_feedback
	queue_redraw()
	return false

func load_encounter(_path: String = RETURN_SLOT) -> bool:
	save_feedback = "Loading isn't available at the hospital yet."
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
	var fresh = load("res://county_hospital.tscn").instantiate()
	fresh.auto_resume = false
	fresh.record_path = record_path
	get_parent().add_child(fresh)
	queue_free()

# ---------------------------------------------------------------- drawing (HUD map layer)

func draw_mission_layer(projection, font: Font) -> void:
	var size := CELL_SIZE
	for x in range(1,7):
		for y in range(4,13):
			draw_rect(Rect2(projection.cell_anchor(Vector2i(x,y)),Vector2.ONE*size),Color(0.55,0.62,0.65,0.12))
	draw_string(font,projection.cell_anchor(Vector2i(1,4))+Vector2(2,-3),"COUNTY HOSPITAL",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("d8e6ea"))
	for x in range(9,GRID_SIZE.x+1):
		draw_rect(Rect2(projection.cell_anchor(Vector2i(x,ROAD_ROW))+Vector2(0,14),Vector2(size,8)),Color(0.85,0.85,0.7,0.12))
	for pair in [[GENERATOR,"GEN","power %d/%d" % [Power.used(power),Power.capacity(power)]],[CHECKPOINT,"TRIAGE","screening"]]:
		var at: Vector2 = projection.cell_anchor(pair[0])
		draw_rect(Rect2(at+Vector2(3,3),Vector2.ONE*(size-6)),Color("2b3a4a"))
		draw_rect(Rect2(at+Vector2(3,3),Vector2.ONE*(size-6)),Color("8be6de"),false,2)
		draw_string(font,at+Vector2(0,22),pair[1],HORIZONTAL_ALIGNMENT_CENTER,size,9,Color("8be6de"))
		draw_string(font,at+Vector2(-20,-4),pair[2],HORIZONTAL_ALIGNMENT_CENTER,76,9,Color("8be6de"))
	var gate: Vector2 = projection.cell_anchor(GATE)
	draw_rect(Rect2(gate+Vector2(2,2),Vector2.ONE*(size-4)),Color("ff8a80") if screening["acted"] else Color("6b6b6b"),false,3)
	draw_string(font,gate+Vector2(-14,-2),"GATE " + ("OPEN" if screening["acted"] else "shut"),HORIZONTAL_ALIGNMENT_CENTER,64,9,Color("ffcfc9"))
	if Power.powered(power,"lights"):
		for x in range(8,GRID_SIZE.x+1): draw_rect(Rect2(projection.cell_anchor(Vector2i(x,3)),Vector2(size,4)),Color(1,0.95,0.6,0.35))
	# Ambulance.
	if ambulance["state"] != "gone":
		var at: Vector2 = projection.cell_anchor(ambulance["cell"])
		draw_rect(Rect2(at+Vector2(-2,6),Vector2(size+4,24)),Color("e9eef0"))
		draw_rect(Rect2(at+Vector2(14,10),Vector2(8,16)),Color("d9433f"))
		draw_rect(Rect2(at+Vector2(8,14),Vector2(20,8)),Color("d9433f"))
		draw_string(font,at+Vector2(-20,-3),"AMBULANCE · " + ("no power" if not Power.powered(power,"ambulance") else ambulance["state"]),HORIZONTAL_ALIGNMENT_CENTER,76,9,Color("ffffff"))
	# Convoy.
	for cell in convoy_cells():
		draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(1,4),Vector2(size-2,28)),Color("6e5a3c"))
	if not convoy_cells().is_empty():
		draw_string(font,projection.cell_anchor(convoy_cells()[0])+Vector2(-10,-3),"DROVER CONVOY" + (" · watched" if convoy["choice"] == "monitored" else ""),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("ffe1a8"))
	# Guard Team Marsh.
	if FireTeam.present(team):
		var center: Vector2 = projection.cell_anchor(team["cell"])+Vector2(18,18)
		for offset in [Vector2(-7,-7),Vector2(7,-7),Vector2(-7,7),Vector2(7,7)]: draw_circle(center+offset,5,Color("9cc48a"))
		draw_rect(Rect2(center+Vector2(-50,-31),Vector2(100,13)),Color(0.04,0.07,0.04,0.85))
		draw_string(font,center+Vector2(-50,-21),"TEAM MARSH %d/4 · %s" % [FireTeam.standing(team),team["order"].to_upper()],HORIZONTAL_ALIGNMENT_CENTER,100,9,Color("c9f0b5"))
	# Reptilians and their cone.
	for cell in reptilians["cone"]:
		draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(2,2),Vector2.ONE*(size-4)),Color(0.85,0.3,0.95,0.22))
	for entry in reptilian_targets():
		var center: Vector2 = projection.cell_anchor(entry["cell"])+Vector2(18,18)
		draw_colored_polygon(PackedVector2Array([center+Vector2(-12,-12),center+Vector2(12,-12),center+Vector2(14,12),center+Vector2(-14,12)]),Color("3d5a3a"))
		draw_rect(Rect2(center+Vector2(-46,-31),Vector2(92,13)),Color(0.05,0.08,0.05,0.85))
		draw_string(font,center+Vector2(-46,-21),"TROOPER %d HP" % entry["hp"],HORIZONTAL_ALIGNMENT_CENTER,92,9,Color("ff8a80"))
		if sight_mode and pinned_target == entry["cell"]:
			draw_rect(Rect2(projection.cell_anchor(entry["cell"])+Vector2(1,1),Vector2.ONE*(size-2)),Color("e6a2c7"),false,2)
	# Persons of interest: a small marker on each group with evidence count.
	for index in range(cohorts.size()):
		var cohort: Dictionary = cohorts[index]
		if cohort["status"] != "active": continue
		var person: Dictionary = screening["people"][index]
		if person["status"] != "with group": continue
		var at: Vector2 = projection.cell_anchor(cohort["cell"])
		var count := Screening.discrepancies(screening,index)
		draw_circle(at+Vector2(size-5,5),6,[Color("8a8f99"),Color("ffb75a"),Color("ff5c66"),Color("ff5c66")][count])
		draw_string(font,at+Vector2(size-11,9),str(count),HORIZONTAL_ALIGNMENT_CENTER,12,9,Color.BLACK)
