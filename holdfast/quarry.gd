extends "res://encounter_controller.gd"
## Mission 07 · Quarry (spec: docs/missions/quarry.md). Closes Act II.
## A power platform command calls hostile, which the briefing has already confirmed powers
## an occupied Drover habitat. Two groups trapped in a collapsing haul tunnel behind the
## platform's live trunk. Demolish, isolate, or recover the controller and take the long way.
## Adds scoped elevation, reuses the Fallow cutter, and brings back the Farm Road Drive Rig.
## The Farm Road machine itself is switched off. Save/load for this mission comes later.
const QuarryMission = preload("res://missions/quarry.tres")
const Works = preload("res://systems/quarry_works.gd")
const Rig = preload("res://systems/drive_rig.gd")
const FallowCutter = preload("res://systems/fallow_cutter.gd")
const CampaignRecord = preload("res://systems/campaign_record.gd")

const PLATFORM := Vector2i(14,9)
const JB_WEST := Vector2i(6,11)
const JB_EAST := Vector2i(17,10)
const DEBRIS: Array[Vector2i] = [Vector2i(3,13),Vector2i(4,13),Vector2i(5,13)]
const HATCH := Vector2i(7,13)
const AIRSHAFT := Vector2i(11,13)
const RIG_START := Vector2i(8,9)
const FALLOW_ENTRY := Vector2i(18,2)
const FALLOW_NODE := Vector2i(19,2)
const BENCH_MAX_ROW := 5         # rows 1–5 are the upper bench (high ground)
const ELEVATION := 10
const REPLACEMENTS := ["Reyes","Okafor","Lindqvist"]

var mission_copy: Resource = null
var record_path := ""
var works: Dictionary = {}
var rig: Dictionary = {}
var fallow: Dictionary = {}
## Carry-ins.
var rig_available := false
var missing_part := false
var hatch_open := false
var surveyed := false

func mission_definition() -> Resource:
	if mission_override != null: return mission_override
	if mission_copy == null: mission_copy = QuarryMission.duplicate(true)
	return mission_copy

func _ready() -> void:
	read_carry_ins()
	if hatch_open: mission_definition().walls.erase(HATCH)
	initialize_tactical()
	initialize_machine()
	initialize_evacuation()
	initialize_breaker()
	initialize_protocol()
	initialize_rescue()
	initialize_results()
	initialize_story()
	initialize_roster(false)
	report_path = "user://holdfast_m07_result.save"
	completion_path = "user://holdfast_m07_completed.save"
	campaign_path = "user://holdfast_m07_campaign.save"
	works = Works.initial(DEBRIS,missing_part,surveyed)
	rig = Rig.initial(rig_available,RIG_START)
	fallow = FallowCutter.initial(FALLOW_ENTRY,FALLOW_NODE)
	for index in range(cohorts.size()):
		cohorts[index]["origin"] = ["Miners in the haul tunnel","Refugees in the haul tunnel","Quarry crew on the upper bench"][index]
	carry_over_squad()
	status_text = "Quarry: the haul tunnel comes down at the end of round %d. Decide what happens to the platform." % Works.COLLAPSE_ROUND
	enemy_message = "The platform hums. Below the ridge, something is running on it."
	save_feedback = "Saving isn't available at the quarry yet."
	rebuild_movement()

func read_carry_ins() -> void:
	if record_path == "": return
	var missions: Dictionary = CampaignRecord.load_record(record_path)["missions"]
	rig_available = ["disabled","diverted"].has(missions.get(1,{}).get("machine",""))
	missing_part = missions.get(4,{}).get("cargo","") == "seized"
	hatch_open = missions.get(6,{}).get("convoy","") == "monitored"
	surveyed = ["partial","full"].has(missions.get(5,{}).get("archive","none"))

func carry_over_squad() -> void:
	if record_path == "": return
	var missions: Dictionary = CampaignRecord.load_record(record_path)["missions"]
	var entry: Dictionary = {}
	for id in [6,5,4,3,2,1]:
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

func in_tunnel(cell: Vector2i) -> bool:
	return cell.y >= 14 and cell.y <= 15 and cell.x >= 2 and cell.x <= 11

func high_ground(cell: Vector2i) -> bool:
	return cell.y <= BENCH_MAX_ROW

