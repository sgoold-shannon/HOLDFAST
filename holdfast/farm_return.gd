extends "res://farm_roster.gd"
const SaveMigration = preload("res://systems/save_migration.gd")
const ReturnOverlay = preload("res://presentation/return_overlay.gd")
const NorthboundMission = preload("res://missions/northbound_return.tres")
const ReturnRules = preload("res://return_rules.gd")
const RETURN_SLOT := "user://holdfast_d1.save"
const RETURN_CAMPAIGN := "user://holdfast_d1_campaign.save"
var TUNNEL: Vector2i:
	get: return NorthboundMission.civilian_exit
var REPAIR_CELL: Vector2i:
	get: return mission_definition().repair_cell
const COOLING_BUTTON := Rect2(40,1136,784,40)
var return_state: Dictionary:
	get: return campaign_state.return_state
	set(value): campaign_state.return_state = value

func _ready() -> void:
	var resume := auto_resume
	auto_resume = false
	prepare_return_startup()
	super._ready()
	auto_resume = resume
	initialize_return(resume)

func prepare_return_startup() -> void:
	if campaign_path == CAMPAIGN_SLOT: campaign_path = RETURN_CAMPAIGN

func initialize_return(resume: bool) -> void:
	report_path = "user://holdfast_d1_result.save"
	completion_path = "user://holdfast_d1_completed.save"
	if return_state["active"]: configure_return()
	if resume:
		if FileAccess.file_exists(campaign_path): load_encounter(campaign_path)
		elif FileAccess.file_exists(CAMPAIGN_SLOT): load_encounter(CAMPAIGN_SLOT)
	save_feedback = "D1: K save / L load. G roster; return map uses the original machine outcome."

func rescue_layout() -> String: return "gdd3.1-d1-return"
func rescue_slot() -> String: return RETURN_SLOT

func encounter_snapshot() -> Dictionary:
	var snapshot := super.encounter_snapshot()
	snapshot["return_map"] = return_state.duplicate(true)
	return snapshot

func restore_extra_snapshot(snapshot: Dictionary) -> void:
	restore_return_state(snapshot)
	super.restore_extra_snapshot(snapshot)

func restore_return_state(snapshot: Dictionary) -> void:
	campaign_state.restore_return(snapshot["return_map"])

func save_encounter(path: String = RETURN_SLOT) -> bool:
	if [TACTICAL_SLOT,STORY_SLOT,RESULT_SLOT].has(path): path = RETURN_SLOT
	return super.save_encounter(path)

func load_encounter(path: String = RETURN_SLOT) -> bool:
	if [TACTICAL_SLOT,STORY_SLOT,RESULT_SLOT].has(path): path = RETURN_SLOT
	var migration := SaveMigration.return_slot(path,campaign_path,rescue_layout())
	if migration["error"] != "":
		save_feedback = migration["error"]
		return false
	path = migration["path"]
	var success := super.load_encounter(path)
	if success: save_feedback = "D1 restored: original outcome, repair progress and one-use cooling record."
	return success

func configure_return() -> void:
	opening_done = true
	opening_step = 2
	scene_view = ""
	# A stationary retained asset or an empty footprint; no new enemy is implied.
	enemies[0]["hp"] = 16 if ["diverted","disabled"].has(return_state["source"]) else 0
	machine["pending_shot"] = NONE
	status_text = "Return to Farm Road: civilians exit north at (10,1). Manual route always available."

func machine_track() -> Array[Vector2i]:
	if return_state["active"]:
		var empty: Array[Vector2i] = []
		return empty
	return super.machine_track()

func skid_visible() -> bool:
	if return_state["active"]: return not campaign["missions"][0]["feeder"].contains("severed")
	return super.skid_visible()

func cooling_ready() -> bool:
	return return_state["source"] == "diverted" or (return_state["source"] == "disabled" and return_state["repair"] == 2)

func can_deploy() -> bool:
	return not return_state["active"] and campaign["committed"] and campaign["deployment"] < 3 and Roster.next_assignments(campaign)[0] == "msg"

func start_second_deployment() -> bool:
	if not can_deploy(): return false
	var next := campaign.duplicate(true)
	next["deployment"] += 1
	next["committed"] = false
	next["assignments"] = Roster.next_assignments(campaign)
	var state := ReturnRules.initial()
	state["active"] = true
	state["source"] = ReturnRules.outcome(campaign)
	return replace_return_attempt(next,state)

func return_scene_path() -> String:
	return "res://farm_return.tscn"

