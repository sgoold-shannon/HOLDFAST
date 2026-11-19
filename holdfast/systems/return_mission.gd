extends RefCounted
## Deployment 2, the return to Farm Road: setup, swapping in a fresh attempt, machine
## repair, the cooling move, rules that differ from the first visit, and the ending test.
## Moved out of encounter_controller.gd; the controller keeps one-line wrappers.

static func configure_return(board) -> void:
	board.opening_done = true
	board.opening_step = 2
	board.scene_view = ""
	# A stationary retained asset or an empty footprint; no new enemy is implied.
	board.enemies[0]["hp"] = 16 if ["diverted","disabled"].has(board.return_state["source"]) else 0
	board.machine["pending_shot"] = board.NONE
	board.status_text = "Return to Farm Road: civilians exit north at (10,1). Manual route always available."

static func replace_return_attempt(board, next: Dictionary, state: Dictionary) -> bool:
	var fresh = load(board.return_scene_path()).instantiate()
	fresh.auto_resume = false
	fresh.campaign = next
	fresh.return_state = state
	fresh.campaign_path = board.campaign_path
	fresh.preference = board.preference
	board.get_parent().add_child(fresh)
	fresh.report_path = board.report_path
	fresh.completion_path = board.completion_path
	var problem: String = fresh.checkpoint()
	if problem != "":
		fresh.queue_free()
		board.result_feedback = problem
		board.queue_redraw()
		return false
	if board.get_tree().current_scene == board: board.get_tree().current_scene = fresh
	board.queue_free()
	return true

static func activate_return_staging(board) -> void:
	board.last_enemy_phase = board.phase
	board.enemy_message = "Return staging: no hostile activation. North access closes after round 10."

static func repair_return_machine(board) -> bool:
	if board.ended or board.return_state["source"] != "disabled" or board.return_state["repair"] == 2:
		board.status_text = "Repairs apply only to the retained disabled machine, once per step."
	elif not board.soldier_can_act(board.active_soldier) or board.soldiers[board.active_soldier]["ap"] < 1:
		board.status_text = "Select an active soldier with 1 AP."
	elif board.soldiers[board.active_soldier]["carrying"] >= 0:
		board.status_text = "Put down the casualty before repairing machinery."
	elif (board.soldiers[board.active_soldier]["cell"]-board.REPAIR_CELL).abs().x+(board.soldiers[board.active_soldier]["cell"]-board.REPAIR_CELL).abs().y != 1:
		board.status_text = "Stand adjacent to the retained machine at (10,8)."
	else:
		board.soldiers[board.active_soldier]["ap"] -= 1
		board.return_state["repair"] += 1
		board.status_text = "Repair %d/2 complete for 1 AP. %s" % [board.return_state["repair"],"Cooling route and one free move available." if board.cooling_ready() else "One more adjacent action required; another soldier may finish."]
		board.rebuild_movement()
		return true
	board.queue_redraw()
	return false

static func use_cooling_move(board) -> bool:
	if board.ended or not board.return_state["active"] or not board.cooling_ready() or board.return_state["bonus_event"] != "":
		board.status_text = "Cooling move unavailable or already used."
		board.queue_redraw()
		return false
	var cohort: Dictionary = board.cohorts[board.cohort_selected]
	if cohort["status"] != "active" or cohort["order"] == "hold":
		board.status_text = "Select an active civilian group and give it an evacuation order first."
		board.queue_redraw()
		return false
	var before: Vector2i = cohort["cell"]
	board.move_cohort(cohort,3)
	if cohort["cell"] == before:
		board.status_text = "No safe movement available; cooling move retained."
		board.queue_redraw()
		return false
	board.return_state["bonus_event"] = "return-cooling-move-1"
	board.return_state["bonus_group"] = cohort["id"]
	board.status_text = "Cooling-assisted move used by group %s: up to 3 squares, no AP. One use per return." % cohort["id"]
	board.queue_redraw()
	return true

static func reject_return_fire(board) -> bool:
	board.status_text = "No hostile targets in this return-map test."
	board.queue_redraw()
	return false

static func reject_return_protocol(board) -> bool:
	board.status_text = "Original protocol outcome retained. Use I to repair or Y for the cooling move."
	board.queue_redraw()
	return false

static func record_return_result(board) -> void:
	if board.return_state["active"] and board.campaign["committed"]:
		board.campaign["missions"][-1]["return_map"] = board.return_state.duplicate(true)

static func open_ending_test(board) -> bool:
	if not board.ending_available(): return false
	var test = load("res://ending_test.tscn").instantiate()
	test.source_snapshot = board.encounter_snapshot()
	test.return_board = board
	board.get_parent().add_child(test)
	board.hide()
	board.set_process_unhandled_input(false)
	return true
