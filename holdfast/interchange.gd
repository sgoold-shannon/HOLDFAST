extends "res://encounter_controller.gd"
## Mission 04 · Interchange (spec: docs/missions/interchange.md). Act II opener.
## Armed Drovers load cargo in the middle of the junction; a stranded group sits on the
## overpass; a Grey drone tries to start a fight in round 4. Three valid ways through:
## a corridor pause, an escort, or an assault (Suppress and Restrain arrive here).
## The Farm Road machine is switched off. Save/load for this mission comes later.
const InterchangeMission = preload("res://missions/interchange.tres")
const DroverCrew = preload("res://systems/drover_crew.gd")
const GreyDrone = preload("res://systems/grey_drone.gd")
const CampaignRecord = preload("res://systems/campaign_record.gd")

const HAULER := Vector2i(11,8)
const SECURITY: Array[Vector2i] = [Vector2i(9,6),Vector2i(12,11)]
const DRONE_ENTRY := Vector2i(18,14)
const LANE_ROW := 9
const LANE_FROM := 7
const LANE_TO := 15
const OVERPASS_RAMP := Vector2i(6,4)
const SUPPRESS_RANGE := 8
const REPLACEMENTS := ["Reyes","Okafor","Lindqvist"]

var crew: Dictionary = {}
var drone: Dictionary = {}
var record_path := ""
## Carry-ins from Missions 01–03 (read from the campaign record).
var acknowledged := false
var wary := false
var component_held := false
var sensor := false

func mission_definition() -> Resource:
	if mission_override != null: return mission_override
	return InterchangeMission

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
	report_path = "user://holdfast_m04_result.save"
	completion_path = "user://holdfast_m04_completed.save"
	campaign_path = "user://holdfast_m04_campaign.save"
	read_carry_ins()
	crew = DroverCrew.initial(HAULER,SECURITY,wary)
	drone = GreyDrone.initial(DRONE_ENTRY,sensor)
	carry_over_squad()
	status_text = "Interchange: Drovers are loading cargo in the junction. Group C is stuck on the overpass."
	enemy_message = "Drover crew working the junction, armed and nervous."
	save_feedback = "Saving isn't available at the Interchange yet."
	rebuild_movement()

func read_carry_ins() -> void:
	if record_path == "": return
	var missions: Dictionary = CampaignRecord.load_record(record_path)["missions"]
	acknowledged = missions.get(1,{}).get("acknowledged",false)
	sensor = missions.get(2,{}).get("sensor",false)
	var main: Dictionary = missions.get(3,{})
	wary = ["isolated","redirected"].has(main.get("platform",""))
	component_held = main.get("component",false)

## Losses and wounds from the latest mission on record. Replacements never double up a name.
func carry_over_squad() -> void:
	if record_path == "": return
	var missions: Dictionary = CampaignRecord.load_record(record_path)["missions"]
	var entry: Dictionary = missions.get(3,missions.get(2,missions.get(1,{})))
	if entry.is_empty() or not entry.has("squad"): return
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

func on_lane(cell: Vector2i) -> bool:
	return cell.y == LANE_ROW and cell.x >= LANE_FROM and cell.x <= LANE_TO

func cohort_at(cell: Vector2i) -> int:
	for index in range(cohorts.size()):
		if cohorts[index]["status"] == "active" and cohorts[index]["cell"] == cell: return index
	return -1

func target_at(cell: Vector2i) -> int:
	if crew.is_empty(): return -1
	var index := DroverCrew.unit_at(crew,cell)
	return 10+index if index >= 0 else -1

func drone_visible() -> bool:
	return not drone.is_empty() and GreyDrone.visible(drone,self)

func civilian_safe(cell: Vector2i) -> bool:
	if not cell_is_in_bounds(cell) or WALL_CELLS.has(cell) or FIXTURES.has(cell): return false
	if target_at(cell) >= 0: return false
	return not DroverCrew.zone_closed(crew,cell)

func civilian_waypoint(order: String) -> Vector2i:
	return mission_definition().civilian_routes["north" if order == "north" else "south"]

func route_available(_order: String) -> bool:
	return true

func route_label(order: String) -> String:
	return "Through the junction" if order == "north" else "Frontage road"

