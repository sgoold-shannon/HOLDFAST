extends RefCounted
## Squad actions: selecting, moving, aiming, firing, reloading, extracting, and the start of each player turn.
## Moved out of encounter_controller.gd; the controller keeps one-line wrappers.
const MovementSearch = preload("res://systems/movement_search.gd")

static func try_extract(board) -> bool:
	var actor = board.active_soldier
	var passenger: int = board.soldiers[actor]["carrying"] if actor >= 0 else -1
	board.close_pending = false
	var success = false
	if not board.ended:
		success = extract_selected_soldier(board)
		# Preserve the original status evaluation before passenger extraction.
		if success and board.all_extracted():
			board.status_text = "Squad extracted. %d civilians remain; continue turns or close operation." % board.remaining_civilians()
	if success and passenger >= 0:
		board.soldiers[passenger]["extracted"] = true
		board.soldiers[passenger]["carried_by"] = -1
		board.soldiers[actor]["carrying"] = -1
		board.status_text = "%s and %s extracted together for 1 AP." % [board.soldiers[actor]["name"],board.soldiers[passenger]["name"]]
		board.record_rescue("extracted_with",actor,passenger)
	if not success and board.return_state["active"]:
		board.status_text = "North extraction: (9,1) through (11,1), 1 AP; carriers extract both."
	return success

static func extract_selected_soldier(board) -> bool:
	if not board.soldier_can_act(board.active_soldier):
		board.status_text = "Select an active soldier to extract."
	elif not board.extraction_cell(board.soldiers[board.active_soldier]["cell"]):
		board.status_text = board.mission_definition().squad_exit_hint
	elif board.soldiers[board.active_soldier]["ap"] < 1:
		board.status_text = "Extraction needs 1 AP. Entering the zone does not extract automatically."
	else:
		var soldier: Dictionary = board.soldiers[board.active_soldier]
		soldier["ap"] -= 1
		soldier["extracted"] = true
		board.status_text = "%s extracted for 1 AP." % soldier["name"]
		if board.all_extracted():
			board.status_text = "All four soldiers extracted. A5 encounter complete."
		board.active_soldier = -1
		board.selected_cell = board.NONE
		board.pinned_target = board.NONE
		board.rebuild_movement()
		return true
	board.queue_redraw()
	return false

static func rifle_block_reason(board) -> String:
	if not board.soldier_can_act(board.active_soldier):
		return "Select an active soldier."
	var soldier: Dictionary = board.soldiers[board.active_soldier]
	if soldier["attacked"]:
		return "Attack already used this round."
	if soldier["ap"] < 1:
		return "No AP remaining."
	if soldier["ammo"] < 1:
		return "Magazine empty. Reload first."
	if not board.sight_mode:
		return "Switch to sight mode [T] and pin a enemy."
	if board.pinned_target == board.NONE:
		return "Click a enemy to pin it before firing."
	if board.target_at(board.pinned_target) < 0:
		return "Pin a standing enemy (red E)."
	var info = board.sight_preview(soldier["cell"], board.pinned_target)
	if not info["clear"]:
		return "Wall blocks the shot."
	if not info["can_fire"]:
		return "Target outside rifle range (1–12 squares)."
	return ""

static func try_fire(board) -> bool:
	if board.return_state["active"]: return board.reject_return_fire()
	var was_diverted: bool = board.protocol["diverted"]
	var shooter_cell: Vector2i = board.soldiers[board.active_soldier]["cell"] if board.active_soldier >= 0 and board.active_soldier < board.soldiers.size() else board.NONE
	var success = board.fire_at_machine()
	if success and board.command_model == "authority":
		board.round_noise.append(shooter_cell)
		board.round_noise.append(board.enemies[0]["cell"])
	board.apply_protocol_betrayal(success,was_diverted)
	board.check_recovery_failure()
	board.finalize_result()
	return success

static func try_reload(board) -> bool:
	board.close_pending = false
	return false if board.ended else reload_selected_soldier(board)

static func reload_selected_soldier(board) -> bool:
	if not board.soldier_can_act(board.active_soldier):
		board.status_text = "Select an active soldier to reload."
	elif board.soldiers[board.active_soldier]["ap"] < 1:
		board.status_text = "Reload needs 1 AP."
	elif board.soldiers[board.active_soldier]["ammo"] == 4:
		board.status_text = "Magazine already full. No AP spent."
	else:
		board.soldiers[board.active_soldier]["ap"] -= 1
		board.soldiers[board.active_soldier]["ammo"] = 4
		board.status_text = "%s reloaded for 1 AP. Attack allowance unchanged." % board.soldiers[board.active_soldier]["name"]
		board.rebuild_movement()
		return true
	board.queue_redraw()
	return false

