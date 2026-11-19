extends RefCounted
## The original single-page layout (1144x1224): every panel, button rect and click handler
## that the encounter controller used to draw itself. farm_final.tscn and the 119-action
## parity tests still run through here; the desktop HUD (presentation/hud/) does not.
## Moved out of encounter_controller.gd unchanged apart from `board.` prefixes.
const SceneChrome = preload("res://presentation/scene_chrome.gd")
const TacticalPanel = preload("res://presentation/tactical_panel.gd")
const OverlayView = preload("res://presentation/tactical_overlay.gd")
const BoardView = preload("res://presentation/board_view.gd")
const TacticalInput = preload("res://presentation/tactical_input.gd")
const MachineStatus = preload("res://presentation/machine_status.gd")
const MachineView = preload("res://presentation/machine_view.gd")
const CivilianPanel = preload("res://presentation/civilian_panel.gd")
const CivilianView = preload("res://presentation/civilian_view.gd")
const BreakerPanel = preload("res://presentation/breaker_panel.gd")
const ProtocolPanel = preload("res://presentation/protocol_panel.gd")
const RescuePanel = preload("res://presentation/rescue_panel.gd")
const ModalInput = preload("res://presentation/modal_input.gd")
const ResultInput = preload("res://presentation/modal_input.gd")
const ResultsPanel = preload("res://presentation/results_panel.gd")
const StoryPanel = preload("res://presentation/story_panel.gd")
const RosterPanel = preload("res://presentation/roster_panel.gd")
const ReturnOverlay = preload("res://presentation/return_overlay.gd")
const InputRouter = preload("res://systems/encounter_input.gd")
const ViewRouter = preload("res://presentation/view_router.gd")
const EndingOverlay = preload("res://presentation/ending_overlay.gd")

static func handle_input(board, event: InputEvent) -> void:
	InputRouter.dispatch(event,{
		"ending":func(e): return handle_ending_input(board,e),"return":func(e): return handle_return_input(board,e),
		"roster":func(e): return handle_roster_input(board,e),"story":func(e): return handle_story_input(board,e),
		"results":func(e): return handle_results_input(board,e),"rescue":func(e): return handle_rescue_input(board,e),
		"protocol":func(e): return handle_protocol_input(board,e),"breaker":func(e): return handle_breaker_input(board,e),
		"civilian":func(e): return handle_civilian_input(board,e),"tactical":func(e): return handle_tactical_input(board,e)})

static func render(board) -> void:
	ViewRouter.render(ViewRouter.screen(board.roster_open,board.scene_view,board.result_ready),{
		"tactical":func(): draw_tactical_layer(board),"machine":func(): draw_machine_layer(board),
		"civilian":func(): draw_civilian_layer(board),"breaker":func(): draw_breaker_layer(board),
		"protocol":func(): draw_protocol_layer(board),"rescue":func(): draw_rescue_layer(board),
		"roster":func(): RosterPanel.render(board,board.font,board.board_projection,board.roster_panel_snapshot()),
		"story":func(): StoryPanel.render(board,board.font,board.board_projection,board.story_panel_snapshot()),
		"results":func(): ResultsPanel.render(board,board.font,board.board_projection,board.results_panel_snapshot()),
		"results_header":func(): SceneChrome.header(board,board.font,"HOLDFAST / B6 MISSION RESULTS",790,Color.WHITE),
		"story_navigation":func(): draw_story_navigation(board),
		"roster_navigation":func(): draw_roster_navigation(board),
		"return":func(): ReturnOverlay.render(board,board.font,board.board_projection,board.return_overlay_snapshot()),
		"ending":func(): EndingOverlay.render(board,board.font,board.board_projection,board.ending_overlay_snapshot())})

static func handle_tactical_input(board, event: InputEvent) -> bool:
	var command := TacticalInput.key_command(event)
	if command != "":
		board.run_tactical_command(command)
	if event is InputEventMouse:
		var local_position: Vector2 = board.get_global_transform_with_canvas().affine_inverse() * event.position
		board.hovered_cell = board.local_to_cell(local_position)
		board.queue_redraw()
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			command = TacticalInput.button_command(local_position,board.tactical_buttons())
			if command != "":
				board.run_tactical_command(command)
				return true
			if not board.cell_is_in_bounds(board.hovered_cell):
				return true
			if board.sight_mode and board.active_soldier >= 0:
				board.pinned_target = board.hovered_cell if board.pinned_target != board.hovered_cell else board.NONE
				return true
			var index = board.soldier_at(board.hovered_cell)
			if index >= 0:
				board.select_soldier(index)
			elif board.active_soldier >= 0:
				board.try_move(board.hovered_cell)
			else:
				board.try_select_cell(board.hovered_cell)
	return true

