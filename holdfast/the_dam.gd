extends "res://encounter_controller.gd"
## Mission 10 · The Dam (spec: docs/missions/the-dam.md). Act III's first cooperative mission.
## Pressure behind the dam rises each round; every spillway release floods someone. Kesh guides
## at the level the Quarry earned. Three power units: footbridge, habitat life support, ark
## trunk. Drover dependents shelter in the habitat until it's stabilized. Optional cargo.
## The Farm Road machine is switched off. Save/load for this mission comes later.
const DamMission = preload("res://missions/the_dam.tres")
const Dam = preload("res://systems/dam_works.gd")
const FallowCutter = preload("res://systems/fallow_cutter.gd")
const Rig = preload("res://systems/drive_rig.gd")
const CampaignRecord = preload("res://systems/campaign_record.gd")

const WEST_VALVE := Vector2i(5,2)
const EAST_VALVE := Vector2i(15,2)
const TURBINE := Vector2i(8,4)
const CONSOLE := Vector2i(17,8)
const JUNCTION := Vector2i(16,11)
const TRUNK := Vector2i(19,14)
const BRIDGE: Array[Vector2i] = [Vector2i(9,13),Vector2i(10,13)]
const CRATES: Array[Vector2i] = [Vector2i(12,8),Vector2i(12,10)]
const DEPENDENTS := 2
const TRANSPORT_START := Vector2i(14,14)
const FALLOW_ENTRY := Vector2i(19,2)
const FALLOW_NODE := Vector2i(20,2)
const REPLACEMENTS := ["Reyes","Okafor","Lindqvist"]

var mission_copy: Resource = null
var record_path := ""
var dam: Dictionary = {}
var fallow: Dictionary = {}
var transport: Dictionary = {}
var crates: Array = []            # each {"cell","state"}: ground / loaded / carried:<soldier> / delivered / lost
## Carry-ins.
var channel := "partial"
var needs_repair := false
var transport_kind := ""          # "rig", "cart" or ""

func mission_definition() -> Resource:
	if mission_override != null: return mission_override
	if mission_copy == null: mission_copy = DamMission.duplicate(true)
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
	report_path = "user://holdfast_m10_result.save"
	completion_path = "user://holdfast_m10_completed.save"
	campaign_path = "user://holdfast_m10_campaign.save"
	dam = Dam.initial(channel,needs_repair)
	fallow = FallowCutter.initial(FALLOW_ENTRY,FALLOW_NODE)
	transport = Rig.initial(transport_kind != "",TRANSPORT_START)
	transport["kind"] = transport_kind
	transport["cargo"] = 0
	transport["driving"] = false
	for cell in CRATES: crates.append({"cell":cell,"state":"ground"})
	cohorts[0]["origin"] = "Farm families from the lowland"
	cohorts[1]["origin"] = "Lowland road crews"
	cohorts[DEPENDENTS]["origin"] = "Drover dependents in the habitat"
	cohorts[DEPENDENTS]["penned"] = true
	cohorts[DEPENDENTS]["note"] = "Sheltering in the habitat"
	carry_over_squad()
	status_text = "The Dam: pressure %d of %d. Every spillway release floods someone. Assign power at the turbine (8,4)." % [dam["pressure"],Dam.BREACH]
	enemy_message = "Water hammers the spillway gates."
	save_feedback = "Saving isn't available at the dam yet."
	rebuild_movement()

func read_carry_ins() -> void:
	if record_path == "": return
	var missions: Dictionary = CampaignRecord.load_record(record_path)["missions"]
	var quarry: Dictionary = missions.get(7,{})
	if quarry.is_empty(): channel = "partial"
	elif quarry.get("controller",false) and quarry.get("habitat","") != "lost": channel = "authenticated"
	elif quarry.get("habitat","") == "lost": channel = "hardened"
	else: channel = "partial"
	needs_repair = quarry.get("habitat","") == "strained"
	if ["present","dug"].has(quarry.get("rig","absent")): transport_kind = "rig"
	elif not missions.get(4,{}).is_empty() and missions[4].get("security",{}).get("killed",1) == 0: transport_kind = "cart"

