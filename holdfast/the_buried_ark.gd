extends "res://encounter_controller.gd"
## Mission 11 · The Buried Ark. GDD v3.1 §11, the close of Act III: reach the sanctuary past the
## Warden (bypass, disable, negotiate or destroy), hold a parley for terms, and when the Fallow
## incursion fractures the meeting choose among the delegates, life support and the nursery.
## Spec: docs/missions/the-buried-ark.md.
const ArkMission = preload("res://missions/the_buried_ark.tres")
const Warden = preload("res://systems/ark_warden.gd")
const Parley = preload("res://systems/ark_parley.gd")
const FallowCutter = preload("res://systems/fallow_cutter.gd")
const Rig = preload("res://systems/drive_rig.gd")
const CampaignRecord = preload("res://systems/campaign_record.gd")

const WARDEN_CELL := Vector2i(10,7)
const CONSOLE := Vector2i(12,9)
const COUPLING := Vector2i(8,9)
const BATTERY := Vector2i(16,12)
const TABLE := Vector2i(10,4)
const SEAT := Vector2i(10,3)
const ALCOVE := Vector2i(3,6)
const PLANT := Vector2i(7,3)
const DOOR := Vector2i(16,2)
const FALLOW_ENTRY := Vector2i(18,6)
const FALLOW_NODE := Vector2i(19,6)
const INCURSION := 4
const SECOND_NODE := 7
const SECOND_WAVE := 8
const CUTTER_HP := 16       # tougher than Main Street's 12: it has a meeting to break
const PLANT_HP := 3
const CONNECTOR_STEPS := 2
const DELEGATES := 0
const KEEPERS := 1
const NURSERY := 2
const LIFT_SPAWNS: Array[Vector2i] = [Vector2i(8,13),Vector2i(9,13),Vector2i(11,13),Vector2i(12,13)]
const TABLE_LANE: Array[Vector2i] = [Vector2i(17,6),Vector2i(16,6),Vector2i(15,6),Vector2i(14,6),Vector2i(13,5),Vector2i(12,5),Vector2i(11,5),Vector2i(11,4),Vector2i(9,5),Vector2i(9,4),Vector2i(11,3),Vector2i(9,3),Vector2i(10,3)]
const LIFE_LANE: Array[Vector2i] = [Vector2i(17,5),Vector2i(16,5),Vector2i(15,4),Vector2i(14,4),Vector2i(13,3),Vector2i(12,3),Vector2i(12,2),Vector2i(9,2),Vector2i(8,3),Vector2i(8,4),Vector2i(7,4),Vector2i(6,3),Vector2i(8,2)]
const NURSERY_LANE: Array[Vector2i] = [Vector2i(18,5),Vector2i(19,5),Vector2i(18,4),Vector2i(18,3),Vector2i(19,3),Vector2i(17,3),Vector2i(18,2),Vector2i(19,2)]
const REPLACEMENTS := ["Reyes","Okafor","Lindqvist"]

var mission_copy: Resource = null
var record_path := ""
var warden: Dictionary = {}
var parley: Dictionary = {}
var fallow: Dictionary = {}
var trunk := 1
var channel := "partial"
var kesh := true
var aven := false
var aven_charge := false
var start_terms := 0
var council := false
var life := PLANT_HP
var connector := 0
var strips := 0
var packing_line := ""
var carry_notes: Array[String] = []

func mission_definition() -> Resource:
	if mission_override != null: return mission_override
	if mission_copy == null: mission_copy = ArkMission.duplicate(true)
	return mission_copy