func target_at(cell: Vector2i) -> int:
	if not fallow.is_empty() and FallowCutter.unit_at(fallow,cell) >= 0: return 10+FallowCutter.unit_at(fallow,cell)
	if not rig.is_empty() and rig["present"] and rig["cell"] == cell: return 40
	return -1

func civilian_safe(cell: Vector2i) -> bool:
	if not cell_is_in_bounds(cell) or WALL_CELLS.has(cell) or FIXTURES.has(cell): return false
	return target_at(cell) < 0

func civilian_waypoint(_order: String) -> Vector2i:
	return civilian_exit()

func route_label(_order: String) -> String:
	return "Quarry gate"

func on_civilian_step(_cohort: Dictionary, _cell: Vector2i) -> void:
	pass

## Nobody runs back into a collapsing tunnel: a group that was out stays out.
func resolve_civilian_phase() -> void:
	var outside := {}
	for cohort in cohorts:
		if cohort["status"] == "active" and not in_tunnel(cohort["cell"]): outside[cohort["id"]] = cohort["cell"]
	super.resolve_civilian_phase()
	for cohort in cohorts:
		if cohort["status"] == "active" and outside.has(cohort["id"]) and in_tunnel(cohort["cell"]):
			cohort["cell"] = outside[cohort["id"]]
			cohort["note"] = "Won't go back into the tunnel"

func civilian_threats() -> Array[Vector2i]:
	var threats: Array[Vector2i] = FallowCutter.threat_cells(fallow)
	threats.append_array(round_noise)
	return threats

func deadline() -> int:
	return mission_definition().closing_round

func mission_completion_reason(round_number: int) -> String:
	return MissionObjectives.completion_reason(mission_definition(),round_number,0,all_extracted(),remaining_civilians())

## Scoped elevation (spec): +10 shooting down from the bench, −10 shooting up at it.
func sight_preview(shooter: Vector2i, target: Vector2i) -> Dictionary:
	var info: Dictionary = super.sight_preview(shooter,target)
	var shift := 0
	if high_ground(shooter) and not high_ground(target): shift = ELEVATION
	elif high_ground(target) and not high_ground(shooter): shift = -ELEVATION
	info["elevation"] = shift
	if shift != 0 and info.get("can_fire",false): info["chance"] = clampi(int(info["chance"])+shift,5,95)
	return info

# Fallow board hooks (the Main Street contract).
func add_rift(cell: Vector2i) -> void:
	var fixtures: Array[Vector2i] = mission_definition().fixtures
	if not fixtures.has(cell): fixtures.append(cell)

func clear_debris(cell: Vector2i) -> void:
	mission_definition().fixtures.erase(cell)
	works["debris"].erase(cell)

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
	if cell == mission.civilian_exit or mission.squad_exits.has(cell) or in_tunnel(cell) or cell == AIRSHAFT: return true
	return Rig.shelters(rig,cell)

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

func charge_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if works["destroyed"] or works["charge_set"]: return "The charge is already set." if works["charge_set"] and not works["destroyed"] else "The platform is gone."
	if not next_to(PLATFORM): return "Stand next to the platform (%d,%d)." % [PLATFORM.x,PLATFORM.y]
	return ""

func set_charge() -> bool:
	var reason := charge_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	status_text = Works.step_charge(works)
	rebuild_movement()
	return true

func junction_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if works["destroyed"]: return "The platform is gone."
	if next_to(JB_WEST): return "Junction box West already dead." if works["jb_west"] else ""
	if next_to(JB_EAST): return "Junction box East already dead." if works["jb_east"] else ""
	return "Stand next to a junction box: West (%d,%d) or East (%d,%d)." % [JB_WEST.x,JB_WEST.y,JB_EAST.x,JB_EAST.y]

func kill_junction() -> bool:
	var reason := junction_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	status_text = Works.step_isolation(works,"west" if next_to(JB_WEST) else "east")
	rebuild_movement()
	return true

func safe_off_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if works["destroyed"] or works["isolated"]: return "Nothing left to isolate."
	if not (works["jb_west"] and works["jb_east"]): return "Kill both junction boxes first."
	if not next_to(PLATFORM): return "Stand next to the platform (%d,%d)." % [PLATFORM.x,PLATFORM.y]
	return ""

func confirm_safe_off() -> bool:
	var reason := safe_off_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	status_text = Works.step_isolation(works,"confirm")
	rebuild_movement()
	return true