func carry_over_squad() -> void:
	if record_path == "": return
	var missions: Dictionary = CampaignRecord.load_record(record_path)["missions"]
	var entry: Dictionary = {}
	for id in [9,8,7,6,5,4,3,2,1]:
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

func in_zone(side: String, cell: Vector2i) -> bool:
	if side == "west": return cell.x >= 1 and cell.x <= 8 and cell.y >= 9 and cell.y <= 14
	return (cell.x >= 11 and cell.x <= 12 and cell.y >= 8 and cell.y <= 10) or cell == Vector2i(13,9)

func low_ground(cell: Vector2i) -> bool:
	return cell.y >= 7

func zone_clear(side: String) -> bool:
	for cohort in cohorts:
		if cohort["status"] == "active" and in_zone(side,cohort["cell"]): return false
	for index in range(soldiers.size()):
		if soldier_can_act(index) and in_zone(side,soldiers[index]["cell"]): return false
	for crate in crates:
		if crate["state"] == "ground" and in_zone(side,crate["cell"]): return false
	return true

func crate_at(cell: Vector2i) -> int:
	for index in range(crates.size()):
		if crates[index]["state"] == "ground" and crates[index]["cell"] == cell: return index
	return -1

func target_at(cell: Vector2i) -> int:
	if not fallow.is_empty() and FallowCutter.unit_at(fallow,cell) >= 0: return 10+FallowCutter.unit_at(fallow,cell)
	if not transport.is_empty() and transport["present"] and transport["cell"] == cell: return 40
	if crate_at(cell) >= 0: return 50
	return -1

func civilian_safe(cell: Vector2i) -> bool:
	if not cell_is_in_bounds(cell) or WALL_CELLS.has(cell) or FIXTURES.has(cell): return false
	if target_at(cell) >= 0: return false
	for side in ["west","east"]:
		if Dam.flooding(dam,side,phase) and in_zone(side,cell): return false
	return true

func is_walkable(cell: Vector2i) -> bool:
	if not super.is_walkable(cell): return false
	for side in ["west","east"]:
		if Dam.flooding(dam,side,phase) and in_zone(side,cell): return false
	return true

func civilian_waypoint(_order: String) -> Vector2i:
	return civilian_exit()

func route_label(_order: String) -> String:
	return "South road"

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

# Board hooks for dam_works.
func add_rift(cell: Vector2i) -> void:
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

func flood_zone(side: String) -> Array[String]:
	var hurt: Array[String] = []
	for x in range(1,GRID_SIZE.x+1):
		for y in range(1,GRID_SIZE.y+1):
			var cell := Vector2i(x,y)
			if not in_zone(side,cell): continue
			if soldier_at(cell) >= 0: hurt.append(apply_casualty_damage(cell,Dam.FLOOD_DAMAGE))
			elif cohort_at(cell) >= 0: hurt.append(apply_casualty_damage(cell,Dam.FLOOD_CROWD_DAMAGE))
			var crate := crate_at(cell)
			if crate >= 0:
				crates[crate]["state"] = "lost"
				dam["crates_lost"] += 1
				hurt.append("a cargo crate swept away")
	return hurt

func breach() -> String:
	var lost: Array[String] = []
	for cohort in cohorts:
		if cohort["status"] == "active" and low_ground(cohort["cell"]) and not cohort.get("penned",false):
			cohort["status"] = "stranded"
			cohort["note"] = "Swept away when the dam breached"
			lost.append("group " + cohort["id"])
	var dependents: Dictionary = cohorts[DEPENDENTS]
	if dependents["status"] in ["active","extracted"]:
		dependents["status"] = "stranded"
		dependents["penned"] = false
		dependents["note"] = "The habitat flooded when the dam breached"
		lost.append("the habitat")
	for index in range(soldiers.size()):
		if soldier_can_act(index) and low_ground(soldiers[index]["cell"]): lost.append(apply_casualty_damage(soldiers[index]["cell"],12))
	for crate in crates:
		if crate["state"] == "ground": crate["state"] = "lost"
	finish_operation("Dam breached")
	return "THE DAM BREACHES. The reservoir comes down the valley. Lost: %s." % (", ".join(lost) if not lost.is_empty() else "nobody on low ground")

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