func _ready() -> void:
	read_carry_ins()
	if trunk >= 2: mission_definition().squad_spawns = LIFT_SPAWNS.duplicate()
	initialize_tactical()
	initialize_machine()
	initialize_evacuation()
	initialize_breaker()
	initialize_protocol()
	initialize_rescue()
	initialize_results()
	initialize_story()
	initialize_roster(false)
	report_path = "user://holdfast_m11_result.save"
	completion_path = "user://holdfast_m11_completed.save"
	campaign_path = "user://holdfast_m11_campaign.save"
	warden = Warden.initial(WARDEN_CELL)
	parley = Parley.initial(start_terms,kesh,aven)
	fallow = FallowCutter.initial(FALLOW_ENTRY,FALLOW_NODE)
	fallow["cutter"]["hp"] = CUTTER_HP
	var labels := [["D","Parley delegates%s" % (" (with the council's representative)" if council else ""),"Seated at the table"],["L","Life-support keepers","Tending the plant"],["N","Nursery: Ilen and the children","Behind the nursery door"]]
	for index in range(3):
		cohorts[index]["id"] = labels[index][0]
		cohorts[index]["origin"] = labels[index][1]
		cohorts[index]["note"] = labels[index][2]
		cohorts[index]["penned"] = true
	carry_over_squad()
	status_text = "The Buried Ark. The Warden watches the gallery. Get MSG to the parley table (%d,%d)." % [TABLE.x,TABLE.y]
	enemy_message = "Somewhere below, something very old is listening."
	save_feedback = "Saving isn't available at the ark yet."
	rebuild_movement()

func read_carry_ins() -> void:
	if record_path == "": return
	var missions: Dictionary = CampaignRecord.load_record(record_path)["missions"]
	var dam: Dictionary = missions.get(10,{})
	var quarry: Dictionary = missions.get(7,{})
	if not dam.is_empty():
		trunk = dam.get("trunk",0)
		channel = dam.get("channel","partial")
		match dam.get("dependents",""):
			"stabilized":
				start_terms += 2
				carry_notes.append("Dam habitat stabilized: +2 terms")
			_:
				start_terms -= 1
				carry_notes.append("Dam habitat %s: -1 terms" % dam.get("dependents","left"))
		if dam.get("cargo",0) > 0:
			start_terms += 1
			carry_notes.append("Dam cargo delivered: +1 terms")
	elif not quarry.is_empty():
		channel = "authenticated" if quarry.get("controller",false) and quarry.get("habitat","") != "lost" else "hardened" if quarry.get("habitat","") == "lost" else "partial"
	kesh = not (quarry.get("habitat","") == "lost" and dam.get("dependents","") != "stabilized")
	var airfield: Dictionary = missions.get(8,{})
	aven = airfield.get("contact",false) and not airfield.get("retry_required",false)
	aven_charge = aven and airfield.get("charges_left",0) >= 1
	var civic: Dictionary = missions.get(9,{})
	if civic.get("records",false):
		start_terms += 1
		carry_notes.append("Civic records: +1 terms")
	council = civic.get("council_out",false)
	var junction: Dictionary = missions.get(4,{})
	if ["honored","honored_greys_attributed"].has(junction.get("agreement","")):
		start_terms += 1
		carry_notes.append("Interchange agreement held: +1 terms")
	start_terms = maxi(0,start_terms)

func carry_over_squad() -> void:
	if record_path == "": return
	var missions: Dictionary = CampaignRecord.load_record(record_path)["missions"]
	var entry: Dictionary = {}
	for id in [10,9,8,7,6,5,4,3,2,1]:
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

func target_at(cell: Vector2i) -> int:
	if not fallow.is_empty() and FallowCutter.unit_at(fallow,cell) >= 0: return 10+FallowCutter.unit_at(fallow,cell)
	if not warden.is_empty() and cell == WARDEN_CELL and warden["state"] in ["hostile","disabled"]: return 20
	return -1

func civilian_safe(cell: Vector2i) -> bool:
	if not cell_is_in_bounds(cell) or WALL_CELLS.has(cell) or FIXTURES.has(cell): return false
	return target_at(cell) < 0

func civilian_waypoint(_order: String) -> Vector2i:
	return civilian_exit()

func route_label(_order: String) -> String:
	return "Service spur"

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
	threats.append_array(round_noise)
	return threats

func deadline() -> int:
	return mission_definition().closing_round

func mission_completion_reason(round_number: int) -> String:
	return MissionObjectives.completion_reason(mission_definition(),round_number,0,all_extracted(),remaining_civilians())

## At the close the sanctuary seals: delegates and keepers still standing are sheltered inside it.
## The nursery has to be got out.
func close_evacuation(reason: String) -> void:
	if not ended:
		for index in [DELEGATES,KEEPERS]:
			var cohort: Dictionary = cohorts[index]
			if cohort["status"] == "active":
				cohort["status"] = "extracted"
				cohort["note"] = "Sheltered in the sealed sanctuary"
	super.close_evacuation(reason)

