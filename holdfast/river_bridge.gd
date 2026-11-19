extends "res://encounter_controller.gd"
## Mission 02 · River Bridge (spec: docs/missions/river-bridge.md).
## Reuses the encounter's squad, civilian command, panic and rescue rules. Replaces the
## Farm Road machine with a Grey extraction team, adds the bridge lane choice, the
## damaged sensor and the unidentified craft. Save/load for this mission comes later.
const RiverMission = preload("res://missions/river_bridge.tres")
const GreyTeam = preload("res://systems/grey_team.gd")
const CampaignRecord = preload("res://systems/campaign_record.gd")

const BRIDGE: Array[Vector2i] = [Vector2i(9,7),Vector2i(10,7),Vector2i(9,8),Vector2i(10,8),Vector2i(9,9),Vector2i(10,9)]
const PEOPLE_ROW := 7
const CHECKPOINT := Vector2i(8,8)
const SENSOR_CELL := Vector2i(6,14)
const BARN: Array[Vector2i] = [Vector2i(14,11),Vector2i(15,11),Vector2i(14,12),Vector2i(15,12)]
const COLLECTOR_START := Vector2i(15,3)
const SENTRY_START := Vector2i(16,4)
const REPLACEMENTS := ["Reyes","Okafor","Lindqvist"]

var greys: Dictionary = {}
var lanes := ""             # "", "people" or "heavy"
var sensor_recovered := false
var sensor_carrier := -1
## Farm Road's record, read once at the start (squad wounds and losses carry over).
var record_path := ""

func mission_definition() -> Resource:
	if mission_override != null: return mission_override
	return RiverMission

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
	report_path = "user://holdfast_m02_result.save"
	completion_path = "user://holdfast_m02_completed.save"
	campaign_path = "user://holdfast_m02_campaign.save"
	greys = GreyTeam.initial(COLLECTOR_START,SENTRY_START)
	carry_over_squad()
	for cohort in cohorts:
		var id: String = cohort["id"]
		cohort["manifest"] = []
		for number in range(1,5): cohort["manifest"].append("RB-%s-%02d" % [id,number])
	status_text = "River Bridge: set the bridge lanes at the checkpoint (8,8), then move the column across."
	enemy_message = "Grey team working the north-east field."
	save_feedback = "Saving isn't available in River Bridge yet."
	rebuild_movement()

## Wounds and losses from Farm Road. MSG always deploys (a lost MSG means a Farm Road retry).
func carry_over_squad() -> void:
	var path := record_path if record_path != "" else ""
	if path == "": return
	var entry: Dictionary = CampaignRecord.load_record(path)["missions"].get(1,{})
	if entry.is_empty(): return
	var next_replacement := 0
	for index in range(mini(entry["squad"].size(),soldiers.size())):
		var previous: Dictionary = entry["squad"][index]
		var soldier: Dictionary = soldiers[index]
		if previous["condition"] == "dead" and index > 0:
			soldier["name"] = REPLACEMENTS[next_replacement % REPLACEMENTS.size()]
			soldier["mark"] = soldier["name"].left(1)
			soldier["replacement_for"] = previous["name"]
			next_replacement += 1
		elif previous["condition"] in ["critical","stable"]:
			soldier["hp"] = 4

# ---------------------------------------------------------------- map rules

func cohort_at(cell: Vector2i) -> int:
	for index in range(cohorts.size()):
		if cohorts[index]["status"] == "active" and cohorts[index]["cell"] == cell: return index
	return -1

func sheltered(cell: Vector2i) -> bool:
	return BARN.has(cell)

func target_at(cell: Vector2i) -> int:
	return GreyTeam.unit_at(greys,cell) if not greys.is_empty() else -1

func civilian_safe(cell: Vector2i) -> bool:
	if not cell_is_in_bounds(cell) or WALL_CELLS.has(cell) or FIXTURES.has(cell): return false
	if target_at(cell) >= 0: return false
	if BRIDGE.has(cell):
		if lanes == "": return false
		if lanes == "heavy" and cell.y != PEOPLE_ROW: return false
	return true