func controller_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if works["destroyed"]: return "The platform is gone."
	if works["controller"]: return "Controller already recovered."
	if works["controller_phase"] == phase: return "One recovery step a round. The next one waits for next round."
	if not next_to(PLATFORM): return "Stand next to the platform (%d,%d)." % [PLATFORM.x,PLATFORM.y]
	return ""

func recover_controller() -> bool:
	var reason := controller_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	status_text = Works.step_controller(works,phase)
	rebuild_movement()
	return true

func debris_next_to(cell: Vector2i) -> Vector2i:
	for pile in works["debris"].keys():
		if Rig.distance(pile,cell) == 1: return pile
	return NONE

func dig_reason() -> String:
	var reason := ready_reason()
	if reason != "": return reason
	if debris_next_to(soldiers[active_soldier]["cell"]) == NONE: return "Stand next to the west-mouth debris."
	if not Works.trunk_dead(works): return "The platform's live trunk runs through that debris. Isolate or demolish first."
	return ""

func dig() -> bool:
	var reason := dig_reason()
	if reason != "": return reject(reason)
	var pile := debris_next_to(soldiers[active_soldier]["cell"])
	soldiers[active_soldier]["ap"] -= 1
	works["debris"][pile] -= 1
	if works["debris"][pile] <= 0:
		clear_debris(pile)
		status_text = "%s clears the debris at (%d,%d)." % [soldiers[active_soldier]["name"],pile.x,pile.y]
	else:
		status_text = "%s digs at (%d,%d): %d AP more." % [soldiers[active_soldier]["name"],pile.x,pile.y,works["debris"][pile]]
	rebuild_movement()
	return true

func rig_reason() -> String:
	if ended: return "Operation over."
	if not rig["present"]: return "No Drive Rig here: the Farm Road machine wasn't preserved."
	if rig["ordered_phase"] == phase: return "One rig order a turn."
	if not soldier_can_act(0) or Rig.distance(soldiers[0]["cell"],rig["cell"]) > Rig.VOICE: return "MSG has to be within %d squares of the rig." % Rig.VOICE
	return ""

func order_rig(kind: String) -> bool:
	var reason := rig_reason()
	if reason != "": return reject(reason)
	match kind:
		"move":
			var goal: Vector2i = soldiers[active_soldier]["cell"] if soldier_can_act(active_soldier) else soldiers[0]["cell"]
			var moved := Rig.move_toward(rig,goal,self)
			status_text = "The Drive Rig grinds %d square%s toward %s." % [moved,"" if moved == 1 else "s",soldiers[active_soldier]["name"] if soldier_can_act(active_soldier) else "MSG"]
		"dig":
			var pile := debris_next_to(rig["cell"])
			if pile == NONE: return reject("The rig isn't next to the debris.")
			if not Works.trunk_dead(works): return reject("The trunk is live. The rig won't dig into it.")
			clear_debris(pile)
			rig["dug"] += 1
			status_text = "The Drive Rig shoulders the debris at (%d,%d) aside." % [pile.x,pile.y]
		_:
			rig["braced"] = true
			status_text = "The Drive Rig braces. The ground right next to it is safe from Fallow marks."
	rig["ordered_phase"] = phase
	rig["log"].append(kind)
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
	var roll := shot_rng.randi_range(1,100)
	if roll <= info["chance"]:
		status_text = "%s fires (%d%%%s): %s" % [soldier["name"],info["chance"],elevation_note(info),FallowCutter.take_hit(fallow,FallowCutter.unit_at(fallow,target),FallowCutter.SHOT_DAMAGE)]
	else:
		status_text = "%s fires (%d%%%s) and misses." % [soldier["name"],info["chance"],elevation_note(info)]
	if FallowCutter.unit_at(fallow,target) < 0: pinned_target = NONE
	rebuild_movement()
	return true

func elevation_note(info: Dictionary) -> String:
	var shift: int = info.get("elevation",0)
	return "" if shift == 0 else ", elevation %+d" % shift

func interrupt_ridge_node() -> bool:
	if ended or not FallowCutter.node_present(fallow): return reject("No node to interrupt.")
	if not soldier_can_act(active_soldier) or soldiers[active_soldier]["ap"] < 1 or FallowCutter.distance(soldiers[active_soldier]["cell"],fallow["node"]) > 1:
		return reject("Interrupt: a soldier with 1 AP next to the node at (%d,%d)." % [fallow["node"].x,fallow["node"].y])
	if fallow["interrupted"]: return reject("The node is already interrupted this turn.")
	soldiers[active_soldier]["ap"] -= 1
	status_text = FallowCutter.interrupt(fallow)
	rebuild_movement()
	return true