func remaining_civilians() -> int:
	return 4 if cohorts[NURSERY]["status"] == "active" else 0

# The Warden watches the gallery mouth.
func try_move(cell: Vector2i) -> bool:
	var index := active_soldier
	var start: Vector2i = soldiers[index]["cell"] if soldier_can_act(index) else NONE
	var moved := super.try_move(cell)
	if moved and start != NONE and Warden.crossing(warden,start,soldiers[index]["cell"]):
		var line := Warden.overwatch(warden,index,self)
		if line != "": status_text = line
		rebuild_movement()
	return moved

# Board hooks for rifts.
func add_rift(cell: Vector2i) -> void:
	var walls: Array[Vector2i] = mission_definition().walls
	walls.erase(cell)
	var fixtures: Array[Vector2i] = mission_definition().fixtures
	if not fixtures.has(cell): fixtures.append(cell)

func throw_clear(cell: Vector2i) -> void:
	var soldier := soldier_at(cell)
	if soldier < 0: return
	for direction in DIRECTIONS:
		var landing: Vector2i = cell+direction
		if cell_is_in_bounds(landing) and not WALL_CELLS.has(landing) and not FIXTURES.has(landing) and soldier_at(landing) < 0 and target_at(landing) < 0:
			soldiers[soldier]["cell"] = landing
			return

func near(cell: Vector2i, other: Vector2i, reach: int) -> bool:
	return Rig.distance(cell,other) <= reach

## The parley sits when the delegates are seated, MSG is within 2 of the table and no Fallow
## unit or mark is within 3 of it.
func parley_sits() -> bool:
	if ended or cohorts[DELEGATES]["status"] != "active" or cohorts[DELEGATES]["cell"] != SEAT: return false
	if soldiers[0]["extracted"] or not soldier_can_act(0) or not near(soldiers[0]["cell"],TABLE,2): return false
	return fallow_clear_of_table()

func fallow_clear_of_table() -> bool:
	for cell in FallowCutter.threat_cells(fallow):
		if near(cell,TABLE,3): return false
	return true

# ---------------------------------------------------------------- the incursion

func lane(index: int) -> Array[Vector2i]:
	return [TABLE_LANE,LIFE_LANE,NURSERY_LANE][index]

func lane_name(index: int) -> String:
	return ["the parley table","the life-support plant","the nursery"][index]

## Mark the next strip, cycling table, life support, nursery; an exhausted lane is skipped.
func mark_strip() -> String:
	var length := 6 if phase >= SECOND_NODE else 4
	for attempt in range(3):
		var which := strips % 3
		strips += 1
		var cells: Array = []
		for cell in lane(which):
			if cells.size() >= length: break
			if fallow["rifts"].has(cell) or (FIXTURES.has(cell) and not WALL_CELLS.has(cell)): continue
			cells.append(cell)
		if not cells.is_empty():
			fallow["marked"] = cells
			fallow["target"] = which
			return "The cutter marks %d squares toward %s." % [cells.size(),lane_name(which)]
	fallow["marked"] = []
	return ""

func fold_strip() -> String:
	var hurt: Array[String] = []
	var touched_plant := false
	for cell in fallow["marked"]:
		if fallow["rifts"].has(cell): continue
		fallow["rifts"].append(cell)
		add_rift(cell)
		if soldier_at(cell) >= 0 or cohort_at(cell) >= 0:
			hurt.append(apply_casualty_damage(cell,FallowCutter.RIFT_DAMAGE if soldier_at(cell) >= 0 else FallowCutter.RIFT_CROWD_DAMAGE))
		throw_clear(cell)
		if Rig.distance(cell,PLANT) == 1: touched_plant = true
	fallow["marked"] = []
	var line := "The marked ground folds into rift."
	if touched_plant and life > 0:
		life -= 1
		line += " The life-support plant shudders (%d/%d)." % [life,PLANT_HP]
		if life == 0:
			line += " It fails. The keepers fall back from the dead plant."
			cohorts[KEEPERS]["note"] = "Life support lost"
	if not hurt.is_empty(): line += " Caught: " + "; ".join(hurt) + "."
	return line