func valve_reason(side: String) -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if Dam.flooding(dam,side,phase): return "The %s spillway is already running." % side
	var valve := WEST_VALVE if side == "west" else EAST_VALVE
	var remote: bool = dam["channel"] == "authenticated" and active_soldier == 0 and soldiers[0]["cell"].y == Dam.CREST_ROW
	if not next_to(valve) and not remote: return "Stand next to the %s valve (%d,%d)%s." % [side,valve.x,valve.y," (MSG on the crest can open it remotely)" if dam["channel"] == "authenticated" else ""]
	return ""

func open_valve(side: String) -> bool:
	var reason := valve_reason(side)
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	status_text = Dam.open_valve(dam,side,self)
	rebuild_movement()
	return true

func power_reason(system: String) -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if active_soldier != 0: return "MSG assigns power. Select MSG."
	if not next_to(TURBINE): return "MSG has to stand next to the turbine (%d,%d)." % [TURBINE.x,TURBINE.y]
	if system != "trunk" and not dam["power"][system] and Dam.power_used(dam) >= Dam.POWER: return "All %d power units are assigned. Take one back first." % Dam.POWER
	return ""

## Bridge and life support toggle; the trunk steps up while power is free, otherwise back to 0.
func assign_power(system: String) -> bool:
	var reason := power_reason(system)
	if reason != "": return reject(reason)
	soldiers[0]["ap"] -= 1
	if system == "trunk":
		dam["power"]["trunk"] = dam["power"]["trunk"]+1 if dam["power"]["trunk"] < 2 and Dam.power_used(dam) < Dam.POWER else 0
	else:
		dam["power"][system] = not dam["power"][system]
	update_bridge()
	status_text = "Power: footbridge %s, life support %s, ark trunk %d. %d of %d used." % ["on" if dam["power"]["bridge"] else "off","on" if dam["power"]["life"] else "off",dam["power"]["trunk"],Dam.power_used(dam),Dam.POWER]
	rebuild_movement()
	return true

func update_bridge() -> void:
	var walls: Array[Vector2i] = mission_definition().walls
	for cell in BRIDGE:
		if dam["power"]["bridge"]: walls.erase(cell)
		elif not walls.has(cell) and soldier_at(cell) < 0 and cohort_at(cell) < 0: walls.append(cell)

func repair_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if not dam["needs_repair"] or dam["repair"] >= Dam.REPAIR_STEPS: return "Nothing to repair."
	if not next_to(JUNCTION): return "Stand next to the habitat power junction (%d,%d)." % [JUNCTION.x,JUNCTION.y]
	return ""

func repair_junction() -> bool:
	var reason := repair_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	dam["repair"] += 1
	status_text = "Habitat junction repaired: the Quarry isolation is bridged." if dam["repair"] >= Dam.REPAIR_STEPS else "Junction repair %d/%d." % [dam["repair"],Dam.REPAIR_STEPS]
	rebuild_movement()
	return true

func stabilize_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if dam["stabilized"]: return "The habitat is stable."
	if dam["breached"]: return "The habitat is gone."
	if not dam["power"]["life"]: return "Assign power to habitat life support first."
	if dam["needs_repair"] and dam["repair"] < Dam.REPAIR_STEPS: return "Repair the habitat power junction (%d,%d) first: the Quarry isolation cut it." % [JUNCTION.x,JUNCTION.y]
	if not next_to(CONSOLE): return "Stand next to the habitat console (%d,%d)." % [CONSOLE.x,CONSOLE.y]
	return ""

