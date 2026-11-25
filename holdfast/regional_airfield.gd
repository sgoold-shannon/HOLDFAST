extends "res://encounter_controller.gd"
## Mission 08 · Regional Airfield (spec: docs/missions/regional-airfield.md). Act III opener.
## Three groups at the terminal, a damaged Nordic craft in hangar 2 with a contact window and
## finite protection charges, a Grey crew stripping the transport plane, and a Fallow cutter
## coming down the runway. Every unit shows its faction and stance. A supporting team holds
## the terminal. The Farm Road machine is switched off. Save/load for this mission comes later.
const AirfieldMission = preload("res://missions/regional_airfield.tres")
const Craft = preload("res://systems/nordic_craft.gd")
const Strip = preload("res://systems/grey_strippers.gd")
const FallowCutter = preload("res://systems/fallow_cutter.gd")
const FireTeam = preload("res://systems/fire_team.gd")
const CampaignRecord = preload("res://systems/campaign_record.gd")

const PLANE := Vector2i(11,8)
const CRAFT := Vector2i(15,2)
const CRAFT_DOOR := Vector2i(15,3)
const POD := Vector2i(17,14)
const COLLECTOR_START := Vector2i(17,11)
const SENTRIES: Array[Vector2i] = [Vector2i(16,12),Vector2i(18,12)]
const FALLOW_ENTRY := Vector2i(19,8)
const FALLOW_NODE := Vector2i(20,8)
const TEAM_START := Vector2i(12,9)
const RUNWAY_ROWS := [7,8,9]
const RUNWAY_RUIN := 2           # this many rift squares on the runway ruins it
const FALLOW_ARRIVAL := 3
const CUT_AP := 2
const ENGINEER := 2
const HOLT := ["Sgt. Holt","Cpl. Baines","Spc. Orozco","Pfc. Lam"]
const REPLACEMENTS := ["Reyes","Okafor","Lindqvist"]

var mission_copy: Resource = null
var record_path := ""
var craft: Dictionary = {}
var strip: Dictionary = {}
var fallow: Dictionary = {}
var team: Dictionary = {}
var pod := {"active":false,"group":-1,"cut":0,"open":false,"origin":""}
## Carry-ins.
var river_shield := false
var intel_line := false
var custody: Array = []
var marsh_dead: Array = []

func mission_definition() -> Resource:
	if mission_override != null: return mission_override
	if mission_copy == null: mission_copy = AirfieldMission.duplicate(true)
	return mission_copy

func _ready() -> void:
	read_carry_ins()
	if not custody.is_empty(): mission_definition().civilian_spawns[2] = POD
	initialize_tactical()
	initialize_machine()
	initialize_evacuation()
	initialize_breaker()
	initialize_protocol()
	initialize_rescue()
	initialize_results()
	initialize_story()
	initialize_roster(false)
	report_path = "user://holdfast_m08_result.save"
	completion_path = "user://holdfast_m08_completed.save"
	campaign_path = "user://holdfast_m08_campaign.save"
	craft = Craft.initial(CRAFT,river_shield,"from River Bridge")
	strip = Strip.initial(COLLECTOR_START,SENTRIES)
	fallow = FallowCutter.initial(FALLOW_ENTRY,FALLOW_NODE)
	team = FireTeam.initial(TEAM_START)
	if marsh_dead.size() >= FireTeam.MEMBERS.size():
		for index in range(team["members"].size()): team["members"][index]["name"] = HOLT[index]
		team["name"] = "Guard Team Holt"
	else:
		team["members"] = team["members"].filter(func(member): return not marsh_dead.has(member["name"]))
		team["name"] = "Guard Team Marsh"
	for index in range(cohorts.size()):
		cohorts[index]["origin"] = ["Stranded travellers","Airfield ground crew","Families from the hangars"][index]
	if not custody.is_empty():
		pod = {"active":true,"group":2,"cut":0,"open":false,"origin":"Rail Yard group %s (in Grey custody)" % custody[0]}
		cohorts[2]["origin"] = pod["origin"]
		cohorts[2]["penned"] = true
		cohorts[2]["note"] = "Held in a Grey cargo pod"
	carry_over_squad()
	status_text = "Regional Airfield: three factions on one field. Reach the craft in hangar 2 by round %d." % Craft.WINDOW_ROUND
	enemy_message = "A Grey crew is working the apron. The east end of the runway shimmers."
	save_feedback = "Saving isn't available at the airfield yet."
	rebuild_movement()