func fallow_act() -> String:
	if fallow["stage"] == "waiting":
		if phase < INCURSION-1: return ""
		fallow["stage"] = "active"
		var delegates: Dictionary = cohorts[DELEGATES]
		if delegates["status"] == "active":
			delegates["cell"] = ALCOVE
			delegates["note"] = "Scattered to the shelter alcove"
		return "THE EAST WALL TEARS OPEN. A Fallow cutter comes through the rift, a node anchored behind it. The delegates scatter to the alcove. " + mark_strip()
	if not FallowCutter.cutter_alive(fallow):
		if phase >= SECOND_WAVE-1 and not fallow.get("second_wave",false):
			fallow["second_wave"] = true
			fallow["cutter"]["hp"] = CUTTER_HP
			fallow["cutter"]["cell"] = FALLOW_ENTRY
			fallow["interrupted"] = false
			if soldier_at(FALLOW_ENTRY) >= 0: throw_clear(FALLOW_ENTRY)
			return "The rift opens again. A second cutter comes through. " + mark_strip()
		return ""
	if fallow["interrupted"]:
		fallow["interrupted"] = false
		return "The cutter hesitates without its link; the marks hold."
	var line := fold_strip()
	var next := mark_strip()
	return line + (" " + next if next != "" else "")

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
	return soldier_can_act(active_soldier) and Rig.distance(soldiers[active_soldier]["cell"],cell) == 1

func console_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if not Warden.hostile(warden): return "The Warden isn't hostile."
	if trunk == 0: return "The Warden console is dark: no ark trunk power came through from the Dam."
	if not (trunk >= 2 or (channel == "authenticated" and trunk >= 1)): return "No authenticated control: it needs full trunk power from the Dam, or Kesh's authenticated channel."
	if active_soldier != 0: return "MSG negotiates. Select MSG."
	if not next_to(CONSOLE): return "Stand next to the Warden console (%d,%d)." % [CONSOLE.x,CONSOLE.y]
	return ""

func negotiate_warden() -> bool:
	var reason := console_reason()
	if reason != "": return reject(reason)
	soldiers[0]["ap"] -= 1
	warden["state"] = "allied"
	warden["marked"] = []
	warden["log"].append("negotiated:%d" % phase)
	status_text = "MSG keys the authenticated handshake. The Warden's eye dims, then turns away from the gallery. It's listening to the stewards now."
	rebuild_movement()
	return true

func disable_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if not Warden.hostile(warden): return "The Warden isn't hostile."
	if active_soldier != 2: return "Bell's job (the engineer). Select %s." % soldiers[2]["name"]
	if not next_to(COUPLING): return "Stand next to the Warden's power coupling (%d,%d)." % [COUPLING.x,COUPLING.y]
	return ""

func disable_warden() -> bool:
	var reason := disable_reason()
	if reason != "": return reject(reason)
	soldiers[2]["ap"] -= 1
	warden["disable"] += 1
	if warden["disable"] >= Warden.DISABLE_STEPS:
		warden["state"] = "disabled"
		warden["marked"] = []
		warden["log"].append("disabled:%d" % phase)
		status_text = "%s pulls the coupling. The Warden sags in its mount, damaged. It won't guard anything now." % soldiers[2]["name"]
	else:
		status_text = "Coupling %d/%d." % [warden["disable"],Warden.DISABLE_STEPS]
	rebuild_movement()
	return true

func connector_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if connector >= CONNECTOR_STEPS: return "The reserve connector is seated."
	if active_soldier != 2: return "Bell's job (the engineer). Select %s." % soldiers[2]["name"]
	if not next_to(BATTERY): return "Stand next to the reserve battery (%d,%d)." % [BATTERY.x,BATTERY.y]
	return ""

func seat_connector() -> bool:
	var reason := connector_reason()
	if reason != "": return reject(reason)
	soldiers[2]["ap"] -= 1
	connector += 1
	status_text = "Reserve connector seated. One launch, if the primary ever fails." if connector >= CONNECTOR_STEPS else "Reserve connector %d/%d: corroded, but it's the original part." % [connector,CONNECTOR_STEPS]
	rebuild_movement()
	return true