# ---------------------------------------------------------------- turn

func resolve_enemy_turn() -> void:
	if last_enemy_phase == phase: return
	last_enemy_phase = phase
	var lines: Array[String] = []
	for line in [FallowCutter.act(fallow,self),Works.act(works,self)]:
		if line != "": lines.append(line)
	enemy_message = " ".join(lines) if not lines.is_empty() else "The quarry creaks. The tunnel face sheds grit."
	rebuild_movement()
	check_recovery_failure()
	finalize_result()

func begin_player_phase() -> void:
	super.begin_player_phase()
	if fallow["stage"] == "signaled": status_text = "Round %d. A distortion is opening over the ridge (%d,%d). Something arrives next turn." % [phase,FALLOW_ENTRY.x,FALLOW_ENTRY.y]
	elif not works["collapsed"] and phase >= Works.COLLAPSE_ROUND-2: status_text = "Round %d. The tunnel comes down at the end of round %d. Who's still inside?" % [phase,Works.COLLAPSE_ROUND]
	else: status_text = "Round %d. %s" % [phase,enemy_message.left(150)]

func enemy_intent() -> String:
	var parts: Array[String] = ["Platform %s" % Works.platform_state(works)]
	if works["charge_set"] and not works["destroyed"]: parts.append("CHARGE SET: blows next phase")
	if not works["collapsed"]: parts.append("Tunnel collapses after round %d" % Works.COLLAPSE_ROUND)
	if works["controller_steps"] > 0 and not works["controller"]: parts.append("Controller %d/%d" % [works["controller_steps"],works["controller_needed"]])
	match fallow["stage"]:
		"signaled": parts.append("FALLOW arriving next turn")
		"active": parts.append("FALLOW: %d squares marked" % fallow["marked"].size() if FallowCutter.cutter_alive(fallow) else "Fallow cutter down")
	return " · ".join(parts)

func danger_summary() -> String:
	return "The west mouth is three squares from the tunnel groups, but the platform's live trunk runs through it. The airshaft at (%d,%d) is open: the long way round." % [AIRSHAFT.x,AIRSHAFT.y]

func plan_name() -> String:
	if works["destroyed"]: return "demolish"
	if works["isolated"]: return "isolate"
	if works["controller"]: return "recover the controller"
	return "no decision carried through"

func machine_outcome() -> String:
	match Works.platform_state(works):
		"demolished": return "Platform demolished. The habitat it powered is lost, with its ecological reserve."
		"isolated": return "Platform isolated, intact and inert. The habitat runs on reserve."
	return "Platform still running; the habitat kept full power." + (" Controller recovered." if works["controller"] else "")

func feeder_result() -> String:
	var parts: Array[String] = []
	if not works["lost"].is_empty(): parts.append("Lost in the tunnel collapse: group %s." % ", ".join(works["lost"]))
	parts.append("Drive Rig: %s." % ("not present" if not rig["present"] else ("dug %d debris" % rig["dug"] if rig["dug"] > 0 else "on the field")))
	parts.append("%d squares of rift ground." % fallow["rifts"].size())
	return " ".join(parts)

func result_title() -> String:
	if retry_required(): return "ATTEMPT ENDED / RETRY REQUIRED"
	var everyone := evacuated_people() == 12
	for soldier in soldiers:
		everyone = everyone and soldier["extracted"] and soldier["condition"] != "dead"
	return "QUARRY / EVERYONE OUT" if everyone else "QUARRY / PARTIAL"

# ---------------------------------------------------------------- story

func opening_pages() -> Array:
	return [
		{"speaker":"ACT II · MISSION 07: QUARRY","text":"Command's order: secure the quarry power platform, flagged as hostile command infrastructure.\n\nTwo groups are trapped in the old haul tunnel behind it. The tunnel face is going.","tag":"Rescue the tunnel groups · decide the platform · extract the squad"},
		{"speaker":"BRIEFING / CORROBORATED","text":"Two quarry workers saw families below the ridge: Drover families, with animals in pens and lights on a schedule. The platform's own telemetry says the same: steady draw, occupied habitat, life support.\n\nThis isn't a guess, and it isn't a trick. It's what the thing does.","tag":"Known before commitment: it powers an occupied Drover habitat"},
		{"speaker":"BELL","text":"‘Fast way in is the west mouth, but the trunk runs right through that rubble. Blow the platform and the mouth comes open with it. Or kill it at both junction boxes and dig. Or leave it running, pull the controller, and walk them out the airshaft. That's the long way.’","tag":"Demolish · isolate · recover the controller"}]

