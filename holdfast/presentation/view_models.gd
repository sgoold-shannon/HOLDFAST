extends RefCounted
## View models: the plain dictionaries each panel and map layer draws from.
## Read-only summaries of encounter state; moved out of encounter_controller.gd
## (the controller keeps one-line wrappers with the original names).
const ReturnRules = preload("res://return_rules.gd")

static func board_view_snapshot(board) -> Dictionary:
	var costs := {}
	if not board.sight_mode:
		for y in range(1,board.GRID_SIZE.y+1):
			for x in range(1,board.GRID_SIZE.x+1):
				var cell := Vector2i(x,y)
				var cost = board.move_cost(cell)
				if cost > 0: costs[cell] = cost
	return {"size":board.GRID_SIZE,"cell_size":board.CELL_SIZE,"origin":board.GRID_ORIGIN,
		"walls":board.WALL_CELLS.duplicate(),"exits":board.mission_definition().squad_exits.duplicate(),
		"selected":board.selected_cell,"costs":costs}

static func soldier_marker_snapshot(board, index: int) -> Dictionary:
	return {"shape":index%4,"mark":board.soldiers[index]["mark"],"selected":index==board.active_soldier,
		"color":board.soldier_color(index) if board.soldiers[index]["hp"] > 0 else Color("b36b6b")}

static func tactical_overlay_snapshot(board, path: Array[Vector2i], target: Vector2i) -> Dictionary:
	var aim := {}
	if board.sight_mode and board.active_soldier >= 0 and board.cell_is_in_bounds(target):
		var source: Vector2i = board.soldiers[board.active_soldier]["cell"]
		var info = board.sight_preview(source,target)
		aim = {"source":source,"target":target,"cells":info["cells"].duplicate(),
			"blockers":info["blockers"].duplicate(),"clear":info["clear"],"protected":info["protected"]}
	return {"path":path.duplicate(),"aim":aim,"cover":board.mission_definition().cover_edges.duplicate(true),"cell_size":board.CELL_SIZE}

static func tactical_panel_snapshot(board, path: Array[Vector2i], target: Vector2i) -> Dictionary:
	var roles := []
	var colors := []
	for index in range(board.soldiers.size()):
		roles.append(board.soldier_role(index))
		colors.append(board.soldier_color(index))
	return {
		"active_soldier":board.active_soldier,
		"selected_cell":board.selected_cell,
		"NONE":board.NONE,
		"hovered_cell":board.hovered_cell,
		"sight_mode":board.sight_mode,
		"pinned_target":board.pinned_target,
		"status_text":board.status_text,
		"phase":board.phase,
		"enemy_message":board.enemy_message,
		"save_feedback":board.save_feedback,
		"NEXT_PHASE_RECT":board.NEXT_PHASE_RECT,
		"MODE_RECT":board.MODE_RECT,
		"FIRE_RECT":board.FIRE_RECT,
		"RELOAD_RECT":board.RELOAD_RECT,
		"EXTRACT_RECT":board.EXTRACT_RECT,
		"SAVE_RECT":board.SAVE_RECT,
		"LOAD_RECT":board.LOAD_RECT,
		"soldiers":board.soldiers.duplicate(true),
		"path":path.duplicate(),
		"target":target,
		"cost":board.move_cost(board.hovered_cell),
		"valid_target":board.cell_is_in_bounds(target),
		"info":board.sight_preview(board.soldiers[board.active_soldier]["cell"],target).duplicate(true) if board.active_soldier >= 0 and board.cell_is_in_bounds(target) else {},
		"roles":roles,
		"colors":colors,
		"intent":board.enemy_intent(),
		"fire_reason":board.fire_block_reason()}

static func machine_view_snapshot(board) -> Dictionary:
	return {
		"track":board.machine_track().duplicate(),
		"FIXTURES":board.FIXTURES.duplicate(),
		"breaker":board.mission_definition().breaker_cell,
		"skid":board.mission_definition().skid_cell,
		"skid_visible":board.skid_visible(),
		"next":board.next_machine_cell(),
		"present":board.machine_present(),
		"machine":board.machine.duplicate(true),
		"enemies":board.enemies.duplicate(true),
		"sight_mode":board.sight_mode,
		"pinned_target":board.pinned_target,
		"NONE":board.NONE}