func read_carry_ins() -> void:
	if record_path == "": return
	var missions: Dictionary = CampaignRecord.load_record(record_path)["missions"]
	river_shield = missions.get(2,{}).get("craft_shield",false)
	intel_line = missions.get(5,{}).get("archive","none") == "full"
	custody = missions.get(5,{}).get("aboard",[]).duplicate()
	marsh_dead = missions.get(6,{}).get("team_dead",[]).duplicate()

func carry_over_squad() -> void:
	if record_path == "": return
	var missions: Dictionary = CampaignRecord.load_record(record_path)["missions"]
	var entry: Dictionary = {}
	for id in [7,6,5,4,3,2,1]:
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

func plane_present() -> bool:
	return true

func team_at(cell: Vector2i) -> bool:
	return not team.is_empty() and FireTeam.present(team) and team["cell"] == cell

func target_at(cell: Vector2i) -> int:
	if not strip.is_empty():
		var index := Strip.unit_at(strip,cell)
		if index >= 0: return 10+index
	if not fallow.is_empty() and FallowCutter.unit_at(fallow,cell) >= 0: return 20+FallowCutter.unit_at(fallow,cell)
	if team_at(cell): return 40
	return -1

func blocked_for_team(cell: Vector2i) -> bool:
	var code := target_at(cell)
	return code >= 0 and code != 40

func protected_cell(cell: Vector2i) -> bool:
	return not craft.is_empty() and Craft.shielded(craft,cell,phase)

func fallow_marked(cell: Vector2i) -> bool:
	return not fallow.is_empty() and fallow["marked"].has(cell)

func civilian_safe(cell: Vector2i) -> bool:
	if not cell_is_in_bounds(cell) or WALL_CELLS.has(cell) or FIXTURES.has(cell): return false
	return target_at(cell) < 0

func civilian_waypoint(_order: String) -> Vector2i:
	return civilian_exit()

func route_label(_order: String) -> String:
	return "North-west ground route"

func on_civilian_step(_cohort: Dictionary, _cell: Vector2i) -> void:
	pass

func move_cohort(cohort: Dictionary, budget: int) -> void:
	if cohort.get("penned",false): return
	super.move_cohort(cohort,budget)

func resolve_civilian_phase() -> void:
	var held: Array = []
	for cohort in cohorts:
		if cohort.get("penned",false) and cohort["status"] == "active":
			cohort["status"] = "held"
			held.append(cohort)
	super.resolve_civilian_phase()
	for cohort in held: cohort["status"] = "active"

func civilian_threats() -> Array[Vector2i]:
	var threats: Array[Vector2i] = FallowCutter.threat_cells(fallow)
	if not strip["withdrawn"]:
		for entry in strip["units"]:
			if entry["hp"] > 0 and Strip.firing(strip): threats.append(entry["cell"])
			if not entry["aim"].is_empty(): threats.append(entry["aim"]["cell"])
	threats.append_array(round_noise)
	return threats

func deadline() -> int:
	return mission_definition().closing_round

func mission_completion_reason(round_number: int) -> String:
	return MissionObjectives.completion_reason(mission_definition(),round_number,0,all_extracted(),remaining_civilians())

func runway_rifts() -> int:
	var count := 0
	for cell in fallow["rifts"]:
		if RUNWAY_ROWS.has(cell.y): count += 1
	return count

func runway_ruined() -> bool:
	return runway_rifts() >= RUNWAY_RUIN

func aircraft_state() -> String:
	if strip["engines"] <= 0: return "stripped"
	if strip["engines"] < Strip.ENGINES: return "one engine"
	return "intact"

# Fallow hooks (the Main Street contract).
func add_rift(cell: Vector2i) -> void:
	var fixtures: Array[Vector2i] = mission_definition().fixtures
	if not fixtures.has(cell): fixtures.append(cell)

