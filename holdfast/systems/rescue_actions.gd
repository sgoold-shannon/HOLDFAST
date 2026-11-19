extends RefCounted
## Casualty rules: damage, bleeding out, stabilize, carry and put down.
## Moved out of encounter_controller.gd; the controller keeps one-line wrappers.

static func kill_soldier(board, index: int) -> void:
	var soldier: Dictionary = board.soldiers[index]
	soldier["condition"] = "dead"
	soldier["ap"] = 0
	soldier["bleed"] = 0
	var passenger: int = soldier["carrying"]
	if passenger >= 0:
		board.soldiers[passenger]["carried_by"] = -1
		soldier["carrying"] = -1
	var host: int = soldier["carried_by"]
	if host >= 0:
		board.soldiers[host]["carrying"] = -1
		soldier["carried_by"] = -1
	if board.active_soldier == index:
		board.active_soldier = -1
		board.selected_cell = board.NONE

static func apply_casualty_damage(board, cell: Vector2i, amount: int) -> String:
	var reports: Array[String] = []
	for index in range(board.soldiers.size()):
		var soldier: Dictionary = board.soldiers[index]
		if soldier["extracted"] or soldier["condition"] == "dead" or soldier["cell"] != cell:
			continue
		var new_hp: int = soldier["hp"] - amount
		soldier["hp"] = maxi(-4,new_hp)
		if new_hp <= -4:
			kill_soldier(board, index)
		elif new_hp <= 0:
			if soldier["condition"] != "critical":
				soldier["bleed"] = 3
				soldier["critical_epoch"] = board.phase
			soldier["condition"] = "critical"
			soldier["ap"] = 0
			if board.active_soldier == index:
				board.active_soldier = -1
				board.selected_cell = board.NONE
		reports.append("%s -%d HP (%s)" % [soldier["name"],amount,soldier["condition"]])
	for cohort in board.cohorts:
		if cohort["status"] == "active" and cohort["cell"] == cell:
			cohort["hp"] = maxi(0,cohort["hp"]-amount)
			if cohort["hp"] == 0:
				cohort["status"] = "stranded"
				cohort["note"] = "Dispersed; four stranded"
			reports.append("group %s -%d HP" % [cohort["id"],amount])
	if board.soldiers[0]["condition"] == "dead" and not board.ended:
		board.finish_operation("MSG killed: retry required")
	return "empty cell" if reports.is_empty() else "; ".join(reports)

static func resolve_bleeding(board) -> bool:
	board.drop_mode = false
	for index in range(board.soldiers.size()):
		var soldier: Dictionary = board.soldiers[index]
		if soldier["condition"] == "critical" and not soldier["extracted"] and board.phase > soldier["critical_epoch"]:
			soldier["bleed"] -= 1
			if soldier["bleed"] == 0:
				kill_soldier(board, index)
	if board.soldiers[0]["condition"] == "dead":
		board.finish_operation("MSG bled out: retry required")
		return false
	return true

static func casualty_available(board, index: int) -> bool:
	return index >= 0 and index < board.soldiers.size() and not board.soldiers[index]["extracted"] and ["critical","stable"].has(board.soldiers[index]["condition"])

static func casualty_in_reach(board, index: int) -> bool:
	if not board.soldier_can_act(board.active_soldier) or not casualty_available(board, index):
		return false
	if board.soldiers[board.active_soldier]["carrying"] == index:
		return true
	var delta: Vector2i = board.soldiers[board.active_soldier]["cell"] - board.soldiers[index]["cell"]
	return absi(delta.x)+absi(delta.y) == 1

static func target_for_rescue(board) -> int:
	if board.active_soldier >= 0 and board.soldiers[board.active_soldier]["carrying"] >= 0:
		return board.soldiers[board.active_soldier]["carrying"]
	return board.rescue_target

static func try_stabilize(board) -> bool:
	var actor = board.active_soldier
	var casualty := target_for_rescue(board)
	var success := stabilize_casualty(board)
	if success: board.record_rescue("stabilized",actor,casualty)
	return success

static func stabilize_casualty(board) -> bool:
	var target := target_for_rescue(board)
	if board.ended or not casualty_in_reach(board, target) or board.soldiers[board.active_soldier]["ap"] < 1:
		board.status_text = "Stabilize: select a rescuer with 1 AP and an adjacent or carried casualty."
	elif board.soldiers[target]["condition"] != "critical":
		board.status_text = "Casualty already stable."
	elif board.soldiers[board.active_soldier]["medical"] < 1:
		board.status_text = "No medical charges. The deployed medic starts with two."
	else:
		board.soldiers[board.active_soldier]["ap"] -= 1
		board.soldiers[board.active_soldier]["medical"] -= 1
		board.soldiers[target]["hp"] = 1
		board.soldiers[target]["condition"] = "stable"
		board.soldiers[target]["bleed"] = 0
		board.status_text = "%s stabilized %s: 1 HP, bleeding stopped, still incapacitated." % [board.soldiers[board.active_soldier]["name"],board.soldiers[target]["name"]]
		board.rebuild_movement()
		return true
	board.queue_redraw()
	return false

