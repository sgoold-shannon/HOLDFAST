extends "res://farm_return.gd"
const InputRouter = preload("res://systems/encounter_input.gd")
const Snapshot = preload("res://systems/encounter_snapshot.gd")
const ViewRouter = preload("res://presentation/view_router.gd")
const EndingOverlay = preload("res://presentation/ending_overlay.gd")
const ENDING_RECT := Rect2(60,945,320,40)

func _ready() -> void:
	prepare_return_startup()
	initialize_tactical()
	initialize_machine()
	initialize_evacuation()
	initialize_breaker()
	initialize_protocol()
	initialize_rescue()
	initialize_results()
	initialize_story()
	# Restore only after roster assignment and return configuration are ready.
	initialize_roster(false)
	initialize_return(auto_resume)

func return_scene_path() -> String:
	return "res://farm_final.tscn"

func ending_available() -> bool:
	return result_ready and return_state["active"] and not retry_required() and campaign["committed"]

func open_ending_test() -> bool:
	if not ending_available(): return false
	var test = load("res://ending_test.tscn").instantiate()
	test.source_snapshot = encounter_snapshot()
	test.return_board = self
	get_parent().add_child(test)
	hide()
	set_process_unhandled_input(false)
	return true

func _unhandled_input(event: InputEvent) -> void:
	InputRouter.dispatch(event,{
		"ending":handle_ending_input,"return":handle_return_input,"roster":handle_roster_input,
		"story":handle_story_input,"results":handle_results_input,"rescue":handle_rescue_input,
		"protocol":handle_protocol_input,"breaker":handle_breaker_input,"civilian":handle_civilian_input,
		"tactical":handle_tactical_input})

func handle_ending_input(event: InputEvent) -> bool:
	if ending_available():
		if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_Z or (roster_open and event.keycode == KEY_ENTER)):
			open_ending_test()
			return true
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = get_global_transform_with_canvas().affine_inverse()*event.position
			if (roster_open and DEPLOY_RECT.has_point(point)) or (not roster_open and scene_view == "" and ENDING_RECT.has_point(point)):
				open_ending_test()
				return true
	return false

func _draw() -> void:
	ViewRouter.render(ViewRouter.screen(roster_open,scene_view,result_ready),{
		"tactical":draw_tactical_layer,"machine":draw_machine_layer,"civilian":draw_civilian_layer,
		"breaker":draw_breaker_layer,"protocol":draw_protocol_layer,"rescue":draw_rescue_layer,
		"roster":func(): RosterPanel.render(self,font,board_projection,roster_panel_snapshot()),
		"story":func(): StoryPanel.render(self,font,board_projection,story_panel_snapshot()),
		"results":func(): ResultsPanel.render(self,font,board_projection,results_panel_snapshot()),
		"results_header":func(): SceneChrome.header(self,font,"HOLDFAST / B6 MISSION RESULTS",790,Color.WHITE),
		"story_navigation":draw_story_navigation,
		"roster_navigation":draw_roster_navigation,
		"return":func(): ReturnOverlay.render(self,font,board_projection,return_overlay_snapshot()),
		"ending":func(): EndingOverlay.render(self,font,board_projection,ending_overlay_snapshot())})

func draw_story_navigation() -> void:
	if not result_ready:
		SceneChrome.header(self,font,"HOLDFAST / C1 · TAB: SCENE LOG",790,Color.WHITE)
	elif not retry_required():
		SceneChrome.button(self,font,DEBRIEF_RECT,"Debrief [B]",Color("344f46"),27,18)

func draw_roster_navigation() -> void:
	if not result_ready:
		SceneChrome.header(self,font,"HOLDFAST / C2 · DEPLOYMENT %d / 2" % campaign.get("deployment",1),805,Color.WHITE)
	else:
		SceneChrome.button(self,font,ROSTER_RECT,"Roster / service history [G]",Color("344f46"),27,17)
		if campaign["committed"]:
			SceneChrome.button(self,font,RETRY_RECT,"Roster [Q / G]",Color("304965"),35,19)

func ending_overlay_snapshot() -> Dictionary:
	return {
		"scene_view":scene_view,
		"roster_open":roster_open,
		"DEPLOY_RECT":DEPLOY_RECT,
		"ENDING_RECT":ENDING_RECT,
		"available":ending_available()}

func encounter_snapshot() -> Dictionary:
	return Snapshot.assemble(rescue_layout(),{
		"combat":combat_snapshot(),"ui":ui_state_snapshot(),"machine":machine,
		"evac":evac_state_snapshot(),"breaker":breaker_progress,"protocol":protocol,
		"rescue_target":rescue_target,"rescue_events":rescue_events,"story":story_state_snapshot(),
		"campaign":campaign,"return_map":return_state})