func civilian_waypoint(order: String) -> Vector2i:
	return mission_definition().civilian_routes["north" if order == "north" else "south"]

func route_available(order: String) -> bool:
	if lanes == "": return false
	return not (lanes == "heavy" and order == "south")

func route_label(order: String) -> String:
	return "Bridge, upstream row" if order == "north" else "Bridge, downstream row"

## Single file on the heavy-lane bridge: one group on it at a time, two squares a turn.
func move_cohort(cohort: Dictionary, budget: int) -> void:
	if lanes == "heavy" and cohort["status"] == "active" and cohort["order"] != "hold":
		var path := route_preview(cohort,cohort["order"])
		var on_bridge: bool = BRIDGE.has(cohort["cell"])
		var entering: bool = not path.is_empty() and BRIDGE.has(path[0])
		if entering and not on_bridge:
			for other in cohorts:
				if other != cohort and other["status"] == "active" and BRIDGE.has(other["cell"]):
					cohort["note"] = "Waiting: single file on the bridge"
					return
		if on_bridge or entering: budget = mini(budget,2)
	super.move_cohort(cohort,budget)

func civilian_threats() -> Array[Vector2i]:
	var threats: Array[Vector2i] = GreyTeam.threat_cells(greys)
	threats.append_array(round_noise)
	return threats

func deadline() -> int:
	return mission_definition().closing_round

func mission_completion_reason(round_number: int) -> String:
	return MissionObjectives.completion_reason(mission_definition(),round_number,0,all_extracted(),remaining_civilians())

# ---------------------------------------------------------------- actions

func set_lanes(mode: String) -> bool:
	if ended or lanes != "" or not ["people","heavy"].has(mode):
		status_text = "The bridge lanes are already set." if lanes != "" else "Lane order unavailable."
		queue_redraw()
		return false
	if not soldier_can_act(active_soldier) or soldiers[active_soldier]["ap"] < 1 or GreyTeam.distance(soldiers[active_soldier]["cell"],CHECKPOINT) > 1:
		status_text = "Set lanes: a soldier with 1 AP on or next to the checkpoint (8,8)."
		queue_redraw()
		return false
	soldiers[active_soldier]["ap"] -= 1
	lanes = mode
	status_text = "People first: all three bridge rows open to civilians. The supply trucks wait." if mode == "people" else "Heavy lane: rows 8–9 go to the supply convoy. Civilians cross single file on row 7."
	rebuild_movement()
	return true

func recover_sensor() -> bool:
	if ended or sensor_recovered:
		status_text = "Sensor already recovered." if sensor_recovered else "Operation over."
		queue_redraw()
		return false
	if not soldier_can_act(active_soldier) or soldiers[active_soldier]["ap"] < 1 or GreyTeam.distance(soldiers[active_soldier]["cell"],SENSOR_CELL) > 1:
		status_text = "Recover sensor: a soldier with 1 AP on or next to the reeds at (6,14)."
		queue_redraw()
		return false
	soldiers[active_soldier]["ap"] -= 1
	sensor_recovered = true
	sensor_carrier = active_soldier
	status_text = "%s recovers the damaged sensor. Its last log shows two different signatures on the far bank." % soldiers[active_soldier]["name"]
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
	var target := sight_target()
	if GreyTeam.unit_at(greys,target) < 0: return "Aim [T], then click a Grey unit to pin it."
	var info := sight_preview(soldier["cell"],target)
	if not info["can_fire"]: return "No clear shot at that range."
	return ""

