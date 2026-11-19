extends RefCounted
## Farm Road's machine: its plan and route, what it intends, its activation, damage it deals, and being shot or blown up.
## Moved out of encounter_controller.gd; the controller keeps one-line wrappers.

static func origin_machine_intent(board) -> String:
	if board.machine["departed"]:
		return "Machine departed unresolved."
	if not board.machine_present():
		return "Machine destroyed. Route and pending shot cleared."
	var next = board.next_machine_cell()
	var action = "collect skid" if board.machine["stage"] == 3 else ("depart" if board.machine["stage"] == 8 else "move to (%d,%d)" % [next.x, next.y])
	var shot: Vector2i = board.machine["pending_shot"]
	return "%s | Next: %s%s" % ["HOSTILE" if board.machine["hostile"] else "NEUTRAL", action, " | SHOT (%d,%d): 4 damage" % [shot.x, shot.y] if shot != board.NONE else ""]

static func danger_summary(board) -> String:
	if not board.machine_present(): return "Machine gone. Civilian rescue still needs orders and End turn [N]."
	if board.next_machine_cell() == board.NONE and board.machine["pending_shot"] == board.NONE:
		return board.enemy_intent()
	if board.machine["pending_shot"] != board.NONE:
		return "DANGER: red X takes 4 damage next machine turn. Move off it before [N]."
	if board.machine["hostile"]:
		return "HOSTILE: charges after its move if a soldier is visible within 6 cells; fires next turn."
	return "NEUTRAL: orange cell takes 4 damage if occupied. Firing makes it hostile."

static func damage_cell(board, cell: Vector2i, amount: int) -> String:
	var report = board.apply_casualty_damage(cell,amount)
	# Recovery must wait for every cell in the enclosing blast to resolve.
	board.call_deferred("check_recovery_failure")
	return report

static func activate_origin_machine(board) -> void:
	if board.last_enemy_phase == board.phase: return
	board.last_enemy_phase = board.phase
	var outcome = board.machine_behavior.activate(board.machine,board.enemies[0],board.soldiers,board.phase,machine_plan(board))
	board.enemy_message = outcome["message"]
	if outcome["rebuild"]: board.rebuild_movement()

static func fire_at_machine(board) -> bool:
	var reason = board.fire_block_reason()
	if reason != "":
		board.status_text = reason
		board.queue_redraw()
		return false
	var soldier: Dictionary = board.soldiers[board.active_soldier]
	var info = board.sight_preview(soldier["cell"], board.pinned_target)
	# The machine never receives low-cover protection.
	var chance = clampi(75 + info["range_modifier"], 5, 95)
	var before = board.shot_rng.state
	var roll = board.shot_rng.randi_range(1, 100)
	var damage = 4 if roll <= chance else 0
	soldier["ap"] -= 1
	soldier["ammo"] -= 1
	soldier["attacked"] = true
	board.machine["hostile"] = true
	board.enemies[0]["hp"] = maxi(0, board.enemies[0]["hp"] - damage)
	board.shot_history.append({"phase": board.phase, "soldier": board.active_soldier, "target": board.pinned_target,
		"chance": chance, "roll": roll, "damage": damage, "rng_before": before, "rng_after": board.shot_rng.state})
	board.status_text = "%s: %s (roll %d/%d%%), %d damage. Machine HP %d/16." % [soldier["name"], "HIT" if damage > 0 else "MISS", roll, chance, damage, board.enemies[0]["hp"]]
	if board.enemies[0]["hp"] == 0:
		board.machine["pending_shot"] = board.NONE
		for direction in [Vector2i.ZERO, Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			damage_cell(board, board.enemies[0]["cell"] + direction, 4)
		board.status_text += " Blast: 4 damage nearby. Destroyed before any further response."
	board.rebuild_movement()
	return true

static func machine_plan(board) -> Dictionary:
	return {"collect_stage":board.mission_definition().machine_collect_stage,"depart_stage":board.ROUTE.size()-1,
		"disabled":board.disabled(),"protocol":board.protocol,"skid":board.SKID_CELL,"diversion":board.DIVERSION}

static func machine_path(board, start: Vector2i, goal: Vector2i, avoid_people: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var frontier: Array[Vector2i] = [start]
	var previous: Dictionary = {start: board.NONE}
	var cursor = 0
	while cursor < frontier.size():
		var current = frontier[cursor]
		cursor += 1
		if current == goal:
			while current != start:
				result.push_front(current)
				current = previous[current]
			return result
		for direction in board.DIRECTIONS:
			var next = current + direction
			if previous.has(next) or not board.cell_is_in_bounds(next) or board.WALL_CELLS.has(next) or board.FIXTURES.has(next):
				continue
			if avoid_people and board.cell_occupied_by_people(next):
				continue
			previous[next] = current
			frontier.append(next)
	return result

static func blast_victims(board) -> String:
	var names: Array[String] = []
	for soldier in board.soldiers:
		var delta: Vector2i = soldier["cell"] - board.enemies[0]["cell"]
		if not soldier["extracted"] and absi(delta.x) + absi(delta.y) <= 1:
			names.append(soldier["name"])
	for cohort in board.cohorts:
		var delta: Vector2i = cohort["cell"] - board.enemies[0]["cell"]
		if cohort["status"] == "active" and absi(delta.x) + absi(delta.y) <= 1:
			names.append("group " + cohort["id"])
	return "none" if names.is_empty() else ", ".join(names)

static func origin_machine_outcome(board) -> String:
	if board.enemies[0]["hp"] <= 0:
		return "Destroyed | cooling lost | " + ("skid recoverable" if board.machine["collected_round"] == 0 else "collected skid not restored")
	if board.disabled():
		return "Disabled: machine retained; feeder outage; civilian gates locked."
	if board.machine["departed"]:
		return "Departed unresolved: machine and cooling unit unavailable."
	return "Active: no intervention completed."