func restore_extra_snapshot(snapshot: Dictionary) -> void:
	Snapshot.restore_extras(snapshot,{"return_map":restore_return_state,"results":restore_results_state,
		"story":restore_story_state,"campaign":restore_campaign_state})

func close_result_operation(reason: String) -> void:
	close_evacuation(reason)
	close_rescue()

func finalize_result() -> void:
	Completion.finalize(result_state,soldiers,close_result_operation,save_mission_result,
		commit_roster,persist_campaign_result)

func commit_roster() -> void:
	record_campaign_result()
	record_return_result()

func after_turn_resolution() -> void:
	check_recovery_failure()
	finalize_result()
	update_closure_knowledge()

func encounter_slot(path: String) -> String:
	if [SaveStore.SAVE_PATH,FARM_SLOT,EVAC_SLOT,OPTIONS_SLOT,PROTOCOL_SLOT,RESCUE_SLOT,
		RESULT_SLOT,STORY_SLOT,TACTICAL_SLOT].has(path):
		return rescue_slot()
	return path

func save_encounter(path: String = RETURN_SLOT) -> bool:
	var error := Persistence.write(encounter_snapshot(),encounter_slot(path))
	if error != "":
		save_feedback = error
		queue_redraw()
		return false
	# Preserve the existing contract: the requested slot succeeded even if its
	# separate campaign checkpoint fails. Feedback reports the checkpoint error.
	var problem := checkpoint()
	save_feedback = "C2 saved: deployment, roster, service history and current actions." if problem == "" else problem
	queue_redraw()
	return true

func load_encounter(path: String = RETURN_SLOT) -> bool:
	# Migration historically examines the requested source before lower-gate
	# aliases are mapped. Keep that order for existing legacy saves.
	if [TACTICAL_SLOT,STORY_SLOT,RESULT_SLOT].has(path): path = RETURN_SLOT
	var migration := SaveMigration.return_slot(path,campaign_path,rescue_layout())
	if migration["error"] != "":
		save_feedback = migration["error"]
		return false
	var error := Persistence.restore(encounter_slot(migration["path"]),rescue_layout(),
		"Save belongs to another encounter.",apply_loaded_encounter)
	if error != "":
		save_feedback = error
		result_feedback = error
		queue_redraw()
		return false
	save_feedback = "D1 restored: original outcome, repair progress and one-use cooling record."
	queue_redraw()
	return true

func resolve_enemy_turn() -> void:
	if return_state["active"]: activate_return_staging()
	else: activate_origin_machine()
	check_recovery_failure()
	finalize_result()

func protocol_action(action: String) -> bool:
	if return_state["active"]: return reject_return_protocol()
	var success := execute_protocol_action(action)
	update_protocol_observation(action,success)
	return success

func try_fire() -> bool:
	if return_state["active"]: return reject_return_fire()
	var was_diverted: bool = protocol["diverted"]
	var success := fire_at_machine()
	apply_protocol_betrayal(success,was_diverted)
	check_recovery_failure()
	finalize_result()
	return success

func damage_cell(cell: Vector2i, amount: int) -> String:
	var report := apply_casualty_damage(cell,amount)
	# Recovery must wait for every cell in the enclosing blast to resolve.
	call_deferred("check_recovery_failure")
	return report

func record_rescue(kind: String, actor: int, casualty: int) -> void:
	append_rescue_record(kind,actor,casualty)
	apply_rescue_knowledge(actor)

func try_stabilize() -> bool:
	var actor := active_soldier
	var casualty := target_for_rescue()
	var success := stabilize_casualty()
	if success: record_rescue("stabilized",actor,casualty)
	return success

func try_pickup() -> bool:
	var actor := active_soldier
	var casualty := rescue_target
	var success := pick_up_casualty()
	if success: record_rescue("picked_up",actor,casualty)
	return success

func try_extract() -> bool:
	var actor := active_soldier
	var passenger: int = soldiers[actor]["carrying"] if actor >= 0 else -1
	close_pending = false
	var success := false
	if not ended:
		success = extract_selected_soldier()
		# Preserve the original status evaluation before passenger extraction.
		if success and all_extracted():
			status_text = "Squad extracted. %d civilians remain; continue turns or close operation." % remaining_civilians()
	if success and passenger >= 0:
		soldiers[passenger]["extracted"] = true
		soldiers[passenger]["carried_by"] = -1
		soldiers[actor]["carrying"] = -1
		status_text = "%s and %s extracted together for 1 AP." % [soldiers[actor]["name"],soldiers[passenger]["name"]]
		record_rescue("extracted_with",actor,passenger)
	if not success and return_state["active"]:
		status_text = "North extraction: (9,1) through (11,1), 1 AP; carriers extract both."
	return success