func try_fire() -> bool:
	var reason := fire_block_reason()
	if reason != "":
		status_text = reason
		queue_redraw()
		return false
	var soldier: Dictionary = soldiers[active_soldier]
	var target := sight_target()
	var index := GreyTeam.unit_at(greys,target)
	var info := sight_preview(soldier["cell"],target)
	soldier["ap"] -= 1
	soldier["ammo"] -= 1
	soldier["attacked"] = true
	round_noise.append(soldier["cell"])
	round_noise.append(target)
	var roll := shot_rng.randi_range(1,100)
	if roll <= info["chance"]:
		status_text = "%s fires (%d%%): %s" % [soldier["name"],info["chance"],GreyTeam.take_hit(greys,index,GreyTeam.SHOT_DAMAGE)]
	else:
		greys["hostile"] = true
		status_text = "%s fires (%d%%) and misses. The Greys know you're here." % [soldier["name"],info["chance"]]
	pinned_target = NONE if GreyTeam.unit_at(greys,target) < 0 else pinned_target
	rebuild_movement()
	return true

# ---------------------------------------------------------------- turn

func resolve_enemy_turn() -> void:
	if last_enemy_phase == phase: return
	last_enemy_phase = phase
	enemy_message = GreyTeam.act(greys,self)
	check_recovery_failure()
	finalize_result()

func begin_player_phase() -> void:
	super.begin_player_phase()
	if lanes == "":
		status_text = "Round %d. The bridge lanes still aren't set: stand a soldier at the checkpoint (8,8)." % phase
	elif not greys["withdrawn"]:
		status_text = "Round %d. %s" % [phase,enemy_message]
	else:
		status_text = "Round %d. The far bank is quiet. Get the column across before dusk (round %d)." % [phase,deadline()]

func enemy_intent() -> String:
	if greys["withdrawn"]: return "Grey team gone (%s)." % greys["withdraw_reason"]
	var parts: Array[String] = []
	if not greys["lift"].is_empty():
		parts.append("LIFT on group %s: %d" % [cohorts[greys["lift"]["group"]]["id"],greys["lift"]["count"]])
	if not greys["aim"].is_empty():
		parts.append("Sentry beam aimed at (%d,%d)" % [greys["aim"]["cell"].x,greys["aim"]["cell"].y])
	if parts.is_empty(): parts.append("Collector hunting for civilians" + (" · Sentry hostile" if greys["hostile"] else " · Sentry passive"))
	return " · ".join(parts)

func danger_summary() -> String:
	if greys["withdrawn"]: return "No Grey activity. Dusk closes the crossing after round %d." % deadline()
	return "Greys withdraw after round %d. Hitting the Collector breaks a lift; so does getting the group into the barn (14–15, 11–12)." % GreyTeam.WITHDRAW_ROUND

func machine_outcome() -> String:
	if greys.is_empty(): return ""
	var collector := GreyTeam.unit(greys,"collector")
	if collector.is_empty() and not greys["withdraw_reason"].begins_with("Extraction"): return "Grey Collector down; the team abandoned the site."
	if greys["withdrawn"]: return "Grey team withdrew on its own clock."
	return "Grey team still on the far bank."

func feeder_result() -> String:
	var lane_text: String = {"people":"Bridge given to people; supply trucks turned back.","heavy":"Heavy lane held; supplies crossed.","":"Bridge lanes never set."}[lanes]
	return lane_text + (" Damaged sensor recovered." if sensor_recovered else " Sensor left in the reeds.")

# ---------------------------------------------------------------- story

func opening_pages() -> Array:
	return [
		{"speaker":"ACT I · MISSION 02 / RIVER BRIDGE","text":"Ward's patrol order came through at dawn: get the north-bank column across the river before dusk, and bring back anything that explains what's happening.\n\nThe reports don't agree. Some say machines are rerouting around people. Others say people are being taken.","tag":"Escort the column · recover the sensor · extract the squad"},
		{"speaker":"BELL / BRIDGE CHECKPOINT","text":"‘Three rows. We can give them all to the civilians, or keep two for the supply trucks. Not both before dark.’\n\nPark is already looking past the river. ‘Far field. Two of them. They're not machines.’","tag":"Set the lanes at the checkpoint (8,8) before anyone can cross"},
		{"speaker":"ORTIZ","text":"‘Whatever they are, they're watching the people, not us.’\n\nA sensor mast lies broken in the reeds downstream. Its last log might say which reports are true.","tag":"Greys extract people; they escalate only if you interfere"}]