func stabilize_habitat() -> bool:
	var reason := stabilize_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	dam["stabilize"] += 1
	if dam["stabilize"] >= Dam.STABILIZE_STEPS:
		dam["stabilized"] = true
		var cohort: Dictionary = cohorts[DEPENDENTS]
		cohort["status"] = "extracted"
		cohort["note"] = "Sheltered: the habitat is stable"
		dam["log"].append("stabilized:%d" % phase)
		status_text = "Life support holds. The families in the habitat settle. Somebody hands Ortiz a cup of something warm."
	else:
		status_text = "Habitat stabilization %d/%d." % [dam["stabilize"],Dam.STABILIZE_STEPS]
	rebuild_movement()
	return true

func carried_by(index: int) -> int:
	for crate_index in range(crates.size()):
		if crates[crate_index]["state"] == "carried:%d" % index: return crate_index
	return -1

func crate_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	var soldier_cell: Vector2i = soldiers[active_soldier]["cell"]
	if carried_by(active_soldier) >= 0:
		return "" if Rig.distance(soldier_cell,TRUNK) == 1 else "Carry the crate to the trunk tunnel (%d,%d)." % [TRUNK.x,TRUNK.y]
	for crate in crates:
		if crate["state"] == "ground" and Rig.distance(crate["cell"],soldier_cell) == 1: return ""
	return "Stand next to a cargo crate."

## Pick up an adjacent crate, or set it down at the trunk tunnel.
func handle_crate() -> bool:
	var reason := crate_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	var carried := carried_by(active_soldier)
	if carried >= 0:
		crates[carried]["state"] = "delivered"
		dam["delivered"] += 1
		status_text = "%s sets the crate down in the trunk tunnel. Seed stock, by the smell of it." % soldiers[active_soldier]["name"]
	else:
		for crate in crates:
			if crate["state"] == "ground" and Rig.distance(crate["cell"],soldiers[active_soldier]["cell"]) == 1:
				crate["state"] = "carried:%d" % active_soldier
				status_text = "%s shoulders a cargo crate. No firing while carrying it." % soldiers[active_soldier]["name"]
				break
	rebuild_movement()
	return true

func transport_reason() -> String:
	if ended: return "Operation over."
	if not transport["present"]: return "No transport: no Drive Rig from the Quarry, and no Drover cart (Drover security died at the Interchange)."
	if transport["ordered_phase"] == phase: return "One transport order a turn."
	if not soldier_can_act(0) or Rig.distance(soldiers[0]["cell"],transport["cell"]) > Rig.VOICE: return "MSG has to be within %d squares of the %s." % [Rig.VOICE,"rig" if transport["kind"] == "rig" else "cart"]
	return ""

func order_transport(kind: String) -> bool:
	var reason := transport_reason()
	if reason != "": return reject(reason)
	var label_name: String = "Drive Rig" if transport["kind"] == "rig" else "Drover cart"
	match kind:
		"load":
			var loaded := 0
			for crate in crates:
				if crate["state"] == "ground" and Rig.distance(crate["cell"],transport["cell"]) == 1:
					crate["state"] = "loaded"
					transport["cargo"] += 1
					loaded += 1
			if loaded == 0: return reject("The %s isn't next to a crate." % label_name)
			status_text = "The %s takes %d crate%s aboard." % [label_name,loaded,"" if loaded == 1 else "s"]
		"deliver":
			if transport["cargo"] == 0: return reject("The %s has nothing aboard." % label_name)
			transport["driving"] = true
			status_text = "The %s heads for the trunk tunnel." % label_name
		_:
			var goal: Vector2i = soldiers[active_soldier]["cell"] if soldier_can_act(active_soldier) else soldiers[0]["cell"]
			Rig.move_toward(transport,goal,self)
			status_text = "The %s moves up." % label_name
	transport["ordered_phase"] = phase
	rebuild_movement()
	return true

func drive_transport() -> String:
	if not transport["present"] or not transport["driving"]: return ""
	Rig.move_toward(transport,TRUNK,self)
	if Rig.distance(transport["cell"],TRUNK) <= 1:
		var count: int = transport["cargo"]
		for crate in crates:
			if crate["state"] == "loaded":
				crate["state"] = "delivered"
				dam["delivered"] += 1
		transport["cargo"] = 0
		transport["driving"] = false
		return "The %s unloads %d crate%s into the trunk tunnel." % ["Drive Rig" if transport["kind"] == "rig" else "Drover cart",count,"" if count == 1 else "s"]
	return ""