func move_cohort(cohort: Dictionary, budget: int) -> void:
	if cohort["status"] == "active" and cohort["cell"].x > DroverCrew.ZONE_MAX.x: cohort["passed"] = true
	super.move_cohort(cohort,budget)

## Once a group is east of the junction it heads straight for the exit, whichever route it took.
func on_civilian_step(cohort: Dictionary, cell: Vector2i) -> void:
	if cell.x > DroverCrew.ZONE_MAX.x: cohort["passed"] = true

func civilian_threats() -> Array[Vector2i]:
	var threats: Array[Vector2i] = DroverCrew.threat_cells(crew,phase)
	if drone_visible(): threats.append(drone["cell"])
	threats.append_array(round_noise)
	return threats

func deadline() -> int:
	return mission_definition().closing_round

func mission_completion_reason(round_number: int) -> String:
	return MissionObjectives.completion_reason(mission_definition(),round_number,0,all_extracted(),remaining_civilians())

# ---------------------------------------------------------------- actions

func reject(text: String) -> bool:
	status_text = text
	queue_redraw()
	return false

func active_ready(cost: int = 1) -> String:
	if ended: return "Operation over."
	if not soldier_can_act(active_soldier): return "Select a standing soldier."
	if soldiers[active_soldier].get("carrying",-1) >= 0: return "Put the casualty down first."
	if soldiers[active_soldier]["ap"] < cost: return "Needs %d AP." % cost
	return ""

func observe_hauler_reason() -> String:
	var reason := active_ready()
	if reason != "": return reason
	if active_soldier != 0: return "MSG reads the crew's pattern. Select MSG."
	if not DroverCrew.hauler_running(crew): return "The hauler is gone."
	if crew["observed"]: return "Already observed."
	if DroverCrew.distance(soldiers[0]["cell"],HAULER) > DroverCrew.VOICE_RANGE or not sight_preview(soldiers[0]["cell"],HAULER)["clear"]:
		return "MSG needs sight of the hauler within %d squares." % DroverCrew.VOICE_RANGE
	return ""

func observe_hauler() -> bool:
	var reason := observe_hauler_reason()
	if reason != "": return reject(reason)
	soldiers[0]["ap"] -= 1
	crew["observed"] = true
	crew["log"].append("hauler_observed")
	status_text = "MSG logs the crew's pattern: they're loading marked components and covering each other, not advancing. A pause request now carries a verified pattern."
	rebuild_movement()
	return true

func observe_drone_reason() -> String:
	var reason := active_ready()
	if reason != "": return reason
	if not drone_visible(): return "No drone in sight."
	if drone["observed"]: return "Drone already observed."
	if not sight_preview(soldiers[active_soldier]["cell"],drone["cell"])["clear"]: return "No clear sight of the drone."
	return ""

func observe_drone() -> bool:
	var reason := observe_drone_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	status_text = "%s: %s" % [soldiers[active_soldier]["name"],GreyDrone.observe(drone)]
	rebuild_movement()
	return true

func pause_reason(gift: bool) -> String:
	var reason := active_ready()
	if reason != "": return reason
	if active_soldier != 0: return "Only MSG can negotiate a pause. Select MSG."
	if gift and not component_held: return "No Drover component to return (it wasn't recovered at Main Street)."
	if gift and crew["log"].has("component_returned"): return "Component already returned."
	if DroverCrew.distance(soldiers[0]["cell"],HAULER) > DroverCrew.VOICE_RANGE: return "MSG needs to be within %d squares of the hauler." % DroverCrew.VOICE_RANGE
	return ""

func transmit_pause(gift: bool = false) -> bool:
	var reason := pause_reason(gift)
	if reason != "": return reject(reason)
	var refused := DroverCrew.request_pause(crew,phase,acknowledged,gift)
	if refused != "": return reject(refused)
	soldiers[0]["ap"] -= 1
	status_text = "MSG transmits on the work channel%s. They'll answer in their phase." % (", and sets the Main Street component on the asphalt for them" if gift else ", citing ACK-01" if acknowledged else ", citing the pattern he just logged")
	rebuild_movement()
	return true