func replace_return_attempt(next: Dictionary, state: Dictionary) -> bool:
	var fresh = load(return_scene_path()).instantiate()
	fresh.auto_resume = false
	fresh.campaign = next
	fresh.return_state = state
	fresh.campaign_path = campaign_path
	fresh.preference = preference
	get_parent().add_child(fresh)
	fresh.report_path = report_path
	fresh.completion_path = completion_path
	var problem: String = fresh.checkpoint()
	if problem != "":
		fresh.queue_free()
		result_feedback = problem
		queue_redraw()
		return false
	if get_tree().current_scene == self: get_tree().current_scene = fresh
	queue_free()
	return true

func restart_attempt() -> void:
	if campaign["committed"]:
		open_roster()
		return
	var state := ReturnRules.initial()
	if return_state["active"]:
		state["active"] = true
		state["source"] = return_state["source"]
	replace_return_attempt(campaign.duplicate(true),state)




func next_machine_cell() -> Vector2i:
	return NONE if return_state["active"] else super.next_machine_cell()

func resolve_enemy_turn() -> void:
	if not return_state["active"]:
		super.resolve_enemy_turn()
		return
	last_enemy_phase = phase
	enemy_message = "Return staging: no hostile activation. North access closes after round 10."
	check_recovery_failure()
	finalize_result()

func target_at(cell: Vector2i) -> int:
	return -1 if return_state["active"] else super.target_at(cell)

func is_walkable(cell: Vector2i) -> bool:
	if return_state["active"] and enemies[0]["hp"] > 0 and cell == REPAIR_CELL: return false
	return super.is_walkable(cell)

func civilian_safe(cell: Vector2i) -> bool:
	if return_state["active"]:
		return cell_is_in_bounds(cell) and not WALL_CELLS.has(cell) and not FIXTURES.has(cell) and not (enemies[0]["hp"] > 0 and cell == REPAIR_CELL)
	return super.civilian_safe(cell)

func civilian_waypoint(order: String) -> Vector2i:
	if return_state["active"]: return mission_definition().civilian_routes["north" if order == "north" else "south"]
	return super.civilian_waypoint(order)

func route_label(order: String) -> String:
	if return_state["active"]:
		return ("Cooling" if cooling_ready() else "Cooling locked") if order == "north" else "Manual route"
	return super.route_label(order)

func route_available(order: String) -> bool:
	return not (return_state["active"] and order == "north" and not cooling_ready())

func order_cohort(index: int, order: String) -> bool:
	if return_state["active"] and order == "north" and not cooling_ready():
		status_text = "Cooling route unavailable. Choose the manual route; disabled equipment needs two repairs."
		queue_redraw()
		return false
	return super.order_cohort(index,order)

func try_breaker(confirm: bool = false) -> bool:
	if not return_state["active"]: return super.try_breaker(confirm)
	if ended or return_state["source"] != "disabled" or return_state["repair"] == 2:
		status_text = "Repairs apply only to the retained disabled machine, once per step."
	elif not soldier_can_act(active_soldier) or soldiers[active_soldier]["ap"] < 1:
		status_text = "Select an active soldier with 1 AP."
	elif soldiers[active_soldier]["carrying"] >= 0:
		status_text = "Put down the casualty before repairing machinery."
	elif (soldiers[active_soldier]["cell"]-REPAIR_CELL).abs().x+(soldiers[active_soldier]["cell"]-REPAIR_CELL).abs().y != 1:
		status_text = "Stand adjacent to the retained machine at (10,8)."
	else:
		soldiers[active_soldier]["ap"] -= 1
		return_state["repair"] += 1
		status_text = "Repair %d/2 complete for 1 AP. %s" % [return_state["repair"],"Cooling route and one free move available." if cooling_ready() else "One more adjacent action required; another soldier may finish."]
		rebuild_movement()
		return true
	queue_redraw()
	return false

func use_cooling_move() -> bool:
	if ended or not return_state["active"] or not cooling_ready() or return_state["bonus_event"] != "":
		status_text = "Cooling move unavailable or already used."
		queue_redraw()
		return false
	var cohort: Dictionary = cohorts[cohort_selected]
	if cohort["status"] != "active" or cohort["order"] == "hold":
		status_text = "Select an active civilian group and give it an evacuation order first."
		queue_redraw()
		return false
	var before: Vector2i = cohort["cell"]
	move_cohort(cohort,3)
	if cohort["cell"] == before:
		status_text = "No safe movement available; cooling move retained."
		queue_redraw()
		return false
	return_state["bonus_event"] = "return-cooling-move-1"
	return_state["bonus_group"] = cohort["id"]
	status_text = "Cooling-assisted move used by group %s: up to 3 squares, no AP. One use per return." % cohort["id"]
	queue_redraw()
	return true