func throw_clear(cell: Vector2i) -> void:
	var frontier: Array[Vector2i] = [cell]
	var seen := {cell:true}
	var landing := NONE
	var cursor := 0
	while cursor < frontier.size() and landing == NONE:
		var current: Vector2i = frontier[cursor]
		cursor += 1
		for direction in DIRECTIONS:
			var next: Vector2i = current+direction
			if seen.has(next) or not cell_is_in_bounds(next) or WALL_CELLS.has(next): continue
			seen[next] = true
			if not FIXTURES.has(next) and soldier_at(next) < 0 and cohort_at(next) < 0 and target_at(next) < 0:
				landing = next
				break
			frontier.append(next)
	if landing == NONE: return
	var soldier := soldier_at(cell)
	if soldier >= 0: soldiers[soldier]["cell"] = landing
	var group := cohort_at(cell)
	if group >= 0: cohorts[group]["cell"] = landing

func sheltered_from_fallow(cell: Vector2i) -> bool:
	var mission := mission_definition()
	if cell == mission.civilian_exit or mission.squad_exits.has(cell) or cell == CRAFT_DOOR: return true
	return protected_cell(cell)

## Fire team hooks: it engages whatever is hostile and visible (Fallow always; Greys once firing).
func reptilian_targets() -> Array:
	var out: Array = []
	if FallowCutter.cutter_alive(fallow): out.append({"kind":"cutter","cell":fallow["cutter"]["cell"],"hp":fallow["cutter"]["hp"]})
	if Strip.firing(strip):
		for entry in strip["units"]:
			if entry["hp"] > 0: out.append(entry)
	return out

func hit_reptilian(entry: Dictionary) -> String:
	if entry.get("kind","") == "cutter":
		var line := FallowCutter.take_hit(fallow,0,3)
		entry["hp"] = fallow["cutter"]["hp"]
		return line
	return Strip.take_hit(strip,strip["units"].find(entry),3)

func damage_team(amount: int) -> String:
	return FireTeam.damage(team,amount)

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

func contact_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if craft["contact"]: return "Contact made."
	if not Craft.window_open(craft,phase): return "The contact window has closed."
	if active_soldier != 0: return "MSG makes contact. Select MSG."
	if FallowCutter.distance(soldiers[0]["cell"],CRAFT) != 1: return "MSG has to stand at the hangar 2 hatch (%d,%d)." % [CRAFT_DOOR.x,CRAFT_DOOR.y]
	return ""

func make_contact() -> bool:
	var reason := contact_reason()
	if reason != "": return reject(reason)
	soldiers[0]["ap"] -= 1
	status_text = Craft.contact(craft)
	rebuild_movement()
	return true

func shield_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if not craft["contact"]: return "Make contact with the craft first."
	if craft["left"]: return "The craft has gone."
	if craft["charges"] <= 0: return "No protection charges left."
	if active_soldier != 0: return "MSG asks for protection. Select MSG."
	if cohorts[cohort_selected]["status"] != "active": return "Select a group to cover."
	return ""

func request_shield() -> bool:
	var reason := shield_reason()
	if reason != "": return reject(reason)
	soldiers[0]["ap"] -= 1
	var center: Vector2i = cohorts[cohort_selected]["cell"]
	status_text = Craft.shield(craft,center,phase)
	# Marked ground under the shield can't fold this time.
	fallow["marked"] = fallow["marked"].filter(func(cell): return not protected_cell(cell))
	rebuild_movement()
	return true

func data_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if craft["data"]: return "Sensor data already copied."
	if not craft["contact"]: return "Make contact first."
	if craft["left"]: return "The craft has gone."
	if FallowCutter.distance(soldiers[active_soldier]["cell"],CRAFT) != 1: return "Stand at the hangar 2 hatch (%d,%d)." % [CRAFT_DOOR.x,CRAFT_DOOR.y]
	return ""

func download_sensors() -> bool:
	var reason := data_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	status_text = Craft.download(craft)
	rebuild_movement()
	return true

func bargain_offered() -> bool:
	return intel_line and phase == Strip.BARGAIN_ROUND and strip["bargain"]["state"] == "none" and not strip["withdrawn"]

func bargain_reason() -> String:
	if not intel_line: return "No Grey intel line: that came from the full Rail Yard archive."
	if not bargain_offered(): return "No offer on the channel." if strip["bargain"]["state"] == "none" else "Bargain: " + strip["bargain"]["state"]
	var reason := ready_reason()
	if reason != "": return reason
	if active_soldier != 0: return "Only MSG answers the channel."
	return ""

func accept_bargain() -> bool:
	var reason := bargain_reason()
	if reason != "": return reject(reason)
	soldiers[0]["ap"] -= 1
	status_text = Strip.accept_bargain(strip,phase)
	rebuild_movement()
	return true