func interrupt_crest_node() -> bool:
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
	if soldier.get("carrying",-1) >= 0 or carried_by(active_soldier) >= 0: return "Cannot fire while carrying."
	if soldier["ap"] < 1: return "No AP left."
	if soldier["attacked"]: return "Already fired this round."
	if soldier["ammo"] < 1: return "Out of ammunition: reload."
	if FallowCutter.unit_at(fallow,sight_target()) < 0: return "Aim [T], then click the cutter or the node."
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
	if shot_rng.randi_range(1,100) <= info["chance"]:
		status_text = "%s fires (%d%%): %s" % [soldier["name"],info["chance"],FallowCutter.take_hit(fallow,FallowCutter.unit_at(fallow,target),FallowCutter.SHOT_DAMAGE)]
	else:
		status_text = "%s fires (%d%%) and misses." % [soldier["name"],info["chance"]]
	if FallowCutter.unit_at(fallow,target) < 0: pinned_target = NONE
	rebuild_movement()
	return true

# ---------------------------------------------------------------- turn

func resolve_enemy_turn() -> void:
	if last_enemy_phase == phase: return
	last_enemy_phase = phase
	var lines: Array[String] = []
	for line in [Dam.fallow_act(dam,fallow,self),drive_transport(),Dam.environment(dam,self)]:
		if line != "": lines.append(line)
	update_bridge()
	enemy_message = " ".join(lines)
	rebuild_movement()
	check_recovery_failure()
	finalize_result()

func begin_player_phase() -> void:
	super.begin_player_phase()
	var line := Dam.guidance(dam,self)
	status_text = "Round %d. Pressure %d of %d.%s" % [phase,dam["pressure"],Dam.BREACH," " + line if line != "" else ""]

func enemy_intent() -> String:
	var parts: Array[String] = ["PRESSURE %d/%d" % [dam["pressure"],Dam.BREACH]]
	for side in ["west","east"]:
		if Dam.flooding(dam,side,phase): parts.append("%s spillway running" % side)
	parts.append("Power %d/%d" % [Dam.power_used(dam),Dam.POWER])
	parts.append("Habitat %s" % ("stable" if dam["stabilized"] else "%d/%d" % [dam["stabilize"],Dam.STABILIZE_STEPS]))
	if fallow["stage"] == "active" and FallowCutter.cutter_alive(fallow): parts.append("FALLOW on the crest: %d marked" % fallow["marked"].size())
	parts.append("Kesh channel: %s" % dam["channel"])
	return " · ".join(parts)

func danger_summary() -> String:
	return "Pressure +1 every round and +1 each time the Fallow fold the crest; breach at %d. A valve drops it by 3 and floods its side for 2 rounds: west the lowland, east the habitat mouth." % Dam.BREACH

func machine_outcome() -> String:
	if dam["breached"]: return "The dam breached."
	return "The dam held. Valves opened: west %d, east %d. Habitat %s." % [dam["valves"]["west"],dam["valves"]["east"],"stabilized" if dam["stabilized"] else "not stabilized"]

func feeder_result() -> String:
	return "Power at the end: footbridge %s, life support %s, ark trunk %d. Cargo: %d of 2 crates in the trunk tunnel%s." % ["on" if dam["power"]["bridge"] else "off","on" if dam["power"]["life"] else "off",dam["power"]["trunk"],dam["delivered"],"" if dam["crates_lost"] == 0 else ", %d lost to the water" % dam["crates_lost"]]

func dependents_state() -> String:
	if dam["breached"]: return "flooded"
	return "stabilized" if dam["stabilized"] else "left"

