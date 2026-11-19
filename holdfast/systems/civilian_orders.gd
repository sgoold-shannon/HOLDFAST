extends RefCounted
## Civilian orders and the civilian turn: both command models (one order per turn, and
## MSG's voice / 1 AP orders / panic), routes, closing the operation early.
## Moved out of encounter_controller.gd; the controller keeps one-line wrappers.
const CivilianCommand = preload("res://systems/civilian_command.gd")

static func remaining_civilians(board) -> int:
	var count := 0
	for cohort in board.cohorts:
		if cohort["status"] == "active":
			count += 4
	return count

static func civilian_waypoint(board, order: String) -> Vector2i:
	var route := "north" if order == "north" else "south"
	if board.return_state["active"]: return board.mission_definition().civilian_routes[route]
	if board.disabled(): return board.mission_definition().disabled_routes[route]
	return board.NORTH_WAYPOINT if order == "north" else board.SOUTH_WAYPOINT

static func order_cohort(board, index: int, order: String) -> bool:
	if board.return_state["active"] and order == "north" and not board.cooling_ready():
		board.status_text = "Cooling route unavailable. Choose the manual route; disabled equipment needs two repairs."
		board.queue_redraw()
		return false
	return issue_civilian_order(board, index,order)

static func issue_civilian_order(board, index: int, order: String) -> bool:
	board.close_pending = false
	if board.command_model == "authority":
		return issue_authority_order(board, index,order)
	if board.ended or board.order_used or index < 0 or index >= 3 or board.cohorts[index]["status"] != "active" or not ["hold", "north", "south", "follow"].has(order):
		board.status_text = "Order unavailable: one free group order per player phase."
		board.queue_redraw()
		return false
	if order == "follow" and not board.soldier_can_act(board.active_soldier):
		board.status_text = "Select a standing soldier on the map, then choose Follow Soldier."
		board.queue_redraw()
		return false
	board.cohorts[index]["leader"] = board.active_soldier if order == "follow" else -1
	board.cohorts[index]["order"] = order
	board.cohorts[index]["passed"] = board.cohorts[index]["cell"] == civilian_waypoint(board, order)
	board.cohorts[index]["note"] = "Waiting for your order" if order == "hold" else "Moves after End turn [N]"
	board.order_used = true
	board.status_text = "Group %s: %s. End turn [N] to move; this order stays active." % [board.cohorts[index]["id"], cohort_order_label(board, board.cohorts[index])]
	board.queue_redraw()
	return true

static func issue_authority_order(board, index: int, order: String) -> bool:
	if board.ended or index < 0 or index >= 3 or board.cohorts[index]["status"] != "active" or not ["hold", "north", "south", "follow"].has(order):
		board.status_text = "Order unavailable."
		board.queue_redraw()
		return false
	var cohort: Dictionary = board.cohorts[index]
	var authority = CivilianCommand.order_authority(board.soldiers,board.active_soldier,cohort)
	if not authority["ok"]:
		board.status_text = "Group %s: %s." % [cohort["id"],authority["text"]]
		board.queue_redraw()
		return false
	if order == "follow" and not board.soldier_can_act(board.active_soldier):
		board.status_text = "Select a standing soldier on the map, then choose Follow Soldier."
		board.queue_redraw()
		return false
	if authority["cost"] > 0:
		board.soldiers[authority["by"]]["ap"] -= authority["cost"]
	cohort["leader"] = board.active_soldier if order == "follow" else -1
	cohort["order"] = order
	cohort["passed"] = cohort["cell"] == civilian_waypoint(board, order)
	cohort["note"] = "Waiting for your order" if order == "hold" else "Moves after End turn [N]"
	board.status_text = "Group %s: %s — %s. Moves when you end the turn." % [cohort["id"],cohort_order_label(board, cohort),authority["text"]]
	board.queue_redraw()
	return true

static func calm_cohort(board, index: int) -> bool:
	if board.command_model != "authority" or board.ended or index < 0 or index >= board.cohorts.size() or board.cohorts[index]["status"] != "active":
		return false
	var cohort: Dictionary = board.cohorts[index]
	var authority = CivilianCommand.calm_authority(board.soldiers,board.active_soldier,cohort)
	if not authority["ok"]:
		board.status_text = "Group %s: %s." % [cohort["id"],authority["text"]]
		board.queue_redraw()
		return false
	board.soldiers[authority["by"]]["ap"] -= authority["cost"]
	cohort["panic"] = maxi(CivilianCommand.CALM,CivilianCommand.level(cohort)-authority["steps"])
	board.status_text = "Group %s: %s. Now %s." % [cohort["id"],authority["text"],CivilianCommand.level_name(cohort)]
	board.queue_redraw()
	return true