func current_pages() -> Array:
	if scene_view == "opening": return opening_pages()
	if scene_view == "debrief": return debrief_pages()
	return log_pages()

func log_pages() -> Array:
	var pages := opening_pages()
	pages.append({"speaker":"INTELLIGENCE / QUARRY","text":enemy_intent()+"\n\n"+danger_summary(),"tag":"Observation, not doctrine"})
	if result_ready and not retry_required(): pages.append_array(debrief_pages())
	return pages

func debrief_pages() -> Array:
	var out: Array[String] = []
	var left: Array[String] = []
	for cohort in cohorts:
		if cohort["status"] == "extracted": out.append("%s (%s)" % [cohort["id"],cohort["origin"]])
		else: left.append("%s (%s)" % [cohort["id"],cohort["origin"]])
	var pages: Array = [{"speaker":"QUARRY / VERIFIED FIELD REPORT","text":"Out: %s.\nNot out: %s.\n\n%s\n%s" % [", ".join(out) if not out.is_empty() else "none",", ".join(left) if not left.is_empty() else "none",machine_outcome(),feeder_result()],"tag":"Read to the available survivors"}]
	pages.append({"speaker":"MSG / FOR THE RECORD","text":"What I knew: the platform powered an occupied Drover habitat. Two witnesses and its own telemetry.\nWhat I recommended: %s.\nWhat we saved: %d of 12 people; the habitat %s." % [plan_name(),evacuated_people(),{"lost":"is lost","strained":"is on reserve","powered":"still has power"}[Works.habitat(works)]],"tag":"What the MSG knew, recommended, and actually saved"})
	if not retry_required():
		pages.append({"speaker":"ACT II COMPLETE / THE HIDDEN WAR","text":"Ward reads the six reports back to back: machines that went around people, Greys that took them and kept books on everyone, Reptilians that counted them as stock, and Drovers who powered homes under a ridge.\n\nShe signs off on the assessment. These are separate threats with separate objectives, and treating one like another has a cost. Then she asks what's under the ridge.","tag":"Act III begins: The Enemy of My Enemy"})
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
	save_feedback = "Saving isn't available at the quarry yet."
	status_text = save_feedback
	queue_redraw()
	return false

func load_encounter(_path: String = RETURN_SLOT) -> bool:
	save_feedback = "Loading isn't available at the quarry yet."
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
	var fresh = load("res://quarry.tscn").instantiate()
	fresh.auto_resume = false
	fresh.record_path = record_path
	get_parent().add_child(fresh)
	queue_free()

# ---------------------------------------------------------------- drawing (HUD map layer)