func pod_next_to() -> bool:
	return pod["active"] and not pod["open"] and soldier_can_act(active_soldier) and FallowCutter.distance(soldiers[active_soldier]["cell"],POD) == 1 and cohorts[pod["group"]]["status"] == "active"

func open_pod(how: String) -> void:
	pod["open"] = true
	var cohort: Dictionary = cohorts[pod["group"]]
	cohort["penned"] = false
	cohort["order"] = "north"
	cohort["panic"] = maxi(cohort.get("panic",0),1)
	cohort["note"] = "Freed from the pod; heading west"
	var reaction := Strip.provoke(strip,"pod")
	status_text = "%s %s the Grey pod. %s are out. %s" % [soldiers[active_soldier]["name"],how,pod["origin"].replace(" (in Grey custody)",""),reaction]

func pod_bypass_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if not pod["active"]: return "No pod on the apron."
	if active_soldier != ENGINEER: return "%s bypasses Grey locks. Anyone can cut it instead." % soldiers[ENGINEER]["name"]
	if not pod_next_to(): return "Stand next to the pod (%d,%d)." % [POD.x,POD.y]
	return ""

func pod_bypass() -> bool:
	var reason := pod_bypass_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	open_pod("bypasses the lock on")
	rebuild_movement()
	return true

func pod_cut_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if not pod["active"]: return "No pod on the apron."
	if not pod_next_to(): return "Stand next to the pod (%d,%d)." % [POD.x,POD.y]
	return ""

func pod_cut() -> bool:
	var reason := pod_cut_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	pod["cut"] += 1
	if pod["cut"] >= CUT_AP: open_pod("cuts open")
	else: status_text = "%s starts cutting the pod: 1 more AP." % soldiers[active_soldier]["name"]
	rebuild_movement()
	return true

func team_reason() -> String:
	if ended: return "Operation over."
	if not FireTeam.present(team): return "%s isn't on the field." % team["name"]
	if team["ordered_phase"] == phase: return "One order a turn."
	return ""

func order_team(kind: String) -> bool:
	var reason := team_reason()
	if reason != "": return reject(reason)
	var cell: Vector2i = team["cell"]
	if kind == "hold" and soldier_can_act(active_soldier): cell = soldiers[active_soldier]["cell"]+Vector2i(1,0)
	if kind == "hold" and (not cell_is_in_bounds(cell) or WALL_CELLS.has(cell) or FIXTURES.has(cell)):
		return reject("That square won't hold a team.")
	status_text = FireTeam.order(team,phase,kind,cell,cohort_selected).replace("Guard Team Marsh",team["name"])
	queue_redraw()
	return true

func interrupt_runway_node() -> bool:
	if ended or not FallowCutter.node_present(fallow): return reject("No node to interrupt.")
	if not soldier_can_act(active_soldier) or soldiers[active_soldier]["ap"] < 1 or FallowCutter.distance(soldiers[active_soldier]["cell"],fallow["node"]) > 1:
		return reject("Interrupt: a soldier with 1 AP next to the node at (%d,%d)." % [fallow["node"].x,fallow["node"].y])
	if fallow["interrupted"]: return reject("The node is already interrupted this turn.")
	soldiers[active_soldier]["ap"] -= 1
	status_text = FallowCutter.interrupt(fallow)
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
	if Strip.unit_at(strip,sight_target()) < 0 and FallowCutter.unit_at(fallow,sight_target()) < 0: return "Aim [T], then click a Grey or a Fallow unit."
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
	var grey := Strip.unit_at(strip,target)
	var roll := shot_rng.randi_range(1,100)
	if roll <= info["chance"]:
		status_text = "%s fires (%d%%): %s" % [soldier["name"],info["chance"],Strip.take_hit(strip,grey,4) if grey >= 0 else FallowCutter.take_hit(fallow,FallowCutter.unit_at(fallow,target),FallowCutter.SHOT_DAMAGE)]
	else:
		var reaction := Strip.provoke(strip,"shot") if grey >= 0 else ""
		status_text = "%s fires (%d%%) and misses. %s" % [soldier["name"],info["chance"],reaction]
	if target_at(target) < 0: pinned_target = NONE
	rebuild_movement()
	return true

# ---------------------------------------------------------------- turn