static func machine_status_snapshot(board) -> Dictionary:
	return {
		"phase":board.phase,
		"enemy_message":board.enemy_message,
		"save_feedback":board.save_feedback,
		"sight_mode":board.sight_mode,
		"pinned_target":board.pinned_target,
		"machine":board.machine.duplicate(true),
		"enemies":board.enemies.duplicate(true),
		"danger":board.danger_summary(),
		"present":board.machine_present(),
		"intent":board.enemy_intent()}

static func civilian_view_snapshot(board) -> Dictionary:
	return {
		"cohorts":board.cohorts.duplicate(true),
		"cohort_selected":board.cohort_selected,
		"waypoints":[board.civilian_waypoint("north"),board.civilian_waypoint("south")],
		"route":board.route_preview(board.cohorts[board.cohort_selected],board.cohorts[board.cohort_selected]["order"]).duplicate() if board.cohorts[board.cohort_selected]["status"] == "active" else [],
		"exit":board.civilian_exit()}

static func civilian_panel_snapshot(board) -> Dictionary:
	var labels := []
	var notes := []
	for cohort in board.cohorts:
		labels.append(board.cohort_order_label(cohort))
		notes.append(board.follow_wait_reason(cohort) if cohort["status"] == "active" and cohort["order"] == "follow" and board.follow_path(cohort).is_empty() else ("Waiting for your order" if cohort["order"] == "hold" and cohort["status"] == "active" else cohort["note"]))
	return {
		"cohort_selected":board.cohort_selected,
		"ended":board.ended,
		"order_used":board.order_used,
		"close_pending":board.close_pending,
		"end_reason":board.end_reason,
		"phase":board.phase,
		"save_feedback":board.save_feedback,
		"EXIT_ORDER_RECT":board.EXIT_ORDER_RECT,
		"FOLLOW_RECT":board.FOLLOW_RECT,
		"HOLD_RECT":board.HOLD_RECT,
		"NORTH_RECT":board.NORTH_RECT,
		"SOUTH_RECT":board.SOUTH_RECT,
		"CLOSE_RECT":board.CLOSE_RECT,
		"CANCEL_RECT":board.CANCEL_RECT,
		"cohorts":board.cohorts.duplicate(true),
		"soldiers":board.soldiers.duplicate(true),
		"machine":board.machine.duplicate(true),
		"labels":labels,
		"notes":notes,
		"leader":board.soldiers[board.active_soldier]["name"] if board.soldier_can_act(board.active_soldier) else "select soldier",
		"north_label":board.route_label("north"),
		"south_label":board.route_label("south"),
		"north_available":board.route_available("north"),
		"exit":board.civilian_exit(),
		"deadline":board.deadline(),
		"remaining":board.remaining_civilians(),
		"present":board.machine_present()}

static func breaker_panel_snapshot(board) -> Dictionary:
	return {
		"sight_mode":board.sight_mode,
		"breaker_progress":board.breaker_progress,
		"pinned_target":board.pinned_target,
		"isolate_pending":board.isolate_pending,
		"BREAKER_RECT":board.BREAKER_RECT,
		"CONFIRM_RECT":board.CONFIRM_RECT,
		"ABORT_RECT":board.ABORT_RECT,
		"save_feedback":board.save_feedback,
		"GATES":board.GATES.duplicate(),
		"enemies":board.enemies.duplicate(true),
		"disabled":board.disabled(),
		"reason":board.breaker_reason(),
		"present":board.machine_present(),
		"victims":board.blast_victims(),
		"outcome":board.machine_outcome(),
		"deadline":board.deadline()}

static func protocol_panel_snapshot(board) -> Dictionary:
	var reasons := {}
	for action in ["observe","transmit","authenticate","divert"]: reasons[action] = board.protocol_reason(action)
	return {
		"OBSERVE_RECT":board.OBSERVE_RECT,
		"TRANSMIT_RECT":board.TRANSMIT_RECT,
		"AUTH_RECT":board.AUTH_RECT,
		"DIVERT_RECT":board.DIVERT_RECT,
		"phase":board.phase,
		"protocol":board.protocol.duplicate(true),
		"soldiers":board.soldiers.duplicate(true),
		"machine":board.machine.duplicate(true),
		"DIVERSION":board.DIVERSION.duplicate(),
		"reasons":reasons,
		"present":board.machine_present(),
		"disabled":board.disabled(),
		"path":board.machine_path(board.enemies[0]["cell"],board.SKID_CELL,false).duplicate() if board.machine["collected_round"] == 0 and board.machine_present() and not board.disabled() and not board.protocol["diverted"] else [],
		"deadline":board.deadline()}