## What the selected soldier is aiming at: "security:<n>", "hauler", "drone" or "".
func aimed() -> String:
	var cell := sight_target()
	if drone_visible() and drone["cell"] == cell: return "drone"
	var index := DroverCrew.unit_at(crew,cell)
	if index == 0: return "hauler"
	if index > 0 and DroverCrew.unit_fighting(crew["units"][index-1]): return "security:%d" % index
	return ""

func suppress_reason() -> String:
	var reason := active_ready()
	if reason != "": return reason
	var soldier: Dictionary = soldiers[active_soldier]
	if soldier["attacked"]: return "Already attacked this round."
	if soldier["ammo"] < 2: return "Suppression needs 2 rounds in the magazine: reload."
	var target := aimed()
	if target == "" or target == "hauler": return "Aim [T] and pin Drover security or a visible drone."
	var info := sight_preview(soldier["cell"],sight_target())
	if not info["clear"] or info["distance"] > SUPPRESS_RANGE: return "Suppression needs clear sight within %d squares." % SUPPRESS_RANGE
	return ""

func suppress() -> bool:
	var reason := suppress_reason()
	if reason != "": return reject(reason)
	var soldier: Dictionary = soldiers[active_soldier]
	var target := aimed()
	soldier["ap"] -= 1
	soldier["ammo"] -= 2
	soldier["attacked"] = true
	round_noise.append(soldier["cell"])
	if target == "drone":
		drone["suppressed_by"] = active_soldier
		status_text = "%s puts suppressing fire on the drone: it slows to 2 squares." % soldier["name"]
	else:
		var entry: Dictionary = crew["units"][int(target.split(":")[1])-1]
		entry["suppressed_by"] = active_soldier
		var reaction := DroverCrew.provoke(crew,phase,"squad")
		if crew["agreement"] == "none" and crew["pause"]["state"] == "none": crew["agreement"] = "assault"
		status_text = "%s suppresses Drover security: −20 Aim, 2-square moves until your next turn. %s" % [soldier["name"],reaction]
	rebuild_movement()
	return true

func restrain_target() -> int:
	if not soldier_can_act(active_soldier): return -1
	for index in range(crew["units"].size()):
		var entry: Dictionary = crew["units"][index]
		if DroverCrew.unit_fighting(entry) and entry["suppressed_by"] >= 0 and entry["hp"] <= DroverCrew.RESTRAIN_HP and DroverCrew.distance(entry["cell"],soldiers[active_soldier]["cell"]) == 1:
			return index+1
	return -1

func restrain_reason() -> String:
	var reason := active_ready()
	if reason != "": return reason
	if restrain_target() < 0: return "Restrain: stand next to a suppressed Drover security unit at %d HP or less." % DroverCrew.RESTRAIN_HP
	return ""

func restrain() -> bool:
	var reason := restrain_reason()
	if reason != "": return reject(reason)
	soldiers[active_soldier]["ap"] -= 1
	status_text = "%s: %s" % [soldiers[active_soldier]["name"],DroverCrew.restrain(crew,restrain_target())]
	rebuild_movement()
	return true

func try_move(cell: Vector2i) -> bool:
	var mover := active_soldier
	var moved := super.try_move(cell)
	if moved: clear_suppression(mover)
	return moved

func clear_suppression(by: int = -2) -> void:
	for entry in crew.get("units",[]):
		if by == -2 or entry["suppressed_by"] == by: entry["suppressed_by"] = -1
	if not drone.is_empty() and (by == -2 or drone["suppressed_by"] == by): drone["suppressed_by"] = -1

func fire_block_reason() -> String:
	if ended: return "Operation ended."
	if not soldier_can_act(active_soldier): return "Select a standing soldier."
	var soldier: Dictionary = soldiers[active_soldier]
	if soldier.get("carrying",-1) >= 0: return "Cannot fire while carrying a casualty."
	if soldier["ap"] < 1: return "No AP left."
	if soldier["attacked"]: return "Already fired this round."
	if soldier["ammo"] < 1: return "Out of ammunition: reload."
	if aimed() == "": return "Aim [T], then click Drover security, the hauler or a visible drone."
	if not sight_preview(soldier["cell"],sight_target())["can_fire"]: return "No clear shot at that range."
	return ""