## Round order: player, allied team, Greys, Fallow, environment (the craft), civilians.
func resolve_enemy_turn() -> void:
	if last_enemy_phase == phase: return
	last_enemy_phase = phase
	var lines: Array[String] = []
	var fallow_line := ""
	if phase >= FALLOW_ARRIVAL-1 or fallow["stage"] != "waiting": fallow_line = FallowCutter.act(fallow,self)
	for line in [FireTeam.act(team,self).replace("Guard Team Marsh",team["name"]),Strip.act(strip,self),fallow_line,Craft.act(craft,phase)]:
		if line != "": lines.append(line)
	enemy_message = " ".join(lines) if not lines.is_empty() else "Wind across the runway."
	rebuild_movement()
	check_recovery_failure()
	finalize_result()

func begin_player_phase() -> void:
	super.begin_player_phase()
	if bargain_offered(): status_text = "Round %d. A Grey voice on the channel: one engine, three rounds, the apron; the people untouched. MSG can accept this round only." % phase
	elif not craft["contact"] and Craft.window_open(craft,phase): status_text = "Round %d. The craft's contact window closes after round %d. MSG to the hangar 2 hatch (%d,%d)." % [phase,Craft.WINDOW_ROUND,CRAFT_DOOR.x,CRAFT_DOOR.y]
	else: status_text = "Round %d. %s" % [phase,enemy_message.left(150)]

func enemy_intent() -> String:
	var parts: Array[String] = []
	parts.append("GREYS (stripping, %s)" % ("hostile" if Strip.firing(strip) else ("bargain" if Strip.bargain_active(strip) else "passive")) if not strip["withdrawn"] else "Greys gone")
	parts.append("Plane: %s" % aircraft_state())
	parts.append("Runway rift %d/%d" % [runway_rifts(),RUNWAY_RUIN])
	match fallow["stage"]:
		"signaled": parts.append("FALLOW (hostile) arriving")
		"active": parts.append("FALLOW (hostile): %d marked" % fallow["marked"].size())
	parts.append("Nordic craft: %s, %d charge%s" % ["gone" if craft["left"] else ("contact" if craft["contact"] else "waiting"),craft["charges"],"" if craft["charges"] == 1 else "s"])
	return " · ".join(parts)

func danger_summary() -> String:
	return "Greys strip on a clock and fire only at interference. The Fallow are always hostile to the ground. The Nordic craft doesn't fight; each shield it spends is gone."

func machine_outcome() -> String:
	return "Nordic contact: %s. Sensor data: %s. Charges left: %d." % ["made" + (", the River Bridge craft verified" if craft["river_shield"] else "") if craft["contact"] else "missed","copied" if craft["data"] else "not taken",craft["charges"]]

func feeder_result() -> String:
	var parts: Array[String] = ["Transport plane: %s; runway %s." % [aircraft_state(),"ruined" if runway_ruined() else "clear"]]
	if pod["active"]: parts.append("%s: %s." % [pod["origin"].replace(" (in Grey custody)",""),"freed" if pod["open"] else "still in custody"])
	match strip["bargain"]["state"]:
		"honored","active": parts.append("Grey bargain honored.")
		"broken": parts.append("Grey bargain broken (%s)." % strip["bargain"]["broken_by"])
	parts.append("%s: %d standing." % [team["name"],FireTeam.standing(team)])
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
	return "REGIONAL AIRFIELD / CLEARED" if everyone else "REGIONAL AIRFIELD / PARTIAL"

# ---------------------------------------------------------------- story

func opening_pages() -> Array:
	return [
		{"speaker":"ACT III · THE ENEMY OF MY ENEMY / MISSION 08: REGIONAL AIRFIELD","text":"Ward needs the regional airfield: the last transport capacity in the valley.\n\nA Grey crew is already stripping the field. The east end of the runway is shimmering. And in hangar 2 there's a damaged craft nobody can identify.","tag":"Evacuate the terminal across the runway · make contact · aircraft or sensor data"},
		{"speaker":"PARK","text":"‘Three of them on one field, Sergeant. The grey ones only fight if we touch their shipment. The Fallow fight the ground. That thing in the hangar hasn't fired a shot.’","tag":"Visible hostility: every unit shows its faction and stance"},
		{"speaker":"%s" % team["name"].to_upper(),"text":"‘We'll hold the terminal. Give us one order a turn and we'll keep it.’","tag":"A supporting team holds a sector"}]