func nursery_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if not cohorts[NURSERY].get("penned",false): return "The nursery door is open."
	if not next_to(DOOR): return "Stand next to the nursery door (%d,%d)." % [DOOR.x,DOOR.y]
	return ""

func open_nursery() -> bool:
	var reason := nursery_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	mission_definition().fixtures.erase(DOOR)
	var cohort: Dictionary = cohorts[NURSERY]
	cohort["penned"] = false
	cohort["order"] = "south"
	cohort["passed"] = false
	cohort["note"] = "Heading for the spur with %s" % soldiers[active_soldier]["name"]
	status_text = "The nursery door grinds open. Ilen herds the children out. They head for the spur."
	rebuild_movement()
	return true

func recall_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	var delegates: Dictionary = cohorts[DELEGATES]
	if delegates["status"] != "active": return "The delegates are gone."
	if delegates["cell"] == SEAT: return "The delegates are at the table."
	if active_soldier != 0: return "MSG calls the delegates back. Select MSG."
	if not near(soldiers[0]["cell"],delegates["cell"],6) and not near(soldiers[0]["cell"],TABLE,2): return "MSG has to be within 6 of the delegates, or at the table."
	if not fallow_clear_of_table(): return "Not while the Fallow are within 3 of the table."
	if soldier_at(SEAT) >= 0: return "Someone is standing in the delegates' place."
	return ""

func recall_delegates() -> bool:
	var reason := recall_reason()
	if reason != "": return reject(reason)
	soldiers[0]["ap"] -= 1
	cohorts[DELEGATES]["cell"] = SEAT
	cohorts[DELEGATES]["note"] = "Back at the table"
	status_text = "MSG brings the delegates back to the table. Nobody sits down quickly."
	rebuild_movement()
	return true

func shield_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if not aven_charge: return "Aven has no protection charge to give." if aven else "Aven isn't here: no Nordic contact at the Airfield."
	if fallow["marked"].is_empty(): return "Nothing is marked."
	if active_soldier != 0: return "MSG asks Aven. Select MSG."
	return ""

func shield_strip() -> bool:
	var reason := shield_reason()
	if reason != "": return reject(reason)
	soldiers[0]["ap"] -= 1
	aven_charge = false
	var count: int = fallow["marked"].size()
	fallow["marked"] = []
	status_text = "Aven raises a shield over the %d marked squares. The fold breaks against it. That was her last charge." % count
	rebuild_movement()
	return true

func interrupt_rift_node() -> bool:
	var reason := node_reason()
	if reason != "": return reject(reason)
	if ended or not FallowCutter.node_present(fallow) or not FallowCutter.cutter_alive(fallow): return reject("No node to interrupt.")
	if not soldier_can_act(active_soldier) or soldiers[active_soldier]["ap"] < 1 or FallowCutter.distance(soldiers[active_soldier]["cell"],fallow["node"]) > 1:
		return reject("Interrupt: a soldier with 1 AP next to the node at (%d,%d)." % [fallow["node"].x,fallow["node"].y])
	if fallow["interrupted"]: return reject("The node is already interrupted this turn.")
	soldiers[active_soldier]["ap"] -= 1
	fallow["relink"] = phase+1
	status_text = FallowCutter.interrupt(fallow) + " It re-links next round: no second interrupt then."
	rebuild_movement()
	return true

## The node re-links for a round after an interrupt, so the Fallow can't be frozen outright.
func node_reason() -> String:
	if ended or not FallowCutter.node_present(fallow) or not FallowCutter.cutter_alive(fallow): return "No node to interrupt."
	if phase <= fallow.get("relink",0): return "The node is re-linking after the last interrupt. Next round."
	return ""