static func try_select_cell(board, cell: Vector2i) -> bool:
	if not board.cell_is_in_bounds(cell):
		return false
	if not board.is_walkable(cell):
		board.status_text = "Cell (%d, %d) is blocked. Selection unchanged." % [cell.x, cell.y]
		board.queue_redraw()
		return false
	board.selected_cell = cell
	board.status_text = "Selected ground (%d, %d)." % [cell.x, cell.y]
	board.queue_redraw()
	return true

static func refresh_tactical_movement(board) -> void:
	board.distances.clear()
	board.parents.clear()
	if not board.soldier_can_act(board.active_soldier):
		board.queue_redraw()
		return
	var found = MovementSearch.reachable(board.soldiers[board.active_soldier]["cell"],board.soldiers[board.active_soldier]["ap"]*4,board.DIRECTIONS,board.is_walkable)
	board.distances.merge(found["distances"])
	board.parents.merge(found["parents"])
	board.queue_redraw()

static func move_cost(board, cell: Vector2i) -> int:
	if not board.soldier_can_act(board.active_soldier) or not board.distances.has(cell) or board.soldier_at(cell) >= 0:
		return 0
	var steps: int = board.distances[cell]
	if steps <= 0:
		return 0
	return 1 if steps <= 4 else 2

static func path_to(board, cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if move_cost(board, cell) == 0:
		return path
	var current = cell
	path.push_front(current)
	while board.parents.has(current):
		current = board.parents[current]
		path.push_front(current)
	return path

static func select_soldier(board, index: int) -> void:
	if not board.soldier_can_act(index):
		board.status_text = "Soldier unavailable. Critical soldiers cannot act; recovery comes later."
		board.queue_redraw()
		return
	board.active_soldier = index
	board.selected_cell = board.soldiers[index]["cell"]
	board.status_text = "%s selected. Hover a target; click to pin or unpin." % board.soldiers[index]["name"] if board.sight_mode else "%s selected. Hover a destination to preview its route." % board.soldiers[index]["name"]
	board.rebuild_movement()

static func try_move(board, cell: Vector2i) -> bool:
	var actor = board.active_soldier
	board.close_pending = false
	if board.ended: return false
	var success = move_selected_soldier(board, cell)
	if success and board.soldiers[actor]["carrying"] >= 0:
		board.soldiers[board.soldiers[actor]["carrying"]]["cell"] = cell
	return success

static func move_selected_soldier(board, cell: Vector2i) -> bool:
	var cost = move_cost(board, cell)
	if cost == 0 or cost > board.soldiers[board.active_soldier]["ap"]:
		board.status_text = "Cannot move there: blocked, occupied, or beyond remaining AP."
		board.queue_redraw()
		return false
	var steps: int = board.distances[cell]
	board.soldiers[board.active_soldier]["cell"] = cell
	board.soldiers[board.active_soldier]["ap"] -= cost
	board.selected_cell = cell
	board.status_text = "%s moved %d squares for %d AP. %d AP remaining." % [board.soldiers[board.active_soldier]["name"], steps, cost, board.soldiers[board.active_soldier]["ap"]]
	board.rebuild_movement()
	return true

static func toggle_sight(board) -> void:
	board.sight_mode = not board.sight_mode
	board.status_text = "Aim: click the enemy to pin it, review the chance, then press F to fire." if board.sight_mode else "Movement mode. Click a destination to move."
	board.queue_redraw()

static func run_tactical_command(board, command: String) -> void:
	match command:
		"save": board.save_encounter()
		"load": board.load_encounter()
		"extract": try_extract(board)
		"fire": try_fire(board)
		"reload": try_reload(board)
		"mode": toggle_sight(board)
		"next": board.next_phase()
		"clear":
			board.active_soldier = -1
			board.pinned_target = board.NONE
			board.status_text = "Selection cleared. Click a soldier or inspect a ground cell."
			board.rebuild_movement()

static func begin_player_phase(board) -> void:
	board.phase += 1
	board.order_used = false
	for index in range(board.soldiers.size()):
		if board.soldier_can_act(index):
			board.soldiers[index]["ap"] = 2
			board.soldiers[index]["attacked"] = false
	board.status_text = "Player phase %d: one free group order available." % board.phase
	if board.phase == 2:
		board.status_text = "Briefing: the buried feeder supplies occupied structures; their nature is unknown."
	elif board.phase == 3:
		board.status_text = "Briefing: external road closure confirmed at the end of round 10."
	board.rebuild_movement()