func current_pages() -> Array:
	if scene_view == "opening": return opening_pages()
	if scene_view == "debrief": return debrief_pages()
	return log_pages()

func log_pages() -> Array:
	var pages := opening_pages()
	pages.append({"speaker":"INTELLIGENCE / REGIONAL AIRFIELD","text":enemy_intent()+"\n\n"+danger_summary(),"tag":"Observation, not doctrine"})
	if result_ready and not retry_required(): pages.append_array(debrief_pages())
	return pages

func debrief_pages() -> Array:
	var out: Array[String] = []
	var left: Array[String] = []
	for cohort in cohorts:
		if cohort["status"] == "extracted": out.append("%s (%s)" % [cohort["id"],cohort["origin"]])
		else: left.append("%s (%s)" % [cohort["id"],cohort["origin"]])
	var pages: Array = [{"speaker":"REGIONAL AIRFIELD / VERIFIED FIELD REPORT","text":"Out: %s.\nNot out: %s.\n\n%s\n%s" % [", ".join(out) if not out.is_empty() else "none",", ".join(left) if not left.is_empty() else "none",machine_outcome(),feeder_result()],"tag":"Read to the available survivors"}]
	if craft["contact"]:
		pages.append({"speaker":"CUSTODIAN AVEN","text":"‘We have twelve seats. We cannot carry your valley. We will not pretend otherwise.’\n\nShe doesn't ask for anything. That's almost worse.","tag":"Nordic aid is real, and small"})
	if craft["data"]:
		pages.append({"speaker":"BELL / SENSOR DATA","text":"‘That's not an incursion. That's the leading edge. And that's every rescue ship they know of.’\n\nHe holds up one hand.","tag":"The scale of the Fallow; the limits of rescue"})
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
	save_feedback = "Saving isn't available at the airfield yet."
	status_text = save_feedback
	queue_redraw()
	return false

func load_encounter(_path: String = RETURN_SLOT) -> bool:
	save_feedback = "Loading isn't available at the airfield yet."
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
	var fresh = load("res://regional_airfield.tscn").instantiate()
	fresh.auto_resume = false
	fresh.record_path = record_path
	get_parent().add_child(fresh)
	queue_free()

# ---------------------------------------------------------------- drawing (HUD map layer)

func faction_label(center: Vector2, text: String, color: Color, font: Font) -> void:
	draw_rect(Rect2(center+Vector2(-52,-31),Vector2(104,13)),Color(0.04,0.05,0.07,0.85))
	draw_string(font,center+Vector2(-52,-21),text,HORIZONTAL_ALIGNMENT_CENTER,104,9,color)