func try_fire() -> bool:
	var reason := fire_block_reason()
	if reason != "": return reject(reason)
	var soldier: Dictionary = soldiers[active_soldier]
	var target := sight_target()
	var what := aimed()
	var info := sight_preview(soldier["cell"],target)
	soldier["ap"] -= 1
	soldier["ammo"] -= 1
	soldier["attacked"] = true
	round_noise.append(soldier["cell"])
	round_noise.append(target)
	var roll := shot_rng.randi_range(1,100)
	if roll > info["chance"]:
		var reaction := "" if what == "drone" else DroverCrew.provoke(crew,phase,"squad")
		if what != "drone" and crew["agreement"] == "none" and crew["pause"]["state"] == "none": crew["agreement"] = "assault"
		status_text = "%s fires (%d%%) and misses. %s" % [soldier["name"],info["chance"],reaction]
	elif what == "drone":
		status_text = "%s fires (%d%%): %s" % [soldier["name"],info["chance"],GreyDrone.take_hit(drone,DroverCrew.SHOT_DAMAGE,"squad")]
	else:
		status_text = "%s fires (%d%%): %s" % [soldier["name"],info["chance"],DroverCrew.take_hit(crew,DroverCrew.unit_at(crew,target),DroverCrew.SHOT_DAMAGE,phase)]
	if aimed() == "": pinned_target = NONE
	rebuild_movement()
	return true

# ---------------------------------------------------------------- turn

func resolve_enemy_turn() -> void:
	if last_enemy_phase == phase: return
	last_enemy_phase = phase
	var lines: Array[String] = []
	# Drover phase, then Grey phase (GDD §12 multifaction order).
	if drone["fired"] and drone["attributed"] and GreyDrone.flying(drone) and DroverCrew.armed(crew):
		lines.append("Drover security fires on the drone. " + GreyDrone.take_hit(drone,GreyDrone.HP,"drovers"))
	var drover_line := DroverCrew.act(crew,self)
	if drover_line != "": lines.append(drover_line)
	var grey_line := GreyDrone.act(drone,crew,self)
	if grey_line != "": lines.append(grey_line)
	enemy_message = " ".join(lines) if not lines.is_empty() else ("The junction is quiet." if crew["left"] else "The crew keeps loading.")
	rebuild_movement()
	check_recovery_failure()
	finalize_result()

func begin_player_phase() -> void:
	super.begin_player_phase()
	clear_suppression()
	if DroverCrew.pause_active(crew): status_text = "Round %d. Corridor pause holds through round %d: move people along the green lane." % [phase,crew["pause"]["until"]]
	elif DroverCrew.hostile(crew,phase): status_text = "Round %d. Drover security is hostile. Move off the red aim lines." % phase
	else: status_text = "Round %d. %s" % [phase,enemy_message.left(150)]

func agreement() -> String:
	if crew["agreement"] == "active": return "honored"
	if crew["agreement"] == "none" and drone["attributed"]: return "greys_attributed"
	if crew["agreement"] == "honored" and drone["attributed"]: return "honored_greys_attributed"
	return crew["agreement"]

func enemy_intent() -> String:
	var parts: Array[String] = []
	if crew["left"]: parts.append("Drover crew gone (%s)" % ("cargo seized" if crew["cargo"] == "seized" else "drove out with the cargo"))
	elif DroverCrew.pause_active(crew): parts.append("PAUSE holding through round %d" % crew["pause"]["until"])
	elif crew["pause"]["state"] == "requested": parts.append("Pause requested: answer next Drover phase")
	elif DroverCrew.hostile(crew,phase): parts.append("DROVERS HOSTILE" + (" until round %d" % crew["hostile_until"] if crew["hostile_until"] < 99 else ""))
	else: parts.append("Drovers loading until the end of round %d (%s)" % [DroverCrew.LEAVE_ROUND,crew["stance"]])
	if drone_visible(): parts.append("GREY DRONE at (%d,%d)%s" % [drone["cell"].x,drone["cell"].y," · observed" if drone["observed"] else ""])
	return " · ".join(parts)

func danger_summary() -> String:
	if crew["left"]: return "The junction is open. The convoy window closes after round %d." % deadline()
	return "Civilians won't walk into the armed work zone (columns 9–13) unless a pause holds. A soldier within 2 squares of the hauler without a pause provokes security."