func try_fire() -> bool:
	if not return_state["active"]: return super.try_fire()
	status_text = "No hostile targets in this return-map test."
	queue_redraw()
	return false

func protocol_action(action: String) -> bool:
	if not return_state["active"]: return super.protocol_action(action)
	status_text = "Original protocol outcome retained. Use I to repair or Y for the cooling move."
	queue_redraw()
	return false

func try_extract() -> bool:
	var success := super.try_extract()
	if not success and return_state["active"]: status_text = "North extraction: (9,1) through (11,1), 1 AP; carriers extract both."
	return success

func machine_outcome() -> String:
	if not return_state["active"]: return super.machine_outcome()
	return "Return: original %s / %s" % [return_state["source"],"cooling available" if cooling_ready() else ("repair %d/2" % return_state["repair"] if return_state["source"] == "disabled" else "manual route")]

func feeder_result() -> String:
	if not return_state["active"]: return super.feeder_result()
	return "Original record: "+campaign["missions"][0]["feeder"]

func commit_roster() -> void:
	super.commit_roster()
	record_return_result()

func record_return_result() -> void:
	if return_state["active"] and campaign["committed"]:
		campaign["missions"][-1]["return_map"] = return_state.duplicate(true)

func debrief_pages() -> Array:
	if not return_state["active"]: return super.debrief_pages()
	return [{"speaker":"FARM ROAD RETURN / VERIFIED REPORT","text":report_text(),"tag":"Return-map outcomes; original losses remain recorded."},
		{"speaker":"STAGING RECORD","text":machine_outcome()+"\n\n"+feeder_result()+"\n\n"+("One cooling move used by group %s." % return_state["bonus_group"] if return_state["bonus_event"] != "" else "No cooling move used.")+"\n\nRepairs restore a function. They do not restore the original casualties.","tag":"Earlier choice / observed playable consequence"}]

func log_pages() -> Array:
	if not return_state["active"]: return super.log_pages()
	var pages: Array = [{"speaker":"FARM ROAD RETURN / EARLIER RECORD","text":"Original machine: %s.\n\n%s\n\nManual route: waypoint (5,4).\nCooling route: waypoint (10,4), when available.\nCivilian exit: north service tunnel (10,1).\n\nDisabled machinery needs two adjacent 1-AP repairs.\nCooling provides one free move of up to three cells." % [return_state["source"],feeder_result()],"tag":"Original losses persist; this test changes route and repair work."}]
	if result_ready and not retry_required(): pages.append_array(debrief_pages())
	return pages

func scene_options() -> Array:
	return [] if return_state["active"] else super.scene_options()

func choose_scene_option(index: int) -> void:
	if not return_state["active"]: super.choose_scene_option(index)

func advance_scene() -> void:
	if return_state["active"] and scene_view == "debrief":
		if scene_page == 0: scene_page = 1
		else:
			deliver_briefing()
			scene_view = ""
		queue_redraw()
	else: super.advance_scene()

func _unhandled_input(event: InputEvent) -> void:
	if not handle_return_input(event): super._unhandled_input(event)

func handle_return_input(event: InputEvent) -> bool:
	if return_state["active"] and scene_view == "" and not roster_open and not result_ready:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Y:
			use_cooling_move()
			return true
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
			if COOLING_BUTTON.has_point(point):
				use_cooling_move()
				return true
	return false

func _draw() -> void:
	super._draw()
	ReturnOverlay.render(self,font,board_projection,return_overlay_snapshot())

func mission_definition() -> Resource:
	if mission_override != null: return mission_override
	return NorthboundMission if return_state["active"] else super.mission_definition()

func return_overlay_snapshot() -> Dictionary:
	return {
		"roster_open":roster_open,
		"scene_view":scene_view,
		"result_ready":result_ready,
		"DEPLOY_RECT":DEPLOY_RECT,
		"BREAKER_RECT":BREAKER_RECT,
		"COOLING_BUTTON":COOLING_BUTTON,
		"save_feedback":save_feedback,
		"return_state":return_state.duplicate(true),
		"campaign":campaign.duplicate(true),
		"source_outcome":ReturnRules.outcome(campaign),
		"deploy":can_deploy(),
		"outcome":machine_outcome(),
		"cooling":cooling_ready()}