func draw_mission_layer(projection, font: Font) -> void:
	var size := CELL_SIZE
	for x in range(1,GRID_SIZE.x+1):
		for y in RUNWAY_ROWS:
			draw_rect(Rect2(projection.cell_anchor(Vector2i(x,y)),Vector2.ONE*size),Color(0.3,0.3,0.32,0.2))
		draw_line(projection.cell_anchor(Vector2i(x,8))+Vector2(6,18),projection.cell_anchor(Vector2i(x,8))+Vector2(size-6,18),Color(1,1,1,0.35),2)
	draw_string(font,projection.cell_anchor(Vector2i(1,7))+Vector2(2,-3),"RUNWAY · " + ("RUINED" if runway_ruined() else "rift %d/%d" % [runway_rifts(),RUNWAY_RUIN]),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e6e9f0"))
	draw_string(font,projection.cell_anchor(Vector2i(9,11))+Vector2(0,-4),"TERMINAL",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("d8e6ea"))
	var plane: Vector2 = projection.cell_anchor(PLANE)
	draw_rect(Rect2(plane+Vector2(-30,10),Vector2(size+60,16)),Color("9aa3ad"))
	draw_rect(Rect2(plane+Vector2(4,-8),Vector2(size-8,size+16)),Color("9aa3ad"))
	faction_label(plane+Vector2(18,18),"TRANSPORT · %s" % aircraft_state(),Color("e6e9f0"),font)
	# Nordic craft.
	var hull: Vector2 = projection.cell_anchor(CRAFT)
	if not craft["left"]:
		draw_colored_polygon(PackedVector2Array([hull+Vector2(18,4),hull+Vector2(32,30),hull+Vector2(4,30)]),Color("dfe8f2"))
		faction_label(hull+Vector2(18,18)+Vector2(0,44),"NORDIC · non-combatant · %d charge%s" % [craft["charges"],"" if craft["charges"] == 1 else "s"],Color("bfe3ff"),font)
	for shield in craft["shields"]:
		if phase > shield["until"]: continue
		var at: Vector2 = projection.cell_anchor(shield["center"]-Vector2i.ONE)
		draw_rect(Rect2(at,Vector2.ONE*size*3),Color(0.6,0.85,1,0.18))
		draw_rect(Rect2(at,Vector2.ONE*size*3),Color("bfe3ff"),false,2)
	# Pod.
	if pod["active"] and not pod["open"]:
		var at: Vector2 = projection.cell_anchor(POD)
		draw_rect(Rect2(at+Vector2(-3,-3),Vector2.ONE*(size+6)),Color("b98cff"),false,3)
		draw_string(font,at+Vector2(-20,size+12),"GREY POD" + (" · CUT %d/%d" % [pod["cut"],CUT_AP] if pod["cut"] > 0 else ""),HORIZONTAL_ALIGNMENT_CENTER,76,9,Color("d9b8ff"))
	# Greys.
	if not strip["withdrawn"]:
		for entry in strip["units"]:
			if entry["hp"] <= 0: continue
			var center: Vector2 = projection.cell_anchor(entry["cell"])+Vector2(18,18)
			draw_circle(center,12,Color("c9d3e0"))
			draw_circle(center+Vector2(-4,-3),3,Color("10141a"))
			draw_circle(center+Vector2(4,-3),3,Color("10141a"))
			var stance: String = "HOSTILE" if Strip.firing(strip) else ("bargain" if Strip.bargain_active(strip) else "passive")
			faction_label(center,"GREY %s %d HP · %s" % [entry["kind"].to_upper(),entry["hp"],stance],Color("ff8a80") if Strip.firing(strip) else Color("c9d3e0"),font)
			if not entry["aim"].is_empty():
				draw_line(center,projection.cell_anchor(entry["aim"]["cell"])+Vector2(18,18),Color(1,0.3,0.35,0.85),3)
			if sight_mode and pinned_target == entry["cell"]:
				draw_rect(Rect2(projection.cell_anchor(entry["cell"])+Vector2(1,1),Vector2.ONE*(size-2)),Color("e6a2c7"),false,2)
	# Fallow.
	for cell in fallow.get("rifts",[]):
		draw_rect(Rect2(projection.cell_anchor(cell),Vector2.ONE*size),Color("1a0f24"))
	for cell in fallow.get("marked",[]):
		draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(1,1),Vector2.ONE*(size-2)),Color(0.6,0.3,0.95,0.35))
	if fallow.get("stage","") == "signaled":
		draw_string(font,projection.cell_anchor(FALLOW_ENTRY)+Vector2(-30,-8),"DISTORTION",HORIZONTAL_ALIGNMENT_CENTER,76,9,Color("d9b8ff"))
	if FallowCutter.node_present(fallow):
		draw_circle(projection.cell_anchor(fallow["node"])+Vector2(18,18),10,Color("5e3a8c") if fallow["interrupted"] else Color("b98cff"))
	if FallowCutter.cutter_alive(fallow):
		var center: Vector2 = projection.cell_anchor(fallow["cutter"]["cell"])+Vector2(18,18)
		draw_colored_polygon(PackedVector2Array([center+Vector2(0,-15),center+Vector2(9,0),center+Vector2(0,15),center+Vector2(-9,0)]),Color("2a1a3a"))
		faction_label(center,"FALLOW CUTTER %d HP · hostile" % fallow["cutter"]["hp"],Color("d9b8ff"),font)
	# Supporting team.
	if FireTeam.present(team):
		var center: Vector2 = projection.cell_anchor(team["cell"])+Vector2(18,18)
		for offset in [Vector2(-7,-7),Vector2(7,-7),Vector2(-7,7),Vector2(7,7)]: draw_circle(center+offset,5,Color("9cc48a"))
		faction_label(center,"%s %d · %s" % [team["name"].replace("Guard Team ","TEAM ").to_upper(),FireTeam.standing(team),team["order"].to_upper()],Color("c9f0b5"),font)