func machine_outcome() -> String:
	match agreement():
		"honored": return "Corridor pause honored. The crew loaded and left on schedule."
		"honored_greys_attributed", "greys_attributed": return "The Grey drone fired on the hauler; the Drovers saw who did it. The local agreement held."
		"breached_squad": return "The squad broke the corridor pause."
		"breached_greys": return "Unseen Grey fire broke the pause, and the Drovers blamed the squad."
		"assault": return "Assault: the squad took the junction by force."
		"expired": return "Pause expired before the crew left."
	return "No agreement with the Drover crew."

func security_tally() -> Dictionary:
	var tally := {"unharmed":0,"restrained":0,"killed":0}
	for entry in crew["units"]:
		if entry["restrained"]: tally["restrained"] += 1
		elif entry["hp"] <= 0: tally["killed"] += 1
		else: tally["unharmed"] += 1
	return tally

func feeder_result() -> String:
	var tally := security_tally()
	var parts: Array[String] = []
	parts.append("Cargo seized." if crew["cargo"] == "seized" else ("Cargo left with the Drovers." if crew["cargo"] == "left" else "Cargo still loading."))
	parts.append("Drover security: %d unharmed, %d restrained, %d killed." % [tally["unharmed"],tally["restrained"],tally["killed"]])
	parts.append({"ignored":"The drone was never identified.","observed":"Grey drone observed and logged.","shot":"Grey drone shot down before it fired.","shot_after":"Grey drone shot down after it fired.","downed_by_drovers":"Drover security downed the Grey drone."}.get(drone["outcome"],""))
	if crew["log"].has("component_returned"): parts.append("Main Street component returned.")
	return " ".join(parts)

func result_title() -> String:
	if retry_required(): return "ATTEMPT ENDED / RETRY REQUIRED"
	var everyone := evacuated_people() == 12
	for soldier in soldiers:
		everyone = everyone and soldier["extracted"] and soldier["condition"] != "dead"
	return "INTERCHANGE / JUNCTION REOPENED" if everyone else "INTERCHANGE / PARTIAL"

# ---------------------------------------------------------------- story

func opening_pages() -> Array:
	return [
		{"speaker":"ACT II · THE HIDDEN WAR / MISSION 04: INTERCHANGE","text":"Ward's convoy needs the interchange east of town. It's the last road out that can take trucks.\n\nIt's occupied. Armed Drovers are loading cargo off a jackknifed freight line, fast and nervous. A civilian group is stuck on the overpass right above them.","tag":"Reopen the junction · get the overpass group down · extract the squad"},
		{"speaker":"WARD / RADIO","text":"‘You told me the Farm Road machine answered a signal. Here's your chance to prove it scales. Or clear them out. Your call, Sergeant. I need that road by the end of round ten.’","tag":"Pause, escort, or assault: all three are legal"},
		{"speaker":"PARK","text":"‘Something's sitting low over the frontage road to the south. Small. Grey. It isn't Drover.’\n\nBell: ‘Then whose is it?’","tag":"Something else is watching the crew"}]

func current_pages() -> Array:
	if scene_view == "opening": return opening_pages()
	if scene_view == "debrief": return debrief_pages()
	return log_pages()

func log_pages() -> Array:
	var pages := opening_pages()
	pages.append({"speaker":"INTELLIGENCE / INTERCHANGE","text":enemy_intent()+"\n\n"+danger_summary(),"tag":"Observation, not doctrine"})
	if result_ready and not retry_required(): pages.append_array(debrief_pages())
	return pages