func draw_mission_layer(projection, font: Font) -> void:
	var size := CELL_SIZE
	for x in range(1,GRID_SIZE.x+1):
		for y in range(1,BENCH_MAX_ROW+1):
			draw_rect(Rect2(projection.cell_anchor(Vector2i(x,y)),Vector2.ONE*size),Color(0.62,0.55,0.42,0.16))
	draw_string(font,projection.cell_anchor(Vector2i(1,1))+Vector2(2,10),"UPPER BENCH (high ground: +10 down, −10 up)",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e8d9b8"))
	for x in range(2,12):
		for y in [14,15]:
			draw_rect(Rect2(projection.cell_anchor(Vector2i(x,y)),Vector2.ONE*size),Color(0.2,0.17,0.13,0.45 if not works["collapsed"] else 0.85))
	draw_string(font,projection.cell_anchor(Vector2i(6,15))+Vector2(0,size+11),"HAUL TUNNEL · " + ("COLLAPSED" if works["collapsed"] else "collapses after round %d" % Works.COLLAPSE_ROUND),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("ffb75a"))
	draw_string(font,projection.cell_anchor(AIRSHAFT)+Vector2(-10,-3),"AIRSHAFT",HORIZONTAL_ALIGNMENT_CENTER,56,9,Color("c9d3e0"))
	if hatch_open: draw_string(font,projection.cell_anchor(HATCH)+Vector2(-10,-3),"HATCH",HORIZONTAL_ALIGNMENT_CENTER,56,9,Color("a8f0b8"))
	for pile in works["debris"].keys():
		var at: Vector2 = projection.cell_anchor(pile)
		draw_rect(Rect2(at+Vector2(2,2),Vector2.ONE*(size-4)),Color("6b5a45"))
		draw_string(font,at+Vector2(0,22),"%d" % works["debris"][pile],HORIZONTAL_ALIGNMENT_CENTER,size,11,Color("ffe1a8"))
		if not Works.trunk_dead(works): draw_line(at+Vector2(4,18),at+Vector2(size-4,18),Color(1,0.85,0.2,0.8),2)
	# Trunk from the platform to the west mouth while it's live.
	if not Works.trunk_dead(works):
		draw_dashed_line(projection.cell_anchor(PLATFORM)+Vector2(18,18),projection.cell_anchor(DEBRIS[1])+Vector2(18,18),Color(1,0.85,0.2,0.6),2,6)
	var plat: Vector2 = projection.cell_anchor(PLATFORM)
	draw_rect(Rect2(plat+Vector2(-4,-4),Vector2.ONE*(size+8)),Color("3a3a3a") if works["destroyed"] else Color("4f6b5a"))
	draw_string(font,plat+Vector2(-30,-8),"PLATFORM · %s%s" % [Works.platform_state(works),"" if not works["charge_set"] or works["destroyed"] else " · CHARGE"],HORIZONTAL_ALIGNMENT_CENTER,96,9,Color("d8f0e0"))
	for pair in [[JB_WEST,"JB-W",works["jb_west"]],[JB_EAST,"JB-E",works["jb_east"]]]:
		var at: Vector2 = projection.cell_anchor(pair[0])
		draw_rect(Rect2(at+Vector2(3,3),Vector2.ONE*(size-6)),Color("2b3a4a"))
		draw_rect(Rect2(at+Vector2(3,3),Vector2.ONE*(size-6)),Color("555555") if pair[2] else Color("8be6de"),false,2)
		draw_string(font,at+Vector2(0,22),pair[1],HORIZONTAL_ALIGNMENT_CENTER,size,9,Color("8be6de"))
	if rig["present"]:
		var at: Vector2 = projection.cell_anchor(rig["cell"])
		draw_rect(Rect2(at+Vector2(-3,-3),Vector2.ONE*(size+6)),Color("8a6a3a"))
		draw_string(font,at+Vector2(-14,22),"RIG",HORIZONTAL_ALIGNMENT_CENTER,64,11,Color.WHITE)
		if rig["braced"]:
			for direction in DIRECTIONS:
				var cell: Vector2i = rig["cell"]+direction
				if cell_is_in_bounds(cell): draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(4,4),Vector2.ONE*(size-8)),Color(0.55,0.9,0.87,0.2))
	for cell in fallow.get("rifts",[]):
		draw_rect(Rect2(projection.cell_anchor(cell),Vector2.ONE*size),Color("1a0f24"))
	for cell in fallow.get("marked",[]):
		draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(1,1),Vector2.ONE*(size-2)),Color(0.6,0.3,0.95,0.35))
	if fallow.get("stage","") == "signaled":
		draw_string(font,projection.cell_anchor(FALLOW_ENTRY)+Vector2(-20,-8),"DISTORTION",HORIZONTAL_ALIGNMENT_CENTER,76,9,Color("d9b8ff"))
	if FallowCutter.node_present(fallow):
		draw_circle(projection.cell_anchor(fallow["node"])+Vector2(18,18),10,Color("5e3a8c") if fallow["interrupted"] else Color("b98cff"))
	if FallowCutter.cutter_alive(fallow):
		var center: Vector2 = projection.cell_anchor(fallow["cutter"]["cell"])+Vector2(18,18)
		draw_colored_polygon(PackedVector2Array([center+Vector2(0,-15),center+Vector2(9,0),center+Vector2(0,15),center+Vector2(-9,0)]),Color("2a1a3a"))
		draw_string(font,center+Vector2(-40,-21),"CUTTER %d HP" % fallow["cutter"]["hp"],HORIZONTAL_ALIGNMENT_CENTER,80,9,Color("d9b8ff"))