func current_pages() -> Array:
	if scene_view == "opening": return opening_pages()
	if scene_view == "debrief": return debrief_pages()
	return log_pages()

func log_pages() -> Array:
	var pages := opening_pages()
	pages.append({"speaker":"INTELLIGENCE / RIVER BRIDGE","text":enemy_intent()+"\n\n"+danger_summary(),"tag":"Observation, not doctrine"})
	if result_ready and not retry_required(): pages.append_array(debrief_pages())
	return pages

func debrief_pages() -> Array:
	var crossed: Array[String] = []
	var taken: Array[String] = []
	var stranded: Array[String] = []
	for cohort in cohorts:
		match cohort["status"]:
			"extracted": crossed.append(cohort["id"])
			"taken": taken.append(cohort["id"])
			_: stranded.append(cohort["id"])
	var report := "Crossed: %s.\nTaken: %s.\nLeft on the north bank: %s.\n\n%s\n%s" % [", ".join(crossed) if not crossed.is_empty() else "none",", ".join(taken) if not taken.is_empty() else "none",", ".join(stranded) if not stranded.is_empty() else "none",machine_outcome(),feeder_result()]
	var pages: Array = [{"speaker":"RIVER BRIDGE / VERIFIED FIELD REPORT","text":report,"tag":"Read to the available survivors"}]
	var craft: String = "An unidentified craft spent a shield over group %s and left damaged, heading east. Identity unconfirmed." % greys["log"].filter(func(entry): return entry.begins_with("craft_shield:")).map(func(entry): return entry.split(":")[1]).front() if greys["shield_used"] else "No craft intervened."
	pages.append({"speaker":"PARK","text":"‘The machines at Farm Road went around people. These went for them.’\n\n"+craft,"tag":"Two different patterns: the single-invasion line doesn't hold"})
	if not taken.is_empty():
		pages.append({"speaker":"ORTIZ","text":"‘We have their names. That isn't the same as having them back.’","tag":"Taken groups stay on record, unresolved"})
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
	save_feedback = "Saving isn't available in River Bridge yet."
	status_text = save_feedback
	queue_redraw()
	return false

func load_encounter(_path: String = RETURN_SLOT) -> bool:
	save_feedback = "Loading isn't available in River Bridge yet."
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
	var fresh = load("res://river_bridge.tscn").instantiate()
	fresh.auto_resume = false
	fresh.record_path = record_path
	get_parent().add_child(fresh)
	queue_free()

# ---------------------------------------------------------------- drawing (HUD map layer)