static func try_pickup(board) -> bool:
	var actor = board.active_soldier
	var casualty = board.rescue_target
	var success := pick_up_casualty(board)
	if success: board.record_rescue("picked_up",actor,casualty)
	return success

static func pick_up_casualty(board) -> bool:
	var target = board.rescue_target
	if board.ended or not casualty_in_reach(board, target) or board.soldiers[board.active_soldier]["ap"] < 1:
		board.status_text = "Pick up: select a rescuer with 1 AP and an adjacent casualty."
	elif board.soldiers[board.active_soldier]["carrying"] >= 0:
		board.status_text = "Already carrying a casualty."
	elif board.soldiers[target]["carrying"] >= 0:
		board.status_text = "This fallen carrier has a casualty. Rescue their passenger first (V cycles)."
	elif board.soldiers[target]["carried_by"] >= 0 and board.soldier_can_act(board.soldiers[target]["carried_by"]):
		board.status_text = "Another active soldier is carrying this casualty. Put them down first."
	else:
		var old_host: int = board.soldiers[target]["carried_by"]
		if old_host >= 0:
			board.soldiers[old_host]["carrying"] = -1
		board.soldiers[board.active_soldier]["ap"] -= 1
		board.soldiers[board.active_soldier]["carrying"] = target
		board.soldiers[target]["carried_by"] = board.active_soldier
		board.soldiers[target]["cell"] = board.soldiers[board.active_soldier]["cell"]
		board.status_text = "%s picked up %s. Move ≤2 squares; no firing or machinery." % [board.soldiers[board.active_soldier]["name"],board.soldiers[target]["name"]]
		board.rebuild_movement()
		return true
	board.queue_redraw()
	return false

static func request_drop(board) -> void:
	if board.ended or not board.soldier_can_act(board.active_soldier) or board.soldiers[board.active_soldier]["carrying"] < 0 or board.soldiers[board.active_soldier]["ap"] < 1:
		board.status_text = "Put down requires a carrier with 1 AP."
	else:
		board.drop_mode = true
		board.status_text = "Click a free adjacent cell to put down the casualty. Esc cancels."
	board.queue_redraw()

static func try_drop(board, cell: Vector2i) -> bool:
	if board.ended or not board.soldier_can_act(board.active_soldier) or board.soldiers[board.active_soldier]["carrying"] < 0 or board.soldiers[board.active_soldier]["ap"] < 1:
		return false
	var delta: Vector2i = cell - board.soldiers[board.active_soldier]["cell"]
	if absi(delta.x)+absi(delta.y) != 1 or not board.is_walkable(cell) or board.soldier_at(cell) >= 0 or board.cell_occupied_by_people(cell):
		board.status_text = "Choose a free adjacent ground cell."
		board.queue_redraw()
		return false
	var target: int = board.soldiers[board.active_soldier]["carrying"]
	board.soldiers[board.active_soldier]["ap"] -= 1
	board.soldiers[board.active_soldier]["carrying"] = -1
	board.soldiers[target]["carried_by"] = -1
	board.soldiers[target]["cell"] = cell
	board.drop_mode = false
	board.status_text = "%s put down at (%d,%d) for 1 AP." % [board.soldiers[target]["name"],cell.x,cell.y]
	board.rebuild_movement()
	return true

static func limit_carrier_movement(board) -> void:
	if board.soldier_can_act(board.active_soldier) and board.soldiers[board.active_soldier].get("carrying",-1) >= 0:
		for cell in board.distances.keys():
			if board.distances[cell] > 2:
				board.distances.erase(cell)
	board.queue_redraw()

static func close_rescue(board) -> void:
	for soldier in board.soldiers:
		if soldier.get("condition","active") == "dead":
			soldier["left_behind"] = false
	board.drop_mode = false

static func cycle_casualty(board) -> void:
	for offset in range(1,5):
		var index = (board.rescue_target+offset) % 4
		if casualty_available(board, index):
			board.rescue_target = index
			board.queue_redraw()
			return
	board.rescue_target = -1
	board.queue_redraw()