func fire_block_reason() -> String:
	if ended: return "Operation ended."
	if not soldier_can_act(active_soldier): return "Select a standing soldier."
	var soldier: Dictionary = soldiers[active_soldier]
	if soldier.get("carrying",-1) >= 0: return "Cannot fire while carrying."
	if soldier["ap"] < 1: return "No AP left."
	if soldier["attacked"]: return "Already fired this round."
	if soldier["ammo"] < 1: return "Out of ammunition: reload."
	if target_at(sight_target()) < 0: return "Aim [T], then click the cutter, the node or the Warden."
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
	var hit: bool = shot_rng.randi_range(1,100) <= info["chance"]
	if target == WARDEN_CELL:
		status_text = "%s fires on the Warden (%d%%): %s" % [soldier["name"],info["chance"],Warden.take_hit(warden,FallowCutter.SHOT_DAMAGE,soldier["cell"].y < WARDEN_CELL.y) if hit else "miss."]
	elif hit:
		status_text = "%s fires (%d%%): %s" % [soldier["name"],info["chance"],FallowCutter.take_hit(fallow,FallowCutter.unit_at(fallow,target),FallowCutter.SHOT_DAMAGE)]
	else:
		status_text = "%s fires (%d%%) and misses." % [soldier["name"],info["chance"]]
	if target_at(target) < 0: pinned_target = NONE
	rebuild_movement()
	return true

# ---------------------------------------------------------------- turn

func resolve_enemy_turn() -> void:
	if last_enemy_phase == phase: return
	last_enemy_phase = phase
	var lines: Array[String] = []
	for line in [Warden.act(warden,fallow,self),fallow_act(),Parley.session(parley,parley_sits(),phase)]:
		if line != "": lines.append(line)
	enemy_message = " ".join(lines)
	rebuild_movement()
	check_recovery_failure()
	finalize_result()

func begin_player_phase() -> void:
	super.begin_player_phase()
	status_text = "Round %d. Terms %d. Warden %s.%s" % [phase,parley["terms"],warden["state"]," Life support %d/%d." % [life,PLANT_HP] if fallow["stage"] == "active" else ""]

func enemy_intent() -> String:
	var parts: Array[String] = ["TERMS %d (%s)" % [parley["terms"],agreement()]]
	parts.append("Warden %s%s" % [warden["state"],", %d marked" % warden["marked"].size() if not warden["marked"].is_empty() else ""])
	if fallow["stage"] == "waiting": parts.append("incursion expected round %d" % INCURSION)
	elif FallowCutter.cutter_alive(fallow): parts.append("FALLOW cutter %d HP, %d marked toward %s" % [fallow["cutter"]["hp"],fallow["marked"].size(),lane_name(fallow.get("target",0))])
	parts.append("Life support %d/%d" % [life,PLANT_HP])
	return " · ".join(parts)

func danger_summary() -> String:
	return "The Warden shoots anyone crossing the gallery mouth and marks whoever stands in its cone, firing next phase. From round %d the Fallow mark strips toward the table, the life-support plant and the nursery in turn; marks fold a phase later. Kill the cutter and a second one comes through the rift in round %d." % [INCURSION,SECOND_WAVE]

func agreement() -> String:
	return Parley.agreement(parley,life > 0)

func machine_outcome() -> String:
	return "The Warden: %s. Parley terms %d: a %s agreement." % [{"hostile":"intact, still hostile","allied":"preserved and allied","disabled":"disabled (damaged)","destroyed":"destroyed"}[warden["state"]],parley["terms"],agreement()]

func feeder_result() -> String:
	return "Life support %d/%d%s. Reserve connector %s." % [life,PLANT_HP," (lost)" if life == 0 else "","seated" if connector >= CONNECTOR_STEPS else "not seated"]

func group_state(index: int) -> String:
	var cohort: Dictionary = cohorts[index]
	if cohort["status"] == "extracted": return "safe" if cohort["hp"] >= 4 else "hurt"
	if cohort["status"] == "active": return "in danger"
	return "lost"

func result_title() -> String:
	if retry_required(): return "ATTEMPT ENDED / RETRY REQUIRED"
	return "THE BURIED ARK / %s AGREEMENT" % agreement().to_upper()

# ---------------------------------------------------------------- story