func debrief_pages() -> Array:
	var out: Array[String] = []
	var left: Array[String] = []
	for cohort in cohorts:
		if cohort["status"] == "extracted": out.append(cohort["id"])
		else: left.append(cohort["id"])
	var pages: Array = [{"speaker":"INTERCHANGE / VERIFIED FIELD REPORT","text":"Through the junction: %s.\nLeft behind: %s.\n\n%s\n%s" % [", ".join(out) if not out.is_empty() else "none",", ".join(left) if not left.is_empty() else "none",machine_outcome(),feeder_result()],"tag":"Who broke what, and why, is on the record"}]
	var verdict := agreement()
	if verdict in ["honored","honored_greys_attributed","greys_attributed","expired"]:
		pages.append({"speaker":"KESH / WORK CHANNEL","text":"A voice on the channel, in careful English: ‘You held your side. We held ours. I am Kesh. I speak for the surface crews, not for everyone below.’\n\nWard, afterwards: ‘Then you're my contact for them. Limited agreements. Written down.’","tag":"MSG designated field contact for limited Drover agreements"})
	elif verdict == "breached_greys":
		pages.append({"speaker":"PARK","text":"‘That shot came from the south. Not us. They didn't see it, and we can't prove it.’\n\nThe channel stays silent.","tag":"An unattributed breach: the record says what happened, even if they don't believe it"})
	else:
		pages.append({"speaker":"ORTIZ","text":"‘We got the road. They'll remember how.’","tag":"No agreement on record"})
	if drone["observed"] or drone["outcome"] in ["shot","shot_after","downed_by_drovers"]:
		pages.append({"speaker":"BELL","text":"‘It wasn't watching us. It was watching them, and it fired to start something.’\n\nFirst verified evidence: the Greys monitor the other factions.","tag":"A second operational pattern"})
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
	save_feedback = "Saving isn't available at the Interchange yet."
	status_text = save_feedback
	queue_redraw()
	return false

func load_encounter(_path: String = RETURN_SLOT) -> bool:
	save_feedback = "Loading isn't available at the Interchange yet."
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
	var fresh = load("res://interchange.tscn").instantiate()
	fresh.auto_resume = false
	fresh.record_path = record_path
	get_parent().add_child(fresh)
	queue_free()

# ---------------------------------------------------------------- drawing (HUD map layer)