func result_title() -> String:
	if retry_required(): return "ATTEMPT ENDED / RETRY REQUIRED"
	if dam["breached"]: return "THE DAM / BREACHED"
	var everyone := evacuated_people() == 12
	for soldier in soldiers:
		everyone = everyone and soldier["extracted"] and soldier["condition"] != "dead"
	return "THE DAM / HELD" if everyone else "THE DAM / PARTIAL"

# ---------------------------------------------------------------- story

func opening_pages() -> Array:
	var kesh: String = {"authenticated":"‘Your controller answers to us now. I can see what you see. Use the valves from the crest; I will tell you where the water can go.’","partial":"‘I can guide you, but not every hour. Listen when I speak.’","hardened":"‘You took a habitat from us at the quarry. Protect these families first. Then we will talk about anything else.’"}[dam["channel"]]
	return [
		{"speaker":"ACT III · MISSION 10: THE DAM","text":"The reservoir behind the north-west dam is rising. The Fallow have been at the dam face.\n\nBelow the spillway: two human groups on the lowland, and a Drover habitat in the cavern at the dam's base. Every release of water goes somewhere.","tag":"Pressure, power, people: the first cooperative objective"},
		{"speaker":"KESH / AUTHENTICATED CHANNEL" if dam["channel"] == "authenticated" else "KESH / CHANNEL","text":kesh,"tag":"Guidance in exchange for protecting Drover dependents"},
		{"speaker":"BELL","text":"‘Three units off the turbine. Footbridge, their life support, or the trunk down to whatever's under the ridge. Pick.’","tag":"Power allocation: human evacuation, habitat, ark"}]

func current_pages() -> Array:
	if scene_view == "opening": return opening_pages()
	if scene_view == "debrief": return debrief_pages()
	return log_pages()

func log_pages() -> Array:
	var pages := opening_pages()
	pages.append({"speaker":"INTELLIGENCE / THE DAM","text":enemy_intent()+"\n\n"+danger_summary(),"tag":"Observation, not doctrine"})
	if result_ready and not retry_required(): pages.append_array(debrief_pages())
	return pages

func debrief_pages() -> Array:
	var out: Array[String] = []
	var left: Array[String] = []
	for cohort in cohorts:
		if cohort["status"] == "extracted": out.append("%s (%s)" % [cohort["id"],cohort["origin"]])
		else: left.append("%s (%s)" % [cohort["id"],cohort["origin"]])
	var pages: Array = [{"speaker":"THE DAM / VERIFIED FIELD REPORT","text":"Safe: %s.\nNot safe: %s.\n\n%s\n%s" % [", ".join(out) if not out.is_empty() else "none",", ".join(left) if not left.is_empty() else "none",machine_outcome(),feeder_result()],"tag":"Read to the available survivors"}]
	pages.append({"speaker":"THE HABITAT","text":"Families. Children who stare, and then go back to their chores. Maintenance logs scratched into stone in an unbroken hand, older than any human city. Seed vaults, animal pens, a garden lit by lamps on a schedule.\n\nWhatever this is, it was here first, and it has been waiting a very long time.","tag":"The revelation is physical"})
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
	save_feedback = "Saving isn't available at the dam yet."
	status_text = save_feedback
	queue_redraw()
	return false

func load_encounter(_path: String = RETURN_SLOT) -> bool:
	save_feedback = "Loading isn't available at the dam yet."
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
	var fresh = load("res://the_dam.tscn").instantiate()
	fresh.auto_resume = false
	fresh.record_path = record_path
	get_parent().add_child(fresh)
	queue_free()

# ---------------------------------------------------------------- drawing (HUD map layer)