static func civilian_threats(board) -> Array[Vector2i]:
	var threats: Array[Vector2i] = []
	if board.machine_present():
		threats.append(board.enemies[0]["cell"])
		if board.machine["pending_shot"] != board.NONE: threats.append(board.machine["pending_shot"])
	threats.append_array(board.round_noise)
	return threats

static func route_label(board, order: String) -> String:
	if board.return_state["active"]:
		return ("Cooling" if board.cooling_ready() else "Cooling locked") if order == "north" else "Manual route"
	return "Upper route" if order == "north" else "Lower route"

static func order_exit(board, index: int) -> bool:
	if index < 0 or index >= board.cohorts.size(): return false
	var best = board.evacuation_rules.best_exit_route(board.cohorts[index], board.soldiers)
	if best == "":
		board.status_text = "No safe route to exit right now. Clear the marked hazard, then try again."
		board.queue_redraw()
		return false
	return order_cohort(board, index, best)

static func cohort_order_label(board, cohort: Dictionary) -> String:
	if cohort["order"] == "hold": return "HOLD — needs an order"
	if cohort["order"] == "follow":
		var leader: int = cohort.get("leader", -1)
		return "Follow " + (board.soldiers[leader]["name"] if leader >= 0 and leader < board.soldiers.size() else "missing leader")
	return "To EXIT / " + route_label(board, cohort["order"])

static func resolve_civilian_phase(board) -> void:
	if board.ended or board.last_civilian_phase == board.phase:
		return
	board.last_civilian_phase = board.phase
	if board.command_model == "authority":
		resolve_authority_civilians(board)
		return
	for cohort in board.cohorts:
		board.move_cohort(cohort,3)

static func resolve_authority_civilians(board) -> void:
	var threats := civilian_threats(board)
	for cohort in board.cohorts:
		if cohort["status"] != "active": continue
		var fear = CivilianCommand.update_panic(cohort,threats,board.soldiers)
		if fear == CivilianCommand.PANICKED:
			var step = CivilianCommand.scatter_step(cohort,threats,board.civilian_safe)
			if step != cohort["cell"]:
				cohort["cell"] = step
				board.on_civilian_step(cohort,step)
				cohort["note"] = "PANICKED — scattering away from danger"
			else:
				cohort["note"] = "PANICKED — frozen in place"
			continue
		board.move_cohort(cohort,CivilianCommand.MOVE_BUDGET[fear])
		if fear == CivilianCommand.SHAKEN and cohort["status"] == "active":
			cohort["note"] = "SHAKEN (moves 2) — " + cohort["note"]
	board.round_noise.clear()

static func finish_operation(board, reason: String) -> void:
	if board.ended or board.pending_finish_reason != "":
		return
	board.pending_finish_reason = reason
	board.call_deferred("finalize_result")

static func close_evacuation(board, reason: String) -> void:
	if board.ended:
		return
	board.ended = true
	board.end_reason = reason
	board.close_pending = false
	for cohort in board.cohorts:
		if cohort["status"] == "active":
			cohort["status"] = "stranded"
			cohort["note"] = "Road closed; four stranded" if reason == "Road closed" else "Four left stranded"
	for soldier in board.soldiers:
		if not soldier["extracted"]:
			soldier["left_behind"] = true
	board.active_soldier = -1
	board.selected_cell = board.NONE
	board.pinned_target = board.NONE
	board.status_text = reason + (". MSG not extracted: retry required." if not board.soldiers[0]["extracted"] else ". Dispositions recorded at right.")
	board.rebuild_movement()

static func request_close(board) -> bool:
	if board.ended:
		return false
	if not board.soldiers[0]["extracted"]:
		board.status_text = "MSG must extract before you can close the operation early."
		board.queue_redraw()
		return false
	if not board.close_pending:
		board.close_pending = true
		board.queue_redraw()
		return false
	finish_operation(board, "Operation closed early")
	return true