func draw_mission_layer(projection, font: Font) -> void:
	var size := CELL_SIZE
	# Overpass deck and frontage road.
	for x in range(6,17):
		for y in [2,3]:
			draw_rect(Rect2(projection.cell_anchor(Vector2i(x,y)),Vector2.ONE*size),Color(0.42,0.42,0.46,0.25))
	draw_string(font,projection.cell_anchor(Vector2i(7,2))+Vector2(2,-3),"OVERPASS · east end collapsed",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("c9d3e0"))
	draw_string(font,projection.cell_anchor(OVERPASS_RAMP)+Vector2(0,22),"RAMP",HORIZONTAL_ALIGNMENT_CENTER,size,9,Color("c9d3e0"))
	for x in range(1,GRID_SIZE.x+1):
		for y in [13,14]:
			draw_rect(Rect2(projection.cell_anchor(Vector2i(x,y)),Vector2.ONE*size),Color(0.35,0.33,0.3,0.18))
	draw_string(font,projection.cell_anchor(Vector2i(7,14))+Vector2(2,size+11),"FRONTAGE ROAD (slow way round)",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("d8c9a8"))
	for cell in FIXTURES:
		draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(3,3),Vector2.ONE*(size-6)),Color("5a4a33"))
		draw_string(font,projection.cell_anchor(cell)+Vector2(0,22),"CRATE",HORIZONTAL_ALIGNMENT_CENTER,size,8,Color("e8c9a0"))
	if crew.is_empty(): return
	# Work zone (closed to civilians) and the corridor lane.
	if DroverCrew.hauler_running(crew) and DroverCrew.armed(crew):
		var paused := DroverCrew.pause_active(crew)
		for x in range(DroverCrew.ZONE_MIN.x,DroverCrew.ZONE_MAX.x+1):
			for y in range(DroverCrew.ZONE_MIN.y,DroverCrew.ZONE_MAX.y+1):
				var cell := Vector2i(x,y)
				if WALL_CELLS.has(cell): continue
				var near := DroverCrew.distance(cell,HAULER) <= DroverCrew.PROVOKE_RANGE
				draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(1,1),Vector2.ONE*(size-2)),Color(0.95,0.7,0.2,(0.06 if paused else 0.14)+(0.08 if near else 0.0)))
		draw_string(font,projection.cell_anchor(DroverCrew.ZONE_MIN)+Vector2(-6,-4),"WORK ZONE" + (" · PAUSED" if paused else " · civilians won't enter"),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("ffcf7a"))
		if paused or crew["pause"]["state"] == "requested":
			for x in range(LANE_FROM,LANE_TO+1):
				var at: Vector2 = projection.cell_anchor(Vector2i(x,LANE_ROW))
				draw_rect(Rect2(at+Vector2(2,12),Vector2(size-4,12)),Color(0.4,0.9,0.5,0.55 if paused else 0.25))
	# Hauler.
	if not crew["left"]:
		var at: Vector2 = projection.cell_anchor(HAULER)
		var alive: bool = crew["hauler"]["hp"] > 0
		draw_rect(Rect2(at+Vector2(-4,-2),Vector2(size+8,size+4)),Color("6e5a3c") if alive else Color("3a3a3a"))
		var lamp := Color("6fe08a") if DroverCrew.pause_active(crew) else (Color("ff5c66") if DroverCrew.hostile(crew,phase) else Color("ffb75a"))
		draw_circle(at+Vector2(size-4,4),5,lamp if alive else Color("555555"))
		draw_rect(Rect2(at+Vector2(-30,-17),Vector2(96,13)),Color(0.05,0.06,0.05,0.85))
		draw_string(font,at+Vector2(-30,-7),"HAULER %d HP" % crew["hauler"]["hp"] if alive else "HAULER (seized)",HORIZONTAL_ALIGNMENT_CENTER,96,9,Color("ffe1a8"))
	# Security units and their aim lines.
	for entry in crew["units"]:
		if crew["left"] and not entry["restrained"]: continue
		if entry["hp"] <= 0 and not entry["restrained"]:
			draw_string(font,projection.cell_anchor(entry["cell"])+Vector2(0,22),"DOWN",HORIZONTAL_ALIGNMENT_CENTER,size,9,Color("aebbb6"))
			continue
		var center: Vector2 = projection.cell_anchor(entry["cell"])+Vector2(18,18)
		var hostile_now := DroverCrew.hostile(crew,phase)
		draw_colored_polygon(PackedVector2Array([center+Vector2(0,-13),center+Vector2(12,10),center+Vector2(-12,10)]),Color("4f7da6") if not entry["restrained"] else Color("5d6670"))
		var label: String = "HELD" if entry["restrained"] else "SECURITY %d HP%s" % [entry["hp"]," · SUPP" if entry["suppressed_by"] >= 0 else ""]
		draw_rect(Rect2(center+Vector2(-50,-31),Vector2(100,13)),Color(0.04,0.06,0.09,0.85))
		draw_string(font,center+Vector2(-50,-21),label,HORIZONTAL_ALIGNMENT_CENTER,100,9,Color("ff8a80") if hostile_now and not entry["restrained"] else Color("a8d0f0"))
		if not entry["aim"].is_empty():
			draw_line(center,projection.cell_anchor(entry["aim"]["cell"])+Vector2(18,18),Color(1,0.3,0.35,0.85),3)
			draw_rect(Rect2(projection.cell_anchor(entry["aim"]["cell"])+Vector2(2,2),Vector2.ONE*(size-4)),Color("ff5c66"),false,2)
		if sight_mode and pinned_target == entry["cell"]:
			draw_rect(Rect2(projection.cell_anchor(entry["cell"])+Vector2(1,1),Vector2.ONE*(size-2)),Color("e6a2c7"),false,2)
	# Grey drone.
	if drone_visible():
		var center: Vector2 = projection.cell_anchor(drone["cell"])+Vector2(18,18)
		draw_circle(center,9,Color("c9d3e0"))
		draw_line(center+Vector2(-15,-8),center+Vector2(15,-8),Color("c9d3e0"),2)
		draw_rect(Rect2(center+Vector2(-40,-31),Vector2(80,13)),Color(0.05,0.06,0.08,0.85))
		draw_string(font,center+Vector2(-40,-21),"DRONE" + (" · LOGGED" if drone["observed"] else " · ?"),HORIZONTAL_ALIGNMENT_CENTER,80,9,Color("e6e9f0"))
		if sight_mode and pinned_target == drone["cell"]:
			draw_rect(Rect2(projection.cell_anchor(drone["cell"])+Vector2(1,1),Vector2.ONE*(size-2)),Color("e6a2c7"),false,2)