func draw_mission_layer(projection, font: Font) -> void:
	var size := CELL_SIZE
	for x in range(1,GRID_SIZE.x+1):
		draw_rect(Rect2(projection.cell_anchor(Vector2i(x,1)),Vector2.ONE*size),Color(0.2,0.35,0.55,0.75))
	draw_string(font,projection.cell_anchor(Vector2i(2,1))+Vector2(2,24),"RESERVOIR · PRESSURE %d / %d" % [dam["pressure"],Dam.BREACH],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("e8f4ff") if dam["pressure"] < Dam.BREACH-2 else Color("ff8a80"))
	for y in range(9,17):
		for x in [9,10]:
			if BRIDGE.has(Vector2i(x,y)) and dam["power"]["bridge"]: continue
			draw_rect(Rect2(projection.cell_anchor(Vector2i(x,y)),Vector2.ONE*size),Color(0.2,0.4,0.6,0.55))
	if dam["power"]["bridge"]:
		for cell in BRIDGE: draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(0,10),Vector2(size,16)),Color("9aa3ad"))
	for side in ["west","east"]:
		if not Dam.flooding(dam,side,phase): continue
		for x in range(1,GRID_SIZE.x+1):
			for y in range(1,GRID_SIZE.y+1):
				if in_zone(side,Vector2i(x,y)): draw_rect(Rect2(projection.cell_anchor(Vector2i(x,y)),Vector2.ONE*size),Color(0.25,0.5,0.8,0.45))
	for pair in [[WEST_VALVE,"VALVE W"],[EAST_VALVE,"VALVE E"],[TURBINE,"TURBINE"],[CONSOLE,"HABITAT"],[TRUNK,"TRUNK"]]:
		var at: Vector2 = projection.cell_anchor(pair[0])
		draw_rect(Rect2(at+Vector2(3,3),Vector2.ONE*(size-6)),Color("2b3a4a"))
		draw_rect(Rect2(at+Vector2(3,3),Vector2.ONE*(size-6)),Color("8be6de"),false,2)
		draw_string(font,at+Vector2(-20,-4),pair[1],HORIZONTAL_ALIGNMENT_CENTER,76,9,Color("8be6de"))
	if dam["needs_repair"]:
		var junction: Vector2 = projection.cell_anchor(JUNCTION)
		draw_string(font,junction+Vector2(-20,size+10),"JUNCTION %d/%d" % [dam["repair"],Dam.REPAIR_STEPS],HORIZONTAL_ALIGNMENT_CENTER,76,9,Color("ffb75a"))
	for crate in crates:
		if crate["state"] != "ground": continue
		var at: Vector2 = projection.cell_anchor(crate["cell"])
		draw_rect(Rect2(at+Vector2(6,6),Vector2.ONE*(size-12)),Color("7a9a5a"))
		draw_string(font,at+Vector2(0,22),"CARGO",HORIZONTAL_ALIGNMENT_CENTER,size,8,Color.WHITE)
	if transport["present"]:
		var at: Vector2 = projection.cell_anchor(transport["cell"])
		draw_rect(Rect2(at+Vector2(-3,-3),Vector2.ONE*(size+6)),Color("8a6a3a"))
		draw_string(font,at+Vector2(-14,22),("RIG" if transport["kind"] == "rig" else "CART") + (" ·%d" % transport["cargo"] if transport["cargo"] > 0 else ""),HORIZONTAL_ALIGNMENT_CENTER,64,10,Color.WHITE)
	for cell in fallow.get("rifts",[]):
		draw_rect(Rect2(projection.cell_anchor(cell),Vector2.ONE*size),Color("1a0f24"))
	for cell in fallow.get("marked",[]):
		draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(1,1),Vector2.ONE*(size-2)),Color(0.6,0.3,0.95,0.35))
	if FallowCutter.node_present(fallow):
		draw_circle(projection.cell_anchor(fallow["node"])+Vector2(18,18),10,Color("5e3a8c") if fallow["interrupted"] else Color("b98cff"))
	if FallowCutter.cutter_alive(fallow):
		var center: Vector2 = projection.cell_anchor(fallow["cutter"]["cell"])+Vector2(18,18)
		draw_colored_polygon(PackedVector2Array([center+Vector2(0,-15),center+Vector2(9,0),center+Vector2(0,15),center+Vector2(-9,0)]),Color("2a1a3a"))
		draw_string(font,center+Vector2(-40,-21),"CUTTER %d HP" % fallow["cutter"]["hp"],HORIZONTAL_ALIGNMENT_CENTER,80,9,Color("d9b8ff"))
