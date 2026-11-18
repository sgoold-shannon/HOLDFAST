extends RefCounted
## Desktop HUD map clicks. Mirrors the legacy click priority (encounter_input.gd ORDER)
## for clicks that land on the board; buttons and panels are handled by game_shell.gd.

## Returns true when the click did something.
static func click(board, cell: Vector2i) -> bool:
	if board.roster_open or board.scene_view != "" or board.ended or board.isolate_pending:
		return false
	board.hovered_cell = cell
	if not board.cell_is_in_bounds(cell):
		return false
	# Rescue: placing a carried casualty.
	if board.drop_mode:
		board.try_drop(cell)
		board.queue_redraw()
		return true
	# Rescue: clicking a downed soldier marks them as the casualty.
	var index: int = board.soldier_at(cell)
	if index >= 0 and board.casualty_available(index):
		board.rescue_target = index
		board.status_text = "%s selected for rescue. Choose an adjacent rescuer, then Stabilize or Pick up." % board.soldiers[index]["name"]
		board.queue_redraw()
		return true
	# Civilians: clicking a group's square selects that group.
	if index < 0 and not board.sight_mode:
		for group in range(board.cohorts.size()):
			if board.cohorts[group]["status"] == "active" and board.cohorts[group]["cell"] == cell:
				board.cohort_selected = group
				board.status_text = "Group %s selected. Give it an order in the Civilians panel." % board.cohorts[group]["id"]
				board.queue_redraw()
				return true
	# Tactical: aim, select, move.
	if board.sight_mode and board.active_soldier >= 0:
		board.pinned_target = cell if board.pinned_target != cell else board.NONE
		board.queue_redraw()
		return true
	if index >= 0:
		board.select_soldier(index)
	elif board.active_soldier >= 0:
		board.try_move(cell)
	else:
		board.try_select_cell(cell)
	board.queue_redraw()
	return true

static func hover(board, cell: Vector2i) -> void:
	if board.hovered_cell != cell:
		board.hovered_cell = cell
		board.queue_redraw()