static func rescue_panel_snapshot(board) -> Dictionary:
	var visible := []
	for index in range(board.soldiers.size()): visible.append(board.soldier_visible(index))
	var target = board.target_for_rescue()
	return {
		"active_soldier":board.active_soldier,
		"close_pending":board.close_pending,
		"ended":board.ended,
		"CASUALTY_RECT":board.CASUALTY_RECT,
		"STABILIZE_RECT":board.STABILIZE_RECT,
		"PICKUP_RECT":board.PICKUP_RECT,
		"DROP_RECT":board.DROP_RECT,
		"soldiers":board.soldiers.duplicate(true),
		"visible":visible,
		"target":target,
		"target_available":board.casualty_available(target),
		"can_act":board.soldier_can_act(board.active_soldier)}

static func results_panel_snapshot(board) -> Dictionary:
	var dispositions := []
	for index in range(board.soldiers.size()): dispositions.append(board.soldier_disposition(index))
	return {
		"phase":board.phase,
		"end_reason":board.end_reason,
		"result_feedback":board.result_feedback,
		"RETRY_RECT":board.RETRY_RECT,
		"RESUME_RECT":board.RESUME_RECT,
		"RECORD_RECT":board.RECORD_RECT,
		"soldiers":board.soldiers.duplicate(true),
		"cohorts":board.cohorts.duplicate(true),
		"protocol":board.protocol.duplicate(true),
		"rescue_events":board.rescue_events.duplicate(true),
		"title":board.result_title(),
		"retry":board.retry_required(),
		"dispositions":dispositions,
		"evacuated":board.evacuated_people(),
		"outcome":board.machine_outcome(),
		"feeder":board.feeder_result()}

static func story_panel_snapshot(board) -> Dictionary:
	return {
		"scene_view":board.scene_view,
		"scene_page":board.scene_page,
		"NEXT_RECT":board.NEXT_RECT,
		"SKIP_RECT":board.SKIP_RECT,
		"LOG_RECT":board.LOG_RECT,
		"save_feedback":board.save_feedback,
		"pages":board.current_pages().duplicate(true),
		"options":board.scene_options().duplicate()}

static func roster_panel_snapshot(board) -> Dictionary:
	var details = board.roster_details(board.campaign["members"][board.roster_index])
	board.history_page = clampi(board.history_page,0,maxi(1,ceili(details.size()/9.0))-1)
	return {
		"roster_index":board.roster_index,
		"history_page":board.history_page,
		"CARE_RECT":board.CARE_RECT,
		"DEPLOY_RECT":board.DEPLOY_RECT,
		"BACK_RECT":board.BACK_RECT,
		"result_feedback":board.result_feedback,
		"campaign":board.campaign.duplicate(true),
		"details":details,
		"care":board.can_receive_staging_care(),
		"deploy":board.can_deploy()}

static func return_overlay_snapshot(board) -> Dictionary:
	return {
		"roster_open":board.roster_open,
		"scene_view":board.scene_view,
		"result_ready":board.result_ready,
		"DEPLOY_RECT":board.DEPLOY_RECT,
		"BREAKER_RECT":board.BREAKER_RECT,
		"COOLING_BUTTON":board.COOLING_BUTTON,
		"save_feedback":board.save_feedback,
		"return_state":board.return_state.duplicate(true),
		"campaign":board.campaign.duplicate(true),
		"source_outcome":ReturnRules.outcome(board.campaign),
		"deploy":board.can_deploy(),
		"outcome":board.machine_outcome(),
		"cooling":board.cooling_ready()}

static func ending_overlay_snapshot(board) -> Dictionary:
	return {
		"scene_view":board.scene_view,
		"roster_open":board.roster_open,
		"DEPLOY_RECT":board.DEPLOY_RECT,
		"ENDING_RECT":board.ENDING_RECT,
		"available":board.ending_available()}