func draw_mission_layer(projection, font: Font) -> void:
	var size := CELL_SIZE
	for cell in FIXTURES:
		draw_rect(Rect2(projection.cell_anchor(cell),Vector2.ONE*size),Color("1f4a63"))
	for cell in BRIDGE:
		var people := lanes == "people" or (lanes == "heavy" and cell.y == PEOPLE_ROW)
		var tint := Color("6b5a3e") if lanes == "" else (Color("3c6e5a") if people else Color("5b4a6b"))
		draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(1,1),Vector2.ONE*(size-2)),tint)
		if lanes == "heavy" and not people:
			draw_string(font,projection.cell_anchor(cell)+Vector2(0,22),"TRUCK",HORIZONTAL_ALIGNMENT_CENTER,size,9,Color("e6d6ff"))
	if lanes == "":
		draw_string(font,projection.cell_anchor(Vector2i(9,7))+Vector2(0,-4),"LANES NOT SET",HORIZONTAL_ALIGNMENT_CENTER,size*2,10,Color("ffb75a"))
	draw_rect(Rect2(projection.cell_anchor(CHECKPOINT)+Vector2(3,3),Vector2.ONE*(size-6)),Color("f7cd6c"),false,2)
	draw_string(font,projection.cell_anchor(CHECKPOINT)+Vector2(0,22),"CHK",HORIZONTAL_ALIGNMENT_CENTER,size,10,Color("f7cd6c"))
	for cell in BARN:
		draw_rect(Rect2(projection.cell_anchor(cell)+Vector2(1,1),Vector2.ONE*(size-2)),Color(0.55,0.38,0.25,0.45))
	draw_string(font,projection.cell_anchor(BARN[0])+Vector2(0,-3),"BARN · SHELTER",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e8c9a0"))
	if not sensor_recovered:
		var at: Vector2 = projection.cell_anchor(SENSOR_CELL)
		draw_line(at+Vector2(8,30),at+Vector2(28,6),Color("8be6de"),3)
		draw_string(font,at+Vector2(0,-3),"SENSOR",HORIZONTAL_ALIGNMENT_CENTER,size,9,Color("8be6de"))
	if greys.is_empty(): return
	if greys["hardware"] != NONE:
		draw_string(font,projection.cell_anchor(greys["hardware"])+Vector2(0,22),"HW",HORIZONTAL_ALIGNMENT_CENTER,size,10,Color("aebbb6"))
	if greys["withdrawn"]: return
	if not greys["aim"].is_empty():
		var sentry := GreyTeam.unit(greys,"sentry")
		if not sentry.is_empty():
			draw_line(projection.cell_anchor(sentry["cell"])+Vector2(18,18),projection.cell_anchor(greys["aim"]["cell"])+Vector2(18,18),Color(1,0.3,0.35,0.85),3)
			draw_rect(Rect2(projection.cell_anchor(greys["aim"]["cell"])+Vector2(2,2),Vector2.ONE*(size-4)),Color("ff5c66"),false,2)
	for entry in greys["units"]:
		if entry["hp"] <= 0: continue
		var center: Vector2 = projection.cell_anchor(entry["cell"])+Vector2(18,18)
		var hostile: bool = greys["hostile"] or entry["kind"] == "collector"
		draw_circle(center,12,Color("c9d3e0"))
		draw_circle(center+Vector2(-4,-3),3,Color("10141a"))
		draw_circle(center+Vector2(4,-3),3,Color("10141a"))
		draw_rect(Rect2(center+Vector2(-46,-31),Vector2(92,13)),Color(0.05,0.06,0.08,0.85))
		draw_string(font,center+Vector2(-46,-21),("COLLECTOR " if entry["kind"] == "collector" else "SENTRY ")+"%d HP" % entry["hp"],HORIZONTAL_ALIGNMENT_CENTER,92,9,Color("ff8a80") if hostile else Color("c9d3e0"))
		if sight_mode and pinned_target == entry["cell"]:
			draw_rect(Rect2(projection.cell_anchor(entry["cell"])+Vector2(1,1),Vector2.ONE*(size-2)),Color("e6a2c7"),false,2)
	if not greys["lift"].is_empty():
		var cohort: Dictionary = cohorts[greys["lift"]["group"]]
		var at: Vector2 = projection.cell_anchor(cohort["cell"])
		draw_rect(Rect2(at+Vector2(-4,-4),Vector2.ONE*(size+8)),Color("ff5c66"),false,3)
		draw_rect(Rect2(at+Vector2(-2,size-2),Vector2(40,14)),Color(0.1,0.02,0.02,0.9))
		draw_string(font,at+Vector2(-2,size+9),"LIFT %d" % greys["lift"]["count"],HORIZONTAL_ALIGNMENT_CENTER,40,11,Color("ff8a80"))
		var collector := GreyTeam.unit(greys,"collector")
		if not collector.is_empty():
			draw_dashed_line(projection.cell_anchor(collector["cell"])+Vector2(18,18),at+Vector2(18,18),Color(1,0.4,0.4,0.6),2,6)

func result_title() -> String:
	if retry_required(): return "ATTEMPT ENDED / RETRY REQUIRED"
	var everyone := evacuated_people() == 12
	for soldier in soldiers:
		everyone = everyone and soldier["extracted"] and soldier["condition"] != "dead"
	return "RIVER BRIDGE / COLUMN ACROSS" if everyone else "RIVER BRIDGE / PARTIAL CROSSING"
