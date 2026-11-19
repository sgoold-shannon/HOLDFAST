extends RefCounted
## Farm Road's machine controls: the breaker (open, isolate) and the console protocol
## (observe, transmit, authenticate, divert), including when the machine turns on you.
## Moved out of encounter_controller.gd; the controller keeps one-line wrappers.

static func origin_breaker_reason(board) -> String:
	if board.ended:
		return "Operation ended."
	if not board.machine_present():
		return "Machine destroyed or departed; breaker unavailable."
	if board.disabled():
		return "Drive already isolated."
	if not board.soldier_can_act(board.active_soldier):
		return "Select an active soldier."
	var delta: Vector2i = board.soldiers[board.active_soldier]["cell"] - board.BREAKER_CELL
	if absi(delta.x) + absi(delta.y) != 1:
		return "Stand adjacent to breaker (9,4)."
	if board.soldiers[board.active_soldier]["ap"] < 1:
		return "Breaker action needs 1 AP."
	return ""

static func operate_origin_breaker(board, confirm: bool = false) -> bool:
	var reason = board.breaker_reason()
	if reason != "":
		board.status_text = reason
		board.isolate_pending = false
		board.queue_redraw()
		return false
	board.close_pending = false
	if board.breaker_progress == 0:
		board.soldiers[board.active_soldier]["ap"] -= 1
		board.breaker_progress = 1
		board.status_text = "%s opened the breaker for 1 AP. Housing stays open." % board.soldiers[board.active_soldier]["name"]
		board.rebuild_movement()
		return true
	if not confirm or not board.isolate_pending:
		board.isolate_pending = true
		board.queue_redraw()
		return false
	board.soldiers[board.active_soldier]["ap"] -= 1
	board.breaker_progress = 2
	board.isolate_pending = false
	board.machine["pending_shot"] = board.NONE
	for cohort in board.cohorts:
		if cohort["status"] == "active" and cohort["order"] in ["north", "south"] and not cohort["passed"]:
			cohort["passed"] = cohort["cell"] == board.civilian_waypoint(cohort["order"])
			cohort["note"] = "Using confirmed bypass"
	board.status_text = "Drive isolated for 1 AP. Machine stopped; civilian gates locked; bypasses applied."
	board.enemy_message = "Feeder unpowered. Machine retained for later repair."
	board.rebuild_movement()
	return true

static func origin_protocol_reason(board, action: String) -> String:
	if board.ended or not board.machine_present() or board.disabled():
		return "Protocol unavailable: encounter ended or machine stopped/departed."
	if board.machine["collected_round"] > 0:
		return "Too late: the skid has already been collected."
	if not board.soldier_can_act(board.active_soldier) or board.soldiers[board.active_soldier]["ap"] < 1:
		return "Select an active soldier with 1 AP."
	if action == "observe" or action == "transmit":
		if board.active_soldier != 0:
			return "Only MSG may observe and transmit the pause protocol."
		if action == "observe":
			if board.protocol["observed"]:
				return "Machine already observed."
			var info = board.sight_preview(board.soldiers[0]["cell"],board.enemies[0]["cell"])
			if not info["clear"] or info["distance"] > 8:
				return "Observation needs sight and Manhattan distance 8 or less."
		else:
			if not board.protocol["observed"]:
				return "Observe the machine before transmitting."
			if board.protocol["acknowledged"]:
				return "Pause already acknowledged; it can be requested only once."
	else:
		if not board.protocol["acknowledged"]:
			return "Console requires the returned acknowledgement token."
		var eligible = board.active_soldier == 2 or (board.active_soldier == 0 and not board.soldier_can_act(2))
		if not eligible:
			return "%s operates the console. MSG substitutes if unavailable." % board.soldiers[2]["name"]
		var delta: Vector2i = board.soldiers[board.active_soldier]["cell"] - board.CONSOLE_CELL
		if absi(delta.x) + absi(delta.y) != 1:
			return "Stand adjacent to the console at (11,12)."
		if action == "authenticate" and board.protocol["authenticated"]:
			return "Token already authenticated."
		if action == "divert":
			if not board.protocol["authenticated"]:
				return "Authenticate ACK-01 before setting the route."
			if board.protocol["route_set"]:
				return "Diversion already used; firing on it cancels safe routing."
	return ""

static func execute_protocol_action(board, action: String) -> bool:
	if not ["observe","transmit","authenticate","divert"].has(action):
		return false
	var reason = board.protocol_reason(action)
	if reason != "":
		board.status_text = reason
		board.queue_redraw()
		return false
	board.close_pending = false
	board.soldiers[board.active_soldier]["ap"] -= 1
	match action:
		"observe":
			board.protocol["observed"] = true
			board.status_text = "Observed machine. Pause protocol displayed: HOLD / ONE CYCLE."
		"transmit":
			board.protocol["acknowledged"] = true
			board.protocol["pause_pending"] = true
			board.status_text = "ACK-01 received. The next machine activation will be skipped once."
		"authenticate":
			board.protocol["authenticated"] = true
			board.status_text = "ACK-01 authenticated. Set alternate route for 1 AP before skid collection."
		"divert":
			board.protocol["route_set"] = true
			board.protocol["diverted"] = true
			board.machine["pending_shot"] = board.NONE
			board.machine["hostile"] = false
			board.status_text = "Diverted: (10,10) → (14,10) → component (14,8). Avoids people."
	board.rebuild_movement()
	return true

static func apply_protocol_betrayal(board, fired: bool, was_diverted: bool) -> void:
	if fired and was_diverted:
		board.protocol["diverted"] = false
		board.protocol["betrayed"] = true
		board.machine["hostile"] = true
		if board.machine_present():
			board.status_text += " Safe routing canceled; returning to skid."

static func update_protocol_observation(board, action: String, success: bool) -> void:
	if success and action == "observe":
		board.status_text = "Fact: retrieving a marked component. Assessment: evacuation equipment (unconfirmed). Tab: log."