func opening_pages() -> Array:
	var kesh_line := "‘You came. Good. Walk slowly in the gallery; the Warden is older than our names for it.’" if kesh else "A steward you haven't met speaks for the habitats. Kesh isn't here. ‘Kesh's families were left to the water. Say what you came to say.’"
	var pages: Array = [
		{"speaker":"ACT III · MISSION 11: THE BURIED ARK","text":"The service spur goes down further than any survey said. At the bottom, the cavern opens, and what's in it isn't a ruin. It's a ship, grown over with gardens.\n\nIn the sanctuary at its heart, a parley is waiting: Ward's people, the ark stewards%s." % (", and Custodian Aven" if aven else ""),"tag":"Reach the sanctuary; protect the parley"},
		{"speaker":"KESH" if kesh else "A STEWARD","text":kesh_line,"tag":"Kesh at the table" if kesh else "Kesh absent: another steward speaks"},
		{"speaker":"BELL","text":"‘That thing in the gallery's tracking us. Coupling's on the left. There's a console on the right, if anybody's got the keys.’%s" % (" The console lamps are dark." if trunk == 0 else ""),"tag":"The Warden: bypass, disable, negotiate"}]
	if not carry_notes.is_empty():
		pages.append({"speaker":"WHAT YOU BRING TO THE TABLE","text":"\n".join(carry_notes) + "\n\nStarting terms: %d." % start_terms,"tag":"Prior actions widen the terms"})
	return pages

func current_pages() -> Array:
	if scene_view == "opening": return opening_pages()
	if scene_view == "debrief": return debrief_pages()
	return log_pages()

func log_pages() -> Array:
	var pages := opening_pages()
	pages.append({"speaker":"INTELLIGENCE / THE BURIED ARK","text":enemy_intent()+"\n\n"+danger_summary(),"tag":"Observation, not doctrine"})
	if result_ready and not retry_required(): pages.append_array(debrief_pages())
	return pages

func debrief_pages() -> Array:
	var lines: Array[String] = []
	for index in range(3): lines.append("%s (%s): %s" % [cohorts[index]["id"],cohorts[index]["origin"],group_state(index)])
	var pages: Array = [{"speaker":"THE BURIED ARK / VERIFIED FIELD REPORT","text":"%s\n\n%s\n%s" % ["\n".join(lines),machine_outcome(),feeder_result()],"tag":"Read to the available survivors"}]
	pages.append({"speaker":"THE AGREEMENT","text":{"generous":"The stewards open more of the ark than anyone asked for. Berths, boarding time, the lift. Life support can carry it.","working":"A working agreement: human evacuees board alongside the habitats, on a schedule both sides can check.","narrow":"A narrow bargain. Some berths, a short boarding window, and every promise counted twice."}[agreement()] + "\n\nThen the observations come in from the stewards' instruments%s. They say the same thing. The Fallow aren't stopping. Earth can't be held." % (" and Aven's sensors" if aven else ""),"tag":"Act III exit: the goal becomes evacuation"})
	var ortiz: String = "Ortiz" if soldiers[1]["name"] == "Ortiz" and soldiers[1]["condition"] != "dead" else soldiers[1]["name"]
	var bell: String = "Bell" if soldiers[2]["name"] == "Bell" and soldiers[2]["condition"] != "dead" else soldiers[2]["name"]
	var text := "Back at the base, people are packing.\n\n%s asks whether medical records count against personal cargo. %s sets down a spare tool he can't justify carrying, then picks it up again, then sets it down." % [ortiz,bell]
	if packing_line != "": text += "\n\nMSG: " + {"duty":"‘We carry what keeps people alive. Everything else is weight.’","uncertainty":"‘I don't know what we'll need. Nobody does. Pack like you'll find out.’","people":"‘There are still people out there we can reach. Leave room.’"}[packing_line]
	pages.append({"speaker":"PACKING","text":text,"tag":"The loss of home registers"})
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
	if scene_view == "debrief" and scene_page == debrief_pages().size()-1 and packing_line == "" and soldiers[0]["condition"] != "dead":
		return ["Duty: carry what keeps people alive.","Uncertainty: nobody knows what we'll need.","The people still in reach: leave room."]
	return []

func choose_scene_option(index: int) -> void:
	if scene_options().is_empty(): return
	packing_line = ["duty","uncertainty","people"][clampi(index,0,2)]
	queue_redraw()