static func draw_tactical_layer(board) -> void:
	SceneChrome.sandbox_header(board,board.font)
	BoardView.render(board,board.font,board.board_projection,board.board_view_snapshot())
	var path: Array[Vector2i] = []
	if not board.sight_mode:
		path = board.path_to(board.hovered_cell)
	var target = board.sight_target()
	OverlayView.render(board,board.board_projection,board.tactical_overlay_snapshot(path,target))
	board.draw_targets()
	for i in range(board.soldiers.size()):
		if not board.soldier_visible(i):
			continue
		var center = board.cell_to_local(board.soldiers[i]["cell"]) + Vector2(18, 18)
		board.draw_soldier_marker(i, center)
	TacticalPanel.render(board,board.font,board.board_projection,board.tactical_panel_snapshot(path,target))

static func draw_machine_layer(board) -> void:
	# Scene-specific title and footer replace the Gate A test labels.
	SceneChrome.header(board,board.font,"HOLDFAST / B1 FARM ROAD MACHINE",790,Color("e5e9e7"))
	MachineView.render(board,board.font,board.board_projection,board.machine_view_snapshot())
	MachineStatus.render(board,board.font,board.board_projection,board.machine_status_snapshot())

static func handle_civilian_input(board, event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = board.get_global_transform_with_canvas().affine_inverse() * event.position
		var action = board.interaction_command(event,{}, {"exit":board.EXIT_ORDER_RECT,"follow":board.FOLLOW_RECT})
		if action == "exit":
			board.order_exit(board.cohort_selected)
			return true
		if action == "follow":
			board.order_cohort(board.cohort_selected,"follow")
			return true
		var clicked_cell = board.local_to_cell(point)
		if board.soldier_at(clicked_cell) < 0 and not board.sight_mode:
			for index in range(3):
				if board.cohorts[index]["status"] == "active" and board.cohorts[index]["cell"] == clicked_cell:
					board.cohort_selected = index
					board.status_text = "Group %s selected. Choose Move to Exit or Follow Soldier at right." % board.cohorts[index]["id"]
					board.queue_redraw()
					return true
		var rows := []
		for index in range(3): rows.append(Rect2(876,132+index*112,248,100))
		# Cards retain priority over the route/closure controls.
		action = board.interaction_command(event,{}, {},rows)
		if action.begins_with("row:"):
			board.cohort_selected = int(action.get_slice(":",1))
			board.queue_redraw()
			return true
		action = board.interaction_command(event,{}, {"north":board.NORTH_RECT,"south":board.SOUTH_RECT,"hold":board.HOLD_RECT,"close":board.CLOSE_RECT,"cancel":board.CANCEL_RECT})
		if action in ["north","south","hold"]: board.order_cohort(board.cohort_selected,action)
		elif action == "close": board.request_close()
		elif action == "cancel":
			board.close_pending = false
			board.queue_redraw()
		if action != "": return true
	if board.ended:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_K:
				board.save_encounter()
			elif event.keycode == KEY_L:
				board.load_encounter()
		if event is InputEventMouseButton and event.pressed:
			var point: Vector2 = board.get_global_transform_with_canvas().affine_inverse() * event.position
			if board.SAVE_RECT.has_point(point):
				board.save_encounter()
			elif board.LOAD_RECT.has_point(point):
				board.load_encounter()
		return true
	return false

static func draw_civilian_layer(board) -> void:
	SceneChrome.header(board,board.font,"HOLDFAST / B2 CIVILIAN EVACUATION",790,Color("e5e9e7"))
	SceneChrome.rescue_guide(board,board.font)
	CivilianView.render(board,board.font,board.board_projection,board.civilian_view_snapshot())
	CivilianPanel.render(board,board.font,board.board_projection,board.civilian_panel_snapshot())

static func handle_breaker_input(board, event: InputEvent) -> bool:
	if board.isolate_pending:
		var action = board.interaction_command(event,{KEY_I:"confirm",KEY_ESCAPE:"cancel"},{"confirm":board.CONFIRM_RECT,"cancel":board.ABORT_RECT})
		if action == "confirm": board.try_breaker(true)
		elif action == "cancel": board.isolate_pending = false
		board.queue_redraw()
		return true
	var buttons = {} if board.sight_mode else {"breaker":board.BREAKER_RECT}
	if board.interaction_command(event,{KEY_I:"breaker"},buttons) == "breaker":
		board.try_breaker()
		return true
	return false

static func draw_breaker_layer(board) -> void:
	BreakerPanel.render(board,board.font,board.board_projection,board.breaker_panel_snapshot())

static func handle_protocol_input(board, event: InputEvent) -> bool:
	if board.isolate_pending:
		return false
	var action = board.interaction_command(event,
		{KEY_O:"observe",KEY_P:"transmit",KEY_A:"authenticate",KEY_D:"divert"},
		{"observe":board.OBSERVE_RECT,"transmit":board.TRANSMIT_RECT,"authenticate":board.AUTH_RECT,"divert":board.DIVERT_RECT})
	if action != "":
		board.protocol_action(action)
		return true
	return false

static func draw_protocol_layer(board) -> void:
	ProtocolPanel.render(board,board.font,board.board_projection,board.protocol_panel_snapshot())

static func handle_rescue_input(board, event: InputEvent) -> bool:
	if board.isolate_pending:
		return false
	if board.drop_mode:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			board.drop_mode = false
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = board.get_global_transform_with_canvas().affine_inverse()*event.position
			board.try_drop(board.local_to_cell(point))
		board.queue_redraw()
		return true
	var action = board.interaction_command(event,
		{KEY_S:"stabilize",KEY_U:"pickup",KEY_J:"drop",KEY_V:"cycle"},
		{"cycle":board.CASUALTY_RECT,"stabilize":board.STABILIZE_RECT,"pickup":board.PICKUP_RECT,"drop":board.DROP_RECT})
	match action:
		"stabilize": board.try_stabilize()
		"pickup": board.try_pickup()
		"drop": board.request_drop()
		"cycle": board.cycle_casualty()
	if action != "": return true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var point: Vector2 = board.get_global_transform_with_canvas().affine_inverse()*event.position
		var index = board.soldier_at(board.local_to_cell(point))
		if board.casualty_available(index) and not board.ended:
			board.rescue_target = index
			board.status_text = "%s selected for rescue. Choose an adjacent rescuer, then S or U." % board.soldiers[index]["name"]
			board.queue_redraw()
			return true
	return false

static func draw_rescue_layer(board) -> void:
	RescuePanel.render(board,board.font,board.board_projection,board.rescue_panel_snapshot())

static func handle_results_input(board, event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		board.load_encounter(board.report_path)
		return true
	if not board.ended:
		return false
	if not board.result_ready:
		return true
	var point := Vector2.ZERO
	if event is InputEventMouse: point = board.get_global_transform_with_canvas().affine_inverse()*event.position
	var action := ResultInput.command(event,point,{KEY_Q:"retry",KEY_L:"load",KEY_K:"save"},
		{"retry":board.RETRY_RECT,"load":board.RESUME_RECT,"save":board.RECORD_RECT})
	match action:
		"retry": board.restart_attempt()
		"load": board.load_encounter()
		"save":
			board.save_encounter()
			board.result_feedback = board.save_feedback
	board.queue_redraw()
	return true

static func handle_story_input(board, event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			board.toggle_log()
			return true
		if event.keycode == KEY_L:
			board.load_encounter()
			return true
		if event.keycode == KEY_K:
			board.save_encounter()
			return true
		if board.scene_view == "" and event.keycode == KEY_B and board.result_ready:
			board.begin_debrief()
			return true
	if board.scene_view == "":
		if board.result_ready and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = board.get_global_transform_with_canvas().affine_inverse()*event.position
			if board.DEBRIEF_RECT.has_point(point):
				board.begin_debrief()
				return true
		return false
	var rows := []
	for index in range(3): rows.append(Rect2(60,770+index*70,980,58))
	var point := Vector2.ZERO
	if event is InputEventMouse: point = board.get_global_transform_with_canvas().affine_inverse()*event.position
	var action := ModalInput.command(event,point,
		{KEY_ESCAPE:"back",KEY_ENTER:"next",KEY_SPACE:"next",KEY_1:"row:0",KEY_2:"row:1",KEY_3:"row:2"},
		{"next":board.NEXT_RECT,"back":board.SKIP_RECT,"log":board.LOG_RECT},rows)
	match action:
		"back":
			if board.scene_view == "opening": board.finish_opening()
			elif board.scene_view == "log": board.toggle_log()
			else: board.scene_view = ""
		"next": board.advance_scene()
		"log": board.toggle_log()
		_:
			if action.begins_with("row:"): board.choose_scene_option(int(action.get_slice(":",1)))
	board.queue_redraw()
	return true

static func handle_roster_input(board, event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		if board.roster_open: board.roster_open = false
		else: board.open_roster()
		board.queue_redraw()
		return true
	if not board.roster_open:
		if board.result_ready and board.scene_view == "" and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = board.get_global_transform_with_canvas().affine_inverse()*event.position
			if board.ROSTER_RECT.has_point(point):
				board.open_roster()
				return true
		return false
	var rows := []
	for index in range(board.campaign["members"].size()): rows.append(Rect2(60,210+index*67,300,58))
	var point := Vector2.ZERO
	if event is InputEventMouse: point = board.get_global_transform_with_canvas().affine_inverse()*event.position
	var action := ModalInput.command(event,point,
		{KEY_ESCAPE:"back",KEY_ENTER:"deploy",KEY_T:"care",KEY_RIGHT:"right",KEY_LEFT:"left",KEY_DOWN:"down",KEY_UP:"up",KEY_K:"save",KEY_L:"load"},
		{"care":board.CARE_RECT,"deploy":board.DEPLOY_RECT,"back":board.BACK_RECT},rows)
	match action:
		"back": board.roster_open = false
		"deploy": board.start_second_deployment()
		"care": board.provide_staging_care()
		"right": board.history_page += 1
		"left": board.history_page = maxi(0,board.history_page-1)
		"down", "up":
			board.roster_index = posmod(board.roster_index+(1 if action=="down" else -1),board.campaign["members"].size())
			board.history_page = 0
		"save": board.save_encounter()
		"load": board.load_encounter()
		_:
			if action.begins_with("row:"):
				board.roster_index = int(action.get_slice(":",1))
				board.history_page = 0
	board.queue_redraw()
	return true

static func handle_return_input(board, event: InputEvent) -> bool:
	if board.return_state["active"] and board.scene_view == "" and not board.roster_open and not board.result_ready:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Y:
			board.use_cooling_move()
			return true
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = board.get_global_transform_with_canvas().affine_inverse()*event.position
			if board.COOLING_BUTTON.has_point(point):
				board.use_cooling_move()
				return true
	return false

static func handle_ending_input(board, event: InputEvent) -> bool:
	if board.ending_available():
		if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_Z or (board.roster_open and event.keycode == KEY_ENTER)):
			board.open_ending_test()
			return true
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var point: Vector2 = board.get_global_transform_with_canvas().affine_inverse()*event.position
			if (board.roster_open and board.DEPLOY_RECT.has_point(point)) or (not board.roster_open and board.scene_view == "" and board.ENDING_RECT.has_point(point)):
				board.open_ending_test()
				return true
	return false

static func draw_story_navigation(board) -> void:
	if not board.result_ready:
		SceneChrome.header(board,board.font,"HOLDFAST / C1 · TAB: SCENE LOG",790,Color.WHITE)
	elif not board.retry_required():
		SceneChrome.button(board,board.font,board.DEBRIEF_RECT,"Debrief [B]",Color("344f46"),27,18)

static func draw_roster_navigation(board) -> void:
	if not board.result_ready:
		SceneChrome.header(board,board.font,"HOLDFAST / C2 · DEPLOYMENT %d / 2" % board.campaign.get("deployment",1),805,Color.WHITE)
	else:
		SceneChrome.button(board,board.font,board.ROSTER_RECT,"Roster / service history [G]",Color("344f46"),27,17)
		if board.campaign["committed"]:
			SceneChrome.button(board,board.font,board.RETRY_RECT,"Roster [Q / G]",Color("304965"),35,19)
