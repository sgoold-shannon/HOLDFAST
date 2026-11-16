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