# ---------------------------------------------------------------- saves and retry

func save_encounter(_path: String = RETURN_SLOT) -> bool:
	save_feedback = "Saving isn't available at the ark yet."
	status_text = save_feedback
	queue_redraw()
	return false

func load_encounter(_path: String = RETURN_SLOT) -> bool:
	save_feedback = "Loading isn't available at the ark yet."
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
	var fresh = load("res://the_buried_ark.tscn").instantiate()
	fresh.auto_resume = false
	fresh.record_path = record_path
	get_parent().add_child(fresh)
	queue_free()

# ---------------------------------------------------------------- drawing (HUD map layer)

func draw_mission_layer(projection, font: Font) -> void:
	var size := CELL_SIZE
	if Warden.hostile(warden):
		for cell in Warden.cone_cells(warden):
			if cell_is_in_bounds(cell) and not WALL_CELLS.has(cell): draw_rect(Rect2(projection.cell_anchor(cell),Vector2.ONE*size),Color(1.0,0.55,0.2,0.12))
		for cell in warden["marked"]:
			draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(2,2),Vector2.ONE*(size-4)),Color("ff8a3d"),false,3)
	var eye: Vector2 = projection.cell_anchor(WARDEN_CELL)+Vector2(18,18)
	var eye_color: Color = {"hostile":Color("ff8a3d"),"allied":Color("8be6de"),"disabled":Color("6a6a6a"),"destroyed":Color("3a3a3a")}[warden["state"]]
	draw_circle(eye,14,Color("1e2630"))
	draw_circle(eye,8,eye_color)
	draw_string(font,eye+Vector2(-50,-20),"WARDEN · %s%s" % [warden["state"].to_upper()," %d HP" % warden["hp"] if warden["state"] == "hostile" else ""],HORIZONTAL_ALIGNMENT_CENTER,100,9,eye_color)
	var labels: Array = [[CONSOLE,"CONSOLE" if trunk > 0 else "CONSOLE (dark)"],[COUPLING,"COUPLING %d/%d" % [warden["disable"],Warden.DISABLE_STEPS]],[BATTERY,"RESERVE %d/%d" % [connector,CONNECTOR_STEPS]],[TABLE,"PARLEY · %d" % parley["terms"]],[PLANT,"LIFE %d/%d" % [life,PLANT_HP]]]
	if cohorts[NURSERY].get("penned",false): labels.append([DOOR,"NURSERY DOOR"])
	for pair in labels:
		var at: Vector2 = projection.cell_anchor(pair[0])
		var color := Color("ff8a80") if pair[0] == PLANT and life == 0 else Color("8be6de")
		draw_rect(Rect2(at+Vector2(3,3),Vector2.ONE*(size-6)),Color("2b3a4a"))
		draw_rect(Rect2(at+Vector2(3,3),Vector2.ONE*(size-6)),color,false,2)
		draw_string(font,at+Vector2(-24,-4),pair[1],HORIZONTAL_ALIGNMENT_CENTER,84,9,color)
	for cell in fallow.get("rifts",[]):
		draw_rect(Rect2(projection.cell_anchor(cell),Vector2.ONE*size),Color("1a0f24"))
	for cell in fallow.get("marked",[]):
		draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(1,1),Vector2.ONE*(size-2)),Color(0.6,0.3,0.95,0.35))
	if FallowCutter.node_present(fallow) and FallowCutter.cutter_alive(fallow):
		draw_circle(projection.cell_anchor(fallow["node"])+Vector2(18,18),10,Color("5e3a8c") if fallow["interrupted"] else Color("b98cff"))
	if FallowCutter.cutter_alive(fallow):
		var center: Vector2 = projection.cell_anchor(fallow["cutter"]["cell"])+Vector2(18,18)
		draw_colored_polygon(PackedVector2Array([center+Vector2(0,-15),center+Vector2(9,0),center+Vector2(0,15),center+Vector2(-9,0)]),Color("2a1a3a"))
		draw_string(font,center+Vector2(-40,-21),"CUTTER %d HP" % fallow["cutter"]["hp"],HORIZONTAL_ALIGNMENT_CENTER,80,9,Color("d9b8ff"))
